#!/usr/bin/env bash
set -ex

echo "🔧 Downloading latest SCons (4.7.0)..."
mkdir -p /tmp/scons
curl -sL https://files.pythonhosted.org/packages/source/s/scons/scons-4.7.0.tar.gz | tar -xz -C /tmp/scons --strip-components 1
export PYTHONPATH="/tmp/scons"

echo "📦 Cloning NSIS 3.11 source..."
rm -rf /tmp/nsis
git clone --branch v3.11 --depth 1 https://github.com/kichik/nsis.git /tmp/nsis
cd /tmp/nsis

echo "✏️ Patching config.h..."
CONFIG="Source/exehead/config.h"
sed -i 's/^#define NSIS_MAX_STRLEN.*/#define NSIS_MAX_STRLEN 8192/' "$CONFIG"
grep -q NSIS_CONFIG_LOG "$CONFIG" || echo "#define NSIS_CONFIG_LOG" >> "$CONFIG"
grep -q NSIS_SUPPORT_LOG "$CONFIG" || echo "#define NSIS_SUPPORT_LOG" >> "$CONFIG"

echo "🛠️ Building makensis (NSIS 3.11, minimal)..."
/usr/bin/python /tmp/scons/script/scons.py \
  STRIP=0 \
  SKIPSTUBS=all \
  SKIPPLUGINS=all \
  SKIPUTILS=all \
  SKIPMISC=all \
  NSIS_CONFIG_CONST_DATA_PATH=no \
  NSIS_CONFIG_LOG=yes \
  NSIS_MAX_STRLEN=8192 \
  makensis

echo "✅ Build complete: /tmp/nsis/Build/urelease/makensis.exe"
ls -lh /tmp/nsis/Build/urelease/makensis.exe
