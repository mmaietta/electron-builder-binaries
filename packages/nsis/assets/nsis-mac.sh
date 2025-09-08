#!/usr/bin/env bash
set -euo pipefail

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=$BASEDIR/out/nsis
VERSION=${VERSION:-3.11}

mkdir -p "$OUT_DIR"

echo "⚒️ Installing dependencies..."
xcode-select --install 2>/dev/null || true
brew install -q p7zip || true

echo "🍎 Preparing macOS makensis..."
MAC_TMP=/tmp/nsis-mac
rm -rf "$MAC_TMP"
mkdir -p "$MAC_TMP"

brew tap nsis-dev/makensis || true
brew install "makensis@$VERSION" --with-large-strings --with-advanced-logging || true

BREW_PREFIX=$(brew --prefix "makensis@$VERSION")

# Binary
mkdir -p "$MAC_TMP/bin"
cp -aL "$BREW_PREFIX/bin/makensis" "$MAC_TMP/bin/makensis"

# Resources
mkdir -p "$MAC_TMP/share/nsis"
cp -aR "$BREW_PREFIX/share/nsis/"* "$MAC_TMP/share/nsis/"

# Wrapper
cat > "$MAC_TMP/makensis-macos" <<'EOF'
#!/bin/bash
HERE="$(cd "$(dirname "$0")" && pwd)"
export NSISDIR="$HERE/share/nsis"
exec "$HERE/bin/makensis" "$@"
EOF
chmod +x "$MAC_TMP/makensis-macos"

# Stage for combine
mkdir -p "${OUT_DIR}/nsis-bundle/mac"
cp -a "$MAC_TMP/"* "${OUT_DIR}/nsis-bundle/mac/"
