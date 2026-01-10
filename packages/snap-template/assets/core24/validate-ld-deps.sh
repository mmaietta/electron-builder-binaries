#!/bin/bash
# validate-ld-deps.sh
# Portable LD dependency validator for GTK/Electron runtime templates
#
# Usage:
#   ./validate-ld-deps.sh /path/to/template [skip-wayland]
# Example:
#   ./validate-ld-deps.sh ./snap-template false

set -e

TEMPLATE_DIR="${1:-.}"
SKIP_WAYLAND="${2:-false}"
GENERATED_DIR="$TEMPLATE_DIR/generated"
rm -rf "$GENERATED_DIR"
mkdir -p "$GENERATED_DIR"
ALLOWLIST_FILE="$GENERATED_DIR/ld-allowlist.json"
DENYLIST_FILE="$GENERATED_DIR/ld-denylist.json"
SIZE_REPORT="$GENERATED_DIR/binary-size-report.txt"


echo "🔍 Validating LD dependencies in $TEMPLATE_DIR"
echo "Platform: $(uname)"
echo "Skip Wayland libs: $SKIP_WAYLAND"
echo "Scanning binaries..."

BINARIES=()

# Find executables
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: Mach-O executables
    while IFS= read -r line; do
        BINARIES+=("$line")
    done < <(find "$TEMPLATE_DIR" -type f -perm -111 -exec file '{}' \; | grep 'Mach-O' | cut -d: -f1)
else
    # Linux: ELF executables
    while IFS= read -r line; do
        BINARIES+=("$line")
    done < <(find "$TEMPLATE_DIR" -type f -perm /111 -exec file '{}' \; | grep 'ELF' | cut -d: -f1)
fi

echo "Found ${#BINARIES[@]} binaries"
echo ""
if [ "${#BINARIES[@]}" -eq 0 ]; then
    echo "❌ No binaries found to scan."
    exit 1
fi

# Prepare allow/deny lists
ALLOWLIST=()
DENYLIST=()

# Prepare binary size report
echo "Binary Size Report" > "$SIZE_REPORT"
echo "==================" >> "$SIZE_REPORT"

# Helper: normalize library paths for comparison
normalize_lib() {
    local lib="$1"
    basename "$lib" | sed 's/\.[0-9][0-9]*//g'
}

# Scan each binary
for bin in "${BINARIES[@]}"; do
    echo "🔹 Scanning $bin..."

    # Record size
    size_bytes=$(stat -f%z "$bin" 2>/dev/null || stat -c %s "$bin" 2>/dev/null)
    echo "$bin: $size_bytes bytes" >> "$SIZE_REPORT"

    # Get dynamic dependencies
    if [[ "$(uname)" == "Darwin" ]]; then
        deps=$(otool -L "$bin" 2>/dev/null | tail -n +2 | awk '{print $1}')
    else
        deps=$(ldd "$bin" 2>/dev/null | awk '{print $1}' | grep -v '^$')
    fi

    # Check each dependency
    while IFS= read -r dep; do
        # Skip empty
        [[ -z "$dep" ]] && continue

        # Optionally skip Wayland libs
        if [[ "$SKIP_WAYLAND" == "true" && "$dep" == *wayland* ]]; then
            continue
        fi

        # Normalize library name
        lib_name=$(normalize_lib "$dep")

        # Track allow/deny lists
        if [[ -f "$dep" ]]; then
            ALLOWLIST+=("$lib_name")
        else
            DENYLIST+=("$lib_name")
            echo "❌ Missing: $lib_name (required by $bin)"
        fi
    done <<< "$deps"

done

# Deduplicate allow/deny lists
ALLOWLIST_JSON=$(printf '%s\n' "${ALLOWLIST[@]}" | sort -u | jq -R . | jq -s .)
DENYLIST_JSON=$(printf '%s\n' "${DENYLIST[@]}" | sort -u | jq -R . | jq -s .)

# Write JSON files
echo "$ALLOWLIST_JSON" > "$ALLOWLIST_FILE"
echo "$DENYLIST_JSON" > "$DENYLIST_FILE"

# Summary
echo ""
echo "✅ Validation complete"
echo "Allowed libraries written to: $ALLOWLIST_FILE"
echo "Missing libraries written to: $DENYLIST_FILE"
echo "Binary size report: $SIZE_REPORT"
echo ""

# CI Gate: fail if any missing libraries
if [[ ${#DENYLIST[@]} -gt 0 ]]; then
    echo "❌ CI Gate: Found ${#DENYLIST[@]} missing libraries"
    exit 1
else
    echo "✅ All dynamic libraries satisfied"
    exit 0
fi
