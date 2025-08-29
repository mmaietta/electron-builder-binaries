#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# Config
# ----------------------
IMAGE_NAME="nsis-builder"
CONTAINER_NAME="nsis-build-container"
OUTPUT_TARBALL="nsis-bundle.tar.gz"

# ----------------------
# Build Docker image
# ----------------------
echo "📦 Building Docker image..."
docker build -t ${IMAGE_NAME} .

# ----------------------
# Create temporary container
# ----------------------
echo "🚀 Creating container..."
docker create --name ${CONTAINER_NAME} ${IMAGE_NAME} /bin/true

# ----------------------
# Copy bundle tarball
# ----------------------
echo "📂 Copying tarball from container..."
docker cp ${CONTAINER_NAME}:/out/$(docker run --rm ${IMAGE_NAME} bash -c "ls /out | grep '^nsis-bundle-.*\.tar\.gz$'") ./${OUTPUT_TARBALL}

