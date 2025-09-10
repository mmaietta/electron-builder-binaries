#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# Config
# ----------------------
BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=$BASEDIR/out/nsis
NSIS_VERSION=${NSIS_VERSION:-3.11}
NSIS_SHA256=${NSIS_SHA256:-19e72062676ebdc67c11dc032ba80b979cdbffd3886c60b04bb442cdd401ff4b}
ZLIB_VERSION=${ZLIB_VERSION:-1.3.1}
IMAGE_NAME="nsis-builder"
CONTAINER_NAME="nsis-build-container"
OUTPUT_ARCHIVE="nsis-bundle-linux-${NSIS_VERSION}.7z"

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
docker buildx build \
  --platform linux/amd64 \
  --build-arg NSIS_VERSION=$NSIS_VERSION \
  --build-arg NSIS_SHA256=$NSIS_SHA256 \
  --build-arg ZLIB_VERSION=$ZLIB_VERSION \
  -t ${IMAGE_NAME} \
  -f "$BASEDIR/assets/Dockerfile" \
  --load .

echo "🚀 Creating container..."
docker create --name ${CONTAINER_NAME} ${IMAGE_NAME} /bin/true

echo "📂 Copying 7z archive from container..."
BUNDLE_FILE=$(docker run --rm ${IMAGE_NAME} bash -c "ls /out | grep '^nsis-bundle.*\.7z$'")
docker cp ${CONTAINER_NAME}:/out/${BUNDLE_FILE} ${OUT_DIR}/${OUTPUT_ARCHIVE}

# ----------------------
# Step 2: Extract 7z bundle
# ----------------------
echo "📦 Extracting Docker-built bundle..."
7z x -y ${OUT_DIR}/${OUTPUT_ARCHIVE} -o${OUT_DIR}

# ----------------------
# Step 3: Write VERSION.txt
# ----------------------
echo "📝 Writing version metadata..."
cat > ${OUT_DIR}/nsis-bundle/VERSION.txt <<EOF
NSIS Version: ${NSIS_VERSION}
zlib Version: ${ZLIB_VERSION}
Build Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# ----------------------
# Step 4: Finalize unified 7z bundle
# ----------------------
echo "📦 Creating unified 7z bundle..."
cd "${OUT_DIR}"
7z a -t7z nsis-bundle-win-linux-${NSIS_VERSION}.7z nsis-bundle

# cleanup temporary assets
rm -rf "${OUT_DIR}/nsis-bundle" "${OUT_DIR}/${OUTPUT_ARCHIVE}"

echo "✅ Done!"
echo "Bundle available at: ${OUT_DIR}/nsis-bundle-win-linux-${NSIS_VERSION}.7z"
