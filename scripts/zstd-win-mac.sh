#!/usr/bin/env bash
set -ex

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
cd $BASEDIR
OUTPUT_DIR=$BASEDIR/out/zstd
mkdir -p $OUTPUT_DIR

TMP_DIR=/tmp/zstd
rm -rf $TMP_DIR
mkdir $TMP_DIR
cd $TMP_DIR

curl -L https://github.com/facebook/zstd/releases/download/v1.5.0/zstd-v1.5.0-win64.zip --output zstd-win64.zip
unzip zstd-win64.zip
cp zstd-v1.5.0-win64/zstd.exe "$OUTPUT_DIR/win-x64/zstd.exe"

curl -L https://github.com/facebook/zstd/releases/download/v1.5.0/zstd-v1.5.0-win32.zip --output zstd-win32.zip
unzip zstd-win32.zip
cp zstd-v1.5.0-win32/zstd.exe "$OUTPUT_DIR/win-ia32/zstd.exe"

# build on macOS
git clone --depth 1 --branch v1.5.0 https://github.com/facebook/zstd.git
cd zstd
make -j5
cp programs/zstd "$OUTPUT_DIR/mac/zstd"

rm -rf $TMP_DIR