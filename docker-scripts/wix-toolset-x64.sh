#!/usr/bin/env bash
set -ex

BASEDIR=$(dirname "$0")
cd $BASEDIR/..
OUTPUT_DIR=$(pwd)/wix
rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

curl -L 'https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip' > a.zip
7za x a.zip -oa
unlink a.zip
cp -a a/* $OUTPUT_DIR
rm -rf a
rm -rf $OUTPUT_DIR/sdk
rm -rf $OUTPUT_DIR/doc