$ErrorActionPreference = 'Continue'
$env:GIT_TERMINAL_PROMPT = '0'

# Token extraction
$credPath = Join-Path $HOME '.git-credentials'
$raw = Get-Content $credPath -Encoding UTF8
$lines = @()
foreach ($l in $raw) {
  $clean = $l.TrimEnd("`r").TrimStart([char]0xFEFF)
  if ($clean -match '^https?://') { $lines += $clean }
}
$ghToken = $null
$glToken = $null
foreach ($l in $lines) {
  $stripped = $l -replace '^https?://', ''
  $parts = $stripped -split '@', 2
  if ($parts.Count -lt 2) { continue }
  $userpass = $parts[0] -split ':', 2
  if ($userpass.Count -lt 2) { continue }
  $tok = $userpass[1]
  $hst = $parts[1]
  if ($hst -eq 'github.com' -and -not $ghToken) { $ghToken = $tok }
  if ($hst -eq 'gitlink.org.cn' -and -not $glToken) { $glToken = $tok }
}
Write-Output "GitHub token: $($ghToken.Substring(0,4))...$($ghToken.Substring($ghToken.Length-4))"
Write-Output "GitLink token: $($glToken.Substring(0,4))...$($glToken.Substring($glToken.Length-4))"

# GitHub push with retry
$ghUrl = "https://Across2005:${ghToken}@github.com/Across2005/harness-self-evolution-plugin.git"
Write-Output ''
Write-Output '=== Pushing to GitHub ==='
$ghOk = $false
for ($i = 1; $i -le 5; $i++) {
  Write-Output "Attempt $i..."
  $out = git -c credential.helper= push $ghUrl 'moonbit-port:main' 2>&1 | Out-String
  if ($LASTEXITCODE -eq 0) {
    Write-Output "OK on attempt $i"
    Write-Output $out
    $ghOk = $true
    break
  }
  Write-Output "Failed: $out"
  if ($i -lt 5) { Start-Sleep -Seconds 5 }
}
if (-not $ghOk) { throw 'GitHub push failed after 5 attempts' }

# GitLink push
$glUrl = "https://Across2005:${glToken}@gitlink.org.cn/Across2005/harness-self-evolution-plugin.git"
Write-Output ''
Write-Output '=== Pushing to GitLink ==='
$out = git -c credential.helper= push $glUrl 'moonbit-port:master' 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
  Write-Output "Failed: $out"
  throw 'GitLink push failed'
}
Write-Output 'OK'
Write-Output $out

# Verify
Write-Output ''
Write-Output '=== Verify ==='
Write-Output 'origin/main:'
git ls-remote origin main 2>$null | Select-Object -First 1
Write-Output 'gitlink/master:'
git ls-remote https://Across2005:${glToken}@gitlink.org.cn/Across2005/harness-self-evolution-plugin.git master 2>$null | Select-Object -First 1
Write-Output "local HEAD: $(git rev-parse HEAD)"

$env:GIT_TERMINAL_PROMPT = $null
