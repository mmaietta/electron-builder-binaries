#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Main Build Script - Cross-Platform NSIS Builder
# =============================================================================
# Builds static makensis binaries and bundles for macOS, Linux, and Windows
# with comprehensive plugin support.
# =============================================================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ASSETS_DIR="$SCRIPT_DIR/assets"
OUT_DIR="$SCRIPT_DIR/out"
FINAL_DIR="$OUT_DIR/final"

# Build configuration (can be overridden via environment)
export NSIS_VERSION="${NSIS_VERSION:-3.11}"
export NSIS_BRANCH_OR_COMMIT="${NSIS_BRANCH_OR_COMMIT:-v311}"
export NSIS_SHA256="${NSIS_SHA256:-19e72062676ebdc67c11dc032ba80b979cdbffd3886c60b04bb442cdd401ff4b}"
export ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"

# Detect OS
OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS_TYPE" in
    darwin*) OS_NAME="mac" ;;
    linux*)  OS_NAME="linux" ;;
    mingw*|msys*|cygwin*) OS_NAME="windows" ;;
    *) echo "❌ Unsupported OS: $OS_TYPE"; exit 1 ;;
esac

# Parse command line arguments
BUILD_TARGET="${1:-$OS_NAME}"
CLEAN_BUILD="${CLEAN_BUILD:-false}"

# =============================================================================
# Functions
# =============================================================================

print_banner() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  NSIS Cross-Platform Builder"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Version:    $NSIS_VERSION ($NSIS_BRANCH_OR_COMMIT)"
    echo "  Platform:   $BUILD_TARGET"
    echo "  Output:     $FINAL_DIR"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

clean_output() {
    if [ "$CLEAN_BUILD" = "true" ]; then
        echo "🧹 Cleaning previous builds..."
        rm -rf "$OUT_DIR"
    fi
    mkdir -p "$FINAL_DIR"
}

build_mac() {
    echo "🍎 Building for macOS..."
    if [ ! -f "$ASSETS_DIR/nsis-mac.sh" ]; then
        echo "❌ Missing nsis-mac.sh"
        exit 1
    fi
    bash "$ASSETS_DIR/nsis-mac.sh"
}

build_linux() {
    echo "🐧 Building for Linux..."
    if [ ! -f "$ASSETS_DIR/nsis-linux.sh" ]; then
        echo "❌ Missing nsis-linux.sh"
        exit 1
    fi
    bash "$ASSETS_DIR/nsis-linux.sh"
}

build_windows() {
    echo "🪟 Building for Windows..."
    if [ ! -f "$ASSETS_DIR/nsis-windows.ps1" ]; then
        echo "❌ Missing nsis-windows.ps1"
        exit 1
    fi
    
    if command -v pwsh &> /dev/null; then
        pwsh -File "$ASSETS_DIR/nsis-windows.ps1"
    elif command -v powershell &> /dev/null; then
        powershell -File "$ASSETS_DIR/nsis-windows.ps1"
    else
        echo "❌ PowerShell not found. Cannot build for Windows on this system."
        exit 1
    fi
}

build_all() {
    echo "🌍 Building for all platforms..."
    
    if [ "$OS_NAME" = "mac" ]; then
        build_mac
        echo ""
        echo "⚠️  To build Linux, run: docker run --rm -v \$(pwd):/work -w /work ubuntu:22.04 bash build.sh linux"
        echo "⚠️  To build Windows, run this script on a Windows machine with PowerShell"
    elif [ "$OS_NAME" = "linux" ]; then
        build_linux
        echo ""
        echo "⚠️  To build macOS, run this script on a Mac"
        echo "⚠️  To build Windows, run this script on a Windows machine with PowerShell"
    elif [ "$OS_NAME" = "windows" ]; then
        build_windows
        echo ""
        echo "⚠️  To build macOS, run this script on a Mac"
        echo "⚠️  To build Linux, run: docker run --rm -v \$(pwd):/work -w /work ubuntu:22.04 bash build.sh linux"
    fi
}

verify_builds() {
    echo ""
    echo "📦 Build Summary:"
    echo "─────────────────────────────────────────────────────────────"
    
    for platform in mac linux windows; do
        bundle_file="$OUT_DIR/nsis/nsis-bundle-${platform}-${NSIS_BRANCH_OR_COMMIT}.zip"
        if [ -f "$bundle_file" ]; then
            size=$(du -h "$bundle_file" | cut -f1)
            echo "✅ $platform: $bundle_file ($size)"
        else
            echo "⏭️  $platform: Not built"
        fi
    done
    
    echo "─────────────────────────────────────────────────────────────"
}

show_usage() {
    cat << EOF
Usage: $0 [TARGET] [OPTIONS]

Targets:
  mac       Build for macOS (requires macOS)
  linux     Build for Linux (requires Linux or Docker)
  windows   Build for Windows (requires Windows + PowerShell)
  all       Build for all platforms (limited by current OS)
  
  If no target is specified, builds for the current platform.

Environment Variables:
  NSIS_VERSION           NSIS version (default: 3.11)
  NSIS_BRANCH_OR_COMMIT  Git branch/tag (default: v311)
  ZLIB_VERSION           zlib version (default: 1.3.1)
  CLEAN_BUILD            Clean before build (default: false)

Examples:
  ./build.sh                    # Build for current platform
  ./build.sh linux              # Build for Linux
  CLEAN_BUILD=true ./build.sh   # Clean build for current platform
  ./build.sh all                # Build for all available platforms

EOF
}

# =============================================================================
# Main
# =============================================================================

# Handle help
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    show_usage
    exit 0
fi

# Print banner
print_banner

# Clean if requested
clean_output

# Execute build
case "$BUILD_TARGET" in
    mac|macos|darwin)
        build_mac
        ;;
    linux)
        build_linux
        ;;
    windows|win)
        build_windows
        ;;
    all)
        build_all
        ;;
    *)
        echo "❌ Unknown target: $BUILD_TARGET"
        echo ""
        show_usage
        exit 1
        ;;
esac

# Verify and summarize
verify_builds

echo ""
echo "✅ Build complete!"
echo "📁 Output directory: $OUT_DIR/nsis"
echo ""