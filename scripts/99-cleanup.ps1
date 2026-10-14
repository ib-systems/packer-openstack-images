$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Stop-Service wuauserv -ErrorAction SilentlyContinue
Remove-Item 'C:\Windows\SoftwareDistribution\Download\*' -Recurse -Force -ErrorAction SilentlyContinue
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

wevtutil el | ForEach-Object { wevtutil cl $_ 2>$null }

# Zero free space to keep the qcow2 image compact
try {
  $sd = 'C:\Windows\Temp\sdelete64.exe'
  (New-Object Net.WebClient).DownloadFile('https://live.sysinternals.com/sdelete64.exe', $sd)
  & $sd -accepteula -z C:
} catch { Write-Host "sdelete skipped: $_" }
exit 0
