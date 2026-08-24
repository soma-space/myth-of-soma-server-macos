#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RUNTIME="$ROOT/.runtime/distribution/server/oneperone"
STATE="$ROOT/.runtime/state"
LOG_DIR="$ROOT/.runtime/logs"
LOG="$LOG_DIR/game-server.log"
SHIM_LOG="$RUNTIME/odbc-shim.log"
SHARED_PID_FILE="$STATE/sharedmem.pid"
GAME_PID_FILE="$STATE/oneperone.pid"

[[ -f "$RUNTIME/OnePerOne.exe" && -f "$RUNTIME/odbc32.dll" &&
   -f "$RUNTIME/odbc32_real.dll" ]] || {
  echo 'Run make fetch, make crossover, and make prepare first.' >&2
  exit 1
}
mkdir -p "$STATE" "$LOG_DIR"

port_open() {
  nc -z 127.0.0.1 "$1" >/dev/null 2>&1
}

wait_for_port() {
  local port=$1 label=$2 attempts=${3:-90}
  for _ in $(seq 1 "$attempts"); do
    if port_open "$port"; then
      printf '%-16s listening on 127.0.0.1:%s\n' "$label" "$port"
      return 0
    fi
    sleep 1
  done
  return 1
}

if ! port_open 12000; then
  : > "$LOG"
  : > "$SHIM_LOG"
  cd "$RUNTIME"

  nohup env WINEDLLOVERRIDES=odbc32=n CX_DEBUGMSG=-all \
    "$ROOT/scripts/run-crossover.sh" sharedmem.exe >> "$LOG" 2>&1 &
  shared_pid=$!
  printf '%s\n' "$shared_pid" > "$SHARED_PID_FILE"
  sleep 3

  nohup env WINEDLLOVERRIDES=odbc32=n CX_DEBUGMSG=-all \
    "$ROOT/scripts/run-crossover.sh" OnePerOne.exe >> "$LOG" 2>&1 &
  game_pid=$!
  printf '%s\n' "$game_pid" > "$GAME_PID_FILE"

  if ! wait_for_port 12000 OnePerOne 90; then
    tail -80 "$LOG" >&2
    tail -30 "$SHIM_LOG" >&2
    "$ROOT/scripts/stop-game-server.sh" >/dev/null 2>&1 || true
    echo 'OnePerOne did not open port 12000.' >&2
    exit 1
  fi
else
  printf '%-16s already listening on 127.0.0.1:12000\n' OnePerOne
fi

"$ROOT/scripts/configure-services.sh"

for port_label in '4100 UserManager' '4120 GameDirectory' '4110 Session'; do
  port=${port_label%% *}
  label=${port_label#* }
  if ! wait_for_port "$port" "$label" 45; then
    tail -80 "$LOG_DIR/services-setup.log" >&2
    echo "$label did not open port $port." >&2
    exit 1
  fi
done

printf 'All four server endpoints are ready.\n'
printf 'Core log: %s\n' "$LOG"
printf 'ODBC shim log: %s\n' "$SHIM_LOG"
