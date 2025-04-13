#!/usr/bin/env bash
set -ex

BASEDIR=$(dirname "$0")


rm -rf a $BASEDIR/../winCodeSign/darwin/
curl -L 'https://github.com/mtrojnar/osslsigncode/releases/download/2.9/osslsigncode-2.9-macOS.zip' > a.zip
7za x a.zip -oa
unlink a.zip
cp -a a/bin $BASEDIR/../winCodeSign/darwin/