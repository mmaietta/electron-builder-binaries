#!/usr/bin/env bash
set -ex

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

rm -rf $BASEDIR/wix
mkdir -p $BASEDIR/wix

rm -rf a $BASEDIR/winCodeSign/darwin/
curl -L 'https://github.com/mtrojnar/osslsigncode/releases/download/2.9/osslsigncode-2.9-macOS.zip' > a.zip
7za x a.zip -oa
unlink a.zip
cp -a a/bin $BASEDIR/winCodeSign/darwin/