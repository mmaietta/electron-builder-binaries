#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building AppImage tools for multiple architectures...${NC}"
echo ""

ROOT=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
    echo -e "${RED}Error: Docker buildx is not available${NC}"
    echo "Please install Docker buildx or use Docker Desktop which includes it"
    exit 1
fi

# Create a new builder instance if it doesn't exist
if ! docker buildx ls | grep -q appimage-builder; then
    echo -e "${BLUE}Creating buildx builder instance...${NC}"
    docker buildx create --name appimage-builder --use
fi

# Use the builder
docker buildx use appimage-builder

mkdir -p $ROOT/out/AppImage

# Build for each architecture separately and extract
PLATFORMS=("linux/amd64" "linux/386" "linux/arm64" "linux/arm/v7")
PLATFORM_NAMES=("amd64" "386" "arm64" "armv7")

for i in "${!PLATFORMS[@]}"; do
    PLATFORM="${PLATFORMS[$i]}"
    NAME="${PLATFORM_NAMES[$i]}"
    
    echo ""
    echo -e "${BLUE}Building for ${PLATFORM} (${NAME})...${NC}"
    
    # Build for specific platform and output to local directory
    DEST="./out/AppImage/${NAME}"
    docker buildx build \
        --platform "${PLATFORM}" \
        --output type=local,dest="${DEST}" \
        -f "$ROOT/assets/Dockerfile" \
        .
    
    echo -e "${BLUE}Extracting files for ${NAME}...${NC}"
    
    # Extract the tarball from build output
    if [ -f "${DEST}/appimage-tools-${NAME}.tar.gz" ]; then
        mkdir $DEST/${NAME}
        tar xzf "${DEST}/appimage-tools-${NAME}.tar.gz" -C $DEST/.
        rm "${DEST}/appimage-tools-${NAME}.tar.gz"
        echo -e "${GREEN}✓ Completed ${NAME}${NC}"
    else
        echo -e "${RED}✗ Failed to find output for ${NAME}${NC}"
        exit 1
    fi
done

echo ""
echo -e "${BLUE}Organizing directory structure...${NC}"

# Verify executables have correct permissions
echo -e "${BLUE}Verifying executable permissions...${NC}"
chmod +x $ROOT/out/AppImage/linux-x64/mksquashfs $ROOT/out/AppImage/linux-x64/desktop-file-validate 2>/dev/null || true
chmod +x $ROOT/out/AppImage/linux-x64/opj_decompress 2>/dev/null || true
chmod +x $ROOT/out/AppImage/linux-ia32/mksquashfs $ROOT/out/AppImage/linux-ia32/desktop-file-validate 2>/dev/null || true
chmod +x $ROOT/out/AppImage/linux-arm64/mksquashfs $ROOT/out/AppImage/linux-arm64/desktop-file-validate 2>/dev/null || true
chmod +x $ROOT/out/AppImage/linux-arm32/mksquashfs 2>/dev/null || true
echo ""
echo -e "${GREEN}Extraction complete!${NC}"
echo ""
echo "Directory structure:"
tree $ROOT/out/AppImage -L 3 2>/dev/null || find $ROOT/out/AppImage -type f

echo ""
echo -e "${GREEN}Done!${NC}"
docker buildx rm appimage-builder