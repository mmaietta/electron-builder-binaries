#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Build Wine for All Platforms
# ============================================================================
# Builds Wine for all supported platforms and architectures
#
# Arguments:
#   $1 - Wine version (optional, default: 9.0)
#   $2 - Build directory (optional, default: ./build)
# ============================================================================

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    # Minimal logging fallback
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    error_exit() { echo "[ERROR] $*" >&2; exit 1; }
    print_banner() { echo "============================================================================"; echo "$@"; echo "============================================================================"; }
fi

# Parse arguments
WINE_VERSION="${1:-${WINE_VERSION:-9.0}}"
BUILD_DIR="${2:-${BUILD_DIR:-$(pwd)/build}}"

export WINE_VERSION
export BUILD_DIR

print_banner "Build Wine ${WINE_VERSION} for All Platforms"

echo ""
echo "Wine Version:    $WINE_VERSION"
echo "Build Directory: $BUILD_DIR"
echo ""
echo "This will build Wine for:"
echo "  - macOS Intel (x86_64)"
echo "  - macOS Apple Silicon (ARM64)"
echo "  - Linux x86_64 (Docker)"
echo "  - Linux ARM64 (Docker)"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Build cancelled."
    exit 0
fi

# Track build results
BUILDS_ATTEMPTED=0
BUILDS_SUCCEEDED=0
BUILDS_FAILED=0
FAILED_BUILDS=()

# Determine which platform we're running on
HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

# Build function
build_platform() {
    local os="$1"
    local arch="$2"
    local name="$3"
    
    BUILDS_ATTEMPTED=$((BUILDS_ATTEMPTED + 1))
    
    echo ""
    print_banner "Building $name"
    echo ""
    
    if OS_TARGET="$os" PLATFORM_ARCH="$arch" WINE_VERSION="$WINE_VERSION" BUILD_DIR="$BUILD_DIR" bash "$SCRIPT_DIR/../build.sh"; then
        BUILDS_SUCCEEDED=$((BUILDS_SUCCEEDED + 1))
        log_success "$name build completed"
    else
        BUILDS_FAILED=$((BUILDS_FAILED + 1))
        FAILED_BUILDS+=("$name")
        log_error "$name build failed"
    fi
}

# ============================================================================
# Build macOS Platforms
# ============================================================================

if [ "$HOST_OS" = "darwin" ]; then
    # Determine host architecture
    HOST_ARCH="$(uname -m)"
    
    # Build for host architecture first (faster, no emulation)
    if [ "$HOST_ARCH" = "arm64" ]; then
        build_platform "darwin" "arm64" "macOS Apple Silicon (ARM64)"
        build_platform "darwin" "x86_64" "macOS Intel (x86_64)"
    else
        build_platform "darwin" "x86_64" "macOS Intel (x86_64)"
        build_platform "darwin" "arm64" "macOS Apple Silicon (ARM64)"
    fi
else
    log_warn "Not running on macOS, skipping macOS builds"
fi

# ============================================================================
# Build Linux Platforms (via Docker)
# ============================================================================

# Check if Docker is available
if command -v docker &> /dev/null && docker info &>/dev/null; then
    build_platform "linux" "x86_64" "Linux x86_64 (Docker)"
    build_platform "linux" "arm64" "Linux ARM64 (Docker)"
else
    log_warn "Docker not available, skipping Linux builds"
    log_info "Install and start Docker Desktop to build Linux platforms"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
print_banner "Build Summary"

echo ""
echo "Builds Attempted: $BUILDS_ATTEMPTED"
echo "Builds Succeeded: $BUILDS_SUCCEEDED"
echo "Builds Failed:    $BUILDS_FAILED"

if [ $BUILDS_FAILED -gt 0 ]; then
    echo ""
    echo "Failed builds:"
    for build in "${FAILED_BUILDS[@]}"; do
        echo "  - $build"
    done
fi

echo ""
echo "Build artifacts:"
ls -lh "$BUILD_DIR"/*.tar.gz 2>/dev/null || echo "  No archives found"

echo ""

if [ $BUILDS_FAILED -eq 0 ]; then
    log_success "All builds completed successfully!"
    exit 0
else
    log_error "Some builds failed"
    exit 1
fi