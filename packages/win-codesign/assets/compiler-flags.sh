#!/usr/bin/env bash
set -euo pipefail

ARCH="${1:-amd64}"

case "$ARCH" in
  amd64)
    # Native 64-bit build
    echo ""
    ;;
  i386)
    # 32-bit Intel build
    echo "-DCMAKE_C_COMPILER=i686-linux-gnu-gcc \
          -DCMAKE_CXX_COMPILER=i686-linux-gnu-g++ \
          -DCMAKE_C_FLAGS=-m32 \
          -DCMAKE_CXX_FLAGS=-m32 \
          -DCMAKE_EXE_LINKER_FLAGS=-m32 \
          -DCMAKE_SHARED_LINKER_FLAGS=-m32"
    ;;
  arm64)
    # Cross-compile for ARM64
    echo "-DCMAKE_SYSTEM_NAME=Linux \
          -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
          -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
          -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
          -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
          -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
          -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
          -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY"
    ;;
  *)
    echo "Unknown PLATFORM_ARCH: $ARCH" >&2
    exit 1
    ;;
esac
