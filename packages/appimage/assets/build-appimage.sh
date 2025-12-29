#!/bin/env bash
set -exuo pipefail

CWD=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)

SQUASHFS_TOOLS_VERSION_TAG=${SQUASHFS_TOOLS_VERSION_TAG:-"4.6.1"}
DESKTOP_UTILS_DEPS_VERSION_TAG=${DESKTOP_UTILS_DEPS_VERSION_TAG:-"0.28"}

# Detect OS
case "$(uname -s)" in
    Linux*)
        OS="linux"
    ;;
    Darwin*)
        OS="darwin"
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
    
else
    
    # macOS: use uname
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH_DIR="x64" # map to NodeJS process.arch
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
    REQUIRED_DEPS=("lzo" "xz" "lz4" "zstd" "meson" "ninja" "tree")
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
echo "   Building Target: $TARGETARCH"
echo ""
TARGETVARIANT="${TARGETVARIANT:-}"

# =============================================================================
# Setup directories
DEST="${DEST:-$CWD/out/build}"

TEMP_DIR=${TEMP_DIR:-"/tmp/appimage-output"}
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# build tools
OS_OUTPUT="$TEMP_DIR/$OS"
ARCH_OUTPUT_DIR="$OS_OUTPUT/$ARCH_DIR"

# lib for runtimes go at root
LIB_DIR="$TEMP_DIR/lib"
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
    
    mkdir -p "$ARCH_OUTPUT_DIR"
    cp -aL mksquashfs "$ARCH_OUTPUT_DIR/"
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
    
    mkdir -p "$ARCH_OUTPUT_DIR"
    cp mksquashfs "$ARCH_OUTPUT_DIR/"
    chmod +x "$ARCH_OUTPUT_DIR/mksquashfs"
    echo "   ✅ Built mksquashfs"
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
cp -aL "$BUILD/usr/bin/desktop-file-validate" "$ARCH_OUTPUT_DIR/"
chmod +x "$ARCH_OUTPUT_DIR/desktop-file-validate"
echo "   ✅ Built desktop-file-validate"

# =============================================================================
# PATCH BINARIES
# note: limit to only mksquashfs. (smaller scope for packaging)
EXECS_TO_PATCH=("mksquashfs")
# =============================================================================
copy_lib_recursive() {
    local lib_path="$1"
    local dest_dir="$2"
    local libname
    libname=$(basename "$lib_path")
    
    # Already handled
    if [ -e "$dest_dir/$libname" ]; then
        return 0
    fi
    
    # Resolve real file
    local real_file
    real_file=$(readlink -f "$lib_path")
    
    # Copy real file
    cp -a "$real_file" "$dest_dir/"
    echo "      ✅ $libname"
    
    # Recreate symlink if this is one
    if [ -L "$lib_path" ]; then
        ln -sf "$(basename "$real_file")" "$dest_dir/$libname"
        
        # Follow symlink chain safely
        local next_target
        next_target=$(readlink "$lib_path")
        
        if [ -n "$next_target" ]; then
            if [[ "$next_target" != /* ]]; then
                next_target="$(dirname "$lib_path")/$next_target"
            fi
            copy_lib_recursive "$next_target" "$dest_dir"
        fi
    fi
}

if [ "$OS" = "darwin" ]; then
    echo ""
    echo "🔧 Patching macOS binaries for portability..."
    
    mkdir -p "$ARCH_OUTPUT_DIR/lib"
    
    find "$ARCH_OUTPUT_DIR" -type f -executable | while read -r binary; do
        
        if [[ " ${EXECS_TO_PATCH[*]} " == *"$(basename "$binary")"* ]]; then
            continue
        fi
        
        echo "   🔧 Patching $binary..."
        otool -L "$binary" | grep -v ":" | grep -v "@" | awk '{print $1}' | while read -r lib; do
            if [[ "$lib" == /usr/local/* ]] || [[ "$lib" == /opt/homebrew/* ]]; then
                libname=$(basename "$lib")
                cp "$lib" "$ARCH_OUTPUT_DIR/lib/$libname"
                echo "      ✅ Copied $libname"
                install_name_tool -change "$lib" "@executable_path/lib/$libname" "$binary" 2>/dev/null || \
                install_name_tool -change "$lib" "@loader_path/lib/$libname" "$binary" 2>/dev/null || \
                echo "      ⚠️  Could not update path for $lib"
            fi
        done
        echo "   🔍 Checking $(basename "$binary")..."
        
        otool -L "$binary"   | grep -v ":" | awk '{print $1}' | while read -r lib; do
            case "$lib" in
                @executable_path/*|@loader_path/*)
                    echo "      ✅ $lib"
                ;;
                /usr/lib/*)
                    # system libraries are allowed
                ;;
                *)
                    echo "      ❌ Non-portable dependency: $lib"
                    exit 1
                ;;
            esac
        done
    done
    
    echo "   ✅ macOS binaries are portable"
    
else
    echo ""
    echo "🔧 Patching Linux binaries for portability..."
    
    mkdir -p "$ARCH_OUTPUT_DIR/lib"
    
    
    
    # Recursively find all ELF binaries in a directory
    find "$ARCH_OUTPUT_DIR" -type f -executable | while read -r binary; do
        
        # note: limit to only mksquashfs. (smaller scope for packaging)
        if [ "$(basename "$binary")" != "mksquashfs" ]; then
            continue
        fi
        
        echo "   🔧 Patching $(basename "$binary")..."
        
        # Collect all non-system shared library dependencies
        ldd "$binary" \
        | awk '/=> \// { print $3 }' \
        | while read -r lib; do
            libname=$(basename "$lib")
            
            # Skip system libraries
            case "$libname" in
                libc.so.*|ld-linux*.so.*|libpthread.so.*|librt.so.*|libdl.so.*)
                    continue
                ;;
            esac
            
            echo "      🔄 Copying $libname and its symlink chain..."
            copy_lib_recursive "$lib" "$ARCH_OUTPUT_DIR/lib"
        done
        
        # Make the binary hermetic
        patchelf --remove-rpath "$binary" 2>/dev/null || true
        patchelf --set-rpath '$ORIGIN/../lib' "$binary"
        
        # Verify all dependencies are now local or system
        ldd "$binary" | while read -r line; do
            case "$line" in
                linux-gate.so*|linux-vdso.so*)
                    # kernel-provided VDSO
                ;;
                /lib*/ld-linux*.so*'('*')')
                    # ELF dynamic loader (absolute path form)
                ;;
                *"=> not found"*)
                    echo "      ❌ Missing dependency: $line"
                    exit 1
                ;;
                *"=> $ARCH_OUTPUT_DIR/lib/"*)
                    lib=$(echo "$line" | awk '{print $1}')
                    echo "      ✅ $lib (local)"
                ;;
                *"=> /lib/"*|*"=> /usr/lib/"*)
                    # glibc system libs
                ;;
                *)
                    echo "      ❌ Non-portable dependency: $line"
                    exit 1
                ;;
            esac
        done
    done
    
    LD_LIBRARY_PATH= "$ARCH_OUTPUT_DIR/mksquashfs" -version > /dev/null 2>&1 || {
        echo "      ❌ mksquashfs failed to run"
        exit 1
    }
    LD_LIBRARY_PATH= "$ARCH_OUTPUT_DIR/desktop-file-validate" --help > /dev/null 2>&1 || {
        echo "      ❌ desktop-file-validate failed to run"
        exit 1
    }
