$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

tzutil /s "UTC"
powercfg /setactive SCHEME_MIN
powercfg /hibernate off

# RDP
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'

# ICMP echo
netsh advfirewall firewall add rule name="ICMPv4 echo in" protocol=icmpv4:8,any dir=in action=allow | Out-Null

# A DWORD value; the key is made only when missing: New-Item -Force on an existing registry key
# deletes it with its subkeys and values (and fails on keys with protected subkeys, e.g. ServerManager).
function Set-RegDword($path, $name, $value) {
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
  Set-ItemProperty -Path $path -Name $name -Value $value -Type DWord
}

# Disable the shutdown reason prompt and prevent Server Manager from opening at logon
Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability' ShutdownReasonOn 0
Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability' ShutdownReasonUI 0
Set-RegDword 'HKLM:\SOFTWARE\Microsoft\ServerManager' DoNotOpenServerManagerAtLogon 1

# Strong .NET cryptography (TLS 1.2) - important
foreach ($p in 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319','HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319') {
  Set-RegDword $p SchUseStrongCrypto 1
}
