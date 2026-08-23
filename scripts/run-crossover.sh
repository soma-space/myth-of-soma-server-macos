#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CX_ROOT=${CX_ROOT:-/Applications/CrossOver.app/Contents/SharedSupport/CrossOver}
BOTTLE=${SOMA_CX_BOTTLE:-myth-of-soma-server-macos}

[[ -x "$CX_ROOT/bin/wine" ]] || {
  echo 'CrossOver is required at /Applications/CrossOver.app.' >&2
  exit 1
}

export CX_BOTTLE_PATH="$ROOT/.runtime/crossover-bottles"
exec "$CX_ROOT/bin/wine" --bottle "$BOTTLE" --no-gui \
  --debugmsg "${CX_DEBUGMSG:--all}" "$@"
