# !/usr/bin/env bash
set -euo pipefail

export APPIMAGE_VERSION=13

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

if [ "$OS_TARGET" = "darwin" ]; then
    f() {
        errorCode=$? # save the exit code as the first thing done in the trap function
        echo "error $errorCode"
        echo "the command executing at the time of the error was"
        echo "$BASH_COMMAND"
        echo "on line ${BASH_LINENO[0]}"
        exit $errorCode
    }
    trap f ERR

    echo "Building for macOS"
    
else
    echo "Building for Linux"
    
    ARCH_KEY="multi"
    DEST="$CWD/build-output-${ARCH_KEY}"
    rm -rf "$DEST"
    mkdir -p "$DEST"

    #  multi-platform build with output to local directory
    docker buildx build \
        --platform linux/amd64,linux/arm64,linux/arm/v7 \
        --output type=local,dest="${DEST}" \
        -f "$CWD/assets/Dockerfile" \
        $CWD
fi
echo "Build completed successfully."
