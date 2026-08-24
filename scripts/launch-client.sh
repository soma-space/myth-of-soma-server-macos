#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SIKARUGIR_APP=${SOMA_SIKARUGIR_APP:-$HOME/Applications/Sikarugir/myth of soma.app}
CONTENTS="$SIKARUGIR_APP/Contents"
ENGINE="$CONTENTS/SharedSupport/wine"
WINE="$ENGINE/bin/wine"
PREFIX=${SOMA_CLIENT_PREFIX:-$ROOT/.runtime/sikarugir-client-prefix}
DXWND="$PREFIX/drive_c/DxWnd"

[[ -x "$WINE" && -f "$DXWND/dxwnd.exe" &&
   -f "$PREFIX/drive_c/Soma/Soma.exe" ]] || {
  echo 'Run make client-setup first.' >&2
  exit 1
}

for port in 4110 12000; do
  nc -z 127.0.0.1 "$port" >/dev/null 2>&1 || {
    echo "Soma server port $port is not listening; run make start first." >&2
    exit 1
  }
done

export WINEPREFIX="$PREFIX"
export WINEDLLPATH="$ENGINE/lib/wine"
export DYLD_FALLBACK_LIBRARY_PATH="$CONTENTS/Frameworks"
export MVK_CONFIG_LOG_LEVEL=0
export WINEDEBUG=-all

cd "$DXWND"
"$WINE" dxwnd.exe /E >/dev/null 2>&1 || true
exec "$WINE" dxwnd.exe /R:0 /Q
