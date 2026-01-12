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

CMD="${1:-help}"
shift || true

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$CMD" in
  clean)
    # clean build artifacts except the reference-snap for locat testing
    rm -rf "$BUILD_DIR/vendor"
    rm -rf "$BUILD_DIR/extracted"
    rm -rf "$ROOT/build/electron"
    rm -rf "$TEMPLATE_DIR"
    echo "🧹 Cleaned build artifacts"
    ;;
  # build machine CI
  all)
    "$BASE_DIR/core24/download-electron.sh" arm64 30.0.0 "$ROOT/build/electron"
    "$BASE_DIR/core24/download-electron.sh" amd64 30.0.0 "$ROOT/build/electron"
    "$BASE_DIR/core24/download-core.sh" arm64 "$BUILD_DIR/vendor"
    "$BASE_DIR/core24/download-core.sh" amd64 "$BUILD_DIR/vendor"

    "$BASE_DIR/core24/template.sh" arm64 "$ROOT" 
    "$BASE_DIR/core24/template.sh" amd64 "$ROOT" 
    ( 
      cd "$BUILD_DIR"
      tar -czf "$BUILD_DIR/core24-snaps-stable.tar.gz" .
    )
    # snapcraft --offline
    ;;
  arm64|amd64)
    # "$BASE_DIR/core24/preflight-offline-check.sh"
    # "$BASE_DIR/core24/download-electron.sh" "$CMD" 30.0.0 "$BUILD_DIR/electron"
    "$BASE_DIR/core24/download-core.sh" "$CMD" "$BUILD_DIR/vendor"
    # "$BASE_DIR/core24/template.sh" "$CMD" "$TEMPLATE_DIR" "$ROOT/out/snap-template"
    # snapcraft --offline
    ;;
  # install local pinned base snaps
  bootstrap)
    "$BASE_DIR/core24/bootstrap-offline.sh"
    ;;
  # preflight check for offline build - using bootstrapped snaps
  preflight)
    "$BASE_DIR/core24/preflight-offline-check.sh"
    ;;
  # validate electron runtime completeness for pinned electron for full template output
  validate-electron)
    "$BASE_DIR/core24/validate-electron-runtime.sh" "$@"
    ;;
  # full build: preflight + snapcraft --offline
  build)
    "$BASE_DIR/core24/preflight-offline-check.sh"
    # "$BASE_DIR/core24/download-electron.sh"
    snapcraft --offline
    ;;
  doctor)
    "$BASE_DIR/core24/offline-doctor.sh"
    ;;
  validate-electron)
    "$BASE_DIR/core24/validate-electron-runtime.sh" "$@"
  ;;
  help|*)
    cat <<EOF
Offline Snap Template CLI

Commands:
  bootstrap           Install pinned base snaps (offline)
  preflight           Verify build will be 100% offline
  validate-electron   Validate Electron runtime completeness
  build               Run preflight + snapcraft --offline
  doctor              Full diagnostics report
EOF
    ;;
esac
