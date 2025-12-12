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
    apt-get install -y -qq \
        libxss1 \
        libxtst6 \
        libnotify4 \
        libappindicator3-1 2>/dev/null || \
        apt-get install -y -qq libayatana-appindicator3-1 2>/dev/null || true
    
    if is_x64; then
        LIB_DIR="/usr/lib/x86_64-linux-gnu"
        OUT_DIR="/output/lib/x64"
    else
        LIB_DIR="/usr/lib/i386-linux-gnu"
        OUT_DIR="/output/lib/ia32"
    fi
    
    mkdir -p "$OUT_DIR"
    
    # Copy libraries
    cp "$LIB_DIR/libXss.so.1" "$OUT_DIR/" 2>/dev/null # || echo "  ⚠ libXss.so.1 not found"
    cp "$LIB_DIR/libXtst.so.6" "$OUT_DIR/" 2>/dev/null # || echo "  ⚠ libXtst.so.6 not found"
    cp "$LIB_DIR/libnotify.so.4" "$OUT_DIR/" 2>/dev/null # || echo "  ⚠ libnotify.so.4 not found"
    
    # Try both appindicator variants
    if cp "$LIB_DIR/libappindicator3.so.1" "$OUT_DIR/libappindicator.so.1" 2>/dev/null; then
        echo "  ✓ Copied libappindicator3.so.1"
    elif cp "$LIB_DIR/libayatana-appindicator3.so.1" "$OUT_DIR/libappindicator.so.1" 2>/dev/null; then
        echo "  ✓ Copied libayatana-appindicator3.so.1"
    else
        echo "  ⚠ libappindicator.so.1 not found"
    fi
    
    # Try both indicator variants
    if cp "$LIB_DIR/libindicator3.so.7" "$OUT_DIR/libindicator.so.7" 2>/dev/null; then
        echo "  ✓ Copied libindicator3.so.7"
    elif cp "$LIB_DIR/libayatana-indicator3.so.7" "$OUT_DIR/libindicator.so.7" 2>/dev/null; then
        echo "  ✓ Copied libayatana-indicator3.so.7"
    else
        echo "  ⚠ libindicator.so.7 not found"
    fi
fi

# Create tarball
echo "Creating tarball..."
cd /output
tar czf "/appimage-tools-${TARGETARCH}${TARGETVARIANT}.tar.gz" .
chmod 644 /appimage-tools-*.tar.gz

echo "✓ Build complete for $ARCH_DIR"