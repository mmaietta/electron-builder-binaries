#!/usr/bin/env bash
set -euo pipefail

ARCH="$1"

case "$ARCH" in
    x86_64|amd64)
        # Native / default build
        exit 0
        ;;

    arm64|aarch64|arm64v8)
        echo "-DCMAKE_SYSTEM_NAME=Linux \
              -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
              -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
              -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++"
        ;;

    i386|i686|x86)
        echo "-DCMAKE_SYSTEM_NAME=Linux \
              -DCMAKE_SYSTEM_PROCESSOR=i386 \
              -DCMAKE_C_COMPILER=i686-linux-gnu-gcc \
              -DCMAKE_CXX_COMPILER=i686-linux-gnu-g++"
        ;;

    *)
        echo "ERROR: Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac
