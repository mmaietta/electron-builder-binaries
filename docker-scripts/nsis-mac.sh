#!/usr/bin/env bash
set -ex
BASEDIR=$(dirname "$0")
OUTPUT_DIR=/tmp/nsis
rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR

# Download the latest version of NSIS (macOS)
mkdir -p $OUTPUT_DIR/mac
brew tap nsis-dev/makensis
brew install makensis@3.11 --with-large-strings --with-advanced-logging
cp $(which makensis) $OUTPUT_DIR/mac/makensis

cd $BASEDIR/..
cp -a $OUTPUT_DIR/* ./nsis