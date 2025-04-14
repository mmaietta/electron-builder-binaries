#!/usr/bin/env bash
set -ex

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
cd $BASEDIR

if [ -z "$ARCH" ]; then
  echo "Building default target."
  ARCH="x86_64"
fi
if [ "$ARCH" == "x86_64" ]; then
  echo "Building x64 target."
  OUTPUT_ARCH="x64"
elif [ "$ARCH" == "i386" ]; then
  echo "Building ia32 target."
  OUTPUT_ARCH="ia32"
else
  echo "Unknown architecture: $ARCH"
  exit 1
fi
OUTPUT_DIR=$BASEDIR/AppImage/linux-$OUTPUT_ARCH

# Build the latest version of mksquashfs and ztsd (Linux) in docker container
cidFile="/tmp/desktop-file-validate-build-container-id"
if test -f "$cidFile"; then
  echo "already running (removing $cidFile)"
  containerId=$(cat "$cidFile")
  docker rm "$containerId"
  unlink "$cidFile"
fi

docker run --cidfile="$cidFile" --platform=linux/$ARCH buildpack-deps:bionic bash -c \
'git clone --depth 1 --branch v1.5.0 https://github.com/facebook/zstd.git && cd zstd && make -j5 install && cd .. &&
 git clone --depth 1 --branch 4.5 https://github.com/plougher/squashfs-tools && cd squashfs-tools/squashfs-tools &&
 apt-get update -yq &&
 apt-get install -yq desktop-file-utils liblzo2-dev &&
 make -j5 XZ_SUPPORT=1 LZO_SUPPORT=1 ZSTD_SUPPORT=1 GZIP_SUPPORT=0 COMP_DEFAULT=zstd install
'
containerId=$(cat "$cidFile")

rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR
docker cp "$containerId":/usr/bin/desktop-file-validate $OUTPUT_DIR/desktop-file-validate
docker cp "$containerId":/usr/local/bin/mksquashfs $OUTPUT_DIR/mksquashfs

ZTSD_OUTPUT_DIR=$BASEDIR/zstd/linux-$OUTPUT_ARCH
rm -rf $ZTSD_OUTPUT_DIR
mkdir -p $ZTSD_OUTPUT_DIR
docker cp "$containerId":/usr/local/bin/zstd $ZTSD_OUTPUT_DIR/zstd
docker rm "$containerId"
unlink "$cidFile"