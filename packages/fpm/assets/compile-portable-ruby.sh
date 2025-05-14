#!/bin/bash

set -euo pipefail

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
source "$CWD/constants.sh"

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
    brew install -q autoconf automake libtool pkg-config openssl@3 readline zlib p7zip libyaml xz

    echo "  🍎 Compiling for MacOS."

    BREW_PREFIX="$(brew --prefix)"
    export CFLAGS="-I$BREW_PREFIX/include"
    export LDFLAGS="-L$BREW_PREFIX/lib"
    export PKG_CONFIG_PATH="$BREW_PREFIX/opt/openssl@3/lib/pkgconfig"
    export PATH="$BREW_PREFIX/bin:$PATH"

    echo "  ⚙️ Running configure..."
    ./configure \
        --prefix="$RUBY_PREFIX" \
        --disable-install-doc \
        --enable-shared \
        --enable-load-relative \
        --with-opt-dir="$BREW_PREFIX" \
        --with-openssl-dir="$(brew --prefix openssl)" \
        --with-readline-dir="$(brew --prefix readline)" \
        --with-zlib-dir="$(brew --prefix zlib)" \
        --with-libyaml-dir=$(brew --prefix libyaml) \
        1>/dev/null

    echo "  🔨 Building Ruby..."
    make -j"$(sysctl -n hw.ncpu)" 1>/dev/null
    echo "  ⤵️ Installing Ruby..."
    make install 1>/dev/null

    mkdir -p "$RUBY_PREFIX/lib"
    cp -a "$BREW_PREFIX/lib/liblzma."*dylib "$RUBY_PREFIX/lib/"
else
    echo "  🐧 Compiling for Linux."
    autoconf
    ./autogen.sh

    ARCH_FLAGS=""
    if [ "$TARGET_ARCH" = "i386" ]; then
        echo " ✏️ Using 32-bit architecture flags."
        ARCH_FLAGS='--host=i386-linux-gnu CC="gcc -m32" CXX="g++ -m32"'
    fi

    echo "  ⚙️ Running configure..."
    ./configure \
        --prefix="$RUBY_PREFIX" \
        --disable-install-doc \
        --enable-shared \
        --enable-load-relative \
        --with-opt-dir=/usr \
        --with-libyaml-dir=/usr \
        --with-openssl-dir=/usr \
        --with-zlib-dir=/usr \
        --with-readline-dir=/usr \
        --with-baseruby=$(which ruby) \
        $ARCH_FLAGS \
        1>/dev/null

    echo "  🔨 Building Ruby..."
    make -j$(nproc) 1>/dev/null
    echo "  ⤵️ Installing Ruby..."
    make install 1>/dev/null

    mkdir -p "$RUBY_PREFIX/lib"
    cp -a /usr/lib/$TARGET_ARCH-linux-gnu/liblzma.so.* $RUBY_PREFIX/lib/
fi

echo "  🔨 Stripping debug symbols..."
strip $RUBY_PREFIX/bin/ruby

echo "💎 Ruby $RUBY_VERSION installed to $RUBY_PREFIX"
echo "🗑️ Cleaning up source code download..."
rm -rf "$SOURCE_DIR"
echo "✅ Done!"
