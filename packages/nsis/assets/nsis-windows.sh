#!/usr/bin/env bash
set -euo pipefail

echo "📥 Install Scons..."
python -m pip install --upgrade pip
python -m pip install scons

echo "📥 Cloning NSIS v3.11..."
rm -rf /tmp/nsis
git clone --branch v311 --depth 1 https://github.com/kichik/nsis.git /tmp/nsis
cd /tmp/nsis

echo "✏️ Patching config.h for STRLEN=8192 and LOGGING..."
CONFIG="Source/exehead/config.h"
sed -i.bak 's/^#define NSIS_MAX_STRLEN.*/#define NSIS_MAX_STRLEN 8192/' "$CONFIG"
grep -q NSIS_CONFIG_LOG "$CONFIG" || echo "#define NSIS_CONFIG_LOG" >> "$CONFIG"
grep -q NSIS_SUPPORT_LOG "$CONFIG" || echo "#define NSIS_SUPPORT_LOG" >> "$CONFIG"

echo "🔧 Detecting platform..."
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')

echo "🛠️ Building makensis for $OS_NAME..."

if [ "$OS_NAME" = "linux" ]; then
  python -m SCons \
    TARGET_ARCHITECTURE=posix \
    STRIP=0 \
    NSIS_MAX_STRLEN=8192 \
    NSIS_CONFIG_LOG=yes \
    NSIS_CONFIG_CONST_DATA_PATH=no \
    SKIPSTUBS=all \
    SKIPPLUGINS=all
else
  python -m SCons \
    STRIP=0 \
    NSIS_MAX_STRLEN=8192 \
    NSIS_CONFIG_LOG=yes \
    NSIS_CONFIG_CONST_DATA_PATH=no \
    SKIPSTUBS=all \
    SKIPPLUGINS=all
fi

echo "✅ Build complete. Output:"
find Build -type f
