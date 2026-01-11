#!/bin/bash
set -e

ARCH="${1:-$(uname -m | sed 's/x86_64/x64/')}"
ELECTRON_VERSION="${2:?Electron version required}"
BASE_DIR="${3:-$(cd "$(dirname "$0")/../.." && pwd)}"

OUT_DIR="$BASE_DIR/electron/v$ELECTRON_VERSION"
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

URL="https://github.com/electron/electron/releases/download/v$ELECTRON_VERSION/electron-v$ELECTRON_VERSION-linux-$ARCH.zip"

echo "Downloading Electron v$ELECTRON_VERSION..."
curl -L -o electron.zip "$URL"

echo "Extracting..."
unzip -q electron.zip
rm electron.zip

chmod +x electron

echo "Recording version..."
echo "v$ELECTRON_VERSION" > version.txt

echo "Generating checksums..."
sha256sum electron LICENSE version.txt > SHA256SUMS

echo "✓ Electron v$ELECTRON_VERSION pinned"
