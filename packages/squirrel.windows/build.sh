#!/usr/bin/env bash
set -ex

VERSION=2.0.1

BASEDIR=$(cd "$(dirname "$0")" && pwd)
cd $BASEDIR
OUT_DIR=$BASEDIR/out/squirrel.windows
rm -rf $OUT_DIR
mkdir -p $OUT_DIR
# Check if the script is run from the correct directory
if [ ! -d "./out/squirrel.windows" ]; then
    echo "This script must be run from the squirrel.windows directory."
    exit 1
fi

TMP_DIR=/tmp/squirrel
rm -rf $TMP_DIR
mkdir $TMP_DIR

cd $TMP_DIR
git clone --single-branch --depth 1 --branch $VERSION --recursive https://github.com/squirrel/squirrel.windows
cd $TMP_DIR/squirrel.windows
cp -a $BASEDIR/patches/* $TMP_DIR/squirrel.windows
git apply $TMP_DIR/squirrel.windows/*.patch

.\.nuget\NuGet.exe restore
msbuild /p:Configuration=Release

echo $VERSION > $TMP_DIR/VERSION

rm -rf $OUT_DIR
mkdir $OUT_DIR
cp -a $TMP_DIR/* $OUT_DIR