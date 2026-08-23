#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE="$ROOT/.env"

[[ -f "$ENV_FILE" ]] || {
  echo 'Copy .env.example to .env and set a strong SA password.' >&2
  exit 1
}
[[ -f "$ROOT/.runtime/distribution/database/soma.bak" ]] || {
  echo 'Run make fetch first.' >&2
  exit 1
}

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
: "${MSSQL_SA_PASSWORD:?MSSQL_SA_PASSWORD is required}"

cd "$ROOT"
sqlcmd=(/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -b)

printf 'Waiting for SQL Server'
ready=0
for _ in $(seq 1 60); do
  if docker-compose exec -T mssql "${sqlcmd[@]}" -Q 'SELECT 1' >/dev/null 2>&1; then
    printf ' ready.\n'
    ready=1
    break
  fi
  printf '.'
  sleep 2
done
[[ "$ready" == 1 ]] || {
  printf ' timed out.\n' >&2
  exit 1
}

docker-compose exec -T mssql "${sqlcmd[@]}" -i /dev/stdin < "$ROOT/sql/restore.sql"
docker-compose exec -T mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost \
  -U soma -P soma -b -d soma \
  -Q 'SELECT DB_NAME() AS database_name, (SELECT COUNT(*) FROM sys.tables) AS table_count;'
