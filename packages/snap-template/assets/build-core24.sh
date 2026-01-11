#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Electron core24 Runtime Template Builder (Docker buildx)
# =============================================================================
# Builds multi-arch (amd64 + arm64) runtime templates containing all
# shared libraries required by Electron snaps.
#
# Output:
#   out/electron-runtime-template/
#
# Requirements:
#   - Docker with buildx enabled
# =============================================================================
ARCH="${1:-amd64}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT/build/core24"
TEMPLATE_DIR="$BUILD_DIR/electron-runtime-template"
OUT_DIR="$ROOT/out/snap-template"

IMAGE_NAME="electron-core24-runtime-builder"
BUILDER_NAME="electron-runtime-builder"

echo "📦 Electron core24 Runtime Template Builder"
echo "=========================================="
echo ""

# Check for required commands
MISSING_CMDS=""
for cmd in snapcraft unsquashfs python3 tree; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is required but not installed."
    MISSING_CMDS="$MISSING_CMDS $cmd"
  fi
done
if [ -n "$MISSING_CMDS" ]; then
  if [[ $(uname -s) == "Linux" ]]; then
    echo "Installing missing commands:$MISSING_CMDS"
    sudo apt-get update
    sudo apt-get install -y $MISSING_CMDS
  else
    brew install $MISSING_CMDS
  fi
fi

bash -e ${ROOT}/assets/core24/template-core24.sh $ARCH $TEMPLATE_DIR
# bash -e ${ROOT}/assets/core24/validate-ld-deps.sh $TEMPLATE_DIR/ false
# bash -e ${ROOT}/assets/core24/runtime-smoke-test.sh $TEMPLATE_DIR/
# bash -e ${ROOT}/assets/core24/generate-allowlist.sh $TEMPLATE_DIR/   # first time only

find "$BUILD_DIR" -type f -name "*.so*" -exec du -b {} + \
  | awk '{print "{\"file\":\""$2"\",\"bytes\":"$1"}"}' \
  | jq -s '.' | jq 'sort_by(.bytes) | reverse | .[]'
