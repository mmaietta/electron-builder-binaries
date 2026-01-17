#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

OUTPUT_DIR="${ROOT}/out/dmg-builder"

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Default to current architecture
# can also be space-separated list, e.g. "x86_64 arm64"
ARCHS=${1:-"$(uname -m)"}

for ARCH in $ARCHS; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🏗️  Building Python runtime for ${ARCH}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "$ROOT/assets/build-python-runtime.sh" "$ROOT" "$OUTPUT_DIR" "3.11.8" "1.6.6" "-" "${ARCH}"
done