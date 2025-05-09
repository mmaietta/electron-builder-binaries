#!/bin/bash

set -e

BASEDIR=$(cd "$(dirname "$BASH_SOURCE")/../.." && pwd)
OUTPUT_DIR="$BASEDIR/out/fpm/darwin"
mkdir -p "$OUTPUT_DIR"

# ===== Configuration =====
RUBY_VERSION="3.2.3"
INSTALL_DIR="/tmp/portable-ruby"
PREFIX="$INSTALL_DIR/ruby-install"
GEM_LIST=("bundler" "fpm")  # Add other gem names here

# ===== Ensure dependencies =====
echo "[1/7] Installing dependencies..."
xcode-select --install 2>/dev/null || true
brew install -q autoconf automake libtool pkg-config openssl readline zlib

# ===== Prepare folders =====
echo "[2/7] Creating install directories..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

===== Download Ruby source =====
echo "[3/7] Downloading Ruby $RUBY_VERSION source..."
curl -O "https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz"
tar -xzf "ruby-${RUBY_VERSION}.tar.gz"
cd "ruby-${RUBY_VERSION}"

# ===== Build Ruby from source =====
echo "[4/7] Configuring and compiling Ruby..."
./configure \
  --prefix="$PREFIX" \
  --with-openssl-dir="$(brew --prefix openssl)" \
  --with-readline-dir="$(brew --prefix readline)" \
  --with-zlib-dir="$(brew --prefix zlib)"

make -j"$(sysctl -n hw.ncpu)"
make install

# ===== Install gems =====
echo "[5/7] Installing gems..."
export PATH="$PREFIX/bin:$PATH"
mkdir -p "$PREFIX/gems"
export GEM_HOME="$PREFIX/gems"
export GEM_PATH="$PREFIX/gems"
gem install --no-document ${GEM_LIST[@]}

# ===== Create wrapper scripts =====
echo "[6/7] Creating environment scripts..."

# env.sh
cat <<EOF > "$INSTALL_DIR/env.sh"
#!/bin/bash
# Portable Ruby environment setup
RUBY_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/ruby-install" && pwd)"
export PATH="\$RUBY_DIR/bin:\$PATH"
export GEM_HOME="\$RUBY_DIR/gems"
export GEM_PATH="\$GEM_HOME"
export RUBYLIB="\$RUBY_DIR/lib:\$RUBYLIB"
echo "Portable Ruby environment configured."
EOF

chmod +x "$INSTALL_DIR/env.sh"

# ruby.sh
cat <<EOF > "$INSTALL_DIR/ruby.sh"
#!/bin/bash
# Wrapper to run portable Ruby
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
RUBY_DIR="\$SCRIPT_DIR/ruby-install"
export PATH="\$RUBY_DIR/bin:\$PATH"
export GEM_HOME="\$RUBY_DIR/gems"
export GEM_PATH="\$GEM_HOME"
export RUBYLIB="\$RUBY_DIR/lib:\$RUBYLIB"
exec "\$RUBY_DIR/bin/ruby" "\$@"
EOF

chmod +x "$INSTALL_DIR/ruby.sh"

# ===== Package =====
FPM_VERSION=$(fpm --version | cut -d' ' -f2)
ARCHIVE_NAME="fpm-${FPM_VERSION}-ruby-${RUBY_VERSION}-darwin.tar.gz"

echo "[7/7] Creating portable archive..."
cd "$INSTALL_DIR"
tar -czf "$OUTPUT_DIR/$ARCHIVE_NAME" ruby-install env.sh ruby.sh

echo "✅ Portable Ruby $RUBY_VERSION built and bundled at:"
echo "   $INSTALL_DIR/$ARCHIVE_NAME"
