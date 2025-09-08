#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# Config
# ----------------------
BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR="$BASEDIR/out/nsis"
VERSION=${VERSION:-3.11}

BUNDLE_DIR="$OUT_DIR/nsis-bundle"

# Start fresh
rm -rf "$BUNDLE_DIR/mac" "$BUNDLE_DIR/share"
mkdir -p "$BUNDLE_DIR/mac/bin" "$BUNDLE_DIR/share"

echo "🍎 Installing dependencies..."
xcode-select --install 2>/dev/null || true
brew install -q p7zip
brew tap nsis-dev/makensis

# Install NSIS via Homebrew if not already present
if ! brew list "makensis@$VERSION" >/dev/null 2>&1; then
  brew install "makensis@$VERSION"
fi

# ----------------------
# Copy macOS makensis binary
# ----------------------
echo "📦 Copying macOS makensis binary..."
cp -aL "$(which makensis)" "$BUNDLE_DIR/mac/bin/makensis"

# ----------------------
# Copy share/nsis data tree
# ----------------------
echo "📂 Copying share/nsis data..."
CELLAR="$(brew --cellar makensis@$VERSION)"
cp -a "$CELLAR/$VERSION/share/nsis" "$BUNDLE_DIR/share/"

cat > "${BUNDLE_DIR}/makensis" <<'EOF'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export NSISDIR="$DIR/share/nsis"
case "$(uname -s)" in
  Linux)  exec "$DIR/linux/bin/makensis" "$@" ;;
  Darwin) exec "$DIR/mac/bin/makensis" "$@" ;;
  *) echo "Unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac
EOF
chmod +x "${BUNDLE_DIR}/makensis"

echo "✅ macOS makensis and share/nsis added to bundle:"
echo "   $BUNDLE_DIR"
