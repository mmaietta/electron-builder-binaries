#!/bin/bash

set -e

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

DEST="$ROOT/out/AppImage"
mkdir -p $DEST
# Build all architectures in one command
PLATFORMS=("linux/amd64" "linux/arm64" "linux/arm/v7")
PLATFORM_NAMES=("amd64" "arm64" "armv7" "386") # 386 will be built separately

echo "🚀 Building for all platforms..."
docker buildx build \
    --platform "$(IFS=,; echo "${PLATFORMS[*]}")" \
    --build-arg SQUASHFS_TOOLS_VERSION_TAG="$SQUASHFS_TOOLS_VERSION_TAG" \
    --output type=local,dest="${DEST}" \
    -f "$ROOT/assets/Dockerfile" \
    .

# Build i386 separately with i386/ prefix
echo ""
echo "🚀 Building for linux/386 (i386)..."
docker buildx build \
    --platform linux/386 \
    --build-arg PLATFORM_PREFIX="i386/" \
    --build-arg TARGETPLATFORM="linux/386" \
    --build-arg TARGETARCH="386" \
    --build-arg SQUASHFS_TOOLS_VERSION_TAG="$SQUASHFS_TOOLS_VERSION_TAG" \
    --output type=local,dest="${DEST}" \
    -f "$ROOT/assets/Dockerfile" \
    .

# Extract files for each architecture
for NAME in "${PLATFORM_NAMES[@]}"; do
    echo ""
    echo "📦 Extracting files for ${NAME}..."
    
    if [ -f "${DEST}/appimage-tools-${NAME}.tar.gz" ]; then
        tar xzf "${DEST}/appimage-tools-${NAME}.tar.gz" -C "${DEST}/."
        rm "${DEST}/appimage-tools-${NAME}.tar.gz"
        echo "✅ Completed ${NAME}"
    else
        echo "❌ Failed to find output for ${NAME}"
        exit 1
    fi
done

echo ""
echo "📁 Organizing directory structure..."

# Verify executables have correct permissions
echo "🔐 Verifying executable permissions..."
chmod +x $DEST/linux-x64/mksquashfs \
    $DEST/linux-x64/desktop-file-validate \
    $DEST/linux-x64/opj_decompress \
    $DEST/linux-ia32/mksquashfs \
    $DEST/linux-ia32/desktop-file-validate \
    $DEST/linux-arm64/mksquashfs \
    $DEST/linux-arm64/desktop-file-validate \
    $DEST/linux-arm32/mksquashfs

echo ""
echo "✨ Extraction complete!"
echo ""
echo "📂 Directory structure:"
tree $ROOT/out/AppImage -L 4 2>/dev/null || find $ROOT/out/AppImage -type f

echo ""
echo "🎉 Done!"
docker buildx rm appimage-builder
