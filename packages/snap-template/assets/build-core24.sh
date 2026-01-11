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

IMAGE_NAME="electron-core24-runtime-builder"
BUILDER_NAME="electron-runtime-builder"

echo "📦 Electron core24 Runtime Template Builder"
echo "=========================================="
echo ""

# Check for required commands
MISSING_CMDS=""
for cmd in snapcraft unsquashfs python3 tree patchelf; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is required but not installed."
    MISSING_CMDS="$MISSING_CMDS $cmd"
  fi
done

if [ -n "$MISSING_CMDS" ]; then
  echo "Missing commands:$MISSING_CMDS"

  if [[ "$(uname -s)" == "Linux" ]]; then
    echo "Attempting to install missing commands on Linux..."

    # Update apt and install what is available
    sudo apt-get update

    # snapcraft may need snapd, check first
    for cmd in $MISSING_CMDS; do
      if [ "$cmd" == "snapcraft" ]; then
        if ! command -v snap >/dev/null 2>&1; then
          echo "Installing snapd first..."
          sudo apt-get install -y snapd
        fi
        echo "Installing snapcraft via snap..."
        sudo snap install snapcraft --classic
        sudo snap install gnome-46-2404 --channel=latest/stable --dangerous || true
      else
        sudo apt-get install -y "$cmd" || echo "❌ Could not install $cmd via apt"
      fi
    done

  else
    # macOS
    echo "Installing missing commands via Homebrew..."
    for cmd in $MISSING_CMDS; do
      brew install "$cmd"
    done
  fi
fi

bash ${ROOT}/assets/core24/template.sh $ARCH $TEMPLATE_DIR
