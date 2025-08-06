# !/usr/bin/env bash
set -euo pipefail

export RUBY_VERSION=3.4.3

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OUT_DIR="$CWD/out"
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

if [ "$OS_TARGET" = "darwin" ]; then
    echo "Building for macOS"
    bash "$CWD/assets/nsis-mac.sh"
elif [ "$OS_TARGET" = "linux" ]; then
    echo "Building for Linux"
    bash "$CWD/assets/nsis-windows.sh"
elif [ "$OS_TARGET" = "win32" ] || [ "$OS_TARGET" = "windows" ]; then
    echo "Building for Windows"
    # sh "$CWD/assets/nsis-prepare.sh"
    bash "$CWD/assets/nsis-windows.sh"
else
    echo "Building for Linux and Windows"
    bash "$CWD/assets/nsis-windows.sh"
fi
echo "Build completed successfully."
