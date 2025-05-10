#!/usr/bin/env bash
set -euo pipefail

export RUBY_VERSION=3.4.3

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
BASEDIR=$CWD/out
mkdir -p $BASEDIR

OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

if [ "$OS_TARGET" = "darwin" ]; then
    echo "Building for macOS"
    bash assets/compile-portable-ruby.sh
else
    echo "Building for Linux"
    if [ -z "$ARCH" ]; then
        echo "Architecture not specified. Options are: x86_64, arm64, 386, armhf."
        echo "Defaulting to x86_64."
        ARCH="x86_64"
    fi
    echo "Building for architecture: $ARCH"
    cidFile="/tmp/linux-build-container-id-$ARCH"
    cleanup() {
        if test -f "$cidFile"; then
            containerId=$(cat "$cidFile")
            if docker ps -q --no-trunc | grep -q "$containerId"; then
                echo "Stopping container $containerId."
                docker rm "$containerId"
                unlink "$cidFile"
            fi
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
        -t $DOCKER_TAG \
        $CWD
        # --progress=plain \
    docker run --cidfile="$cidFile" $DOCKER_TAG

    containerId=$(cat "$cidFile")

    FPM_OUTPUT_DIR=$CWD
    mkdir -p $FPM_OUTPUT_DIR
    docker cp -a "$containerId":/tmp/out $FPM_OUTPUT_DIR

    cleanup
fi
echo "Build completed successfully."
