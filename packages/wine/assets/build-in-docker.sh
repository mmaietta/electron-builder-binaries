#!/usr/bin/env bash
set -euo pipefail

# Enable command tracing
set -x

WINE_VERSION=${WINE_VERSION:-11.0}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR=${BUILD_DIR:-$ROOT_DIR/build}

# NOTE: update the checksums here as new versions are added
get_checksum() {
    case "$1" in
        11.0) echo "c07a6857933c1fc60dff5448d79f39c92481c1e9db5aa628db9d0358446e0701" ;;
        *) exit 1 ;;
    esac
}

PLATFORM_ARCH="x86_64"
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
HOST_ARCH=$(arch)

if [ "$HOST_ARCH" = 'arm64' ] && [ "$PLATFORM" = "darwin" ]; then
    echo "🔄 ARM64 - building x86_64 via Rosetta"
    ARCH_CMD='arch -x86_64'
    export SDKROOT="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
else
    echo "🍺 building x86_64"
    ARCH_CMD=''
fi

execute_cmd() {
    if [ -n "$ARCH_CMD" ]; then
        $ARCH_CMD "$@"
    else
        "$@"
    fi
}

if [ "$PLATFORM" = "darwin" ]; then
    echo "🍺 Ensuring Homebrew dependencies (brew bundle)"
    
    if ! command -v brew >/dev/null 2>&1; then
        echo "❌ Homebrew not found"
        exit 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/Brewfile" ]; then
        echo "❌ Brewfile not found"
        exit 1
    fi
    
    (
        cd "$SCRIPT_DIR"
        if ! brew bundle check; then
            echo "📦 Installing missing dependencies"
            brew bundle install
        else
            echo "🍻 Brewfile dependencies already satisfied"
        fi
    )
    
fi

CHECKSUM=$(get_checksum "$WINE_VERSION")
WINE_MAJOR=$(echo "$WINE_VERSION" | cut -d. -f1)
WINE_URL="https://dl.winehq.org/wine/source/${WINE_MAJOR}.0/wine-${WINE_VERSION}.tar.xz"

DOWNLOAD_DIR="$BUILD_DIR/downloads"
SOURCE_DIR="$BUILD_DIR/wine-${WINE_VERSION}"
BUILD_WINE_DIR="$BUILD_DIR/wine64-build"
STAGE_DIR="$BUILD_DIR/wine-stage"
OUTPUT_DIR="$BUILD_DIR/wine-${WINE_VERSION}-darwin-${PLATFORM_ARCH}"
TRACE_LOG="$BUILD_DIR/dll-trace.log"
SYS32_ALLOW="$BUILD_DIR/system32.allow"
WINE_ALLOW="$BUILD_DIR/wine.allow"

mkdir -p "$DOWNLOAD_DIR"

# Download and verify archive
ARCHIVE="$DOWNLOAD_DIR/wine-${WINE_VERSION}.tar.xz"
if [ ! -f "$ARCHIVE" ]; then
    echo "📥 Downloading Wine ${WINE_VERSION}..."
    curl -L --progress-bar "$WINE_URL" -o "$ARCHIVE"
    
    if [ -n "$CHECKSUM" ]; then
        ACTUAL=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
        if [ "$ACTUAL" != "$CHECKSUM" ]; then
            echo "❌ Checksum failed: expected $CHECKSUM, got $ACTUAL"
            exit 1
        fi
        echo "✅ Verified"
    fi
fi

# Extract source
if [ ! -d "$SOURCE_DIR" ]; then
    echo "📂 Extracting..."
    tar -xJf "$ARCHIVE" -C "$BUILD_DIR"
fi

# Configure Wine
echo "⚙️  Configuring Wine (without FreeType)..."
rm -rf "$BUILD_WINE_DIR" "$STAGE_DIR"
mkdir -p "$BUILD_WINE_DIR" "$STAGE_DIR"
cd "$BUILD_WINE_DIR"

execute_cmd "$SOURCE_DIR/configure" \
    --prefix="$STAGE_DIR" \
    --enable-win64 \
    --without-x \
    --without-cups \
    --without-dbus \
    --without-freetype \
    2>&1 | tee configure.log

if [ "$PLATFORM" = "darwin" ]; then
    # 🧠 Auto-update Brewfile if dependencies changed
    bash "$SCRIPT_DIR/generate-brewfile.sh" "$BUILD_WINE_DIR/config.log"
fi

echo "🔨 Building..."
execute_cmd make -j$(sysctl -n hw.ncpu)

echo "📦 Installing..."
execute_cmd make install

cd "$ROOT_DIR"

# Remove unnecessary directories
rm -rf "$STAGE_DIR/share/man"  "$STAGE_DIR/share/doc"  "$STAGE_DIR/share/gtk-doc" "$STAGE_DIR/include" "$STAGE_DIR/share/applications"

# Adjust RPATHs for all binaries
add_rpath_if_missing() {
    local binary="$1"
    local rpath="$2"
    
    echo "🔍 Checking RPATH in: $binary"
    
    # List existing rpaths
    if otool -l "$binary" | grep -A2 LC_RPATH | grep -q "$rpath"; then
        echo "✅ RPATH already present: $rpath — skipping 🛑"
        return 0
    fi
    
    echo "➕ Adding RPATH: $rpath"
    install_name_tool -add_rpath "$rpath" "$binary"
}

