#!/bin/bash
set -euo pipefail

# ----------------------------
# Configuration
# ----------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ROOT/build/gnome-offline-template"
CORE24_SNAP="$ROOT/build/vendor/core24-1244.snap"        # path to your core24.snap
EXTENSIONS_SOURCE="/var/lib/snapd/snaps"           # location where GNOME extensions are installed
GNOME_LIBS_SOURCE="/usr/lib/x86_64-linux-gnu"      # or your staged GNOME libs
APP_DIR="./app"                                    # optional placeholder app

# ----------------------------
# Create folder structure
# ----------------------------
echo "📂 Creating template folder structure..."
mkdir -p "$TEMPLATE_DIR"/{meta,runtime,deps/gnome-libs,deps/gnome-extensions,scripts,app}

# ----------------------------
# Create meta/snap.yaml
# ----------------------------
cat > "$TEMPLATE_DIR/meta/snap.yaml" <<EOF
name: gnome-offline-template
version: "1.0"
summary: Fully offline GNOME Snapcraft template
description: Template snap for offline builds with core24 and GNOME extensions
confinement: devmode
base: core24

parts:
  template-setup:
    plugin: nil
    override-build: |
      ./scripts/pre-build.sh
      echo "Template pre-build complete"
EOF

# ----------------------------
# Create scripts/pre-build.sh
# ----------------------------
cat > "$TEMPLATE_DIR/scripts/pre-build.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

STAGE_DIR="${SNAPCRAFT_PART_INSTALL:-$PWD/stage}"

echo "⏳ Staging core24 runtime..."
mkdir -p "$STAGE_DIR/core24"
cp -r ../runtime/core24/* "$STAGE_DIR/core24/"

echo "⏳ Staging GNOME libraries..."
mkdir -p "$STAGE_DIR/gnome-libs"
cp -r ../deps/gnome-libs/* "$STAGE_DIR/gnome-libs/"

echo "⏳ Staging GNOME extension hooks..."
mkdir -p "$STAGE_DIR/gnome-extensions"
cp -r ../deps/gnome-extensions/* "$STAGE_DIR/gnome-extensions/"

echo "✅ Pre-build staging complete."
EOF

chmod +x "$TEMPLATE_DIR/scripts/pre-build.sh"

# ----------------------------
# Extract core24.snap
# ----------------------------
echo "📦 Extracting core24.snap..."
unsquashfs -d "$TEMPLATE_DIR/runtime/core24" "$CORE24_SNAP"

# ----------------------------
# Copy GNOME libraries
# ----------------------------
echo "📦 Copying GNOME libraries..."
cp -r "$GNOME_LIBS_SOURCE"/* "$TEMPLATE_DIR/deps/gnome-libs/"

# ----------------------------
# Copy GNOME extension hooks
# ----------------------------
echo "📦 Copying GNOME extension hooks..."
# Example: find snapcraft GNOME extension snaps
for ext_snap in "$EXTENSIONS_SOURCE"/snapcraft-gnome-*; do
    echo "  - Extracting $(basename "$ext_snap")"
    unsquashfs -d "$TEMPLATE_DIR/deps/gnome-extensions/$(basename "$ext_snap" .snap)" "$ext_snap"
done

# ----------------------------
# Placeholder app folder
# ----------------------------
touch "$TEMPLATE_DIR/app/.placeholder"

echo "✅ Offline GNOME Snapcraft template generated at $TEMPLATE_DIR"
