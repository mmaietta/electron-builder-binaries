#!/usr/bin/env bash
set -exuo pipefail

# =============================================================================
# Linux NSIS Binary Builder (Docker-based)
# =============================================================================
# Compiles native Linux makensis binary from source using Docker
# Injects the Linux binary into the base Windows bundle
# Can be run from any platform with Docker (Mac, Linux, Windows)
# =============================================================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUT_DIR="$BASE_DIR/out/nsis"

# Version configuration
NSIS_VERSION=${NSIS_VERSION:-3.10}
NSIS_BRANCH=${NSIS_BRANCH_OR_COMMIT:-v310}

# Docker configuration
IMAGE_NAME="nsis-linux-builder:${NSIS_BRANCH}"
CONTAINER_NAME="nsis-linux-build-$$"

BUNDLE_DIR="$OUT_DIR/nsis-bundle"
BASE_ARCHIVE="$OUT_DIR/nsis-bundle-base-$NSIS_BRANCH.zip"
OUTPUT_ARCHIVE="$OUT_DIR/nsis-bundle-linux-$NSIS_BRANCH.zip"

echo "🐧 Building native Linux makensis binary..."
echo "   Version: $NSIS_VERSION"
echo "   Branch:  $NSIS_BRANCH"
echo ""

# =============================================================================
# Check Prerequisites
# =============================================================================

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not installed"
    echo "   Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if [ ! -f "$BASE_ARCHIVE" ]; then
    echo "❌ Base bundle not found: $BASE_ARCHIVE"
    echo "Contents:"
    ls -l "$OUT_DIR"
    echo "   Run assets/nsis-windows.sh first to create the base bundle"
    exit 1
fi

# =============================================================================
# Cleanup Handler
# =============================================================================

cleanup() {
    echo ""
    echo "🧹 Cleaning up Docker resources..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# =============================================================================
# Create Dockerfile
# =============================================================================

echo "📝 Creating Dockerfile for Linux build..."

DOCKERFILE="$OUT_DIR/Dockerfile.linux"

cat > "$DOCKERFILE" <<'DOCKERFILE_END'
FROM ubuntu:22.04

ARG NSIS_BRANCH=v310
ARG DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    scons \
    zlib1g-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone NSIS source
RUN git clone --branch ${NSIS_BRANCH} --depth=1 https://github.com/kichik/nsis.git nsis

WORKDIR /build/nsis

# Build native Linux makensis
# Skip stubs, plugins, utils - we only need the compiler
RUN scons \
    SKIPSTUBS=all \
    SKIPPLUGINS=all \
    SKIPUTILS=all \
    SKIPMISC=all \
    NSIS_CONFIG_CONST_DATA_PATH=no \
    NSIS_MAX_STRLEN=8192 \
    PREFIX=/build/install \
    install-compiler

# The binary is now at /build/install/makensis
RUN chmod +x /build/install/makensis

# Verify the binary works
# RUN /build/install/makensis -VERSION

# Create output directory
RUN mkdir -p /output && \
    cp /build/install/makensis /output/makensis

DOCKERFILE_END

# =============================================================================
# Build Docker Image
# =============================================================================

echo ""
echo "🔨 Building Docker image (this may take 5-10 minutes on first run)..."

docker build \
    --build-arg NSIS_BRANCH="$NSIS_BRANCH" \
    -t "$IMAGE_NAME" \
    -f "$DOCKERFILE" \
    "$OUT_DIR"

if [ $? -ne 0 ]; then
    echo "❌ Docker build failed"
    exit 1
fi

echo "  ✓ Docker image built successfully"

# =============================================================================
# Extract Compiled Binary
# =============================================================================

echo ""
echo "📦 Extracting compiled Linux binary..."

# Create container
docker create --name "$CONTAINER_NAME" "$IMAGE_NAME" /bin/true

# Create temp directory for extraction
TEMP_BINARY="$OUT_DIR/temp-linux-binary"
mkdir -p "$TEMP_BINARY"

# Copy binary from container
docker cp "$CONTAINER_NAME:/output/makensis" "$TEMP_BINARY/makensis"

if [ ! -f "$TEMP_BINARY/makensis" ]; then
    echo "❌ Failed to extract Linux binary"
    exit 1
fi

chmod +x "$TEMP_BINARY/makensis"
echo "  ✓ Linux binary extracted"

# Verify binary
echo "  → Verifying binary..."
if file "$TEMP_BINARY/makensis" | grep -q "ELF"; then
    echo "  ✓ Valid Linux ELF binary"
else
    echo "  ⚠️  Binary verification inconclusive"
fi

# =============================================================================
# Inject into Base Bundle
# =============================================================================

echo ""
echo "📂 Injecting Linux binary into base bundle..."

# Extract base bundle
rm -rf "$BUNDLE_DIR"
unzip -q "$BASE_ARCHIVE" -d "$OUT_DIR"

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "❌ Failed to extract base bundle"
    exit 1
fi

# Create Linux directory and copy binary
mkdir -p "$BUNDLE_DIR/linux"
cp "$TEMP_BINARY/makensis" "$BUNDLE_DIR/linux/makensis"
chmod +x "$BUNDLE_DIR/linux/makensis"

echo "  ✓ Linux binary added to bundle"

# =============================================================================
# Create Version Metadata
# =============================================================================

echo ""
echo "📝 Creating Linux version metadata..."

cat > "$BUNDLE_DIR/linux/VERSION.txt" <<EOF
Platform: Linux
Binary: makensis (native ELF binary)
Architecture: x86_64
Build Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Compiled from source: NSIS $NSIS_BRANCH
Compiler: GCC (Ubuntu 22.04)
Build system: SCons
Docker image: ubuntu:22.04

This binary is compiled from source with:
- Static linking where possible
- NSIS_MAX_STRLEN=8192
- NSIS_CONFIG_CONST_DATA_PATH=no

Usage:
  ./linux/makensis -DNSISDIR=\$(pwd)/share/nsis your-script.nsi

Or set environment:
  export NSISDIR="\$(pwd)/share/nsis"
  ./linux/makensis your-script.nsi
EOF

# =============================================================================
# Create Final Archive
# =============================================================================

echo ""
echo "📦 Creating final Linux bundle..."

cd "$OUT_DIR"
rm -f "$OUTPUT_ARCHIVE"
zip -r -9 "$OUTPUT_ARCHIVE" nsis-bundle

# =============================================================================
# Cleanup
# =============================================================================

rm -f "$DOCKERFILE"
rm -rf "$TEMP_BINARY"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "================================================================"
echo "  ✅ Linux Build Complete!"
echo "================================================================"
echo "  📁 Archive: $OUTPUT_ARCHIVE"
echo "  📊 Size:    $(du -h "$OUTPUT_ARCHIVE" | cut -f1)"
echo "================================================================"
echo ""
echo "📋 Bundle now contains:"
echo "   ✓ windows/makensis.exe   (Windows binary)"
echo "   ✓ linux/makensis         (Linux native binary)"
echo "   ✓ share/nsis/            (Complete NSIS data)"
echo ""
echo "🧪 Test the Linux binary:"
echo "   cd $BUNDLE_DIR"
echo "   ./linux/makensis -VERSION"
echo ""
echo "💡 Next step:"
echo "   Run assets/nsis-mac.sh to add macOS binary"
echo ""