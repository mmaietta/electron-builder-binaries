# !/usr/bin/env bash
set -euo pipefail

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

# Global vars for each build (easy updating from a single script)
export ZLIB_VERSION="1.3.1"
export NSIS_VERSION="3.11"
export NSIS_BRANCH_OR_COMMIT="v311" # 7359413009afd4f0fff472d841fc2f2cc0e0a5f8 commit head as of 2024-06-03


if [ "$OS_TARGET" = "darwin" ]; then
    echo "Building for macOS"
    bash "$CWD/assets/nsis-mac.sh"
else
    echo "Building for Linux"
    bash "$CWD/assets/nsis-linux.sh"
fi

echo "Build completed successfully."
