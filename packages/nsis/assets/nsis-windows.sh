#!/usr/bin/env bash
set -ex

echo "📦 Downloading latest SCons via PyPI..."
rm -rf /tmp/scons
mkdir -p /tmp/scons-download
python -m pip download scons --no-binary :all: -d /tmp/scons-download
tarball=$(find /tmp/scons-download -name 'scons-*.tar.gz' | head -n1)
mkdir -p /tmp/scons
tar -xzf "$tarball" -C /tmp/scons --strip-components 1
export PYTHONPATH="/tmp/scons"

echo "📥 Cloning NSIS 3.11 source..."
rm -rf /tmp/nsis
git clone --branch v3.11 --depth 1 https://github.com/kichik/nsis.git /tmp/nsis
cd /tmp/nsis

echo "✏️ Patching config.h for STRLEN and LOGGING..."
CONFIG="Source/exehead/config.h"
sed -i 's/^#define NSIS_MAX_STRLEN.*/#define NSIS_MAX_STRLEN 8192/' "$CONFIG"
grep -q NSIS_CONFIG_LOG "$CONFIG" || echo "#define NSIS_CONFIG_LOG" >> "$CONFIG"
grep -q NSIS_SUPPORT_LOG "$CONFIG" || echo "#define NSIS_SUPPORT_LOG" >> "$CONFIG"

echo "🛠️ Building makensis (NSIS 3.11)..."
python /tmp/scons/script/scons.py \
  STRIP=0 \
  SKIPSTUBS=all \
  SKIPPLUGINS=all \
  SKIPUTILS=all \
  SKIPMISC=all \
  NSIS_CONFIG_CONST_DATA_PATH=no \
  NSIS_CONFIG_LOG=yes \
  NSIS_MAX_STRLEN=8192 \
  makensis

echo "✅ Done: /tmp/nsis/Build/urelease/makensis.exe"
ls -lh /tmp/nsis/Build/urelease/makensis.exe

echo "🗜️ Compressing to vendor.7z..."
7z a -m0=lzma2 -mx=9 -mfb=64 -md=64m -ms=on nsis-3.11.7z /tmp/nsis/Build/urelease/

echo "✅ Done. Output: nsis-3.11.7z"
