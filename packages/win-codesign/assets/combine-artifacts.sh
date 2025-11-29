#!/usr/bin/env bash
set -euo pipefail

# Set these environment variables in GHA build-wincodesign.yaml
OSSLSIGNCODE_VER="${OSSLSIGNCODE_VER:-setenvvalue-unknown}"
RCEDIT_VERSION="${RCEDIT_VERSION:-setenvvalue-unknown}"

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=$BASEDIR/out
BUNDLE_DIR="$OUT_DIR/win-codesign"

# ----------------------
echo "🧹 Cleaning up old merge..."
rm -rf "$BUNDLE_DIR"


# ----------------------
# Verify
# ----------------------
echo "📂 Final nsis-bundle structure:"
if command -v tree >/dev/null 2>&1; then
  tree -L 3 "$BUNDLE_DIR"
else
  ls -R "$BUNDLE_DIR"
fi

echo "✅ Done! Combined bundle is at $BUNDLE_DIR"

# ----------------------
# Write version metadata
# ----------------------
echo "📝 Writing version metadata..."
{
  echo "osslsigncode Version: ${OSSLSIGNCODE_VER}"
  echo "rcedit Version: ${RCEDIT_VERSION}"
  echo "Windows Kits: $(cat "${BUNDLE_DIR}"/*/VERSION.txt | tr '\n' ' ')"
  echo "Packaging Date (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} > "${BUNDLE_DIR}/VERSION.txt"

# ----------------------
# Create final archive
# ----------------------
ARCHIVE_NAME="win-codesign-bundle-${OSSLSIGNCODE_VER}-${RCEDIT_VERSION}.zip"

echo "📦 Creating final archive $ARCHIVE_NAME..."
cd "${OUT_DIR}"
rm -f "$ARCHIVE_NAME"
# ensure win-codesign contents are at top-level in the zip
zip -r -9 "$ARCHIVE_NAME" win-codesign/*
rm -rf "${BUNDLE_DIR}"

echo "✅ Done!"
echo "Bundle available at: ${OUT_DIR}/$ARCHIVE_NAME"