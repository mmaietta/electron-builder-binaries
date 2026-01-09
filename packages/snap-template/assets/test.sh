#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Functional Test for Electron Runtime Templates (core22 + core24)
# Multi-arch: amd64 + arm64
# =============================================================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUT_DIR="$BASE_DIR/out/functional-test"
TMP_DIR="/tmp/electron-runtime-test"
rm -rf "$OUT_DIR" "$TMP_DIR"
mkdir -p "$OUT_DIR" "$TMP_DIR"

# Templates: template_path:core_ubuntu
TEMPLATES=(
    "$BASE_DIR/build/core22/electron-runtime-template:22.04"
    "$BASE_DIR/build/core24/electron-runtime-template:24.04"
)

SUMMARY=()
ARCHS=(amd64 arm64)

# =============================================================================
# Ensure dependencies
# =============================================================================
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required"
    exit 1
fi

if ! command -v snapcraft &> /dev/null; then
    echo "📦 Installing snapcraft..."
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if command -v brew &> /dev/null; then
            brew install snapcraft
        else
            python3 -m pip install --user snapcraft
        fi
    else
        sudo apt-get update
        sudo apt-get install -y snapcraft squashfs-tools
    fi
fi

# =============================================================================
# Main Loop
# =============================================================================
echo "🧪 Functional Test for Electron Runtime Templates (multi-arch)"
echo "==============================================================="

for ENTRY in "${TEMPLATES[@]}"; do
    IFS=':' read -r TEMPLATE CORE_UBUNTU <<< "$ENTRY"
    TEMPLATE_NAME=$(basename "$TEMPLATE")

    if [ ! -d "$TEMPLATE" ]; then
        echo "❌ Template not found: $TEMPLATE"
        SUMMARY+=("$TEMPLATE_NAME | $CORE_UBUNTU | MISSING")
        continue
    fi

    # Copy template into TMP_DIR
    TMP_TEMPLATE_DIR="$TMP_DIR/template"
    rm -rf "$TMP_TEMPLATE_DIR"
    cp -r "$TEMPLATE" "$TMP_TEMPLATE_DIR"

    # Ensure snap.yaml exists
    mkdir -p "$TMP_TEMPLATE_DIR/meta"
    SNAP_YAML="$TMP_TEMPLATE_DIR/meta/snap.yaml"
    if [ ! -f "$SNAP_YAML" ]; then
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
    fi

    # Create dummy executable
    mkdir -p "$TMP_TEMPLATE_DIR/bin"
    echo -e "#!/bin/sh\nexit 0" > "$TMP_TEMPLATE_DIR/bin/true"
    chmod +x "$TMP_TEMPLATE_DIR/bin/true"

    # Fix permissions
    chmod -R a+rX "$TMP_TEMPLATE_DIR"

    # Unique snap file name for caching
    SNAP_FILE="$OUT_DIR/${TEMPLATE_NAME}-core${CORE_UBUNTU//./}-ubuntu${CORE_UBUNTU}.snap"

    echo ""
    echo "📦 Creating snap from template for Ubuntu $CORE_UBUNTU: $SNAP_FILE"
    snapcraft pack "$TMP_TEMPLATE_DIR" --output "$SNAP_FILE"
    echo "  ✅ Snap created: $SNAP_FILE"

    # Loop over architectures
    for ARCH in "${ARCHS[@]}"; do
        echo ""
        echo "🐳 Testing architecture: $ARCH"

        TEST_DIR="$TMP_DIR/test-$CORE_UBUNTU-$ARCH"
        rm -rf "$TEST_DIR"
        mkdir -p "$TEST_DIR"
        cp "$SNAP_FILE" "$TEST_DIR/"

        # =============================================================================
        # Create dynamic Dockerfile
        # =============================================================================
        cat > "$TEST_DIR/Dockerfile" <<EOF
FROM ubuntu:${CORE_UBUNTU}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        squashfs-tools curl lsb-release ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY $(basename "$SNAP_FILE") /tmp/template.snap

RUN unsquashfs -d /tmp/test-snap /tmp/template.snap && \\
    for ARCH_DIR in /tmp/test-snap/usr/lib/*; do \\
        if [ -d "\$ARCH_DIR/nss" ]; then \\
            echo "🔹 Checking libraries in \$ARCH_DIR/nss"; \\
            for so in \$ARCH_DIR/nss/*.so; do \\
                echo "  Testing: \$so"; \\
                ldd \$so || echo "  ⚠ Could not resolve: \$so"; \\
            done; \\
            for chk in libfreebl3.chk libfreeblpriv3.chk libsoftokn3.chk libnssckbi.chk libnssdbm3.chk; do \\
                if [ ! -f \$ARCH_DIR/nss/\$chk ]; then \\
                    echo "❌ Missing NSS integrity file: \$ARCH_DIR/nss/\$chk"; \\
                    exit 1; \\
                else \\
                    echo "  ✓ Found: \$chk"; \\
                fi; \\
            done; \\
        fi; \\
    done && \\
    ELECTRON_BIN=/tmp/test-snap/usr/bin/electron && \\
    if [ -x \$ELECTRON_BIN ]; then \\
        echo "🔹 Running ldd on Electron binary"; \\
        ldd \$ELECTRON_BIN || exit 1; \\
        echo "🔹 Running electron --version"; \\
        \$ELECTRON_BIN --version || exit 1; \\
    else \\
        echo "⚠ Electron binary not found"; \\
    fi
EOF

        # =============================================================================
        # Run Docker buildx for current architecture
        # =============================================================================
        TEST_RESULT="PASS"
        if ! docker buildx build --platform "linux/$ARCH" -f "$TEST_DIR/Dockerfile" "$TEST_DIR"; then
            TEST_RESULT="FAIL"
        fi
        SUMMARY+=("$TEMPLATE_NAME | $CORE_UBUNTU | $ARCH | $TEST_RESULT")
        echo "  📝 Result: $TEST_RESULT"
    done
done

# =============================================================================
# Summary Table
# =============================================================================
echo ""
echo "================================================================"
echo "📊 Functional Test Summary"
echo "================================================================"
printf "%-25s | %-8s | %-6s | %-5s\n" "Template" "Ubuntu" "Arch" "Result"
echo "---------------------------+----------+--------+-------"
for ENTRY in "${SUMMARY[@]}"; do
    IFS='|' read -r TPL UB ARCH RES <<< "$ENTRY"
    printf "%-25s | %-8s | %-6s | %-5s\n" "$TPL" "$UB" "$ARCH" "$RES"
done
echo "================================================================"
echo ""
