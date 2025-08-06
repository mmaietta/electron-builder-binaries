#!/usr/bin/env bash
set -ex

echo "📦 Downloading SCons 4.7.0 from PyPI..."
rm -rf /tmp/scons /tmp/scons-download
mkdir -p /tmp/scons-download
python -m pip download scons==4.7.0 --no-binary :all: -d /tmp/scons-download

echo "📦 Extracting SCons..."
tarball=$(find /tmp/scons-download -iname 'scons-*.tar.gz' | head -n1)
mkdir -p /tmp/scons
tar -xzf "$tarball" -C /tmp/scons --strip-components=1
export PYTHONPATH="/tmp/scons"

echo "📥 Cloning NSIS v3.11..."
rm -rf /tmp/nsis
git clone --branch v311 --depth 1 https://github.com/kichik/nsis.git /tmp/nsis
cd /tmp/nsis

echo "✏️ Patching config.h for STRLEN=8192 and LOGGING..."
CONFIG="Source/exehead/config.h"
sed -i 's/^#define NSIS_MAX_STRLEN.*/#define NSIS_MAX_STRLEN 8192/' "$CONFIG"
grep -q NSIS_CONFIG_LOG "$CONFIG" || echo "#define NSIS_CONFIG_LOG" >> "$CONFIG"
grep -q NSIS_SUPPORT_LOG "$CONFIG" || echo "#define NSIS_SUPPORT_LOG" >> "$CONFIG"

# Optional cross-compile setup
if [[ "${BUILD_WINDOWS:-0}" == "1" ]]; then
  echo "🪟 Setting up Windows build dependencies..."
  sudo apt-get update
  sudo apt-get install -y mingw-w64 unzip curl

  echo "📦 Downloading and building zlib for Windows..."
  cd /tmp
  curl -LO https://zlib.net/zlib1211.zip
  unzip -q zlib1211.zip
  cd zlib-1.2.11
  make -f win32/Makefile.gcc PREFIX=i686-w64-mingw32- \
    BINARY_PATH=$(pwd)/bin INCLUDE_PATH=$(pwd)/include LIBRARY_PATH=$(pwd)/lib
  export ZLIB_W32="$(pwd)"
  cd /tmp/nsis

  echo "🛠️ Building Windows makensis.exe..."
  python -m SCons \
    STRIP=0 \
    NSIS_MAX_STRLEN=8192 \
    NSIS_CONFIG_LOG=yes \
    NSIS_CONFIG_CONST_DATA_PATH=no \
    SKIPSTUBS=all SKIPPLUGINS=all
else
  echo "🛠️ Building native Linux makensis..."
python -m SCons \
  TARGET_ARCHITECTURE=posix \
  STRIP=0 \
  NSIS_MAX_STRLEN=8192 \
  NSIS_CONFIG_LOG=yes \
  NSIS_CONFIG_CONST_DATA_PATH=no \
  SKIPSTUBS=all SKIPPLUGINS=all
fi

echo "📂 Creating vendor/ structure..."
cd /tmp
rm -rf vendor
mkdir -p vendor

cp -r nsis/Contrib vendor/
cp -r nsis/Include vendor/
cp -r nsis/Plugins vendor/
cp -r nsis/Stubs vendor/
cp -r nsis/Menu vendor/
cp -r nsis/Build/urelease vendor/Bin || cp -r nsis/Build/ulocal vendor/Bin
cp nsis/NSIS.exe vendor/ 2>/dev/null || true
cp nsis/nsisconf.nsh vendor/
cp nsis/COPYING vendor/
cp nsis/elevate.exe vendor/ || true

# Cleanup
rm -f vendor/Bin/makensisw.exe || true
rm -rf vendor/Docs vendor/Examples vendor/NSIS.chm

echo "🔌 Downloading additional plugins..."
cd vendor

# nsProcess
curl -sL http://nsis.sourceforge.net/mediawiki/images/1/18/NsProcess.zip -o np.zip
7z x np.zip -oa
mv a/Plugin/nsProcess.dll Plugins/x86-ansi/nsProcess.dll
mv a/Plugin/nsProcessW.dll Plugins/x86-unicode/nsProcess.dll
mv a/Include/nsProcess.nsh Include/nsProcess.nsh
rm -rf a np.zip

# UAC
curl -sL http://nsis.sourceforge.net/mediawiki/images/8/8f/UAC.zip -o uac.zip
7z x uac.zip -oa
mv a/Plugins/x86-ansi/UAC.dll Plugins/x86-ansi/UAC.dll
mv a/Plugins/x86-unicode/UAC.dll Plugins/x86-unicode/UAC.dll
mv a/UAC.nsh Include/UAC.nsh
rm -rf a uac.zip

# WinShell
curl -sL http://nsis.sourceforge.net/mediawiki/images/5/54/WinShell.zip -o ws.zip
7z x ws.zip -oa
mv a/Plugins/x86-ansi/WinShell.dll Plugins/x86-ansi/WinShell.dll
mv a/Plugins/x86-unicode/WinShell.dll Plugins/x86-unicode/WinShell.dll
rm -rf a ws.zip

echo "🗜️ Compressing vendor folder into vendor.7z..."
7z a -m0=lzma2 -mx=9 -mfb=64 -md=64m -ms=on vendor.7z vendor/

echo "✅ Done!"
ls -lh vendor.7z
