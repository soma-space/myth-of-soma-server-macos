#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SERVICES="$ROOT/.runtime/distribution/server/services"

[[ -f "$SERVICES/Services.exe" ]] || {
  echo 'Run make fetch and make prepare first.' >&2
  exit 1
}

printf 'Press Create Services, verify every service says Started, then close the window.\n'
cd "$SERVICES"
exec "$ROOT/scripts/run-crossover.sh" Services.exe
