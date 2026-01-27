#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Wine Build Script - Main Entry Point
# ============================================================================
# This script orchestrates Wine compilation for different platforms
#
# Environment Variables:
#   OS_TARGET        - Target OS: linux, darwin, windows (default: auto-detect)
#   PLATFORM_ARCH    - Target architecture: x86_64, arm64, aarch64 (default: x86_64)
#   WINE_VERSION     - Wine version to build (default: 9.0)
#   BUILD_DIR        - Build output directory (default: ./build)
#   ENABLE_32BIT     - Build 32-bit support (default: true for linux, false for darwin)
# ============================================================================

# ----------------------------
# Configuration
# ----------------------------
export WINE_VERSION="${WINE_VERSION:-9.0}"
export PLATFORM_ARCH="${PLATFORM_ARCH:-x86_64}"
export BUILD_DIR="${BUILD_DIR:-$(pwd)/build}"
export ENABLE_32BIT="${ENABLE_32BIT:-auto}"

# Get script directory
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect OS if not specified
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

# Normalize OS name
case "$OS_TARGET" in
    darwin|macos|osx)
        OS_TARGET="darwin"
        ;;
    linux)
        OS_TARGET="linux"
        ;;
    windows|win|mingw*)
        OS_TARGET="windows"
        ;;
    *)
        echo "Unknown OS target: $OS_TARGET"
        exit 1
        ;;
esac

# Normalize architecture
case "$PLATFORM_ARCH" in
    x86_64|amd64|x64)
        PLATFORM_ARCH="x86_64"
        ;;
    arm64|aarch64)
        PLATFORM_ARCH="arm64"
        ;;
    *)
        echo "Unknown architecture: $PLATFORM_ARCH"
        exit 1
        ;;
esac

# Set 32-bit build default based on platform
if [ "$ENABLE_32BIT" = "auto" ]; then
    if [ "$OS_TARGET" = "darwin" ]; then
        ENABLE_32BIT="false"  # macOS dropped 32-bit support
    else
        ENABLE_32BIT="true"
    fi
fi

export ENABLE_32BIT

# ----------------------------
# Display Configuration
# ----------------------------
echo "============================================================================"
echo "Wine Build Configuration"
echo "============================================================================"
echo "Wine Version:    $WINE_VERSION"
echo "Target OS:       $OS_TARGET"
echo "Architecture:    $PLATFORM_ARCH"
echo "Build Directory: $BUILD_DIR"
echo "32-bit Support:  $ENABLE_32BIT"
echo "============================================================================"
echo ""

# Create build directory
mkdir -p "$BUILD_DIR"

# ----------------------------
# Execute Platform-Specific Build
# ----------------------------
if [ "$OS_TARGET" = "linux" ]; then
    echo "Building Wine for Linux..."
    bash "$CWD/scripts/build-linux.sh" "$WINE_VERSION" "$PLATFORM_ARCH" "$BUILD_DIR" "$ENABLE_32BIT"
    
elif [ "$OS_TARGET" = "darwin" ]; then
    echo "Building Wine for macOS..."
    bash "$CWD/scripts/build-mac.sh" "$WINE_VERSION" "$PLATFORM_ARCH" "$BUILD_DIR" "$ENABLE_32BIT"
    
elif [ "$OS_TARGET" = "windows" ]; then
    echo "Building Wine for Windows is not supported."
    echo "Wine runs ON Windows to execute Windows applications."
    echo "If you meant to cross-compile Wine with MinGW, this is not the standard use case."
    exit 1
    
fi

# ----------------------------
# Build Complete
# ----------------------------
echo ""
echo "============================================================================"
echo "✓ Wine Build Complete!"
echo "============================================================================"
echo "Output location: $BUILD_DIR/wine-${WINE_VERSION}-${OS_TARGET}-${PLATFORM_ARCH}"
echo "============================================================================"