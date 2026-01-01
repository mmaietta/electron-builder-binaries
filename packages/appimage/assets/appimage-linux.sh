#!/bin/bash

set -eo pipefail

SQUASHFS_TOOLS_VERSION_TAG=${SQUASHFS_TOOLS_VERSION_TAG:-"4.6.1"}
DESKTOP_UTILS_DEPS_VERSION_TAG=${DESKTOP_UTILS_DEPS_VERSION_TAG:-"0.28"}

ROOT=$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)

# Check if buildx is available
if ! docker buildx version &> /dev/null; then
    echo "❌ Error: Docker buildx is not available"
    echo "Please install Docker buildx or use Docker Desktop which includes it"
    exit 1
fi

DEST="${DEST:-$ROOT/out/build}"
TMP_DOCKER_CONTEXT="/tmp/appimage-docker-context"
TEMP_DIR="/tmp/appimage-build-linux"

cleanup() {
    docker buildx rm appimage-builder || true
    echo "Cleaning up temporary directories..."
    rm -rf "$TEMP_DIR" "$TMP_DOCKER_CONTEXT"
}
trap 'errorCode=$?; echo "Error $errorCode at command: $BASH_COMMAND"; cleanup; exit $errorCode' ERR

echo "🏗️  Preparing build environment..."
cleanup
mkdir -p "$TEMP_DIR" "$TMP_DOCKER_CONTEXT"

# Create a new builder instance if it doesn't exist
echo "🏗️  Creating buildx builder instance..."
docker buildx create --name appimage-builder
docker buildx use appimage-builder

# Build all Linux architectures
echo ""
echo "🚀 Building for amd64, arm64, armv7, i386 platforms..."
docker buildx build \
    --platform   "linux/amd64,linux/arm64,linux/arm/v7,linux/386" \
    --build-arg  DESKTOP_UTILS_DEPS_VERSION_TAG="$DESKTOP_UTILS_DEPS_VERSION_TAG" \
    --build-arg  SQUASHFS_TOOLS_VERSION_TAG="$SQUASHFS_TOOLS_VERSION_TAG" \
    --cache-from type=local,src=.buildx-cache \
    --cache-to   type=local,dest=.buildx-cache,mode=max \
    --output     type=local,dest="${TMP_DOCKER_CONTEXT}" \
    -f           "$ROOT/assets/Dockerfile" \
    $ROOT

echo ""
echo "📦 Extracting all tarballs..."

# Find and extract all .tar.gz files to TMP_DIR root
find "${TMP_DOCKER_CONTEXT}" -name "*.tar.gz" -type f | while read -r tarfile; do
    echo "  Extracting $(basename "$tarfile")..."
    tar -xzf "$tarfile" -C "${TEMP_DIR}"
    rm -f "$tarfile"
done


echo "✅ All builds completed and extracted"

# Verify executables have correct permissions
echo "🔐 Verifying executable permissions..."
chmod +x $TEMP_DIR/linux/x64/mksquashfs \
    $TEMP_DIR/linux/x64/desktop-file-validate \
    $TEMP_DIR/linux/x64/opj_decompress \
    $TEMP_DIR/linux/ia32/mksquashfs \
    $TEMP_DIR/linux/ia32/desktop-file-validate \
    $TEMP_DIR/linux/arm64/mksquashfs \
    $TEMP_DIR/linux/arm64/desktop-file-validate \
    $TEMP_DIR/linux/arm64/opj_decompress \
    $TEMP_DIR/linux/arm32/mksquashfs \
    $TEMP_DIR/linux/arm32/desktop-file-validate

echo "✅ Executable permissions set"

# =============================================================================
# CREATE GENERIC APPIMAGE TOOL WRAPPER
# =============================================================================
echo ""
echo "🔨 Creating generic AppImage tool wrapper with debug support..."

cat <<'EOF' >"$TEMP_DIR/appimage-tool"
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared runtime selector
source "$ROOT_DIR/select-runtime.env"

# Determine tool name
INVOKED_AS="$(basename "$0")"

