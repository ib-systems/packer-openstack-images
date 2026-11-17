# Setup places a Recovery (WinRE) partition after C:. It would stop cloudbase-init from extending C:
# to the whole disk on the server: WinRE goes back into C: (reagentc /disable), the partition is
# removed and C: takes its space (same approach as rgl/windows-vagrant's remove-recovery-partition.ps1).
$ErrorActionPreference = 'Stop'

reagentc /disable | Out-Host
if (@(0, 2) -notcontains $LASTEXITCODE) { throw "reagentc /disable: exit $LASTEXITCODE" } # 2: already disabled

Get-Partition | Where-Object { $_.Type -eq 'Recovery' } | ForEach-Object {
  Write-Host "recovery: removing partition $($_.PartitionNumber) ($([math]::Round($_.Size / 1MB)) MB)"
  $_ | Remove-Partition -Confirm:$false
}

$max = (Get-PartitionSupportedSize -DriveLetter C).SizeMax
$max -= $max % 1MB
if ((Get-Partition -DriveLetter C).Size -lt $max) { Resize-Partition -DriveLetter C -Size $max }
Get-Partition | Format-Table PartitionNumber, Type, Size -AutoSize | Out-Host
