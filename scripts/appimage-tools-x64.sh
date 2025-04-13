#!/usr/bin/env bash
set -ex

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR=$BASEDIR/../AppImage/linux-x64

# desktop-file-validate

# Build the latest version of NSIS (Linux) in docker container
cidFile="/tmp/desktop-file-validate-build-container-id"
if test -f "$cidFile"; then
  echo "already running (removing $cidFile)"
  containerId=$(cat "$cidFile")
  docker rm "$containerId"
  unlink "$cidFile"
fi

rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR

cd "$BASEDIR"
docker run --cidfile="$cidFile" buildpack-deps:bionic bash -c \
'git clone --depth 1 --branch v1.5.0 https://github.com/facebook/zstd.git && cd zstd && make -j5 install && cd .. &&
 git clone --depth 1 --branch 4.5 https://github.com/plougher/squashfs-tools && cd squashfs-tools/squashfs-tools &&
 apt-get update -yq &&
 apt-get install -yq desktop-file-utils liblzo2-dev &&
 make -j5 XZ_SUPPORT=1 LZO_SUPPORT=1 ZSTD_SUPPORT=1 GZIP_SUPPORT=0 COMP_DEFAULT=zstd install
'

containerId=$(cat "$cidFile")
docker cp "$containerId":/usr/local/bin/zstd $BASEDIR/zstd/linux-x64/zstd
docker cp "$containerId":/usr/bin/desktop-file-validate $OUTPUT_DIR/desktop-file-validate
docker cp "$containerId":/usr/local/bin/mksquashfs $OUTPUT_DIR/mksquashfs
docker rm "$containerId"
unlink "$cidFile"

# get openjpg
rm -rf /tmp/openjpeg
mkdir /tmp/openjpeg
curl -L https://github.com/uclouvain/openjpeg/releases/download/v2.5.3/openjpeg-v2.5.3-linux-x86_64.tar.gz | tar -xz -C /tmp/openjpeg
mkdir -p $OUTPUT_DIR/lib/openjpeg-2.5
cp -a /tmp/openjpeg/openjpeg-v2.5.3-linux-x86_64/bin/* $OUTPUT_DIR/
cp -a /tmp/openjpeg/openjpeg-v2.5.3-linux-x86_64/lib/cmake/openjpeg-2.5 $OUTPUT_DIR/lib/openjpeg-2.5
cp -a /tmp/openjpeg/openjpeg-v2.5.3-linux-x86_64/lib/libopenjp2.* $OUTPUT_DIR/lib/
cp -a /tmp/openjpeg/openjpeg-v2.5.3-linux-x86_64/lib/pkgconfig $OUTPUT_DIR/lib
rm -rf /tmp/openjpeg
