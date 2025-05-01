#!/usr/bin/env bash
set -e

BASEDIR=$(cd "$(dirname "$0")/../.." && pwd)
cd $BASEDIR
OUTPUT_DIR=$BASEDIR/${OUTPUT_SUBDIR:-"out/fpm"}
rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

TMP_DIR=/tmp/fpm
rm -rf $TMP_DIR
mkdir -p $TMP_DIR

RUBY_VERSION=3.4.0
FPM_VERSION=1.16.0
echo "RUBY_VERSION: $RUBY_VERSION"
echo "FPM_VERSION: $FPM_VERSION"

rm -f $BASEDIR/Gemfile

# sudo might be needed for some systems (e.g. ubuntu GH runners)
gem install bundler --no-document --quiet || sudo gem install bundler --no-document --quiet
bundle init

echo "\"ruby\" \"$RUBY_VERSION\"" >> $BASEDIR/Gemfile
echo "gem \"fpm\", \"$FPM_VERSION\"" >> $BASEDIR/Gemfile

bundle install --without=development --path=$TMP_DIR/

# gem install fpm --version $FPM_VERSION --install-dir $TMP_DIR --no-document --quiet

cp -a $TMP_DIR/* $OUTPUT_DIR
rm -rf $OUTPUT_DIR/ruby/$RUBY_VERSION/{build_info,cache,doc,extensions,doc,plugins,specifications,tests}
echo $FPM_VERSION > $OUTPUT_DIR/VERSION

# create symlink to fpm relative to the output directory so that it correctly copies out of the docker image
cd $OUTPUT_DIR
ln -s ./ruby/$RUBY_VERSION/bin/fpm fpm

echo "FPM installed to $OUTPUT_DIR"
# verify symlink and installation
echo "FPM version: $(./fpm --version)"