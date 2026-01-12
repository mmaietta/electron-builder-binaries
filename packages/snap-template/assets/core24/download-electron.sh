#!/bin/bash
set -e

RAW_ARCH="${1:-$(uname -m)}"
ELECTRON_VERSION="${2:?Electron version required}"
BASE_DIR="${3:-$(cd "$(dirname "$0")/../.." && pwd)}"

# Normalize Electron arch names
case "$RAW_ARCH" in
  x86_64|amd64) ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l|armv7) ARCH="armv7l" ;;
  *) 
    echo "❌ Unsupported architecture: $RAW_ARCH"
    exit 1
    ;;
esac
echo "Using Electron architecture: $ARCH"

OUT_DIR="$BASE_DIR/electron/v$ELECTRON_VERSION-$ARCH"
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

# Example download URL
ELECTRON_VERSION="v30.0.0"
URL="https://github.com/electron/electron/releases/download/$ELECTRON_VERSION/electron-$ELECTRON_VERSION-linux-$ARCH.zip"
echo "Download URL: $URL"

echo "Downloading Electron v$ELECTRON_VERSION $ARCH ..."
echo "From: $URL"
curl -L -o electron.zip "$URL"

echo "Extracting..."
unzip -q electron.zip
rm electron.zip

chmod +x electron

ldd electron | grep "not found"  # Shows missing libs
ldd electron | grep "=>" | awk '{print $3}' | xargs dpkg -S 2>/dev/null | cut -d: -f1 | sort -u

echo "Recording version..."
echo "v$ELECTRON_VERSION" > VERSION.txt

echo "Generating checksums..."
sha256sum electron LICENSE VERSION.txt > SHA256SUMS

echo "✓ Electron v$ELECTRON_VERSION pinned"
