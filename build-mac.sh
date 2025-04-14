#!/usr/bin/env bash
set -ex

sh ./scripts/nsis-mac.sh
sh ./scripts/zstd-win-mac.sh
sh ./winCodeSign/darwin/build.sh
sh ./wine/wine-mac-ia32-and-x64.sh