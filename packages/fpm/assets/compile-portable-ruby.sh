#!/bin/bash

set -euo pipefail

BASEDIR=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)
if [[ ${BASEDIR: -1} == "/" ]]; then
    BASEDIR="."
fi
echo "BASEDIR: $BASEDIR"
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
GEM_LIST=("fpm") # Add other gem names here

# ===== Prepare folders =====
echo "🔨 Creating install directories..."
rm -rf "$INSTALL_DIR" "$SOURCE_DIR"
mkdir -p "$INSTALL_DIR" "$SOURCE_DIR"

# ===== Download Ruby source =====
echo "🔨 Downloading Ruby $RUBY_VERSION source..."
cd "$SOURCE_DIR"
curl -O "https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz"
tar -xzf "ruby-${RUBY_VERSION}.tar.gz"
cd "ruby-${RUBY_VERSION}"

# ===== Configure and compile Ruby =====
echo "🔨 Configuring and compiling Ruby..."
if [ "$(uname)" = "Darwin" ]; then
    echo "  🔨 Installing dependencies..."
    xcode-select --install 2>/dev/null || true
    brew install -q autoconf automake libtool pkg-config openssl readline zlib

    echo "  🔨 Compiling for MacOS."
    echo "  🔨 Running configure..."
    ./configure \
        --prefix="$RUBY_PREFIX" \
        --disable-install-doc \
        --with-openssl-dir="$(brew --prefix openssl)" \
        --with-readline-dir="$(brew --prefix readline)" \
        --with-zlib-dir="$(brew --prefix zlib)" \
        1>/dev/null

    echo "  🔨 Building Ruby..."
    make -j"$(sysctl -n hw.ncpu)" 1>/dev/null
    echo "  🔨 Installing Ruby..."
    make install 1>/dev/null

    echo "  🔨 Patching shebangs to use relative ruby interpreter..."
    for f in "$RUBY_PREFIX/bin/"*; do
        if head -n 1 "$f" | grep -qE '^#!.*ruby'; then
            echo "    🔨 Patching: $(basename "$f")"
            tail -n +2 "$f" >"$f.tmp"
            {
                echo '#!/bin/bash -e'
                echo 'source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/ruby.env"'
                echo 'exec "$(dirname "$0")/ruby" -x "$0" "$@"'
                echo '#!/usr/bin/env ruby'
            } >"$f"
            cat "$f.tmp" >>"$f"
            rm "$f.tmp"
            chmod +x "$f"
        fi
    done
else
    echo "  🔨 Compiling for Linux."
    autoconf
    ./autogen.sh
    echo "  🔨 Running configure..."
    if [ "$TARGETARCH" = "i386" ]; then
        echo "    🔨 Using 32-bit architecture flags."
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
    echo "  🔨 Installing Ruby..."
    make install 1>/dev/null

    echo "  🔍 Scanning Ruby extensions for shared libraries..."
    LIB_DIR="$RUBY_PREFIX/lib"

    IFS=$'\n'
    LDD_SEARCH_PATHS=("$RUBY_PREFIX/bin/ruby" $(find "$LIB_DIR/ruby" -type f -name '*.so'))
    unset IFS

    for ext_so in "${LDD_SEARCH_PATHS[@]}"; do
        if [[ ! -f "$ext_so" ]]; then
            echo "  ⏩️ Skipping $ext_so (not a file)"
            continue
        fi

        echo "  🔍 Scanning $ext_so"
        ldd "$ext_so" | awk '/=>/ { print $3 }' | while read -r dep; do
            if [[ -f "$dep" ]]; then
                dest="$LIB_DIR/$(basename $dep)"
                if [[ ! -f "$dest" ]]; then
                    echo "    📝 Copying $(basename $dep)"
                    cp -u "$dep" "$LIB_DIR/"
                fi
            fi
        done

        SO_DIR=$(dirname "$ext_so")
        REL_RPATH=$(realpath --relative-to="$SO_DIR" "$LIB_DIR")
        echo "  🩹 Patching $(realpath --relative-to="$RUBY_PREFIX" "$ext_so") to rpath: \$ORIGIN/$REL_RPATH"
        patchelf --set-rpath "\$ORIGIN/$REL_RPATH" "$ext_so"
    done
fi

# ===== Create wrapper scripts =====
echo "🔨 Creating environment script..."
echo "  ✏️ ruby.env -> $INSTALL_DIR/ruby.env"
cat <<EOF >"$INSTALL_DIR/ruby.env"
#!/bin/bash
# Portable Ruby environment setup
RUBY_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/$RUBY_DIR_NAME" && pwd)"
RUBY_BIN="\$RUBY_DIR/bin"
export PATH="\$RUBY_BIN:\$PATH"
export GEM_HOME="\$RUBY_DIR/gems"
export GEM_PATH="\$GEM_HOME"
export RUBYLIB="\$RUBY_DIR/lib:\$RUBYLIB"
if [ "\$(uname)" = "Darwin" ]; then
    # Remove quarantine attribute on macOS
    # This is necessary to avoid the "ruby is damaged and can't be opened" error when running the ruby interpreter for the first time
    if grep -q "com.apple.quarantine" <<< "\$(xattr "\$RUBY_BIN/ruby")"; then
        xattr -d com.apple.quarantine "\$RUBY_BIN/ruby"
    fi
fi
EOF
chmod +x "$INSTALL_DIR/ruby.env"

# ===== Install gems =====
echo "🔨 Installing gems..."
export PATH="$RUBY_PREFIX/bin:$PATH"
mkdir -p "$RUBY_PREFIX/gems"
export GEM_HOME="$RUBY_PREFIX/gems"
export GEM_PATH="$RUBY_PREFIX/gems"
gem install --no-document ${GEM_LIST[@]}

echo "🔨 Creating entrypoint scripts for installed gems..."
for gem in "${GEM_LIST[@]}"; do
    echo "  ✏️ $gem -> $INSTALL_DIR/$gem"
    cat <<EOF >"$INSTALL_DIR/$gem"
#!/bin/bash -e
# Portable Ruby environment setup
source "\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)/ruby.env"

exec "\$GEM_HOME/bin/fpm" "\$@"
EOF
    chmod +x "$INSTALL_DIR/$gem"
done

# ===== Create VERSION file =====
echo "🔨 Creating VERSION file..."
FPM_VERSION="$($INSTALL_DIR/fpm --version | cut -d' ' -f2)"
RUBY_VERSION_VERBOSE="$($RUBY_PREFIX/bin/ruby --version)"
echo "$RUBY_VERSION_VERBOSE" >$INSTALL_DIR/VERSION.txt
echo "fpm: $FPM_VERSION" >>$INSTALL_DIR/VERSION.txt

echo "🔨 Creating portable archive..."
cd "$INSTALL_DIR"
ARCHIVE_NAME="fpm-${FPM_VERSION}-ruby-${RUBY_VERSION}-$(uname -s | tr '[:upper:]' '[:lower:]')-${TARGETARCH:-$(uname -m)}.tar.gz"

tar -czf "$OUTPUT_DIR/$ARCHIVE_NAME" -C $INSTALL_DIR .
echo "🚢 Portable Ruby $RUBY_VERSION built and bundled at:"
echo "  ⏭️ $OUTPUT_DIR/$ARCHIVE_NAME"

echo "🗑️ Cleaning up source code download..."
rm -rf "$SOURCE_DIR"
echo "✅ Done!"
