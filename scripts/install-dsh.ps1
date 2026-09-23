# scripts/install-dsh.ps1
# ★ v3.1 安装入口：把 MCP 挂载行**按目标树**注入 DSH profile 的 patch 层。
#
# ══════════════════════════════════════════════════════════════════════════════
# 兼容性要点（哪些代码为什么重要）—— 修改本脚本前请先读完这一节
# ══════════════════════════════════════════════════════════════════════════════
#
# 【A】为什么需要它：出厂 `cordis.patch.yml` 的挂载行默认 `disabled: true` 且不含机器
# 绝对路径。挂载行是静态的，DSH 树是每台机器各自的（`$DSH_HOME` 决定 boot 哪棵）——
# 出厂写死一台机器的 command/cwd，换机器就指向不存在的文件。本脚本把「路径」这件事
# 挪到**安装期**，在目标树上算一次、写一次，于是出厂产物保持零机器依赖。
#
# 【B】什么才是真正「致命」的（★ 2026-09-22 复验修正的文档缺陷）：
# 曾经这里写着「握手失败会直接中止整个 profile 启动」。**那是过度声明**。宿主真实语义
# （`dsh-app-boot/lib/index.js`，0.1.6-alpha.1）：
#
#     const requiredStartupEntryIds = new Set([
#       "agent-loop","webserver","modules","connection",
#       "headless-runner","acp","sdk-jsonrpc-server" ]);        // :2408-2416
#     for (const failure of failures)
#       (failure.entry === bootstrapIncludes.get(ctx)
#        || requiredStartupEntryIds.has(failure.entry.options.id)
#          ? required : optional).push(failure);               // :2513
#     if (optional.length > 0) warn(...);                       // :2514  ← 只打一行 warning
#     if (required.length > 0) throw ...;                       // :2515
#
# `mcp-harness-evolution` **不在** required 名单里 → 该行激活失败只归入 optional →
# 一行 warning，**其余条目照常运行**。所以：
#   · 路径写错 = 该插件不挂载 + 一行 warning（可观测、可恢复）；
#   · **真正会打挂整个 profile 的是 patch 层 YAML 解析失败** —— `parsePatchList` 是
#     `throw`（:2158-2163），异常一路上抛到 `prepareProfile`，profile **完全无法 boot**。
# 本脚本写的就是那个文件，所以「产出合法 YAML」是本脚本**最高优先级的不变量**，
# 而 §【D】那个分支正是这条不变量的唯一历史破口。改动此处务必跑
# `scripts/test-install-dsh.ps1`（回归测试）与 `-Verify`。
#
# 【C】为什么 `disabled: true` + 安装期启用的结论仍然成立：理由不是「否则拖挂宿主」，
# 而是「静态字面量必然只对一棵树成立，装错树 = 插件静默不工作」。把易变的那一维
# （路径）从出厂产物里挪到安装期，是「可复现产物 + 每机部署」的正确切分。
#
# 【D】为什么本脚本是「标记块 + 文本替换」而不是 YAML 解析/重排：PowerShell 没有内置
# YAML 解析器，而标记块天然幂等，且**绝不触碰**该文件里既有的其它行（例如
# `mcp-headroom` 的 insert）。
#
#     ★ 历史阻塞缺陷（2026-09-22 复验，已修）：DSH 为每个新 profile 生成的出厂 patch
#     层模板逐字是「两行注释 + 一行 `[]`」（`PROFILE_PATCH_TEMPLATE`，
#     dsh-app-boot/lib/index.js:480-484）。`[]` 是 **flow 序列**，YAML **不允许**在同一
#     层级上让 flow 序列后接块序列项。旧代码把 `[]` 视同「空文件」而**在其后追加**块，
#     产出 `[]` + `- id: …`，宿主 `--dump-config` / boot 直接：
#         YAMLException: end of the stream or a document separator is expected (6:1)
#     这恰好命中「新 profile 的默认状态」。修法见 §4 的 `$existing` 归一化：
#     **整行替换 `[]`，而不是追加**。
#
# 【E】「先读后写」的顺序是安全的（复验附带观察的结论，已核实源码）：本脚本在第 2 节
# 读取 patch 层、第 3 节才跑 `dsh plugin add`。核实结论是**没有陈旧内容风险**，因为
# `dsh plugin add` 只经 `writeProfileManifest(profileDir, after)` 改写 profile 的
# `package.json`（`dsh.profile.bundles` / `dependencies`），**从不触碰 `cordis.patch.yml`**
# （`@deepseek-ai/dsh/lib/plugin-*.js` 只 import 了 readProfileManifest /
# writeProfileManifest；`initProfile` 仅在文件**不存在**时创建 patch 层）。
# 故保持「先读后写」；若未来宿主改为在 `plugin add` 里改写 patch 层，第 4 节会在写前
# 重新 `Get-Content` 一次（那里已留了说明）。
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
#
# ⚠ 这里**故意不把 `[]` 视为「无内容」**。历史缺陷正是这个 `if ($t -eq '[]') { continue }`：
# 它让调用方以为「文件是空的，直接追加就行」，于是把块序列项追加到 flow 序列 `[]` 之后，
# 产出宿主无法解析的 YAML（详见文件头 §【D】）。正确做法是：`[]` 是**必须被整行替换**的
# 占位符，而不是可以忽略的噪声 —— 判据是「除了注释与空行，还剩什么」。
function Test-HasRealContent([string]$text) {
  foreach ($line in ($text -split "`r?`n")) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    return $true
  }
  return $false
}

