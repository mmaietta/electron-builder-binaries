# !/usr/bin/env bash
set -euo pipefail

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OUT_DIR="$CWD/out"
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

if [ "$OS_TARGET" = "darwin" ]; then
    echo "Building for macOS"
    bash "$CWD/assets/nsis-mac.sh"
else
    echo "Building for Linux and Windows"
    bash "$CWD/assets/nsis-linux.sh"
fi
echo "Build completed successfully."
