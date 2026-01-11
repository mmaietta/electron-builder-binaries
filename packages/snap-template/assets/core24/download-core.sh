#!/usr/bin/env bash
set -euo pipefail

CORE_BASE="core24"
CORE_CHANNEL="stable"
ARCH="${1:-$(uname -m | sed 's/x86_64/amd64/')}"

OUT_DIR="${2:-./offline-assets/core24}"
mkdir -p "$OUT_DIR"

echo "📦 Downloading $CORE_BASE for $ARCH"

snap download "$CORE_BASE" --channel="$CORE_CHANNEL" --target-directory="$OUT_DIR"

SNAP_FILE="$(ls "$OUT_DIR"/${CORE_BASE}_*.snap)"
ASSERT_FILE="$(ls "$OUT_DIR"/${CORE_BASE}_*.assert)"

echo "🔐 Calculating checksums"
sha256sum "$SNAP_FILE" > "$SNAP_FILE.sha256"
sha256sum "$ASSERT_FILE" > "$ASSERT_FILE.sha256"

echo "✅ Downloaded:"
echo "  - $(basename "$SNAP_FILE")"
echo "  - $(basename "$ASSERT_FILE")"
