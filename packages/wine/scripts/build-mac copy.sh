#!/usr/bin/env bash
set -ex

WINE_VERSION=${WINE_VERSION:-9.0}
BUILD_DIR=${BUILD_DIR:-$(pwd)/build}
PLATFORM_ARCH=${PLATFORM_ARCH:-$(arch)}

get_checksum() {
    case "$1" in
        9.0) echo "527e9fb2c46f0131d2e2349391aea3062e63bb03b1ced2a0cc8f4c1b03f99173" ;;
        8.0) echo "542496c086a38e0e5a8d8d3db5d9eada8b6ee51fcab664dd58dcd75ac11c0e6a" ;;
        *) echo "" ;;
    esac
}

CHECKSUM=$(get_checksum "$WINE_VERSION")
WINE_MAJOR=$(echo "$WINE_VERSION" | cut -d. -f1)
WINE_URL="https://dl.winehq.org/wine/source/${WINE_MAJOR}.0/wine-${WINE_VERSION}.tar.xz"

# Determine architecture and Homebrew paths
HOST_ARCH=$(arch)
X86_BREW_HOME='/usr/local'

if [ "$HOST_ARCH" = 'arm64' ]; then
    ARCH_BREW_HOME='/opt/homebrew'
    ARCH_CMD='arch -x86_64'
    
    # Use Xcode's SDK for ARM builds
    export SDKROOT="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
else
    ARCH_BREW_HOME="$X86_BREW_HOME"
    ARCH_CMD=
fi

# Execute command with proper architecture
# On ARM Mac building x86_64: prefixes with 'arch -x86_64'
# On Intel Mac: runs command directly
execute_cmd() {
    if [ -n "$ARCH_CMD" ]; then
        $ARCH_CMD "$@"
    else
        "$@"
    fi
}

DOWNLOAD_DIR="$BUILD_DIR/downloads"
SOURCE_DIR="$BUILD_DIR/wine-${WINE_VERSION}"
BUILD_WINE_DIR="$BUILD_DIR/wine64-build"
STAGE_DIR="$BUILD_DIR/wine-stage"
OUTPUT_DIR="$BUILD_DIR/wine-${WINE_VERSION}-darwin-${PLATFORM_ARCH}"

mkdir -p "$DOWNLOAD_DIR"

# Download
ARCHIVE="$DOWNLOAD_DIR/wine-${WINE_VERSION}.tar.xz"
if [ ! -f "$ARCHIVE" ]; then
    echo "📥 Downloading Wine ${WINE_VERSION}..."
    curl -L --progress-bar "$WINE_URL" -o "$ARCHIVE"
    
    if [ -n "$CHECKSUM" ]; then
        echo "🔍 Verifying checksum..."
        ACTUAL=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
        if [ "$ACTUAL" != "$CHECKSUM" ]; then
            echo "❌ Checksum failed!"
            echo "   Expected: $CHECKSUM"
            echo "   Got:      $ACTUAL"
            exit 1
        fi
        echo "✅ Verified"
    fi
fi

# Extract
if [ ! -d "$SOURCE_DIR" ]; then
    echo "📂 Extracting..."
    tar -xJf "$ARCHIVE" -C "$BUILD_DIR"
fi

# Configure
echo "⚙️  Configuring Wine for $PLATFORM_ARCH..."
rm -rf "$BUILD_WINE_DIR" "$STAGE_DIR"
mkdir -p "$BUILD_WINE_DIR" "$STAGE_DIR"
cd "$BUILD_WINE_DIR"

# Use architecture-specific Homebrew paths
export PATH="$ARCH_BREW_HOME/bin:$PATH"

# Set PKG_CONFIG_PATH to find all Homebrew libraries
# export PKG_CONFIG_PATH="$ARCH_BREW_HOME/opt/freetype/lib/pkgconfig:$ARCH_BREW_HOME/opt/libpng/lib/pkgconfig:$ARCH_BREW_HOME/opt/gnutls/lib/pkgconfig:$ARCH_BREW_HOME/lib/pkgconfig"
export FREETYPE_PREFIX="$(brew --prefix freetype)"

export PKG_CONFIG_PATH="$FREETYPE_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export CFLAGS="-I$FREETYPE_PREFIX/include"
export LDFLAGS="-L$FREETYPE_PREFIX/lib"


execute_cmd "$SOURCE_DIR/configure" \
    --prefix="$STAGE_DIR" \
    --enable-win64 \
    --without-x \
    --without-cups \
    --without-dbus

# Build
echo "🔨 Building (30-60 min)..."
execute_cmd make -j$(sysctl -n hw.ncpu)

# Install
echo "📦 Installing..."
execute_cmd make install

# Create portable structure
echo "📋 Creating portable bundle..."
cd "$STAGE_DIR"

# Remove unnecessary files
rm -rf share/man share/applications include

# Fix library paths
cd bin
for binary in wine64 wine wineserver wineboot winecfg; do
    if [ -f "$binary" ]; then
        install_name_tool -add_rpath "@executable_path/../lib" "$binary" 2>/dev/null || true
    fi
done
cd ..

# Initialize Wine prefix
echo "🍇 Initializing Wine prefix..."
export WINEPREFIX="$STAGE_DIR/wine-home"
export WINEARCH=win64
export WINEDEBUG=-all
execute_cmd ./bin/wineboot --init 2>&1 | grep -v "fixme:" | head -5 || true
sleep 2

# Clean Wine prefix
echo "🧹 Cleaning Wine prefix..."
rm -rf wine-home/drive_c/windows/Installer
rm -rf wine-home/drive_c/windows/Microsoft.NET
rm -rf wine-home/drive_c/windows/mono
rm -rf wine-home/drive_c/windows/system32/gecko
rm -rf wine-home/drive_c/windows/syswow64/gecko 2>/dev/null || true
rm -rf wine-home/drive_c/windows/logs
rm -rf wine-home/drive_c/windows/inf

# Copy to output
echo "📦 Packaging..."
rm -rf "$OUTPUT_DIR"
cp -R "$STAGE_DIR" "$OUTPUT_DIR"

# Create launcher
cat > "$OUTPUT_DIR/wine-launcher.sh" << 'LAUNCHER_EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export WINEPREFIX="${WINEPREFIX:-$SCRIPT_DIR/wine-home}"
export WINEDEBUG="${WINEDEBUG:--all}"
export DYLD_LIBRARY_PATH="$SCRIPT_DIR/lib:${DYLD_LIBRARY_PATH:-}"
exec "$SCRIPT_DIR/bin/wine64" "$@"
LAUNCHER_EOF
chmod +x "$OUTPUT_DIR/wine-launcher.sh"

# Create README
cat > "$OUTPUT_DIR/README.md" << README_EOF
# Wine ${WINE_VERSION} Portable - macOS ${PLATFORM_ARCH}

Portable Wine bundle compiled from source.

## Usage
\`\`\`bash
./wine-launcher.sh notepad
./wine-launcher.sh your-app.exe
\`\`\`

Built on $(date) for ${PLATFORM_ARCH}
README_EOF

# Create archive
echo "🗜️  Creating archive..."
cd "$BUILD_DIR"
tar -czf "wine-${WINE_VERSION}-darwin-${PLATFORM_ARCH}.tar.gz" "$(basename "$OUTPUT_DIR")"

SIZE=$(du -h "wine-${WINE_VERSION}-darwin-${PLATFORM_ARCH}.tar.gz" | cut -f1)
echo "✅ Done! (${SIZE})"