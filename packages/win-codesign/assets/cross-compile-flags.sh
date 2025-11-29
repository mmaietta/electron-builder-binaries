#!/usr/bin/env bash
set -euo pipefail

ARCH_RAW="${1:-x86_64}"

# Normalize architecture aliases
case "$ARCH_RAW" in
  amd64|x86_64)
    ARCH_CANONICAL="x86_64"
    ;;
  arm64|arm64/v8|aarch64)
    ARCH_CANONICAL="aarch64"
    ;;
  *)
    echo "❌ Unsupported architecture: $ARCH_RAW"
    exit 1
    ;;
esac

# Print CMake arguments for this architecture
if [[ "$ARCH_CANONICAL" = "aarch64" ]]; then
    cat <<EOF
-DCMAKE_SYSTEM_NAME=Linux
-DCMAKE_SYSTEM_PROCESSOR=aarch64
-DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc
-DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++
EOF
else
    # Native x86_64 build
    cat <<EOF
# (no cross flags needed)
EOF
fi
