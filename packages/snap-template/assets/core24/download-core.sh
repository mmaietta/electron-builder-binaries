#!/usr/bin/env bash
set -euo pipefail

CORE_BASE="core24"
CORE_CHANNEL="stable"
ARCHES=(amd64 arm64)
OUT_DIR="${2:-./offline-assets/core24}"

rm -rf "$OUT_DIR"

echo "📦 Downloading $CORE_BASE and gnome extensions"

echo "➡️ Downloading $CORE_BASE for ${ARCHES[*]}..."

for ARCH in "${ARCHES[@]}"; do
  echo "📦 Downloading snaps for ${ARCH}..."

  mkdir -p "$OUT_DIR/$ARCH"

  docker run --rm \
    --platform="linux/${ARCH}" \
    -v "$OUT_DIR/$ARCH":/out \
    ubuntu:24.04 bash -c "
      set -euo pipefail

      apt update
      apt install -y snapd

      snap download core24 \
        --channel=${CORE_CHANNEL} \
        --target-directory=/out

      snap download gnome-42-2204 \
        --channel=${CORE_CHANNEL} \
        --target-directory=/out
    "
done

for ARCH in "${ARCHES[@]}"; do
  (
    cd "$OUT_DIR/$ARCH"
    shasum -a 256 *.snap *.assert > SHA256SUMS
  )
done

echo "✓ Downloaded $CORE_BASE and GNOME extensions to $OUT_DIR"
echo "Contents:"
tree "$OUT_DIR" | find "$OUT_DIR" -type f