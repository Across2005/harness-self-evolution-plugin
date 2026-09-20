# scripts/install-dsh.ps1
# ★ v3.1 安装入口：把 MCP 挂载行**按目标树**注入 DSH profile 的 patch 层。
#
# 为什么需要它：出厂 `cordis.patch.yml` 的挂载行默认 `disabled: true` 且不含机器绝对路径。
# 挂载行是静态的，DSH 树是每台机器各自的（`$DSH_HOME` 决定 boot 哪棵）——出厂写死
# 一台机器的 command/cwd，换机器就指向不存在的文件，而 `failOnStartupError: true`
# 会让 MCP 握手失败**直接中止整个 profile 启动**。本脚本把「路径」这件事挪到**安装期**，
# 在目标树上算一次、写一次，于是出厂产物保持零机器依赖。
#
# 它写什么：`<DSH_HOME>/profiles/<profile>/cordis.patch.yml` 里的一个**标记块**，
# 内容是 **id 定向覆盖行**（DSH patch 语义：id 命中即逐字段 `target[key] = value`，
# 故覆盖行重述整个 `config`）：
#
#   - id: mcp-harness-evolution
#     disabled: false
#     config:
#       transport: stdio
#       serverName: harness-evolution
#       command: '<profile>/node_modules/@across2005/harness-self-evolution/bin/harness-evolution.exe'
#       args: []
#       cwd:     '<profile>/node_modules/@across2005/harness-self-evolution'
#       env:
#         DSH_HOME: '<DSH_HOME>'
#       failOnStartupError: true
#
# 为什么是「标记块 + 文本替换」而不是 YAML 解析/重排：PowerShell 没有内置 YAML 解析器，
# 而标记块天然幂等，且**绝不触碰**该文件里既有的其它行（例如 `mcp-headroom` 的 insert）。
#
# 用法：
#   pwsh -File scripts/install-dsh.ps1 -Profile web                    # 默认 $env:DSH_HOME，否则 ~/.dsh
#   pwsh -File scripts/install-dsh.ps1 -Profile web -DshHome 'C:/Users/me/.minimax/.../dsh-home'
#   pwsh -File scripts/install-dsh.ps1 -Profile web -DryRun            # 只打印将写入的内容
#   pwsh -File scripts/install-dsh.ps1 -Profile web -SkipPluginAdd     # 已装好，只写 patch
#   pwsh -File scripts/install-dsh.ps1 -Profile web -Uninstall         # 只删标记块
#   pwsh -File scripts/install-dsh.ps1 -Profile web -Verify            # 顺带跑 --dump-config 自检
#
# `dsh` 不在 PATH 时用 -DshCommand 指定（例如：
#   -DshCommand 'node C:/Users/me/.minimax/v2/plugin-data/local-minimax/dsh/runtime/node_modules/@deepseek-ai/dsh/lib/bin.js'）
#
# 生效时机：`dsh.profile.bundles` 与 patch 层都在 **boot** 时读取 —— 写完必须**重启宿主**，
# 会话里才会出现 14 个 `mcp__harness-evolution__*` 工具。

[CmdletBinding()]
param(
  [string]$Profile = 'web',
  [string]$DshHome,
  [string]$DshCommand = 'dsh',
  [string]$RepoRoot,
  [switch]$DryRun,
  [switch]$Uninstall,
  [switch]$SkipPluginAdd,
  [switch]$Verify
)

$ErrorActionPreference = 'Stop'

$PackageName = '@across2005/harness-self-evolution'
$MarkerOpen  = '# >>> mcp-harness-evolution (install-dsh.ps1) >>>'
$MarkerClose = '# <<< mcp-harness-evolution (install-dsh.ps1) <<<'

# ---- 工具函数 ---------------------------------------------------------------

# 归一化为 `C:/x/y` 形态（反斜杠 → 斜杠，去尾斜杠），并展开 `~`。
function Resolve-AbsPath([string]$raw, [string]$label) {
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  $v = $raw.Trim()
  if ($v -eq '~') { $v = $HOME }
  elseif ($v -match '^[~][\\/]') { $v = Join-Path $HOME $v.Substring(2) }
  $v = $v -replace '\\', '/'
  if ($v -notmatch '^(/|[A-Za-z]:/)') {
    throw "$label must be an absolute path (got '$raw'). A relative value is ignored by the plugin (its cwd is not the host's), so the row would look configured while definitions still land elsewhere."
  }
  $abs = $v.TrimEnd('/')
  if ($abs -match '^[A-Za-z]:$') { $abs = "$abs/" }   # 保留 `C:/` 这种根写法
  $abs
}

