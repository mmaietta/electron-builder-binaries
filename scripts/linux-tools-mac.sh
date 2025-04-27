#!/usr/bin/env bash
set -ex

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
cd $BASEDIR
OUTPUT_DIR=$BASEDIR/out/linux-tools
rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

TMP_DIR=/tmp/linux-tools
rm -rf $TMP_DIR
mkdir $TMP_DIR

brew install gettext glib gnu-tar libffi libgsf libtool lzip makedepend openssl osslsigncode pcre

cp -a $(brew --prefix)/Cellar $TMP_DIR/Cellar
cp -a $(brew --prefix)/bin $TMP_DIR/bin
# cp -a $(brew --prefix)/etc $TMP_DIR/etc
# cp -a $(brew --prefix)/include $TMP_DIR/include
# cp -a $(brew --prefix)/lib $TMP_DIR/lib
cp -a $(brew --prefix)/opt $TMP_DIR/opt

cp -a $TMP_DIR/* $OUTPUT_DIR
rm -rf $TMP_DIR