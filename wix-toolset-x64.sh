#!/usr/bin/env bash
set -ex

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

rm -rf $BASEDIR/wix
mkdir -p $BASEDIR/wix

curl -L 'https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip' > a.zip
7za x a.zip -oa
unlink a.zip
cp -a a/* $BASEDIR/wix
rm -rf a
rm -rf $BASEDIR/wix/sdk
rm -rf $BASEDIR/wix/doc