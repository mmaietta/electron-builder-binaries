#!/bin/bash
set -eou pipefail

BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_NAME="core24"
OUT_DIR="$BASE_DIR/build/$BASE_NAME/electron-runtime-template/base"

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

echo "Downloading pinned base: $BASE_NAME"

snap download "$BASE_NAME"

snap download snapcraft-gnome-3-38
snap download snapcraft-gnome-42

SNAP_FILE=$(ls *.snap)
ASSERT_FILE=$(ls *.assert)

echo "Recording metadata..."
cat > core24.meta <<EOF
base: core24
snap: $SNAP_FILE
assert: $ASSERT_FILE
downloaded: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "Generating checksums..."
sha256sum "$SNAP_FILE" "$ASSERT_FILE" > SHA256SUMS

echo "✓ core24 pinned and recorded"
