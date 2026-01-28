#!/usr/bin/env bash
set -ex

############################################
# CONFIG
############################################

WINE_VERSION=11.0
ARCH=x86_64

ROOT="$(pwd)"
BUILD="$ROOT/build"
SRC="$BUILD/src"
INSTALL="$BUILD/install"
PREFIX="$INSTALL/wine-home"
OUT="$ROOT/wine2-${WINE_VERSION}-darwin-${ARCH}"

JOBS="$(sysctl -n hw.ncpu)"

# EXEs TO TRACE (newline-separated for bash 3.2)
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

############################################
# CLEAN
############################################

echo "🧹 Cleaning"
rm -rf "$BUILD" "$OUT"
mkdir -p "$SRC" "$INSTALL"

############################################
# FETCH WINE
############################################

echo "🍷 Fetching Wine $WINE_VERSION"
cd "$SRC"
curl -LO "https://dl.winehq.org/wine/source/11.0/wine-${WINE_VERSION}.tar.xz"
tar xf "wine-${WINE_VERSION}.tar.xz"
cd "wine-${WINE_VERSION}"

############################################
# ENV (FreeType REQUIRED)
############################################

export PKG_CONFIG_PATH="$(brew --prefix freetype)/lib/pkgconfig"
export CC=clang
export CXX=clang++

############################################
# CONFIGURE
############################################

echo "⚙️ Configuring Wine"
./configure \
  --enable-win64 \
  --disable-tests \
  --without-alsa \
  --without-capi \
  --without-dbus \
  --without-oss \
  --without-pulse \
  --without-udev \
  --without-v4l2 \
  --without-x \
  --prefix="$INSTALL"

############################################
# BUILD + INSTALL
############################################

echo "🔨 Building Wine"
make -j"$JOBS"
make install

############################################
# INIT PREFIX
############################################

echo "🍇 Initializing Wine prefix"
export WINEPREFIX="$PREFIX"
export WINEARCH=win64
"$INSTALL/bin/wine64" wineboot --init

############################################
# 🧪 DLL TRACE
############################################

echo "🧪 Tracing DLL loads"
TRACE_LOG="$BUILD/dll-trace.log"
: > "$TRACE_LOG"

export WINEDEBUG=+loaddll

echo "$TRACE_EXES" | while IFS= read exe; do
  [ -z "$exe" ] && continue
  echo "▶️ Running $exe"
  "$INSTALL/bin/wine64" "$exe" || true
done 2>&1 | tee -a "$TRACE_LOG"

############################################
# 🧠 GENERATE ALLOW-LISTS
############################################

echo "🧠 Generating allow-lists"

SYS32_ALLOW="$BUILD/system32.allow"
WINE_ALLOW="$BUILD/wine.allow"

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
cd "$INSTALL/lib/wine/${ARCH}-windows"

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
cd "$PREFIX/drive_c/windows/system32"

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
cd "$PREFIX/drive_c/windows"

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
find "$INSTALL/bin" "$INSTALL/lib" -type f -perm +111 -exec strip -x {} \; || true

############################################
# 📦 PACKAGE
############################################

echo "📦 Packaging archive"
mkdir -p "$OUT"
cp -R "$INSTALL/"* "$OUT"

cd "$ROOT"
tar -cJf "wine-${WINE_VERSION}-darwin-${ARCH}.tar.xz" "$(basename "$OUT")"

echo "✅ DONE"
du -sh "wine-${WINE_VERSION}-darwin-${ARCH}.tar.xz"
