#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_NAME="win-codesign-bundle.zip"

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=$BASEDIR/out
BUNDLE_DIR="$OUT_DIR/win-codesign"

# ----------------------
echo "🧹 Cleaning up old merge..."
rm -f "${OUT_DIR}/$ARCHIVE_NAME"

# ----------------------
# Verify
# ----------------------
echo "📂 Final win-codesign-bundle structure:"
if command -v tree >/dev/null 2>&1; then
  tree -L 3 "$BUNDLE_DIR"
else
  ls -R "$BUNDLE_DIR"
fi

echo "✅ Combined bundle is at $BUNDLE_DIR"

# ----------------------
# Write version metadata
# ----------------------
echo "📝 Writing version metadata..."
ROOT_VERSION_FILE="$BUNDLE_DIR/VERSION.txt"

# Empty or create the root VERSION.txt
: > "$ROOT_VERSION_FILE"
# Find all VERSION.txt files except any at root
find "$BUNDLE_DIR" -type f -name "VERSION.txt" ! -path "$ROOT_VERSION_FILE" -print0 | sort -z |
while IFS= read -r -d '' version_file; do
  rel_path="${version_file#$BUNDLE_DIR/}"
  version_dir=$(dirname "$rel_path")
  echo "Adding version info from $rel_path"
  echo "[$version_dir]" >> "$ROOT_VERSION_FILE"
  cat "$version_file" >> "$ROOT_VERSION_FILE"
  echo "" >> "$ROOT_VERSION_FILE"
done

# ----------------------
# Create final archive
# ----------------------

echo "📦 Creating final archive $ARCHIVE_NAME..."
cd "${OUT_DIR}"
# ensure win-codesign contents are at top-level in the zip
zip -r -9 "$ARCHIVE_NAME" win-codesign/*
rm -rf "${BUNDLE_DIR}"

echo "✅ Done!"
echo "Bundle available at: ${OUT_DIR}/$ARCHIVE_NAME"