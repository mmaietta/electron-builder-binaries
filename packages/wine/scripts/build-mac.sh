#!/usr/bin/env bash
set -ex

WINE_VERSION=${WINE_VERSION:-11.0}
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

############################################
# 🧪 DLL TRACE
############################################

TRACE_EXES="
/Users/mikemaietta/Downloads/nsis-bundle/windows/makensis.exe
/Users/mikemaietta/Downloads/nsis-bundle/windows/Bin/makensis.exe
/Users/mikemaietta/Downloads/nsis-bundle/windows/Bin/zip2exe.exe
/Users/mikemaietta/Downloads/rcedit-windows-2_0_0/rcedit-x64.exe
/Users/mikemaietta/Downloads/win-codesign-windows-x64/bin/osslsigncode.exe
/Users/mikemaietta/Downloads/windows-kits-bundle-10_0_26100_0/x64/makecat.exe
/Users/mikemaietta/Downloads/windows-kits-bundle-10_0_26100_0/x64/pvk2pfx.exe
/Users/mikemaietta/Downloads/windows-kits-bundle-10_0_26100_0/x64/makecert.exe
/Users/mikemaietta/Downloads/windows-kits-bundle-10_0_26100_0/x64/signtool.exe
/Users/mikemaietta/Downloads/windows-kits-bundle-10_0_26100_0/x64/makeappx.exe
/Users/mikemaietta/Downloads/windows-kits-bundle-10_0_26100_0/x64/makepri.exe
"

echo "🧪 Tracing DLL loads"
TRACE_LOG="$BUILD_DIR/dll-trace.log"
: > "$TRACE_LOG"

export WINEDEBUG=+loaddll

echo "$TRACE_EXES" | while IFS= read exe; do
  [ -z "$exe" ] && continue
  echo "▶️ Running $exe"
  "$STAGE_DIR/bin/wine64" "$exe" || true
done 2>&1 | tee -a "$TRACE_LOG"

############################################
# 🧠 GENERATE ALLOW-LISTS
############################################

echo "🧠 Generating allow-lists"

SYS32_ALLOW="$BUILD_DIR/system32.allow"
WINE_ALLOW="$BUILD_DIR/wine.allow"

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
cd "$STAGE_DIR/lib/wine/${PLATFORM_ARCH}-windows"

for f in *.dll.so; do
  base="$(basename "$f" .dll.so)"
  if ! grep -qx "$base" "$WINE_ALLOW"; then
    rm -f "$f"
  fi
done

############################################
# 🔥 PRUNE PREFIX system32
############################################

echo "🔥 Pruning prefix system32"
cd "$WINEPREFIX/drive_c/windows/system32"

for f in *.dll; do
  lower="$(echo "$f" | tr 'A-Z' 'a-z')"
  if ! grep -qx "$lower" "$SYS32_ALLOW"; then
    rm -f "$f"
  fi
done

############################################
# 🧹 REMOVE BULK WINDOWS CONTENT
############################################

echo "🧹 Removing Windows bulk"
cd "$WINEPREFIX/drive_c/windows"

rm -rf \
  Installer \
  Microsoft.NET \
  mono \
  syswow64 \
  logs \
  inf \
  Temp \
  system32/gecko

############################################
# 🪓 STRIP BINARIES
############################################

echo "🪓 Stripping binaries"
find "$STAGE_DIR/bin" "$STAGE_DIR/lib" -type f -perm +111 -exec strip -x {} \; || true

############################################
# 📦 PACKAGE
############################################

echo "📦 Packaging archive"
mkdir -p "$OUTPUT_DIR"
cp -R "$STAGE_DIR/"* "$OUTPUT_DIR"

cd "$ROOT"
tar -cJf "wine-${WINE_VERSION}-darwin-${PLATFORM_ARCH}.tar.xz" "$(basename "$OUTPUT_DIR")"

echo "✅ DONE"
du -sh "wine-${WINE_VERSION}-darwin-${PLATFORM_ARCH}.tar.xz"
