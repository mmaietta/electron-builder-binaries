#!/bin/bash
set -e

#############################################
# Universal Snap Template Builder
# Works on: macOS, Linux, GitHub Actions
# Uses: Native snapcraft with LXD
#############################################

ARCH="${1:-amd64}"
TEMPLATE_VERSION="1"

BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$BASE_DIR/build/core24"
TEMPLATE_DIR="$BUILD_DIR/electron-runtime-template"
OUT_DIR="$BASE_DIR/out/snap-template"

TEMPLATE_NAME="snap-template-electron-core24-v${TEMPLATE_VERSION}-${ARCH}"
WORK_DIR="$BUILD_DIR/work-$ARCH"

echo "======================================================================="
echo "Universal Snap Template Builder"
echo "======================================================================="
echo "Platform: $(uname -s)"
echo "Architecture: $ARCH"
echo "Work Directory: $WORK_DIR"
echo "Output Directory: $OUT_DIR"
echo ""

# Create directories
mkdir -p "$WORK_DIR" "$OUT_DIR"

# Check required commands
MISSING_CMDS=()
for cmd in unsquashfs rsync python3 jq tar; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING_CMDS+=("$cmd")
done

if [ ${#MISSING_CMDS[@]} -gt 0 ]; then
  echo "❌ Missing required commands: ${MISSING_CMDS[*]}"
  echo ""
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "Installing on macOS:"
    brew install squashfs coreutils python3 jq tree
  else
    echo "Installing on Linux:"
    sudo apt-get install squashfs-tools rsync python3 python3-yaml jq tree
  fi
fi

# Check for snapcraft
if ! command -v snapcraft >/dev/null 2>&1; then
  echo "❌ snapcraft not found"
  echo ""
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "Installing on macOS:"
    brew install snapcraft
  else
    echo "Installing on Linux:"
    sudo snap install snapcraft --classic
  fi
  exit 1
fi

# Detect build environment
BUILD_MODE="unknown"
if [[ "$(uname -s)" == "Darwin" ]]; then
  BUILD_MODE="multipass"
  echo "✓ macOS detected - will use Multipass"
elif [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
  BUILD_MODE="lxd"
  echo "✓ CI environment detected - will use LXD"
elif command -v lxd >/dev/null 2>&1 || systemctl is-active --quiet snap.lxd.daemon 2>/dev/null; then
  BUILD_MODE="lxd"
  echo "✓ LXD detected - will use LXD"
elif command -v multipass >/dev/null 2>&1; then
  BUILD_MODE="multipass"
  echo "✓ Multipass detected - will use Multipass"
else
  echo "❌ No build environment detected"
  echo ""
  echo "You need either:"
  echo "  - LXD (Linux): sudo snap install lxd && sudo lxd init --auto"
  echo "  - Multipass (macOS/Linux): brew install multipass"
  exit 1
fi

echo ""

# Step 1: Create snapcraft project
echo "[1/6] Creating reference snap project..."
SNAP_DIR="$WORK_DIR/reference-snap"
mkdir -p "$SNAP_DIR/bin"

cat > "$SNAP_DIR/bin/hello" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$SNAP_DIR/bin/hello"

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

echo "✅ Snapcraft project created"

# Step 2: Build snap
echo ""
echo "[2/6] Building reference snap..."
SNAP_FILE=$(find "$SNAP_DIR" -maxdepth 1 -name "*.snap" -type f 2>/dev/null | head -1)

if [ -n "$SNAP_FILE" ] && [ -f "$SNAP_FILE" ]; then
  echo "✅ Using cached snap: $(basename "$SNAP_FILE")"
  echo "   (Delete to rebuild: rm $SNAP_FILE)"
else
  echo "Building with snapcraft (this may take 5-10 minutes)..."
  echo "Build mode: $BUILD_MODE"
  echo ""
  
  (
    cd "$SNAP_DIR"
    
    case "$BUILD_MODE" in
      lxd)
        echo "Building with LXD..."
        snapcraft --use-lxd --verbose
        ;;
      multipass)
        echo "Building with Multipass..."
        snapcraft --verbose
        ;;
      *)
        echo "❌ Unknown build mode: $BUILD_MODE"
        exit 1
        ;;
    esac
  )
  
  if [ $? -ne 0 ]; then
    echo "❌ Snapcraft build failed"
    exit 1
  fi
  
  SNAP_FILE=$(find "$SNAP_DIR" -maxdepth 1 -name "*.snap" -type f | head -1)
  
  if [ -z "$SNAP_FILE" ] || [ ! -f "$SNAP_FILE" ]; then
    echo "❌ No snap file generated"
    echo "Looking for any .snap files in $SNAP_DIR..."
    find "$SNAP_DIR" -name "*.snap" -type f || echo "No .snap files found"
    exit 1
  fi
  
  echo "✅ Built: $(basename "$SNAP_FILE")"
fi

# Step 3: Extract snap
echo ""
echo "[3/6] Extracting snap contents..."
EXTRACT_DIR="$WORK_DIR/extracted"
rm -rf "$EXTRACT_DIR"
unsquashfs -q -d "$EXTRACT_DIR" "$SNAP_FILE"

