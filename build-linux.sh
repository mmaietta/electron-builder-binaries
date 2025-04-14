#!/usr/bin/env bash
set -ex

BASEDIR=$(cd "$(dirname "$0")" && pwd)
cd $BASEDIR

if [ -z "$ARCH" ]; then
  echo "Building default target."
  ARCH="x86_64"
fi
if [ "$ARCH" = "x86_64" ]; then
  echo "Building x64 target."
  OUTPUT_ARCH="x64"
elif [ "$ARCH" = "i386" ]; then
  echo "Building ia32 target."
  OUTPUT_ARCH="ia32"
else
  echo "Unknown architecture: $ARCH"
  exit 1
fi

cidFile="/tmp/desktop-file-validate-build-container-id"
if test -f "$cidFile"; then
  echo "already running (removing $cidFile)"
  containerId=$(cat "$cidFile")
  docker rm "$containerId"
  unlink "$cidFile"
fi

# these all build in the own docker container
# sh ./winCodeSign/linux/build.sh
# ARCH=x86_64 sh ./scripts/appimage-tools-arch-arg.sh
# ARCH=i386 sh ./scripts/appimage-tools-arch-arg.sh

docker build -f docker-scripts/Dockerfile -t binaries-builder .
docker run --cidfile="$cidFile" -e IMAGE_VERSION=x86_64 --rm -v ${PWD}:/app -v ./docker-scripts:/usr/src/app/docker-scripts binaries-builder bash -c \
'
sh ./docker-scripts/appImage-packages-x64.sh
sh ./docker-scripts/nsis-linux.sh
sh ./docker-scripts/nsis-plugins.sh
sh ./docker-scripts/nsis.sh
sh ./docker-scripts/winCodeSign-tools-x64.sh
'
# might not be needed anymore. if so, move into `docker run` command
# sh ./docker-scripts/appImage-packages-ia32.sh

# desktop-file-validate & mksquashfs
APPIMAGE_OUTPUT_DIR=$BASEDIR/AppImage/linux-$OUTPUT_ARCH
rm -rf $APPIMAGE_OUTPUT_DIR
mkdir -p $APPIMAGE_OUTPUT_DIR
docker cp "$containerId":/usr/bin/desktop-file-validate $APPIMAGE_OUTPUT_DIR/desktop-file-validate
docker cp "$containerId":/usr/local/bin/mksquashfs $APPIMAGE_OUTPUT_DIR/mksquashfs

# ztsd
ZTSD_OUTPUT_DIR=$BASEDIR/zstd/linux-$OUTPUT_ARCH
rm -rf $ZTSD_OUTPUT_DIR
mkdir -p $ZTSD_OUTPUT_DIR
docker cp "$containerId":/usr/local/bin/zstd $ZTSD_OUTPUT_DIR/zstd

# cleanup
docker rm "$containerId"
unlink "$cidFile"

sh ./scripts/appimage-openjpeg-x64.sh
