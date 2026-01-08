#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# NSIS Bundle Combiner
# =============================================================================
# Combines base, Linux, and macOS bundles into a single complete bundle
# Generates universal entrypoint wrapper script
# =============================================================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUT_DIR="${OUT_DIR:-$BASE_DIR/out/nsis}"
BUILD_DIR="/tmp/nsis-bundle-combine"

# Version info
NSIS_VERSION=${NSIS_VERSION:-3.10}
NSIS_BRANCH=${NSIS_BRANCH_OR_COMMIT:-v310}

echo "🔗 Combining NSIS bundles..."
echo "   Version: $NSIS_VERSION"
echo "   Branch:  $NSIS_BRANCH"
echo ""

# =============================================================================
# Cleanup and Setup
# =============================================================================

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# =============================================================================
# Find Input Bundles
# =============================================================================

echo "📂 Locating bundle files..."

BASE_BUNDLE=$(find "$OUT_DIR" -name "nsis-bundle-base-*.tar.gz" -type f | head -1)
LINUX_BUNDLE=$(find "$OUT_DIR" -name "nsis-bundle-linux-*.tar.gz" -type f | head -1)

# Find Mac bundles - may have different architectures
MAC_BUNDLES=$(find "$OUT_DIR" -name "nsis-bundle-mac-*.tar.gz" -type f)
# Debug output
echo "Searching in: $OUT_DIR"
echo "Files found:"
find "$OUT_DIR" -name "*.tar.gz" -type f 2>/dev/null || echo "  (none)"
echo ""

# Validate base bundle
if [ -z "$BASE_BUNDLE" ] || [ ! -f "$BASE_BUNDLE" ]; then
    echo "❌ Base bundle not found in $OUT_DIR"
    exit 1
fi

echo "  ✓ Base:         $(basename "$BASE_BUNDLE")"

if [ -n "$LINUX_BUNDLE" ] && [ -f "$LINUX_BUNDLE" ]; then
    echo "  ✓ Linux:        $(basename "$LINUX_BUNDLE")"
else
    echo "  ⚠️  Linux:        not found (skipping)"
    LINUX_BUNDLE=""
fi

if [ -n "$MAC_BUNDLES" ]; then
    for mac_bundle in $MAC_BUNDLES; do
        echo "  ✓ macOS:        $(basename "$mac_bundle")"
    done
else
    echo "  ⚠️  macOS:        not found (skipping)"
fi

# =============================================================================
# Extract Base Bundle
# =============================================================================

echo ""
echo "📦 Extracting base bundle..."
mkdir -p "$BUILD_DIR"
tar -xzf "$BASE_BUNDLE" -C "$BUILD_DIR"

if [ ! -d "$BUILD_DIR/nsis-bundle" ]; then
    echo "❌ Base bundle extraction failed - nsis-bundle directory not found"
    exit 1
fi

echo "  ✓ Base bundle extracted"

# =============================================================================
# Inject Linux Binary
# =============================================================================

if [ -n "$LINUX_BUNDLE" ]; then
    echo ""
    echo "🐧 Injecting Linux binary..."
    
    TEMP_LINUX="$BUILD_DIR/temp-linux"
    mkdir -p "$TEMP_LINUX"
    
    tar -xzf "$LINUX_BUNDLE" -C "$TEMP_LINUX"
    
    if [ -d "$TEMP_LINUX/nsis-bundle/linux" ]; then
        cp -r "$TEMP_LINUX/nsis-bundle/linux" "$BUILD_DIR/nsis-bundle/"
        echo "  ✓ Linux binary added"
    else
        echo "  ⚠️  Linux binary not found in bundle"
        exit 1
    fi
    
    rm -rf "$TEMP_LINUX"
fi

# =============================================================================
# Inject macOS Binaries
# =============================================================================

