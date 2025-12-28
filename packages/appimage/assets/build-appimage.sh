#!/bin/env bash
set -euo pipefail

CWD=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)

SQUASHFS_TOOLS_VERSION_TAG=${SQUASHFS_TOOLS_VERSION_TAG:-"4.6.1"}
DESKTOP_UTILS_DEPS_VERSION_TAG=${DESKTOP_UTILS_DEPS_VERSION_TAG:-"0.28"}

# Detect OS
case "$(uname -s)" in
    Linux*)
        OS="linux"
        ;;
    Darwin*)
        OS="macos"
        ;;
    *)
        echo "❌ Unsupported OS: $(uname -s)"
        exit 1
        ;;
esac

echo "🏗️  AppImage Tools Compiler for $OS"
echo ""

BUILD_DIR="/tmp/appimage-build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
trap "rm -rf $BUILD_DIR" EXIT

# =============================================================================
# Architecture Detection
# =============================================================================
if [ "$OS" = "linux" ]; then
    # Linux: use TARGETPLATFORM from Docker
    get_arch_dir() {
        case "$TARGETPLATFORM" in
            "linux/amd64") echo "x64" ;;
            "linux/386") echo "ia32" ;;
            "linux/arm64") echo "arm64" ;;
            "linux/arm/v7") echo "arm32" ;;
            *) echo "unknown" ;;
        esac
    }
    
    is_x64() { [ "$TARGETPLATFORM" = "linux/amd64" ]; }
    is_ia32() { [ "$TARGETPLATFORM" = "linux/386" ]; }
    is_arm64() { [ "$TARGETPLATFORM" = "linux/arm64" ]; }
    is_arm32() { [ "$TARGETPLATFORM" = "linux/arm/v7" ]; }
    is_x86() { is_x64 || is_ia32; }
    
    ARCH_DIR=$(get_arch_dir)
    if [ "$ARCH_DIR" = "unknown" ]; then
        echo "❌ Unsupported TARGETPLATFORM: $TARGETPLATFORM"
        exit 1
    fi
    
    TARGETARCH="${TARGETARCH:-unknown}"
    TARGETVARIANT="${TARGETVARIANT:-}"

else
    # macOS: use uname
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH_DIR="x86_64"
    elif [ "$ARCH" = "arm64" ]; then
        ARCH_DIR="arm64"
    else
        echo "❌ Unsupported architecture: $ARCH"
        exit 1
    fi
    
    TARGETARCH="$ARCH"
    
    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew is required but not installed"
        echo "   Install from: https://brew.sh"
        exit 1
    fi
    
    # Verify required brew packages are installed
    echo "🔍 Checking Homebrew dependencies..."
    REQUIRED_DEPS=("lzo" "xz" "lz4" "zstd" "desktop-file-utils" "meson" "ninja" "tree")
    MISSING_DEPS=()
    
    for dep in "${REQUIRED_DEPS[@]}"; do
        if ! brew list "$dep" &> /dev/null; then
            MISSING_DEPS+=("$dep")
        else
            echo "   ✅ $dep is installed"
        fi
    done
    
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        echo "❌ Missing required Homebrew packages: ${MISSING_DEPS[*]}"
        brew install ${MISSING_DEPS[*]}
    fi
    echo "   ✅ All required packages installed"
fi

# Setup directories
OUTPUT_DIR=${DEST:-"$CWD/linux"}
DEST="$OUTPUT_DIR/$ARCH_DIR"
LIB_DIR="$OUTPUT_DIR/lib"
LIB_DEST="$LIB_DIR/$ARCH_DIR"

echo "🏗️  Building for $OS/$ARCH_DIR"
echo ""

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "   📥 Cloning squashfs-tools..."
git clone https://github.com/plougher/squashfs-tools.git
cd $BUILD_DIR/squashfs-tools
git checkout $SQUASHFS_TOOLS_VERSION_TAG
echo "   ✅ squashfs-tools cloned"

