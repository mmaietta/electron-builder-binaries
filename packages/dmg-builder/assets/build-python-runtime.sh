#!/usr/bin/env bash
set -euo pipefail

### ================================
### CONFIG
### ================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/dist}"
PYTHON_VERSION="${2:-3.11.8}"
DMGBUILD_VERSION="${3:-1.6.6}"
CODESIGN_IDENTITY="${4:-"-"}" # "-" = ad-hoc
ENTITLEMENTS_PLIST="${5:-}"

MACOS_DEPLOYMENT_TARGET="11.0"
ROOT_DIR="${SCRIPT_DIR}/../build/python-runtime"
SRC_DIR="$ROOT_DIR/src"
PREFIX="$ROOT_DIR/python"
JOBS="$(sysctl -n hw.ncpu)"

echo "🐍 dmgbuild portable bundler"
echo "📁 Output directory: ${OUTPUT_DIR}"
echo "🔢 Python version: ${PYTHON_VERSION}"
echo "📦 dmgbuild version: ${DMGBUILD_VERSION}"
echo ""

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "❌ Must be run on macOS"
    exit 1
fi

### ================================
### CLEAN
### ================================
rm -rf "$ROOT_DIR"
mkdir -p "$SRC_DIR"

### ================================
### FETCH PYTHON
### ================================
cd "$SRC_DIR"
curl -LO https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz
tar xf Python-${PYTHON_VERSION}.tgz
cd Python-${PYTHON_VERSION}

### ================================
### BUILD ENV (NO HOMEBREW)
### ================================
export MACOSX_DEPLOYMENT_TARGET
export CC=clang
export CXX=clang++
export CFLAGS="-O3 -fPIC"
export LDFLAGS=""
unset CPATH LIBRARY_PATH PKG_CONFIG_PATH SDKROOT

### ================================
### CONFIGURE
### ================================
./configure \
--prefix="$PREFIX" \
--enable-optimizations \
--without-ensurepip \
--disable-shared \
--disable-test-modules \
ac_cv_func_clock_gettime=no

### ================================
### BUILD & INSTALL
### ================================
make -j"$JOBS"
make install

### ================================
### INSTALL REQUIRED TOOLS
### ================================
"$PREFIX/bin/python3" -m pip install --upgrade pip
"$PREFIX/bin/python3" -m pip install dmgbuild==${DMGBUILD_VERSION}

### ================================
### AGGRESSIVE SIZE REDUCTION
### ================================
echo "Reducing runtime size..."

# Compile to bytecode only
"$PREFIX/bin/python3" -m compileall -q -j 0 "$PREFIX/lib/python3.11"
find "$PREFIX/lib/python3.11" -name "*.py" -delete

# Remove unused stdlib
rm -rf \
  "$PREFIX/lib/python3.11/test" \
  "$PREFIX/lib/python3.11/idlelib" \
  "$PREFIX/lib/python3.11/tkinter" \
  "$PREFIX/lib/python3.11/turtledemo" \
  "$PREFIX/lib/python3.11/pydoc_data" \
  "$PREFIX/lib/python3.11/lib2to3" \
  "$PREFIX/lib/python3.11/distutils" \
  "$PREFIX/lib/python3.11/venv" \
  "$PREFIX/lib/python3.11/unittest" \
  "$PREFIX/lib/python3.11/sqlite3" \
  "$PREFIX/lib/python3.11/asyncio"

# Remove extra tools
rm -f \
  "$PREFIX/bin/2to3" \
  "$PREFIX/bin/pydoc3" \
  "$PREFIX/bin/idle3"

# Strip binaries
find "$PREFIX" -type f \( -name "*.so" -o -name "*.dylib" -o -perm +111 \) \
  -exec strip -S {} \; || true

# Remove metadata
find "$PREFIX/lib/python3.11/site-packages" \
  -name "*.dist-info" -prune -exec rm -rf {} +

find "$PREFIX" -name "__pycache__" -type d -exec rm -rf {} +


### ================================
### FIX RPATHS (RELOCATABLE)
### ================================

find "$PREFIX" -type f \( -name "*.so" -o -name "*.dylib" \) | while read -r BIN; do
  echo "Fixing rpath for $BIN"
  install_name_tool -add_rpath "@loader_path/../lib" "$BIN"
  if [ -n "$LIBPYTHON" ]; then
    install_name_tool -change "$LIBPYTHON" "@rpath/$(basename "$LIBPYTHON")" "$BIN"
  fi
done

install_name_tool -add_rpath "@executable_path/../lib" "$PREFIX/bin/python3"

### ================================
### CODESIGN
### ================================
echo "Codesigning runtime..."

if [[ -n "$ENTITLEMENTS_PLIST" ]]; then
    find "$PREFIX" -type f \( -name "*.so" -o -name "*.dylib" -o -perm +111 \) \
    -exec codesign --force --options runtime \
    --entitlements "$ENTITLEMENTS_PLIST" \
    --sign "$CODESIGN_IDENTITY" {} +
else
    find "$PREFIX" -type f \( -name "*.so" -o -name "*.dylib" -o -perm +111 \) \
    -exec codesign --force --sign "$CODESIGN_IDENTITY" {} +
fi

codesign --force --sign "$CODESIGN_IDENTITY" "$PREFIX/bin/python3"

### ================================
### VERIFY
### ================================
"$PREFIX/bin/python3" - <<EOF
import sys, dmgbuild
print("OK:", sys.version)
print("dmgbuild:", dmgbuild.__version__)
EOF

echo
echo "✅ Python runtime built successfully"
du -sh "$PREFIX"

cd "${PREFIX}"

ARCHIVE="dmgbuild-bundle-${ARCH}-${DMGBUILD_VERSION}.tar.gz"
ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE}"

tar -czf "${ARCHIVE_PATH}" -C "${OUTPUT_DIR}" .

shasum -a 256 "${ARCHIVE_PATH}" > "${ARCHIVE_PATH}.sha256"

echo "✅ Created ${ARCHIVE}"