if [ -n "$MAC_BUNDLES" ]; then
    echo ""
    echo "🍎 Injecting macOS binaries..."
    
    for mac_bundle in $MAC_BUNDLES; do
        TEMP_MAC="$BUILD_DIR/temp-mac-$$"
        mkdir -p "$TEMP_MAC"
        
        tar -xzf "$mac_bundle" -C "$TEMP_MAC"
        
        if [ -d "$TEMP_MAC/nsis-bundle/mac" ]; then
            # Check if this is first mac binary or additional architecture
            cp -r "$TEMP_MAC/nsis-bundle/mac" "$BUILD_DIR/nsis-bundle/mac/${mac_bundle##*/}"
            echo "  ✓ macOS binary added ($(basename "$mac_bundle"))"
        else
            echo "  ⚠️  macOS binary not found in $(basename "$mac_bundle")"
            exit 1
        fi
        
        rm -rf "$TEMP_MAC"
    done
fi

# =============================================================================
# Create Universal Entrypoint Wrapper
# =============================================================================

echo ""
echo "🔧 Creating universal entrypoint wrapper..."

cat > "$BUILD_DIR/nsis-bundle/makensis" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# NSIS Universal Entrypoint
# =============================================================================
# Auto-detects platform and architecture, sets NSISDIR, and executes makensis
# =============================================================================

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect platform
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Map to binary location
case "$PLATFORM" in
    darwin*)
        PLATFORM_DIR="mac"
        ;;
    linux*)
        PLATFORM_DIR="linux"
        ;;
    mingw*|msys*|cygwin*)
        PLATFORM_DIR="windows"
        ;;
    *)
        echo "❌ Unsupported platform: $PLATFORM" >&2
        exit 1
        ;;
esac

# Find the binary
BINARY="$SCRIPT_DIR/$PLATFORM_DIR/makensis"
if [ "$PLATFORM_DIR" = "windows" ]; then
    BINARY="${BINARY}.exe"
fi

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "❌ makensis binary not found: $BINARY" >&2
    echo "" >&2
    echo "Available binaries:" >&2
    find "$SCRIPT_DIR" -name "makensis*" -type f 2>/dev/null || echo "  (none found)" >&2
    exit 1
fi

# Make sure it's executable
chmod +x "$BINARY" 2>/dev/null || true

# Set NSISDIR if not already set
if [ -z "${NSISDIR:-}" ]; then
    export NSISDIR="$SCRIPT_DIR/share/nsis"
fi

# Execute makensis with all arguments
exec "$BINARY" "$@"
EOF

chmod +x "$BUILD_DIR/nsis-bundle/makensis"
echo "  ✓ Created universal makensis wrapper"

# =============================================================================
# Create README
# =============================================================================

echo ""
echo "📝 Creating README..."

cat > "$BUILD_DIR/nsis-bundle/README.md" <<EOF
# NSIS Cross-Platform Bundle

This bundle contains NSIS (Nullsoft Scriptable Install System) binaries for multiple platforms.

## Contents

