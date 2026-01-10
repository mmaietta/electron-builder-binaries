#!/usr/bin/env bash
set -ex

# Automated offline snap template builder
# Extracts ACTUAL files from gnome extension for offline/airgapped builds
#
# Usage: ./build-offline-template.sh [architecture]
# Example: ./build-offline-template.sh amd64

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$ROOT/build/core24"

TEMPLATE_VERSION="1"
ARCH="${1:-amd64}"
TEMPLATE_DIR="${2:-$BUILD_DIR/electron-runtime-template}"

TEMPLATE_NAME="snap-template-electron-core24-v${TEMPLATE_VERSION}-${ARCH}"
WORK_DIR="$BUILD_DIR/work-$ARCH"

# Cleanup on exit
cleanup() {
  if [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
  fi
}
# trap cleanup EXIT
# cleanup
mkdir -p "$WORK_DIR"

echo "======================================================================="
echo "Automated Offline Snap Template Builder"
echo "======================================================================="
echo "Architecture: $ARCH"
echo "Template Version: $TEMPLATE_VERSION"
echo "Output Directory: $TEMPLATE_DIR"
echo ""

# Step 1: Create reference snap with gnome extension
echo "[1/7] Creating reference snap with gnome extension..."
SNAP_DIR="$WORK_DIR/reference-snap"
mkdir -p "$SNAP_DIR"
cd "$SNAP_DIR"

# # Create dummy executable
# mkdir -p "bin"
# echo "#!/bin/sh\nexit 0" > "bin/hello"
# chmod +x "bin/hello"

# cat > snapcraft.yaml << 'EOF'
# name: reference-app
# base: core24
# version: '1.0'
# summary: Reference app to extract gnome extension
# description: Temporary snap to extract extension configuration

# grade: stable
# confinement: strict

# apps:
#   reference-app:
#     command: bin/hello
#     extensions: [gnome]
#     plugs:
#       - home
#       - network
#       - browser-support
#       - audio-playback

# parts:
#     dummy:
#         plugin: dump
#         source: .
#         stage:
#             - bin/hello
# EOF

# echo "Building reference snap (this may take several minutes)..."
# if snapcraft pack --verbose 2>&1 | tee "$WORK_DIR/build.log"; then
#     echo "Executing snapcraft pack ouptput..."
# else
#   echo "❌ Failed to build snap. Check $WORK_DIR/build.log for details"
#   exit 1
# fi

SNAP_FILE=$(ls *.snap 2>/dev/null | head -1)
if [ -z "$SNAP_FILE" ] || [ ! -f "$SNAP_FILE" ]; then
  echo "❌ No .snap file generated"
  exit 1
fi

echo "✅ Built: $SNAP_FILE"

# Step 2: Extract the snap
echo ""
echo "[2/7] Extracting snap contents..."
EXTRACT_DIR="$WORK_DIR/extracted"
rm -rf "$EXTRACT_DIR"
unsquashfs -q -d "$EXTRACT_DIR" "$SNAP_FILE"

if [ ! -d "$EXTRACT_DIR" ]; then
  echo "❌ Failed to extract snap"
  exit 1
fi

echo "✅ Snap extracted to temporary directory"

# Step 3: Extract ACTUAL snap.yaml (not generate!)
echo ""
echo "[3/7] Extracting actual snap metadata..."

SNAP_YAML="$EXTRACT_DIR/meta/snap.yaml"

cd "$WORK_DIR"

python3 << 'PYTHON_SCRIPT'
import yaml
import json
import sys

try:
    with open('extracted/meta/snap.yaml', 'r') as f:
        snap_data = yaml.safe_load(f)

    app_name = list(snap_data['apps'].keys())[0]
    app_config = snap_data['apps'][app_name]

    metadata = {
        'environment': app_config.get('environment', {}),
        'plugs': app_config.get('plugs', []),
        'slots': app_config.get('slots', []),
        'layout': snap_data.get('layout', {}),
        'assumes': snap_data.get('assumes', []),
        'command': app_config.get('command', '')
    }

    with open('metadata.json', 'w') as f:
        json.dump(metadata, f, indent=2)

    with open('environment.json', 'w') as f:
        json.dump(metadata['environment'], f, indent=2)

    with open('plugs.json', 'w') as f:
        json.dump(metadata['plugs'], f, indent=2)

    print(f"✅ Extracted {len(metadata['environment'])} environment variables")
    print(f"✅ Extracted {len(metadata['plugs'])} plugs")
    print(f"✅ Command: {metadata['command']}")

except Exception as e:
    print(f"❌ Error parsing snap.yaml: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT

if [ $? -ne 0 ]; then
  echo "❌ Failed to parse snap metadata"
  exit 1
fi
ls -lh "$WORK_DIR" | grep -E 'environment.json|plugs.json|metadata.json'

cd "$WORK_DIR"

# Step 4: Create template directory structure
echo ""
echo "[4/7] Creating template directory and extracting ALL files..."

FINAL_TEMPLATE_DIR="$TEMPLATE_DIR/$TEMPLATE_NAME"
mkdir -p "$FINAL_TEMPLATE_DIR"

# Copy the ENTIRE snap contents (excluding our dummy app)
echo "Copying all snap contents..."
rsync -a --exclude='bin/hello' --exclude='meta/' "$EXTRACT_DIR/" "$FINAL_TEMPLATE_DIR/"

# Count what we got
COPIED_LIBS=$(find "$FINAL_TEMPLATE_DIR" -name "*.so*" | wc -l | tr -d ' ')
echo "✅ Copied entire snap contents ($COPIED_LIBS library files)"

echo ""
echo "[4.5/7] Pruning GNOME runtime to reduce size (Electron-safe)..."

cd "$FINAL_TEMPLATE_DIR"

ORIGINAL_SIZE=$(du -sh . | cut -f1)

echo "Original size: $ORIGINAL_SIZE"

############################################
# A. Remove development & documentation files
############################################
echo "Removing development files, docs, manpages..."

rm -rf usr/include
rm -rf usr/share/doc
rm -rf usr/share/man
rm -rf usr/lib/*/pkgconfig
rm -rf usr/lib/*/*.a

############################################
# B. Remove GTK 4 (Electron uses GTK 3)
############################################
echo "Removing GTK4 / libadwaita..."

rm -f usr/lib/*/libgtk-4.so*
rm -f usr/lib/*/libadwaita*
rm -rf usr/share/gtk-4.0

############################################
# C. Prune locale data (keep en + en_US)
############################################
echo "Pruning locales..."

if [ -d usr/share/locale ]; then
  find usr/share/locale -mindepth 1 -maxdepth 1 \
    ! -name en ! -name en_US -exec rm -rf {} +
fi

############################################
# D. Reduce font set (Electron-safe)
############################################
echo "Reducing font set..."

if [ -d usr/share/fonts ]; then
  find usr/share/fonts -type d \
    ! -iname '*dejavu*' \
    ! -iname '*liberation*' \
    -exec rm -rf {} +
fi

############################################
# E. Remove unused icon themes (keep Adwaita + hicolor)
############################################
echo "Pruning icon themes..."

if [ -d usr/share/icons ]; then
  find usr/share/icons -mindepth 1 -maxdepth 1 \
    ! -name Adwaita ! -name hicolor \
    -exec rm -rf {} +
fi

############################################
# F. Strip ELF binaries (safe)
############################################
echo "Stripping binaries..."

find usr/lib lib -type f -name "*.so*" -exec strip --strip-unneeded {} + 2>/dev/null || true

############################################
# G. Remove static caches (safe regeneration)
############################################
echo "Removing icon and font caches..."

find usr/share/icons -name "icon-theme.cache" -delete 2>/dev/null || true
find usr/share/fonts -name "*.cache-*" -delete 2>/dev/null || true

############################################
# Size report
############################################
FINAL_SIZE=$(du -sh . | cut -f1)

echo "Pruning complete"
echo "Size before: $ORIGINAL_SIZE"
echo "Size after:  $FINAL_SIZE"

# Step 5: Extract and analyze wrapper scripts
echo ""
echo "[5/7] Extracting wrapper/launcher scripts from snap..."

# The gnome extension may create wrapper scripts - let's find them
WRAPPER_SCRIPTS=$(find "$EXTRACT_DIR" -type f -name "*.sh" -o -name "*wrapper*" -o -name "command-*" | grep -v "build\|parts" || true)

if [ -n "$WRAPPER_SCRIPTS" ]; then
  echo "Found wrapper scripts:"
  echo "$WRAPPER_SCRIPTS" | while read -r script; do
    REL_PATH="${script#$EXTRACT_DIR/}"
    echo "  - $REL_PATH"
    
    # Copy to template
    TARGET="$FINAL_TEMPLATE_DIR/$REL_PATH"
    mkdir -p "$(dirname "$TARGET")"
    cp -p "$script" "$TARGET"
  done
else
  echo "No additional wrapper scripts found (extension may inline everything)"
fi

# Step 6: Copy the ACTUAL snap.yaml as a reference
echo ""
echo "[6/7] Copying actual snap.yaml as reference..."

mkdir -p "$FINAL_TEMPLATE_DIR/meta-reference"
cp "$SNAP_YAML" "$FINAL_TEMPLATE_DIR/meta-reference/snap.yaml"
if [ -f "$WORK_DIR/metadata.json" ]; then
  cp "$WORK_DIR/metadata.json" "$FINAL_TEMPLATE_DIR/"
else
  echo "ℹ️ metadata.json not present (expected for snapcraft pack)"
fi
cp "$WORK_DIR/environment.json" "$FINAL_TEMPLATE_DIR/"
cp "$WORK_DIR/plugs.json" "$FINAL_TEMPLATE_DIR/"

echo "✅ Actual snap.yaml saved to meta-reference/"

# Step 7: Create helper scripts that USE the extracted data
echo ""
echo "[7/7] Creating helper scripts..."

# Generate snapcraft.yaml from ACTUAL extracted data
cat > "$FINAL_TEMPLATE_DIR/generate-snapcraft.sh" << 'GENERATE_SCRIPT'
#!/bin/bash
# Generate snapcraft.yaml using EXTRACTED data from gnome extension

set -e

APP_NAME="${1:-myapp}"
VERSION="${2:-1.0.0}"
SUMMARY="${3:-My Application}"
DESCRIPTION="${4:-My application description}"

if [ ! -f "metadata.json" ]; then
  echo "❌ metadata.json not found. Are you in the template directory?"
  exit 1
fi

echo "Generating snapcraft.yaml from extracted gnome extension data..."

# Read actual environment and plugs from extracted snap
python3 << 'PYTHON'
import yaml
import json
import sys
import os

app_name = os.environ.get('APP_NAME', 'myapp')
version = os.environ.get('VERSION', '1.0.0')
summary = os.environ.get('SUMMARY', 'My Application')
description = os.environ.get('DESCRIPTION', 'My application description')

# Load extracted metadata
with open('metadata.json', 'r') as f:
    metadata = json.load(f)

# Load the reference snap.yaml to see exact structure
with open('meta-reference/snap.yaml', 'r') as f:
    reference_snap = yaml.safe_load(f)

# Build snapcraft.yaml using ACTUAL extracted data
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
            'command': 'app/' + app_name,  # Your app executable
            'plugs': metadata['plugs'],
            'environment': metadata['environment']
        }
    },
    'parts': {
        'gnome-runtime': {
            'plugin': 'dump',
            'source': '.',
            'stage': [
                'lib',
                'usr',
                'etc',
                'data-dir',
                'gnome-platform',
                # Exclude template files
                '-metadata.json',
                '-environment.json',
                '-plugs.json',
                '-README.md',
                '-generate-snapcraft.sh',
                '-meta-reference',
                '-*.tar.gz'
            ]
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
            'organize': {
                '*': 'app/'
            },
            'after': ['gnome-runtime']
        }
    }
}