if [ ! -d "$EXTRACT_DIR" ]; then
  echo "❌ Extraction failed"
  exit 1
fi

echo "✅ Extracted to $EXTRACT_DIR"

# Step 4: Copy runtime files to template
echo ""
echo "[4/6] Creating template structure..."
FINAL_TEMPLATE_DIR="$TEMPLATE_DIR/$TEMPLATE_NAME"
rm -rf "$FINAL_TEMPLATE_DIR"
mkdir -p "$FINAL_TEMPLATE_DIR/meta-reference"

# Copy snap.yaml
cp "$EXTRACT_DIR/meta/snap.yaml" "$FINAL_TEMPLATE_DIR/meta-reference/"

# Copy runtime directories
echo "Copying GNOME runtime files..."
for dir in gnome-platform gpu-2404 data-dir graphics-core24 mesa-2404; do
  if [ -d "$EXTRACT_DIR/$dir" ]; then
    echo "  ✓ Copying $dir/"
    rsync -a "$EXTRACT_DIR/$dir/" "$FINAL_TEMPLATE_DIR/$dir/"
  fi
done

# Count libraries
SO_COUNT=$(find "$FINAL_TEMPLATE_DIR" -name "*.so*" -type f 2>/dev/null | wc -l | tr -d ' ')
DIR_COUNT=$(find "$FINAL_TEMPLATE_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')

echo "✅ Template structure created"
echo "   Directories: $DIR_COUNT"
echo "   Libraries: $SO_COUNT"

# Step 5: Generate helper scripts
echo ""
echo "[5/6] Generating helper scripts..."

cat > "$FINAL_TEMPLATE_DIR/generate-snapcraft.sh" <<'GEN'
#!/bin/bash
set -e

APP_NAME="${1:-myapp}"
VERSION="${2:-1.0.0}"
SUMMARY="${3:-My Application}"
DESCRIPTION="${4:-My application description}"

if [ ! -f "meta-reference/snap.yaml" ]; then
  echo "❌ meta-reference/snap.yaml not found"
  echo "Are you in the template directory?"
  exit 1
fi

echo "Generating snapcraft.yaml from extracted gnome extension..."

export APP_NAME VERSION SUMMARY DESCRIPTION

python3 <<'PY'
import yaml
import os
import sys

try:
    app_name = os.environ['APP_NAME']
    version = os.environ['VERSION']
    summary = os.environ.get('SUMMARY', 'My Application')
    description = os.environ.get('DESCRIPTION', 'My application description')
    
    with open('meta-reference/snap.yaml') as f:
        snap = yaml.safe_load(f)
    
    ref_app = snap['apps'][list(snap['apps'].keys())[0]]
    
    # Find which runtime directories exist
    import os
    runtime_dirs = []
    for d in ['gnome-platform', 'gpu-2404', 'data-dir', 'graphics-core24', 'mesa-2404']:
        if os.path.isdir(d):
            runtime_dirs.append(d)
    
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
                'stage': runtime_dirs + ['-meta-reference', '-*.sh', '-*.md', '-*.txt']
            },
            'app': {
                'plugin': 'dump',
                'source': 'app/',
                'stage-packages': [
                    'libnspr4',
                    'libnss3',
                    'libxss1',
                    'libappindicator3-1',
                    'libsecret-1-0',
                    'libatomic1'
                ],
                'organize': {'*': 'app/'},
                'after': ['gnome-runtime']
            }
        }
    }
    
    if snap.get('layout'):
        snapcraft['layout'] = snap['layout']
    if snap.get('assumes'):
        snapcraft['assumes'] = snap['assumes']
    
    with open('snapcraft.yaml', 'w') as f:
        yaml.dump(snapcraft, f, default_flow_style=False, sort_keys=False, indent=2)
    
    print(f"✅ Generated snapcraft.yaml for {app_name}")
    print(f"   Version: {version}")
    print(f"   Plugs: {len(ref_app.get('plugs', []))}")
    print(f"   Environment variables: {len(ref_app.get('environment', {}))}")
    print(f"   Runtime directories: {', '.join(runtime_dirs)}")
    print("")
    print("Next steps:")
    print("  1. mkdir -p app")
    print("  2. Copy your Electron app to app/")
    print("  3. Review snapcraft.yaml")
    print("  4. Run: snapcraft --offline")

