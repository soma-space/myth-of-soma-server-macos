#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
warnings=0
ok() { printf 'ok    %s\n' "$1"; }
warn() { printf 'warn  %s\n' "$1"; warnings=$((warnings + 1)); }

if [[ $(uname -m) == arm64 ]]; then
  ok 'Apple Silicon host detected'
else
  warn "Apple Silicon expected; found $(uname -m)"
fi
if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
  ok 'Rosetta 2 can execute x86-64 programs'
else
  warn 'Rosetta 2 is unavailable'
fi
if [[ -x /Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine ]]; then
  ok 'CrossOver runtime is available'
else
  warn 'CrossOver was not found in /Applications'
fi
for command_name in colima docker docker-compose i686-w64-mingw32-gcc; do
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name is installed"
  else
    warn "$command_name is not installed"
  fi
done
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  ok 'Docker engine is reachable'
else
  warn 'Docker engine is not running'
fi
if [[ -f "$ROOT/.runtime/distribution/server/oneperone/ServerExtention.dll" ]]; then
  ok 'Checksum-verified server payload is present'
else
  warn 'Server payload is absent; run make fetch'
fi
if [[ -f "$ROOT/.runtime/crossover-bottles/myth-of-soma-server-macos/drive_c/windows/system32/msodbcsql17.dll" ]]; then
  ok 'CrossOver x86 Microsoft ODBC driver is installed'
else
  warn 'CrossOver ODBC runtime is absent; run make crossover after database restore'
fi

printf '\n%d warning(s).\n' "$warnings"
