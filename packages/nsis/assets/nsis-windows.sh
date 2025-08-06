#!/usr/bin/env bash
set -ex

echo "🔧 Setting up Python environment..."
python -m pip install --upgrade pip
python -m pip install scons

echo "📁 Cloning NSIS..."
rm -rf nsis nsis-src vendor vendor.7z
git clone https://github.com/kichik/nsis.git nsis
cd nsis
git checkout v3.11

echo "✏️ Patching config.h..."
CONFIG_FILE="Source/exehead/config.h"
sed -i 's/^#define NSIS_MAX_STRLEN.*/#define NSIS_MAX_STRLEN 8192/' "$CONFIG_FILE"

# Ensure logging flags are defined
grep -q NSIS_CONFIG_LOG "$CONFIG_FILE" || echo "#define NSIS_CONFIG_LOG" >> "$CONFIG_FILE"
grep -q NSIS_SUPPORT_LOG "$CONFIG_FILE" || echo "#define NSIS_SUPPORT_LOG" >> "$CONFIG_FILE"

echo "🛠️ Building NSIS with SCons..."
scons SKIPPLUGINS=0 NSIS_MAX_STRLEN=8192 NSIS_CONFIG_LOG=yes

echo "📦 Creating portable vendor folder..."
cd ..
mkdir -p vendor/Bin

cp nsis/Build/urelease/makensis.exe vendor/Bin/
cp nsis/Build/urelease/zlib1.dll vendor/Bin/ || true
cp nsis/Build/urelease/NSIS.exe vendor/
cp nsis/Build/urelease/elevate.exe vendor/ || true
cp nsis/nsisconf.nsh nsis/COPYING vendor/

cp -r nsis/Include vendor/
cp -r nsis/Stubs vendor/
cp -r nsis/Menu vendor/
cp -r nsis/Plugins vendor/
cp -r nsis/Contrib vendor/Contrib

echo "🧼 Removing unnecessary files..."
rm -rf vendor/Docs vendor/Examples vendor/NSIS.chm vendor/Bin/makensisw.exe

echo "🔌 Downloading and adding nsProcess plugin..."
curl -L -o a.zip http://nsis.sourceforge.net/mediawiki/images/1/18/NsProcess.zip
7z x a.zip -oa
mv a/Plugin/nsProcessW.dll vendor/Plugins/x86-unicode/nsProcess.dll
mv a/Plugin/nsProcess.dll vendor/Plugins/x86-ansi/nsProcess.dll
mv a/Include/nsProcess.nsh vendor/Include/nsProcess.nsh
rm -rf a a.zip

echo "🔌 Adding UAC plugin..."
curl -L -o a.zip http://nsis.sourceforge.net/mediawiki/images/8/8f/UAC.zip
7z x a.zip -oa
mv a/Plugins/x86-unicode/UAC.dll vendor/Plugins/x86-unicode/UAC.dll
mv a/Plugins/x86-ansi/UAC.dll vendor/Plugins/x86-ansi/UAC.dll
mv a/UAC.nsh vendor/Include/UAC.nsh
rm -rf a a.zip

echo "🔌 Adding WinShell plugin..."
curl -L -o a.zip http://nsis.sourceforge.net/mediawiki/images/5/54/WinShell.zip
7z x a.zip -oa
mv a/Plugins/x86-unicode/WinShell.dll vendor/Plugins/x86-unicode/WinShell.dll
mv a/Plugins/x86-ansi/WinShell.dll vendor/Plugins/x86-ansi/WinShell.dll
rm -rf a a.zip

echo "🗜️ Compressing to vendor.7z..."
7z a -m0=lzma2 -mx=9 -mfb=64 -md=64m -ms=on vendor.7z vendor/

echo "✅ Done. Output: vendor.7z"