- **Windows**: \`windows/makensis.exe\` (official pre-built binary)
- **Linux**: \`linux/makensis\` (native ELF binary, compiled from source)
- **macOS**: \`mac/makensis\` (native Mach-O binary, compiled from source)
- **NSIS Data**: \`share/nsis/\` (Contrib, Include, Plugins, Stubs)
- **Universal Wrapper**: \`makensis\` (auto-detects platform)

## Quick Start

### Option 1: Use Universal Wrapper (Recommended)

The wrapper automatically detects your platform and sets \`NSISDIR\`:

\`\`\`bash
./makensis your-script.nsi
\`\`\`

### Option 2: Use Platform-Specific Binary

\`\`\`bash
# Set NSISDIR manually
export NSISDIR="\$(pwd)/share/nsis"

# Run platform-specific binary
./windows/makensis.exe your-script.nsi  # Windows
./linux/makensis your-script.nsi         # Linux
./mac/makensis your-script.nsi           # macOS
\`\`\`

## Version Information

- NSIS Version: $NSIS_VERSION
- Branch/Tag: $NSIS_BRANCH
- Build Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Included Plugins

This bundle includes 8 additional community plugins:

1. NsProcess - Process management
2. UAC - User Account Control
3. WinShell - Shell integration
4. NsJSON - JSON parsing
5. NsArray - Array support
6. INetC - HTTP client
7. NsisMultiUser - Multi-user installs
8. StdUtils - Standard utilities

## Environment Variables

- **NSISDIR**: Path to NSIS data directory (auto-set by wrapper)
- Set manually if needed: \`export NSISDIR=/path/to/share/nsis\`

## More Information

- NSIS Documentation: https://nsis.sourceforge.io/Docs/
- Plugin Repository: https://nsis.sourceforge.io/Category:Plugins
EOF

echo "  ✓ README created"

# =============================================================================
# Update VERSION.txt
# =============================================================================

echo ""
echo "📝 Updating VERSION.txt..."

cat > "$BUILD_DIR/nsis-bundle/VERSION.txt" <<EOF
NSIS Complete Bundle
====================
NSIS Version: $NSIS_VERSION
Branch/Tag: $NSIS_BRANCH
Bundle Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

Platforms Included:
-------------------
EOF

if [ -f "$BUILD_DIR/nsis-bundle/windows/makensis.exe" ]; then
    echo "✓ Windows: windows/makensis.exe (official pre-built)" >> "$BUILD_DIR/nsis-bundle/VERSION.txt"
fi

if [ -f "$BUILD_DIR/nsis-bundle/linux/makensis" ]; then
    echo "✓ Linux: linux/makensis (native ELF, compiled from source)" >> "$BUILD_DIR/nsis-bundle/VERSION.txt"
fi

if [ -f "$BUILD_DIR/nsis-bundle/mac/makensis" ]; then
    echo "✓ macOS: mac/makensis (native Mach-O, compiled from source)" >> "$BUILD_DIR/nsis-bundle/VERSION.txt"
fi

cat >> "$BUILD_DIR/nsis-bundle/VERSION.txt" <<EOF

Components:
-----------
✓ 8 community plugins installed
✓ Complete NSIS data files (Contrib, Include, Plugins, Stubs)
✓ Universal entrypoint wrapper (makensis)
✓ Language file patches applied

Usage:
------
./makensis your-script.nsi

The wrapper automatically sets:
  NSISDIR=\$(pwd)/share/nsis

Or use platform-specific binary:
  export NSISDIR="\$(pwd)/share/nsis"
  ./windows/makensis.exe your-script.nsi
  ./linux/makensis your-script.nsi
  ./mac/makensis your-script.nsi
EOF

echo "  ✓ VERSION.txt updated"

# =============================================================================
# Create Final Archive
# =============================================================================

echo ""
echo "📦 Creating final tar.gz archive..."

ARCHIVE_NAME="nsis-bundle-complete-$NSIS_BRANCH.tar.gz"
rm -f "$OUT_DIR/$ARCHIVE_NAME"

(
    cd "$BUILD_DIR"
    tar -czf "$OUT_DIR/$ARCHIVE_NAME" nsis-bundle
)

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "================================================================"
echo "  ✅ Bundle Combination Complete!"
echo "================================================================"
echo "  📁 Archive: $OUT_DIR/$ARCHIVE_NAME"
echo "  📊 Size:    $(du -h "$OUT_DIR/$ARCHIVE_NAME" | cut -f1)"
echo "================================================================"
echo ""
echo "📋 Combined bundle contains:"

if [ -f "$BUILD_DIR/nsis-bundle/windows/makensis.exe" ]; then
    echo "  ✓ Windows binary"
fi

if [ -f "$BUILD_DIR/nsis-bundle/linux/makensis" ]; then
    echo "  ✓ Linux binary"
fi

if [ -f "$BUILD_DIR/nsis-bundle/mac/makensis" ]; then
    echo "  ✓ macOS binary"
fi

echo "  ✓ Complete NSIS data"
echo "  ✓ 8 community plugins"
echo "  ✓ Universal entrypoint wrapper"
echo "  ✓ Language file patches"
echo ""

# =============================================================================
# Cleanup
# =============================================================================

rm -rf "$BUILD_DIR"

echo "✅ Done!"
echo ""