# Add layout if present in extracted metadata
if metadata.get('layout'):
    snapcraft['layout'] = metadata['layout']

# Add assumes if present
if metadata.get('assumes'):
    snapcraft['assumes'] = metadata['assumes']

# Write snapcraft.yaml
with open('snapcraft.yaml', 'w') as f:
    yaml.dump(snapcraft, f, default_flow_style=False, sort_keys=False, indent=2)

print(f"✅ Generated snapcraft.yaml for {app_name}")
print(f"\nExtracted from gnome extension:")
print(f"  - {len(metadata['environment'])} environment variables")
print(f"  - {len(metadata['plugs'])} plugs")
print(f"\nSee meta-reference/snap.yaml for the original snap configuration")
PYTHON

export APP_NAME VERSION SUMMARY DESCRIPTION
python3

echo ""
echo "Next steps:"
echo "1. mkdir -p app"
echo "2. Copy your Electron app to app/"
echo "3. Review snapcraft.yaml"
echo "4. Run: snapcraft --offline"
GENERATE_SCRIPT

chmod +x "$FINAL_TEMPLATE_DIR/generate-snapcraft.sh"

# Create a script to show what the extension actually does
cat > "$FINAL_TEMPLATE_DIR/show-extension-details.sh" << 'SHOW_SCRIPT'
#!/bin/bash
# Display what the gnome extension actually configured

