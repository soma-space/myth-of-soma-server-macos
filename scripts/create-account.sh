#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
account_user=${1:-${SOMA_ACCOUNT_USER:-}}
account_password=${2:-${SOMA_ACCOUNT_PASSWORD:-}}
account_email=${3:-${SOMA_ACCOUNT_EMAIL:-}}

if [[ -z "$account_user" || -z "$account_password" || -z "$account_email" ]]; then
  echo 'Usage: create-account.sh USERNAME PASSWORD EMAIL' >&2
  echo 'The SOMA_ACCOUNT_USER, SOMA_ACCOUNT_PASSWORD, and SOMA_ACCOUNT_EMAIL environment variables are also accepted.' >&2
  exit 2
fi

[[ "$account_user" =~ ^[A-Za-z0-9_.-]{1,20}$ ]] || {
  echo 'Username must be 1-20 letters, digits, dots, underscores, or hyphens.' >&2
  exit 2
}
[[ "$account_password" =~ ^[A-Za-z0-9_.!@#%-]{1,20}$ ]] || {
  echo 'Password must be 1-20 characters from A-Z, a-z, 0-9, _ . ! @ # % -.' >&2
  exit 2
}
[[ "$account_email" =~ ^[A-Za-z0-9_.+@-]{3,100}$ ]] || {
  echo 'Email contains unsupported characters.' >&2
  exit 2
}

cd "$ROOT"
docker-compose exec -T mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U soma -P soma -d soma -b \
  -v "ACCOUNT_USER=$account_user" \
     "ACCOUNT_PASSWORD=$account_password" \
     "ACCOUNT_EMAIL=$account_email" \
  -i /dev/stdin < "$ROOT/sql/create-account.sql"
