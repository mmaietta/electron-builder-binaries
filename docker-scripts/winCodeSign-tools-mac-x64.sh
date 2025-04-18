#!/usr/bin/env bash
set -ex


BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
cd $BASEDIR
OUTPUT_DIR=$BASEDIR/winCodeSign/darwin
mkdir -p $OUTPUT_DIR

VERSION=2.9

rm -rf a $OUTPUT_DIR
curl -L https://github.com/mtrojnar/osslsigncode/releases/download/$VERSION/osslsigncode-$VERSION-macOS.zip > a.zip
7za x a.zip -oa
unlink a.zip

cp -a a/bin $OUTPUT_DIR/
echo $VERSION > $OUTPUT_DIR/VERSION
chmod +x $OUTPUT_DIR/osslsigncode

rm -rf a