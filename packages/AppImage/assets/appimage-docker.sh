#!/bin/bash
set -e

# Determine architecture directory based on platform
get_arch_dir() {
    case "$TARGETPLATFORM" in
        "linux/amd64") echo "linux-x64" ;;
        "linux/386") echo "linux-ia32" ;;
        "linux/arm64") echo "linux-arm64" ;;
        "linux/arm/v7") echo "linux-arm32" ;;
        *) echo "linux-unknown" ;;
    esac
}

is_x64() { [ "$TARGETPLATFORM" = "linux/amd64" ]; }
is_ia32() { [ "$TARGETPLATFORM" = "linux/386" ]; }
is_arm64() { [ "$TARGETPLATFORM" = "linux/arm64" ]; }
is_arm32() { [ "$TARGETPLATFORM" = "linux/arm/v7" ]; }
is_x86() { is_x64 || is_ia32; }

ARCH_DIR=$(get_arch_dir)
echo "Building for $TARGETPLATFORM -> $ARCH_DIR"

# Build squashfs-tools
echo "Building squashfs-tools..."
cd /build/squashfs-tools/squashfs-tools
make -j$(nproc) GZIP_SUPPORT=1 XZ_SUPPORT=1 LZO_SUPPORT=1 LZ4_SUPPORT=1 ZSTD_SUPPORT=1

mkdir -p "/output/$ARCH_DIR"
cp mksquashfs "/output/$ARCH_DIR/"
echo "✓ Built mksquashfs"

# Copy desktop-file-validate
if [ -f /usr/bin/desktop-file-validate ]; then
    cp /usr/bin/desktop-file-validate "/output/$ARCH_DIR/"
    echo "✓ Copied desktop-file-validate"
fi

# Build OpenJPEG (only for x64)
if is_x64; then
    echo "Building OpenJPEG..."
    cd /build
    wget -q https://github.com/uclouvain/openjpeg/archive/v2.3.0.tar.gz
    tar xzf v2.3.0.tar.gz
    cd openjpeg-2.3.0
    mkdir build && cd build
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local > /dev/null
    make -j$(nproc) > /dev/null
    make install DESTDIR=/output/openjpeg-install > /dev/null
    
    mkdir -p "/output/$ARCH_DIR/lib"
    cp -a /output/openjpeg-install/usr/local/lib/libopenjp2.* "/output/$ARCH_DIR/lib/"
    cp -a /output/openjpeg-install/usr/local/lib/openjpeg-2.3 "/output/$ARCH_DIR/lib/"
    cp -a /output/openjpeg-install/usr/local/lib/pkgconfig "/output/$ARCH_DIR/lib/"
    cp /output/openjpeg-install/usr/local/bin/opj_decompress "/output/$ARCH_DIR/"
    
    # Create symlinks
    cd "/output/$ARCH_DIR/lib"
    ln -sf libopenjp2.so.2.3.0 libopenjp2.so.7
    ln -sf libopenjp2.so.7 libopenjp2.so
    echo "✓ Built OpenJPEG"
fi

# Extract runtime libraries (only for x86 architectures)
if is_x86; then
    echo "Installing runtime libraries..."
    apt-get update -qq
    
    # Install packages and verify they succeeded
    echo "  Installing libxss1..."
    apt-get install -y libxss1 || { echo "  ❌ Failed to install libxss1"; exit 1; }
    
    echo "  Installing libxtst6..."
    apt-get install -y libxtst6 || { echo "  ❌ Failed to install libxtst6"; exit 1; }
    
    echo "  Installing libnotify4..."
    apt-get install -y libnotify4 || { echo "  ❌ Failed to install libnotify4"; exit 1; }
    
    echo "  Installing libgconf-2-4..."
    apt-get install -y libgconf-2-4 || { echo "  ❌ Failed to install libgconf-2-4"; exit 1; }
    
    # For i386, use libappindicator1 instead of libappindicator3-1
    if is_ia32; then
        echo "  Installing libappindicator1 (i386 version)..."
        apt-get install -y libappindicator1 || { echo "  ❌ Failed to install libappindicator1"; exit 1; }
        
        echo "  Installing libindicator7..."
        apt-get install -y libindicator7 || { echo "  ❌ Failed to install libindicator7"; exit 1; }
    else
        echo "  Installing libappindicator3-1..."
        apt-get install -y libappindicator3-1 || { echo "  ❌ Failed to install libappindicator3-1"; exit 1; }
        
        echo "  Installing libindicator3-7..."
        apt-get install -y libindicator3-7 || { echo "  ❌ Failed to install libindicator3-7"; exit 1; }
    fi
    
    if is_x64; then
        LIB_DIR="/usr/lib/x86_64-linux-gnu"
        OUT_DIR="/output/lib/x64"
    else
        LIB_DIR="/usr/lib/i386-linux-gnu"
        OUT_DIR="/output/lib/ia32"
    fi
    
    mkdir -p "$OUT_DIR"
    
    echo "  Verifying installed libraries in $LIB_DIR:"
    ls -la "$LIB_DIR"/libXss* "$LIB_DIR"/libXtst* "$LIB_DIR"/libnotify* "$LIB_DIR"/libgconf* "$LIB_DIR"/libappindicator* "$LIB_DIR"/libindicator* 2>/dev/null || echo "  Some libraries not found in expected location"
    
    # Find and copy libraries
    echo "  Copying libraries to $OUT_DIR"
    
    # Helper function to find and copy library
    copy_lib() {
        local libname=$1
        local outname=${2:-$libname}
        
        # Try common locations in order of preference
        local search_dirs=("$LIB_DIR" "/usr/lib/i386-linux-gnu" "/usr/lib/x86_64-linux-gnu" "/usr/lib32" "/usr/lib" "/lib/i386-linux-gnu" "/lib/x86_64-linux-gnu" "/lib32" "/lib")
        
        for dir in "${search_dirs[@]}"; do
            if [ -f "$dir/$libname" ]; then
                cp "$dir/$libname" "$OUT_DIR/$outname"
                echo "  ✓ Copied $libname from $dir"
                return 0
            fi
        done
        
        # If not found in standard locations, try a broader search
        local found=$(find /usr/lib /lib -name "$libname" 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            cp "$found" "$OUT_DIR/$outname"
            echo "  ✓ Copied $libname from $(dirname $found)"
            return 0
        fi
        
        echo "  ❌ $libname not found in any location"
        echo "     Searched directories: ${search_dirs[*]}"
        return 1
    }
    
    # Copy all required libraries
    copy_lib "libXss.so.1" || exit 1
    copy_lib "libXtst.so.6" || exit 1
    copy_lib "libnotify.so.4" || exit 1
    copy_lib "libgconf-2.so.4" || exit 1
    
    # For i386, use libappindicator1 library names
    if is_ia32; then
        copy_lib "libappindicator.so.1" "libappindicator.so.1" || exit 1
        copy_lib "libindicator.so.7" "libindicator.so.7" || exit 1
    else
        copy_lib "libappindicator3.so.1" "libappindicator.so.1" || exit 1
        copy_lib "libindicator3.so.7" "libindicator.so.7" || exit 1
    fi
    
    echo "  ✅ All required libraries copied"
fi

# Create tarball
echo "Creating tarball..."
cd /output
tar czf "/appimage-tools-${TARGETARCH}${TARGETVARIANT}.tar.gz" .
chmod 644 /appimage-tools-*.tar.gz

echo "✓ Build complete for $ARCH_DIR"