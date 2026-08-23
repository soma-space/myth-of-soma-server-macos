#!/usr/bin/env bash
set -euo pipefail

if colima status >/dev/null 2>&1; then
  echo 'Colima is already running.'
  exit 0
fi

if [[ $(uname -m) == arm64 ]]; then
  colima start --vm-type=vz --vz-rosetta --cpu 4 --memory 6 --disk 40
else
  colima start --vm-type=vz --cpu 4 --memory 6 --disk 40
fi
