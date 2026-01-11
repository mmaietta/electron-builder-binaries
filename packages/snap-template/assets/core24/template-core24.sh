#!/bin/bash
set -e

# All operations relative to BASE_DIR/WORK_DIR - minimal use of `cd` (only in subshells)

ARCH="${1:-amd64}"
SKIP_WAYLAND="${2:-false}"
TEMPLATE_VERSION="1"
BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$BASE_DIR/build/core24"
TEMPLATE_DIR="$BUILD_DIR/electron-runtime-template"
TEMPLATE_NAME="snap-template-electron-core24-v${TEMPLATE_VERSION}-${ARCH}"
WORK_DIR="$BUILD_DIR/work-$ARCH"

cleanup() {
  if [ -d "$WORK_DIR" ]; then 
    echo "Cleaning up work directory..."
    rm -rf "$WORK_DIR"
  fi
}
# trap cleanup EXIT

echo "======================================================================="
echo "Automated Offline Snap Template Builder"
echo "======================================================================="
echo "Architecture: $ARCH"
echo "Base Directory: $BASE_DIR"
echo "Work Directory: $WORK_DIR"
echo "Output Directory: $TEMPLATE_DIR"
echo ""

# Check required commands
MISSING_CMDS=()
for cmd in snapcraft unsquashfs python3 jq find file; do
  command -v "$cmd" >/dev/null 2>&1 || MISSING_CMDS+=("$cmd")
done

