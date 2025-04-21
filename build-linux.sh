#!/usr/bin/env bash
set -ex

CWD=$(cd "$(dirname "$0")" && pwd)
cd $CWD

BASEDIR=$CWD/out
# Note: output directory is not cleaned beforehand
# we run this script multiple times for each arch to the joined output dir
mkdir -p $BASEDIR

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
  echo "Unknown architecture: $ARCH. Expected: x86_64 or i386"
  OUTPUT_ARCH=$ARCH
fi

# check if previous docker containers are still running based off of container lockfile
cidFile="/tmp/linux-build-container-id"
if test -f "$cidFile"; then
  echo "already running (removing $cidFile)"
  containerId=$(cat "$cidFile")
  unlink "$cidFile"
  docker rm "$containerId"
fi

# cleanup docker container (if-exists) on error
f () {
    errorCode=$? # save the exit code as the first thing done in the trap function
    echo "error $errorCode"
    echo "the command executing at the time of the error was"
    echo "$BASH_COMMAND"
    echo "on line ${BASH_LINENO[0]}"

    unlink "$cidFile"
    docker rm "$containerId"

    exit $errorCode
}
trap f ERR

docker build -f Dockerfile -t binaries-builder:${ARCH} .
docker run --cidfile="$cidFile" -e IMAGE_ARCH=${ARCH} -v ${PWD}:/app binaries-builder:${ARCH} 

containerId=$(cat "$cidFile")

# desktop-file-validate & mksquashfs
APPIMAGE_OUTPUT_DIR=$BASEDIR/AppImage/linux-$OUTPUT_ARCH
# rm -rf $APPIMAGE_OUTPUT_DIR
mkdir -p $APPIMAGE_OUTPUT_DIR
docker cp "$containerId":/usr/bin/desktop-file-validate $APPIMAGE_OUTPUT_DIR/desktop-file-validate
docker cp "$containerId":/usr/local/bin/mksquashfs $APPIMAGE_OUTPUT_DIR/mksquashfs

# zstd
ZSTD_OUTPUT_DIR=$BASEDIR/zstd/linux-$OUTPUT_ARCH
# rm -rf $ZSTD_OUTPUT_DIR
mkdir -p $ZSTD_OUTPUT_DIR
docker cp "$containerId":/usr/local/bin/zstd $ZSTD_OUTPUT_DIR/zstd

# appimage-tools
APPIMAGE_TOOLS_OUTPUT_DIR=$BASEDIR/AppImage/lib/$OUTPUT_ARCH
# rm -rf $APPIMAGE_TOOLS_OUTPUT_DIR
mkdir -p $APPIMAGE_TOOLS_OUTPUT_DIR
docker cp "$containerId":/usr/src/app/appimage/. $APPIMAGE_TOOLS_OUTPUT_DIR

# winCodeSign
WIN_CODE_SIGN_OUTPUT_DIR=$BASEDIR/winCodeSign/darwin
# rm -rf $WIN_CODE_SIGN_OUTPUT_DIR
mkdir -p $WIN_CODE_SIGN_OUTPUT_DIR
docker cp "$containerId":/usr/src/app/winCodeSign/darwin/. $WIN_CODE_SIGN_OUTPUT_DIR

# openjpeg
OPENJPEG_OUTPUT_DIR=$BASEDIR/AppImage/linux-x64
# rm -rf $OPENJPEG_OUTPUT_DIR
mkdir -p $OPENJPEG_OUTPUT_DIR
docker cp "$containerId":/usr/src/app/AppImage/linux-x64/. $OPENJPEG_OUTPUT_DIR

# osslsigncode
WIN_CODE_SIGN_OUTPUT_DIR=$BASEDIR/winCodeSign
# rm -rf $WIN_CODE_SIGN_OUTPUT_DIR
mkdir -p $WIN_CODE_SIGN_OUTPUT_DIR/linux/
docker cp "$containerId":/usr/local/bin/osslsigncode $WIN_CODE_SIGN_OUTPUT_DIR/linux/
# copy the other remaining winCodeSign files
cp -a $CWD/winCodeSign/appxAssets $WIN_CODE_SIGN_OUTPUT_DIR
cp -a $CWD/winCodeSign/windows-6 $WIN_CODE_SIGN_OUTPUT_DIR
cp -a $CWD/winCodeSign/openssl-ia32 $WIN_CODE_SIGN_OUTPUT_DIR

# nsis-resources (note: we still use some vendored resources committed in this repo)
NSIS_PLUGINS_OUTPUT_DIR=$BASEDIR/nsis-resources/plugins
# rm -rf $NSIS_PLUGINS_OUTPUT_DIR
cp -a $CWD/nsis-resources $BASEDIR
docker cp "$containerId":/usr/src/app/nsis-resources/plugins/. $NSIS_PLUGINS_OUTPUT_DIR

# makensis
MAKENSIS_LINUX_OUTPUT=$BASEDIR/nsis/linux
# rm -rf $MAKENSIS_LINUX_OUTPUT
mkdir -p $MAKENSIS_LINUX_OUTPUT
# docker cp "$containerId":/usr/src/app/nsis/linux/. $MAKENSIS_LINUX_OUTPUT
docker cp "$containerId":/usr/local/bin/makensis $MAKENSIS_LINUX_OUTPUT/makensis

# makensis Windows
MAKENSIS_WINDOWS_OUTPUT=$BASEDIR/nsis/windows
# rm -rf $MAKENSIS_WINDOWS_OUTPUT
mkdir -p $MAKENSIS_WINDOWS_OUTPUT
docker cp "$containerId":/usr/src/app/nsis/windows/. $MAKENSIS_WINDOWS_OUTPUT

# Squirrel.Windows
SQUIRREL_WINDOWS_OUTPUT_DIR=$BASEDIR/Squirrel.Windows
# rm -rf $SQUIRREL_WINDOWS_OUTPUT_DIR
mkdir -p $SQUIRREL_WINDOWS_OUTPUT_DIR
docker cp "$containerId":/usr/src/app/Squirrel.Windows/. $SQUIRREL_WINDOWS_OUTPUT_DIR

# wix
WIX_OUTPUT_DIR=$BASEDIR/wix
# rm -rf $WIX_OUTPUT_DIR
mkdir -p $WIX_OUTPUT_DIR
docker cp "$containerId":/usr/src/app/wix/. $WIX_OUTPUT_DIR

# cleanup
docker rm "$containerId"
unlink "$cidFile"
echo "Build completed successfully."