$ErrorActionPreference = 'Continue'
$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$script = 'C:\Users\Admin\Pictures\SatWall\sat-tray.ps1'

# kill every running tray instance
$old = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*sat-tray.ps1*' }
foreach ($p in $old) {
  Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
  Write-Output ('killed ' + $p.ProcessId)
}
Start-Sleep -Seconds 2

# start one fresh instance
Start-Process -FilePath $ps -ArgumentList ('-STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $script + '"') -WindowStyle Hidden
Start-Sleep -Seconds 6

$live = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*sat-tray.ps1*' }
if ($live) { foreach ($p in $live) { Write-Output ('running pid=' + $p.ProcessId) } }
else { Write-Output 'NOT_RUNNING' }
