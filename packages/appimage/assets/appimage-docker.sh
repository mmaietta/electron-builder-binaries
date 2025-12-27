#!/bin/bash
set -e

echo "🔧 Setting up AppImage build environment..."

# Update package lists
echo "📦 Updating package lists..."
rm -rf /var/lib/apt/lists/* \
 && apt-get clean \
 && apt-get update -qq

# Install build tools
echo "🛠️  Installing build tools..."
BUILD_TOOLS=(
    "build-essential"
    "cmake"
    "wget"
    "tar"
    "git"
    "pkg-config"
)

for tool in "${BUILD_TOOLS[@]}"; do
    echo "   📥 Installing $tool..."
    if ! apt-get install -y "$tool" > /dev/null 2>&1; then
        echo "   ❌ Failed to install $tool"
        exit 1
    fi
done

# Install compression libraries and development headers
echo "📚 Installing compression libraries..."
COMPRESSION_LIBS=(
    "zlib1g-dev"
    "liblzma-dev"
    "liblzo2-dev"
    "liblz4-dev"
    "libzstd-dev"
)

for lib in "${COMPRESSION_LIBS[@]}"; do
    echo "   📥 Installing $lib..."
    if ! apt-get install -y "$lib" > /dev/null 2>&1; then
        echo "   ❌ Failed to install $lib"
        exit 1
    fi
done

# Install desktop-file-utils build dependencies
echo "📥 Installing desktop-file-utils dependencies..."
DESKTOP_UTILS_DEPS=(
    "libglib2.0-dev"
    "autoconf"
    "automake"
    "libtool"
)

for lib in "${DESKTOP_UTILS_DEPS[@]}"; do
    echo "   📥 Installing $lib..."
    if ! apt-get install -y "$lib" > /dev/null 2>&1; then
        echo "   ❌ Failed to install $lib"
        exit 1
    fi
done

# Install runtime libraries
echo "📚 Installing runtime libraries..."
RUNTIME_LIBS=(
    "libxss1"
    "libxtst6"
    "libnotify4"
    "libgconf-2-4"
)

for lib in "${RUNTIME_LIBS[@]}"; do
    echo "   📥 Installing $lib..."
    if ! apt-get install -y "$lib" > /dev/null 2>&1; then
        echo "   ❌ Failed to install $lib"
        exit 1
    fi
done

# Architecture-specific packages
case "$TARGETPLATFORM" in
    "linux/386")
        echo "📥 Downloading libappindicator1 from Ubuntu 18.04 archive (i386)..."
        cd /tmp
        wget -q http://archive.ubuntu.com/ubuntu/pool/universe/liba/libappindicator/libappindicator1_12.10.1+18.04.20180322.1-0ubuntu1_i386.deb
        wget -q http://archive.ubuntu.com/ubuntu/pool/universe/libi/libindicator/libindicator7_16.10.0+18.04.20180321.1-0ubuntu1_i386.deb
        dpkg -x libappindicator1_12.10.1+18.04.20180322.1-0ubuntu1_i386.deb /tmp/appind
        dpkg -x libindicator7_16.10.0+18.04.20180321.1-0ubuntu1_i386.deb /tmp/ind
        echo "   ✅ i386 libappindicator packages extracted"
        ;;
    *)
        echo "📥 Installing libappindicator3-1 & libindicator3-7..."
        if ! apt-get install -y libappindicator3-1 libindicator3-7 > /dev/null 2>&1; then
            echo "   ❌ Failed to install libappindicator/libindicator"
            exit 1
        fi
        ;;
esac

# Install tree utility for displaying structure (optional)
apt-get install -y tree > /dev/null 2>&1 || echo "   ⚠️  tree not installed (optional)"

echo ""
echo "🎉 Environment setup complete!"
echo "   Platform: $TARGETPLATFORM"
echo "   Ready for compilation"