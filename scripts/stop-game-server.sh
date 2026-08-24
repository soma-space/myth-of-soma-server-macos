#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE="$ROOT/.runtime/state"

for image in session.exe Game.exe UserManager.exe OnePerOne.exe sharedmem.exe; do
  "$ROOT/scripts/run-crossover.sh" taskkill.exe /f /im "$image" \
    >/dev/null 2>&1 || true
done

# Wine keeps application sockets in wineserver. If an old process crashes,
# those listeners can otherwise survive and make a port-only health check look
# healthy. Shut the bottle down after the graceful per-process attempts so the
# next start always gets a clean wineserver and fresh executable images.
"$ROOT/scripts/run-crossover.sh" wineboot.exe -k >/dev/null 2>&1 || true

for pid_file in "$STATE/oneperone.pid" "$STATE/sharedmem.pid"; do
  [[ -f "$pid_file" ]] || continue
  launcher_pid=$(<"$pid_file")
  if [[ -n "$launcher_pid" ]] && kill -0 "$launcher_pid" 2>/dev/null; then
    kill "$launcher_pid" 2>/dev/null || true
  fi
  : > "$pid_file"
done

echo 'Soma core, services, and CrossOver bottle stopped.'