except Exception as e:
    print(f"❌ Error: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc()
    sys.exit(1)
PY
GEN
chmod +x "$FINAL_TEMPLATE_DIR/generate-snapcraft.sh"

cat > "$FINAL_TEMPLATE_DIR/show-extension-details.sh" <<'SHOW'
#!/bin/bash

if [ ! -f "meta-reference/snap.yaml" ]; then
  echo "❌ Not in template directory"
  exit 1
fi

python3 <<'PY'
import yaml
import os

with open('meta-reference/snap.yaml') as f:
    snap = yaml.safe_load(f)

app = snap['apps'][list(snap['apps'].keys())[0]]

print("=" * 70)
print("GNOME Extension Configuration (Extracted from Actual Snap)")
print("=" * 70)
print()

print("Environment Variables:")
print("-" * 70)
for k, v in sorted(app.get('environment', {}).items()):
    print(f"{k}={v}")

print()
print("Plugs (Interfaces):")
print("-" * 70)
for plug in sorted(app.get('plugs', [])):
    print(f"  {plug}")

if snap.get('layout'):
    print()
    print("Layouts:")
    print("-" * 70)
    for path, config in snap['layout'].items():
        print(f"  {path}:")
        for k, v in config.items():
            print(f"    {k}: {v}")

print()
print("Runtime Directories:")
print("-" * 70)
for d in ['gnome-platform', 'gpu-2404', 'data-dir', 'graphics-core24', 'mesa-2404']:
    if os.path.isdir(d):
        size = sum(
            os.path.getsize(os.path.join(dirpath, filename))
            for dirpath, dirnames, filenames in os.walk(d)
            for filename in filenames
        )
        print(f"  {d}: {size / 1024 / 1024:.1f} MB")
PY
SHOW
chmod +x "$FINAL_TEMPLATE_DIR/show-extension-details.sh"

# Generate README
cat > "$FINAL_TEMPLATE_DIR/README.md" <<EOF
# Offline GNOME Runtime Template

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Platform:** $(uname -s)  
**Architecture:** $ARCH  
**Build Mode:** $BUILD_MODE  
**Directories:** $DIR_COUNT  
**Libraries:** $SO_COUNT

## What is this?

This template was **EXTRACTED** from a snap built with the \`gnome\` extension.
It contains the ACTUAL runtime files, configuration, and environment that
Canonical's GNOME extension provides.

**Key benefit:** Rebuild this template monthly to automatically get the latest
security updates and library versions from Canonical.

## Contents

- **$SO_COUNT shared libraries** from GNOME platform
- Complete GNOME runtime (GTK, GDK, Cairo, Pango, etc.)
- GPU/Mesa drivers
- Font configuration and icon themes
- Pre-compiled GSettings schemas

## Quick Start

### 1. Inspect what the extension provides

\`\`\`bash
./show-extension-details.sh
\`\`\`

### 2. Generate snapcraft.yaml

\`\`\`bash
./generate-snapcraft.sh myapp 1.0.0 "My App" "Description"
\`\`\`

This uses the actual extracted metadata from the gnome extension.

### 3. Add your Electron app

\`\`\`bash
mkdir -p app
cp -r /path/to/your/electron/app/* app/
\`\`\`

### 4. Build offline

\`\`\`bash
snapcraft --offline
\`\`\`

## Files

- \`meta-reference/snap.yaml\` - Actual snap.yaml from built snap
- \`gnome-platform/\` - GNOME runtime libraries
- \`gpu-2404/\` - GPU/graphics libraries
- \`data-dir/\` - Themes, icons, fonts
- \`generate-snapcraft.sh\` - Helper to create snapcraft.yaml
- \`show-extension-details.sh\` - Show extension configuration

## Updating

**IMPORTANT:** Rebuild monthly to get security updates!

\`\`\`bash
./build-snap-template.sh $ARCH
\`\`\`

This automatically gets:
- ✅ Security patches from Canonical
- ✅ Updated library versions
- ✅ New gnome extension features
- ✅ Bug fixes

## Build Environment

This template was built using **$BUILD_MODE**:
- macOS: Uses Multipass
- Linux: Uses LXD
- CI/CD: Uses LXD

## License

The libraries included are from Ubuntu packages and maintain their original licenses.
EOF

echo "✅ Helper scripts generated"

# Step 6: Create tarball
echo ""
echo "[6/6] Creating distribution tarball..."
TAR_NAME="${TEMPLATE_NAME}.tar.gz"
( cd "$TEMPLATE_DIR" && tar czf "$OUT_DIR/$TAR_NAME" "$TEMPLATE_NAME" )

TAR_SIZE=$(du -h "$OUT_DIR/$TAR_NAME" | cut -f1)
TEMPLATE_SIZE=$(du -sh "$FINAL_TEMPLATE_DIR" | cut -f1)

# Final summary
echo ""
echo "======================================================================="
echo "✅ Template created successfully!"
echo "======================================================================="
echo ""
echo "Build Mode: $BUILD_MODE"
echo "Template Directory: $FINAL_TEMPLATE_DIR"
echo "Template Size: $TEMPLATE_SIZE"
echo "Tarball: $OUT_DIR/$TAR_NAME ($TAR_SIZE)"
echo ""
echo "Contents:"
echo "  - $DIR_COUNT runtime directories"
echo "  - $SO_COUNT shared libraries"
echo ""
echo "To use:"
echo "  cd $FINAL_TEMPLATE_DIR"
echo "  ./show-extension-details.sh"
echo "  ./generate-snapcraft.sh myapp 1.0.0"
echo "  mkdir app && cp your-electron-app/* app/"
echo "  snapcraft --offline"
echo ""
echo "To rebuild template with latest updates:"
echo "  $(basename "$0") $ARCH"
echo ""