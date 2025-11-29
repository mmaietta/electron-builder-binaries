#!/usr/bin/env bash
set -euo pipefail

ARCH_RAW="${1:-x86_64}"

case "$ARCH_RAW" in
  amd64|x86_64)
    echo ""   # no flags needed
    ;;
  arm64|arm64/v8|aarch64)
    echo "-DCMAKE_SYSTEM_NAME=Linux \
          -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
          -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
          -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++"
    ;;
  *)
    echo "Unsupported architecture: $ARCH_RAW" >&2
    exit 1
    ;;
esac
