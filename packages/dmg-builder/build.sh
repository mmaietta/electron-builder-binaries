#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

OUTPUT_DIR="${ROOT}/out/dmg-builder"

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

for ARCH in arm64 x86_64; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🏗️  Building Python runtime for ${ARCH}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "$ROOT/assets/build-python-runtime.sh" "$ROOT" "$OUTPUT_DIR" "3.11.8" "1.6.6" "-" "${ARCH}"
done