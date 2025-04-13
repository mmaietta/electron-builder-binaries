#!/usr/bin/env bash
set -ex

sh ./scripts/nsis-mac.sh
sh ./scripts/wine/wine-mac-ia32-and-x64.sh
sh ./scripts/scripts/update-zstd.sh
sh ./scripts/./winCodeSign/darwin/build.sh