cd "$BUILD_DIR"
git clone https://gitlab.freedesktop.org/xdg/desktop-file-utils.git
cd $BUILD_DIR/desktop-file-utils
git checkout $DESKTOP_UTILS_DEPS_VERSION_TAG
echo "   ✅ desktop-file-utils cloned"

# =============================================================================
# BUILD SQUASHFS-TOOLS
# =============================================================================
echo "📦 Building squashfs-tools..."

if [ "$OS" = "linux" ]; then
    cd $BUILD_DIR/squashfs-tools/squashfs-tools
    make -j$(nproc) \
        GZIP_SUPPORT=1 \
        XZ_SUPPORT=1 \
        LZO_SUPPORT=1 \
        LZ4_SUPPORT=1 \
        ZSTD_SUPPORT=1 \
        XZ_STATIC=1 \
        LZO_STATIC=1 \
        LZ4_STATIC=1 \
        ZSTD_STATIC=1
    
    mkdir -p "$DEST"
    cp -aL mksquashfs "$DEST/"
    echo "   ✅ Built mksquashfs with static compression libraries"
else
    cd $BUILD_DIR/squashfs-tools/squashfs-tools

    BREW_PREFIX=$(brew --prefix)
    make -j$(sysctl -n hw.ncpu) \
        GZIP_SUPPORT=1 \
        XZ_SUPPORT=1 \
        LZO_SUPPORT=1 \
        LZ4_SUPPORT=1 \
        ZSTD_SUPPORT=1 \
        XZ_STATIC=1 \
        LZO_STATIC=1 \
        LZ4_STATIC=1 \
        ZSTD_STATIC=1 \
        EXTRA_CFLAGS="-I${BREW_PREFIX}/include" \
        EXTRA_LDFLAGS="-L${BREW_PREFIX}/lib"
    
    mkdir -p "$DEST"
    cp mksquashfs "$DEST/"
    chmod +x "$DEST/mksquashfs"
    echo "   ✅ Built mksquashfs with static compression libraries"
fi

# =============================================================================
# BUILD DESKTOP-FILE-UTILS
# =============================================================================
echo ""
echo "📦 Building desktop-file-utils..."
cd "$BUILD_DIR/desktop-file-utils"

BUILD=$BUILD_DIR/desktop-file-utils/build
meson setup "$BUILD" \
  --prefix=/usr \
  --buildtype=release
ninja -C "$BUILD"
DESTDIR="$BUILD" ninja -C "$BUILD" install
cp -aL "$BUILD/usr/bin/desktop-file-validate" "$DEST/"
chmod +x "$DEST/desktop-file-validate"
echo "   ✅ Built desktop-file-validate"

