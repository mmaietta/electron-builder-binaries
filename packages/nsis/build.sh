# !/usr/bin/env bash
set -euo pipefail

export RUBY_VERSION=3.4.3

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OUT_DIR="$CWD/out"
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

if [ "$OS_TARGET" = "darwin" ]; then
    echo "Building for macOS"
    sh "$CWD/assets/nsis-mac.sh"
elif [ "$OS_TARGET" = "linux" ]; then
    echo "Building for Linux"
    sh "$CWD/assets/nsis-linux.sh"
elif [ "$OS_TARGET" = "win32" ] || [ "$OS_TARGET" = "windows" ]; then
    echo "Building for Windows"
    # sh "$CWD/assets/nsis-prepare.sh"
    sh "$CWD/assets/nsis-windows.sh"
else
    echo "Building for Linux and Windows"
    bash "$CWD/assets/nsis-linux.sh"
fi
echo "Build completed successfully."
