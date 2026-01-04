#!/usr/bin/env bash
set -euo pipefail

# ----------------------
# Config
# ----------------------
BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR="$BASEDIR/out/nsis"
VERSION=${NSIS_VERSION:-3.11}

BUNDLE_DIR="$OUT_DIR/nsis-bundle"

# Start fresh
rm -rf "$BUNDLE_DIR/mac" "$BUNDLE_DIR/share"
mkdir -p "$BUNDLE_DIR/mac" "$BUNDLE_DIR/share"

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
cp -aL "$(which makensis)" "$BUNDLE_DIR/mac/makensis"

# ----------------------
# Copy share/nsis data tree
# ----------------------
echo "📂 Copying share/nsis data..."
CELLAR="$(brew --cellar makensis@$VERSION)"
cp -a "$CELLAR/$VERSION/share/nsis" "$BUNDLE_DIR/share/"
rm -rf "$BUNDLE_DIR/share/nsis/.git" "$BUNDLE_DIR/share/nsis/Docs" "$BUNDLE_DIR/share/nsis/Examples"

# ----------------------
# Add extra plugins (nsProcess, UAC, WinShell)
# ----------------------
echo "🔌 Adding extra plugins (nsProcess, UAC, WinShell)..."
cd $BUNDLE_DIR/share/nsis

# nsProcess
curl -sL http://nsis.sourceforge.net/mediawiki/images/1/18/NsProcess.zip -o np.zip
7z x np.zip -oa
mv a/Plugin/nsProcess.dll   Plugins/x86-ansi/nsProcess.dll
mv a/Plugin/nsProcessW.dll  Plugins/x86-unicode/nsProcess.dll
mv a/Include/nsProcess.nsh  Include/nsProcess.nsh
rm -rf a np.zip

# UAC
curl -sL http://nsis.sourceforge.net/mediawiki/images/8/8f/UAC.zip -o uac.zip
7z x uac.zip -oa
mv a/Plugins/x86-ansi/UAC.dll     Plugins/x86-ansi/UAC.dll
mv a/Plugins/x86-unicode/UAC.dll  Plugins/x86-unicode/UAC.dll
mv a/UAC.nsh                      Include/UAC.nsh
rm -rf a uac.zip

# WinShell
curl -sL http://nsis.sourceforge.net/mediawiki/images/5/54/WinShell.zip -o ws.zip
7z x ws.zip -oa
mv a/Plugins/x86-ansi/WinShell.dll     Plugins/x86-ansi/WinShell.dll
mv a/Plugins/x86-unicode/WinShell.dll  Plugins/x86-unicode/WinShell.dll
rm -rf a ws.zip

# ----------------------
# Package up the macOS bundle with contents for NSISDIR heirarchy
# ----------------------
cd "${OUT_DIR}"
zip -r9 "${OUT_DIR}/nsis-bundle-mac-${VERSION}.zip" nsis-bundle

echo "✅ macOS makensis and share/nsis added to bundle:"
echo "   $BUNDLE_DIR"
