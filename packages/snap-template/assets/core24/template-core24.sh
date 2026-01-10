#!/bin/bash
set -e

# =============================================================================
# Automated Offline Snap Template Builder with LD dependency validation
# Extracts ACTUAL files from gnome extension for offline/airgapped builds
# Includes:
#   - LD dependency validation
#   - RPATH normalization (patchelf)
#   - Allow/Deny list generation
#   - Optional Wayland pruning
#   - Binary-level size report
#   - CI gate for missing libraries
# =============================================================================

ARCH="${1:-amd64}"
SKIP_WAYLAND="${2:-false}"  # true/false
TEMPLATE_VERSION="3"
BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$BASE_DIR/build/core24"
TEMPLATE_DIR="$BUILD_DIR/electron-runtime-template"
TEMPLATE_NAME="snap-template-electron-core24-v${TEMPLATE_VERSION}-${ARCH}"
WORK_DIR="$BUILD_DIR/work-$ARCH"

# Cleanup on exit
cleanup() {
  if [ -d "$WORK_DIR" ]; then rm -rf "$WORK_DIR"; fi
}
# trap cleanup EXIT

echo "======================================================================="
echo "Automated Offline Snap Template Builder"
echo "======================================================================="
echo "Architecture: $ARCH"
echo "Template Version: $TEMPLATE_VERSION"
echo "Output Directory: $TEMPLATE_DIR"
echo ""

# Required commands
for cmd in snapcraft unsquashfs python3 jq stat find file; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

# Step 1: Build reference snap with gnome extension
echo "[1/7] Creating reference snap with gnome extension..."
SNAP_DIR="$WORK_DIR/reference-snap"
mkdir -p "$SNAP_DIR"
cd "$SNAP_DIR"

mkdir -p bin
echo -e "#!/bin/sh\nexit 0" > bin/hello
chmod +x bin/hello

cat > snapcraft.yaml << 'EOF'
name: reference-app
base: core24
version: '1.0'
summary: Reference app to extract gnome extension
description: Temporary snap to extract extension configuration

grade: stable
confinement: strict

apps:
  reference-app:
    command: bin/hello
    extensions: [gnome]
    plugs:
      - home
      - network
      - browser-support
      - audio-playback

parts:
    dummy:
        plugin: dump
        source: .
        stage:
            - bin/hello
EOF

echo "Building reference snap..."

SNAP_FILE=$(ls *.snap 2>/dev/null | head -1)
if [ -z "$SNAP_FILE" ]; then
  echo "❌ No .snap file generated"
  snapcraft pack --verbose 2>&1 | tee "$WORK_DIR/build.log"
  SNAP_FILE=$(ls *.snap | head -1)
fi
echo "✅ Built: $SNAP_FILE"

# Step 2: Extract the snap
echo "[2/7] Extracting snap contents..."
EXTRACT_DIR="$WORK_DIR/extracted"
unsquashfs -q -d "$EXTRACT_DIR" "$SNAP_FILE"
echo "✅ Snap extracted to $EXTRACT_DIR"

# Step 3: Copy actual snap.yaml as reference
echo "[3/7] Copying snap.yaml reference..."
FINAL_TEMPLATE_DIR="$TEMPLATE_DIR/$TEMPLATE_NAME"
mkdir -p "$FINAL_TEMPLATE_DIR/meta-reference"
cp "$EXTRACT_DIR/meta/snap.yaml" "$FINAL_TEMPLATE_DIR/meta-reference/snap.yaml"

# Step 4: Copy all extracted files
echo "[4/7] Copying all extracted files..."
rsync -a --exclude='bin/hello' --exclude='meta/' "$EXTRACT_DIR/" "$FINAL_TEMPLATE_DIR/"

# Step 5: LD Dependency Validation & RPATH Normalization
echo "[5/7] Validating LD dependencies, normalizing RPATH..."

ALLOWLIST_FILE="$FINAL_TEMPLATE_DIR/ld-allowlist.json"
DENYLIST_FILE="$FINAL_TEMPLATE_DIR/ld-denylist.json"
SIZE_REPORT="$FINAL_TEMPLATE_DIR/binary-size-report.txt"

echo "Binary Size Report" > "$SIZE_REPORT"
echo "==================" >> "$SIZE_REPORT"

ALLOWLIST=()
DENYLIST=()

normalize_lib() { basename "$1" | sed 's/\.[0-9][0-9]*//g'; }

# Find binaries
BINARIES=()
if [[ "$(uname)" == "Darwin" ]]; then
    while IFS= read -r line; do BINARIES+=("$line"); done < <(find "$FINAL_TEMPLATE_DIR" -type f -perm -111 -exec file '{}' \; | grep 'Mach-O' | cut -d: -f1)
else
    while IFS= read -r line; do BINARIES+=("$line"); done < <(find "$FINAL_TEMPLATE_DIR" -type f -perm /111 -exec file '{}' \; | grep 'ELF' | cut -d: -f1)
fi

echo "Found ${#BINARIES[@]} binaries"

