# Vendor drivers for the fleet (drivers/<component>/*.inf): staged into the driver store, PnP installs
# the matching ones on the server. A storage controller's driver must also start at boot, or Windows
# cannot boot from a disk behind it (INACCESSIBLE_BOOT_DEVICE): every SCSIAdapter driver becomes boot-start.
# A miniport for a controller the server does not have loads and stays idle.
$ErrorActionPreference = 'Stop'

$infs = @(Get-ChildItem 'C:\Windows\Temp\drivers' -Recurse -Filter *.inf -ErrorAction SilentlyContinue)
if (-not $infs) { Write-Host 'drivers: none'; exit 0 }

foreach ($inf in $infs) {
  pnputil /add-driver $inf.FullName | Out-Host
  if ($LASTEXITCODE -notin 0, 259, 3010) { throw "pnputil $($inf.FullName): exit $LASTEXITCODE" }

  $class = (Select-String -Path $inf.FullName -Pattern '^\s*Class\s*=\s*(\w+)' | Select-Object -First 1).Matches.Groups[1].Value
  if ($class -ne 'SCSIAdapter') { continue }
  $svc = (Select-String -Path $inf.FullName -Pattern '^\s*AddService\s*=\s*([\w.-]+)' | Select-Object -First 1).Matches.Groups[1].Value
  if (-not $svc) { throw "drivers: no service in $($inf.FullName)" }

  if (Get-Service $svc -ErrorAction SilentlyContinue) {
    sc.exe config $svc start= boot | Out-Host
  } else {
    $sys = Join-Path $inf.DirectoryName "$svc.sys"
    if (-not (Test-Path $sys)) { throw "drivers: $svc.sys is not next to $($inf.FullName)" }
    Copy-Item $sys "$env:windir\System32\drivers\" -Force
    sc.exe create $svc type= kernel start= boot error= normal group= 'SCSI miniport' binPath= "System32\drivers\$svc.sys" | Out-Host
  }
  if ($LASTEXITCODE -ne 0) { throw "drivers: sc.exe for $svc failed ($LASTEXITCODE)" }
  Write-Host "drivers: $svc starts at boot ($($inf.Name))"
}