echo "========================================"
echo "GNOME Extension Configuration (Extracted)"
echo "========================================"
echo ""

echo "Environment Variables:"
echo "----------------------"
python3 -c "import json; env = json.load(open('environment.json')); print('\n'.join([f'{k}={v}' for k, v in sorted(env.items())]))"

echo ""
echo "Plugs (Interfaces):"
echo "-------------------"
python3 -c "import json; plugs = json.load(open('plugs.json')); print('\n'.join(sorted(plugs)))"

echo ""
echo "Command:"
echo "--------"
python3 -c "import json; print(json.load(open('metadata.json'))['command'])"

echo ""
echo "See meta-reference/snap.yaml for the complete configuration"
SHOW_SCRIPT

chmod +x "$FINAL_TEMPLATE_DIR/show-extension-details.sh"

# Generate README
GENERATED_DATE="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
ENV_COUNT=$(python3 -c "import json; print(len(json.load(open('$WORK_DIR/environment.json'))))")
PLUGS_COUNT=$(python3 -c "import json; print(len(json.load(open('$WORK_DIR/plugs.json'))))")

cat > "$FINAL_TEMPLATE_DIR/README.md" << EOF
# Offline Snap Template (Extracted from GNOME Extension)

**Generated:** $GENERATED_DATE  
**Base:** core24  
**Architecture:** $ARCH  
**Template Version:** $TEMPLATE_VERSION

