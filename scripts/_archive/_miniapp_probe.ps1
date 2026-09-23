$ErrorActionPreference = 'Stop'
$pids = @(43260, 44196, 40252, 34680)
foreach ($x in $pids) {
  $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$x" -ErrorAction SilentlyContinue).CommandLine
  if ($cmd) {
    Write-Output ("PID " + $x + ": " + $cmd.Substring(0, [Math]::Min(220, $cmd.Length)))
  } else {
    Write-Output ("PID " + $x + ": <no cmd>")
  }
}
Write-Output "=== port 18923 raw curl ==="
try {
  $r = Invoke-WebRequest 'http://127.0.0.1:18923/dashboard' -UseBasicParsing -TimeoutSec 8
  Write-Output ("STATUS: " + $r.StatusCode)
  Write-Output ("LEN: " + $r.Content.Length)
} catch {
  Write-Output ("ERR: " + $_.Exception.Message.Split([Environment]::NewLine)[0])
}