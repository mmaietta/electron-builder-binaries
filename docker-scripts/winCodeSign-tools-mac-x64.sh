#!/usr/bin/env bash
set -ex


BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
cd $BASEDIR
OUTPUT_DIR=$BASEDIR/winCodeSign/darwin
mkdir -p $OUTPUT_DIR

rm -rf a $OUTPUT_DIR
curl -L 'https://github.com/mtrojnar/osslsigncode/releases/download/2.9/osslsigncode-2.9-macOS.zip' > a.zip
7za x a.zip -oa
unlink a.zip
cp -a a/bin $OUTPUT_DIR/