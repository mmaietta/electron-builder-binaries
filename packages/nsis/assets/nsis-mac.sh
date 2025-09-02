#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# Config
# ----------------------
BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=$BASEDIR/out/nsis
VERSION=3.11
IMAGE_NAME="nsis-builder"
CONTAINER_NAME="nsis-build-container"
OUTPUT_TARBALL="nsis-bundle.tar.gz"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "  ⚒️ Installing dependencies..."
xcode-select --install 2>/dev/null || true
brew install -q p7zip


# ----------------------
echo "🍎 Building macOS makensis..."
MAC_TMP=/tmp/nsis-mac
rm -rf $MAC_TMP
mkdir -p $MAC_TMP/mac

brew tap nsis-dev/makensis
brew install makensis@$VERSION --with-large-strings --with-advanced-logging || true

cp -aL "$(which makensis)" $MAC_TMP/mac/makensis

# Copy into unified bundle
mkdir -p ${OUT_DIR}/nsis-bundle/mac
cp -a $MAC_TMP/* ${OUT_DIR}/nsis-bundle/mac/

# ----------------------
# Step 3: Write VERSION.txt
# ----------------------
echo "📝 Writing version metadata..."
cat > ${OUT_DIR}/nsis-bundle/VERSION.txt <<EOF
NSIS Version: ${VERSION}
Build Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# ----------------------
# Step 4: Finalize unified tarball
# ----------------------
echo "📦 Creating unified bundle..."
cd ${OUT_DIR}
7za a -mx=9 -mfb=64 nsis-bundle-unified.7z nsis-bundle

echo "✅ Done!"
echo "Bundle available at: ${OUT_DIR}/nsis-bundle-unified.7z"
tree -L 4 ${OUT_DIR}/nsis-bundle || true