# 把 profile patch 层归一化成「可以安全追加块序列项」的形态。
#
# 宿主为每个新 profile 生成的出厂模板逐字是（`PROFILE_PATCH_TEMPLATE`，
# dsh-app-boot/lib/index.js:480-484）：
#
#     # Your patch layer for this dsh profile, applied after every bundle layer:
#     # a top-level YAML array of loader patch entries (id-targeted config
#     # overrides, disables, and insert lists; `!!js` expressions allowed).
#     []
#
# 其中 `[]` 是**空 flow 序列**，代表「这一层目前有零条 patch」。要在这一层里加一条
# **块序列项**（`- id: …`），必须**删掉 `[]`**：YAML 不允许同一层级上 flow 序列后接
# 块序列项。只删这一个 token（连同它所在整行），注释与其它内容原样保留。
#
# 为什么不干脆「没有 `[]` 就整文件重写」：那会丢掉用户自己写的注释（模板注释、或用户
# 手写的说明）。最小改动 = 只动那一个 token，是本脚本「绝不触碰既有其它行」原则的延续。
function Remove-EmptyFlowSequence([string]$text) {
  # `(?m)` 逐行匹配；`[ \t]*` 容忍缩进与行尾空白；`\r?\n?` 兼容 CRLF/LF 与「文件末尾无换行」。
  return [regex]::Replace($text, '(?m)^[ \t]*\[\][ \t]*\r?\n?', '')
}

# 写盘前的最后一道守卫：patch 层**必须**是宿主能解析的形态。
#
# 为什么值得在这里再查一遍：`parsePatchList` 是 throw，写坏这一个文件 = profile 完全
# 无法 boot（见文件头 §【B】）。这里只做**结构性**检查（不引 YAML 解析器，PowerShell 没有），
# 覆盖历史缺陷的确切形状：`[]` 与块序列项共存、或块序列项缺失。真正的解析验证由
# `scripts/test-install-dsh.ps1`（用宿主的 js-yaml）完成。
#
# ⚠ 实现提示（一次真实的踩坑）：判「裸 `[]`」必须**逐行**比，不能用
# `-match '(?m)^[ \t]*\[\][ \t]*$'`。PowerShell 的 `-match` 里 `$` 会匹配**输入末尾**，
# 而本文件恒以换行结尾 —— 于是 `(?m)$` 在末尾的空位置上恒成立，前两段全空也能匹配，
# 守卫会对**每一个**合法产物误报（`Assert` 变 `Reject`，比没有守卫更糟）。
# 逐行 `Trim()` 比较没有这个歧义。
function Test-HasBareFlowSequence([string]$text) {
  foreach ($line in ($text -split "`r?`n")) {
    if ($line.Trim() -eq '[]') { return $true }
  }
  return $false
}

