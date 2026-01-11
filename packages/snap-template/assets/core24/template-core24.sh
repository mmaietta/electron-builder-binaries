#!/bin/bash
set -e

#############################################
# Offline GNOME Runtime Template Builder
# Extracts GNOME runtime for offline snap builds
# Does NOT validate LD or generate SBOM
#############################################

ARCH="${1:-amd64}"
TEMPLATE_VERSION="1"

BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$BASE_DIR/build/core24"
TEMPLATE_DIR="$BUILD_DIR/electron-runtime-template"
OUT_DIR="$BASE_DIR/out/snap-template"

TEMPLATE_NAME="snap-template-electron-core24-v${TEMPLATE_VERSION}-${ARCH}"
WORK_DIR="$BUILD_DIR/work-$ARCH"
mkdir -p "$WORK_DIR"

cleanup() {
    echo "Cleaning up temporary directories..."
    # Keep the reference .snap for caching
    [ -d "$WORK_DIR/extracted" ] && rm -rf "$WORK_DIR/extracted"
    [ -d "$WORK_DIR/reference-snap/bin" ] && rm -rf "$WORK_DIR/reference-snap/bin"
    [ -f "$WORK_DIR/build.log" ] && rm -f "$WORK_DIR/build.log"
}
trap cleanup EXIT
# cleanup

echo "======================================================================="
echo "Offline GNOME Runtime Template Builder"
echo "======================================================================="
echo "Architecture: $ARCH"
echo "Work Directory: $WORK_DIR"
echo "Output Directory: $TEMPLATE_DIR"
echo ""

# Ensure required commands
MISSING_CMDS=()
for cmd in snapcraft unsquashfs rsync python3 jq tar; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING_CMDS+=("$cmd")
done

