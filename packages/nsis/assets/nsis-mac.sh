#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# macOS NSIS Builder
# =============================================================================
# Builds native macOS makensis binary with complete plugin support
# =============================================================================

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR="$BASEDIR/out/nsis"
VERSION=${NSIS_VERSION:-3.11}
BUNDLE_DIR="$OUT_DIR/nsis-bundle"

echo "🍎 Building NSIS for macOS..."

# Start fresh
rm -rf "$BUNDLE_DIR/mac" "$BUNDLE_DIR/share"
mkdir -p "$BUNDLE_DIR/mac" "$BUNDLE_DIR/share"

# =============================================================================
# Install Dependencies
# =============================================================================

echo "📦 Installing dependencies..."

# Check for Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "⚠️  Please complete Xcode installation and run this script again."
    exit 1
fi

# Install Homebrew packages
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is required but not installed."
    echo "Install from: https://brew.sh"
    exit 1
fi

brew install -q p7zip 2>/dev/null || true
brew tap nsis-dev/makensis 2>/dev/null || true

# Install NSIS via Homebrew
if ! brew list "makensis@$VERSION" &> /dev/null; then
    echo "Installing makensis@$VERSION..."
    brew install "makensis@$VERSION"
else
    echo "✓ makensis@$VERSION already installed"
fi

# =============================================================================
# Copy macOS Binary
# =============================================================================

echo "📦 Copying macOS makensis binary..."
MAKENSIS_PATH=$(brew --prefix "makensis@$VERSION")/bin/makensis

if [ ! -f "$MAKENSIS_PATH" ]; then
    # Fallback to generic makensis
    MAKENSIS_PATH=$(which makensis)
fi

cp -aL "$MAKENSIS_PATH" "$BUNDLE_DIR/mac/makensis"
chmod +x "$BUNDLE_DIR/mac/makensis"

# Verify binary
echo "✓ Binary: $("$BUNDLE_DIR/mac/makensis" -VERSION 2>&1 | head -1)"

# =============================================================================
# Copy NSIS Data Tree
# =============================================================================

echo "📂 Copying share/nsis data..."
CELLAR=$(brew --cellar "makensis@$VERSION")

if [ ! -d "$CELLAR/$VERSION/share/nsis" ]; then
    echo "❌ NSIS data directory not found at $CELLAR/$VERSION/share/nsis"
    exit 1
fi

cp -a "$CELLAR/$VERSION/share/nsis" "$BUNDLE_DIR/share/"

# Clean unnecessary files
rm -rf "$BUNDLE_DIR/share/nsis/.git" \
       "$BUNDLE_DIR/share/nsis/Docs" \
       "$BUNDLE_DIR/share/nsis/Examples"

# =============================================================================
# Download and Install Extra Plugins
# =============================================================================

echo "🔌 Installing additional plugins..."
cd "$BUNDLE_DIR/share/nsis"

# Create temp directory for downloads
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

download_plugin() {
    local name=$1
    local url=$2
    local zip_file="$TEMP_DIR/${name}.zip"
    
    echo "  → $name"
    curl -sL "$url" -o "$zip_file"
    
    if [ ! -f "$zip_file" ]; then
        echo "    ⚠️  Failed to download $name"
        return 1
    fi
    
    7z x "$zip_file" -o"$TEMP_DIR/${name}" &> /dev/null || {
        echo "    ⚠️  Failed to extract $name"
        return 1
    }
}

install_plugin_files() {
    local name=$1
    local extract_dir="$TEMP_DIR/${name}"
    
    # Find and copy DLL files
    if [ -d "$extract_dir" ]; then
        # Copy x86-ansi plugins
        find "$extract_dir" -name "*.dll" -path "*/x86-ansi/*" -exec cp {} Plugins/x86-ansi/ \; 2>/dev/null || true
        find "$extract_dir" -name "*.dll" -path "*/ansi/*" -exec cp {} Plugins/x86-ansi/ \; 2>/dev/null || true
        
        # Copy x86-unicode plugins
        find "$extract_dir" -name "*.dll" -path "*/x86-unicode/*" -exec cp {} Plugins/x86-unicode/ \; 2>/dev/null || true
        find "$extract_dir" -name "*.dll" -path "*/unicode/*" -exec cp {} Plugins/x86-unicode/ \; 2>/dev/null || true
        
        # Copy include files
        find "$extract_dir" -name "*.nsh" -exec cp {} Include/ \; 2>/dev/null || true
        find "$extract_dir" -name "*.nsi" -exec cp {} Include/ \; 2>/dev/null || true
    fi
}

# Essential plugins
download_plugin "nsProcess" "http://nsis.sourceforge.net/mediawiki/images/1/18/NsProcess.zip" && \
    install_plugin_files "nsProcess"

download_plugin "UAC" "http://nsis.sourceforge.net/mediawiki/images/8/8f/UAC.zip" && \
    install_plugin_files "UAC"

download_plugin "WinShell" "http://nsis.sourceforge.net/mediawiki/images/5/54/WinShell.zip" && \
    install_plugin_files "WinShell"

# Additional useful plugins
download_plugin "nsJSON" "http://nsis.sourceforge.net/mediawiki/images/5/5a/NsJSON.zip" && \
    install_plugin_files "nsJSON"

download_plugin "nsArray" "http://nsis.sourceforge.net/mediawiki/images/4/4c/NsArray.zip" && \
    install_plugin_files "nsArray"

download_plugin "INetC" "http://nsis.sourceforge.net/mediawiki/images/c/c9/Inetc.zip" && \
    install_plugin_files "INetC"

echo "✓ Plugins installed"

# =============================================================================
# Create Version Metadata
# =============================================================================

cat > "$BUNDLE_DIR/mac/VERSION.txt" <<EOF
NSIS Version: $VERSION
Build Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Platform: macOS $(sw_vers -productVersion)
Architecture: $(uname -m)
Binary: makensis
EOF

# =============================================================================
# Package Bundle
# =============================================================================

echo "📦 Creating bundle archive..."
cd "$OUT_DIR"

ARCHIVE_NAME="nsis-bundle-mac-${VERSION}.zip"
zip -r9q "$ARCHIVE_NAME" nsis-bundle

echo ""
echo "✅ macOS build complete!"
echo "📁 Bundle: $OUT_DIR/$ARCHIVE_NAME"
echo "📊 Size: $(du -h "$OUT_DIR/$ARCHIVE_NAME" | cut -f1)"
echo ""

# Verify bundle contents
echo "📋 Bundle contents:"
echo "   Binary: nsis-bundle/mac/makensis"
echo "   Data:   nsis-bundle/share/nsis/"
echo "   Plugins: $(find "$BUNDLE_DIR/share/nsis/Plugins" -name "*.dll" | wc -l | xargs) installed"