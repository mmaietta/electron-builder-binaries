#!/bin/bash

# Build script for AppImage tools for multiple platforms
# Compile for all builds possible if on MacOS w/ docker buildx.
# rm -rf out; OS_TARGET=runtime sh build.sh && OS_TARGET=linux sh build.sh && OS_TARGET=darwin sh build.sh

set -e

echo "╔════════════════════════════════════════╗"
echo "║  🔧 AppImage Tools Build Script       ║"
echo "╚════════════════════════════════════════╝"
echo ""

# VERSIONS
export SQUASHFS_TOOLS_VERSION_TAG="4.6.1"
export APPIMAGE_TYPE2_RELEASE="20251108"

# Detect OS
CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

# Create output directory if it doesn't exist
OUTPUT_DIR="$CWD/out/AppImage"
mkdir -p $OUTPUT_DIR

if [ "$OS_TARGET" = "darwin" ]; then
    echo "🍎 Detected macOS target - Building Darwin binaries..."
    bash $CWD/assets/appimage-mac.sh    
elif [ "$OS_TARGET" = "linux" ]; then
    echo "🐧 Detected Linux target - Building Linux binaries for all architectures..."
    bash $CWD/assets/appimage-linux.sh
elif [ "$OS_TARGET" = "runtime" ]; then
    echo "📥 Downloading AppImage runtimes into bundle..."
    bash $CWD/assets/download-runtime.sh
else
    ARCHIVE_NAME="appimage-tools-runtime-bundle.zip"
    echo "📦 Creating ZIP bundle: $ARCHIVE_NAME"
    (
    cd "$CWD/out/AppImage"
    zip -r -9 "$CWD/$ARCHIVE_NAME" . >/dev/null
    )
    echo "✅ Done!"
    echo "Bundle at: $OUTPUT_DIR/$ARCHIVE_NAME"
fi


echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Build Complete!                    ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📂 Directory structure:"
tree $OUTPUT_DIR -L 3 2>/dev/null || find $OUTPUT_DIR -maxdepth 3 -type f