for binary in wine64 wine wineserver wineboot winecfg; do
    binary_path="$STAGE_DIR/bin/$binary"
    [ -f "$binary_path" ] && add_rpath_if_missing "$binary_path" "@executable_path/../lib"
done

# Initialize Wine prefix
echo "🍇 Initializing Wine prefix..."
export WINEPREFIX="$STAGE_DIR/wine-home"
export WINEARCH=win64
export WINEDEBUG=-all
export DISPLAY=:99  # Virtual display for headless

if [ "$PLATFORM" = "Darwin" ]; then
    execute_cmd "$STAGE_DIR/bin/wineboot" --init
    sleep 2
else

# Start a virtual X server if not running
if ! command -v Xvfb &> /dev/null; then
    echo "⚠️  Xvfb not available"
    exit 1
else
    Xvfb :99 -screen 0 1024x768x24 &
    XVFB_PID=$!
    sleep 2
    
    "$STAGE_DIR/bin/wineboot" --init
    sleep 2
    
    # Kill Xvfb
    kill $XVFB_PID
fi

############################################
# 🧪 DLL TRACE
############################################

echo "🧪 Generating DLL load traces"
TRACE_EXES_FILE=$(
    sh "$SCRIPT_DIR/generate-trace-exes.sh" \
    | grep '^EXE_LIST_FILE=' \
    | cut -d= -f2
)

echo "🧪 Tracing DLL loads"
: > "$TRACE_LOG"

export WINEDEBUG=+loaddll

while IFS= read -r exe; do
    [ -z "$exe" ] && continue
    echo "▶️ Tracing $exe"
    "$STAGE_DIR/bin/wine" "$exe" >> "$TRACE_LOG" 2>&1 || true
done < "$TRACE_EXES_FILE"

############################################
# 🧠 GENERATE ALLOW-LISTS
############################################

echo "🧠 Generating allow-lists"

# Extract system32 DLL names
grep -o 'system32\\\\[^"]*\.dll' "$TRACE_LOG" \
| sed 's|.*system32\\\\||' \
| tr 'A-Z' 'a-z' \
| sort -u > "$SYS32_ALLOW"

# Convert foo.dll → foo (for dll.so matching)
sed 's/\.dll$//' "$SYS32_ALLOW" \
| sort -u > "$WINE_ALLOW"

echo "✅ Allowed system32 DLLs:"
cat "$SYS32_ALLOW"

############################################
# 🔥 PRUNE lib/wine/*-windows
############################################

echo "🔥 Pruning Wine Windows DLLs"
WINE_WINDOWS_DIR="$STAGE_DIR/lib/wine/${PLATFORM_ARCH}-windows"

for f in "$WINE_WINDOWS_DIR"/*.dll.so; do
    [ ! -f "$f" ] && continue
    base="$(basename "$f" .dll.so)"
    if ! grep -qx "$base" "$WINE_ALLOW"; then
        rm -f "$f"
    fi
done

############################################
# 🔥 PRUNE PREFIX system32
############################################

echo "🔥 Pruning prefix system32"
SYSTEM32_DIR="$WINEPREFIX/drive_c/windows/system32"

for f in "$SYSTEM32_DIR"/*.dll; do
    [ ! -f "$f" ] && continue
    lower="$(basename "$f" | tr 'A-Z' 'a-z')"
    if ! grep -qx "$lower" "$SYS32_ALLOW"; then
        rm -f "$f"
    fi
done

############################################
# 🧹 REMOVE BULK WINDOWS CONTENT
############################################

echo "🧹 Removing Windows bulk"
WINDOWS_DIR="$WINEPREFIX/drive_c/windows"

rm -rf \
"$WINDOWS_DIR/Installer" \
"$WINDOWS_DIR/Microsoft.NET" \
"$WINDOWS_DIR/mono" \
"$WINDOWS_DIR/syswow64" \
"$WINDOWS_DIR/logs" \
"$WINDOWS_DIR/inf" \
"$WINDOWS_DIR/Temp" \
"$WINDOWS_DIR/system32/gecko"

############################################
# 🪓 STRIP BINARIES
############################################

echo "🪓 Stripping binaries"
find "$STAGE_DIR/bin" "$STAGE_DIR/lib" -type f -perm +111 -exec strip -x {} \; 2>/dev/null || true

############################################
# 📦 PACKAGE
############################################

echo "📦 Packaging archive"
mkdir -p "$OUTPUT_DIR"
cp -R "$STAGE_DIR/"* "$OUTPUT_DIR/"

tar -C "$BUILD_DIR" -cJf "$ROOT_DIR/wine-${WINE_VERSION}-${PLATFORM}-${PLATFORM_ARCH}.tar.xz" "$(basename "$OUTPUT_DIR")"

echo "✅ DONE"
du -sh "$ROOT_DIR/wine-${WINE_VERSION}-${PLATFORM}-${PLATFORM_ARCH}.tar.xz"
