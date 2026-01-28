#!/usr/bin/env bash
set -e

# Wine Portable Bundle Builder
# Compiles Wine from source for distribution

WINE_VERSION=${WINE_VERSION:-11.0}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR=${BUILD_DIR:-$SCRIPT_DIR/build}
PLATFORM_ARCH=${PLATFORM_ARCH:-$(uname -m)}
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

case "$PLATFORM_ARCH" in
    x86_64|amd64|x64) PLATFORM_ARCH="x86_64" ;;
    arm64|aarch64) PLATFORM_ARCH="arm64" ;;
esac

case "$OS_TARGET" in
    darwin|macos) OS_TARGET="darwin" ;;
    linux) OS_TARGET="linux" ;;
esac

export WINE_VERSION BUILD_DIR PLATFORM_ARCH OS_TARGET

echo ""
echo "🍷 Wine Portable Bundle Builder"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Wine Version:    $WINE_VERSION"
echo "Platform:        $OS_TARGET"
echo "Architecture:    $PLATFORM_ARCH"
echo "Build Dir:       $BUILD_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

mkdir -p "$BUILD_DIR"

if [ "$OS_TARGET" = "darwin" ]; then
    bash "$SCRIPT_DIR/assets/build-mac.sh"
# elif [ "$OS_TARGET" = "linux" ]; then
#     bash "$SCRIPT_DIR/scripts/build-linux.sh"
else
    echo "❌ Unsupported OS: $OS_TARGET"
    exit 1
fi

echo ""
echo "✅ Portable Wine bundle complete!"
echo "📦 Output: $BUILD_DIR/wine-${WINE_VERSION}-${OS_TARGET}-${PLATFORM_ARCH}.tar.gz"
echo ""