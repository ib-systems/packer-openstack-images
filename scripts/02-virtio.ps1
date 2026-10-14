$ErrorActionPreference = 'Stop'

$vol = Get-WmiObject Win32_Volume | Where-Object { $_.Label -like 'virtio-win*' } | Select-Object -First 1
if (-not $vol) { throw "VirtIO ISO not found (volume label virtio-win*)" }
$root = $vol.DriveLetter + '\'
Write-Host "VirtIO ISO: $($vol.Label) on $root"

function Install-Msi($path, $log) {
  $p = Start-Process msiexec.exe -ArgumentList "/i `"$path`" /qn /norestart /l*v `"C:\Windows\Temp\$log`"" -Wait -PassThru
  if (@(0, 3010) -notcontains $p.ExitCode) { throw "$path exited with code $($p.ExitCode)" }
}

# Install all drivers (viostor, vioscsi, NetKVM, Balloon, vioserial, vioinput, viorng, pvpanic, ...)
Install-Msi "${root}virtio-win-gt-x64.msi" 'virtio-gt.log'

# QEMU Guest Agent
Install-Msi "${root}guest-agent\qemu-ga-x86_64.msi" 'qemu-ga.log'

# Validation: viostor must be boot-start; otherwise the image will not boot on virtio-blk
$svc = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\viostor' -ErrorAction SilentlyContinue
if (-not $svc -or $svc.Start -ne 0) { throw "viostor is not registered as BOOT_START (Start=$($svc.Start))" }

Get-WmiObject Win32_PnPSignedDriver |
  Where-Object { $_.DriverProviderName -match 'Red Hat' } |
  Select-Object DeviceName, DriverVersion | Format-Table -AutoSize | Out-String | Write-Host
