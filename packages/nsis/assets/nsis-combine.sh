#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# NSIS Bundle Combiner
# =============================================================================
# Combines base, Linux, and macOS bundles into a single complete bundle
# with all platform binaries
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

# Use find with a more flexible pattern to handle different paths
BASE_BUNDLE=$(find "$OUT_DIR" -name "nsis-bundle-base-*.zip" -type f | head -1)
LINUX_BUNDLE=$(find "$OUT_DIR" -name "nsis-bundle-linux-*.zip" -type f | head -1)
MAC_X64_BUNDLE=$(find "$OUT_DIR" -name "nsis-bundle-mac-*x64*.zip" -o -name "nsis-bundle-mac-*.zip" | grep -v arm64 | head -1)
MAC_ARM64_BUNDLE=$(find "$OUT_DIR" -name "nsis-bundle-mac-*arm64*.zip" -type f | head -1)

# Debug: Show what we found
echo "Searching in: $OUT_DIR"
echo "Files found:"
find "$OUT_DIR" -name "*.zip" -type f || echo "  (none)"
echo ""

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

if [ -n "$MAC_X64_BUNDLE" ] && [ -f "$MAC_X64_BUNDLE" ]; then
    echo "  ✓ macOS x64:    $(basename "$MAC_X64_BUNDLE")"
else
    echo "  ⚠️  macOS x64:    not found (skipping)"
    MAC_X64_BUNDLE=""
fi

if [ -n "$MAC_ARM64_BUNDLE" ] && [ -f "$MAC_ARM64_BUNDLE" ]; then
    echo "  ✓ macOS arm64:  $(basename "$MAC_ARM64_BUNDLE")"
else
    echo "  ⚠️  macOS arm64:  not found (skipping)"
    MAC_ARM64_BUNDLE=""
fi

# =============================================================================
# Extract Base Bundle
# =============================================================================

echo ""
echo "📦 Extracting base bundle..."

unzip -q "$BASE_BUNDLE" -d "$BUILD_DIR"

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
    
    unzip -q "$LINUX_BUNDLE" -d "$TEMP_LINUX"
    
    if [ -d "$TEMP_LINUX/nsis-bundle/linux" ]; then
        cp -r "$TEMP_LINUX/nsis-bundle/linux" "$BUILD_DIR/nsis-bundle/"
        echo "  ✓ Linux binary added"
    else
        echo "  ⚠️  Linux binary not found in bundle"
    fi
    
    rm -rf "$TEMP_LINUX"
fi

# =============================================================================
# Inject macOS x64 Binary
# =============================================================================

