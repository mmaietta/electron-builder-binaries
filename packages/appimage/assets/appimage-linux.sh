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
trap "docker buildx rm appimage-builder" EXIT

DEST="${DEST:-$ROOT/out/build}"
mkdir -p $DEST

# ,linux/arm64,linux/arm/v7,linux/386
echo ""
echo "🚀 Building for amd64, arm64, armv7, i386 platforms..."
docker buildx build \
    --platform   "linux/amd64,linux/arm64,linux/arm/v7,linux/386" \
    --build-arg  SQUASHFS_TOOLS_VERSION_TAG="$SQUASHFS_TOOLS_VERSION_TAG" \
    --cache-from type=local,src=.buildx-cache \
    --cache-to   type=local,dest=.buildx-cache,mode=max \
    --output     type=local,dest="${DEST}" \
    -f           "$ROOT/assets/Dockerfile" \
                 $ROOT

echo ""
echo "📦 Extracting all tarballs..."

# Find and extract all .tar.gz files to DEST root
find "${DEST}" -name "*.tar.gz" -type f | while read -r tarball; do
    echo "  Extracting $(basename "$tarball")..."
    tar xzf "$tarball" -C "${DEST}"
    rm -r "$(dirname "$tarball")"
done

echo "✅ All builds completed and extracted"

# Verify executables have correct permissions
echo "🔐 Verifying executable permissions..."
chmod +x $DEST/linux/x64/mksquashfs \
    $DEST/linux/x64/desktop-file-validate \
    $DEST/linux/x64/opj_decompress \
    $DEST/linux/ia32/mksquashfs \
    $DEST/linux/ia32/desktop-file-validate \
    $DEST/linux/arm64/mksquashfs \
    $DEST/linux/arm64/desktop-file-validate \
    $DEST/linux/arm32/mksquashfs

echo ""
echo "✨ Extraction complete!"
echo ""
echo "📂 Directory structure:"
tree $DEST -L 4 2>/dev/null || find $DEST -type f

echo ""
echo "Creating zip archive of all builds..."
ARCHIVE_NAME="appimage-tools-linux-all-architectures.zip"
(
    cd "$DEST"
    zip -r -9 "$ROOT/out/$ARCHIVE_NAME" .
)
echo "✓ Archive created: $ROOT/out/$ARCHIVE_NAME"

echo ""
echo "🎉 Done!"