#!/usr/bin/env bash
set -ex

sh nsis-mac.sh
sh wine/wine-mac-ia32-and-x64.sh
sh scripts/update-zstd.sh
sh ./winCodeSign/darwin/build.sh