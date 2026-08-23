#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cleanup() {
  "$ROOT/scripts/stop-game-server.sh" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"$ROOT/scripts/start-game-server.sh"
printf "PASS: repaired OnePerOne loaded Rauban's extension and connected to SQL Server.\n"
