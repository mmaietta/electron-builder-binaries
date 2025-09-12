#!/usr/bin/env bash
set -euo pipefail

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=$BASEDIR/out/nsis
VERSION="${VERSION:-3.11}"
ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"
BUNDLE_DIR="$OUT_DIR/nsis-bundle"

TMP_DIR="$OUT_DIR/tmp-merge"

# ----------------------
echo "🧹 Cleaning up old merge..."
rm -rf "$BUNDLE_DIR" "$TMP_DIR"
mkdir -p "$TMP_DIR" "$BUNDLE_DIR"

# ----------------------
# Find and extract all nsis-bundle-*.7z archives
# ----------------------
shopt -s nullglob
ARCHIVES=("$OUT_DIR"/nsis-bundle-*.7z)

if [ ${#ARCHIVES[@]} -eq 0 ]; then
  echo "❌ No nsis-bundle-*.7z archives found in $OUT_DIR"
  exit 1
fi

echo "📦 Found ${#ARCHIVES[@]} archives:"
printf '  - %s\n' "${ARCHIVES[@]}"

i=0
for ARCHIVE in "${ARCHIVES[@]}"; do
  i=$((i+1))
  DEST="$TMP_DIR/extracted-$i"
  echo "📂 Extracting $ARCHIVE → $DEST"
  7z x -y "$ARCHIVE" -o"$DEST"
  rm -f "$ARCHIVE"
done

# ----------------------
# Merge into nsis-bundle
# ----------------------
echo "🔗 Merging extracted bundles..."

for DIR in "$TMP_DIR"/extracted-*; do
  if [ -d "$DIR/nsis-bundle" ]; then
    cp -a "$DIR/nsis-bundle/." "$BUNDLE_DIR/"
  else
    echo "⚠️ $DIR does not contain nsis-bundle/"
    exit 1
  fi
done

# ----------------------
# Verify
# ----------------------
echo "📂 Final nsis-bundle structure:"
if command -v tree >/dev/null 2>&1; then
  tree -L 3 "$BUNDLE_DIR"
else
  ls -R "$BUNDLE_DIR"
fi

rm -rf "$TMP_DIR"
echo "✅ Done! Combined bundle is at $BUNDLE_DIR"

# ----------------------
# Patch language files so that warnings-as-errors can remain enabled
# ----------------------
echo "🩹 Adding patches to language files"
bash "$BASEDIR/assets/patch-language-files.sh"

# ----------------------
# Create wrapper script that auto-sets NSISDIR
# ----------------------
echo "🛠️  Creating makensis wrapper scripts...
"
# Linux/mac wrapper
cat > "${BUNDLE_DIR}/makensis" <<'EOF'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export NSISDIR="$DIR/share/nsis"
case "$(uname -s)" in
  Linux)  exec "$DIR/linux/makensis" "$@" ;;
  Darwin) exec "$DIR/mac/makensis" "$@" ;;
  *) echo "Unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac
EOF
chmod +x "${BUNDLE_DIR}/makensis"

# Windows CMD wrapper
cat > "${BUNDLE_DIR}/makensis.cmd" <<'EOF'
@echo off
REM NSIS Wrapper for Windows (cmd.exe)
set DIR=%~dp0
set DIR=%DIR:~0,-1%
set NSISDIR=%DIR%\share\nsis
"%DIR%\win32\Bin\makensis.exe" %*
EOF

# Windows PowerShell wrapper
cat > "${BUNDLE_DIR}/makensis.ps1" <<'EOF'
# NSIS Wrapper for Windows (PowerShell)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$env:NSISDIR = Join-Path $ScriptDir "share\nsis"
$Makensis = Join-Path $ScriptDir "win32\Bin\makensis.exe"
& $Makensis @args
exit $LASTEXITCODE
EOF

# ----------------------
# Write version metadata
# ----------------------
echo "📝 Writing version metadata..."
{
  echo "NSIS Version/Branch: ${VERSION}"
  echo "zlib Version: ${ZLIB_VERSION}"
  echo "Build Date (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Platforms Included:"
  [ -d "${BUNDLE_DIR}/linux" ]  && echo "  - linux"
  [ -d "${BUNDLE_DIR}/win32" ]  && echo "  - win32"
  [ -d "${BUNDLE_DIR}/win64" ]  && echo "  - win64"
  [ -d "${BUNDLE_DIR}/mac" ]    && echo "  - macos"
} > "${BUNDLE_DIR}/VERSION.txt"

# ----------------------
# Build archive name dynamically
# ----------------------
PLATFORMS=()
[ -d "${BUNDLE_DIR}/linux" ] && PLATFORMS+=("linux")
[ -d "${BUNDLE_DIR}/win32" ] && PLATFORMS+=("win32")
[ -d "${BUNDLE_DIR}/win64" ] && PLATFORMS+=("win64")
[ -d "${BUNDLE_DIR}/mac" ]   && PLATFORMS+=("macos")

PLATFORM_STR=$(IFS=-; echo "${PLATFORMS[*]}")
ARCHIVE_NAME="nsis-bundle-${PLATFORM_STR}-${VERSION}.7z"

echo "📦 Creating final archive $ARCHIVE_NAME..."
cd "${OUT_DIR}"
rm -f "$ARCHIVE_NAME"
7za a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=64m -ms=on -m0=BCJ2:- "$ARCHIVE_NAME" nsis-bundle
rm -rf "${BUNDLE_DIR}"

echo "✅ Done!"
echo "Bundle available at: ${OUT_DIR}/$ARCHIVE_NAME"
