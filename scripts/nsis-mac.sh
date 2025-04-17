#!/usr/bin/env bash
set -ex

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
cd $BASEDIR

OUTPUT_DIR=/tmp/nsis-mac
rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR

# Download the latest version of NSIS (macOS)
mkdir -p $OUTPUT_DIR/mac
brew tap nsis-dev/makensis
brew install makensis@3.11 --with-large-strings --with-advanced-logging
cp $(which makensis) $OUTPUT_DIR/mac/makensis

cp -a $OUTPUT_DIR/* ./nsis