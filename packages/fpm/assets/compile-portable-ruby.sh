#!/bin/bash

set -euo pipefail

BASEDIR=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)
if [[ ${BASEDIR: -1} == "/" ]]; then
    BASEDIR="."
fi
echo "🎯 Base directory: $BASEDIR"
# Check if the script is running from the correct directory
if [[ ! -d "$BASEDIR/assets" ]]; then
    echo "Please run this script from the fpm package directory."
    exit 1
fi
OUTPUT_DIR="$BASEDIR/out/fpm"
mkdir -p "$OUTPUT_DIR"

# ===== Configuration =====
RUBY_VERSION=$RUBY_VERSION # 3.4.3
# Check if RUBY_VERSION is set
if [ -z "$RUBY_VERSION" ]; then
    echo "RUBY_VERSION is not set. Please set it to the desired Ruby version."
    exit 1
fi
SOURCE_DIR="/tmp/ruby-source"
INSTALL_DIR="/tmp/ruby-install"
RUBY_DIR_NAME="ruby-$RUBY_VERSION-portable"
RUBY_PREFIX="$INSTALL_DIR/$RUBY_DIR_NAME"

# ===== Prepare folders =====
echo "🪏 Creating install directories..."
rm -rf "$INSTALL_DIR" "$SOURCE_DIR"
mkdir -p "$INSTALL_DIR" "$SOURCE_DIR"

# ===== Download Ruby source =====
echo "⬇️ Downloading Ruby $RUBY_VERSION source..."
cd "$SOURCE_DIR"
curl -O "https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz"
tar -xzf "ruby-${RUBY_VERSION}.tar.gz"
cd "ruby-${RUBY_VERSION}"

# ===== Configure and compile Ruby =====
echo "🔨 Configuring and compiling Ruby..."
if [ "$(uname)" = "Darwin" ]; then
    echo "  ⚒️ Installing dependencies..."
    xcode-select --install 2>/dev/null || true
    brew install -q autoconf automake libtool pkg-config openssl readline zlib p7zip

    echo "  🍎 Compiling for MacOS."
    echo "  ⚙️ Running configure..."
    ./configure \
        --prefix="$RUBY_PREFIX" \
        --disable-install-doc \
        --with-openssl-dir="$(brew --prefix openssl)" \
        --with-readline-dir="$(brew --prefix readline)" \
        --with-zlib-dir="$(brew --prefix zlib)" \
        1>/dev/null

    echo "  🔨 Building Ruby..."
    make -j"$(sysctl -n hw.ncpu)" 1>/dev/null
    echo "  ⤵️ Installing Ruby..."
    make install 1>/dev/null
else
    echo "  🐧 Compiling for Linux."
    autoconf
    ./autogen.sh
    echo "  ⚙️ Running configure..."
    if [ "$TARGET_ARCH" = "386" ]; then
        echo "    ✏️ Using 32-bit architecture flags."
        ./configure \
            --prefix="$RUBY_PREFIX" \
            --disable-install-doc \
            --enable-shared \
            --enable-load-relative \
            --with-openssl-dir=/usr \
            --with-libyaml-dir=/usr \
            --with-baseruby=$(which ruby) \
            --host=i386-linux-gnu \
            CC="gcc -m32" \
            CXX="g++ -m32" 1>/dev/null
    else
        ./configure \
            --prefix="$RUBY_PREFIX" \
            --disable-install-doc \
            --enable-shared \
            --enable-load-relative \
            --with-openssl-dir=/usr \
            --with-libyaml-dir=/usr \
            --with-baseruby=$(which ruby) 1>/dev/null
    fi

    echo "  🔨 Building Ruby..."
    make -j$(nproc) 1>/dev/null
    echo "  ⤵️ Installing Ruby..."
    make install 1>/dev/null
fi
echo "💎 Ruby $RUBY_VERSION installed to $RUBY_PREFIX"
echo "🗑️ Cleaning up source code download..."
rm -rf "$SOURCE_DIR"
echo "✅ Done!"
