# !/usr/bin/env bash
set -euo pipefail

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

# Global vars for each build (easy updating from a single script)
export ZLIB_VERSION="1.3.1"
export NSIS_VERSION="3.11"
export NSIS_SHA256="19e72062676ebdc67c11dc032ba80b979cdbffd3886c60b04bb442cdd401ff4b"

if [ "$OS_TARGET" = "darwin" ]; then
    echo "Building for macOS"
    bash "$CWD/assets/nsis-mac.sh"
else
    echo "Building for Linux"
    bash "$CWD/assets/nsis-linux.sh"
fi

echo "Build completed successfully."
