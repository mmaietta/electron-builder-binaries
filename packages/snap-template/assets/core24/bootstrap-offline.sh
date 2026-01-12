#!/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="core24"
BASE_DIR_FULL="$BASE_DIR/build/$BASE/electron-runtime-template/base"

echo "Installing pinned base: $BASE"

cd "$BASE_DIR_FULL"

echo "Verifying checksums..."
sha256sum -c SHA256SUMS

echo "Installing assertion..."
sudo snap ack *.assert

echo "Installing snap..."
sudo snap install *.snap

echo "✓ $BASE installed successfully"
