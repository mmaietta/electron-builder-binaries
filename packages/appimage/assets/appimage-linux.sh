#!/bin/bash

set -eo pipefail

SQUASHFS_TOOLS_VERSION_TAG=${SQUASHFS_TOOLS_VERSION_TAG:-"4.6.1"}

ROOT=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
    echo "❌ Error: Docker buildx is not available"
    echo "Please install Docker buildx or use Docker Desktop which includes it"
    exit 1
fi

# Create a new builder instance if it doesn't exist
if ! docker buildx ls | grep -q appimage-builder; then
    echo "🏗️  Creating buildx builder instance..."
    docker buildx create --name appimage-builder --use
fi

# Use the builder
docker buildx use appimage-builder

DEST="${DEST:-$ROOT/out/build}"
TMP_DOCKER_CONTEXT="/tmp/appimage-docker-context"
TMP_DIR="/tmp/appimage-build-linux"
rm -rf $TMP_DIR "$TMP_DOCKER_CONTEXT"
mkdir -p $TMP_DIR "$TMP_DOCKER_CONTEXT"

# ,linux/arm64,linux/arm/v7,linux/386
echo ""
echo "🚀 Building for amd64, arm64, armv7, i386 platforms..."
docker buildx build \
    --platform   "linux/amd64,linux/arm64,linux/arm/v7,linux/386" \
    --build-arg  SQUASHFS_TOOLS_VERSION_TAG="$SQUASHFS_TOOLS_VERSION_TAG" \
    --cache-from type=local,src=.buildx-cache \
    --cache-to   type=local,dest=.buildx-cache,mode=max \
    --output     type=local,dest="${TMP_DOCKER_CONTEXT}" \
    -f           "$ROOT/assets/Dockerfile" \
                 $ROOT

echo ""
echo "📦 Extracting all tarballs..."

# Find and extract all .zip files to TMP_DIR root
find "${TMP_DOCKER_CONTEXT}" -name "*.zip" -type f | while read -r zipfile; do
    echo "  Extracting $(basename "$zipfile")..."
    unzip -q "$zipfile" -d "${TMP_DIR}"
    rm -f "$zipfile"
done


echo "✅ All builds completed and extracted"

# Verify executables have correct permissions
echo "🔐 Verifying executable permissions..."
chmod +x $TMP_DIR/linux/x64/mksquashfs \
    $TMP_DIR/linux/x64/desktop-file-validate \
    $TMP_DIR/linux/x64/opj_decompress \
    $TMP_DIR/linux/ia32/mksquashfs \
    $TMP_DIR/linux/ia32/desktop-file-validate \
    $TMP_DIR/linux/arm64/mksquashfs \
    $TMP_DIR/linux/arm64/desktop-file-validate \
    $TMP_DIR/linux/arm32/mksquashfs

echo ""
echo "✨ Extraction complete!"
echo ""
echo "📂 Directory structure:"
tree $TMP_DIR -L 4 2>/dev/null || find $TMP_DIR -type f

echo ""
echo "Creating zip archive of all builds..."
ARCHIVE_NAME="appimage-tools-linux-all-architectures.zip"
(
    cd "$TMP_DIR"
    zip -r -9 "$DEST/$ARCHIVE_NAME" .
)
echo "✓ Archive created: $DEST/$ARCHIVE_NAME"

rm -rf "$TMP_DIR" "$TMP_DOCKER_CONTEXT"
docker buildx rm appimage-builder
echo ""
echo "🎉 Done!"