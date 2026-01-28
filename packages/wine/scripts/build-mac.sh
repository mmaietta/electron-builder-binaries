#!/usr/bin/env bash
set -ex

WINE_VERSION=${WINE_VERSION:-9.0}
BUILD_DIR=${BUILD_DIR:-$(pwd)/build}
PLATFORM_ARCH="x86_64"

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

HOST_ARCH=$(arch)

if [ "$HOST_ARCH" = 'arm64' ]; then
    echo "🔄 ARM64 - building x86_64 via Rosetta"
    ARCH_CMD='arch -x86_64'
    export SDKROOT="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
else
    echo "🍺 Intel - building x86_64"
    ARCH_CMD=
fi

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

if [ ! -d "$SOURCE_DIR" ]; then
    echo "📂 Extracting..."
    tar -xJf "$ARCHIVE" -C "$BUILD_DIR"
fi

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
    --without-freetype

echo "🔨 Building..."
execute_cmd make -j$(sysctl -n hw.ncpu)

echo "📦 Installing..."
execute_cmd make install

cd "$STAGE_DIR"
rm -rf share/man share/applications include

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
cd bin
for binary in wine64 wine wineserver wineboot winecfg; do
    [ -f "$binary" ] && add_rpath_if_missing "$binary" "@executable_path/../lib"
done
cd ..

echo "🍇 Initializing Wine prefix..."
export WINEPREFIX="$STAGE_DIR/wine-home"
export WINEARCH=win64
export WINEDEBUG=-all
execute_cmd ./bin/wineboot --init
sleep 2

echo "🧹 Cleaning..."
rm -rf wine-home/drive_c/windows/Installer
rm -rf wine-home/drive_c/windows/Microsoft.NET
rm -rf wine-home/drive_c/windows/mono
rm -rf wine-home/drive_c/windows/system32/gecko
rm -rf wine-home/drive_c/windows/syswow64/gecko
rm -rf wine-home/drive_c/windows/logs
rm -rf wine-home/drive_c/windows/inf

echo "🧹🧹🧹 AGGRESSIVE PRUNING MODE ENABLED 🧹🧹🧹"

cd "$STAGE_DIR"

echo "❌ Removing headers, docs, manpages"
rm -rf include share/man share/doc share/gtk-doc

echo "❌ Removing Wine dev helpers"
rm -rf bin/function_grep.pl
rm -rf bin/winemaker

echo "❌ Removing unused Wine tools"
rm -rf bin/winecfg
rm -rf bin/wineconsole
rm -rf bin/winefile

echo "🔥 Removing *ALL* Windows GUI stacks"
rm -rf lib/wine/*-windows
rm -rf lib/wine/*/d3d*
rm -rf lib/wine/*/opengl*
rm -rf lib/wine/*/vulkan*

echo "🔥 Removing printing, audio, video"
rm -rf lib/wine/*/winspool.drv*
rm -rf lib/wine/*/winepulse*
rm -rf lib/wine/*/winealsa*
rm -rf lib/wine/*/qcap*
rm -rf lib/wine/*/mf*

echo "🍷 Trimming Wine prefix HARD"
cd wine-home/drive_c/windows

rm -rf Installer
rm -rf Microsoft.NET
rm -rf mono
rm -rf logs
rm -rf inf
rm -rf system32/gecko
rm -rf syswow64/gecko

echo "🔥 Removing unused system32 DLLs"
find system32 -type f ! -name 'kernel32.dll' \
                        ! -name 'ntdll.dll' \
                        ! -name 'user32.dll' \
                        ! -name 'advapi32.dll' \
                        ! -name 'shell32.dll' \
                        ! -name 'shlwapi.dll' \
                        ! -name 'ole32.dll' \
                        ! -name 'oleaut32.dll' \
                        ! -name 'msvcrt.dll' \
                        -delete || true

rm -rf syswow64 || true

cd "$STAGE_DIR"

echo "🪓 Stripping binaries"
find bin lib -type f -perm +111 -exec strip -x {} \; || true

echo "📉 Final size"
du -sh "$STAGE_DIR"

rm -rf "$OUTPUT_DIR"
cp -R "$STAGE_DIR" "$OUTPUT_DIR"

cat > "$OUTPUT_DIR/wine-launcher.sh" << 'LAUNCHER_EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export WINEPREFIX="${WINEPREFIX:-$SCRIPT_DIR/wine-home}"
export WINEDEBUG="${WINEDEBUG:--all}"
export DYLD_LIBRARY_PATH="$SCRIPT_DIR/lib:${DYLD_LIBRARY_PATH:-}"
exec "$SCRIPT_DIR/bin/wine64" "$@"
LAUNCHER_EOF
chmod +x "$OUTPUT_DIR/wine-launcher.sh"

cat > "$OUTPUT_DIR/README.md" << README_EOF
# Wine ${WINE_VERSION} - macOS x86_64

Built $(date) without FreeType (fonts work via fallback)

## Usage
\`\`\`bash
./wine-launcher.sh notepad
./wine-launcher.sh your-app.exe
\`\`\`
README_EOF

echo "🗜️ Creating compressed archive (XZ)…"
cd "$BUILD_DIR"
tar -cJf "wine-${WINE_VERSION}-darwin-${PLATFORM_ARCH}.tar.xz" "$(basename "$OUTPUT_DIR")"

echo "✅ Final archive size:"
ls -lh "wine-${WINE_VERSION}-darwin-${PLATFORM_ARCH}.tar.xz"
