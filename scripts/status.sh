#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

cd "$ROOT"
docker-compose ps

printf '\n%-16s %-9s %s\n' component status endpoint
for port_label in \
  '4100 UserManager' \
  '4110 Session' \
  '4120 GameDirectory' \
  '12000 OnePerOne'; do
  port=${port_label%% *}
  label=${port_label#* }
  status=stopped
  nc -z 127.0.0.1 "$port" >/dev/null 2>&1 && status=listening
  printf '%-16s %-9s 127.0.0.1:%s\n' "$label" "$status" "$port"
done
