#!/bin/sh
# Bash 3.2 compatible
# Usage: ./offline-pack-multiarch.sh <electron_version> <build_root>
# Example: ./offline-pack-multiarch.sh 30.0.0 /path/to/build

set -e

ELECTRON_VERSION="${1:?Electron version required (e.g. 30.0.0)}"
BUILD_ROOT="${2:-$(pwd)}"
OUTPUT_ROOT="${3:-$BUILD_ROOT/out/offline-snaps}"

# Architectures
ARCHES="x64" # arm64 armv7l"

# Paths
CACHE_ROOT="$BUILD_ROOT/electron"     # <- contains v30.0.0-ARCH folders
PRIME_ROOT="$BUILD_ROOT/prime"

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

    CACHE_DIR="$CACHE_ROOT/v${ELECTRON_VERSION}-${ARCH}"
    PRIME_DIR="$PRIME_ROOT/$ARCH"
    mkdir -p "$PRIME_DIR"

    # Tarball name (runtime delta)
    DELTA_TAR="$CACHE_ROOT/runtime-delta-core24-${ARCH}.tar.gz"

    # Snap metadata
    SNAP_YAML_SRC="$CACHE_ROOT/snap.yaml"

    # --- Clean prime for this arch
    rm -rf "$PRIME_DIR"/*
    echo "• Preparing prime for $ARCH"

    # --- Extract runtime delta into prime/usr/lib
    if [ -f "$DELTA_TAR" ]; then
        echo "• Extracting runtime delta"
        tar -xzf "$DELTA_TAR" -C "$PRIME_DIR"
    else
        echo "⚠ Runtime delta tarball missing: $DELTA_TAR"
        echo "  You may skip if there is no extra runtime delta."
    fi

    # --- Copy Electron app payload into prime/electron
    if [ -d "$CACHE_DIR" ]; then
        echo "• Copying Electron app payload from $CACHE_DIR"
        cp -a "$CACHE_DIR" "$PRIME_DIR/electron"
    else
        echo "⚠ Electron app directory not found: $CACHE_DIR"
        continue
    fi

    # --- Copy snap.yaml into prime/meta
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
