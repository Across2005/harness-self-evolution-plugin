# scripts/test-install-dsh.ps1
# ─────────────────────────────────────────────────────────────────────────────
# install-dsh.ps1 的回归测试（★ 对应 2026-09-22 复验发现的阻塞缺陷）。
#
# 为什么需要它：`install-dsh.ps1` 写的是 DSH **profile 的 patch 层**，而宿主解析该文件
# 失败是 `throw`（`dsh-app-boot/lib/index.js::parsePatchList` :2158-2163），一路上抛到
# prepareProfile —— profile **完全无法 boot**，不只是「插件不挂载」。也就是说：
#
#     这个脚本写坏一个 YAML，用户就打挂了自己的 DSH。
#
# 历史缺陷（复验报告 §4.1）正是如此：DSH 给每个新 profile 生成的出厂 patch 层模板是
# 「注释 + `[]`」，而旧代码把 `[]` 当成「空文件」在其后**追加**块序列项，产出
# `[]` + `- id: …` —— YAML 不允许同一层级上 flow 序列后接块序列项。触发条件是**默认状态**
# （任何新 profile），所以这条回归必须被机器钉住。
#
# 本脚本做什么：在**临时目录**里构造一棵假的 DSH 树，对 patch 层的每一种现状跑**真实的**
# install-dsh.ps1，然后用**宿主自己的 yaml 解析器**（scripts/test-patch-layer.mjs）验证产物。
# 全程只写临时目录，**不触碰任何真实 DSH 树**。
#
# 用法：
#   pwsh -File scripts/test-install-dsh.ps1              # 全部场景
#   pwsh -File scripts/test-install-dsh.ps1 -Keep        # 保留临时树以便人工查看
#   pwsh -File scripts/test-install-dsh.ps1 -Scenario factory-empty
#
# 前置：`node` 在 PATH 上（用于调用宿主 yaml 解析器）；`dsh` **不需要**（用 -SkipPluginAdd）。
# 退出码：0 = 全绿；1 = 有场景失败。
# ─────────────────────────────────────────────────────────────────────────────

[CmdletBinding()]
param(
  [switch]$Keep,
  [string]$Scenario
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $PSScriptRoot 'install-dsh.ps1'
$validator = Join-Path $PSScriptRoot 'test-patch-layer.mjs'
$packageName = '@across2005/harness-self-evolution'

# 宿主的 yaml 包位置：优先 $env:DSH_RUNTIME，其次本机已知 runtime。
if ([string]::IsNullOrWhiteSpace($env:DSH_RUNTIME)) {
  $candidate = 'C:\Users\19207\.minimax\v2\plugin-data\local-minimax\dsh\runtime'
  if (Test-Path (Join-Path $candidate 'node_modules\yaml')) { $env:DSH_RUNTIME = $candidate }
}

foreach ($required in @($installer, $validator)) {
  if (-not (Test-Path $required)) { throw "missing prerequisite: $required" }
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'node is required on PATH (the validator uses the host yaml parser).' }

# ---- 夹具构造 ---------------------------------------------------------------

# 写夹具的统一入口。
#
# 为什么统一走 `[IO.File]::WriteAllText(..., UTF8Encoding($false))`：
#   ① 与 install-dsh.ps1 的写盘方式**逐字一致**（无 BOM、不加尾随换行），这样「幂等」
#      断言比较的是同一件事；
#   ② `Set-Content -NoNewline` 会按宿主默认编码写出，且 here-string 是 CRLF —— 混入
#      CRLF 会让「产物是否逐字不变」的断言出现与兼容性无关的噪声。
#   ③ 归一化到 LF：安装器自己的块就是 LF（`-join "`n"`）。
function Write-Fixture([string]$path, [string]$content) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $lf = ($content -replace "`r`n", "`n")
  [IO.File]::WriteAllText($path, $lf, [Text.UTF8Encoding]::new($false))
}

