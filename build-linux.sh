#!/usr/bin/env bash
set -ex

sh ./winCodeSign/linux/build.sh
ARCH=x86_64 sh ./scripts/appimage-tools-arch-arg.sh
ARCH=i386 sh ./scripts/appimage-tools-arch-arg.sh

docker build -f docker-scripts/Dockerfile -t binaries-builder .
docker run --rm -v ${PWD}:/app -v ./docker-scripts:/usr/src/app/docker-scripts binaries-builder bash -c \
'
sh ./docker-scripts/appImage-packages-x64.sh
sh ./docker-scripts/nsis-linux.sh
sh ./docker-scripts/nsis-plugins.sh
sh ./docker-scripts/nsis.sh
sh ./docker-scripts/winCodeSign-tools-x64.sh
sh ./scripts/appimage-openjpeg-x64.sh
'
# might not be needed anymore. if so, move into `docker run` command
# sh ./docker-scripts/appImage-packages-ia32.sh
