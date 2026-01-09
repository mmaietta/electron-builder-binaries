#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Main Build Script - Electron core24 Runtime Templates (Docker)
# =============================================================================
# Orchestrates building Electron runtime template bundles for Linux using Docker buildx
#
# Output:
#   out/electron-runtime-template/
#
# Platforms:
#   - Linux (amd64 + arm64) via Docker buildx
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
Usage: $0 [options]

Requirements:
  - Docker
  - Docker buildx enabled

Output:
  build/electron-runtime-template/
  out/*.tar.gz

EOF
}

# =============================================================================
# Main
# =============================================================================

# Help
BUILD_TARGET="${1:-}"
if [[ "$BUILD_TARGET" == "-h" || "$BUILD_TARGET" == "--help" ]]; then
  show_usage
  exit 0
fi

# Banner
print_banner

echo "🐧 Building Linux runtime templates (amd64 + arm64) via Docker..."
echo ""
bash "$SCRIPT_DIR/assets/build-linux.sh"

echo ""
echo "✅ Build complete!"
echo ""
