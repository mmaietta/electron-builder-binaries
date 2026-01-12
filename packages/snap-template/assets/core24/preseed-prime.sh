#!/bin/sh
# Bash 3.2 compatible
# Usage: ./offline-pack-multiarch.sh <electron_version> <build_root>
# Example: ./offline-pack-multiarch.sh 26.1.0 /path/to/build

set -e

ELECTRON_VERSION="${1:?Electron version required (e.g. 26.1.0)}"
BUILD_ROOT="${2:-$(pwd)}"

# Architectures
ARCHES="x64 arm64 armv7l"

# Paths
CACHE_ROOT="$BUILD_ROOT/electron-remplates/v${ELECTRON_VERSION}"
PRIME_ROOT="$BUILD_ROOT/prime"
OUTPUT_ROOT="$BUILD_ROOT/offline-snaps"

echo "▶ Offline multi-arch pack: Electron $ELECTRON_VERSION"
echo "• Build root: $BUILD_ROOT"
echo "• Cache root: $CACHE_ROOT"
echo "• Output root: $OUTPUT_ROOT"
echo ""

# Clean output dir
rm -rf "$OUTPUT_ROOT"
mkdir -p "$OUTPUT_ROOT"

# Loop over architectures
for ARCH in $ARCHES; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Packing architecture: $ARCH"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    CACHE_DIR="$CACHE_ROOT/$ARCH"
    PRIME_DIR="$PRIME_ROOT/$ARCH"
    mkdir -p "$PRIME_DIR"

    # Tarball name (runtime delta)
    DELTA_TAR="$CACHE_DIR/electron-${ARCH}.tar.gz"

    # Electron app payload
    APP_SRC="$CACHE_DIR/electron-app"

    # Snap metadata
    SNAP_YAML_SRC="$CACHE_DIR/snap.yaml"

    # --- Clean prime for this arch
    rm -rf "$PRIME_DIR"/*
    echo "• Preparing prime for $ARCH"

    # --- Extract runtime delta
    if [ -f "$DELTA_TAR" ]; then
        echo "• Extracting runtime delta"
        tar -xzf "$DELTA_TAR" -C "$PRIME_DIR"
    else
        echo "⚠ Runtime delta tarball missing: $DELTA_TAR"
        echo "  Generate it first using an online snapcraft build."
        continue
    fi

    # --- Copy Electron app
    if [ -d "$APP_SRC" ]; then
        echo "• Copying Electron app payload"
        cp -a "$APP_SRC" "$PRIME_DIR/electron"
    else
        echo "⚠ Electron app not found: $APP_SRC"
        continue
    fi

    # --- Copy snap.yaml
    if [ -f "$SNAP_YAML_SRC" ]; then
        echo "• Copying snap.yaml"
        mkdir -p "$PRIME_DIR/meta"
        cp "$SNAP_YAML_SRC" "$PRIME_DIR/meta/snap.yaml"
    else
        echo "⚠ snap.yaml not found: $SNAP_YAML_SRC"
        continue
    fi

    # --- Pack offline snap
    echo "• Running snapcraft pack --offline"
    cd "$PRIME_DIR"
    snapcraft pack --offline

    # --- Move resulting snap to output
    SNAP_NAME=$(basename $(ls *.snap 2>/dev/null) || echo "electron-${ELECTRON_VERSION}-${ARCH}.snap")
    mkdir -p "$OUTPUT_ROOT/$ARCH"
    mv "$PRIME_DIR/$SNAP_NAME" "$OUTPUT_ROOT/$ARCH/"

    echo "✓ Snap created: $OUTPUT_ROOT/$ARCH/$SNAP_NAME"
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ All architectures complete!"
echo "Results in: $OUTPUT_ROOT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
