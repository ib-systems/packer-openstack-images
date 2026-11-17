#!/bin/sh
# Dell drivers for the bare-metal image, from downloads.dell.com (paths and SHA-256 from Dell's catalog,
# downloads.dell.com/catalog/Catalog.xml.gz), unpacked into drivers/<component>/ without running anything.
# Needs curl and 7zip (7z). Add a model: a package line below and its unpack step.
#   PowerEdge R640: PERC H740P (megasas35 7.738.8.0, WS2025), ConnectX-4 Lx (WinOF-2 25.1)
set -eu
cd "$(dirname "$0")/.."
D=$PWD/drivers
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
cd "$W"

while read -r rel sha; do
	f=${rel##*/}
	curl -fsSLo "$f" "https://downloads.dell.com/$rel"
	echo "$sha  $f" | sha256sum -c -
done <<'PKGS'
FOLDER14850375M/3/SAS-RAID_Driver_F23GR_WN64_7.738.8.0_A02_01.EXE 39a21363a55c0ff3ded8392a3215dc207ad0f858e7e3ffffe58c3096c316f628
FOLDER13036121M/1/Network_Driver_3G71F_WN64_25.1_A00.EXE 86e7bf8e2f832590f364d55dfce2cd74f32109d4b72e4bfaf2102f615eac1b12
PKGS

x() { 7z e -y -bso0 -bsp0 "$@"; }

mkdir -p "$D/perc-h740p"
x -o"$D/perc-h740p" SAS-RAID_Driver_F23GR_WN64_7.738.8.0_A02_01.EXE \
	payload/megasas35.inf payload/megasas35.sys payload/megasas35.cat

# Mellanox: Dell EXE > 7z SFX > MSI > Data1.cab; InstallShield adds a digit to colliding names.
mkdir -p "$D/mlx5-connectx4lx" m
x -om Network_Driver_3G71F_WN64_25.1_A00.EXE payload/MLNX_WinOF2-25_1_50020_All_x64.exe
x -om m/MLNX_WinOF2-25_1_50020_All_x64.exe MLNX_WinOF2.msi
x -om m/MLNX_WinOF2.msi Data1.cab
x -om m/Data1.cab mlx5.inf5 mlx5.sys5 mlx5.cat5 mlx5ui.dll
for e in inf sys cat; do mv "m/mlx5.${e}5" "$D/mlx5-connectx4lx/mlx5.$e"; done
mv m/mlx5ui.dll "$D/mlx5-connectx4lx/"

ls -l "$D"/*/