fi

# =============================================================================
# VERIFY BINARIES
# =============================================================================
VERSION_FILE="$ARCH_OUTPUT_DIR/VERSION.txt"
echo ""
echo "🔍 Verifying binaries and recording versions..."
: > "$VERSION_FILE"

if MKSQ_VER=$("$ARCH_OUTPUT_DIR/mksquashfs" -version | head -n1 2>&1); then
    echo "mksquashfs: $MKSQ_VER" >> "$VERSION_FILE"
    echo "   ✅ mksquashfs verified: $MKSQ_VER"
else
    echo "   ❌ mksquashfs verification failed"
    exit 1
fi

if "$ARCH_OUTPUT_DIR/desktop-file-validate" --help > /dev/null 2>&1; then
    echo "desktop-file-validate: $DESKTOP_UTILS_DEPS_VERSION_TAG" >> "$VERSION_FILE"
    echo "   ✅ desktop-file-validate verified: $DESKTOP_UTILS_DEPS_VERSION_TAG"
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
    mkdir -p /tmp/openjpeg-build
    cd /tmp/openjpeg-build
    wget -q https://github.com/uclouvain/openjpeg/archive/v2.3.0.tar.gz
    tar xzf v2.3.0.tar.gz
    cd openjpeg-2.3.0
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local > /dev/null
    make -j$(nproc) > /dev/null
    make install DESTDIR=/tmp/openjpeg-install
    
    mkdir -p "$ARCH_OUTPUT_DIR/lib"
    cp -a /tmp/openjpeg-install/usr/local/lib/libopenjp2.* "$ARCH_OUTPUT_DIR/lib/"
    # cp -a /tmp/openjpeg-install/usr/local/lib/openjpeg-2.3 "$ARCH_OUTPUT_DIR/lib/"
    cp -a /tmp/openjpeg-install/usr/local/lib/pkgconfig "$ARCH_OUTPUT_DIR/lib/"
    cp -aL /tmp/openjpeg-install/usr/local/bin/opj_decompress "$ARCH_OUTPUT_DIR/"
    
    rm -rf /tmp/openjpeg-build /tmp/openjpeg-install
    # Create symlinks
    cd "$ARCH_OUTPUT_DIR/lib"
    ln -sf libopenjp2.so.2.3.0 libopenjp2.so.7
    ln -sf libopenjp2.so.7 libopenjp2.so
    echo "   ✅ Built OpenJPEG"
fi

# =============================================================================
# COPY RUNTIME LIBRARIES
# =============================================================================
echo ""
echo "📚 Copying runtime libraries..."

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
                    copy_lib_recursive "$deb_dir/usr/lib/i386-linux-gnu/$libname" "$LIB_DEST"
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
                copy_lib_recursive "$dir/$libname" "$LIB_DEST"
                echo "   ✅ $libname"
                return 0
            fi
        done
        
        echo "   ❌ $libname not found"
        return 1
    }
    
    # Copy required libraries
    mkdir -p "$LIB_DEST"
    
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
fi

echo "   ✅ All libraries copied successfully"

# =============================================================================
# CREATE ARCHIVE
# =============================================================================
echo ""
echo "📦 Creating archive..."

ARCHIVE_NAME="appimage-tools-${OS}-${TARGETARCH}${TARGETVARIANT}.tar.gz"
mkdir -p "$DEST"

(
    cd "$TEMP_DIR"
    tar czf "$DEST/$ARCHIVE_NAME" "$(basename "$OS_OUTPUT")" "$(basename "$LIB_DIR")"
)

echo ""
echo "🎉 Build complete!"
echo "   Archive: $DEST/$ARCHIVE_NAME"
echo ""
echo "Files created:"
tree $ARCH_OUTPUT_DIR -L 6 2>/dev/null || find $ARCH_OUTPUT_DIR -type f -maxdepth 6

rm -rf "$TEMP_DIR" "$BUILD_DIR"