function Assert-PatchLayerShape([string]$text, [string]$path) {
  # ① `[]` 必须已被替换掉 —— 否则块序列项就接在 flow 序列后面（历史缺陷的确切形状）
  if (Test-HasBareFlowSequence $text) {
    throw "refusing to write $path : it still carries a bare '[]' flow sequence, so the appended block sequence would be invalid YAML. This is the 2026-09-22 regression; please report it."
  }
  # ② 本脚本的标记块必须完整（开标记 + 覆盖行 + 闭标记）
  if ($text -notmatch [regex]::Escape($MarkerOpen) -or
      $text -notmatch [regex]::Escape($MarkerClose) -or
      $text -notmatch '(?m)^- id: mcp-harness-evolution[ \t]*$') {
    throw "refusing to write $path : the mount block is incomplete (open marker, '- id: mcp-harness-evolution' row, and close marker are all required)."
  }
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
  # 复原到「出厂空模板」形态：删块后若只剩注释/空行，补回 `[]` 占位符。
  #
  # 为什么值得补：`[]` 是宿主 `PROFILE_PATCH_TEMPLATE` 表达「这一层有零条 patch」的写法，
  # 也是**合法** YAML（一个只有注释的文件同样合法）。补回去是为了让 `-Uninstall` 之后的
  # 文件与「从未装过」的状态**逐字一致** —— 卸载应当是可逆的，而不是留下一个形状不同、
  # 让下一个读文件的人（或脚本）需要额外判断的状态。
  #
  # 若卸载后仍有真实条目（用户自己的 patch），绝不加 `[]`：那才是非法的
  # 「flow 序列后接块序列项」（见文件头 §【D】）。
  if (-not (Test-HasRealContent $stripped)) {
    $stripped = $stripped.TrimEnd() + "`n[]`n"
  }
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

# ══════════════════════════════════════════════════════════════════════════════
# 四条分支，覆盖 patch 层全部现状（复验已实测收窄边界，见文件头 §【D】）
#
# ★ 分支**顺序即正确性**，别重排。要点：出厂空模板的 `[]` 是一行**真实内容**
#   （`Test-HasRealContent` 对它返回 `$true`），所以它天然落进「有内容 → 追加」那一支；
#   必须**先**把这一行归一化掉，再判「追加还是新建」。顺序写反 = 复现 2026-09-22 那个
#   阻塞缺陷（`[]` 后接块序列项 → 宿主 `parsePatchList` throw → profile 无法 boot）。
#
#   1. 文件不存在          → 模板注释 + 块                     ✅
#   2. 已含本脚本标记块    → 就地替换块（幂等）                 ✅
#   3. 归一化 `[]` 后再判：
#        · 已含其它条目（如 mcp-headroom 的 insert）→ 追加块     ✅
#        · 只剩注释/空行                            → 直接接块   ✅ ← 历史破口在此修复
# ══════════════════════════════════════════════════════════════════════════════
if ($null -eq $existing) {
  $newContent = "# Your patch layer for this dsh profile, applied after every bundle layer:`n" +
                "# a top-level YAML array of loader patch entries.`n`n" + $block + "`n"
} elseif ($existing -match [regex]::Escape($MarkerOpen)) {
  $newContent = [regex]::Replace($existing, $blockPattern, ($block -replace '\$', '$$') + "`n")
} else {
  # 先归一化：删掉占位的 `[]`。它是 flow 序列，后面不能再接块序列项（见文件头 §【D】）。
  # 注释与其它内容原样保留 —— 最小改动，绝不重排用户自己的文件。
  $normalized = Remove-EmptyFlowSequence $existing
  if (Test-HasRealContent $normalized) {
    # 已有真实 patch 条目（例如 `mcp-headroom` 的 insert）：保留原样，空一行后追加本块。
    $newContent = $normalized.TrimEnd() + "`n`n" + $block + "`n"
  } else {
    # 只剩注释/空行的「出厂空模板」形态：直接接上本块。
    $newContent = $normalized.TrimEnd() + "`n" + $block + "`n"
  }
}

# 写前守卫：宁可在这里 throw（安装失败、用户树保持原状），也不要写出让宿主无法 boot 的
# patch 层。守卫只做结构检查，真正的 YAML 解析验证在 scripts/test-install-dsh.ps1。
Assert-PatchLayerShape $newContent $patchPath

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
