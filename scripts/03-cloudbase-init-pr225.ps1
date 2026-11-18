# Bare metal: cloudbase-init 1.1.8 from the MSI with the fix of cloudbase/cloudbase-init#225. NetworkConfigPlugin
# sets a static address on a VLAN team NIC before Windows has its IP interface and fails ("Network interface
# with name ... not found"), leaving the server without its management address; the fix retries the lookup.
# osutils\windows.py is replaced by the one from the PR's commit. Both files are checked by SHA-256 (line
# endings aside), so the build fails if the MSI brings another cloudbase-init. Drop this script once a
# released MSI has the fix.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$commit = 'e2ab7512acf9545c80a6a66194e0e2c234f1a368'
$from = '825a8292672a55f0e5bd3b67bc045a5de7f9799e69506b9248e02440e25f2375' # 1.1.8
$to = 'e7aa6d985e40ada152d902650ad016b21e0b89a484e9a2c6a4ad55489693029b'   # 1.1.8 with the fix
$file = Join-Path $env:ProgramFiles 'Cloudbase Solutions\Cloudbase-Init\Python\Lib\site-packages\cloudbaseinit\osutils\windows.py'

function Get-TextSha256([string]$Text) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($Text.Replace("`r`n", "`n"))
  ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)) -replace '-').ToLower()
}

$have = Get-TextSha256 ([IO.File]::ReadAllText($file))
if ($have -eq $to) { Write-Host 'cloudbase-init: the fix of #225 is already in place'; exit 0 }
if ($have -ne $from) {
  throw "cloudbase-init: $file is not the 1.1.8 one (sha256 $have): check whether this MSI has the fix of cloudbase/cloudbase-init#225"
}

$wc = New-Object Net.WebClient
$wc.Encoding = [Text.Encoding]::UTF8
$new = $wc.DownloadString("https://raw.githubusercontent.com/ib-systems/cloudbase-init/$commit/cloudbaseinit/osutils/windows.py")
if ((Get-TextSha256 $new) -ne $to) { throw "cloudbase-init: windows.py of $commit does not match its SHA-256" }
[IO.File]::WriteAllText($file, $new, (New-Object Text.UTF8Encoding($false)))
Remove-Item (Join-Path (Split-Path $file) '__pycache__\windows.*.pyc') -Force -ErrorAction SilentlyContinue
Write-Host "cloudbase-init: osutils\windows.py from $commit (cloudbase/cloudbase-init#225)"
