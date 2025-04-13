#!/usr/bin/env bash
set -ex

sh ./scripts/appImage-packages-ia32.sh
sh ./scripts/appImage-packages-x64.sh
sh ./scripts/appimage-tools-x64.sh
sh ./scripts/nsis-linux.sh
sh ./scripts/nsis-plugins.sh
sh ./scripts/nsis-prepare.sh
sh ./scripts/update-zstd.sh
sh ./scripts/winCodeSign-tools-x64.sh
