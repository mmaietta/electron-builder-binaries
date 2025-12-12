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

echo "Building for macOS ($ARCH) -> $ARCH_DIR"

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
mkdir -p "$OUTPUT_DIR"

# Copy binaries
echo "Copying binaries..."
cp "$MKSQUASHFS" "$OUTPUT_DIR/mksquashfs"
cp "$DESKTOP_FILE_VALIDATE" "$OUTPUT_DIR/desktop-file-validate"

# Make sure they're executable
chmod +x "$OUTPUT_DIR/mksquashfs"
chmod +x "$OUTPUT_DIR/desktop-file-validate"

# Verify the binaries work
echo "Verifying binaries..."
if "$OUTPUT_DIR/mksquashfs" -version &> /dev/null; then
    echo "✓ mksquashfs verified"
else
    echo "⚠ mksquashfs verification failed (may still work)"
fi

if "$OUTPUT_DIR/desktop-file-validate" --help &> /dev/null; then
    echo "✓ desktop-file-validate verified"
else
    echo "⚠ desktop-file-validate verification failed (may still work)"
fi

echo ""
echo "✓ macOS build complete!"
echo "Output: $OUTPUT_DIR"
echo ""
echo "Files created:"
ls -lh "$OUTPUT_DIR"