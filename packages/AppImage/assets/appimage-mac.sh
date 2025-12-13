#!/bin/bash
set -e

echo "Building AppImage tools for macOS..."

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_DIR="darwin"
elif [ "$ARCH" = "arm64" ]; then
    ARCH_DIR="darwin"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

echo "Building for macOS ($ARCH_DIR) -> $ARCH"

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
OUTPUT_DIR="./out/AppImage/$ARCH_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Copy binaries
echo "Copying binaries..."
cp -aL "$MKSQUASHFS" "$OUTPUT_DIR/mksquashfs"
cp -aL "$DESKTOP_FILE_VALIDATE" "$OUTPUT_DIR/desktop-file-validate"
echo "✓ Binaries copied to $OUTPUT_DIR"

VERSION_FILE="$OUTPUT_DIR/VERSION.txt"

echo "Verifying binaries and recording versions..."
: > "$VERSION_FILE"

# Verify mksquashfs
if MKSQ_VER=$("$OUTPUT_DIR/mksquashfs" -version 2>&1); then
    echo "mksquashfs: $MKSQ_VER" >> "$VERSION_FILE"
    echo "✓ mksquashfs verified"
else
    echo "❌ mksquashfs verification failed"
    exit 1
fi

# Verify desktop-file-validate
if DFV_VER=$("$OUTPUT_DIR/desktop-file-validate" --version 2>&1); then
    echo "desktop-file-validate: $DFV_VER" >> "$VERSION_FILE"
    echo "✓ desktop-file-validate verified"
else
    echo "❌ desktop-file-validate verification failed"
    exit 1
fi

echo "Versions written to $VERSION_FILE"

echo ""
echo "✓ macOS build complete!"
echo "Output: $OUTPUT_DIR"
echo ""
echo "Files created:"
ls -lh "$OUTPUT_DIR"