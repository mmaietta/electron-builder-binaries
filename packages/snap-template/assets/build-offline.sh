#!/bin/bash
set -euo pipefail

# ----------------------------
# Paths
# ----------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build/core24"

TEMPLATE_DIR="$BUILD_DIR/gnome-offline-template"
CORE24_SNAP="$BUILD_DIR/vendor/core24_1244.snap"
EXTENSIONS_DIR="$BUILD_DIR/vendor/gnome-extensions"  # staged snaps for template
APP_DIR="$BUILD_DIR/app"
DOCKER_IMAGE="ubuntu:24.04"

# ----------------------------
# Create template folder structure
# ----------------------------
echo "📂 Creating template folder structure..."
rm -rf "$TEMPLATE_DIR"
mkdir -p "$TEMPLATE_DIR"/{meta,scripts,app}

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
extensions: [gnome]

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

echo "⏳ Staging combined core24 + GNOME extension tar..."
mkdir -p "$STAGE_DIR"
tar -C "$PWD/../" -xf gnome-offline-template.tar
echo "✅ Pre-build staging complete."
EOF

chmod +x "$TEMPLATE_DIR/scripts/pre-build.sh"

# ----------------------------
# Detect GNOME extension snaps
# ----------------------------
echo "🔍 Detecting GNOME extension snaps..."
mkdir -p "$EXTENSIONS_DIR"

# Example: look for snapcraft-gnome-*.snap in vendor folder
REQUIRED_SNAPS=( "snapcraft-gnome-3-38.snap" "snapcraft-gnome-42.snap" )

FOUND=()
for snap in "${REQUIRED_SNAPS[@]}"; do
    if [ -f "$BUILD_DIR/vendor/gnome-extensions/$snap" ]; then
        cp "$BUILD_DIR/vendor/gnome-extensions/$snap" "$EXTENSIONS_DIR/"
        FOUND+=("$snap")
    fi
done

if [ ${#FOUND[@]} -eq 0 ]; then
    echo "❌ Error: extensions: [gnome] declared but no GNOME extension snaps found in $EXTENSIONS_DIR"
    exit 1
else
    echo "✅ Found GNOME extension snaps: ${FOUND[*]}"
fi

# ----------------------------
# Extract & combine everything in Docker
# ----------------------------
echo "📦 Extracting core24 and GNOME extensions in Docker..."
docker run --rm -v "$BUILD_DIR":/mnt "$DOCKER_IMAGE" bash -c "
  set -e
  apt-get update && apt-get install -y squashfs-tools tar

  # Temp dirs
  mkdir -p /tmp/core24 /tmp/gnome-ext /tmp/combined

  # Extract core24
  echo '🔹 Extracting core24.snap...'
  unsquashfs -d /tmp/core24 /mnt/vendor/core24_1244.snap

  # Extract GNOME extension snaps
  if compgen -G /mnt/vendor/gnome-extensions/*.snap > /dev/null; then
      echo '🔹 Extracting GNOME extension snaps...'
      for ext_snap in /mnt/vendor/gnome-extensions/*.snap; do
          base_name=\$(basename \$ext_snap .snap)
          mkdir -p /tmp/gnome-ext/\$base_name
          unsquashfs -d /tmp/gnome-ext/\$base_name \$ext_snap
      done
  fi

  # Combine everything
  cp -r /tmp/core24/* /tmp/combined/
  cp -r /tmp/gnome-ext/* /tmp/combined/ 2>/dev/null || true

  # Create single combined tar
  echo '🔹 Creating combined tar...'
  tar -C /tmp/combined -cf /mnt/gnome-offline-template.tar .
"

# ----------------------------
# Placeholder app
# ----------------------------
touch "$TEMPLATE_DIR/app/.placeholder"

# ----------------------------
# Validation
# ----------------------------
echo "🔍 Validating offline template..."
if [ ! -f "$CORE24_SNAP" ]; then
    echo "❌ core24.snap not found at $CORE24_SNAP"
    exit 1
fi

if [ ! -f "$BUILD_DIR/gnome-offline-template.tar" ]; then
    echo "❌ Combined tar file missing! Docker extraction failed."
    exit 1
fi

echo "✅ Offline GNOME Snapcraft template ready at $TEMPLATE_DIR"
echo "✅ Combined tar available: $BUILD_DIR/gnome-offline-template.tar"
echo "Use the template with: cd $TEMPLATE_DIR && snapcraft --offline"
