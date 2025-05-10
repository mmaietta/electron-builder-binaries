#!/bin/bash

set -euo pipefail

BASEDIR=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)
if [[ ${BASEDIR: -1} == "/" ]]; then
    BASEDIR="."
fi
echo "BASEDIR: $BASEDIR"
# Check if the script is run from the correct directory
if [[ ! -d "$BASEDIR/assets" ]]; then
    echo "Please run this script from the fpm package directory."
    exit 1
fi
# ./out/OS_NAME-ARCHITECTURE/
# darwin-arms64, darwin-x64, linux-arms64, etc...
OUTPUT_DIR="$BASEDIR/out"
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
echo "[+] Creating install directories..."
rm -rf "$INSTALL_DIR" "$SOURCE_DIR"
mkdir -p "$INSTALL_DIR" "$SOURCE_DIR"

# ===== Download Ruby source =====
echo "[+] Downloading Ruby $RUBY_VERSION source..."
cd "$SOURCE_DIR"
curl -O "https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz"
tar -xzf "ruby-${RUBY_VERSION}.tar.gz"
cd "ruby-${RUBY_VERSION}"

# ===== Configure and compile Ruby =====
echo "[+] Configuring and compiling Ruby..."
if [ "$(uname)" = "Darwin" ]; then
    echo "  ↳ Installing dependencies..."
    xcode-select --install 2>/dev/null || true
    brew install -q autoconf automake libtool pkg-config openssl readline zlib

    echo "  ↳ Compiling for MacOS."

    ./configure \
        --prefix="$RUBY_PREFIX" \
        --disable-install-doc \
        --with-openssl-dir="$(brew --prefix openssl)" \
        --with-readline-dir="$(brew --prefix readline)" \
        --with-zlib-dir="$(brew --prefix zlib)"
    # --disable-install-rdoc \
    make -j"$(sysctl -n hw.ncpu)"
    make install
else
    echo "  ↳ Compiling for Linux."
    if [ "$TARGETARCH" = "386" ]; then
        ARCH_FLAGS="--host=i386-linux-gnu CFLAGS='-m32' LDFLAGS='-m32'"
        echo "  ↳ Adding 32-bit architecture flags."
    fi

    autoconf
    ./autogen.sh
    ./configure \
        --prefix="$RUBY_PREFIX" \
        --disable-install-doc \
        --enable-shared \
        --disable-static \
        --enable-load-relative \
        --with-baseruby=$(which ruby) \
        ${ARCH_FLAGS:-}
    # --with-openssl-dir=/usr/include/openssl \
    # --disable-install-rdoc \
    make -j$(nproc)
    make install

    patchelf --set-rpath '$ORIGIN/../lib' $RUBY_PREFIX/bin/ruby
fi

# ===== Install gems =====
echo "[+] Installing gems..."
export PATH="$RUBY_PREFIX/bin:$PATH"
mkdir -p "$RUBY_PREFIX/gems"
export GEM_HOME="$RUBY_PREFIX/gems"
export GEM_PATH="$RUBY_PREFIX/gems"
gem install --no-document ${GEM_LIST[@]}

# ===== Create wrapper scripts =====
echo "[+] Creating environment scripts..."

echo "  ↳ ruby.env -> $INSTALL_DIR/ruby.env"
cat <<EOF >"$INSTALL_DIR/ruby.env"
#!/bin/bash
# Portable Ruby environment setup
RUBY_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/$RUBY_DIR_NAME" && pwd)"
export PATH="\$RUBY_DIR/bin:\$PATH"
export GEM_HOME="\$RUBY_DIR/gems"
export GEM_PATH="\$GEM_HOME"
export RUBYLIB="\$RUBY_DIR/lib:\$RUBYLIB"
EOF
chmod +x "$INSTALL_DIR/ruby.env"

echo "  ↳ fpm -> $INSTALL_DIR/fpm"
cat <<EOF >"$INSTALL_DIR/fpm"
#!/bin/bash
# Portable Ruby environment setup
source "\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)/ruby.env"

exec "\$GEM_HOME/bin/fpm" "\$@"
EOF
chmod +x "$INSTALL_DIR/fpm"

for executable in "$RUBY_PREFIX/bin"/*; do
    if [[ -x "$executable" && ! -L "$executable" ]]; then
        # Create a wrapper script for each executable
        executable_name=$(basename "$executable")
        echo "  ↳ $executable_name..."
        ENTRY_SCRIPT="$INSTALL_DIR/$executable_name"
        cat <<EOF >"$ENTRY_SCRIPT"
#!/bin/bash
# Portable Ruby environment setup
source "\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)/ruby.env"

exec "\$RUBY_DIR/bin/$executable_name" "\$@"
EOF
        chmod +x "$ENTRY_SCRIPT"
    fi
done

# ===== Create VERSION file =====
echo "[+] Creating VERSION file..."
FPM_VERSION="$($GEM_HOME/bin/fpm --version | cut -d' ' -f2)"
echo "ruby: $RUBY_VERSION" >$INSTALL_DIR/VERSION.txt
echo "fpm: $FPM_VERSION" >>$INSTALL_DIR/VERSION.txt

echo "[+] Creating portable archive..."
cd "$INSTALL_DIR"
ARCHIVE_NAME="fpm-${FPM_VERSION}-ruby-${RUBY_VERSION}-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m).tar.gz"

tar -czf "$OUTPUT_DIR/$ARCHIVE_NAME" -C $INSTALL_DIR .
echo "✅ Portable Ruby $RUBY_VERSION built and bundled at:"
echo "  ↳ $OUTPUT_DIR/$ARCHIVE_NAME"

echo "[+] Cleaning up temporary files..."
rm -rf "$SOURCE_DIR"
echo "✅ Done!"
