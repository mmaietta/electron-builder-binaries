#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Main Build Script - Electron Runtime Templates (Docker)
# =============================================================================
# Orchestrates building Electron runtime template bundles for Linux using Docker buildx
# Supports core22 and core24 runtime templates and functional testing.
#
# Platforms:
#   - Linux (amd64 + arm64) via Docker buildx
#
# Usage:
#   ./build.sh all      # build core24 + tests
#   ./build.sh <arch>   # build only arm64 or amd64 runtime template
#   ./build.sh test     # run functional tests only
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Functions
# =============================================================================

print_banner() {
  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  Electron core24 Runtime Template Builder (Docker)"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  Platforms:   Linux (amd64 + arm64)"
  echo "  Snap Base:   core24"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
}

show_usage() {
  cat << EOF
Usage: $0 [TARGET]

Targets:
  all      Build arm64 + amd64 runtime templates and run functional tests
  test     Run functional tests only (requires built templates)

Requirements:
  - Docker
  - Docker buildx enabled

Output:
  build/core24/electron-runtime-template/
  out/*.tar.gz

EOF
}

build_core24() {
  echo ""
  echo "🐧 Building core24 ($1) runtime template..."
  bash "$SCRIPT_DIR/assets/build-core24.sh"  $1
}

run_tests() {
  echo ""
  echo "🧪 Running functional tests..."
  bash "$SCRIPT_DIR/assets/test.sh"
}

# =============================================================================
# Main
# =============================================================================

BUILD_TARGET="${1:-all}"

# Help
if [[ "$BUILD_TARGET" == "-h" || "$BUILD_TARGET" == "--help" ]]; then
  show_usage
  exit 0
fi

print_banner

# Clean previous builds only if cleaning is requested
if [[ "$BUILD_TARGET" = "clean" ]]; then
  echo "🧹 Cleaning previous builds..."
  rm -rf "$SCRIPT_DIR/out" "$SCRIPT_DIR/build"
  exit 0
fi

# Execute build/test according to target
case "$BUILD_TARGET" in
  all)
    build_core24 all
    run_tests
    ;;
  arm64|amd64)
    build_core24 "$BUILD_TARGET"
    ;;
  test)
    run_tests
    ;;
  *)
    echo "❌ Unknown target: $BUILD_TARGET"
    show_usage
    exit 1
    ;;
esac

echo ""
echo "✅ Build script finished for target: $BUILD_TARGET"
echo ""
