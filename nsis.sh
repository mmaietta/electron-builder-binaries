#!/usr/bin/env bash
set -e

# How do update NSIS (and include both LOG + StrLen compiler flags) for both Windows and Mac:
# Note: Update the makensis version number in the urls/brew cmds

# 1. Download source code from https://sourceforge.net/projects/nsis/files/NSIS%203/
#   - Example: nsis-3.06.1-src.tar.bz2 - https://sourceforge.net/projects/nsis/files/NSIS%203/3.06.1/nsis-3.06.1-src.tar.bz2/download
#   - Extract and enter directory.
#   - `scons NSIS_CONFIG_LOG=yes NSIS_MAX_STRLEN=8192 PREFIX=/tmp/nsis install-compiler install-stubs`
#   - You may need to download https://nsis.sourceforge.io/Zlib 32bit. Provide via cmd line arg `ZLIB_W32=<absolute path>/Zlib-1.2.7-win32-x86`
# 2. Copy over nsis in this repo and copy nsis-lang-fixes to nsis/Contrib/Language files
# 3. Inspect changed and unversioned files — delete if need.

# 4. Compile makensis from source for Mac: https://github.com/NSIS-Dev/homebrew-makensis
#   - `brew tap nsis-dev/makensis`
#   - `brew install makensis@3.06.1 --with-large-strings --with-advanced-logging`
#   - `sudo cp /usr/local/Cellar/makensis/*/bin/makensis nsis/mac/makensis`
# 5. See nsis-linux.sh