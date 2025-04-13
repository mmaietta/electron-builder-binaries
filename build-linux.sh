#!/usr/bin/env bash
set -ex

sh appImage-packages-ia32.sh
sh appImage-packages-x64.sh
sh appimage-tools-x64.sh
sh nsis-linux.sh
sh nsis-plugins.sh
sh nsis-prepare.sh
sh update-zstd.sh
sh winCodeSign-tools-x64.sh