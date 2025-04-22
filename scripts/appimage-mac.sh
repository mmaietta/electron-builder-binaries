#!/usr/bin/env bash
set -ex

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
cd $BASEDIR
OUT_DIR=$BASEDIR/out/AppImage/darwin
rm -rf $OUT_DIR
mkdir -p $OUT_DIR

OUTPUT_DIR=/tmp/appimage-mac
rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR

# Download the latest versions for desktop-file-validate and mksquashfs (macOS)
brew install desktop-file-utils squashfs
cp -aL $(which desktop-file-validate) $OUTPUT_DIR/desktop-file-validate
cp -aL $(which mksquashfs) $OUTPUT_DIR/mksquashfs

cp -aL $OUTPUT_DIR/* $OUT_DIR
rm -rf $OUTPUT_DIR