#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DISTRIBUTION="$ROOT/.runtime/distribution"
SERVICES="$DISTRIBUTION/server/services"
ONEPERONE="$DISTRIBUTION/server/oneperone"
CX_ROOT=${CX_ROOT:-/Applications/CrossOver.app/Contents/SharedSupport/CrossOver}
CX_BOTTLES="$ROOT/.runtime/crossover-bottles"
BOTTLE=myth-of-soma-server-macos

[[ -f "$ONEPERONE/ServerExtention.dll" ]] || {
  echo 'Run make fetch first.' >&2
  exit 1
}
[[ -d "$CX_BOTTLES/$BOTTLE" ]] || {
  echo 'Run make crossover first.' >&2
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

printf 'Runtime prepared at %s\n' "$DISTRIBUTION"
printf 'Bind IP: %s; advertised IP: %s\n' "$bind_ip" "$advertised_ip"
printf 'Windows service path: %s\n' "$service_path"
