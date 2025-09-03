#!/usr/bin/env bash
set -euo pipefail

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR="$BASEDIR/out/nsis"
UNIFIED_DIR="$OUT_DIR/nsis-bundle"
FINAL_7Z="$OUT_DIR/nsis-bundle-unified.7z"

mkdir -p "$OUT_DIR"
rm -rf "$UNIFIED_DIR" "$FINAL_7Z"

DOCKER_BUNDLE=$(ls "$OUT_DIR"/nsis-bundle-win-linux-*.7z | head -n1 || true)
MAC_BUNDLE=$(ls "$OUT_DIR"/nsis-bundle-mac-*.7z | head -n1 || true)

if [[ -z "$DOCKER_BUNDLE" || -z "$MAC_BUNDLE" ]]; then
  echo "❌ Missing one or both bundles."
  exit 1
fi

# temp dirs
TMP_DOCKER=$(mktemp -d)
TMP_MAC=$(mktemp -d)

# extract
7z x -y -o"$TMP_DOCKER" "$DOCKER_BUNDLE" >/dev/null
7z x -y -o"$TMP_MAC" "$MAC_BUNDLE" >/dev/null

mkdir -p "$UNIFIED_DIR"

# copy contents (flatten if nsis-bundle/ folder exists)
if [[ -d "$TMP_DOCKER/nsis-bundle" ]]; then
  cp -a "$TMP_DOCKER/nsis-bundle/." "$UNIFIED_DIR/"
else
  cp -a "$TMP_DOCKER/." "$UNIFIED_DIR/"
fi

if [[ -d "$TMP_MAC/nsis-bundle" ]]; then
  cp -a "$TMP_MAC/nsis-bundle/." "$UNIFIED_DIR/"
else
  cp -a "$TMP_MAC/." "$UNIFIED_DIR/"
fi

# repack unified bundle
cd "$OUT_DIR"
rm -f "$FINAL_7Z"
7z a -mx=9 "$FINAL_7Z" "nsis-bundle" >/dev/null

# cleanup temps and old bundles
rm -rf "$TMP_DOCKER" "$TMP_MAC"
rm -f "$DOCKER_BUNDLE" "$MAC_BUNDLE"

echo "✅ Unified bundle created at: $FINAL_7Z"
command -v tree >/dev/null 2>&1 && tree -L 3 "$UNIFIED_DIR" || true
