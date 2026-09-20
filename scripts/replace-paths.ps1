# scripts/replace-paths.ps1
# ★ H7 配套脚本：替换挂载行里的本机绝对路径字面量。
#
# DSH 的 cordis Loader 不解析相对路径、不解析 ${ENV_VAR}（实测 dsh-app-boot/lib/index.js），
# command/cwd 必须是绝对路径字面量。其他仓库路径（fork、CI、迁移机）需用本脚本替换。
#
# 同理 `env.DSH_HOME` 也必须是绝对路径字面量：宿主 spawn MCP 子进程时用
# `scrubbedParentEnv()` 丢弃**全部** `DSH_*`（@deepseek-ai/dsh-subprocess），
# 继承拿不到，只有挂载行里的字面量能在清洗后合并进子进程环境
# （@deepseek-ai/dsh-mcp-client 的 buildChildEnv）。宿主 boot 非默认树时，
# 不填这一项 → 插件的 user 作用域定义会落进宿主不读的另一棵树。
#
# 用法（两种模式各自独立，可单用也可同用）：
#   # ① 换仓库路径（替换 cordis.patch.yml 与 docs/deploy/deepseek-harness.md）
#   pwsh -File scripts/replace-paths.ps1 -OldPath 'D:/Agent设计/harness-self-evolution-plugin' -NewPath 'D:/work/harness-self-evolution-plugin'
#
#   # ② 把挂载行的 DSH_HOME 指向宿主的树（只改 cordis.patch.yml）
#   pwsh -File scripts/replace-paths.ps1 -DshHome 'C:/Users/me/.minimax/v2/plugin-data/local-minimax/dsh/dsh-home'
#   pwsh -File scripts/replace-paths.ps1 -DshHome "$env:DSH_HOME"   # 同上，直接用宿主的变量
#   pwsh -File scripts/replace-paths.ps1 -ResetDshHome             # 复位为默认（插件回落 ~/.dsh）
#
# 复位用 `-ResetDshHome` 而不是 `-DshHome ''`：PowerShell 的 `-File` 参数传递会吃掉落空的
# 字符串实参（报「参数 'DshHome' 缺少自变量」），所以空值走独立开关。
#
# -DshHome 必须是**绝对**路径：相对值会被插件忽略（它无法与宿主 cwd 同源），
# 于是挂载行看着配好了、定义却仍写进 `~/.dsh` —— 故本脚本直接拒绝而非默默写入。
#
# 只改这两个文件：
#   - cordis.patch.yml（仓库路径 + DSH_HOME）
#   - docs/deploy/deepseek-harness.md（仓库路径；文档里的挂载行是模板，DSH_HOME 保留空值示例）
# 同一仓库 grep "D:/Agent设计/harness-self-evolution-plugin" 应仅在叙述性文档与脚本内示例中命中。

[CmdletBinding()]
param(
  [string]$OldPath,
  [string]$NewPath,
  [string]$DshHome,
  [switch]$ResetDshHome
)

$ErrorActionPreference = 'Stop'

$hasOld = -not [string]::IsNullOrEmpty($OldPath)
$hasNew = -not [string]::IsNullOrEmpty($NewPath)
# `-DshHome` 与 `-ResetDshHome` 互斥；空串只在真的传进来时才算「复位」
#（`-File` 会吃掉空实参，故命令行复位请用 -ResetDshHome）。
$hasDsh = $PSBoundParameters.ContainsKey('DshHome') -and -not [string]::IsNullOrEmpty($DshHome)
$reset = [bool]$ResetDshHome

if ($hasDsh -and $reset) {
  throw 'pass either -DshHome or -ResetDshHome, not both.'
}
if ($hasOld -ne $hasNew) {
  throw '-OldPath and -NewPath must be passed together (or neither).'
}
if (-not $hasOld -and -not $hasDsh -and -not $reset) {
  throw 'nothing to do: pass -OldPath/-NewPath, and/or -DshHome / -ResetDshHome.'
}

$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

# 相对/盘符相对路径一律拒绝 —— 插件只接受绝对路径（见 store/paths.mbt::dsh_home）。
function Get-NormalizedDshHome([string]$raw) {
  $norm = $raw.Trim() -replace '\\', '/'
  if ($norm -notmatch '^(/|[A-Za-z]:/)') {
    throw "-DshHome must be an absolute path (got '$raw'); a relative value would be ignored by the plugin, leaving the mount row looking configured while definitions still land in ~/.dsh."
  }
  $abs = $norm.TrimEnd('/')
  if ($abs -match '^[A-Za-z]:$') { $abs = "$abs/" }   # 保留 `C:/` 这种根写法
  $abs
}

# ---- 模式 ①：仓库路径 -------------------------------------------------------
if ($hasOld) {
  $targets = @(
    'cordis.patch.yml',
    'docs/deploy/deepseek-harness.md'
  )
  foreach ($rel in $targets) {
    $abs = Join-Path $root $rel
    if (-not (Test-Path $abs)) {
      Write-Warning "skip (missing): $rel"
      continue
    }
    $content = Get-Content -Path $abs -Encoding UTF8 -Raw
    $count = ([regex]::Matches($content, [regex]::Escape($OldPath))).Count
    if ($count -eq 0) {
      Write-Host "no-op: $rel (0 occurrences)" -ForegroundColor DarkGray
      continue
    }
    $new = $content -replace [regex]::Escape($OldPath), $NewPath
    [IO.File]::WriteAllText($abs, $new, [Text.UTF8Encoding]::new($false))
    Write-Host "patched: $rel ($count occurrences)" -ForegroundColor Green
  }
}

# ---- 模式 ②：挂载行的 DSH_HOME ---------------------------------------------
if ($hasDsh -or $reset) {
  $rel = 'cordis.patch.yml'
  $abs = Join-Path $root $rel
  if (-not (Test-Path $abs)) {
    throw "missing $rel; run this from a checkout of the plugin repo."
  }
  $value = if ($reset) { '' } else { Get-NormalizedDshHome $DshHome }
  $content = Get-Content -Path $abs -Encoding UTF8 -Raw
  $pattern = '(?m)^(\s*DSH_HOME:\s*).*$'
  $hits = [regex]::Matches($content, $pattern)
  if ($hits.Count -eq 0) {
    throw "no DSH_HOME line in $rel; add one under the mount row's env (see that file's comment) and retry."
  }
  if ($hits.Count -gt 1) {
    throw "expected exactly one DSH_HOME line in $rel, found $($hits.Count)."
  }
  # 替换串里的 `$` 要转义，避免被 .NET 当成组引用
  $replacement = '${1}' + "'" + ($value -replace '\$', '$$') + "'"
  $new = [regex]::Replace($content, $pattern, $replacement)
  if ($new -ceq $content) {
    Write-Host "no-op: $rel (DSH_HOME already '$value')" -ForegroundColor DarkGray
  } else {
    [IO.File]::WriteAllText($abs, $new, [Text.UTF8Encoding]::new($false))
    if ($value -eq '') {
      Write-Host "patched: $rel (DSH_HOME reset to '' -> plugin falls back to ~/.dsh)" -ForegroundColor Green
    } else {
      Write-Host "patched: $rel (DSH_HOME -> '$value')" -ForegroundColor Green
    }
  }
}

Write-Host ''
Write-Host 'verify with: git diff -- cordis.patch.yml docs/deploy/deepseek-harness.md' -ForegroundColor Cyan
Write-Host 'then confirm the host really resolves that home: dsh --profile web --dump-config (with the same DSH_HOME)' -ForegroundColor Cyan