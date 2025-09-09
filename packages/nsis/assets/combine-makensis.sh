#!/usr/bin/env bash
set -euo pipefail

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=$BASEDIR/out/nsis
VERSION=${VERSION:-v311}
ZLIB_VERSION=${ZLIB_VERSION:-1.3.1}

mkdir -p "$OUT_DIR"

echo "Adding patches to language files"

bash "$BASEDIR/assets/patch-language-files.sh"

echo "📝 Writing version metadata..."
{
  echo "NSIS Version/Branch: ${VERSION}"
  echo "zlib Version: ${ZLIB_VERSION}"
  echo "Build Date (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Platforms Included:"
  [ -d "${OUT_DIR}/nsis-bundle/linux" ]  && echo "  - linux"
  [ -d "${OUT_DIR}/nsis-bundle/win32" ]  && echo "  - win32"
  [ -d "${OUT_DIR}/nsis-bundle/win64" ]  && echo "  - win64"
  [ -d "${OUT_DIR}/nsis-bundle/mac" ]    && echo "  - macos"
} > "${OUT_DIR}/nsis-bundle/VERSION.txt"

# Build archive name dynamically
PLATFORMS=()
[ -d "${OUT_DIR}/nsis-bundle/linux" ] && PLATFORMS+=("linux")
[ -d "${OUT_DIR}/nsis-bundle/win32" ] && PLATFORMS+=("win32")
[ -d "${OUT_DIR}/nsis-bundle/win64" ] && PLATFORMS+=("win64")
[ -d "${OUT_DIR}/nsis-bundle/mac" ]   && PLATFORMS+=("macos")

PLATFORM_STR=$(IFS=-; echo "${PLATFORMS[*]}")
ARCHIVE_NAME="nsis-bundle-${PLATFORM_STR}-${VERSION}.7z"

echo "📦 Creating final archive $ARCHIVE_NAME..."
cd "${OUT_DIR}"
rm -f "$ARCHIVE_NAME"
7za a -mx=9 -mfb=64 "$ARCHIVE_NAME" nsis-bundle
rm -rf "${OUT_DIR}/nsis-bundle"

echo "✅ Done!"
echo "Bundle available at: ${OUT_DIR}/$ARCHIVE_NAME"
