#!/usr/bin/env bash
set -euo pipefail

# Root of the project (can be overridden by caller)
ROOT=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)
OUT_DIR="${OUT_DIR:-$ROOT/out}"

BUILD_DIR="/tmp/appimage-bundle-and-compress"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# Input directory containing the zip files
ZIP_DIR="${ZIP_DIR:-$ROOT/out/build}"

tree $ZIP_DIR -L 2 2>/dev/null || find $ZIP_DIR -maxdepth 2 -type f

if [ -z "$(ls -A "$ZIP_DIR"/appimage-*.tar.gz 2>/dev/null)" ]; then
    echo "❌ No input tar.gz files found in $ZIP_DIR"
    exit 1
fi

# ----------------------------
# Runtime → project root
# ----------------------------
echo "Extracting runtime to project root → $BUILD_DIR"
tar -xzf "$ZIP_DIR"/appimage-runtime*.tar.gz -C "$BUILD_DIR"
rm -f "$ZIP_DIR"/appimage-runtime*.tar.gz

# ----------------------------
# macOS → darwin/<arch>
# ----------------------------
for zip in "$ZIP_DIR"/appimage-tools-darwin-*.tar.gz; do
    [[ -e "$zip" ]] || continue
    echo "Extracting macOS → $BUILD_DIR/darwin"
    tar -xzf "$zip" -C "$BUILD_DIR"
    rm -f "$zip"
done

# ----------------------------
# Linux (all architectures) → linux/<arch>
# ----------------------------
LINUX_ZIP="$ZIP_DIR/appimage-tools-linux-all-architectures.tar.gz"
echo "Extracting Linux (all architectures) → $BUILD_DIR/linux"
tar -xzf "$LINUX_ZIP" -C "$BUILD_DIR"
rm -f "$LINUX_ZIP"

ARCHIVE_NAME="appimage-tools-runtime-$APPIMAGE_TYPE2_RELEASE.tar.gz"
rm -f "$OUT_DIR/$ARCHIVE_NAME"
echo "📦 Creating tar.gz bundle: $ARCHIVE_NAME"
(
    cd "$BUILD_DIR"
    tar czf "$OUT_DIR/$ARCHIVE_NAME" .
)
echo "✅ Done!"
echo "Bundle at: $OUT_DIR/$ARCHIVE_NAME"

rm -rf "$BUILD_DIR"