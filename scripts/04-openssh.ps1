# OpenSSH Server: starts at boot, PowerShell as the login shell, port 22 open. Not started here: its host
# keys are made on the first start, on the server, so servers do not share them. Authorized keys come from
# minibar's user-data (administrators_authorized_keys: sshd reads that file for members of Administrators).
$ErrorActionPreference = 'Stop'

$cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1
if ($cap -and $cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name $cap.Name | Out-Null }
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) { throw 'sshd is not installed' }
Set-Service sshd -StartupType Automatic

New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -PropertyType String -Force `
  -Value "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" | Out-Null

if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True `
    -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}
Remove-Item "$env:ProgramData\ssh\ssh_host_*" -Force -ErrorAction SilentlyContinue
Write-Host 'OpenSSH Server: automatic start, PowerShell shell, port 22'
