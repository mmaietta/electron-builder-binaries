#!/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ELECTRON_DIR=$(find "$BASE_DIR/electron" -mindepth 1 -maxdepth 1 | sort | tail -1)
BIN="$ELECTRON_DIR/electron.bin"

if [ ! -x "$BIN" ]; then
  echo "❌ Electron binary not found"
  exit 1
fi

echo "Validating Electron runtime using:"
echo "  $ELECTRON_DIR"
echo "=================================="

MISSING=0

ldd "$BIN" | while read -r line; do
  if echo "$line" | grep -q "not found"; then
    echo "❌ $line"
    MISSING=1
  else
    echo "✓ $line"
  fi
done

echo "=================================="

if [ "$MISSING" -eq 1 ]; then
  echo "❌ Electron runtime incomplete"
  exit 1
fi

echo "✅ Electron runtime complete for pinned Electron"
