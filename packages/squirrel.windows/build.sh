#!/usr/bin/env bash
set -ex

VERSION=2.0.0

BASEDIR=$(cd "$(dirname "$0")" && pwd)

OUT_DIR=$BASEDIR/out/squirrel.windows
rm -rf $OUT_DIR
mkdir -p $OUT_DIR

TMP_DIR=/tmp/squirrel
rm -rf $TMP_DIR
mkdir $TMP_DIR

cd $TMP_DIR
git clone --single-branch --depth 1 --branch $VERSION --recursive https://github.com/squirrel/squirrel.windows
cd $TMP_DIR/squirrel.windows
cp -a $BASEDIR/patches/* $TMP_DIR/squirrel.windows
git apply $TMP_DIR/squirrel.windows/*.patch

./.nuget/NuGet.exe restore
msbuild /p:Configuration=Release

echo $VERSION > $TMP_DIR/VERSION.txt

DESTINATION="$OUT_DIR/squirrel.windows-$VERSION-patched.7z"
7za a -mx=9 -mfb=64 "$DESTINATION" "$TMP_DIR"/*
