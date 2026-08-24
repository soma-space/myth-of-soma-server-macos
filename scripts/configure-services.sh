#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SERVICES="$ROOT/.runtime/distribution/server/services"
RUNNER="$ROOT/scripts/run-crossover.sh"
LOG_DIR="$ROOT/.runtime/logs"
LOG="$LOG_DIR/services-setup.log"

[[ -f "$SERVICES/UserManager.exe" && -f "$SERVICES/Game.exe" &&
   -f "$SERVICES/session.exe" ]] || {
  echo 'Run make fetch and make prepare first.' >&2
  exit 1
}

mkdir -p "$LOG_DIR"
: > "$LOG"

windows_services=$(
  "$RUNNER" winepath.exe -w "$SERVICES" 2>>"$LOG" | tr -d '\r'
)
[[ -n "$windows_services" ]] || {
  echo 'Could not convert the services directory to a Windows path.' >&2
  exit 1
}

wine() {
  "$RUNNER" "$@" >>"$LOG" 2>&1
}

service_exists() {
  wine reg.exe query "HKLM\\SYSTEM\\CurrentControlSet\\Services\\$1"
}

ensure_service() {
  local name=$1 display=$2 module=$3

  if service_exists "$name"; then
    wine reg.exe add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\$name" \
      /v ImagePath /t REG_SZ /d "$module" /f
    wine reg.exe add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\$name" \
      /v DisplayName /t REG_SZ /d "$display" /f
    wine reg.exe add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\$name" \
      /v Start /t REG_DWORD /d 3 /f
    wine reg.exe add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\$name" \
      /v Type /t REG_DWORD /d 16 /f
  else
    wine sc.exe create "$name" \
      binPath= "$module" DisplayName= "$display" start= demand type= own
  fi
}

reg_sz() {
  local service=$1 name=$2 value=$3
  wine reg.exe add \
    "HKLM\\SYSTEM\\CurrentControlSet\\Services\\$service\\Config" \
    /v "$name" /t REG_SZ /d "$value" /f
}

reg_dword() {
  local service=$1 name=$2 value=$3
  wine reg.exe add \
    "HKLM\\SYSTEM\\CurrentControlSet\\Services\\$service\\Config" \
    /v "$name" /t REG_DWORD /d "$value" /f
}

um=UM_SOMA
game='GS_SOMA_SOMA Game'
session=SM_SOMA_0

um_module="$windows_services\\UserManager.exe"
game_module="$windows_services\\Game.exe"
session_module="$windows_services\\session.exe"

ensure_service "$um" 'SOMA User' "$um_module"
reg_sz "$um" Addr 127.0.0.1
reg_dword "$um" Capacity 200
reg_sz "$um" FMAddr 127.0.0.1
reg_dword "$um" FMPort 4101
reg_sz "$um" GameID soma
reg_dword "$um" GameVar 0
reg_sz "$um" GSAddr 127.0.0.1
reg_dword "$um" GSPort 4120
reg_dword "$um" ID 0
reg_sz "$um" Module "$um_module"
reg_sz "$um" NoticeSessionMessage test
reg_dword "$um" NoticeSessionStatus 0
reg_sz "$um" Password soma
reg_dword "$um" Port 4100
reg_dword "$um" TimeOut 0
reg_dword "$um" Timer 0
reg_sz "$um" UserID soma

ensure_service "$game" 'SOMA Game' "$game_module"
reg_sz "$game" Addr 127.0.0.1
reg_dword "$game" Capacity 200
reg_sz "$game" GameID soma
reg_dword "$game" ID 0
reg_sz "$game" Module "$game_module"
reg_sz "$game" Password soma
reg_dword "$game" Port 4120
reg_dword "$game" TimeOut 0
reg_dword "$game" Timer 0
reg_sz "$game" UserID soma

ensure_service "$session" 'SOMA Session' "$session_module"
reg_sz "$session" Addr 127.0.0.1
reg_dword "$session" Capacity 200
reg_sz "$session" GameID soma
reg_dword "$session" ID 0
reg_sz "$session" Module "$session_module"
reg_sz "$session" Password soma
reg_dword "$session" Pay 0
reg_dword "$session" Port 4110
reg_sz "$session" ServName 'SOMA Session'
reg_dword "$session" TimeOut 0
reg_dword "$session" Timer 0
reg_sz "$session" UMAddr 127.0.0.1
reg_dword "$session" UMPort 4100
reg_sz "$session" UserID soma

request_start() {
  local service=$1 launcher

  # These 1990s services remain in START_PENDING even after they bind their
  # sockets. Wine's sc.exe consequently waits forever, so start each one in
  # the background and retire only the waiting controller after a grace period.
  "$RUNNER" sc.exe start "$service" >>"$LOG" 2>&1 &
  launcher=$!
  sleep 4
  if kill -0 "$launcher" 2>/dev/null; then
    kill "$launcher" 2>/dev/null || true
  fi
  pkill -f '^sc\.exe start ' 2>/dev/null || true
}

for service in "$um" "$game" "$session"; do
  request_start "$service"
done

printf 'Configured and requested startup for:\n'
printf '  %s\n' "$um" "$game" "$session"
printf 'Service log: %s\n' "$LOG"
