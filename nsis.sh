#!/usr/bin/env bash
set -ex

# How do update NSIS:
# 1. Download https://sourceforge.net/projects/nsis/files/NSIS%203/3.03/nsis-3.03.zip/download (replace 3.03 to new version)
# 2. Copy over nsis in this repo and copy nsis-lang-fixes to nsis/Contrib/Language files
# 3. Inspect changed and unversioned files — delete if need.
# 4. Download https://netix.dl.sourceforge.net/project/nsis/NSIS%203/3.03/nsis-3.03-strlen_8192.zip and copy over
# 5. brew install makensis --with-large-strings --with-advanced-logging && sudo cp /usr/local/Cellar/makensis/*/bin/makensis nsis/mac/makensis
# 6. See nsis-linux.sh

# This script must be run on a macOS machine

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR=/tmp/nsis
rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR

# Download the latest version of NSIS (Windows)
curl 'https://pilotfiber.dl.sourceforge.net/project/nsis/NSIS%203/3.11/nsis-3.11.zip?viasf=1' > nsis.zip
unzip -o nsis.zip -d nsis-3.11
cp -a nsis-3.11/nsis-3.11/* $OUTPUT_DIR/
rm -rf nsis.zip nsis-3.11

curl 'https://master.dl.sourceforge.net/project/nsis/NSIS%203/3.11/nsis-3.11-strlen_8192.zip?viasf=1' > nsis-strlen_8192.zip
unzip -o nsis-strlen_8192.zip -d nsis-strlen_8192
cp -a nsis-strlen_8192/* $OUTPUT_DIR/
rm -rf nsis-strlen_8192.zip nsis-strlen_8192

# cleanup untracked files
rm $OUTPUT_DIR/Bin/GenPat.exe
rm $OUTPUT_DIR/Bin/MakeLangId.exe
rm $OUTPUT_DIR/Bin/RegTool-x86.bin
rm $OUTPUT_DIR/Bin/zip2exe.exe
rm -rf $OUTPUT_DIR/Docs/
rm -rf $OUTPUT_DIR/Examples/
# rm $OUTPUT_DIR/Include/Integration.nsh
# rm $OUTPUT_DIR/Include/Win/RestartManager.nsh
rm $OUTPUT_DIR/NSIS.chm
rm $OUTPUT_DIR/makensisw.exe

# Copy over the "fixed" language files (are these still needed?)
cp -a $BASEDIR/nsis-lang-fixes/* $OUTPUT_DIR/Contrib/Language\ files/


# nsProcess plugin
curl -L http://nsis.sourceforge.net/mediawiki/images/1/18/NsProcess.zip > a.zip
7za x a.zip -oa
mv a/Plugin/nsProcessW.dll $OUTPUT_DIR/Plugins/x86-unicode/nsProcess.dll
mv a/Plugin/nsProcess.dll $OUTPUT_DIR/Plugins/x86-ansi/nsProcess.dll
mv a/Include/nsProcess.nsh $OUTPUT_DIR/Include/nsProcess.nsh
rm -rf a a.zip

# UAC plugin
curl -L http://nsis.sourceforge.net/mediawiki/images/8/8f/UAC.zip > a.zip
7za x a.zip -oa
mv a/Plugins/x86-unicode/UAC.dll $OUTPUT_DIR/Plugins/x86-unicode/UAC.dll
mv a/Plugins/x86-ansi/UAC.dll $OUTPUT_DIR/Plugins/x86-ansi/UAC.dll
mv a/UAC.nsh $OUTPUT_DIR/Include/UAC.nsh
rm -rf a a.zip

# WinShell
curl -L http://nsis.sourceforge.net/mediawiki/images/5/54/WinShell.zip > a.zip
7za x a.zip -oa
mv a/Plugins/x86-unicode/WinShell.dll $OUTPUT_DIR/Plugins/x86-unicode/WinShell.dll
mv a/Plugins/x86-ansi/WinShell.dll $OUTPUT_DIR/Plugins/x86-ansi/WinShell.dll
rm -rf a a.zip

# Download the latest version of NSIS (macOS)
mkdir -p $OUTPUT_DIR/mac
brew tap nsis-dev/makensis
brew install makensis@3.11 --with-large-strings --with-advanced-logging
cp $(which makensis) $OUTPUT_DIR/mac/makensis

# Build the latest version of NSIS (Linux) in docker container
cidFile="/tmp/nsis-build-container-id"
if test -f "$cidFile"; then
  echo "already running (removing $cidFile)"
  containerId=$(cat "$cidFile")
  docker rm "$containerId"
  unlink "$cidFile"
fi

cd "$BASEDIR"
docker run --cidfile="$cidFile" buildpack-deps:xenial bash -c \
'mkdir -p /tmp/scons && curl -L http://prdownloads.sourceforge.net/scons/scons-local-2.5.1.tar.gz | tar -xz -C /tmp/scons &&
 mkdir -p /tmp/nsis && curl -L https://sourceforge.net/projects/nsis/files/NSIS%203/3.04/nsis-3.04-src.tar.bz2/download | tar -xj -C /tmp/nsis --strip-components 1 &&
 cd /tmp/nsis &&
 python /tmp/scons/scons.py STRIP=0 SKIPSTUBS=all SKIPPLUGINS=all SKIPUTILS=all SKIPMISC=all NSIS_CONFIG_CONST_DATA_PATH=no NSIS_CONFIG_LOG=yes NSIS_MAX_STRLEN=8192 makensis
 '

containerId=$(cat "$cidFile")
mkdir $OUTPUT_DIR/linux
docker cp "$containerId":/tmp/nsis/build/urelease/makensis/makensis $OUTPUT_DIR/linux/makensis
docker rm "$containerId"
unlink "$cidFile"


rm -rf $BASEDIR/nsis
mkdir $BASEDIR/nsis
cp -a $OUTPUT_DIR/* $BASEDIR/nsis
# rm -rf $OUTPUT_DIR