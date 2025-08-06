#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Detecting OS..."
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
IS_WINDOWS=0
if [[ "$OS_NAME" == "mingw"* || "$OS_NAME" == "msys"* || "$OS_NAME" == "cygwin"* ]]; then
  IS_WINDOWS=1
fi

echo "📥 Cloning NSIS v3.11..."
rm -rf /tmp/nsis
git clone --branch v311 --depth 1 https://github.com/kichik/nsis.git /tmp/nsis
cd /tmp/nsis

echo "✏️ Patching config.h..."
CONFIG="Source/exehead/config.h"
sed -i.bak 's/^#define NSIS_MAX_STRLEN.*/#define NSIS_MAX_STRLEN 8192/' "$CONFIG"
grep -q NSIS_CONFIG_LOG "$CONFIG" || echo "#define NSIS_CONFIG_LOG" >> "$CONFIG"
grep -q NSIS_SUPPORT_LOG "$CONFIG" || echo "#define NSIS_SUPPORT_LOG" >> "$CONFIG"

if [[ "$IS_WINDOWS" == "1" ]]; then
  echo "🪟 Windows detected. Building zlib for Win32..."

  ZLIB_VERSION="1.3.1"
  ZLIB_DIR="/tmp/zlib-$ZLIB_VERSION"

  cd /tmp
  curl -LO "https://zlib.net/zlib-$ZLIB_VERSION.tar.gz"
  tar -xzf zlib-$ZLIB_VERSION.tar.gz
  cd zlib-$ZLIB_VERSION

  echo "🧱 Building zlib with MinGW..."
  make -f win32/Makefile.gcc \
    PREFIX=i686-w64-mingw32- \
    BINARY_PATH="$ZLIB_DIR/bin" \
    INCLUDE_PATH="$ZLIB_DIR/include" \
    LIBRARY_PATH="$ZLIB_DIR/lib"

  export ZLIB_W32="$ZLIB_DIR"

  echo "🛠️ Building makensis.exe..."
  python -m SCons \
    STRIP=0 \
    NSIS_MAX_STRLEN=8192 \
    NSIS_CONFIG_LOG=yes \
    NSIS_CONFIG_CONST_DATA_PATH=no \
    SKIPSTUBS=all \
    SKIPPLUGINS=all \
    ZLIB_W32="$ZLIB_W32"
else
  echo "🐧 Linux/macOS detected. Building POSIX makensis..."
  python -m SCons \
    TARGET_ARCHITECTURE=posix \
    STRIP=0 \
    NSIS_MAX_STRLEN=8192 \
    NSIS_CONFIG_LOG=yes \
    NSIS_CONFIG_CONST_DATA_PATH=no \
    SKIPSTUBS=all \
    SKIPPLUGINS=all
fi

echo "📦 NSIS built successfully. Output files:"
find Build -type f -name "makensis*" -exec ls -lh {} \;
