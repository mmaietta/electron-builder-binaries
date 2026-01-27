#!/usr/bin/env bash
set -e
set -u
set -o pipefail

echo "🍷🍷🍷 Wine macOS ARM64 Runtime Build 🍷🍷🍷"

############################################
# Config
############################################

WINE_VERSION="${WINE_VERSION:-11.0}"
PLATFORM_ARCH="$(uname -m)"
BUILD_DIR="$(pwd)/build"

DOWNLOAD_DIR="$BUILD_DIR/downloads"
SOURCE_DIR="$BUILD_DIR/wine-$WINE_VERSION"
BUILD_DIR_WINE="$BUILD_DIR/wine-build"
INSTALL_DIR="$BUILD_DIR/install"
OUTPUT_DIR="$BUILD_DIR/wine-$WINE_VERSION-darwin-$PLATFORM_ARCH"

rm -rf "$BUILD_DIR_WINE" "$INSTALL_DIR" "$OUTPUT_DIR"

############################################
# Preconditions
############################################

echo "🔍 Checking platform…"
if [ "$PLATFORM_ARCH" != "arm64" ]; then
  echo "❌ This script is ARM64-only"
  exit 1
fi

echo "🧰 Using SDK:"
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
echo "   $SDKROOT"

############################################
# Wine source
############################################

echo "📦 Preparing directories…"
mkdir -p "$DOWNLOAD_DIR" "$BUILD_DIR"

WINE_TARBALL="wine-$WINE_VERSION.tar.xz"
WINE_URL="https://dl.winehq.org/wine/source/$(echo "$WINE_VERSION" | cut -d. -f1).0/$WINE_TARBALL"
WINE_SHA256="c07a6857933c1fc60dff5448d79f39c92481c1e9db5aa628db9d0358446e0701"

if [ ! -f "$DOWNLOAD_DIR/$WINE_TARBALL" ]; then
  echo "⬇️  Downloading Wine $WINE_VERSION"
  curl -L "$WINE_URL" -o "$DOWNLOAD_DIR/$WINE_TARBALL"
fi

echo "🔐 Verifying Wine checksum…"
ACTUAL_SHA="$(shasum -a 256 "$DOWNLOAD_DIR/$WINE_TARBALL" | awk '{print $1}')"
echo "   Expected: $WINE_SHA256"
echo "   Actual:   $ACTUAL_SHA"
[ "$ACTUAL_SHA" = "$WINE_SHA256" ]

if [ ! -d "$SOURCE_DIR" ]; then
  echo "📂 Extracting Wine source…"
  tar -xJf "$DOWNLOAD_DIR/$WINE_TARBALL" -C "$BUILD_DIR"
fi

############################################
# llvm-mingw bootstrap
############################################

echo "🧱 Bootstrapping llvm-mingw (PE cross tools)…"

LLVM_MINGW_VERSION="20260116"
LLVM_MINGW_NAME="llvm-mingw-$LLVM_MINGW_VERSION-ucrt-macos-universal"
LLVM_MINGW_ARCHIVE="$LLVM_MINGW_NAME.tar.xz"
LLVM_MINGW_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/$LLVM_MINGW_VERSION/$LLVM_MINGW_ARCHIVE"
LLVM_MINGW_SHA256="ceb8346e301290290f4ca4a200fed5e69fcb91d19064f71239e889ef05c8357f"

LLVM_MINGW_ROOT="$BUILD_DIR/llvm-mingw"

if [ ! -d "$LLVM_MINGW_ROOT" ]; then
  curl -L "$LLVM_MINGW_URL" -o "$DOWNLOAD_DIR/$LLVM_MINGW_ARCHIVE"

  echo "🔐 Verifying llvm-mingw checksum…"
  ACTUAL_SHA="$(shasum -a 256 "$DOWNLOAD_DIR/$LLVM_MINGW_ARCHIVE" | awk '{print $1}')"
  echo "   Expected: $LLVM_MINGW_SHA256"
  echo "   Actual:   $ACTUAL_SHA"
  [ "$ACTUAL_SHA" = "$LLVM_MINGW_SHA256" ]

  echo "📦 Extracting llvm-mingw…"
  tar -xJf "$DOWNLOAD_DIR/$LLVM_MINGW_ARCHIVE" -C "$BUILD_DIR"
  mv "$BUILD_DIR/$LLVM_MINGW_NAME" "$LLVM_MINGW_ROOT"
