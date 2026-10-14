$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$msi = 'C:\Windows\Temp\CloudbaseInitSetup.msi'
(New-Object Net.WebClient).DownloadFile($env:CBI_URL, $msi)

$p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$msi`" /qn /norestart /l*v C:\Windows\Temp\cbi.log USERNAME=Administrator LOGGINGSERIALPORTNAME=COM1"
if (@(0, 3010) -notcontains $p.ExitCode) { throw "Cloudbase-Init MSI exit code: $($p.ExitCode)" }

$cbi  = Join-Path $env:ProgramFiles 'Cloudbase Solutions\Cloudbase-Init'
$conf = Join-Path $cbi 'conf'
if (-not (Test-Path "$conf\Unattend.xml")) { throw "Not found: $conf\Unattend.xml" }

# Our config: password from metadata (inject_user_password) + SetUserPasswordPlugin
Copy-Item 'C:\Windows\Temp\cloudbase-init.conf' "$conf\cloudbase-init.conf" -Force

Set-Service cloudbase-init -StartupType Automatic
Write-Host "Cloudbase-Init installed: $cbi"
