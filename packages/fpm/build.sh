# !/usr/bin/env bash
set -euo pipefail

export RUBY_VERSION=3.4.3

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
BASEDIR=$CWD/out
mkdir -p $BASEDIR

OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

if [ "$OS_TARGET" = "darwin" ]; then
    echo "Building for macOS"
    bash "$CWD/assets/compile-portable-ruby.sh"
else
    OPTIONS="x86_64, i386, arm32, arm64"
    echo "Building for Linux"
    if [ -z "$ARCH" ]; then
        echo "Architecture not specified. Options are: $OPTIONS."
        echo "Defaulting to x86_64."
        ARCH="x86_64"
    fi
    if [ "$ARCH" = "x86_64" ]; then
        PLATFORMARCH=amd64
        DOCKER_IMAGE=amd64/buildpack-deps:22.04-curl
    elif [ "$ARCH" = "i386" ]; then
        PLATFORMARCH=amd64
        DOCKER_IMAGE=i386/buildpack-deps:22.04-curl
    elif [ "$ARCH" = "arm32" ]; then
        PLATFORMARCH=armhf
        DOCKER_IMAGE=arm32v7/buildpack-deps:22.04-curl
    elif [ "$ARCH" = "arm64" ]; then
        PLATFORMARCH=arm64
        DOCKER_IMAGE=arm64v8/buildpack-deps:22.04-curl
    else
        echo "Unknown architecture: $ARCH. Options supported: $OPTIONS."
        echo "Please set the ARCH environment variable to one of these values."
        echo "Example: ARCH=x86_64 ./path/to/build.sh"
        exit 1
    fi

    echo "Building for architecture: $ARCH"
    cidFile="/tmp/linux-build-container-id-$ARCH"
    cleanup() {
        if test -f "$cidFile"; then
            containerId=$(cat "$cidFile")
            if docker ps -q --no-trunc | grep -q "$containerId"; then
                echo "Stopping container $containerId."
                docker rm "$containerId"
            fi
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

    DOCKER_TAG="fpm-builder:$ARCH"
    docker buildx build \
        --load \
        -f "$CWD/assets/Dockerfile" \
        --build-arg RUBY_VERSION=$RUBY_VERSION \
        --build-arg TARGETARCH=$ARCH \
        --build-arg PLATFORMARCH=$PLATFORMARCH \
        -t $DOCKER_TAG \
        $CWD
        # --progress=plain \ # Add to above for verbose output
        # --no-cache \ # Add to above to force rebuild
    docker run --cidfile="$cidFile" $DOCKER_TAG

    containerId=$(cat "$cidFile")

    FPM_OUTPUT_DIR=$CWD
    mkdir -p $FPM_OUTPUT_DIR
    docker cp -a "$containerId":/tmp/out $FPM_OUTPUT_DIR

    cleanup
fi
echo "Build completed successfully."