# DSH 出厂 patch 层模板，逐字取自 `PROFILE_PATCH_TEMPLATE`
# （dsh-app-boot/lib/index.js:480-484）。这是**触发态**，也是最该被钉住的一条。
$factoryTemplate = @"
# Your patch layer for this dsh profile, applied after every bundle layer:
# a top-level YAML array of loader patch entries (id-targeted config
# overrides, disables, and insert lists; ``!!js`` expressions allowed).
[]
"@

# 安装器写出的标记块（与 install-dsh.ps1 §4 同形），用于构造「已装过」的场景。
function New-MountBlock([string]$installedDir, [string]$dshHome) {
  @(
    '# >>> mcp-harness-evolution (install-dsh.ps1) >>>'
    '- id: mcp-harness-evolution'
    '  disabled: false'
    '  config:'
    '    transport: stdio'
    '    serverName: harness-evolution'
    "    command: '$installedDir/bin/harness-evolution.exe'"
    '    args: []'
    "    cwd: '$installedDir'"
    '    env:'
    "      DSH_HOME: '$dshHome'"
    "      HARNESS_EVOLUTION_HOME: '$dshHome/.harness-evolution/v2'"
    '    failOnStartupError: true'
    '# <<< mcp-harness-evolution (install-dsh.ps1) <<<'
  ) -join "`n"
}

# 建一棵假 DSH 树：只造 install-dsh.ps1 会检查的那几项
# （profile 目录、安装位、exe 占位文件）。不造 package.json/cordis.yml，
# 因为 -SkipPluginAdd 路径不读它们。
function New-FakeTree([string]$root) {
  $profileDir = Join-Path $root 'profiles\web'
  $installedDir = Join-Path $profileDir "node_modules\$packageName"
  New-Item -ItemType Directory -Force -Path (Join-Path $installedDir 'bin') | Out-Null
  # exe 占位：安装器只做 Test-Path，不执行它。
  Set-Content -Path (Join-Path $installedDir 'bin\harness-evolution.exe') -Value 'stub' -Encoding ASCII
  return [pscustomobject]@{
    Root         = $root
    ProfileDir   = $profileDir
    InstalledDir = ($installedDir -replace '\\', '/')
    PatchPath    = Join-Path $profileDir 'cordis.patch.yml'
    DshHome      = ($root -replace '\\', '/')
  }
}

# ---- 场景定义 ---------------------------------------------------------------
#
# 每个场景：给定 patch 层现状（$Seed），跑一次真实安装器，然后验证产物。
# `Expect` 用来断言「这一场景独有的性质」；通用性质（可解析、行形态、路径一致）
# 全部由 test-patch-layer.mjs 负责。