fi

export PATH="$LLVM_MINGW_ROOT/bin:$PATH"
export CC=clang
export CXX=clang++
export PE_CC=aarch64-w64-mingw32-clang
export PE_CXX=aarch64-w64-mingw32-clang++
export DLLTOOL=llvm-dlltool
export LD=ld.lld

############################################
# Configure Wine
############################################

echo "⚙️  Configuring Wine…"
mkdir -p "$BUILD_DIR_WINE"
cd "$BUILD_DIR_WINE"

"$SOURCE_DIR/configure" \
  --prefix="$INSTALL_DIR" \
  --enable-win64 \
  --without-x \
  --without-cups \
  --without-dbus \
  CFLAGS="-O2" \
  LDFLAGS=""

############################################
# Build + install
############################################

echo "🔨 Building Wine…"
make -j"$(sysctl -n hw.ncpu)"

echo "📦 Installing Wine…"
make install

############################################
# STRIP EVERYTHING
############################################

echo "🧹 Stripping binaries (this saves HUGE space)…"

find "$INSTALL_DIR/bin" -type f -perm +111 -exec strip -x {} \;
find "$INSTALL_DIR/lib" "$INSTALL_DIR/lib64" -name "*.dylib" -exec strip -x {} \;

if command -v llvm-strip; then
  find "$INSTALL_DIR/lib" "$INSTALL_DIR/lib64" -name "*.dll" -exec llvm-strip {} \;
fi

############################################
# DELETE JUNK
############################################

echo "🗑️  Removing dev + test junk…"

rm -rf "$INSTALL_DIR/include"
rm -rf "$INSTALL_DIR/share/man"
rm -rf "$INSTALL_DIR/share/doc"
rm -rf "$INSTALL_DIR/lib/wine/tests"
rm -rf "$INSTALL_DIR/lib64/wine/tests"
rm -f  "$INSTALL_DIR/lib"/*.a
rm -f  "$INSTALL_DIR/lib64"/*.a

############################################
# Shrink share/wine
############################################

echo "📉 Pruning share/wine…"

cd "$INSTALL_DIR/share/wine"
ls | grep -Ev '^(fonts|wine.inf)$' | xargs rm -rf

cd fonts
ls | grep -Ev '^(arial|courier|times|tahoma)\.ttf$' | xargs rm -f

############################################
# Runtime-only packaging
############################################

echo "📦 Creating minimal runtime distribution…"

mkdir -p "$OUTPUT_DIR"/{bin,lib64/wine,share/wine,wine-home}

cp "$INSTALL_DIR/bin/wine64" "$OUTPUT_DIR/bin/"
cp "$INSTALL_DIR/bin/wineserver" "$OUTPUT_DIR/bin/"
cp -R "$INSTALL_DIR/lib64/wine" "$OUTPUT_DIR/lib64/"
cp -R "$INSTALL_DIR/share/wine" "$OUTPUT_DIR/share/"

############################################
# RPATH fix
############################################

echo "🔧 Fixing rpaths…"
install_name_tool -add_rpath "@executable_path/../lib64" "$OUTPUT_DIR/bin/wine64"
install_name_tool -add_rpath "@executable_path/../lib64" "$OUTPUT_DIR/bin/wineserver"

############################################
# Launcher
############################################

echo "🚀 Creating launcher…"

cat > "$OUTPUT_DIR/wine-launcher.sh" <<'EOF'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export WINEPREFIX="${WINEPREFIX:-$DIR/wine-home}"
export DYLD_LIBRARY_PATH="$DIR/lib64:$DYLD_LIBRARY_PATH"
exec "$DIR/bin/wine64" "$@"
EOF

chmod +x "$OUTPUT_DIR/wine-launcher.sh"

############################################
# Archive
############################################

echo "🗜️  Creating tarball…"
cd "$BUILD_DIR"
tar -czf "wine-$WINE_VERSION-darwin-$PLATFORM_ARCH.tar.gz" "$(basename "$OUTPUT_DIR")"

echo "✅ DONE 🍷"
echo "📦 Output: $BUILD_DIR/wine-$WINE_VERSION-darwin-$PLATFORM_ARCH.tar.gz"
