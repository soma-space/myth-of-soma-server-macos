#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CACHE="$ROOT/.cache/client"
BUILD="$ROOT/.runtime/client-build"
DESTINATION="$ROOT/.runtime/client-patched"

command -v 7zz >/dev/null 2>&1 || {
  echo 'Install 7-Zip: brew install sevenzip' >&2
  exit 1
}
command -v unshield >/dev/null 2>&1 || {
  echo 'Install unshield: brew install unshield' >&2
  exit 1
}
command -v rsync >/dev/null 2>&1 || {
  echo 'rsync is required to assemble the client.' >&2
  exit 1
}

mkdir -p "$CACHE" "$BUILD" "$DESTINATION"

fetch() {
  local url=$1 output=$2 checksum=$3
  if [[ ! -f "$output" ]]; then
    curl --fail --location --retry 3 --continue-at - \
      --output "$output" "$url"
  fi
  printf '%s  %s\n' "$checksum" "$output" | shasum -a 256 -c -
}

fetch 'https://drive.usercontent.google.com/download?id=1A69qVlGUfdkr_mKT36yRrCpha62eq91M&export=download&confirm=t' \
  "$CACHE/somainst220.exe" \
  92682d22bc8e73b996cb6c6ccfd507eff2ba8e4f9097d63f3cd16b4d4c8f990f
fetch 'https://drive.usercontent.google.com/download?id=1SuGyl7mhVdHwL2CYZkEWGf9zFdlKHrKt&export=download&confirm=t' \
  "$CACHE/Patch221.exe" \
  90c61b3e787d1f46ca3d472deb26e8f2bd18b2171300c1a3c5a3636c1884424d
fetch 'https://drive.usercontent.google.com/download?id=1wXYB9xJIiCNAbMKrNfeVzp_0deJWPu_7&export=download&confirm=t' \
  "$CACHE/patch222.exe" \
  39d1a2f039687f566fda30ad4ab9c0b91d74ad3c2210e02131307e0fa8bab8c9
fetch 'https://drive.usercontent.google.com/download?id=1WuMSKOe6Noq44St36so7R0gspdv5UHNQ&export=download&confirm=t' \
  "$CACHE/patch223.exe" \
  3b2f820753745e76511931fc5586f979becf019ef719090453fd147321f46e66
fetch 'http://crossover.codeweavers.com/redirect/msvcp60' \
  "$CACHE/Vs6sp6.exe" \
  7fa1d1778824b55a5fceb02f45c399b5d4e4dce7403661e67e587b5f455edbf3

find "$BUILD" -mindepth 1 -delete
find "$DESTINATION" -mindepth 1 -delete

installer_220="$BUILD/installer-220"
client_220="$BUILD/client-220"
mkdir -p "$installer_220" "$client_220"
7zz x -y "$CACHE/somainst220.exe" -o"$installer_220" >/dev/null
unshield -d "$client_220" x "$installer_220/Disk1/data1.cab" >/dev/null
rsync -a "$client_220/App_Executables/" "$DESTINATION/"

for patch_number in 221 222 223; do
  patch_file="$CACHE/patch${patch_number}.exe"
  [[ -f "$patch_file" ]] || patch_file="$CACHE/Patch${patch_number}.exe"
  installer="$BUILD/installer-$patch_number"
  extracted="$BUILD/client-$patch_number"
  mkdir -p "$installer" "$extracted"
  7zz x -y "$patch_file" -o"$installer" >/dev/null
  unshield -d "$extracted" x "$installer/Disk1/data1.cab" >/dev/null
  rsync -a "$extracted/App_Executables/" "$DESTINATION/"
done

printf '%s  %s\n' \
  0bd29f7ff4c61c8b017f81c107efb0e61ee450317cd1d862f0880f62694edfb4 \
  "$DESTINATION/Soma.exe" | shasum -a 256 -c -
printf '%s  %s\n' \
  eff6b5d3528f516e9cb21f0022a85a4594d2939910a6d6e4a7ff1bd13d7b0601 \
  "$DESTINATION/SomaGame.exe" | shasum -a 256 -c -

printf 'Checksum-verified eSoma 223 client assembled at %s\n' "$DESTINATION"