# =============================================================================
# PATCH MACOS BINARIES
# =============================================================================
if [ "$OS" = "macos" ]; then
    echo ""
    echo "🔧 Patching macOS binaries for portability..."
    
    mkdir -p "$DEST/lib"
    for binary in mksquashfs desktop-file-validate; do
        echo "   🔧 Patching $binary..."
        otool -L "$DEST/$binary" | grep -v ":" | grep -v "@" | awk '{print $1}' | while read -r lib; do
            if [[ "$lib" == /usr/local/* ]] || [[ "$lib" == /opt/homebrew/* ]]; then
                libname=$(basename "$lib")
                cp "$lib" "$DEST/lib/$libname"
                echo "      ✅ Copied $libname"
                install_name_tool -change "$lib" "@executable_path/lib/$libname" "$DEST/$binary" 2>/dev/null || \
                install_name_tool -change "$lib" "@loader_path/lib/$libname" "$DEST/$binary" 2>/dev/null || \
                echo "      ⚠️  Could not update path for $lib"
            fi
        done
    done
    echo "   ✅ Binaries patched"
fi

# =============================================================================
# VERIFY BINARIES
# =============================================================================
VERSION_FILE="$DEST/VERSION.txt"
echo ""
echo "🔍 Verifying binaries and recording versions..."
: > "$VERSION_FILE"

if MKSQ_VER=$("$DEST/mksquashfs" -version | head -n1 2>&1); then
    echo "mksquashfs: $MKSQ_VER" >> "$VERSION_FILE"
    echo "   ✅ mksquashfs verified: $MKSQ_VER"
else
    echo "   ❌ mksquashfs verification failed"
    exit 1
fi

if "$DEST/desktop-file-validate" --help > /dev/null 2>&1; then
    if [ "$OS" = "linux" ]; then
        DFV_VER=$(dpkg-query -W -f='${Version}\n' desktop-file-utils 2>&1) || DFV_VER="unknown"
    else
        DFV_VER=$(brew list --versions desktop-file-utils | awk '{print $2}')
    fi
    echo "desktop-file-validate: $DFV_VER" >> "$VERSION_FILE"
    echo "   ✅ desktop-file-validate verified: $DFV_VER"
else
    echo "   ❌ desktop-file-validate verification failed"
    exit 1
fi

# =============================================================================
# BUILD OPENJPEG (Linux x64/arm64 only)
# =============================================================================
if [ "$OS" = "linux" ] && (is_x64 || is_arm64); then
    echo ""
    echo "🖼️  Building OpenJPEG..."
    cd /tmp
    wget -q https://github.com/uclouvain/openjpeg/archive/v2.3.0.tar.gz
    tar xzf v2.3.0.tar.gz
    cd openjpeg-2.3.0
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local > /dev/null
    make -j$(nproc) > /dev/null
    make install DESTDIR=/tmp/openjpeg-install > /dev/null
    
    mkdir -p "$DEST/lib"
    cp -a /tmp/openjpeg-install/usr/local/lib/libopenjp2.* "$DEST/lib/"
    # cp -a /tmp/openjpeg-install/usr/local/lib/openjpeg-2.3 "$DEST/lib/"
    cp -a /tmp/openjpeg-install/usr/local/lib/pkgconfig "$DEST/lib/"
    cp -aL /tmp/openjpeg-install/usr/local/bin/opj_decompress "$DEST/"
    
    # Create symlinks
    cd "$DEST/lib"
    ln -sf libopenjp2.so.2.3.0 libopenjp2.so.7
    ln -sf libopenjp2.so.7 libopenjp2.so
    echo "   ✅ Built OpenJPEG"
fi

# =============================================================================
# COPY RUNTIME LIBRARIES
# =============================================================================
echo ""
echo "📚 Copying runtime libraries..."

mkdir -p "$LIB_DEST"

if [ "$OS" = "linux" ]; then
    # Determine system library directory
    if is_ia32; then
        SYS_LIB_DIR="/usr/lib/i386-linux-gnu"
    elif is_x64; then
        SYS_LIB_DIR="/usr/lib/x86_64-linux-gnu"
    elif is_arm64; then
        SYS_LIB_DIR="/usr/lib/aarch64-linux-gnu"
    elif is_arm32; then
        SYS_LIB_DIR="/usr/lib/arm-linux-gnueabihf"
    fi
    
    # Helper function to find and copy library
    copy_lib() {
        local libname=$1
        local outname=${2:-$libname}
        
        # For i386 appindicator, check extracted .deb first
        if is_ia32 && [[ "$libname" == "libappindicator"* || "$libname" == "libindicator"* ]]; then
            for deb_dir in /tmp/appind /tmp/ind; do
                if [ -f "$deb_dir/usr/lib/i386-linux-gnu/$libname" ]; then
                    cp "$deb_dir/usr/lib/i386-linux-gnu/$libname" "$LIB_DEST/$outname"
                    echo "   ✅ $libname"
                    return 0
                fi
            done
        fi
        
        # Search standard library directories
        local search_dirs=(
            "$SYS_LIB_DIR"
            "/usr/lib/i386-linux-gnu"
            "/usr/lib/x86_64-linux-gnu"
            "/usr/lib/aarch64-linux-gnu"
            "/usr/lib/arm-linux-gnueabihf"
        )
        
        for dir in "${search_dirs[@]}"; do
            if [ -f "$dir/$libname" ]; then
                cp "$dir/$libname" "$LIB_DEST/$outname"
                echo "   ✅ $libname"
                return 0
            fi
        done
        
        echo "   ❌ $libname not found"
        return 1
    }
    
    # Copy required libraries
    copy_lib "libXss.so.1" || exit 1
    copy_lib "libXtst.so.6" || exit 1
    copy_lib "libnotify.so.4" || exit 1
    copy_lib "libgconf-2.so.4" || exit 1
    
    if is_ia32; then
        copy_lib "libappindicator.so.1" || exit 1
        copy_lib "libindicator.so.7" || exit 1
    else
        copy_lib "libappindicator3.so.1" "libappindicator.so.1" || exit 1
        copy_lib "libindicator3.so.7" "libindicator.so.7" || exit 1
    fi
    
else
    # macOS - copy only remaining dynamic dependencies
    # Both binaries should have compression libs statically linked
    
    echo "   🔍 Checking for remaining dynamic dependencies..."
    echo ""
    echo "   mksquashfs dependencies:"
    otool -L "$DEST/mksquashfs" | grep -v ":" | head -10
    
    echo ""
    echo "   desktop-file-validate dependencies:"
    otool -L "$DEST/desktop-file-validate" | grep -v ":" | head -10
    
    BREW_PREFIX=$(brew --prefix)
    
    # Collect all Homebrew dylibs needed by both binaries
    declare dylibs_needed=()
    
    for binary in mksquashfs desktop-file-validate; do
        while IFS= read -r lib; do
            if [[ "$lib" == ${BREW_PREFIX}/* ]]; then
                lib_name=$(basename "$lib")
                dylibs_needed["$lib"]="$lib_name"
            fi
        done < <(otool -L "$DEST/$binary" | grep -v ":" | grep -v "@" | awk '{print $1}')
    done
    
    # Copy all needed dylibs
    if [ ${#dylibs_needed[@]} -gt 0 ]; then
        echo ""
        echo "   📚 Copying ${#dylibs_needed[@]} required dynamic libraries..."
        for lib_path in "${!dylibs_needed[@]}"; do
            lib_name="${dylibs_needed[$lib_path]}"
            if [ -f "$lib_path" ]; then
                cp "$lib_path" "$DEST/$lib_name"
                echo "      ✅ $lib_name"
            else
                echo "      ⚠️  $lib_path not found"
            fi
        done
    else
        echo ""
        echo "   ✅ No Homebrew dependencies needed (fully static or system libs only)"
    fi
fi

echo "   ✅ All libraries copied successfully"

# =============================================================================
# CREATE ARCHIVE
# =============================================================================
echo ""
echo "📦 Creating archive..."

cd "$CWD"

if [ "$OS" = "linux" ]; then
    # Create tarball for Linux extraction from docker container
    tar czf "/appimage-tools-${TARGETARCH}${TARGETVARIANT}.tar.gz" \
        "$(basename "$OUTPUT_DIR")" \
        # "$LIB_DIR" \
    chmod 644 /appimage-tools-*.tar.gz
    
    echo ""
    echo "📂 Final output structure:"
    tree "$CWD" -L 5 2>/dev/null || find "$CWD" -maxdepth 5 -type f
    
    echo ""
    echo "🎉 Build complete!"
    echo "   Archive: /appimage-tools-${TARGETARCH}${TARGETVARIANT}.tar.gz"
else
    # Create zip for macOS
    ARCHIVE_NAME="appimage-tools-macos-${TARGETARCH}.zip"
    mkdir -p "$CWD/out"
    
    (
        cd "$OUTPUT_DIR/.."
        zip -r -9 "$CWD/out/$ARCHIVE_NAME" "$(basename "$OUTPUT_DIR")"
    )
    
    echo ""
    echo "🎉 Build complete!"
    echo "   Archive: $CWD/out/$ARCHIVE_NAME"
    echo ""
    echo "Files created:"
    tree $DEST -L 4 2>/dev/null || find $DEST -type f
    
    # Cleanup build directory
    if [ -d "$BUILD_DIR" ]; then
        echo ""
        echo "🧹 Cleaning up build directory..."
        rm -rf "$BUILD_DIR"
    fi
fi