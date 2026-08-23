#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CX_ROOT=${CX_ROOT:-/Applications/CrossOver.app/Contents/SharedSupport/CrossOver}
BOTTLE=myth-of-soma-server-macos
BOTTLES="$ROOT/.runtime/crossover-bottles"
CACHE="$ROOT/.cache/windows"
BUILD="$ROOT/.runtime/build"
LOG_DIR="$ROOT/.runtime/logs"
VC_REDIST="$CACHE/vc_redist.x86.exe"
ODBC_MSI="$CACHE/msodbcsql17-x86.msi"
VC_SHA256=0c09f2611660441084ce0df425c51c11e147e6447963c3690f97e0b25c55ed64
ODBC_SHA256=27e0f85c0fbf65b5bcaaf1134ff3409014b6e65c3ccb6ad58106f380e08cd0c7
VC_URL=https://download.visualstudio.microsoft.com/download/pr/9d270333-8b7b-4f96-9458-6fcdb2ec0b25/0C09F2611660441084CE0DF425C51C11E147E6447963C3690F97E0B25C55ED64/VC_redist.x86.exe
ODBC_URL=https://download.microsoft.com/download/57ea94d1-a9bd-4ab7-990a-1c1c4e7a2ef8/x86/1033/msodbcsql.msi

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
DB_PORT=${MSSQL_PORT:-1433}

[[ -x "$CX_ROOT/bin/wine" && -x "$CX_ROOT/bin/cxbottle" ]] || {
  echo 'CrossOver is required at /Applications/CrossOver.app.' >&2
  exit 1
}
command -v i686-w64-mingw32-gcc >/dev/null 2>&1 || {
  echo 'Install the MinGW cross-compiler: brew install mingw-w64' >&2
  exit 1
}

mkdir -p "$BOTTLES" "$CACHE" "$BUILD" "$LOG_DIR"
export CX_BOTTLE_PATH="$BOTTLES"

fetch() {
  local url=$1 output=$2 checksum=$3
  if [[ ! -f "$output" ]]; then
    curl --fail --location --output "$output" "$url"
  fi
  printf '%s  %s\n' "$checksum" "$output" | shasum -a 256 -c -
}

fetch "$VC_URL" "$VC_REDIST" "$VC_SHA256"
fetch "$ODBC_URL" "$ODBC_MSI" "$ODBC_SHA256"

if ! "$CX_ROOT/bin/cxbottle" --bottle "$BOTTLE" --status >/dev/null 2>&1; then
  "$CX_ROOT/bin/cxbottle" --bottle "$BOTTLE" --create --template win10 \
    --description 'Myth of Soma macOS 32-bit server runtime' \
    --param 'Bottle:WineArch=win32'
fi
bottle_config="$BOTTLES/$BOTTLE/cxbottle.conf"
grep -Eq '^"WineArch" = "win32"$' "$bottle_config" || {
  echo "Bottle $BOTTLE is not configured for 32-bit Windows applications." >&2
  exit 1
}

wine=("$CX_ROOT/bin/wine" --bottle "$BOTTLE" --no-gui --debugmsg -all)
driver="$BOTTLES/$BOTTLE/drive_c/windows/system32/msodbcsql17.dll"
if [[ ! -f "$driver" ]]; then
  "${wine[@]}" "$VC_REDIST" /install /quiet /norestart \
    > "$LOG_DIR/vcredist-install.log" 2>&1
  "${wine[@]}" msiexec.exe /i "$ODBC_MSI" /qn \
    IACCEPTMSODBCSQLLICENSETERMS=YES ADDLOCAL=ALL \
    > "$LOG_DIR/msodbcsql17-install.log" 2>&1
fi
[[ -f "$driver" ]] || {
  echo "ODBC Driver 17 installation did not produce $driver" >&2
  exit 1
}

for hive in HKCU HKLM; do
  base="$hive\\Software\\ODBC\\ODBC.INI"
  "${wine[@]}" reg.exe add "$base\\ODBC Data Sources" /v soma /t REG_SZ \
    /d 'ODBC Driver 17 for SQL Server' /f >/dev/null 2>&1
  "${wine[@]}" reg.exe add "$base\\soma" /v Description /t REG_SZ \
    /d 'Myth of Soma' /f >/dev/null 2>&1
  "${wine[@]}" reg.exe add "$base\\soma" /v Driver /t REG_SZ \
    /d 'C:\windows\system32\msodbcsql17.dll' /f >/dev/null 2>&1
  "${wine[@]}" reg.exe add "$base\\soma" /v Server /t REG_SZ \
    /d "127.0.0.1,$DB_PORT" /f >/dev/null 2>&1
  "${wine[@]}" reg.exe add "$base\\soma" /v Database /t REG_SZ \
    /d soma /f >/dev/null 2>&1
  "${wine[@]}" reg.exe add "$base\\soma" /v Encrypt /t REG_SZ \
    /d No /f >/dev/null 2>&1
  "${wine[@]}" reg.exe add "$base\\soma" /v TrustServerCertificate /t REG_SZ \
    /d Yes /f >/dev/null 2>&1
done

probe="$BUILD/win32-odbc-probe.exe"
i686-w64-mingw32-gcc -O2 -Wall -Wextra "$ROOT/tools/win32-odbc-probe.c" \
  -o "$probe" -lodbc32
probe_log="$LOG_DIR/odbc-probe.log"
"${wine[@]}" "$probe" > "$probe_log" 2>&1 || {
  tail -40 "$probe_log" >&2
  echo 'ODBC probe failed. Restore and start the database first.' >&2
  exit 1
}
grep -E 'SQLDriverConnect=(0|1)( |$)' "$probe_log" >/dev/null || {
  tail -40 "$probe_log" >&2
  exit 1
}

grep -E 'SQLAlloc|SQLSetConnectOption|SQLDriverConnect' "$probe_log"
printf 'CrossOver bottle %s has a verified 32-bit soma DSN.\n' "$BOTTLE"
