#!/bin/bash
# validate-ld-deps.sh
# Validate dynamic library dependencies in a snap template
# Generates allowlist/denylist JSON
# Works on Linux + macOS (Darwin)
# Optional: remove Wayland libs

set -exuo pipefail

###########################
# Config / Input
###########################

TEMPLATE_DIR="${1:-.}"   # Path to extracted snap template
SKIP_WAYLAND="${2:-false}" # true|false

echo "🔍 Validating LD dependencies in $TEMPLATE_DIR"
echo "Platform: $(uname)"
echo "Skip Wayland libs: $SKIP_WAYLAND"

# Temp files
TMP_ALLOW="/tmp/ld-allowlist.txt"
TMP_DENY="/tmp/ld-denylist.txt"
> "$TMP_ALLOW"
> "$TMP_DENY"

###########################
# Find binaries
###########################

echo "Scanning binaries..."
BINARIES=$(find "$TEMPLATE_DIR" -type f -perm +111 -exec file {} \; | grep 'Mach-O\|ELF' | cut -d: -f1)

if [ -z "$BINARIES" ]; then
    echo "⚠️ No binaries found in $TEMPLATE_DIR"
fi

###########################
# Dependency extraction
###########################

for bin in $BINARIES; do
    echo "Processing: $bin"

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: otool -L
        DEPS=$(otool -L "$bin" | tail -n +2 | awk '{print $1}')
    else
        # Linux: ldd
        DEPS=$(ldd "$bin" | awk '{print $1}' | grep -v '^$')
    fi

    for dep in $DEPS; do
        dep_name=$(basename "$dep")

        # Optionally skip Wayland libs
        if [[ "$SKIP_WAYLAND" == "true" ]] && [[ "$dep_name" == libwayland* ]]; then
            continue
        fi

        # Simple heuristic: allow system libs (libc, libm, libX, libglib, etc.)
        case "$dep_name" in
            libc*|libm*|libpthread*|libdl*|libX11*|libGL*|libgobject*|libglib*|libgtk*|libcairo*|libpango*|libatk*|libgdk*)
                echo "$dep_name" >> "$TMP_ALLOW"
                ;;
            *)
                echo "$dep_name" >> "$TMP_DENY"
                ;;
        esac
    done
done

###########################
# Deduplicate and export JSON
###########################

ALLOW_JSON="$TEMPLATE_DIR/allowlist.json"
DENY_JSON="$TEMPLATE_DIR/denylist.json"

python3 - <<PYTHON
import json

def read_lines(path):
    try:
        with open(path) as f:
            return sorted(set(line.strip() for line in f if line.strip()))
    except FileNotFoundError:
        return []

allow = read_lines("$TMP_ALLOW")
deny = read_lines("$TMP_DENY")

with open("$ALLOW_JSON", "w") as f:
    json.dump(allow, f, indent=2)

with open("$DENY_JSON", "w") as f:
    json.dump(deny, f, indent=2)

print(f"✅ Allowlist ({len(allow)} libs): {', '.join(allow[:10])}{'...' if len(allow)>10 else ''}")
print(f"✅ Denylist ({len(deny)} libs): {', '.join(deny[:10])}{'...' if len(deny)>10 else ''}")
PYTHON

echo "✅ LD dependency validation complete"
echo "Allowlist: $ALLOW_JSON"
echo "Denylist: $DENY_JSON"
