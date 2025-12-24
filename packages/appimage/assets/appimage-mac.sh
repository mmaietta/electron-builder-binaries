#!/bin/bash
set -e

echo "Building AppImage tools for macOS..."

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_DIR="x86_64"
elif [ "$ARCH" = "arm64" ]; then
    ARCH_DIR="arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

DEST="${DEST:-"./packages/AppImage/build"}"
echo "Building for macOS ($ARCH) -> $DEST"

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is required but not installed"
    echo "Install from: https://brew.sh"
    exit 1
fi

# Install dependencies if not present
echo "Checking dependencies..."
DEPS=("squashfs" "desktop-file-utils")
for dep in "${DEPS[@]}"; do
    if ! brew list "$dep" &> /dev/null; then
        echo "Installing $dep..."
        brew install "$dep"
    else
        echo "✓ $dep already installed"
    fi
done

# Find installed binaries
MKSQUASHFS=$(which mksquashfs)
DESKTOP_FILE_VALIDATE=$(which desktop-file-validate)

if [ -z "$MKSQUASHFS" ]; then
    echo "Error: mksquashfs not found"
    exit 1
fi

if [ -z "$DESKTOP_FILE_VALIDATE" ]; then
    echo "Error: desktop-file-validate not found"
    exit 1
fi

echo "✓ Found mksquashfs at: $MKSQUASHFS"
echo "✓ Found desktop-file-validate at: $DESKTOP_FILE_VALIDATE"

# Create output directory
OUTPUT_DIR="$DEST/$ARCH_DIR"
TMP_DIR="/tmp/appimage-macos-build"
rm -rf "$TMP_DIR"
mkdir -p "$OUTPUT_DIR" "$TMP_DIR"

echo "Fixing dynamic library paths with install_name_tool..."

# Copy binaries to temp location for patching
cp "$MKSQUASHFS" "$TMP_DIR/mksquashfs"
cp "$DESKTOP_FILE_VALIDATE" "$TMP_DIR/desktop-file-validate"

# Get the list of dynamic libraries that mksquashfs depends on
echo "Analyzing mksquashfs dependencies..."
otool -L "$TMP_DIR/mksquashfs" | grep -v ":" | grep -v "@" | awk '{print $1}' | while read -r lib; do
    if [[ "$lib" == /usr/local/* ]] || [[ "$lib" == /opt/homebrew/* ]]; then
        libname=$(basename "$lib")
        # Try to change the path to use @executable_path (relative to binary)
        install_name_tool -change "$lib" "@executable_path/lib/$libname" "$TMP_DIR/mksquashfs" 2>/dev/null || \
        # Or try @loader_path
        install_name_tool -change "$lib" "@loader_path/lib/$libname" "$TMP_DIR/mksquashfs" 2>/dev/null || \
        echo "  ⚠️  Could not update path for $lib"
    fi
done

echo "Analyzing desktop-file-validate dependencies..."
otool -L "$TMP_DIR/desktop-file-validate" | grep -v ":" | grep -v "@" | awk '{print $1}' | while read -r lib; do
    if [[ "$lib" == /usr/local/* ]] || [[ "$lib" == /opt/homebrew/* ]]; then
        libname=$(basename "$lib")
        install_name_tool -change "$lib" "@executable_path/lib/$libname" "$TMP_DIR/desktop-file-validate" 2>/dev/null || \
        install_name_tool -change "$lib" "@loader_path/lib/$libname" "$TMP_DIR/desktop-file-validate" 2>/dev/null || \
        echo "  ⚠️  Could not update path for $lib"
    fi
done

# Copy patched binaries
echo "Copying patched binaries..."
cp "$TMP_DIR/mksquashfs" "$OUTPUT_DIR/mksquashfs"
cp "$TMP_DIR/desktop-file-validate" "$OUTPUT_DIR/desktop-file-validate"

# Make sure they're executable
chmod +x "$OUTPUT_DIR/mksquashfs"
chmod +x "$OUTPUT_DIR/desktop-file-validate"

# Copy required dylibs
echo "Copying required dynamic libraries..."
mkdir -p "$OUTPUT_DIR/lib"

copy_dylib() {
    local lib_path=$1
    if [ -f "$lib_path" ]; then
        local lib_name=$(basename "$lib_path")
        cp "$lib_path" "$OUTPUT_DIR/lib/$lib_name"
        echo "  ✓ Copied $lib_name"
    else
        echo "  ⚠️  $lib_path not found"
        exit 1
    fi
}

# Find and copy homebrew libraries
if [ -d "/usr/local/opt" ]; then
    BREW_PREFIX="/usr/local"
elif [ -d "/opt/homebrew" ]; then
    BREW_PREFIX="/opt/homebrew"
fi

if [ -n "$BREW_PREFIX" ]; then
    # Copy common dependencies
    copy_dylib "$BREW_PREFIX/opt/lzo/lib/liblzo2.2.dylib"
    copy_dylib "$BREW_PREFIX/opt/xz/lib/liblzma.5.dylib"
    copy_dylib "$BREW_PREFIX/opt/lz4/lib/liblz4.1.dylib"
    copy_dylib "$BREW_PREFIX/opt/zstd/lib/libzstd.1.dylib"
fi

# Verify the binaries
echo "Verifying patched binaries..."
echo "mksquashfs dependencies:"
otool -L "$OUTPUT_DIR/mksquashfs" | grep -v ":" | head -10

echo ""
echo "✓ macOS build complete!"
echo "Output: $OUTPUT_DIR"
echo ""
echo "Files created:"
ls -lh "$OUTPUT_DIR"
echo ""

echo "Creating zip archive..."
ARCHIVE_NAME="appimage-tools-macos-$ARCH.zip"
(
    cd "$OUTPUT_DIR"
    zip -r -9 "$ROOT/out/$ARCHIVE_NAME" . >/dev/null
)
echo "✓ Archive created: $ROOT/out/$ARCHIVE_NAME"