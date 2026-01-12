#!/bin/bash
set -euo pipefail

# ----------------------------
# Paths
# ----------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build/core24"

TEMPLATE_NAME="electron-core24-template"
OUTPUT_DIR="$BUILD_DIR/$TEMPLATE_NAME-output"
WORK_DIR="$BUILD_DIR/$TEMPLATE_NAME-work"

# Create temporary snapcraft project
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

cat > snapcraft.yaml <<'EOF'
name: electron-core24-template
version: '1.0'
summary: Electron library template for core24
description: Template containing required libraries for Electron snaps
base: core24
confinement: strict
grade: devel

parts:
  electron-libs:
    plugin: nil
    stage-packages:
      - libappindicator3-1
      - libdbusmenu-glib4
      - libdbusmenu-gtk3-4
      - libindicator3-7
      - libnss3
      - libnspr4
      - libxss1
      - libnotify4
      - libxtst6
      - libatspi2.0-0
      - libsecret-1-0
      - libgbm1
      - libdrm2
      
    stage:
      - usr/lib/**/*.so*
      - -usr/lib/*/pkgconfig
    prime:
      - usr/lib/**/*.so*
EOF

echo "Building (prime step only)..."
snapcraft prime --verbose

# Check if prime directory exists
if [ ! -d "prime" ]; then
    echo "Error: prime directory not found!"
    exit 1
fi

# Create output directory and copy libraries
echo "Copying libraries from prime/..."
mkdir -p "$OUTPUT_DIR"
cp -r prime/usr "$OUTPUT_DIR/"

# Create tarball
echo "Creating tarball..."
cd "$OUTPUT_DIR"
tar czf "$BUILD_DIR/${TEMPLATE_NAME}.tar.gz" .

cd "$BUILD_DIR"
echo "Template created: ${TEMPLATE_NAME}.tar.gz"
du -sh "${TEMPLATE_NAME}.tar.gz"

# List contents for verification
echo -e "\nTemplate contents:"
tar tzf "${TEMPLATE_NAME}.tar.gz" | head -n 20

# Verify key libraries are present
echo -e "\nVerifying key libraries:"
for lib in libappindicator3.so.1 libnss3.so libnspr4.so libXss.so.1; do
    if tar tzf "${TEMPLATE_NAME}.tar.gz" | grep -q "$lib"; then
        echo "✓ Found: $lib"
    else
        echo "✗ Missing: $lib"
    fi
done

# Cleanup
echo "Cleaning up..."
rm -rf "$WORK_DIR" "$OUTPUT_DIR"

echo "Done!"