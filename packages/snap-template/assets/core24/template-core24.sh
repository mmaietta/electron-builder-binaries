#!/usr/bin/env bash
set -exuo pipefail

###############################################################################
# Configuration
###############################################################################

ARCH="${1:-amd64}"
SKIP_WAYLAND="${2:-false}"
TEMPLATE_VERSION="1"

BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$BASE_DIR/build/core24"
WORK_DIR="$BUILD_DIR/work-$ARCH"
TEMPLATE_DIR="$BUILD_DIR/electron-runtime-template"
OUT_DIR="$BASE_DIR/out/snap-template"

DATE_UTC="$(date -u +%Y%m%d)"

###############################################################################
# Helpers
###############################################################################

fail() {
  echo "❌ $*" >&2
  exit 1
}

normalize_lib() {
  basename "$1" | sed -E 's/\.so(\.[0-9]+)*$/.so/'
}

###############################################################################
# Requirements
###############################################################################

echo "======================================================================="
echo "Offline GNOME Runtime Template Builder"
echo "======================================================================="
echo "ARCH            : $ARCH"
echo "SKIP_WAYLAND    : $SKIP_WAYLAND"
echo "BASE_DIR        : $BASE_DIR"
echo "WORK_DIR        : $WORK_DIR"
echo "OUT_DIR         : $OUT_DIR"
echo ""

REQUIRED_CMDS=(
  snapcraft
  unsquashfs
  python3
  jq
  find
  file
  patchelf
)

MISSING=()
for c in "${REQUIRED_CMDS[@]}"; do
  command -v "$c" >/dev/null 2>&1 || MISSING+=("$c")
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "❌ Missing required tools:"
  printf "  - %s\n" "${MISSING[@]}"
  if [[ "$(uname)" == "Darwin" ]]; then
    echo ""
    echo "💡 Install on macOS with:"
    echo "   brew install ${MISSING[*]}"
  fi
  exit 1
fi

###############################################################################
# Step 1: Build reference snap
###############################################################################

echo "[1/9] Building reference snap…"

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
summary: Reference GNOME extractor
description: Temporary snap for GNOME extension extraction

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

SNAP_FILE="$(find "$SNAP_DIR" -maxdepth 1 -name "*.snap" | head -1)"
[ -f "$SNAP_FILE" ] || (
  cd "$SNAP_DIR"
  snapcraft --verbose | tee "$WORK_DIR/snapcraft.log"
)
SNAP_FILE="$(find "$SNAP_DIR" -maxdepth 1 -name "*.snap" | head -1)"

###############################################################################
# Step 2: Extract snap
###############################################################################

echo "[2/9] Extracting snap…"

export EXTRACT_DIR="$WORK_DIR/extracted"
rm -rf "$EXTRACT_DIR"
unsquashfs -q -d "$EXTRACT_DIR" "$SNAP_FILE"

###############################################################################
# Step 3: Extract GNOME runtime identity (NO snap info)
###############################################################################
echo "[3/9] Extracting GNOME runtime identity…"

python3 << 'PY'
import yaml, json, os, sys

root = os.environ["EXTRACT_DIR"]
content_meta = os.path.join(root, "meta", "snap.yaml")

if not os.path.exists(content_meta):
    print("❌ gnome-platform content snap not found", file=sys.stderr)
    sys.exit(1)

with open(content_meta) as f:
    snap = yaml.safe_load(f)

identity = {
    "extension": "gnome",
    "content_snap": snap.get("name"),
    "version": snap.get("version"),
    "base": snap.get("base"),
}

with open("gnome-runtime.json", "w") as f:
    json.dump(identity, f, indent=2)

print(f"✅ GNOME runtime: {identity['content_snap']} ({identity['version']})")
PY

GNOME_SNAP="$(jq -r '.content_snap' gnome-runtime.json)"
GNOME_VER="$(jq -r '.version' gnome-runtime.json)"

[ "$GNOME_SNAP" != "unknown" ] || fail "Could not determine GNOME runtime"

###############################################################################
# Step 4: Prepare output directory
###############################################################################

TEMPLATE_NAME="snap-template-electron-core24-${GNOME_SNAP}-v${GNOME_VER}-${ARCH}"
export FINAL_DIR="$TEMPLATE_DIR/$TEMPLATE_NAME"

mkdir -p "$FINAL_DIR/meta-reference"
cp "$EXTRACT_DIR/meta/snap.yaml" "$FINAL_DIR/meta-reference/snap.yaml"
cp gnome-runtime.json "$FINAL_DIR/"

###############################################################################
# Step 5: Copy runtime files
###############################################################################

echo "[4/9] Copying runtime files…"

rsync -a \
  --exclude='bin/hello' \
  --exclude='meta/' \
  "$EXTRACT_DIR/" "$FINAL_DIR/"

###############################################################################
# Step 6: LD dependency validation + RPATH normalization
###############################################################################

echo "[5/9] Validating LD dependencies…"

