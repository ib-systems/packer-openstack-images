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

# Disable the shutdown reason prompt and prevent Server Manager from opening at logon
New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability' -Name ShutdownReasonOn -Value 0 -Type DWord
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability' -Name ShutdownReasonUI -Value 0 -Type DWord
New-Item 'HKLM:\SOFTWARE\Microsoft\ServerManager' -Force | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\ServerManager' -Name DoNotOpenServerManagerAtLogon -Value 1 -Type DWord

# Strong .NET cryptography (TLS 1.2) - important
foreach ($p in 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319','HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319') {
  New-Item $p -Force | Out-Null
  Set-ItemProperty $p -Name SchUseStrongCrypto -Value 1 -Type DWord
}
