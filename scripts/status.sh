#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATE="$ROOT/.runtime/state"

cd "$ROOT"
docker-compose ps

for process_name in sharedmem oneperone; do
  pid_file="$STATE/$process_name.pid"
  process_status=stopped
  process_pid='-'
  if [[ -s "$pid_file" ]]; then
    process_pid=$(<"$pid_file")
    kill -0 "$process_pid" 2>/dev/null && process_status=running
  fi
  printf '%-12s %-8s pid=%s\n' "$process_name" "$process_status" "$process_pid"
done
