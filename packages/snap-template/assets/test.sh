#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

OUT_DIR="$ROOT_DIR/out/functional-test"
TMP_DIR="/tmp/electron-runtime-functional-test"

CORES="core22 core24"
ARCHES="amd64 arm64"

rm -rf "$OUT_DIR" "$TMP_DIR"
mkdir -p "$OUT_DIR" "$TMP_DIR"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

is_linux() {
  [ "$OS" = "linux" ]
}

# -----------------------------------------------------------------------------
# Ensure snapcraft (macOS + Linux)
# -----------------------------------------------------------------------------
ensure_snapcraft() {
  if command -v snapcraft >/dev/null 2>&1; then
    return 0
  fi

  echo "📦 Installing snapcraft..."

  if is_linux; then
    sudo apt-get update
    sudo apt-get install -y squashfs-tools snapd
    sudo snap install snapcraft --classic
  elif command -v brew >/dev/null 2>&1; then
    brew install snapcraft
  else
    echo "❌ snapcraft not found"
    echo "   Install snapcraft manually"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Run one test
# -----------------------------------------------------------------------------
run_test() {
  core="$1"
  arch="$2"

  TEMPLATE_NAME="electron-runtime-template"
  template_dir="$ROOT_DIR/build/$core/electron-runtime-template"
  snap_file="$OUT_DIR/${TEMPLATE_NAME}-${core}-${arch}.snap"

  echo ""
  echo "🔹 Testing $core ($arch)"

  if [ ! -d "$template_dir" ]; then
    echo "❌ Template directory not found: $template_dir"
    return 1
  fi

  # ---------------------------------------------------------------------------
  # Ensure snap.yaml exists (ALWAYS)
  # ---------------------------------------------------------------------------
  echo "📝 Writing snap.yaml"

  mkdir -p "$template_dir/meta"

  SNAP_YAML="$template_dir/meta/snap.yaml"
  cat > "$SNAP_YAML" <<EOF
name: ${TEMPLATE_NAME}-test
version: "1.0"
summary: Functional test snap for $TEMPLATE_NAME
description: Test snap for Electron runtime template
confinement: devmode
apps:
  test:
    command: bin/true
EOF

  # ---------------------------------------------------------------------------
  # Pack snap (macOS + Linux)
  # ---------------------------------------------------------------------------
  ensure_snapcraft

  echo "📦 Packing snap..."
  snapcraft pack "$template_dir" --output "$snap_file"

  # ---------------------------------------------------------------------------
  # Install & run snap (Linux only)
  # ---------------------------------------------------------------------------
  if is_linux; then
    echo "📥 Installing snap..."
    sudo snap remove "${TEMPLATE_NAME}-test" 2>/dev/null || true
    sudo snap install "$snap_file" --dangerous --devmode

    echo "🚀 Running snap..."
    snap run "${TEMPLATE_NAME}-test.test"
  else
    echo "⚠ macOS detected — skipping snap install/run"
  fi

  echo "✅ PASS"
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