if [ ${#MISSING_CMDS[@]} -gt 0 ]; then
    echo "❌ Missing required commands: ${MISSING_CMDS[*]}"
    exit 1
fi

# Step 1: Create reference snap
echo "[1/5] Creating reference snap..."
SNAP_DIR="$WORK_DIR/reference-snap"
mkdir -p "$SNAP_DIR/bin"

# Dummy executable
cat > "$SNAP_DIR/bin/hello" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$SNAP_DIR/bin/hello"

# Snapcraft.yaml for extraction
cat > "$SNAP_DIR/snapcraft.yaml" <<'EOF'
name: reference-app
base: core24
version: '1.0'
summary: Reference GNOME extractor
description: Temporary snap for GNOME extension extraction
grade: stable
confinement: strict

apps:
  reference-app:
    command: bin/hello
    extensions: [gnome]
    plugs:
      - desktop
      - desktop-legacy
      - gsettings
      - opengl
      - wayland
      - x11
      - home
      - network
      - browser-support
      - audio-playback

parts:
  dummy:
    plugin: dump
    source: .
    stage: [bin/hello]
EOF

# Build snap if not cached
SNAP_FILE=$(find "$SNAP_DIR" -maxdepth 1 -name "*.snap" -type f 2>/dev/null | head -1)
if [ -n "$SNAP_FILE" ] && [ -f "$SNAP_FILE" ]; then
    echo "✅ Using cached snap: $(basename "$SNAP_FILE")"
else
    echo "Building reference snap (may take several minutes)..."
docker run --rm --privileged \
  --platform linux/amd64 \
  -v "$SNAP_DIR":/work \
  -w /work \
  ubuntu:24.04 \
  bash -lc '
    set -e

    apt update
    apt install -y snapd squashfs-tools

    # Docker-specific fixes
    ln -sf /usr/lib/snapd/snap /usr/bin/snap

    # Start snapd
    mkdir -p /run/snapd
    /usr/lib/snapd/snapd &
    
    # IMPORTANT: wait for snapd to be ready
    until snap version >/dev/null 2>&1; do
      echo "Waiting for snapd..."
      sleep 2
    done

    # CRITICAL: seed a base snap FIRST
    snap install core24

    # Now install snapcraft (will NOT hang)
    snap install snapcraft --classic

    snapcraft --version
    snapcraft --build-for=amd64
  '

    SNAP_FILE=$(find "$SNAP_DIR" -maxdepth 1 -name "*.snap" -type f | head -1)
    [ -z "$SNAP_FILE" ] && { echo "❌ Snap build failed"; exit 1; }
    echo "✅ Built: $(basename "$SNAP_FILE")"
fi

# Step 2: Extract snap contents
echo "[2/5] Extracting snap..."
EXTRACT_DIR="$WORK_DIR/extracted"
unsquashfs -q -d "$EXTRACT_DIR" "$SNAP_FILE"
[ ! -d "$EXTRACT_DIR" ] && { echo "❌ Extraction failed"; exit 1; }

# Step 3: Copy files to template
echo "[3/5] Copying runtime files..."
FINAL_TEMPLATE_DIR="$TEMPLATE_DIR/$TEMPLATE_NAME"
mkdir -p "$FINAL_TEMPLATE_DIR/meta-reference"
mkdir -p "$OUT_DIR"

# Copy meta/snap.yaml
cp "$EXTRACT_DIR/meta/snap.yaml" "$FINAL_TEMPLATE_DIR/meta-reference/"

# Copy GNOME and GPU runtime, data-dir
rsync -a --exclude='bin/hello' --exclude='meta/' \
"$EXTRACT_DIR/gnome-platform" "$FINAL_TEMPLATE_DIR/"
rsync -a --exclude='bin/hello' --exclude='meta/' \
"$EXTRACT_DIR/gpu-2404" "$FINAL_TEMPLATE_DIR/"
rsync -a --exclude='bin/hello' --exclude='meta/' \
"$EXTRACT_DIR/data-dir" "$FINAL_TEMPLATE_DIR/"

echo "✅ Copied GNOME runtime, GPU runtime, and data-dir"

# Step 4: Generate helper scripts
echo "[4/5] Creating helper scripts..."

# generate-snapcraft.sh
cat > "$FINAL_TEMPLATE_DIR/generate-snapcraft.sh" <<'GEN'
#!/bin/bash
set -e
APP_NAME="${1:-myapp}"
VERSION="${2:-1.0.0}"
SUMMARY="${3:-My Application}"
DESCRIPTION="${4:-My application description}"

python3 <<PY
import yaml, os
app_name = os.environ['APP_NAME']
version = os.environ['VERSION']
summary = os.environ.get('SUMMARY', 'My Application')
description = os.environ.get('DESCRIPTION', 'My application description')

with open('meta-reference/snap.yaml') as f:
    snap = yaml.safe_load(f)

ref_app = snap['apps'][list(snap['apps'].keys())[0]]

snapcraft = {
    'name': app_name,
    'base': 'core24',
    'version': version,
    'summary': summary,
    'description': description,
    'grade': 'stable',
    'confinement': 'strict',
    'apps': {
        app_name: {
            'command': f'app/{app_name}',
            'plugs': ref_app.get('plugs', []),
            'environment': ref_app.get('environment', {})
        }
    },
    'parts': {
        'gnome-runtime': {
            'plugin': 'dump',
            'source': '.',
            'stage': ['gnome-platform', 'gpu-2404', 'data-dir', '-meta-reference']
        },
        'app': {
            'plugin': 'dump',
            'source': 'app/',
            'stage-packages': [
                'libnspr4', 'libnss3', 'libxss1',
                'libappindicator3-1','libsecret-1-0','libatomic1'
            ],
            'organize': {'*': 'app/'},
            'after': ['gnome-runtime']
        }
    },
    'layout': snap.get('layout', {}),
    'assumes': snap.get('assumes', [])
}

with open('snapcraft.yaml', 'w') as f:
    yaml.dump(snapcraft, f, default_flow_style=False, sort_keys=False)
print(f"✅ Generated snapcraft.yaml for {app_name}")
PY
GEN
chmod +x "$FINAL_TEMPLATE_DIR/generate-snapcraft.sh"

# show-extension-details.sh
cat > "$FINAL_TEMPLATE_DIR/show-extension-details.sh" <<'SHOW'
#!/bin/bash
python3 <<PY
import yaml
with open('meta-reference/snap.yaml') as f:
    snap = yaml.safe_load(f)
app = snap['apps'][list(snap['apps'].keys())[0]]
print("Environment Variables:")
for k,v in app.get('environment', {}).items():
    print(f"  {k}={v}")
print("\nPlugs:")
for plug in app.get('plugs', []):
    print(f"  {plug}")
PY
SHOW
chmod +x "$FINAL_TEMPLATE_DIR/show-extension-details.sh"

# Step 5: Create tarball
echo "[5/5] Creating tarball..."
TAR_NAME="${TEMPLATE_NAME}.tar.gz"
( cd "$TEMPLATE_DIR" && tar czf "$OUT_DIR/$TAR_NAME" "$TEMPLATE_NAME" )
echo "✅ Tarball created: $OUT_DIR/$TAR_NAME"

echo ""
echo "✅ Offline GNOME runtime template ready!"
echo "Template Directory: $FINAL_TEMPLATE_DIR"
echo "Tarball: $OUT_DIR/$TAR_NAME"
echo ""
