#!/usr/bin/env bash
set -euo pipefail

CORE_BASE="core24"
CORE_CHANNEL="stable"
ARCHES=${1:-all}
OUT_DIR="${2:-./offline-assets/core24}"

if [ "$ARCHES" == "all" ]; then
  ARCHES=("amd64" "arm64")
else
  IFS=' ' read -r -a ARCHES <<< "$ARCHES"
fi

if ! command -v docker &> /dev/null; then
  echo "⚠️  Docker is not installed. Please install Docker to proceed."
  exit 1
fi

rm -rf "$OUT_DIR/$ARCH"

echo "➡️ Downloading $CORE_BASE for ${ARCHES[*]}..."

for ARCH in "${ARCHES[@]}"; do
  echo "📦 Downloading snaps for ${ARCH}..."

  mkdir -p "$OUT_DIR/$ARCH"

  docker run --rm \
    --platform="linux/${ARCH}" \
    -v "$OUT_DIR/$ARCH":/out \
    ubuntu:24.04 bash -c "
      set -exuo pipefail

      apt update
      apt install -y snapd

      echo 'Installing snapd core...'
      snap download core24 \
        --channel=${CORE_CHANNEL} \
        --target-directory=/out

      echo 'Installing GNOME 42 extension...'
      snap download gnome-42-2204 \
        --channel=${CORE_CHANNEL} \
        --target-directory=/out

      chmod a+r /out/*.snap /out/*.assert
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
tree "$OUT_DIR" || find "$OUT_DIR" -type f
