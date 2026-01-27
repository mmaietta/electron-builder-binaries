#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# List Wine Builds
# ============================================================================
# Lists all Wine builds in the build directory with details
#
# Arguments:
#   $1 - Build directory (optional, default: ./build)
# ============================================================================

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*"; }
fi

# Parse arguments
BUILD_DIR="${1:-${BUILD_DIR:-$(pwd)/build}}"

echo "============================================================================"
echo "Wine Builds"
echo "============================================================================"
echo ""
echo "Build Directory: $BUILD_DIR"
echo ""

if [ ! -d "$BUILD_DIR" ]; then
    log_warn "Build directory does not exist: $BUILD_DIR"
    exit 0
fi

# ============================================================================
# List Archives
# ============================================================================

log_info "Build Archives:"
echo ""

ARCHIVES_FOUND=false
for archive in "$BUILD_DIR"/*.tar.gz "$BUILD_DIR"/*.tar.xz; do
    if [ -f "$archive" ]; then
        ARCHIVES_FOUND=true
        FILENAME=$(basename "$archive")
        SIZE=$(du -h "$archive" | cut -f1)
        MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$archive" 2>/dev/null || stat -c "%y" "$archive" 2>/dev/null | cut -d'.' -f1)
        
        printf "  %-50s %10s  %s\n" "$FILENAME" "$SIZE" "$MODIFIED"
    fi
done

if [ "$ARCHIVES_FOUND" = false ]; then
    echo "  No archives found"
fi

# ============================================================================
# List Build Directories
# ============================================================================

echo ""
log_info "Build Directories:"
echo ""

DIRS_FOUND=false
for dir in "$BUILD_DIR"/wine-*/; do
    if [ -d "$dir" ]; then
        DIRNAME=$(basename "$dir")
        
        # Skip intermediate build directories
        if [[ "$DIRNAME" =~ (build|install) ]]; then
            continue
        fi
        
        DIRS_FOUND=true
        
        # Check if it's a valid Wine installation
        if [ -f "$dir/bin/wine64" ] || [ -f "$dir/bin/wine" ]; then
            STATUS="✓"
            
            # Get Wine version
            WINE_BIN=""
            if [ -f "$dir/bin/wine64" ]; then
                WINE_BIN="$dir/bin/wine64"
            elif [ -f "$dir/bin/wine" ]; then
                WINE_BIN="$dir/bin/wine"
            fi
            
            if [ -n "$WINE_BIN" ]; then
                VERSION=$("$WINE_BIN" --version 2>/dev/null || echo "unknown")
            else
                VERSION="unknown"
            fi
        else
            STATUS="✗"
            VERSION="incomplete"
        fi
        
        # Calculate size
        SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1)
        
        printf "  %s %-50s %10s  %s\n" "$STATUS" "$DIRNAME/" "$SIZE" "$VERSION"
    fi
done

if [ "$DIRS_FOUND" = false ]; then
    echo "  No build directories found"
fi

# ============================================================================
# List Downloads
# ============================================================================

if [ -d "$BUILD_DIR/downloads" ]; then
    echo ""
    log_info "Downloaded Sources:"
    echo ""
    
    DOWNLOADS_FOUND=false
    for download in "$BUILD_DIR/downloads"/*; do
        if [ -f "$download" ]; then
            DOWNLOADS_FOUND=true
            FILENAME=$(basename "$download")
            SIZE=$(du -h "$download" | cut -f1)
            
            printf "  %-50s %10s\n" "$FILENAME" "$SIZE"
        fi
    done
    
    if [ "$DOWNLOADS_FOUND" = false ]; then
        echo "  No downloads found"
    fi
fi

# ============================================================================
# Docker Images (if Docker is available)
# ============================================================================

if command -v docker &> /dev/null && docker info &>/dev/null; then
    echo ""
    log_info "Docker Images:"
    echo ""
    
    IMAGES=$(docker images --filter=reference='wine-builder:*' --format "{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" 2>/dev/null)
    
    if [ -n "$IMAGES" ]; then
        echo "$IMAGES" | while IFS=$'\t' read -r image size created; do
            printf "  %-50s %10s  %s\n" "$image" "$size" "$created"
        done
    else
        echo "  No Wine Docker images found"
    fi
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "============================================================================"
echo "Summary"
echo "============================================================================"
echo ""

# Count archives
ARCHIVE_COUNT=$(find "$BUILD_DIR" -maxdepth 1 -name "*.tar.gz" -o -name "*.tar.xz" 2>/dev/null | wc -l | tr -d ' ')
echo "Archives:          $ARCHIVE_COUNT"

# Count build directories
BUILD_DIR_COUNT=$(find "$BUILD_DIR" -maxdepth 1 -type d -name "wine-*" 2>/dev/null | wc -l | tr -d ' ')
echo "Build Directories: $BUILD_DIR_COUNT"

# Total size
if [ -d "$BUILD_DIR" ]; then
    TOTAL_SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1)
    echo "Total Size:        $TOTAL_SIZE"
fi

echo ""