$scenarios = @(
  @{
    Name = 'factory-empty'
    Why  = '★ 历史阻塞缺陷的触发态：DSH 出厂空模板（注释 + `[]`）'
    Seed = { param($t) $factoryTemplate }
    Expect = {
      param($text, $t)
      if ($text -match '(?m)^[ \t]*\[\][ \t]*$') { return "the bare '[]' was not replaced" }
      if ($text -notmatch 'a top-level YAML array of loader patch entries') { return 'the factory template comments were dropped (minimal-change principle violated)' }
      return $null
    }
  }
  @{
    Name = 'missing-file'
    Why  = 'patch 层不存在：安装器应自建一份带模板注释的合法文件'
    Seed = { param($t) $null }
    Expect = {
      param($text, $t)
      if ($text -notmatch 'a top-level YAML array of loader patch entries') { return 'expected the header comment on a freshly created patch layer' }
      return $null
    }
  }
  @{
    Name = 'comments-only'
    Why  = '只有注释、没有 `[]`（用户手删过占位符）：不应产生裸 `[]`'
    Seed = { param($t) "# hand-written note by the user`n# keep me`n" }
    Expect = {
      param($text, $t)
      if ($text -notmatch 'keep me') { return 'existing user comments were dropped' }
      return $null
    }
  }
  @{
    Name = 'idempotent'
    Why  = '已含本脚本标记块：必须就地替换（幂等），不得重复追加'
    Seed = { param($t) (New-MountBlock $t.InstalledDir $t.DshHome) + "`n" }
    Expect = {
      param($text, $t)
      $n = ([regex]::Matches($text, [regex]::Escape('- id: mcp-harness-evolution'))).Count
      if ($n -ne 1) { return "expected exactly 1 mount row after re-running, got $n" }
      return $null
    }
  }
  @{
    Name = 'other-plugin-present'
    Why  = 'patch 层已有其它插件的 insert（如 mcp-headroom）：必须保留原样并追加'
    Seed = {
      param($t)
      @(
        '- insert:'
        '    - id: mcp-headroom'
        "      name: '@deepseek-ai/dsh-mcp-client'"
        '      config:'
        '        transport: stdio'
        '        serverName: headroom'
      ) -join "`n"
    }
    Expect = {
      param($text, $t)
      if ($text -notmatch 'mcp-headroom') { return 'the pre-existing mcp-headroom entry was dropped' }
      $n = ([regex]::Matches($text, [regex]::Escape('- id: mcp-harness-evolution'))).Count
      if ($n -ne 1) { return "expected exactly 1 mount row, got $n" }
      return $null
    }
  }
  @{
    Name = 'factory-then-uninstall'
    Why  = '出厂模板上先装再卸：必须**逐字**回到出厂态（可逆），且全程是合法 YAML'
    Seed = { param($t) $factoryTemplate }
    Expect = {
      param($text, $t)
      if ($text -match 'mcp-harness-evolution') { return 'the mount block was not removed by -Uninstall' }
      # 可逆性：卸载后应与「从未装过」的出厂模板逐字一致（含 `[]` 占位符）。
      # 只删块、不补 `[]` 也合法，但会留下一个与出厂态形状不同的文件 —— 那是不必要的状态分叉。
      $expect = ($factoryTemplate -replace "`r`n", "`n").TrimEnd() + "`n"
      $actual = ($text -replace "`r`n", "`n").TrimEnd() + "`n"
      if ($actual -cne $expect) {
        return "uninstall is not reversible: expected the factory template back, got:`n--- expected ---`n$expect`n--- actual ---`n$actual"
      }
      return $null
    }
  }
  @{
    Name = 'other-plugin-then-uninstall'
    Why  = '卸载不得误伤同层的其它插件条目（最小改动原则）'
    Seed = {
      param($t)
      @(
        '- insert:'
        '    - id: mcp-headroom'
        "      name: '@deepseek-ai/dsh-mcp-client'"
        '      config:'
        '        transport: stdio'
        '        serverName: headroom'
        ''
        (New-MountBlock $t.InstalledDir $t.DshHome)
      ) -join "`n"
    }
    Expect = {
      param($text, $t)
      if ($text -match 'mcp-harness-evolution') { return 'the mount block was not removed by -Uninstall' }
      if ($text -notmatch 'mcp-headroom') { return 'uninstall dropped the unrelated mcp-headroom entry' }
      if ($text -match '(?m)^[ \t]*\[\][ \t]*$') { return 'uninstall added a `[]` although real entries remain (that would be invalid YAML)' }
      return $null
    }
  }
)
# ---- 执行 -------------------------------------------------------------------

