#!/bin/sh
# Bash 3.2 compatible
# Usage: ./generate-electron-snap-template.sh <cache_root> [root_dir]
# Example: ./generate-electron-snap-template.sh build/electron /home/user/build

set -e

CACHE_ROOT="${1:?Path to cached Electron build required}"
ROOT_DIR="${2:-$(pwd)}"

# Unique output filename
TIMESTAMP=$(date +%Y%m%d%H%M%S)
HASH=$(echo "$CACHE_ROOT" | md5sum | cut -c1-6 2>/dev/null || echo "xxxxxx")
UNIQUE_NAME="snap-template-${TIMESTAMP}-${HASH}.tar.gz"

# Directories
PRIME_DIR="$ROOT_DIR/build/prime-template"
OUT_DIR="$ROOT_DIR/out/snap-template"

echo "▶ Generating offline Electron snap template"
echo "• Cache root: $CACHE_ROOT"
echo "• Root dir: $ROOT_DIR"
echo "• Output dir: $OUT_DIR"
echo "• Prime dir: $PRIME_DIR"
echo "• Unique tarball: $UNIQUE_NAME"
echo ""

# Clean previous prime
rm -rf "$PRIME_DIR"
mkdir -p "$PRIME_DIR/meta"
mkdir -p "$PRIME_DIR/electron"

# Copy Electron binaries from cache
echo "• Copying cached Electron..."
cp -r "$CACHE_ROOT/v30.0.0-arm64/." "$PRIME_DIR/electron/"

# Generate minimal snapcraft.yaml
SNAPCRAFT_YAML="$PRIME_DIR/snapcraft.yaml"
echo "• Generating snapcraft.yaml..."
cat > "$SNAPCRAFT_YAML" <<'EOF'
name: my-electron-app
version: "30.0.0"
base: core24
confinement: strict
summary: Minimal Electron app template
description: A generator for a minimal Electron app template for core24 snaps.

parts:
    app:
        plugin: dump
        source: electron
        stage-packages: []   # optional, empty if you want offline-only

apps:
    app:
        extensions: [gnome]
        command: electron/electron
        plugs:
            - browser-support
            - network
            - home
EOF

# Expand extensions into meta/snap.yaml
echo "• Expanding extensions..."
cd "$PRIME_DIR"
snapcraft expand-extensions --quiet > meta/snap.yaml

# Optional: show preview
echo "• Expanded snap.yaml (first 20 lines):"
head -n 20 meta/snap.yaml
echo "  ..."

# Pack offline
rm -f "$PRIME_DIR/*.snap" "$SNAPCRAFT_YAML"
echo "• Packing snap offline..."
snapcraft pack

# Move resulting snap to output directory
mkdir -p "$OUT_DIR"
SNAP_FILE=$(ls *.snap 2>/dev/null | head -n1)
if [ -z "$SNAP_FILE" ]; then
    echo "⚠ No snap generated"
    exit 1
fi

rm -f "$OUT_DIR/$UNIQUE_NAME"
tar czf "$OUT_DIR/$UNIQUE_NAME" "$SNAP_FILE"

echo "✓ Snap template tarball created:"
echo "  $OUT_DIR/$UNIQUE_NAME"

# Clean up
cd "$ROOT_DIR"
rm -rf "$PRIME_DIR"

echo "Done."