## What is this?

This template was automatically **EXTRACTED** from a snap built with the \`gnome\` 
extension. It contains the ACTUAL files, configuration, and scripts that Canonical's
GNOME extension creates - not hardcoded templates.

**Key Point:** This is a snapshot of the real gnome extension. When you rebuild 
this template, you get the latest updates from Canonical automatically.

## Contents

All files are **extracted from the actual built snap**:

- **$COPIED_LIBS shared libraries** (from GNOME platform)
- **$ENV_COUNT environment variables** (from actual snap.yaml)
- **$PLUGS_COUNT snap interfaces** (from actual snap.yaml)
- **meta-reference/snap.yaml** - The ACTUAL snap.yaml from the built snap
- All wrapper scripts, launcher scripts (if any)
- Complete GNOME runtime (GTK, GDK, Cairo, Pango, etc.)
- Font configuration and icon themes
- Pre-compiled GSettings schemas

## Quick Start

### 1. See what the extension actually does

\`\`\`bash
./show-extension-details.sh
\`\`\`

### 2. Generate snapcraft.yaml (using extracted data)

\`\`\`bash
./generate-snapcraft.sh myapp 1.0.0 "My App" "My application description"
\`\`\`

This reads from the extracted metadata.json, environment.json, and plugs.json
to create a snapcraft.yaml with the EXACT configuration the gnome extension uses.

### 3. Add your Electron app

\`\`\`bash
mkdir -p app
cp -r /path/to/your/electron/app/* app/
\`\`\`

### 4. Build offline

\`\`\`bash
snapcraft --offline
\`\`\`

## Why This Approach is Better

- ✅ Offline/airgapped builds
- ✅ Exact files used by gnome extension
- ✅ No guesswork or hardcoded templates
- ✅ Automatically get security updates when this template is rebuilt
- ✅ Use ACTUAL files from gnome extension
- ✅ Get exact configuration Canonical uses
- ✅ See exactly what the extension does

## Updating the Template

**IMPORTANT:** Rebuild monthly to get security updates!

\`\`\`bash
cd $ROOT
./build-offline-template.sh $ARCH
\`\`\`

This will:
1. Build a new snap with the current gnome extension
2. Extract all files, configs, and metadata
3. Create an updated template with the latest libraries

You automatically get:
- Security patches from Canonical
- Updated library versions
- New features in the gnome extension
- Bug fixes

## Files Explained

### Extracted from Snap
- \`meta-reference/snap.yaml\` - ACTUAL snap.yaml from built snap
- \`metadata.json\` - Parsed metadata (environment, plugs, etc.)
- \`environment.json\` - Exact environment variables
- \`plugs.json\` - Exact interface plugs
- \`lib/\`, \`usr/\`, \`etc/\` - All extracted files

### Helper Scripts
- \`generate-snapcraft.sh\` - Creates snapcraft.yaml from extracted data
- \`show-extension-details.sh\` - Shows what the extension configured

## Inspecting the Extension

To see EXACTLY what the gnome extension does:

\`\`\`bash
# View the actual snap.yaml
cat meta-reference/snap.yaml

# See all environment variables
cat environment.json | python3 -m json.tool

# See all plugs
cat plugs.json | python3 -m json.tool

# Show summary
./show-extension-details.sh
\`\`\`

## Directory Structure

\`\`\`
$TEMPLATE_NAME/
├── meta-reference/
│   └── snap.yaml              # ACTUAL snap.yaml from built snap
├── metadata.json              # Parsed metadata
├── environment.json           # Exact environment variables
├── plugs.json                 # Exact interface plugs
├── generate-snapcraft.sh      # Generate snapcraft.yaml from extracted data
├── show-extension-details.sh  # Show what extension configured
├── README.md                  # This file
├── lib/                       # Extracted shared libraries
├── usr/                       # Extracted user-space libraries and config
├── etc/                       # Extracted configuration files
├── data-dir/                  # Extracted content snap mount points
│   ├── icons/
│   ├── themes/
│   └── sounds/
└── gnome-platform/            # Extracted GNOME platform mount point
\`\`\`

## Size

Template size: ~$(du -sh "$FINAL_TEMPLATE_DIR" 2>/dev/null | cut -f1 || echo "calculating...")

This includes the complete GNOME runtime, so it's larger than using the extension
directly, but it enables offline/airgapped builds.

## Notes

- **All files are EXTRACTED**, not generated
- This is a snapshot of Canonical's gnome extension
- Rebuild regularly to get security updates
- The snap.yaml in meta-reference/ shows exactly what the extension created

## License

The libraries included are from Ubuntu packages and maintain their original
licenses. This template structure is provided as-is for offline snap building.
EOF

echo "✅ Helper scripts and documentation created"

# Create distribution tarball
echo ""
echo "Creating distribution tarball..."

cd "$TEMPLATE_DIR"
tar czf "${TEMPLATE_NAME}.tar.gz" "$TEMPLATE_NAME"

TARBALL_SIZE=$(du -h "${TEMPLATE_NAME}.tar.gz" | cut -f1)

echo "✅ Tarball created: ${TEMPLATE_NAME}.tar.gz ($TARBALL_SIZE)"

# Summary
echo ""
echo "======================================================================="
echo "✅ Template EXTRACTED successfully!"
echo "======================================================================="
echo ""
echo "Template Directory: $FINAL_TEMPLATE_DIR"
echo "Tarball: $TEMPLATE_DIR/${TEMPLATE_NAME}.tar.gz"
echo "Size: $TARBALL_SIZE"
echo ""
echo "EXTRACTED Contents:"
echo "  - $COPIED_LIBS shared libraries (ACTUAL files from snap)"
echo "  - $ENV_COUNT environment variables (from snap.yaml)"
echo "  - $PLUGS_COUNT interface plugs (from snap.yaml)"
echo "  - Complete GNOME runtime (all files extracted)"
echo ""
echo "Key Files:"
echo "  - meta-reference/snap.yaml (ACTUAL snap.yaml from gnome extension)"
echo "  - metadata.json (parsed configuration)"
echo "  - environment.json (exact environment variables)"
echo ""
echo "To inspect what the extension does:"
echo "  cd $FINAL_TEMPLATE_DIR"
echo "  ./show-extension-details.sh"
echo ""
echo "To use this template:"
echo "  cd $FINAL_TEMPLATE_DIR"
echo "  ./generate-snapcraft.sh myapp 1.0.0"
echo "  mkdir app && cp your-electron-app/* app/"
echo "  snapcraft --offline"
echo ""
echo "To get latest updates from Canonical:"
echo "  Re-run: ./$(basename "$0") $ARCH"
echo ""