# YAML 单引号字符串：内部的 `'` 需写成 `''`。
function Quote-Yaml([string]$s) { "'" + ($s -replace "'", "''") + "'" }

# 该文件去掉标记块与注释行后，是否还有实质内容（决定「追加」还是「直接写」）。
function Test-HasRealContent([string]$text) {
  foreach ($line in ($text -split "`r?`n")) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    if ($t -eq '[]') { continue }   # 空 profile 模板
    return $true
  }
  return $false
}

function Invoke-Dsh([string[]]$DshArgs) {
  $parts = @($DshCommand -split '\s+' | Where-Object { $_ -ne '' })
  $exe = $parts[0]
  $pre = @()
  if ($parts.Length -gt 1) { $pre = $parts[1..($parts.Length - 1)] }
  Write-Host "  > $DshCommand $($DshArgs -join ' ')" -ForegroundColor DarkGray
  & $exe @pre @DshArgs
  if ($LASTEXITCODE -ne 0) {
    throw "'$DshCommand $($DshArgs -join ' ')' exited with $LASTEXITCODE."
  }
}

# ---- 1. 仓库与树 ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}
if (-not (Test-Path (Join-Path $RepoRoot 'package.json'))) {
  throw "not a plugin checkout: $RepoRoot has no package.json (pass -RepoRoot)."
}
if (-not (Test-Path (Join-Path $RepoRoot 'cordis.patch.yml'))) {
  throw "not a plugin checkout: $RepoRoot has no cordis.patch.yml (pass -RepoRoot)."
}
$RepoRoot = (Resolve-Path $RepoRoot).Path -replace '\\', '/'

# DSH home 解析顺序与宿主一致：显式参数 > $env:DSH_HOME（trim 后非空）> ~/.dsh
$homeSource = '-DshHome'
$rawHome = $DshHome
if ([string]::IsNullOrWhiteSpace($rawHome)) {
  if (-not [string]::IsNullOrWhiteSpace($env:DSH_HOME)) {
    $rawHome = $env:DSH_HOME
    $homeSource = '$env:DSH_HOME'
  } else {
    $rawHome = Join-Path $HOME '.dsh'
    $homeSource = '~/.dsh (default)'
  }
}
$DshHomeAbs = Resolve-AbsPath $rawHome 'DSH home'
$profileDir = "$DshHomeAbs/profiles/$Profile"
$patchPath = "$profileDir/cordis.patch.yml"

Write-Host "install-dsh.ps1" -ForegroundColor Cyan
Write-Host "  repo        : $RepoRoot"
Write-Host "  dsh home    : $DshHomeAbs   (from $homeSource)"
Write-Host "  profile dir : $profileDir"
Write-Host "  patch layer : $patchPath"

# ---- 2. 卸载 / 纯打印 -------------------------------------------------------

$existing = if (Test-Path $patchPath) { Get-Content -Path $patchPath -Encoding UTF8 -Raw } else { $null }
$blockPattern = "(?ms)^" + [regex]::Escape($MarkerOpen) + ".*?^" + [regex]::Escape($MarkerClose) + "\r?\n?"

if ($Uninstall) {
  if ($null -eq $existing) { Write-Host "no-op: $patchPath does not exist" -ForegroundColor DarkGray; return }
  if ($existing -notmatch [regex]::Escape($MarkerOpen)) {
    Write-Host "no-op: no install-dsh.ps1 block in $patchPath" -ForegroundColor DarkGray
    return
  }
  $stripped = [regex]::Replace($existing, $blockPattern, '')
  $stripped = $stripped.TrimEnd() + "`n"
  if ($DryRun) { Write-Host "`n[dry-run] would remove the block; result:`n$stripped" -ForegroundColor Yellow; return }
  [IO.File]::WriteAllText($patchPath, $stripped, [Text.UTF8Encoding]::new($false))
  Write-Host "removed the mount block from $patchPath" -ForegroundColor Green
  Write-Host "restart the host for the change to take effect." -ForegroundColor Cyan
  return
}

