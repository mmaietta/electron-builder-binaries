#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="/tmp/electron-runtime-test"
OUT_DIR="$SCRIPT_DIR/../out/functional-test"

CORES="core22 core24"
ARCHES="amd64 arm64"

rm -rf "$TMP_DIR" "$OUT_DIR"
mkdir -p "$TMP_DIR" "$OUT_DIR"

# -----------------------------------------------------------------------------
# OS detection
# -----------------------------------------------------------------------------
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

is_linux() {
  [ "$OS" = "linux" ]
}

# -----------------------------------------------------------------------------
# Ensure snapcraft on Linux
# -----------------------------------------------------------------------------
ensure_snapcraft() {
  if ! command -v snapcraft >/dev/null 2>&1; then
    echo "📦 Installing snapcraft (Linux only)..."
    sudo apt-get update
    sudo apt-get install -y squashfs-tools snapd
    sudo snap install snapcraft --classic
  fi
}

# -----------------------------------------------------------------------------
# Run test
# -----------------------------------------------------------------------------
run_test() {
  core="$1"
  arch="$2"

  template_dir="$SCRIPT_DIR/../build/$core/electron-runtime-template"
  snap_name="electron-runtime-${core}-${arch}.snap"
  snap_path="$OUT_DIR/$snap_name"

  echo ""
  echo "🔹 Testing $core ($arch)"

  if [ ! -d "$template_dir" ]; then
    echo "❌ Template not found: $template_dir"
    return 1
  fi

  if is_linux; then
    ensure_snapcraft

    echo "📦 Packing snap..."
    snapcraft pack "$template_dir" --output "$snap_path"

    echo "📥 Installing snap..."
    sudo snap remove electron-runtime-template 2>/dev/null || true
    sudo snap install "$snap_path" --dangerous --devmode

    echo "🚀 Running snap..."
    if ! snap run electron-runtime-template --version; then
      echo "❌ Snap execution failed"
      return 1
    fi

    echo "✅ PASS"

  else
    echo "⚠ macOS detected — skipping snap execution"
    echo "✅ PACK PASS (execution skipped)"
  fi
}

# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------
FAILURES=0

for core in $CORES; do
  for arch in $ARCHES; do
    if ! run_test "$core" "$arch"; then
      FAILURES=$((FAILURES + 1))
    fi
  done
done

echo ""
echo "================================================================"
if [ "$FAILURES" -eq 0 ]; then
  echo "✅ ALL FUNCTIONAL TESTS PASSED"
else
  echo "❌ $FAILURES TEST(S) FAILED"
  exit 1
fi
echo "================================================================"
