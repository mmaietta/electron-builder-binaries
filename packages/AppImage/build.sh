#!/bin/bash

# Build script for AppImage tools for multiple platforms
# Compile for all builds possible if on MacOS w/ docker buildx.
# rm -rf out; OS_TARGET=runtime sh build.sh && OS_TARGET=linux sh build.sh && OS_TARGET=darwin sh build.sh

set -e

echo "╔════════════════════════════════════════╗"
echo "║  🔧 AppImage Tools Build Script       ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Detect OS
CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

# Create output directory if it doesn't exist
mkdir -p $CWD/out/AppImage

if [ "$OS_TARGET" = "darwin" ]; then
    echo "🍎 Detected macOS target - Building Darwin binaries..."
    bash $CWD/assets/appimage-mac.sh    
elif [ "$OS_TARGET" = "linux" ]; then
    echo "🐧 Detected Linux target - Building Linux binaries for all architectures..."
    bash $CWD/assets/appimage-linux.sh
else
    echo "📥 Downloading AppImage runtimes..."
    bash $CWD/assets/download-runtime.sh
fi


echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Build Complete!                    ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📂 Directory structure:"
tree $CWD/out/AppImage -L 2 2>/dev/null || find $CWD/out/AppImage -maxdepth 2 -type f

echo ""
echo "🎉 Done!"