# ---- 3. 确保包已装入该树 ----------------------------------------------------

if (-not $SkipPluginAdd) {
  if ($DryRun) {
    Write-Host "`n[dry-run] would run: $DshCommand plugin --profile $Profile add $RepoRoot" -ForegroundColor Yellow
  } else {
    Write-Host "`n[1/2] dsh plugin add" -ForegroundColor Cyan
    Invoke-Dsh @('plugin', '--profile', $Profile, 'add', $RepoRoot)
  }
}

if (-not (Test-Path $profileDir)) {
  throw "profile dir not found: $profileDir. Is '$DshHomeAbs' the tree your host boots, and does profile '$Profile' exist?"
}

$installedDir = "$profileDir/node_modules/$PackageName"
$exePath = "$installedDir/bin/harness-evolution.exe"
if (-not (Test-Path $installedDir)) {
  throw "installed package not found: $installedDir. Run '$DshCommand plugin --profile $Profile add $RepoRoot' (or drop -SkipPluginAdd), then retry."
}
if (-not $DryRun -and -not (Test-Path $exePath)) {
  throw "binary not found: $exePath. Build it first: .\build.ps1 -Task build"
}

# ---- 4. 写覆盖行（标记块，幂等） --------------------------------------------

$block = @(
  $MarkerOpen
  "- id: mcp-harness-evolution"
  "  disabled: false"
  "  config:"
  "    transport: stdio"
  "    serverName: harness-evolution"
  "    command: $(Quote-Yaml $exePath)"
  "    args: []"
  "    cwd: $(Quote-Yaml $installedDir)"
  "    env:"
  "      DSH_HOME: $(Quote-Yaml $DshHomeAbs)"
  "    failOnStartupError: true"
  $MarkerClose
) -join "`n"

if ($null -eq $existing) {
  $newContent = "# Your patch layer for this dsh profile, applied after every bundle layer:`n" +
                "# a top-level YAML array of loader patch entries.`n`n" + $block + "`n"
} elseif ($existing -match [regex]::Escape($MarkerOpen)) {
  $newContent = [regex]::Replace($existing, $blockPattern, ($block -replace '\$', '$$') + "`n")
} elseif (Test-HasRealContent $existing) {
  $newContent = $existing.TrimEnd() + "`n`n" + $block + "`n"
} else {
  $newContent = $existing.TrimEnd() + "`n" + $block + "`n"
}

Write-Host "`n[2/2] mount row" -ForegroundColor Cyan
if ($DryRun) {
  Write-Host "[dry-run] would write to $patchPath :" -ForegroundColor Yellow
  Write-Host $block
  return
}

if ($newContent -ceq $existing) {
  Write-Host "no-op: $patchPath already carries this exact block" -ForegroundColor DarkGray
} else {
  [IO.File]::WriteAllText($patchPath, $newContent, [Text.UTF8Encoding]::new($false))
  Write-Host "wrote the mount row into $patchPath" -ForegroundColor Green
}

# ---- 5. 自检 ----------------------------------------------------------------

Write-Host "`nverify (static, no boot needed):" -ForegroundColor Cyan
Write-Host "  $DshCommand --profile $Profile --dump-config | Select-String 'mcp-harness-evolution'"
Write-Host "  expect: the row is present, disabled: false, command/cwd point at $installedDir"
Write-Host "`nverify (live, after restarting the host):" -ForegroundColor Cyan
Write-Host "  get_runtime_snapshot                                   # root + data_gaps"
Write-Host "  create_sub_agent scope=user name=evo-smoke-test ...    # must land in $DshHomeAbs/skills/"
Write-Host "  delete_sub_agent scope=user name=evo-smoke-test"
Write-Host "`nrestart the host: dsh.profile.bundles and patch layers are read at boot." -ForegroundColor Yellow

if ($Verify) {
  Write-Host "`n[dump-config]" -ForegroundColor Cyan
  Invoke-Dsh @('--profile', $Profile, '--dump-config')
}
