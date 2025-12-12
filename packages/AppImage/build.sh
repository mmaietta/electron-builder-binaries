#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  AppImage Tools Build Script          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Detect OS
CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
OS=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

# Create output directory if it doesn't exist
mkdir -p $CWD/out/AppImage

if [ "$OS" = "darwin" ]; then
    echo -e "${BLUE}Detected macOS - Building Darwin binaries...${NC}"
    echo ""
    
    if [ ! -f "$CWD/assets/appimage-mac.sh" ]; then
        echo -e "${RED}Error: appimage-mac.sh not found${NC}"
        exit 1
    fi
    
    bash $CWD/assets/appimage-mac.sh    
elif [ "$OS" = "linux" ]; then
    echo -e "${BLUE}Detected Linux - Building Linux binaries for all architectures...${NC}"
    echo ""
    
    if [ ! -f "$CWD/assets/appimage-linux.sh" ]; then
        echo -e "${RED}Error: appimage-linux.sh not found${NC}"
        exit 1
    fi
    bash $CWD/assets/appimage-linux.sh
else
    echo -e "${BLUE}Downloading AppImage runtimes...${NC}"
    
    bash $CWD/assets/download-runtime.sh
fi


echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Build Complete!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Directory structure:"
tree $CWD/out/AppImage -L 2 2>/dev/null || find $CWD/out/AppImage -maxdepth 2 -type f

echo ""
echo -e "${GREEN}Done!${NC}"