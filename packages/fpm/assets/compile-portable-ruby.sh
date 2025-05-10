#!/bin/bash

set -euo pipefail

BASEDIR=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
# ./out/OS_NAME-ARCHITECTURE/
# darwin-arms64, darwin-x64, linux-arms64, etc...
OUTPUT_DIR="$BASEDIR/out/$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# ===== Configuration =====
RUBY_VERSION="3.2.3"
SOURCE_DIR="/tmp/ruby-source"
INSTALL_DIR="/tmp/portable-ruby"
RUBY_PREFIX="$INSTALL_DIR/ruby-install"
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
    echo "[+] Installing dependencies..."
    xcode-select --install 2>/dev/null || true
    brew install -q autoconf automake libtool pkg-config openssl readline zlib
    
    echo "  ↳ Compiling for MacOS."

    ./configure \
        --prefix="$RUBY_PREFIX" \
        --disable-install-doc \
        --disable-install-rdoc \
        --with-openssl-dir="$(brew --prefix openssl)" \
        --with-readline-dir="$(brew --prefix readline)" \
        --with-zlib-dir="$(brew --prefix zlib)"
    make -j"$(sysctl -n hw.ncpu)"
    make install

else
    echo "  ↳ Compiling for Linux."
    echo "  ↳ If for i386, please set env var ARCH_FLAGS=\"--host=i386-linux-gnu CFLAGS='-m32' LDFLAGS='-m32'"

    autoconf
    ./autogen.sh
    ./configure \
        --prefix="$RUBY_PREFIX" \
        --disable-install-doc \
        --disable-install-rdoc \
        --enable-shared \
        --disable-static \
        --enable-load-relative \
        --with-openssl-dir=/usr/include/openssl \
        --with-baseruby=$(which ruby) \
        ${ARCH_FLAGS:-}
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
RUBY_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/ruby-install" && pwd)"
export PATH="\$RUBY_DIR/bin:\$PATH"
export GEM_HOME="\$RUBY_DIR/gems"
export GEM_PATH="\$GEM_HOME"
export RUBYLIB="\$RUBY_DIR/lib:\$RUBYLIB"
echo "Portable Ruby environment configured."
EOF
chmod +x "$INSTALL_DIR/ruby.env"

echo "  ↳ fpm -> $INSTALL_DIR/fpm"
cat <<EOF >"$INSTALL_DIR/fpm"
#!/bin/bash
# Portable Ruby environment setup
source "\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/ruby.env"

exec "\$RUBY_DIR/bin/EXECUTABLE" "\$@"
EOF
chmod +x "$INSTALL_DIR/fpm"

for executable in "$RUBY_PREFIX/bin"/*; do
    if [[ -x "$executable" && ! -L "$executable" ]]; then
        # Create a wrapper script for each executable
        executable_name=$(basename "$executable")
        echo "  ↳ $executable_name..."
        ENTRY_SCRIPT="$INSTALL_DIR/ruby-install/$executable_name"
        cat "$BASEDIR/assets/entrypoint-template.sh" | sed "s|EXECUTABLE|${executable_name}|g" >"$ENTRY_SCRIPT"
        chmod +x "$ENTRY_SCRIPT"
    fi
done

# ===== Create VERSION file =====
echo "[+] Creating VERSION file..."
FPM_VERSION=$(fpm --version | cut -d' ' -f2)
echo "ruby: $RUBY_VERSION" > $RUBY_PREFIX/VERSION.txt
echo "fpm: $FPM_VERSION" >> $RUBY_PREFIX/VERSION.txt

echo "[+] Creating portable archive..."
cd "$INSTALL_DIR"
ARCHIVE_NAME="fpm-${FPM_VERSION}-ruby-${RUBY_VERSION}-darwin.tar.gz"
# tar -czf "$OUTPUT_DIR/$ARCHIVE_NAME" ruby-install ruby.env ruby.sh
tar -czf "$OUTPUT_DIR/fpm-${FPM_VERSION}-ruby-${RUBY_VERSION}.tar.gz" -C $RUBY_PREFIX .
echo "✅ Portable Ruby $RUBY_VERSION built and bundled at:"
echo "  ↳ $OUTPUT_DIR/$ARCHIVE_NAME"

# rm -rf "$SOURCE_DIR"
# echo "✅ Cleaned up temporary files."
# echo "✅ Done!"
