#!/usr/bin/env bash
set -euxo pipefail

PLATFORM_ARCH="${PLATFORM_ARCH:-x86_64}"
OSSLSIGNCODE_VER="${OSSLSIGNCODE_VER:-2.9}"

CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$CWD/out/win-codesign"

# Clean up and prepare output directory
mkdir -p "$OUTPUT_DIR/osslsigncode"

cidFile="/tmp/wincodesign-linux-container-id"
cleanup() {
    if test -f "$cidFile"; then
        containerId=$(cat "$cidFile")
        echo "Stopping docker container $containerId."
        docker rm "$containerId"
        unlink "$cidFile"
    fi
}
# check if previous docker containers are still running based off of container lockfile
cleanup

# cleanup docker container on error
f() {
    errorCode=$? # save the exit code as the first thing done in the trap function
    echo "error $errorCode"
    echo "the command executing at the time of the error was"
    echo "$BASH_COMMAND"
    echo "on line ${BASH_LINENO[0]}"
    
    cleanup
    
    exit $errorCode
}
trap f ERR

# ----------------------------
# Build and extract osslsigncode (Linux)
# ----------------------------
DOCKER_TAG="osslsigncode-builder-linux:$PLATFORM_ARCH"
OUT_DIR="$OUTPUT_DIR/osslsigncode/linux/$PLATFORM_ARCH"
mkdir -p "$OUT_DIR"

docker build \
--build-arg OSSLSIGNCODE_VER="$OSSLSIGNCODE_VER" \
--build-arg PLATFORM_ARCH="$PLATFORM_ARCH" \
-f "$CWD/assets/Dockerfile" \
-t ${DOCKER_TAG} "$CWD"

docker run --cidfile="$cidFile" $DOCKER_TAG
containerId=$(cat "$cidFile")
ARCHIVE_ARCH_SUFFIX=$(echo ${PLATFORM_ARCH:-$(uname -m)} | tr -d '/' | tr '[:upper:]' '[:lower:]')
docker cp "$containerId":/out/linux/osslsigncode/osslsigncode-linux-$ARCHIVE_ARCH_SUFFIX.zip "$OUTPUT_DIR"

cleanup