#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION=${SOMA_WINDOWS_VERSION:-v0.1.0-rc1}
EXPECTED_SHA256=${SOMA_WINDOWS_ZIP_SHA256:-4db30557ea1cb9d36e23d3be80f8584a57a9128cf7b419785320b55160689abc}
ASSET="myth-of-soma-server-windows-$VERSION.zip"
URL="https://github.com/soma-space/myth-of-soma-server-windows/releases/download/$VERSION/$ASSET"
CACHE="$ROOT/.cache/$ASSET"
STAGE="$ROOT/.runtime/extract-$VERSION"
DESTINATION="$ROOT/.runtime/distribution"

if [[ -d "$DESTINATION" && -f "$DESTINATION/SHA256SUMS" ]]; then
  printf 'Server payload already present at %s\n' "$DESTINATION"
  exit 0
fi
mkdir -p "$ROOT/.cache" "$ROOT/.runtime" "$STAGE"
if [[ -n "${SOMA_WINDOWS_ZIP:-}" ]]; then
  cp "$SOMA_WINDOWS_ZIP" "$CACHE"
elif [[ ! -f "$CACHE" ]]; then
  curl --fail --location --output "$CACHE" "$URL"
fi
printf '%s  %s\n' "$EXPECTED_SHA256" "$CACHE" | shasum -a 256 -c -

find "$STAGE" -mindepth 1 -delete
unzip -q "$CACHE" -d "$STAGE"
source_root="$STAGE/myth-of-soma-server-windows-$VERSION"
[[ -f "$source_root/SHA256SUMS" ]] || {
  echo "Release archive has an unexpected layout: $source_root" >&2
  exit 1
}
(
  cd "$source_root"
  shasum -a 256 -c SHA256SUMS >/dev/null
)
echo 'All files in the release manifest are valid.'
mv "$source_root" "$DESTINATION"
find "$STAGE" -mindepth 1 -delete

printf 'Installed checksum-verified server payload at %s\n' "$DESTINATION"