if [[ "$INVOKED_AS" == "appimage-tool" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage:"
        echo "  appimage-tool <tool-name> [args...]"
        exit 1
    fi
    TOOL_NAME="$1"
    shift
else
    TOOL_NAME="$INVOKED_AS"
fi

BIN="$APPIMAGE_TOOLS_DIR/$TOOL_NAME"

if [[ ! -x "$BIN" ]]; then
    echo "Tool not found or not executable:"
    echo "   $BIN"
    echo
    echo "Available tools:"
    ls -1 "$APPIMAGE_TOOLS_DIR" 2>/dev/null || true
    exit 1
fi

# Debug mode
if [[ "${1:-}" == "--debug" || "${1:-}" == "-d" ]]; then
    echo "=== AppImage Tool Debug Info ==="
    echo "Tool name:        $TOOL_NAME"
    echo "Binary path:      $BIN"
    echo "Platform:         $APPIMAGE_TOOLS_PLATFORM"
    echo "Architecture:     $APPIMAGE_TOOLS_ARCH"
    echo "Runtime dir:      $APPIMAGE_TOOLS_DIR"
    echo "Library dir:      $APPIMAGE_TOOLS_LIBDIR"
    if [[ "$APPIMAGE_TOOLS_PLATFORM" == "darwin" ]]; then
        echo "DYLD_LIBRARY_PATH: $DYLD_LIBRARY_PATH"
    else
        echo "LD_LIBRARY_PATH:   $LD_LIBRARY_PATH"
    fi
    echo "Executable file info:"
    file "$BIN"
    echo "Dynamic libs:"
    if [[ "$APPIMAGE_TOOLS_PLATFORM" == "darwin" ]]; then
        otool -L "$BIN" || true
    else
        ldd "$BIN" || true
    fi
    exit 0
fi

# Execute normally
exec "$BIN" "$@"
EOF

chmod +x "$TEMP_DIR/appimage-tool"
ln -sf appimage-tool "$TEMP_DIR/mksquashfs"
ln -sf appimage-tool "$TEMP_DIR/desktop-file-validate"

# =========================
# select-runtime.env
# =========================
echo "  ✏️  select-runtime.env"
cat <<'EOF' >"$TEMP_DIR/select-runtime.env"
#!/usr/bin/env bash
# Shared AppImage tools runtime selector

set -euo pipefail

TOOLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
    APPIMAGE_TOOLS_PLATFORM="darwin"
    case "$(uname -m)" in
        x86_64)  APPIMAGE_TOOLS_ARCH="x64" ;;
        arm64|aarch64) APPIMAGE_TOOLS_ARCH="arm64" ;;
        *)
            echo "❌ Unsupported Darwin architecture: $(uname -m)" >&2
            return 1
            ;;
    esac
else
    APPIMAGE_TOOLS_PLATFORM="linux"
    case "$(uname -m)" in
        x86_64)  APPIMAGE_TOOLS_ARCH="x64" ;;
        aarch64) APPIMAGE_TOOLS_ARCH="arm64" ;;
        armv7l|armv6l) APPIMAGE_TOOLS_ARCH="arm32" ;;
        i686|i386) APPIMAGE_TOOLS_ARCH="ia32" ;;
        *)
            echo "❌ Unsupported Linux architecture: $(uname -m)" >&2
            return 1
            ;;
    esac
fi

APPIMAGE_TOOLS_DIR="$TOOLS_ROOT/$APPIMAGE_TOOLS_PLATFORM/$APPIMAGE_TOOLS_ARCH"
APPIMAGE_TOOLS_LIBDIR="$APPIMAGE_TOOLS_DIR/lib"

if [[ ! -d "$APPIMAGE_TOOLS_DIR" ]]; then
    echo "❌ AppImage tools directory not found:"
    echo "   $APPIMAGE_TOOLS_DIR"
    return 1
fi

if [[ "$APPIMAGE_TOOLS_PLATFORM" == "darwin" ]]; then
    export DYLD_LIBRARY_PATH="$APPIMAGE_TOOLS_LIBDIR${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
else
    export LD_LIBRARY_PATH="$APPIMAGE_TOOLS_LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

export APPIMAGE_TOOLS_PLATFORM
export APPIMAGE_TOOLS_ARCH
export APPIMAGE_TOOLS_DIR
export APPIMAGE_TOOLS_LIBDIR
EOF

chmod +x "$TEMP_DIR/select-runtime.env"
echo "✅ Generic AppImage tool wrapper created"

echo ""
echo "✨ Extraction complete!"
echo ""
echo "📂 Directory structure:"
tree $TEMP_DIR -L 4 2>/dev/null || find $TEMP_DIR -type f -maxdepth 4

echo ""
echo "Creating tar.gz archive of all builds..."
ARCHIVE_NAME="appimage-tools-linux-all-architectures.tar.gz"
(
    cd "$TEMP_DIR"
    tar czf "$DEST/$ARCHIVE_NAME" .
)
echo "✓ Archive created: $DEST/$ARCHIVE_NAME"

cleanup

echo ""
echo "🎉 Done!"