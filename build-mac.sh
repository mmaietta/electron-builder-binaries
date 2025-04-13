#!/usr/bin/env bash
set -ex

sh ./scripts/nsis-mac.sh
sh ./scripts/update-zstd.sh
sh ./winCodeSign/darwin/build.sh
sh ./wine/wine-mac-ia32-and-x64.sh