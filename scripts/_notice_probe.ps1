$ErrorActionPreference = 'Stop'
$exe = 'D:\Agent设计\harness-self-evolution-plugin\bin\harness-evolution.exe'
$cfg = 'D:\Agent设计\harness-self-evolution-plugin\.dsh-plugin\plugin.json'

foreach ($h in @('deepseek-harness', 'minimax-code', 'zcode')) {
  $env:HARNESS_EVOLUTION_HOST = $h
  Write-Output ("=== HOST=" + $h + " ===")
  # Initialize + immediately close stdin to capture the boot log
  $p = Start-Process -FilePath $exe -ArgumentList @() -RedirectStandardInput -RedirectStandardError 'D:\Agent设计\harness-self-evolution-plugin\_notice_probe_' + $h + '.log' -NoNewWindow -PassThru
  Start-Sleep -Milliseconds 1500
  if (!$p.HasExited) { Stop-Process -Id $p.Id -Force }
}
foreach ($h in @('deepseek-harness', 'minimax-code', 'zcode')) {
  Write-Output ("--- stderr for " + $h + " ---")
  Get-Content 'D:\Agent设计\harness-self-evolution-plugin\_notice_probe_' + $h + '.log' -ErrorAction SilentlyContinue | Select-Object -First 12
}