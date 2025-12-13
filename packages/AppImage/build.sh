#!/bin/bash

# Build script for AppImage tools for multiple platforms
# Compile for all builds possible if on MacOS w/ docker buildx.
# rm -rf out; TARGET=linux sh build.sh && TARGET=darwin sh build.sh && TARGET=runtime sh build.sh && TARGET=compress sh build.sh

set -e

echo "╔════════════════════════════════════════╗"
echo "║  🔧 AppImage Tools Build Script       ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Detect OS
CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
TARGET=${TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

# VERSIONS
OUTPUT_DIR="$CWD/out"
export DEST="$OUTPUT_DIR/dist" # must be exported
export SQUASHFS_TOOLS_VERSION_TAG="4.6.1"
export APPIMAGE_TYPE2_RELEASE="20251108"

mkdir -p $DEST

if [ "$TARGET" = "darwin" ]; then
    echo "🍎 Detected macOS target - Building Darwin binaries..."
    bash $CWD/assets/appimage-mac.sh    
elif [ "$TARGET" = "linux" ]; then
    echo "🐧 Detected Linux target - Building Linux binaries for all architectures..."
    bash $CWD/assets/appimage-linux.sh
elif [ "$TARGET" = "runtime" ]; then
    echo "📥 Downloading AppImage runtimes into bundle..."
    bash $CWD/assets/download-runtime.sh --install-directory $DEST
elif [ "$TARGET" = "compress" ]; then
    echo "📦 Creating package hierarchy of all AppImage tools and runtimes..."
    OUT_DIR="$OUTPUT_DIR/AppImage" SRC_DIR="$DEST" bash $CWD/assets/bundle-and-compress.sh
else
    echo "❌ Unsupported TARGET: $TARGET"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Build Complete!                    ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📂 Directory structure:"
tree $OUTPUT_DIR -L 3 2>/dev/null || find $OUTPUT_DIR -maxdepth 3 -type f


