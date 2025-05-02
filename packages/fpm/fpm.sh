#!/usr/bin/env bash
set -e

BASEDIR=$(cd "$(dirname "$BASH_SOURCE")/../.." && pwd)
source $BASEDIR/scripts/utils.sh

TMP_DIR=/tmp/fpm
rm -rf $TMP_DIR
mkdir -p $TMP_DIR

# --------------------------------------------------------

source $BASEDIR/packages/fpm/version.sh # exports RUBY_VERSION & FPM_VERSION
echo "RUBY_VERSION: $RUBY_VERSION"
echo "FPM_VERSION: $FPM_VERSION"

rm -f $BASEDIR/Gemfile

# sudo might be needed for some systems (e.g. ubuntu GH runners)
gem install bundler --no-document --quiet || sudo gem install bundler --no-document --quiet
bundle init

echo "\"ruby\" \"$RUBY_VERSION\"" >> $BASEDIR/Gemfile
echo "gem \"fpm\", \"$FPM_VERSION\"" >> $BASEDIR/Gemfile

bundle install --without=development --path=$TMP_DIR/

rm -rf $TMP_DIR/ruby/$RUBY_VERSION/{build_info,cache,doc,extensions,doc,plugins,specifications,tests}
echo "Fpm: $FPM_VERSION\nRuby: $RUBY_VERSION" > $TMP_DIR/VERSION.txt

# create symlink to fpm relative to the output directory so that it correctly copies out of the docker image
cd $TMP_DIR
ln -s ./ruby/$RUBY_VERSION/bin/fpm fpm

compressArtifact darwin/fpm $TMP_DIR
