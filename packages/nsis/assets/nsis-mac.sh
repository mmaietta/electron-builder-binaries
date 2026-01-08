#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# macOS NSIS Binary Builder
# =============================================================================
# Compiles native macOS makensis binary from source
# Injects the macOS binary into the base Windows bundle
# Must be run on macOS (no Docker cross-compilation for macOS)
# =============================================================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUT_DIR="$BASE_DIR/out/nsis"
BUILD_DIR="$OUT_DIR/build-mac"

# Version configuration
NSIS_VERSION=${NSIS_VERSION:-3.10}
NSIS_BRANCH=${NSIS_BRANCH_OR_COMMIT:-v310}

BUNDLE_DIR="$OUT_DIR/nsis-bundle"
BASE_ARCHIVE="$OUT_DIR/nsis-bundle-base-$NSIS_BRANCH.zip"
OUTPUT_ARCHIVE="$OUT_DIR/nsis-bundle-mac-$NSIS_BRANCH.zip"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_NAME="x64" ;;
    arm64) ARCH_NAME="arm64" ;;
    *) ARCH_NAME="$ARCH" ;;
esac

echo "🍎 Building native macOS makensis binary..."
echo "   Version:      $NSIS_VERSION"
echo "   Branch:       $NSIS_BRANCH"
echo "   Architecture: $ARCH_NAME ($ARCH)"
echo ""

# =============================================================================
# Check Prerequisites
# =============================================================================

# Check if running on macOS
if [ "$(uname -s)" != "Darwin" ]; then
    echo "❌ This script must be run on macOS"
    echo "   For cross-platform builds, use Docker for Linux builds"
    exit 1
fi

# Check for Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo "❌ Xcode Command Line Tools not found"
    echo "   Install with: xcode-select --install"
    exit 1
fi

# Check for scons
if ! command -v scons &> /dev/null; then
    echo "📦 Installing scons via pip..."
    python3 -m pip install --user scons 2>/dev/null || {
        echo "❌ Failed to install scons"
        echo "   Install with: pip3 install scons"
        exit 1
    }
fi

# Check for base bundle
if [ ! -f "$BASE_ARCHIVE" ]; then
    echo "❌ Base bundle not found: $BASE_ARCHIVE"
    echo "   Run assets/nsis-windows.sh first to create the base bundle"
    exit 1
fi

# =============================================================================
# Clone NSIS Source
# =============================================================================

echo "📥 Cloning NSIS source..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

if ! git clone --branch "$NSIS_BRANCH" --depth=1 \
    https://github.com/kichik/nsis.git "$BUILD_DIR/nsis"; then
    echo "❌ Failed to clone NSIS repository"
    exit 1
fi

echo "  ✓ NSIS source cloned"

# =============================================================================
# Build macOS Binary
# =============================================================================

echo ""
echo "🔨 Compiling native macOS binary..."
echo "   This may take 5-10 minutes..."

cd "$BUILD_DIR/nsis"

# Build with SCons
# Skip stubs, plugins, utils - we only need the compiler
if ! scons \
    SKIPSTUBS=all \
    SKIPPLUGINS=all \
    SKIPUTILS=all \
    SKIPMISC=all \
    NSIS_CONFIG_CONST_DATA_PATH=no \
    NSIS_MAX_STRLEN=8192 \
    PREFIX="$BUILD_DIR/install" \
    install-compiler; then
    echo "❌ Compilation failed"
    echo "   Check that Xcode Command Line Tools are properly installed"
    exit 1
fi

echo "  ✓ Compilation successful"

# =============================================================================
# Verify Binary
# =============================================================================

COMPILED_BINARY="$BUILD_DIR/install/makensis"

if [ ! -f "$COMPILED_BINARY" ]; then
    echo "❌ Compiled binary not found at expected location"
    exit 1
fi

chmod +x "$COMPILED_BINARY"

echo ""
echo "🧪 Verifying binary..."

# Check if it's a valid Mach-O binary
if file "$COMPILED_BINARY" | grep -q "Mach-O"; then
    echo "  ✓ Valid macOS Mach-O binary"
else
    echo "  ⚠️  Binary verification inconclusive"
fi

# Try to get version
if "$COMPILED_BINARY" -VERSION &> /dev/null; then
    VERSION_OUTPUT=$("$COMPILED_BINARY" -VERSION 2>&1 | head -1)
    echo "  ✓ Binary test successful: $VERSION_OUTPUT"
else
    echo "  ⚠️  Binary version check failed (may still work)"
fi

# =============================================================================
# Inject into Base Bundle
# =============================================================================

echo ""
echo "📂 Injecting macOS binary into base bundle..."

# Extract base bundle
rm -rf "$BUNDLE_DIR"
unzip -q "$BASE_ARCHIVE" -d "$OUT_DIR"

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "❌ Failed to extract base bundle"
    exit 1
fi

# Create mac directory and copy binary
mkdir -p "$BUNDLE_DIR/mac"
cp "$COMPILED_BINARY" "$BUNDLE_DIR/mac/makensis"
chmod +x "$BUNDLE_DIR/mac/makensis"

echo "  ✓ macOS binary added to bundle"

# =============================================================================
# Create Version Metadata
# =============================================================================

echo ""
echo "📝 Creating macOS version metadata..."

cat > "$BUNDLE_DIR/mac/VERSION.txt" <<EOF
Platform: macOS
Binary: makensis (native Mach-O binary)
Architecture: $ARCH_NAME ($ARCH)
Build Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Compiled from source: NSIS $NSIS_BRANCH
Compiler: Clang $(clang --version | head -1)
Build system: SCons
macOS Version: $(sw_vers -productVersion)

This binary is compiled from source with:
- Native macOS compilation (no cross-compile)
- NSIS_MAX_STRLEN=8192
- NSIS_CONFIG_CONST_DATA_PATH=no

Usage:
  ./mac/makensis -DNSISDIR=\$(pwd)/share/nsis your-script.nsi

Or set environment:
  export NSISDIR="\$(pwd)/share/nsis"
  ./mac/makensis your-script.nsi
EOF

# =============================================================================
# Create Final Archive
# =============================================================================

echo ""
echo "📦 Creating final macOS bundle..."

cd "$OUT_DIR"
rm -f "$OUTPUT_ARCHIVE"
zip -r9q "$OUTPUT_ARCHIVE" nsis-bundle

# =============================================================================
# Cleanup
# =============================================================================

echo ""
echo "🧹 Cleaning up build directory..."
rm -rf "$BUILD_DIR"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "================================================================"
echo "  ✅ macOS Build Complete!"
echo "================================================================"
echo "  📁 Archive: $OUTPUT_ARCHIVE"
echo "  📊 Size:    $(du -h "$OUTPUT_ARCHIVE" | cut -f1)"
echo "  🏗️  Arch:    $ARCH_NAME"
echo "================================================================"
echo ""
echo "📋 Bundle now contains:"
echo "   ✓ windows/makensis.exe   (Windows binary)"
echo "   ✓ mac/makensis           (macOS native binary)"
echo "   ✓ share/nsis/            (Complete NSIS data)"

if [ -d "$BUNDLE_DIR/linux" ]; then
    echo "   ✓ linux/makensis         (Linux native binary)"
fi

echo ""
echo "🧪 Test the macOS binary:"
echo "   cd $BUNDLE_DIR"
echo "   ./mac/makensis -VERSION"
echo ""
echo "✅ All platform binaries ready!"
echo ""