#!/usr/bin/env bash
ARCH="$1"

case "$ARCH" in
  amd64|x86_64)
    echo ""
    ;;
  i386)
    echo "-DCMAKE_C_FLAGS=-m32 -DCMAKE_CXX_FLAGS=-m32"
    ;;
  arm64|aarch64)
    echo "-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
          -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
          -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++"
    ;;
  *)
    echo "Unknown architecture: $ARCH" >&2
    exit 1
    ;;
esac
