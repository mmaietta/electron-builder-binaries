#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Check Build Dependencies
# ============================================================================
# Verifies all required build dependencies are installed
#
# Arguments:
#   $1 - Platform to check: "darwin", "linux", "all" (optional, default: auto-detect)
# ============================================================================

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    log_info() { echo "[INFO] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
    log_warn() { echo "[WARN] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
fi

# Parse arguments
CHECK_PLATFORM="${1:-auto}"

# Auto-detect platform if needed
if [ "$CHECK_PLATFORM" = "auto" ]; then
    CHECK_PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
fi

echo "============================================================================"
echo "Build Dependency Check"
echo "============================================================================"
echo ""
echo "Platform: $CHECK_PLATFORM"
echo ""

# Track results
ALL_DEPS_OK=true

# ============================================================================
# Check Common Dependencies
# ============================================================================

log_info "Checking common build tools..."

COMMON_TOOLS=(
    "bash"
    "curl"
    "tar"
    "gcc"
    "make"
    "flex"
    "bison"
    "pkg-config"
)

for tool in "${COMMON_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        VERSION=$("$tool" --version 2>&1 | head -1 || echo "unknown")
        echo "  ✓ $tool ($VERSION)"
    else
        echo "  ✗ $tool (not found)"
        ALL_DEPS_OK=false
    fi
done

# ============================================================================
# Check macOS Dependencies
# ============================================================================

if [ "$CHECK_PLATFORM" = "darwin" ] || [ "$CHECK_PLATFORM" = "all" ]; then
    echo ""
    log_info "Checking macOS dependencies..."
    
    # Check for Xcode Command Line Tools
    if xcode-select -p &>/dev/null; then
        echo "  ✓ Xcode Command Line Tools"
    else
        echo "  ✗ Xcode Command Line Tools (install with: xcode-select --install)"
        ALL_DEPS_OK=false
    fi
    
    # Check for Homebrew
    if command -v brew &> /dev/null; then
        BREW_VERSION=$(brew --version | head -1)
        echo "  ✓ Homebrew ($BREW_VERSION)"
        
        echo ""
        log_info "Checking Homebrew packages..."
        
        BREW_PACKAGES=(
            "mingw-w64"
            "freetype"
            "libpng"
            "jpeg-turbo"
            "libtiff"
            "little-cms2"
            "libxml2"
            "libxslt"
            "xz"
            "gnutls"
            "sdl2"
            "faudio"
            "openal-soft"
        )
        
        MISSING_PACKAGES=()
        
        for pkg in "${BREW_PACKAGES[@]}"; do
            if brew list "$pkg" &>/dev/null; then
                VERSION=$(brew list --versions "$pkg" | head -1)
                echo "  ✓ $VERSION"
            else
                echo "  ✗ $pkg (not installed)"
                MISSING_PACKAGES+=("$pkg")
                ALL_DEPS_OK=false
            fi
        done
        
        if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
            echo ""
            log_warn "Missing Homebrew packages: ${MISSING_PACKAGES[*]}"
            echo ""
            echo "Install with:"
            echo "  brew install ${MISSING_PACKAGES[*]}"
        fi
    else
        echo "  ✗ Homebrew (not installed)"
        echo ""
        echo "Install Homebrew from: https://brew.sh"
        ALL_DEPS_OK=false
    fi
fi

# ============================================================================
# Check Docker Dependencies (for Linux builds)
# ============================================================================

if [ "$CHECK_PLATFORM" = "linux" ] || [ "$CHECK_PLATFORM" = "all" ] || [ "$CHECK_PLATFORM" = "darwin" ]; then
    echo ""
    log_info "Checking Docker (required for Linux builds)..."
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        echo "  ✓ Docker ($DOCKER_VERSION)"
        
        # Check if Docker daemon is running
        if docker info &>/dev/null; then
            echo "  ✓ Docker daemon is running"
            
            # Check Docker buildx
            if docker buildx version &>/dev/null; then
                BUILDX_VERSION=$(docker buildx version)
                echo "  ✓ Docker buildx ($BUILDX_VERSION)"
            else
                echo "  ✗ Docker buildx (not available)"
                echo "    Update Docker to version 19.03 or later"
                ALL_DEPS_OK=false
            fi
            
            # Check available platforms
            echo ""
            log_info "Docker available platforms:"
            docker buildx ls | grep -E "linux/(amd64|arm64)" || true
        else
            echo "  ✗ Docker daemon is not running"
            echo "    Start Docker Desktop to enable Docker builds"
            ALL_DEPS_OK=false
        fi
    else
        echo "  ✗ Docker (not installed)"
        echo "    Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
        echo "    Required for Linux builds"
        if [ "$CHECK_PLATFORM" = "linux" ]; then
            ALL_DEPS_OK=false
        fi
    fi
fi

# ============================================================================
# Check Linux Dependencies (native)
# ============================================================================

if [ "$CHECK_PLATFORM" = "linux" ]; then
    echo ""
    log_info "Checking Linux native build dependencies..."
    
    # Check for multilib support
    if dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
        echo "  ✓ i386 architecture enabled"
    else
        echo "  ✗ i386 architecture not enabled"
        echo "    Enable with: sudo dpkg --add-architecture i386 && sudo apt update"
        ALL_DEPS_OK=false
    fi
    
    # Check for essential packages
    LINUX_PACKAGES=(
        "build-essential"
        "gcc-multilib"
        "g++-multilib"
        "mingw-w64"
        "libfreetype6-dev"
        "libgnutls28-dev"
        "libpng-dev"
        "libjpeg-dev"
        "libtiff-dev"
        "liblcms2-dev"
        "libxml2-dev"
        "libxslt1-dev"
        "libopenal-dev"
        "libsdl2-dev"
        "libfaudio-dev"
    )
    
    MISSING_PACKAGES=()
    
    for pkg in "${LINUX_PACKAGES[@]}"; do
        if dpkg -l "$pkg" &>/dev/null; then
            echo "  ✓ $pkg"
        else
            echo "  ✗ $pkg (not installed)"
            MISSING_PACKAGES+=("$pkg")
            ALL_DEPS_OK=false
        fi
    done
    
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        echo ""
        log_warn "Missing packages: ${MISSING_PACKAGES[*]}"
        echo ""
        echo "Install with:"
        echo "  sudo apt update && sudo apt install -y ${MISSING_PACKAGES[*]}"
    fi
fi

# ============================================================================
# System Information
# ============================================================================

echo ""
log_info "System Information:"
echo "  OS:           $(uname -s)"
echo "  Architecture: $(uname -m)"
echo "  Kernel:       $(uname -r)"

if [ "$(uname -s)" = "Darwin" ]; then
    echo "  macOS:        $(sw_vers -productVersion)"
fi

# CPU info
if command -v nproc &> /dev/null; then
    echo "  CPU Cores:    $(nproc)"
elif command -v sysctl &> /dev/null; then
    echo "  CPU Cores:    $(sysctl -n hw.ncpu)"
fi

# Memory info
if command -v free &> /dev/null; then
    echo "  Memory:       $(free -h | awk '/^Mem:/{print $2}')"
elif command -v sysctl &> /dev/null; then
    MEM_BYTES=$(sysctl -n hw.memsize)
    MEM_GB=$((MEM_BYTES / 1024 / 1024 / 1024))
    echo "  Memory:       ${MEM_GB}GB"
fi

# Disk space
echo "  Disk Space:   $(df -h . | awk 'NR==2 {print $4 " available"}')"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "============================================================================"

if [ "$ALL_DEPS_OK" = true ]; then
    log_success "All dependencies satisfied!"
    echo ""
    echo "You can now build Wine:"
    echo "  ./build.sh"
    exit 0
else
    log_error "Some dependencies are missing!"
    echo ""
    echo "Please install the missing dependencies listed above."
    exit 1
fi