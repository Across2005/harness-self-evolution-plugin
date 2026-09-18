# scripts/replace-paths.ps1
# ★ H7 配套脚本：替换 cordis.patch.yml 里的本机绝对路径字面量。
#
# DSH 的 cordis Loader 不解析相对路径、不解析 ${ENV_VAR}（实测 dsh-app-boot/lib/index.js），
# command/cwd 必须是绝对路径字面量。其他仓库路径（fork、CI、迁移机）需用本脚本替换。
#
# 用法：
#   pwsh -File scripts/replace-paths.ps1 -OldPath 'D:/Agent设计/harness-self-evolution-plugin' -NewPath 'D:/work/harness-self-evolution-plugin'
#
# 仅替换两个文件：
#   - cordis.patch.yml
#   - docs/deploy/deepseek-harness.md（overlay 模板内）
# 同一仓库 grep "D:/Agent设计/harness-self-evolution-plugin" 应仅在叙述性文档与脚本内示例中命中。

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$OldPath,
  [Parameter(Mandatory=$true)][string]$NewPath
)

$ErrorActionPreference = 'Stop'

$targets = @(
  'cordis.patch.yml',
  'docs/deploy/deepseek-harness.md'
)

$root = Split-Path -Parent $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

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

Write-Host ''
Write-Host 'verify with: git grep -n "<NewPath>" cordis.patch.yml docs/deploy/deepseek-harness.md' -ForegroundColor Cyan