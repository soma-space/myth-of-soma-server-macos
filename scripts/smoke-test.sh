#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cleanup() {
  "$ROOT/scripts/stop-game-server.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"$ROOT/scripts/start-game-server.sh"
for port in 4100 4110 4120 12000; do
  nc -z 127.0.0.1 "$port"
done
grep -q '^SQLPrepare statement=' \
  "$ROOT/.runtime/distribution/server/oneperone/odbc-shim.log"
printf 'PASS: guarded core, ODBC shim, and all client-facing services are ready.\n'
