#!/usr/bin/env bash
set -e

# Wine Linux Build Script (Docker)

WINE_VERSION=${WINE_VERSION:-11.0}
BUILD_DIR=${BUILD_DIR:-$(pwd)/build}
PLATFORM_ARCH=${PLATFORM_ARCH:-x86_64}

# Wine checksums - bash 3.2 compatible
get_checksum() {
    case "$1" in
        11.0) echo "c07a6857933c1fc60dff5448d79f39c92481c1e9db5aa628db9d0358446e0701" ;;
        9.0) echo "7cf3c0efea78abcda4c91cc02cfaead7ec142120d9d49a33bbe3d0faf151ea71" ;;
        *) echo "" ;;
    esac
}

CHECKSUM=$(get_checksum "$WINE_VERSION")
WINE_MAJOR=$(echo "$WINE_VERSION" | cut -d. -f1)
WINE_URL="https://dl.winehq.org/wine/source/${WINE_MAJOR}.0/wine-${WINE_VERSION}.tar.xz"

# Map architecture
case "$PLATFORM_ARCH" in
    x86_64) DOCKER_PLATFORM="linux/amd64" ;;
    amd64) DOCKER_PLATFORM="linux/amd64" ;;
    arm64) DOCKER_PLATFORM="linux/arm64" ;;
    aarch64) DOCKER_PLATFORM="linux/arm64" ;;
esac

DOWNLOAD_DIR="$BUILD_DIR/downloads"
DOCKER_DIR="$BUILD_DIR/docker-build"
OUTPUT_DIR="$BUILD_DIR/wine-${WINE_VERSION}-linux-${PLATFORM_ARCH}"

mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$DOCKER_DIR"

# Check Docker
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Setup buildx
BUILDER_NAME="wine-builder"
if ! docker buildx ls | grep -q "$BUILDER_NAME"; then
    echo "🔧 Setting up Docker buildx..."
    docker buildx create --name "$BUILDER_NAME" --use > /dev/null
fi
docker buildx use "$BUILDER_NAME"
docker buildx inspect --bootstrap > /dev/null 2>&1

# Download Wine source
ARCHIVE="$DOWNLOAD_DIR/wine-${WINE_VERSION}.tar.xz"
if [ ! -f "$ARCHIVE" ]; then
    echo "📥 Downloading Wine ${WINE_VERSION}..."
    curl -L --progress-bar "$WINE_URL" -o "$ARCHIVE"
    
    if [ -n "$CHECKSUM" ]; then
        echo "🔍 Verifying checksum..."
        ACTUAL=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
        if [ "$ACTUAL" != "$CHECKSUM" ]; then
            echo "❌ Checksum mismatch!"
            echo "   Expected: $CHECKSUM"
            echo "   Got:      $ACTUAL"
            exit 1
        fi
        echo "✅ Checksum verified"
    fi
fi

# Copy to Docker context
cp "$ARCHIVE" "$DOCKER_DIR/"

# Create Dockerfile
cat > "$DOCKER_DIR/Dockerfile" << 'DOCKERFILE_EOF'
FROM ubuntu:22.04 as builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential gcc-multilib g++-multilib mingw-w64 flex bison \
    libfreetype6-dev libgnutls28-dev libpng-dev libjpeg-dev libtiff-dev \
    liblcms2-dev libxml2-dev libxslt1-dev libopenal-dev libsdl2-dev \
    liblzma-dev libfaudio-dev libx11-dev libxext-dev && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /build
COPY wine-*.tar.xz .
RUN tar -xJf wine-*.tar.xz && mv wine-*/ wine-src/
RUN mkdir wine64-build && cd wine64-build && \
    ../wine-src/configure --prefix=/wine-install --enable-win64 && \
    make -j$(nproc) && make install

FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    libfreetype6 libgnutls30 libpng16-16 libjpeg8 libtiff5 liblcms2-2 \
    libxml2 libxslt1.1 libopenal1 libsdl2-2.0-0 liblzma5 libfaudio0 \
    libx11-6 libxext6 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /wine-install /wine
ENV PATH="/wine/bin:${PATH}" LD_LIBRARY_PATH="/wine/lib64:/wine/lib"
WORKDIR /wine
DOCKERFILE_EOF

# Build Docker image
echo "🐳 Building Docker image for $DOCKER_PLATFORM..."
echo "   (this takes 30-60 minutes)..."
DOCKER_IMAGE="wine-builder:${WINE_VERSION}-${PLATFORM_ARCH}"

docker buildx build \
    --platform "$DOCKER_PLATFORM" \
    --tag "$DOCKER_IMAGE" \
    --load \
    "$DOCKER_DIR" > /dev/null

echo "✅ Docker image built"

# Extract Wine
echo "📦 Extracting Wine from Docker..."
mkdir -p "$OUTPUT_DIR"
CONTAINER_ID=$(docker create "$DOCKER_IMAGE")
docker cp "$CONTAINER_ID:/wine/." "$OUTPUT_DIR/"
docker rm "$CONTAINER_ID" > /dev/null

# Initialize Wine prefix
echo "🍇 Initializing Wine prefix..."
WINE_PREFIX_DIR="$OUTPUT_DIR/wine-home"
mkdir -p "$WINE_PREFIX_DIR"
docker run --rm -v "$WINE_PREFIX_DIR:/wine-home" -e WINEPREFIX=/wine-home \
    "$DOCKER_IMAGE" wine64 wineboot --init 2>&1 | grep -v "fixme:" | head -5 || true
sleep 3
docker run --rm -v "$WINE_PREFIX_DIR:/wine-home" -e WINEPREFIX=/wine-home \
    "$DOCKER_IMAGE" wineserver -k 2>/dev/null || true

# Create launcher
cat > "$OUTPUT_DIR/wine-launcher.sh" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export WINEPREFIX="${WINEPREFIX:-$SCRIPT_DIR/wine-home}"
export WINEDEBUG="${WINEDEBUG:--all}"
export LD_LIBRARY_PATH="$SCRIPT_DIR/lib64:$SCRIPT_DIR/lib:${LD_LIBRARY_PATH:-}"
exec "$SCRIPT_DIR/bin/wine64" "$@"
EOF
chmod +x "$OUTPUT_DIR/wine-launcher.sh"

# Create README
cat > "$OUTPUT_DIR/README.md" << EOF
# Wine ${WINE_VERSION} - Linux ${PLATFORM_ARCH}

## Usage

\`\`\`bash
./wine-launcher.sh your-app.exe
./wine-launcher.sh notepad
./wine-launcher.sh winecfg
\`\`\`

## Directory Structure

- \`bin/\` - Wine executables
- \`lib64/\` - Wine libraries
- \`share/wine/\` - Wine data files
- \`wine-home/\` - Wine prefix (Windows C: drive)
- \`wine-launcher.sh\` - Launcher script

Built on $(date) using Docker
EOF

# Create archive
echo "🗜️  Creating archive..."
cd "$BUILD_DIR"
tar -czf "wine-${WINE_VERSION}-linux-${PLATFORM_ARCH}.tar.gz" "wine-${WINE_VERSION}-linux-${PLATFORM_ARCH}"

echo "✅ Linux build complete!"