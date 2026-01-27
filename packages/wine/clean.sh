#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Clean Build Artifacts
# ============================================================================
# Removes build artifacts and temporary files
#
# Arguments:
#   $1 - Clean level: "build", "all", or "docker" (optional, default: "build")
#   $2 - Build directory (optional, default: ./build)
# ============================================================================

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_warn() { echo "[WARN] $*"; }
fi

# Parse arguments
CLEAN_LEVEL="${1:-build}"
BUILD_DIR="${2:-${BUILD_DIR:-$(pwd)/build}}"

echo "============================================================================"
echo "Clean Build Artifacts"
echo "============================================================================"
echo ""
echo "Clean Level:     $CLEAN_LEVEL"
echo "Build Directory: $BUILD_DIR"
echo ""

case "$CLEAN_LEVEL" in
    build)
        echo "This will remove:"
        echo "  - Build directories (wine64-build-*, wine32-build-*)"
        echo "  - Install directories (*-install-*)"
        echo "  - Docker build directories"
        echo ""
        echo "This will keep:"
        echo "  - Downloaded source archives"
        echo "  - Final Wine distributions"
        echo "  - Docker images"
        ;;
    
    all)
        echo "This will remove:"
        echo "  - All build artifacts"
        echo "  - Downloaded source archives"
        echo "  - Final Wine distributions"
        echo "  - Entire build directory"
        echo ""
        echo "WARNING: This will delete all Wine builds!"
        ;;
    
    docker)
        echo "This will remove:"
        echo "  - All Wine Docker images"
        echo "  - Docker build cache"
        ;;
    
    *)
        echo "Unknown clean level: $CLEAN_LEVEL"
        echo ""
        echo "Usage: $0 [clean_level] [build_dir]"
        echo ""
        echo "Clean levels:"
        echo "  build  - Remove build artifacts (keep downloads and distributions)"
        echo "  all    - Remove everything including distributions"
        echo "  docker - Remove Docker images and cache"
        exit 1
        ;;
esac

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Clean cancelled."
    exit 0
fi

# ============================================================================
# Clean Build Artifacts
# ============================================================================

if [ "$CLEAN_LEVEL" = "build" ] || [ "$CLEAN_LEVEL" = "all" ]; then
    log_info "Cleaning build artifacts..."
    
    if [ "$CLEAN_LEVEL" = "build" ]; then
        # Remove build directories
        rm -rf "$BUILD_DIR"/wine64-build-* \
               "$BUILD_DIR"/wine32-build-* \
               "$BUILD_DIR"/wine-*-install-* \
               "$BUILD_DIR"/docker-build
        
        log_success "Build artifacts cleaned"
    else
        # Remove entire build directory
        if [ -d "$BUILD_DIR" ]; then
            rm -rf "$BUILD_DIR"
            log_success "Build directory removed: $BUILD_DIR"
        else
            log_info "Build directory does not exist: $BUILD_DIR"
        fi
    fi
fi

# ============================================================================
# Clean Docker
# ============================================================================

if [ "$CLEAN_LEVEL" = "docker" ]; then
    if ! command -v docker &> /dev/null; then
        log_warn "Docker not found, skipping Docker cleanup"
        exit 0
    fi
    
    if ! docker info &>/dev/null; then
        log_warn "Docker daemon not running, skipping Docker cleanup"
        exit 0
    fi
    
    log_info "Removing Wine Docker images..."
    
    # Find and remove Wine builder images
    IMAGES=$(docker images --filter=reference='wine-builder:*' -q)
    if [ -n "$IMAGES" ]; then
        echo "$IMAGES" | xargs docker rmi || log_warn "Some images could not be removed"
        log_success "Wine Docker images removed"
    else
        log_info "No Wine Docker images found"
    fi
    
    log_info "Pruning Docker build cache..."
    docker buildx prune -f || log_warn "Failed to prune build cache"
    log_success "Docker build cache pruned"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
log_success "Clean complete!"

if [ "$CLEAN_LEVEL" = "build" ]; then
    echo ""
    echo "To rebuild:"
    echo "  ./build.sh"
fi

if [ "$CLEAN_LEVEL" = "all" ]; then
    echo ""
    echo "To rebuild from scratch:"
    echo "  ./build.sh"
fi