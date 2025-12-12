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

if [ "$OS" = "darwin" ]; then
    echo -e "${BLUE}Detected macOS - Building Darwin binaries...${NC}"
    echo ""
    
    if [ ! -f "$CWD/assets/appimage-mac.sh" ]; then
        echo -e "${RED}Error: appimage-mac.sh not found${NC}"
        exit 1
    fi

    bash $CWD/assets/appimage-mac.sh
    
    echo ""
    echo -e "${YELLOW}Note: To build Linux binaries, run this script on a Linux machine or use WSL${NC}"
    
elif [ "$OS" = "linux" ]; then
    echo -e "${BLUE}Detected Linux - Building Linux binaries for all architectures...${NC}"
    echo ""
    
    if [ ! -f "extract.sh" ]; then
        echo -e "${RED}Error: extract.sh not found${NC}"
        exit 1
    fi
    bash $CWD/extract.sh    
else
    echo -e "${RED}Unsupported OS: $OS${NC}"
    echo "This script supports macOS and Linux only"
    exit 1
fi

echo ""
echo -e "${BLUE}Downloading AppImage runtimes...${NC}"

# Create output directory if it doesn't exist
mkdir -p $CWD/out/AppImage

bash $CWD/download-runtime.sh

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Build Complete!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Directory structure:"
tree $CWD/out/AppImage -L 2 2>/dev/null || find $CWD/out/AppImage -maxdepth 2 -type f

echo ""
echo -e "${BLUE}Next steps:${NC}"
if [ "$OS" = "Darwin" ]; then
    echo "• Run this script on Linux to build Linux binaries"
elif [ "$OS" = "Linux" ]; then
    echo "• Run this script on macOS to build Darwin binaries"
fi
echo "• Verify all binaries are present in $CWD/out/AppImage/"
echo ""
echo -e "${GREEN}Done!${NC}"