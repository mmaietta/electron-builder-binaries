#!/usr/bin/env bash
set -eu

echo "📦 Installing SCons (locally)..."
rm -rf /tmp/scons-local
python -m pip install --target /tmp/scons-local scons
export PYTHONPATH="/tmp/scons-local"

echo "📥 Cloning NSIS v3.11 source..."
rm -rf /tmp/nsis
git clone --branch v3.11 --depth 1 https://github.com/kichik/nsis.git /tmp/nsis
cd /tmp/nsis

echo "✏️ Patching config.h for STRLEN=8192 and LOGGING..."
CONFIG="Source/exehead/config.h"
sed -i 's/^#define NSIS_MAX_STRLEN.*/#define NSIS_MAX_STRLEN 8192/' "$CONFIG"
grep -q NSIS_CONFIG_LOG "$CONFIG" || echo "#define NSIS_CONFIG_LOG" >> "$CONFIG"
grep -q NSIS_SUPPORT_LOG "$CONFIG" || echo "#define NSIS_SUPPORT_LOG" >> "$CONFIG"

echo "🛠️ Building full NSIS + makensis.exe..."
python -m SCons \
  STRIP=0 \
  NSIS_MAX_STRLEN=8192 \
  NSIS_CONFIG_LOG=yes \
  NSIS_CONFIG_CONST_DATA_PATH=no

echo "📂 Preparing full vendor/ layout..."
cd /tmp
rm -rf vendor
mkdir -p vendor

cp -r nsis/Contrib vendor/
cp -r nsis/Include vendor/
cp -r nsis/Plugins vendor/
cp -r nsis/Stubs vendor/
cp -r nsis/Menu vendor/
cp -r nsis/Build/urelease vendor/Bin
cp nsis/NSIS.exe vendor/
cp nsis/nsisconf.nsh vendor/
cp nsis/COPYING vendor/
cp nsis/elevate.exe vendor/ || true

rm -rf vendor/Bin/makensisw.exe || true
rm -rf vendor/Docs vendor/Examples vendor/NSIS.chm

echo "🔌 Downloading and installing plugins..."

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

echo "🗜️ Compressing to vendor.7z..."
7z a -m0=lzma2 -mx=9 -mfb=64 -md=64m -ms=on vendor.7z vendor/

echo "✅ Done! Full portable package: /tmp/vendor.7z"