#!/usr/bin/env bash
set -ex

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
cd $BASEDIR
OUT_DIR=$BASEDIR/out/AppImage/darwin
mkdir -p $OUT_DIR

OUTPUT_DIR=/tmp/appimage-mac
rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR

# Download the latest version of NSIS (macOS)
mkdir -p $OUTPUT_DIR/mac
brew install desktop-file-utils
brew install squashfs
cp -a $(which desktop-file-validate) $OUTPUT_DIR/desktop-file-validate
cp -a $(which mksquashfs) $OUTPUT_DIR/mksquashfs

cp -a $OUTPUT_DIR/* $OUT_DIR
rm -rf $OUTPUT_DIR