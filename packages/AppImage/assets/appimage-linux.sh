#!/bin/bash

set -e

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

# Build for each architecture separately and extract
PLATFORMS=("linux/amd64" "linux/arm64" "linux/arm/v7")
PLATFORM_NAMES=("amd64" "arm64" "armv7")

for i in "${!PLATFORMS[@]}"; do
    PLATFORM="${PLATFORMS[$i]}"
    NAME="${PLATFORM_NAMES[$i]}"
    
    echo ""
    echo "🚀 Building for ${PLATFORM} (${NAME})..."
    
    # Build for specific platform and output to local directory
    docker buildx build \
        --progress=plain \
        --platform "${PLATFORM}" \
        --output type=local,dest="${DEST}" \
        -f "$ROOT/assets/Dockerfile" \
        .
    
    echo "📦 Extracting files for ${NAME}..."
    
    # Extract the tarball from build output
    if [ -f "${DEST}/appimage-tools-${NAME}.tar.gz" ]; then
        tar xzf "${DEST}/appimage-tools-${NAME}.tar.gz" -C $DEST/.
        rm "${DEST}/appimage-tools-${NAME}.tar.gz"
        echo "✅ Completed ${NAME}"
    else
        echo "❌ Failed to find output for ${NAME}"
        exit 1
    fi
done

# Build i386 separately with i386/ prefix
echo ""
echo "🚀 Building for linux/386 (i386)..."
docker buildx build \
    --progress=plain \
    --platform linux/386 \
    --build-arg PLATFORM_PREFIX="i386/" \
    --build-arg TARGETPLATFORM="linux/386" \
    --build-arg TARGETARCH="386" \
    --output type=local,dest="${DEST}" \
    -f "$ROOT/assets/Dockerfile" \
    .

echo "📦 Extracting files for i386..."
if [ -f "${DEST}/appimage-tools-386.tar.gz" ]; then
    tar xzf "${DEST}/appimage-tools-386.tar.gz" -C $DEST/.
    rm "${DEST}/appimage-tools-386.tar.gz"
    echo "✅ Completed 386"
else
    echo "❌ Failed to find output for 386"
    exit 1
fi

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