if [ ${#MISSING_CMDS[@]} -gt 0 ]; then
  echo "❌ Missing: ${MISSING_CMDS[*]}"
  exit 1
fi

HAS_PATCHELF=false
command -v patchelf >/dev/null 2>&1 && HAS_PATCHELF=true

# Step 1: Create reference snap
echo "[1/8] Creating reference snap..."
SNAP_DIR="$WORK_DIR/reference-snap"
mkdir -p "$SNAP_DIR/bin"

cat > "$SNAP_DIR/bin/hello" << 'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$SNAP_DIR/bin/hello"

cat > "$SNAP_DIR/snapcraft.yaml" << 'EOF'
name: reference-app
base: core24
version: '1.0'
summary: Reference app
description: Extract gnome extension

grade: stable
confinement: strict

apps:
  reference-app:
    command: bin/hello
    extensions: [gnome]
    plugs: [home, network, browser-support, audio-playback]

parts:
  dummy:
    plugin: dump
    source: .
    stage: [bin/hello]
EOF

SNAP_FILE=$(find "$SNAP_DIR" -maxdepth 1 -name "reference-app_*.snap" -type f 2>/dev/null | head -1)

if [ -n "$SNAP_FILE" ] && [ -f "$SNAP_FILE" ]; then
  echo "✅ Using cached: $(basename "$SNAP_FILE")"
else
  echo "Building snap (5-10 minutes)..."
  ( cd "$SNAP_DIR" && snapcraft --verbose 2>&1 | tee "$WORK_DIR/build.log" ) || exit 1
  SNAP_FILE=$(find "$SNAP_DIR" -maxdepth 1 -name "reference-app_*.snap" -type f | head -1)
  [ -z "$SNAP_FILE" ] && { echo "❌ No snap file"; exit 1; }
  echo "✅ Built: $(basename "$SNAP_FILE")"
fi

# Step 2: Extract snap
echo "[2/8] Extracting snap..."
export EXTRACT_DIR="$WORK_DIR/extracted"
unsquashfs -q -d "$EXTRACT_DIR" "$SNAP_FILE"
[ ! -d "$EXTRACT_DIR" ] && { echo "❌ Extract failed"; exit 1; }

# Step 3: Parse metadata
echo "[3/8] Parsing metadata..."
FINAL_TEMPLATE_DIR="$TEMPLATE_DIR/$TEMPLATE_NAME"
mkdir -p "$FINAL_TEMPLATE_DIR/meta-reference"
cp "$EXTRACT_DIR/meta/snap.yaml" "$FINAL_TEMPLATE_DIR/meta-reference/snap.yaml"

( cd "$WORK_DIR" && python3 << 'PY'
import yaml, json, os
with open(os.path.join(os.environ['EXTRACT_DIR'], 'meta', 'snap.yaml')) as f:
    snap = yaml.safe_load(f)
app = snap['apps'][list(snap['apps'].keys())[0]]
meta = {'environment': app.get('environment',{}), 'plugs': app.get('plugs',[]), 
        'slots': app.get('slots',[]), 'layout': snap.get('layout',{}), 
        'assumes': snap.get('assumes',[]), 'command': app.get('command','')}
for name in ['metadata', 'environment', 'plugs']:
    with open(f'{name}.json', 'w') as f:
        json.dump(meta if name=='metadata' else meta[name], f, indent=2)
print(f"✅ {len(meta['environment'])} env, {len(meta['plugs'])} plugs")
PY
) || exit 1

cp "$WORK_DIR"/{metadata,environment,plugs}.json "$FINAL_TEMPLATE_DIR/"

# Step 4: Copy files
echo "[4/8] Copying snap contents..."
if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude='bin/hello' --exclude='meta/' "$EXTRACT_DIR/" "$FINAL_TEMPLATE_DIR/"
else
  find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 ! -name 'meta' -exec cp -r {} "$FINAL_TEMPLATE_DIR/" \;
  rm -f "$FINAL_TEMPLATE_DIR/bin/hello"
fi

COPIED_LIBS=$(find "$FINAL_TEMPLATE_DIR" -name "*.so*" -type f | wc -l | tr -d ' ')
echo "✅ Copied $COPIED_LIBS libraries"

# Step 5: Find wrappers
echo "[5/8] Finding wrappers..."
find "$EXTRACT_DIR" -type f \( -name "*.sh" -o -name "*wrapper*" \) \
  ! -path "*/parts/*" ! -path "*/stage/*" 2>/dev/null | while read -r script; do
  REL="${script#$EXTRACT_DIR/}"
  [[ "$REL" == "bin/hello" ]] && continue
  mkdir -p "$FINAL_TEMPLATE_DIR/$(dirname "$REL")"
  cp -p "$script" "$FINAL_TEMPLATE_DIR/$REL"
  echo "  Found: $REL"
done

# Step 6: Validate dependencies
echo "[6/8] Validating dependencies..."
ALLOWLIST_ITEMS=()
DENYLIST_ITEMS=()
SIZE_REPORT="$FINAL_TEMPLATE_DIR/binary-size-report.txt"
echo "Binary Size Report" > "$SIZE_REPORT"

normalize_lib() { basename "$1" | sed -E 's/\.[0-9]+(\.[0-9]+)*$//'; }

BINARIES=()
if [[ "$(uname)" == "Darwin" ]]; then
  while IFS= read -r line; do BINARIES+=("$line"); done < <(
    find "$FINAL_TEMPLATE_DIR" -type f -perm +111 -exec file {} \; 2>/dev/null | grep 'Mach-O' | cut -d: -f1)
else
  while IFS= read -r line; do BINARIES+=("$line"); done < <(
    find "$FINAL_TEMPLATE_DIR" -type f -perm /111 -exec file {} \; 2>/dev/null | grep 'ELF' | cut -d: -f1)
fi

MISSING_COUNT=0
for bin in "${BINARIES[@]}"; do
  [ "$HAS_PATCHELF" = true ] && [[ "$(uname)" != "Darwin" ]] && \
    patchelf --set-rpath '$ORIGIN:$ORIGIN/../lib:$ORIGIN/../usr/lib' "$bin" 2>/dev/null || true
  
  DEPS=$([[ "$(uname)" == "Darwin" ]] && otool -L "$bin" 2>/dev/null | tail -n +2 | awk '{print $1}' || \
         ldd "$bin" 2>/dev/null | grep "=>" | awk '{print $3}')
  
  while IFS= read -r dep; do
    [[ -z "$dep" || "$dep" == "not" ]] && continue
    [[ "$SKIP_WAYLAND" == "true" && "$dep" =~ wayland ]] && continue
    
    LIB=$(normalize_lib "$dep")
    if [[ -f "$dep" ]] || find "$FINAL_TEMPLATE_DIR" -name "$LIB*" -type f 2>/dev/null | grep -q .; then
      ALLOWLIST_ITEMS+=("$LIB")
    else
      DENYLIST_ITEMS+=("$LIB")
      MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
  done <<< "$DEPS"
done

printf '%s\n' "${ALLOWLIST_ITEMS[@]}" | sort -u | jq -R . | jq -s . > "$FINAL_TEMPLATE_DIR/ld-allowlist.json"
printf '%s\n' "${DENYLIST_ITEMS[@]}" | sort -u | jq -R . | jq -s . > "$FINAL_TEMPLATE_DIR/ld-denylist.json"

ALLOWLIST_COUNT=$(jq 'length' "$FINAL_TEMPLATE_DIR/ld-allowlist.json")
DENYLIST_COUNT=$(jq 'length' "$FINAL_TEMPLATE_DIR/ld-denylist.json")
echo "✅ $ALLOWLIST_COUNT found, $DENYLIST_COUNT missing"

# Step 7: Generate helper scripts
echo "[7/8] Creating helpers..."

cat > "$FINAL_TEMPLATE_DIR/generate-snapcraft.sh" << 'GEN'
#!/bin/bash
set -e
APP_NAME="${1:-myapp}"; VERSION="${2:-1.0.0}"
export APP_NAME VERSION
python3 << 'PY'
import yaml, json, os
with open('meta-reference/snap.yaml') as f: snap = yaml.safe_load(f)
ref = snap['apps'][list(snap['apps'].keys())[0]]
app = os.environ['APP_NAME']
sc = {'name': app, 'base': 'core24', 'version': os.environ['VERSION'],
      'summary': os.environ.get('SUMMARY', 'My App'),
      'description': os.environ.get('DESCRIPTION', 'Description'),
      'grade': 'stable', 'confinement': 'strict',
      'apps': {app: {'command': f'app/{app}', 'plugs': ref.get('plugs',[]),
                     'environment': ref.get('environment',{})}},
      'parts': {'gnome-runtime': {'plugin': 'dump', 'source': '.',
                'stage': ['lib','usr','etc','data-dir','gnome-platform',
                          '-*.json','-*.sh','-*.md','-*.txt','-*.tar.gz','-meta-reference']},
                'app': {'plugin': 'dump', 'source': 'app/',
                        'stage-packages': ['libnspr4','libnss3','libxss1',
                                            'libappindicator3-1','libsecret-1-0','libatomic1'],
                        'organize': {'*': 'app/'}, 'after': ['gnome-runtime']}}}
with open('snapcraft.yaml', 'w') as f: yaml.dump(sc, f, default_flow_style=False, sort_keys=False)
print(f"✅ Generated snapcraft.yaml for {app}")
PY
GEN
chmod +x "$FINAL_TEMPLATE_DIR/generate-snapcraft.sh"

cat > "$FINAL_TEMPLATE_DIR/show-extension-details.sh" << 'SHOW'
#!/bin/bash
python3 << 'PY'
import json
with open('environment.json') as f: env = json.load(f)
with open('plugs.json') as f: plugs = json.load(f)
print("Environment:", *[f"{k}={v}" for k,v in sorted(env.items())], sep="\n  ")
print("\nPlugs:", *sorted(plugs), sep="\n  ")
PY
SHOW
chmod +x "$FINAL_TEMPLATE_DIR/show-extension-details.sh"

# Step 8: Documentation
echo "[8/8] Generating docs..."
ENV_COUNT=$(jq 'length' "$FINAL_TEMPLATE_DIR/environment.json")
PLUGS_COUNT=$(jq 'length' "$FINAL_TEMPLATE_DIR/plugs.json")

cat > "$FINAL_TEMPLATE_DIR/README.md" << EOF
# Offline Snap Template (Extracted from GNOME Extension)

**Generated:** $(date -u)
**Architecture:** $ARCH
**Libraries:** $COPIED_LIBS
**Environment:** $ENV_COUNT vars
**Plugs:** $PLUGS_COUNT
**Dependencies:** $ALLOWLIST_COUNT found, $DENYLIST_COUNT missing

## Quick Start
\`\`\`bash
./generate-snapcraft.sh myapp 1.0.0
mkdir app && cp -r /your/electron/app/* app/
snapcraft --offline
\`\`\`

See meta-reference/snap.yaml for actual extension configuration.
EOF

# Create tarball
( cd "$TEMPLATE_DIR" && tar czf "${TEMPLATE_NAME}.tar.gz" "$TEMPLATE_NAME" )

echo ""
echo "✅ Template: $FINAL_TEMPLATE_DIR"
echo "✅ Tarball: $TEMPLATE_DIR/${TEMPLATE_NAME}.tar.gz"
echo ""
[ $DENYLIST_COUNT -gt 0 ] && { [ -n "$CI" ] && exit 1 || echo "⚠️  $DENYLIST_COUNT missing deps"; }
exit 0