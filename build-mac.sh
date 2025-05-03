#!/usr/bin/env bash
set -ex

bash ./packages/fpm/fpm.sh fpm/darwin/fpm.7z
# sh ./scripts/linux-tools-mac.sh
# sh ./scripts/nsis-mac.sh
# sh ./scripts/zstd-win-mac.sh
# sh ./scripts/nsis-plugins-TBD.sh
# sh ./scripts/appimage-mac.sh
# sh ./packages/win-codesign/darwin/build.sh
# sh ./packages/wine/wine-mac-ia32-and-x64.sh