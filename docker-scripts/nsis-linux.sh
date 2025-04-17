#!/usr/bin/env bash
set -ex

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
cd $BASEDIR
DIR=$BASEDIR/nsis/win

OUTPUT_DIR=/tmp/nsis-linux
rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

# mkdir $OUTPUT_DIR/linux
# cp /usr/local/bin/makensis $OUTPUT_DIR/linux/makensis

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

# find $DIR -type d ! -name 'linux' ! -name 'mac' -exec rm -rf "{}" +
mkdir -p $DIR
cp -a $OUTPUT_DIR/* $DIR