ALLOWLIST_FILE="$WORK_DIR/ld-allowlist.tmp"
DENYLIST_FILE="$WORK_DIR/ld-denylist.tmp"

: > "$ALLOWLIST_FILE"
: > "$DENYLIST_FILE"

# find executable binaries (portable)
LIBRARIES="$(find "$FINAL_DIR" -type f \( -name '*.so' -o -name '*.so.*' -o -name '*.dylib' \))"

BINARIES="$(find "$FINAL_DIR" -type f -exec file {} \; 2>/dev/null | \
  grep -E 'ELF.*executable|Mach-O.*executable' | cut -d: -f1 || true)"
  
if [ -z "$BINARIES" ]; then
  echo "ℹ️  No executable binaries found (runtime-only template)"
else
  echo "🔍 Found executables:"
  echo "$BINARIES"
fi
if [ -z "$LIBRARIES" ]; then
  echo "⚠️  No shared libraries found — nothing to validate"
else
  echo "🔍 Validating $(echo "$LIBRARIES" | wc -l | tr -d ' ') shared libraries"
fi

for bin in $BINARIES; do
  if [[ "$(uname)" != "Darwin" ]]; then
    patchelf --set-rpath '$ORIGIN:$ORIGIN/../lib:$ORIGIN/../usr/lib' "$bin" 2>/dev/null || true
    DEPS="$(ldd "$bin" 2>/dev/null | awk '{print $3}')"
  else
    DEPS="$(otool -L "$bin" 2>/dev/null | tail -n +2 | awk '{print $1}')"
  fi

  for dep in $DEPS; do
    [[ "$SKIP_WAYLAND" == "true" && "$dep" == *wayland* ]] && continue
    lib="$(normalize_lib "$dep")"
    if find "$FINAL_DIR" -name "$lib*" | grep -q .; then
      echo "$lib" >> "$ALLOWLIST_FILE"
    else
      echo "$lib" >> "$DENYLIST_FILE"
    fi
  done
done

sort -u "$ALLOWLIST_FILE" | jq -R . | jq -s . > "$FINAL_DIR/ld-allowlist.json"
sort -u "$DENYLIST_FILE"  | jq -R . | jq -s . > "$FINAL_DIR/ld-denylist.json"

###############################################################################
# Step 7: Generate SBOM (CycloneDX, pretty)
###############################################################################

echo "[6/9] Generating SBOM…"

python3 << 'PY'
import os, json, hashlib, time, platform

ROOT = os.environ["FINAL_DIR"]

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(8192), b""):
            h.update(c)
    return h.hexdigest()

components = []
for r, _, files in os.walk(ROOT):
    for f in files:
        if ".so" not in f:
            continue
        p = os.path.join(r, f)
        components.append({
            "type": "library",
            "name": f,
            "hashes": [{"alg": "SHA-256", "content": sha256(p)}],
            "properties": [
                {"name": "path", "value": os.path.relpath(p, ROOT)},
                {"name": "size", "value": str(os.path.getsize(p))}
            ]
        })

sbom = {
    "bomFormat": "CycloneDX",
    "specVersion": "1.5",
    "version": 1,
    "metadata": {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "component": {
            "type": "application",
            "name": os.path.basename(ROOT),
            "properties": [
                {"name": "platform", "value": platform.system()}
            ]
        }
    },
    "components": sorted(components, key=lambda c: c["name"])
}

with open(os.path.join(ROOT, "sbom.cdx.json"), "w") as f:
    json.dump(sbom, f, indent=2)

print("✅ SBOM components:", len(components))
PY

###############################################################################
# Step 8: Documentation
###############################################################################

echo "[7/9] Writing README…"

cat > "$FINAL_DIR/README.md" << EOF
# Offline GNOME Runtime Template

**GNOME Runtime:** $GNOME_SNAP  
**Base:** core24  
**Architecture:** $ARCH  
**Generated:** $DATE_UTC

## Contents
- GNOME + GTK runtime
- NSS / X11 / indicator libraries
- Deterministic RPATHs
- CycloneDX SBOM
- LD allow/deny lists

## Usage
\`\`\`bash
tar xf ${TEMPLATE_NAME}.tar.gz
cd $TEMPLATE_NAME
./generate-snapcraft.sh myapp 1.0.0
snapcraft --offline
\`\`\`
EOF

###############################################################################
# Step 9: Package
###############################################################################

echo "[8/9] Packaging…"

(
  cd "$TEMPLATE_DIR"
  tar czf "$OUT_DIR/${TEMPLATE_NAME}.tar.gz" "$TEMPLATE_NAME"
)

echo "[9/9] Done."
echo "✅ Output: $FINAL_DIR"
echo "✅ Tarball: $TEMPLATE_DIR/${TEMPLATE_NAME}.tar.gz"

DENY_COUNT="$(jq 'length' "$FINAL_DIR/ld-denylist.json")"
[ "$DENY_COUNT" -eq 0 ] || { echo "⚠️  Missing deps: $DENY_COUNT"; [ -n "${CI:-}" ] && exit 1; }
