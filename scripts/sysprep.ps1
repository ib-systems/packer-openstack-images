$ErrorActionPreference = 'Stop'
$cbi = Join-Path $env:ProgramFiles 'Cloudbase Solutions\Cloudbase-Init'
& "$env:windir\System32\Sysprep\sysprep.exe" /generalize /oobe /shutdown /quiet /unattend:"$cbi\conf\Unattend.xml"