if [ -n "$MAC_X64_BUNDLE" ]; then
    echo ""
    echo "🍎 Injecting macOS x64 binary..."
    
    TEMP_MAC_X64="$BUILD_DIR/temp-mac-x64"
    mkdir -p "$TEMP_MAC_X64"
    
    unzip -q "$MAC_X64_BUNDLE" -d "$TEMP_MAC_X64"
    
    if [ -d "$TEMP_MAC_X64/nsis-bundle/mac" ]; then
        # Create mac directory structure
        mkdir -p "$BUILD_DIR/nsis-bundle/mac/x64"
        cp -r "$TEMP_MAC_X64/nsis-bundle/mac"/* "$BUILD_DIR/nsis-bundle/mac/x64/"
        echo "  ✓ macOS x64 binary added"
    else
        echo "  ⚠️  macOS x64 binary not found in bundle"
    fi
    
    rm -rf "$TEMP_MAC_X64"
fi

# =============================================================================
# Inject macOS arm64 Binary
# =============================================================================

if [ -n "$MAC_ARM64_BUNDLE" ]; then
    echo ""
    echo "🍎 Injecting macOS arm64 binary..."
    
    TEMP_MAC_ARM64="$BUILD_DIR/temp-mac-arm64"
    mkdir -p "$TEMP_MAC_ARM64"
    
    unzip -q "$MAC_ARM64_BUNDLE" -d "$TEMP_MAC_ARM64"
    
    if [ -d "$TEMP_MAC_ARM64/nsis-bundle/mac" ]; then
        # Create mac directory structure
        mkdir -p "$BUILD_DIR/nsis-bundle/mac/arm64"
        cp -r "$TEMP_MAC_ARM64/nsis-bundle/mac"/* "$BUILD_DIR/nsis-bundle/mac/arm64/"
        echo "  ✓ macOS arm64 binary added"
    else
        echo "  ⚠️  macOS arm64 binary not found in bundle"
    fi
    
    rm -rf "$TEMP_MAC_ARM64"
fi

# =============================================================================
# Create Platform Selector Wrappers
# =============================================================================

echo ""
echo "🔧 Creating platform selector wrappers..."

# Create makensis wrapper script
cat > "$BUILD_DIR/nsis-bundle/makensis" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Determine platform and architecture
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$PLATFORM" in
    darwin*)
        PLATFORM="mac"
        case "$ARCH" in
            x86_64) ARCH="x64" ;;
            arm64) ARCH="arm64" ;;
            *) ARCH="x64" ;;  # fallback
        esac
        ;;
    linux*)
        PLATFORM="linux"
        BINARY="$SCRIPT_DIR/$PLATFORM/makensis"
        ;;
    mingw*|msys*|cygwin*)
        PLATFORM="windows"
        BINARY="$SCRIPT_DIR/$PLATFORM/makensis.exe"
        ;;
    *)
        echo "❌ Unsupported platform: $PLATFORM"
        exit 1
        ;;
esac

# For macOS, use architecture-specific binary
if [ "$PLATFORM" = "mac" ]; then
    BINARY="$SCRIPT_DIR/$PLATFORM/$ARCH/makensis"
fi

if [ ! -x "$BINARY" ]; then
    echo "❌ Binary not found or not executable: $BINARY"
    echo ""
    echo "Available binaries:"
    find "$SCRIPT_DIR" -name "makensis*" -type f 2>/dev/null || echo "  (none found)"
    exit 1
fi

# Set NSISDIR if not already set
if [ -z "${NSISDIR:-}" ]; then
    export NSISDIR="$SCRIPT_DIR/share/nsis"
fi

# Execute the platform-specific binary
exec "$BINARY" "$@"
EOF

chmod +x "$BUILD_DIR/nsis-bundle/makensis"
echo "  ✓ Created makensis wrapper"

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
- **macOS x64**: \`mac/x64/makensis\` (native Mach-O binary, compiled from source)
- **macOS arm64**: \`mac/arm64/makensis\` (native Mach-O binary, compiled from source)
- **NSIS Data**: \`share/nsis/\` (Contrib, Include, Plugins, Stubs)

## Quick Start

### Option 1: Use the Platform Wrapper (Recommended)

\`\`\`bash
# The wrapper automatically selects the right binary for your platform
./makensis your-script.nsi
\`\`\`

### Option 2: Use Platform-Specific Binary

\`\`\`bash
# Set NSISDIR
export NSISDIR="\$(pwd)/share/nsis"

# Run platform-specific binary
./windows/makensis.exe your-script.nsi  # Windows
./linux/makensis your-script.nsi         # Linux
./mac/x64/makensis your-script.nsi       # macOS x64
./mac/arm64/makensis your-script.nsi     # macOS arm64
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

if [ -f "$BUILD_DIR/nsis-bundle/mac/x64/makensis" ]; then
    echo "✓ macOS x64: mac/x64/makensis (native Mach-O, compiled from source)" >> "$BUILD_DIR/nsis-bundle/VERSION.txt"
fi

if [ -f "$BUILD_DIR/nsis-bundle/mac/arm64/makensis" ]; then
    echo "✓ macOS arm64: mac/arm64/makensis (native Mach-O, compiled from source)" >> "$BUILD_DIR/nsis-bundle/VERSION.txt"
fi

cat >> "$BUILD_DIR/nsis-bundle/VERSION.txt" <<EOF

Additional Components:
----------------------
✓ 8 community plugins installed
✓ Complete NSIS data files (Contrib, Include, Plugins, Stubs)
✓ Platform selector wrapper (makensis)

Usage:
------
./makensis your-script.nsi

Or with explicit NSISDIR:
export NSISDIR="\$(pwd)/share/nsis"
./windows/makensis.exe your-script.nsi
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

if [ -f "$BUILD_DIR/nsis-bundle/mac/x64/makensis" ]; then
    echo "  ✓ macOS x64 binary"
fi

if [ -f "$BUILD_DIR/nsis-bundle/mac/arm64/makensis" ]; then
    echo "  ✓ macOS arm64 binary"
fi

echo "  ✓ Complete NSIS data"
echo "  ✓ 8 community plugins"
echo "  ✓ Platform selector wrapper"
echo ""

# =============================================================================
# Cleanup
# =============================================================================

rm -rf "$BUILD_DIR"

echo "✅ Done!"
echo ""