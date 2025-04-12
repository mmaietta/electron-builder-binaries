#!/usr/bin/env bash
set -ex


# desktop-file-validate
BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Build the latest version of NSIS (Linux) in docker container
cidFile="/tmp/desktop-file-validate-build-container-id"
if test -f "$cidFile"; then
  echo "already running (removing $cidFile)"
  containerId=$(cat "$cidFile")
  docker rm "$containerId"
  unlink "$cidFile"
fi

OUTPUT_DIR=$BASEDIR/AppImage/linux-x64
# rm -rf $OUTPUT_DIR
# mkdir $OUTPUT_DIR

cd "$BASEDIR"
# docker run --cidfile="$cidFile" buildpack-deps:xenial bash -c \
# 'apt-get update -yq &&
# apt-get install -yq desktop-file-utils
# '

# containerId=$(cat "$cidFile")
# docker cp "$containerId":/usr/bin/desktop-file-validate $OUTPUT_DIR/desktop-file-validate
# docker rm "$containerId"
# unlink "$cidFile"

# get openjpg
mkdir /tmp/openjpeg
curl -L https://github.com/uclouvain/openjpeg/releases/download/v2.5.3/openjpeg-v2.5.3-linux-x86_64.tar.gz | tar -xz -C /tmp/openjpeg
# rm f.tar.gz
cp /tmp/openjpeg/openjpeg-v2.5.3-linux-x86_64/bin/* $OUTPUT_DIR/
cp /tmp/openjpeg/openjpeg-v2.5.3-linux-x86_64/lib/cmake/openjpeg-2.5 $OUTPUT_DIR/lib/openjpeg-2.5
cp /tmp/openjpeg/openjpeg-v2.5.3-linux-x86_64/lib/libopenjp2.* $OUTPUT_DIR/lib/
cp /tmp/openjpeg/openjpeg-v2.5.3-linux-x86_64/lib/pkgconfig $OUTPUT_DIR/lib/pkgconfig
# rm -rf openjpeg-v2.5.3
rm -rf /tmp/openjpeg
# # get libpng
# curl https://download.sourceforge.net/libpng/libpng-1.6.37.tar.gz -o f.tar.gz
# tar -xzf f.tar.gz
# rm f.tar.gz
# mv libpng-1.6.37/bin/* $OUTPUT_DIR
# rm -rf libpng-1.6.37