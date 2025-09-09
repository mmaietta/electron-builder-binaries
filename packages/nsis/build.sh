# !/usr/bin/env bash
set -euo pipefail

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

# Global vars for each build (easy updating from a single script)
export BRANCH_TAG="v311"
export ZLIB_VERSION="1.3.1"
export VERSION="3.11"

if [ "$OS_TARGET" = "darwin" ]; then
    echo "Building for macOS"
    bash "$CWD/assets/nsis-mac.sh"
else
    echo "Building for Linux"
    bash "$CWD/assets/nsis-linux.sh"
fi

echo "Build completed successfully."