$selected = if ([string]::IsNullOrWhiteSpace($Scenario)) { $scenarios } else { @($scenarios | Where-Object { $_.Name -eq $Scenario }) }
if ($selected.Count -eq 0) { throw "unknown -Scenario '$Scenario'. Known: $($scenarios.Name -join ', ')" }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("dsh-install-test-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

Write-Host "test-install-dsh.ps1" -ForegroundColor Cyan
Write-Host "  repo      : $repoRoot"
Write-Host "  temp tree : $tempRoot"
if ($env:DSH_RUNTIME) { Write-Host "  dsh runtime: $env:DSH_RUNTIME" }
Write-Host ""

$failures = @()
$passed = 0

try {
  foreach ($s in $selected) {
    $treeRoot = Join-Path $tempRoot $s.Name
    $t = New-FakeTree $treeRoot

    # 1. 播种 patch 层现状
    $seed = & $s.Seed $t
    if ($null -ne $seed) { Write-Fixture $t.PatchPath $seed }

    # 2. 跑**真实的**安装器（-SkipPluginAdd：不碰 dsh/pnpm，只测本脚本写的那个文件）
    Write-Host "── $($s.Name)" -ForegroundColor Cyan
    Write-Host "   $($s.Why)" -ForegroundColor DarkGray
    $uninstall = $s.Name -like '*uninstall*'
    $installerArgs = @(
      '-File', $installer,
      '-Profile', 'web',
      '-DshHome', $t.DshHome,
      '-RepoRoot', $repoRoot,
      '-SkipPluginAdd'
    )
    if ($uninstall) { $installerArgs += '-Uninstall' }

    $output = & pwsh @installerArgs 2>&1 | Out-String
    $code = $LASTEXITCODE
    if ($code -ne 0) {
      $failures += "$($s.Name): installer exited $code`n$($output.Trim())"
      Write-Host "   FAIL installer exit $code" -ForegroundColor Red
      continue
    }

    # 3. 通用验证：宿主同款 yaml 解析器
    $validateArgs = @(
      $validator, $t.PatchPath,
      "--expect-dsh-home=$($t.DshHome)",
      '--quiet'
    )
    if ($uninstall) {
      # 卸载后：仍须是宿主可解析的 YAML，且不再含本插件的行。
      $validateArgs += '--expect-empty'
    } else {
      $validateArgs += "--expect-cwd=$($t.InstalledDir)"
      $validateArgs += "--expect-command=$($t.InstalledDir)/bin/harness-evolution.exe"
    }
    $vout = & node @validateArgs 2>&1 | Out-String
    $vcode = $LASTEXITCODE

    if ($vcode -ne 0) {
      $failures += "$($s.Name): validator rejected the produced patch layer`n$($vout.Trim())"
      Write-Host "   FAIL validator" -ForegroundColor Red
      Write-Host $vout.Trim() -ForegroundColor DarkRed
      continue
    }

    # 4. 场景独有的性质
    $text = Get-Content -Path $t.PatchPath -Raw
    $shapeErr = & $s.Expect $text $t
    if ($null -ne $shapeErr) { $failures += "$($s.Name): $shapeErr"; Write-Host "   FAIL $shapeErr" -ForegroundColor Red; continue }

    # 5. 幂等：再跑一次，产物必须逐字不变（标记块替换路径的核心性质）
    if (-not $uninstall) {
      $before = Get-Content -Path $t.PatchPath -Raw
      & pwsh @installerArgs 2>&1 | Out-Null
      if ($LASTEXITCODE -ne 0) { $failures += "$($s.Name): second installer run exited $LASTEXITCODE"; Write-Host "   FAIL second run" -ForegroundColor Red; continue }
      $after = Get-Content -Path $t.PatchPath -Raw
      if ($before -cne $after) { $failures += "$($s.Name): installer is not idempotent (second run changed the file)"; Write-Host "   FAIL not idempotent" -ForegroundColor Red; continue }
    }

    $passed++
    Write-Host "   PASS" -ForegroundColor Green
  }
} finally {
  if ($Keep) {
    Write-Host "`nkept: $tempRoot" -ForegroundColor Yellow
  } else {
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
  }
}

Write-Host ""
if ($failures.Count -gt 0) {
  Write-Host "FAILED: $($failures.Count) scenario(s), $passed passed" -ForegroundColor Red
  foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
  exit 1
}
Write-Host "PASS: $passed/$($selected.Count) scenarios" -ForegroundColor Green
exit 0
