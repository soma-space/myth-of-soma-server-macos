#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RUNTIME="$ROOT/.runtime/distribution/server/oneperone"
STATE="$ROOT/.runtime/state"
LOG_DIR="$ROOT/.runtime/logs"
LOG="$LOG_DIR/game-server.log"
SHARED_PID_FILE="$STATE/sharedmem.pid"
GAME_PID_FILE="$STATE/oneperone.pid"

[[ -f "$RUNTIME/OnePerOne.exe" && -f "$RUNTIME/ServerExtention.dll" ]] || {
  echo 'Run make fetch first.' >&2
  exit 1
}
mkdir -p "$STATE" "$LOG_DIR"

for pid_file in "$SHARED_PID_FILE" "$GAME_PID_FILE"; do
  if [[ -s "$pid_file" ]]; then
    old_pid=$(<"$pid_file")
    if kill -0 "$old_pid" 2>/dev/null; then
      echo "A server launcher is already running with PID $old_pid." >&2
      exit 1
    fi
  fi
done

: > "$LOG"
cd "$RUNTIME"
nohup env CX_DEBUGMSG=+loaddll,+odbc "$ROOT/scripts/run-crossover.sh" sharedmem.exe \
  >> "$LOG" 2>&1 &
shared_pid=$!
printf '%s\n' "$shared_pid" > "$SHARED_PID_FILE"
sleep 3
if ! kill -0 "$shared_pid" 2>/dev/null; then
  echo 'sharedmem.exe exited during startup.' >&2
  exit 1
fi

nohup env CX_DEBUGMSG=+loaddll,+odbc "$ROOT/scripts/run-crossover.sh" OnePerOne.exe \
  >> "$LOG" 2>&1 &
game_pid=$!
printf '%s\n' "$game_pid" > "$GAME_PID_FILE"
sleep 12

healthy=1
kill -0 "$shared_pid" 2>/dev/null || healthy=0
kill -0 "$game_pid" 2>/dev/null || healthy=0
grep -Ei 'Loaded L".*ServerExtention\.dll".*native' "$LOG" >/dev/null || healthy=0
grep -E 'SQLDriverConnect Returning (0|1)' "$LOG" >/dev/null || healthy=0
grep -Ei 'Unhandled (page fault|exception)' "$LOG" >/dev/null && healthy=0

if [[ "$healthy" != 1 ]]; then
  tail -80 "$LOG" >&2
  "$ROOT/scripts/stop-game-server.sh" >/dev/null 2>&1 || true
  echo 'Game-server startup validation failed.' >&2
  exit 1
fi

printf 'sharedmem launcher PID: %s\n' "$shared_pid"
printf 'OnePerOne launcher PID: %s\n' "$game_pid"
printf 'Extension and database connection: verified\n'
printf 'Log: %s\n' "$LOG"
