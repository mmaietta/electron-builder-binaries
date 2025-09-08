#!/usr/bin/env bash
set -euo pipefail

# Path to fixes
BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
FIXES_DIR="$BASEDIR/assets/nsis-lang-fixes"
# Path to NSIS contrib language files
CONTRIB_DIR="$BASEDIR/out/nsis/nsis-bundle/mac/share/nsis/Contrib/Language files"

# Ensure dirs exist
if [[ ! -d "$FIXES_DIR" ]]; then
  echo "❌ Fixes dir not found: $FIXES_DIR"
  exit 1
fi

if [[ ! -d "$CONTRIB_DIR" ]]; then
  echo "❌ Contrib language files dir not found: $CONTRIB_DIR"
  exit 1
fi

for fixfile in "$FIXES_DIR"/*; do
  fname=$(basename "$fixfile")
  target="$CONTRIB_DIR/$fname"

  if [[ -f "$target" ]]; then
    echo "🔧 Appending $fname → $target"
    echo -e "\n\n# --- BEGIN FIXES ADDED ---\n" >> "$target"
    cat "$fixfile" >> "$target"
    echo -e "\n# --- END FIXES ADDED ---\n" >> "$target"
  else
    echo "⚠️  Skipping $fname (no matching file in $CONTRIB_DIR)"
  fi
done

echo "✅ Language fixes applied."
