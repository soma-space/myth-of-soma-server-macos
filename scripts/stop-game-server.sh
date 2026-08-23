#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE="$ROOT/.runtime/state"

"$ROOT/scripts/run-crossover.sh" taskkill.exe /f /im OnePerOne.exe >/dev/null 2>&1 || true
"$ROOT/scripts/run-crossover.sh" taskkill.exe /f /im sharedmem.exe >/dev/null 2>&1 || true

for pid_file in "$STATE/oneperone.pid" "$STATE/sharedmem.pid"; do
  [[ -f "$pid_file" ]] || continue
  launcher_pid=$(<"$pid_file")
  if [[ -n "$launcher_pid" ]] && kill -0 "$launcher_pid" 2>/dev/null; then
    kill "$launcher_pid" 2>/dev/null || true
  fi
  : > "$pid_file"
done

echo 'Game-server processes stopped.'
