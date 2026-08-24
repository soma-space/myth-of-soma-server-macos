#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION=${SOMA_WINDOWS_VERSION:-v0.2.0-rc1}
EXPECTED_SHA256=${SOMA_WINDOWS_ZIP_SHA256:-3e5c53f1586d7ff8d3079020632c8d8ebb8d9209ae8e904e17881d30b39a94e1}
ASSET="myth-of-soma-server-windows-$VERSION.zip"
URL="https://github.com/soma-space/myth-of-soma-server-windows/releases/download/$VERSION/$ASSET"
CACHE="$ROOT/.cache/$ASSET"
STAGE="$ROOT/.runtime/extract-$VERSION"
DESTINATION="$ROOT/.runtime/distribution"
PREVIOUS="$ROOT/.runtime/distribution.previous"
VERSION_FILE="$DESTINATION/.soma-release-version"

if [[ -f "$VERSION_FILE" && "$(<"$VERSION_FILE")" == "$VERSION" &&
   -f "$DESTINATION/SHA256SUMS" ]]; then
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
if [[ -d "$PREVIOUS" ]]; then
  find "$PREVIOUS" -mindepth 1 -delete
  rmdir "$PREVIOUS"
fi
if [[ -d "$DESTINATION" ]]; then
  mv "$DESTINATION" "$PREVIOUS"
fi
mv "$source_root" "$DESTINATION"
printf '%s\n' "$VERSION" > "$VERSION_FILE"
find "$STAGE" -mindepth 1 -delete

printf 'Installed checksum-verified server payload at %s\n' "$DESTINATION"
