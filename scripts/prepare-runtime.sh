#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DISTRIBUTION="$ROOT/.runtime/distribution"
SERVICES="$DISTRIBUTION/server/services"
ONEPERONE="$DISTRIBUTION/server/oneperone"
CX_ROOT=${CX_ROOT:-/Applications/CrossOver.app/Contents/SharedSupport/CrossOver}
CX_BOTTLES="$ROOT/.runtime/crossover-bottles"
BOTTLE=myth-of-soma-server-macos
SHIM_SOURCE="$ROOT/compat/odbc-shim"
BUILD="$ROOT/.runtime/build/odbc-shim"
WINE_ODBC="$CX_BOTTLES/$BOTTLE/drive_c/windows/system32/odbc32.dll"

[[ -f "$ONEPERONE/OnePerOne.wine.exe" ]] || {
  echo 'The server payload lacks OnePerOne.wine.exe.' >&2
  echo 'Run make fetch with the v0.2.0-rc1 (or newer) Windows release.' >&2
  exit 1
}
[[ -d "$CX_BOTTLES/$BOTTLE" ]] || {
  echo 'Run make crossover first.' >&2
  exit 1
}
[[ -f "$WINE_ODBC" ]] || {
  echo "Wine's 32-bit odbc32.dll is missing from the CrossOver bottle." >&2
  exit 1
}
command -v i686-w64-mingw32-gcc >/dev/null 2>&1 || {
  echo 'Install the MinGW cross-compiler: brew install mingw-w64' >&2
  exit 1
}

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
bind_ip=${SOMA_BIND_IP:-127.0.0.1}
advertised_ip=${SOMA_ADVERTISED_IP:-127.0.0.1}
db_port=${MSSQL_PORT:-1433}

service_path=$(CX_BOTTLE_PATH="$CX_BOTTLES" "$CX_ROOT/bin/wine" \
  --bottle "$BOTTLE" --no-gui --debugmsg -all winepath.exe -w "$SERVICES" | tr -d '\r')

export SOMA_BIND_IP="$bind_ip"
export SOMA_ADVERTISED_IP="$advertised_ip"
export SOMA_SERVICE_PATH="$service_path"
export SOMA_DB_PORT="$db_port"

perl -pi -e 's/^IP=.*/IP=$ENV{SOMA_BIND_IP}/; s/^ServicePath=.*/ServicePath=$ENV{SOMA_SERVICE_PATH}/' \
  "$SERVICES/config.ini"
perl -pi -e 's/^SVR01_ADDR=.*/SVR01_ADDR=$ENV{SOMA_ADVERTISED_IP}/' \
  "$SERVICES/Dir.ini"
perl -pi -e 's/^db_host=.*/db_host=127.0.0.1,$ENV{SOMA_DB_PORT}/' \
  "$ONEPERONE/config.ini"

if [[ ! -f "$ONEPERONE/OnePerOne.extension.exe" ]]; then
  cp "$ONEPERONE/OnePerOne.exe" "$ONEPERONE/OnePerOne.extension.exe"
fi
cp "$ONEPERONE/OnePerOne.wine.exe" "$ONEPERONE/OnePerOne.exe"

mkdir -p "$BUILD"
i686-w64-mingw32-gcc -Os -Wall -Wextra -shared -static-libgcc \
  -Wl,--kill-at -o "$BUILD/odbc32.dll" \
  "$SHIM_SOURCE/odbc32-shim.c" "$SHIM_SOURCE/odbc32-shim.def"
cp "$BUILD/odbc32.dll" "$ONEPERONE/odbc32.dll"
cp "$WINE_ODBC" "$ONEPERONE/odbc32_real.dll"

printf 'Runtime prepared at %s\n' "$DISTRIBUTION"
printf 'Bind IP: %s; advertised IP: %s\n' "$bind_ip" "$advertised_ip"
printf 'Windows service path: %s\n' "$service_path"
printf 'Wine ODBC 2 compatibility shim: built and installed\n'
printf 'OnePerOne runtime: guarded Wine build (Rauban loader disabled)\n'
