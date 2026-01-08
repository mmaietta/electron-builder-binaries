#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Main Build Script - Cross-Platform NSIS Builder
# =============================================================================
# Orchestrates building NSIS bundles for all platforms
#
# Build order:
#   1. Base (Windows) - Downloads official NSIS with all data files
#   2. Linux         - Compiles native Linux binary, injects into base
#   3. macOS         - Compiles native macOS binary, injects into base
#
# Each platform can be built independently, but they all require the base.
# =============================================================================

export NSIS_VERSION="3.10"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ASSETS_DIR="$SCRIPT_DIR/assets"
OUT_DIR="$SCRIPT_DIR/out"

# Build configuration
export NSIS_VERSION="${NSIS_VERSION:-3.10}"
export NSIS_BRANCH_OR_COMMIT="${NSIS_BRANCH_OR_COMMIT:-v310}"

# Detect current OS
OS_TYPE=${TARGET:-$(uname -s | tr '[:upper:]' '[:lower:]')}
case "$OS_TYPE" in
    darwin*) CURRENT_OS="mac" ;;
    linux*)  CURRENT_OS="linux" ;;
    *) CURRENT_OS="all" ;;
esac

BUILD_TARGET="${1:-}"

# =============================================================================
# Functions
# =============================================================================

print_banner() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  NSIS Cross-Platform Builder"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Version:    $NSIS_VERSION ($NSIS_BRANCH_OR_COMMIT)"
    echo "  Current OS: $CURRENT_OS"
    echo "  Target:     ${BUILD_TARGET:-default}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

build_base() {
    echo "📦 Building base bundle (Windows + plugins)..."
    echo ""
    
    if [ ! -f "$ASSETS_DIR/nsis-windows.sh" ]; then
        echo "❌ Missing nsis-windows.sh"
        exit 1
    fi
    
    bash "$ASSETS_DIR/nsis-windows.sh"
}

build_linux() {
    echo "🐧 Building Linux binary..."
    echo ""
    
    # Check if base exists
    local base_bundle="$OUT_DIR/nsis/nsis-bundle-base-$NSIS_BRANCH_OR_COMMIT.tar.gz"
    if [ ! -f "$base_bundle" ]; then
        echo "⚠️  Base bundle not found, building it first..."
        build_base
        echo ""
    fi
    
    if [ ! -f "$ASSETS_DIR/nsis-linux.sh" ]; then
        echo "❌ Missing nsis-linux.sh"
        exit 1
    fi
    
    bash "$ASSETS_DIR/nsis-linux.sh"
}

build_mac() {
    echo "🍎 Building macOS binary..."
    echo ""
    
    # Check if base exists
    local base_bundle="$OUT_DIR/nsis/nsis-bundle-base-$NSIS_BRANCH_OR_COMMIT.tar.gz"
    if [ ! -f "$base_bundle" ]; then
        echo "⚠️  Base bundle not found, building it first..."
        build_base
        echo ""
    fi
    
    if [ ! -f "$ASSETS_DIR/nsis-mac.sh" ]; then
        echo "❌ Missing nsis-mac.sh"
        exit 1
    fi
    
    bash "$ASSETS_DIR/nsis-mac.sh"
}

build_all() {
    echo "🌍 Building all available platforms..."
    echo ""
    build_base
    build_mac
    build_linux
}

verify_builds() {
    echo ""
    echo "📦 Build Summary"
    echo "═══════════════════════════════════════════════════════════════"
    
    local base_bundle="$OUT_DIR/nsis/nsis-bundle-base-$NSIS_BRANCH_OR_COMMIT.tar.gz"
    local linux_bundle="$OUT_DIR/nsis/nsis-bundle-linux-$NSIS_BRANCH_OR_COMMIT.tar.gz"
    local mac_bundle="$OUT_DIR/nsis/nsis-bundle-mac-$NSIS_BRANCH_OR_COMMIT.tar.gz"
    
    if [ -f "$base_bundle" ]; then
        local size=$(du -h "$base_bundle" | cut -f1)
        echo "  ✅ Base (Windows):  $base_bundle ($size)"
    else
        echo "  ⏭️  Base (Windows):  Not built"
    fi
    
    if [ -f "$linux_bundle" ]; then
        local size=$(du -h "$linux_bundle" | cut -f1)
        echo "  ✅ Linux:           $linux_bundle ($size)"
    else
        echo "  ⏭️  Linux:           Not built"
    fi
    
    if [ -f "$mac_bundle" ]; then
        local size=$(du -h "$mac_bundle" | cut -f1)
        echo "  ✅ macOS:           $mac_bundle ($size)"
    else
        echo "  ⏭️  macOS:           Not built"
    fi
    
    echo "═══════════════════════════════════════════════════════════════"
}

show_usage() {
    cat << EOF
Usage: $0 [TARGET]

Targets:
  base      Build base bundle (Windows + plugins + data files)
  linux     Build Linux native binary (requires Docker)
  mac       Build macOS native binary (requires macOS)
  all       Build base + current platform binary
  
  If no target specified, builds 'all'

Environment Variables:
  NSIS_VERSION           NSIS version (default: 3.10)
  NSIS_BRANCH_OR_COMMIT  Git branch/tag (default: v310)

Build Order:
  1. Base bundle must be built first (contains Windows binary + data)
  2. Linux/Mac builds inject their native binaries into the base bundle

Examples:
  ./build.sh              # Build base + current platform
  ./build.sh base         # Build only the base bundle
  ./build.sh linux        # Build Linux binary (requires Docker, builds base if needed)
  ./build.sh mac          # Build macOS binary (requires macOS, builds base if needed)
  
Platform Requirements:
  Base:   Any OS with bash, curl, unzip
  Linux:  Docker (can run on any OS)
  macOS:  Must run on macOS with Xcode Command Line Tools

EOF
}

# =============================================================================
# Main
# =============================================================================

# Handle help
if [ "$BUILD_TARGET" = "-h" ] || [ "$BUILD_TARGET" = "--help" ]; then
    show_usage
    exit 0
fi

# Print banner
print_banner

# Execute build
case "$BUILD_TARGET" in
    ""|all)
        build_all
        ;;
    base|windows|win)
        build_base
        ;;
    linux)
        build_linux
        ;;
    mac|macos|darwin)
        build_mac
        ;;
    *)
        echo "❌ Unknown target: $BUILD_TARGET"
        echo ""
        show_usage
        exit 1
        ;;
esac

# Summary
verify_builds

echo ""
echo "✅ Build complete!"
echo ""