for bin in "${BINARIES[@]}"; do
    echo "🔹 $bin"
    # Record size
    size_bytes=$(stat -f%z "$bin" 2>/dev/null || stat -c %s "$bin" 2>/dev/null)
    echo "$bin: $size_bytes bytes" >> "$SIZE_REPORT"

    # Normalize RPATH (Linux only)
    if [[ "$(uname)" != "Darwin" ]] && command -v patchelf >/dev/null 2>&1; then
        patchelf --set-rpath '$ORIGIN/../lib:$ORIGIN/../usr/lib' "$bin" || true
    fi

    # Get dependencies
    if [[ "$(uname)" == "Darwin" ]]; then
        deps=$(otool -L "$bin" 2>/dev/null | tail -n +2 | awk '{print $1}')
    else
        deps=$(ldd "$bin" 2>/dev/null | awk '{print $1}' | grep -v '^$')
    fi

    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue
        [[ "$SKIP_WAYLAND" == "true" && "$dep" == *wayland* ]] && continue

        lib_name=$(normalize_lib "$dep")
        if [[ -f "$dep" ]]; then
            ALLOWLIST+=("$lib_name")
        else
            DENYLIST+=("$lib_name")
            echo "❌ Missing: $lib_name (required by $bin)"
        fi
    done <<< "$deps"
done

# Deduplicate lists and write JSON
ALLOWLIST_JSON=$(printf '%s\n' "${ALLOWLIST[@]}" | sort -u | jq -R . | jq -s .)
DENYLIST_JSON=$(printf '%s\n' "${DENYLIST[@]}" | sort -u | jq -R . | jq -s .)

echo "$ALLOWLIST_JSON" > "$ALLOWLIST_FILE"
echo "$DENYLIST_JSON" > "$DENYLIST_FILE"

echo "✅ LD validation complete"
echo "Allowlist: $ALLOWLIST_FILE"
echo "Denylist: $DENYLIST_FILE"
echo "Binary size report: $SIZE_REPORT"

# Step 6: Generate helper scripts and snapcraft.yaml generator
echo "[6/7] Creating helper scripts..."
cat > "$FINAL_TEMPLATE_DIR/generate-snapcraft.sh" << 'GEN_SCRIPT'
#!/bin/bash
set -e
APP_NAME="${1:-myapp}"
VERSION="${2:-1.0.0}"
SUMMARY="${3:-My App}"
DESCRIPTION="${4:-My application description}"

if [ ! -f "meta-reference/snap.yaml" ]; then
  echo "❌ meta-reference/snap.yaml not found"
  exit 1
fi

echo "Generating snapcraft.yaml using extracted gnome extension..."
python3 << 'PY'
import yaml, json, os
metadata_file = 'meta-reference/snap.yaml'
with open(metadata_file) as f:
    snap = yaml.safe_load(f)
snapcraft = {
  'name': os.environ.get('APP_NAME','myapp'),
  'base':'core24',
  'version': os.environ.get('VERSION','1.0.0'),
  'summary': os.environ.get('SUMMARY','My App'),
  'description': os.environ.get('DESCRIPTION','My application description'),
  'grade':'stable','confinement':'strict',
  'apps': { os.environ.get('APP_NAME','myapp'):{ 'command':'app/'+os.environ.get('APP_NAME','myapp'),
  'plugs': snap['apps'][list(snap['apps'].keys())[0]].get('plugs',[]),
  'environment': snap['apps'][list(snap['apps'].keys())[0]].get('environment',{}) } },
  'parts': { 'gnome-runtime': {'plugin':'dump','source':'.'} , 'app': {'plugin':'dump','source':'app/','after':['gnome-runtime'] } }
}
with open('snapcraft.yaml','w') as f: yaml.dump(snapcraft,f,default_flow_style=False,sort_keys=False,indent=2)
print("✅ snapcraft.yaml generated")
PY
GEN_SCRIPT
chmod +x "$FINAL_TEMPLATE_DIR/generate-snapcraft.sh"

# Step 7: Generate VERSION
echo "[7/7] Generating VERSION..."
cat > "$FINAL_TEMPLATE_DIR/VERSION.txt" << EOF
Offline Snap Template:
Generated: $(date -u)
Architecture: $ARCH
Template: $TEMPLATE_NAME
Contains extracted GNOME runtime, validated binaries, and helper scripts.
See ld-allowlist.json / ld-denylist.json for dependency info.
EOF

echo "======================================================================="
echo "✅ Template EXTRACTED and VALIDATED successfully!"
echo "Directory: $FINAL_TEMPLATE_DIR"
echo "LD allowlist: $ALLOWLIST_FILE"
echo "LD denylist: $DENYLIST_FILE"
echo "Binary size report: $SIZE_REPORT"
echo "======================================================================="

# CI Gate: exit if any missing libraries
if [[ ${#DENYLIST[@]} -gt 0 ]]; then
    echo "❌ CI Gate: Missing libraries detected!"
    exit 1
fi

exit 0
