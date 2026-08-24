#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SIKARUGIR_APP=${SOMA_SIKARUGIR_APP:-$HOME/Applications/Sikarugir/myth of soma.app}
CONTENTS="$SIKARUGIR_APP/Contents"
ENGINE="$CONTENTS/SharedSupport/wine"
WINE="$ENGINE/bin/wine"
PREFIX=${SOMA_CLIENT_PREFIX:-$ROOT/.runtime/sikarugir-client-prefix}
CLIENT_SOURCE=${SOMA_CLIENT_SOURCE:-$ROOT/.runtime/client-patched}
DXWND_SOURCE=${SOMA_DXWND_SOURCE:-$CONTENTS/SharedSupport/prefix/drive_c/Program Files/dxwnd-2-06-13}
FRAME_DELAY_MS=${SOMA_CLIENT_FRAME_DELAY_MS:-50}
VC6_PACKAGE=${SOMA_VC6_PACKAGE:-$ROOT/.cache/client/Vs6sp6.exe}
VC6_BUILD="$ROOT/.runtime/client-vc6"

[[ -x "$WINE" ]] || {
  echo "Sikarugir Wine was not found at: $WINE" >&2
  echo 'Set SOMA_SIKARUGIR_APP to your Sikarugir wrapper app.' >&2
  exit 1
}
[[ -f "$CLIENT_SOURCE/Soma.exe" && -f "$CLIENT_SOURCE/SomaGame.exe" ]] || {
  echo 'An extracted and patched eSoma client is required.' >&2
  echo 'Set SOMA_CLIENT_SOURCE to the directory containing Soma.exe and SomaGame.exe.' >&2
  exit 1
}
[[ -f "$DXWND_SOURCE/dxwnd.exe" && -f "$DXWND_SOURCE/dxwnd.dll" ]] || {
  echo 'A complete DxWnd directory is required.' >&2
  echo 'Set SOMA_DXWND_SOURCE to the directory containing dxwnd.exe and dxwnd.dll.' >&2
  exit 1
}
[[ "$FRAME_DELAY_MS" =~ ^[0-9]+$ && "$FRAME_DELAY_MS" -ge 16 &&
   "$FRAME_DELAY_MS" -le 200 ]] || {
  echo 'SOMA_CLIENT_FRAME_DELAY_MS must be an integer from 16 to 200.' >&2
  exit 1
}
[[ -f "$VC6_PACKAGE" ]] || {
  echo 'The official Visual C++ 6 SP6 redistributable is required.' >&2
  echo 'Run make client-fetch first or set SOMA_VC6_PACKAGE.' >&2
  exit 1
}
command -v 7zz >/dev/null 2>&1 || {
  echo 'Install 7-Zip: brew install sevenzip' >&2
  exit 1
}

export WINEPREFIX="$PREFIX"
export WINEDLLPATH="$ENGINE/lib/wine"
export DYLD_FALLBACK_LIBRARY_PATH="$CONTENTS/Frameworks"
export MVK_CONFIG_LOG_LEVEL=0

if [[ ! -f "$PREFIX/system.reg" ]]; then
  WINEARCH=win64 WINEDEBUG=-all "$WINE" wineboot.exe -u
fi

mkdir -p "$PREFIX/drive_c/Soma" "$PREFIX/drive_c/DxWnd"
cp -R "$CLIENT_SOURCE/." "$PREFIX/drive_c/Soma/"
cp -R "$DXWND_SOURCE/." "$PREFIX/drive_c/DxWnd/"
cp "$ROOT/config/dxwnd.ini" "$PREFIX/drive_c/DxWnd/dxwnd.ini"
/usr/bin/sed -i '' \
  "s/^maxfps0=.*/maxfps0=$FRAME_DELAY_MS/" \
  "$PREFIX/drive_c/DxWnd/dxwnd.ini"

if [[ ! -f "$PREFIX/drive_c/windows/syswow64/mfc42.dll" ]]; then
  mkdir -p "$VC6_BUILD/package" "$VC6_BUILD/files"
  find "$VC6_BUILD/package" "$VC6_BUILD/files" -mindepth 1 -delete
  7zz e -y "$VC6_PACKAGE" -o"$VC6_BUILD/package" vcredist.exe >/dev/null
  7zz e -y "$VC6_BUILD/package/vcredist.exe" -o"$VC6_BUILD/files" \
    mfc42.dll mfc42u.dll msvcp60.dll >/dev/null
  cp "$VC6_BUILD/files/"{mfc42.dll,mfc42u.dll,msvcp60.dll} \
    "$PREFIX/drive_c/windows/syswow64/"
fi

printf 'Client installed at %s\n' "$PREFIX/drive_c/Soma"
printf 'DxWnd frame delay: %s ms (approximately %s FPS).\n' \
  "$FRAME_DELAY_MS" "$((1000 / FRAME_DELAY_MS))"
