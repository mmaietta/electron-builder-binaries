# !/usr/bin/env bash
set -euo pipefail

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OUT_DIR="$CWD/out"
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

if [ "$OS_TARGET" = "darwin" ]; then
    echo "Building for macOS (brew) and Windows & Linux (docker cross-compilation)"
    bash "$CWD/assets/nsis-mac.sh"
else
    echo "This script only supports building with docker on macOS. (brew for macos, docker for cross compiling linux/windows)"
    exit 1
fi
echo "Build completed successfully."
