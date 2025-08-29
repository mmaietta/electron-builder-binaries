#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# Config
# ----------------------
BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=$BASEDIR/out/nsis
VERSION=3.11
ZLIB_VERSION=1.3.1
IMAGE_NAME="nsis-builder"
CONTAINER_NAME="nsis-build-container"
OUTPUT_TARBALL="nsis-bundle.tar.gz"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# ----------------------
# Cleanup on exit
# ----------------------
cleanup() {
  echo "🧹 Cleaning up..."
  docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# ----------------------
# Step 1: Build Docker image (Win32/Win64/Linux)
# ----------------------
echo "📦 Building Docker image..."
docker build \
  --build-arg NSIS_VERSION=$VERSION \
  --build-arg ZLIB_VERSION=$ZLIB_VERSION \
  -t ${IMAGE_NAME} .

echo "🚀 Creating container..."
docker create --name ${CONTAINER_NAME} ${IMAGE_NAME} /bin/true

echo "📂 Copying tarball from container..."
BUNDLE_FILE=$(docker run --rm ${IMAGE_NAME} bash -c "ls /out | grep '^nsis-bundle-.*\.tar\.gz$'")
docker cp ${CONTAINER_NAME}:/out/${BUNDLE_FILE} ${OUT_DIR}/${OUTPUT_TARBALL}

echo "📦 Extracting Docker-built bundle..."
tar -xzf ${OUT_DIR}/${OUTPUT_TARBALL} -C ${OUT_DIR}

# ----------------------
# Step 2: Build macOS makensis (via Homebrew)
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
zlib Version: ${ZLIB_VERSION}
Build Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# ----------------------
# Step 4: Finalize unified tarball
# ----------------------
echo "📦 Creating unified bundle..."
cd ${OUT_DIR}
tar -czf nsis-bundle-unified.tar.gz nsis-bundle

echo "✅ Done!"
echo "Bundle available at: ${OUT_DIR}/nsis-bundle-unified.tar.gz"
tree -L 3 ${OUT_DIR}/nsis-bundle || true
