#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Windows NSIS Base Bundle Builder (Cross-Platform)
# =============================================================================
# Downloads official pre-built NSIS for Windows and packages with plugins
# This creates the BASE bundle with Windows binary and all shared data
# Runs on Linux/Mac/Windows via bash
# =============================================================================

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUT_DIR="$BASE_DIR/out/nsis"
TEMP_DIR="$OUT_DIR/temp"

# Version configuration
NSIS_VERSION=${NSIS_VERSION:-3.10}
NSIS_BRANCH=${NSIS_BRANCH_OR_COMMIT:-v310}

BUNDLE_DIR="$OUT_DIR/nsis-bundle"
OUTPUT_ARCHIVE="$OUT_DIR/nsis-bundle-base-$NSIS_BRANCH.tar.gz"

echo "📦 Building NSIS Base Bundle..."
echo "   Version: $NSIS_VERSION"
echo "   Branch:  $NSIS_BRANCH"
echo ""

# =============================================================================
# Setup Directories
# =============================================================================

echo "🧹 Setting up directories..."
rm -rf "$TEMP_DIR" "$BUNDLE_DIR"
mkdir -p "$TEMP_DIR" "$BUNDLE_DIR/windows" "$BUNDLE_DIR/share"

# =============================================================================
# Check Dependencies
# =============================================================================

if ! command -v curl &> /dev/null; then
    echo "❌ curl is required but not installed"
    exit 1
fi

if ! command -v tar &> /dev/null; then
    echo "❌ tar is required but not installed"
    exit 1
fi

# =============================================================================
# Download Official NSIS
# =============================================================================

echo ""
echo "📥 Downloading official NSIS $NSIS_VERSION from SourceForge..."

NSIS_ZIP_URL="https://sourceforge.net/projects/nsis/files/NSIS%203/$NSIS_VERSION/nsis-$NSIS_VERSION.zip/download"
NSIS_ZIP="$TEMP_DIR/nsis-$NSIS_VERSION.zip"

if ! curl -L "$NSIS_ZIP_URL" -o "$NSIS_ZIP" --progress-bar; then
    echo "❌ Failed to download NSIS"
    exit 1
fi

echo "  ✓ Downloaded $(du -h "$NSIS_ZIP" | cut -f1)"

# =============================================================================
# Extract NSIS
# =============================================================================

echo ""
echo "📂 Extracting NSIS..."

if ! unzip -q "$NSIS_ZIP" -d "$TEMP_DIR"; then
    echo "❌ Failed to extract NSIS"
    exit 1
fi

NSIS_EXTRACTED="$TEMP_DIR/nsis-$NSIS_VERSION"

if [ ! -d "$NSIS_EXTRACTED" ]; then
    echo "❌ NSIS directory not found after extraction"
    exit 1
fi

# =============================================================================
# Copy Windows Binaries
# =============================================================================

echo ""
echo "📋 Copying Windows binaries..."

# Copy Windows binaries - THIS IS THE KEY PART
# Copy the ACTUAL makensis.exe and ALL its dependencies
cp -r ${NSIS_EXTRACTED}/Bin/* "$BUNDLE_DIR/windows/"
cp ${NSIS_EXTRACTED}/*.dll "$BUNDLE_DIR/windows/" 2>/dev/null || true
cp ${NSIS_EXTRACTED}/nsisconf.nsh "$BUNDLE_DIR/windows/" 2>/dev/null || true

# Copy share directory (Contrib, Include, Plugins, Stubs)
cp -r ${NSIS_EXTRACTED}/Contrib "$BUNDLE_DIR/share/nsis/"
cp -r ${NSIS_EXTRACTED}/Include "$BUNDLE_DIR/share/nsis/"
cp -r ${NSIS_EXTRACTED}/Plugins "$BUNDLE_DIR/share/nsis/"
cp -r ${NSIS_EXTRACTED}/Stubs "$BUNDLE_DIR/share/nsis/"

echo "  ✓ Windows makensis.exe"

# =============================================================================
# Copy NSIS Data Files
# =============================================================================

echo ""
echo "📚 Copying NSIS data files..."

for item in Contrib Include Plugins Stubs; do
    # if [ -d "$NSIS_EXTRACTED/$item" ]; then
        echo "  → $item/"
        mkdir -p "$BUNDLE_DIR/share/nsis/$item"
        cp -r "$NSIS_EXTRACTED/$item" "$BUNDLE_DIR/share/nsis/"
    # fi
done

# Remove unnecessary files
rm -rf "$BUNDLE_DIR/share/nsis/Contrib/Graphics/Checks" \
       "$BUNDLE_DIR/share/nsis/Contrib/Graphics/Header" \
       2>/dev/null || true

# =============================================================================
# Download Additional Plugins
# =============================================================================

echo ""
echo "🔌 Downloading additional plugins..."

PLUGINS_DIR="$TEMP_DIR/plugins"
mkdir -p "$PLUGINS_DIR"

declare -a PLUGIN_NAMES=(
    "NsProcess"
    "UAC"
    "WinShell"
    "NsJSON"
    "NsArray"
    "INetC"
    "NsisMultiUser"
    "StdUtils"
)

declare -a PLUGIN_URLS=(
    "https://nsis.sourceforge.io/mediawiki/images/1/18/NsProcess.zip"
    "https://nsis.sourceforge.io/mediawiki/images/8/8f/UAC.zip"
    "https://nsis.sourceforge.io/mediawiki/images/5/54/WinShell.zip"
    "https://nsis.sourceforge.io/mediawiki/images/5/5a/NsJSON.zip"
    "https://nsis.sourceforge.io/mediawiki/images/4/4c/NsArray.zip"
    "https://nsis.sourceforge.io/mediawiki/images/c/c9/Inetc.zip"
    "https://nsis.sourceforge.io/mediawiki/images/5/5d/NsisMultiUser.zip"
    "https://nsis.sourceforge.io/mediawiki/images/d/d2/StdUtils.2020-10-23.zip"
)

DOWNLOADED_COUNT=0

for i in "${!PLUGIN_NAMES[@]}"; do
    plugin_name="${PLUGIN_NAMES[$i]}"
    plugin_url="${PLUGIN_URLS[$i]}"
    plugin_zip="$PLUGINS_DIR/${plugin_name}.zip"
    
    echo "  → $plugin_name"
    
    if curl -sL "$plugin_url" -o "$plugin_zip"; then
        ((DOWNLOADED_COUNT++)) || true
    else
        echo "    ⚠️  Failed to download"
    fi
done

echo "  ✓ Downloaded $DOWNLOADED_COUNT plugins"

# =============================================================================
# Install Plugins
# =============================================================================

echo ""
echo "🔧 Installing plugins..."

# Determine extraction tool
if command -v 7z &> /dev/null; then
    EXTRACT_CMD="7z x -y"
elif command -v 7za &> /dev/null; then
    EXTRACT_CMD="7za x -y"
else
    EXTRACT_CMD="unzip -oq"
fi

for plugin_zip in "$PLUGINS_DIR"/*.zip; do
    [ -f "$plugin_zip" ] || continue
    
    plugin_name=$(basename "$plugin_zip" .zip)
    extract_dir="$PLUGINS_DIR/$plugin_name"
    
    mkdir -p "$extract_dir"
    
    # Extract (suppress output)
    if [[ "$EXTRACT_CMD" == "unzip"* ]]; then
        $EXTRACT_CMD "$plugin_zip" -d "$extract_dir" 2>/dev/null || true
    else
        $EXTRACT_CMD "$plugin_zip" -o"$extract_dir" >/dev/null 2>&1 || true
    fi
    
    # Install DLL files
    find "$extract_dir" -type f -name "*.dll" 2>/dev/null | while read -r dll_file; do
        relative_path=$(dirname "${dll_file#$extract_dir}")
        
        case "$relative_path" in
            *x86-ansi*|*/ansi/*|*/Ansi/*)
                mkdir -p "$BUNDLE_DIR/share/nsis/Plugins/x86-ansi"
                cp "$dll_file" "$BUNDLE_DIR/share/nsis/Plugins/x86-ansi/" 2>/dev/null || true
                ;;
            *x86-unicode*|*/unicode/*|*/Unicode/*)
                mkdir -p "$BUNDLE_DIR/share/nsis/Plugins/x86-unicode"
                cp "$dll_file" "$BUNDLE_DIR/share/nsis/Plugins/x86-unicode/" 2>/dev/null || true
                ;;
            *)
                # Determine by filename
                if [[ "$(basename "$dll_file")" =~ W\.dll$ ]] || [[ "$(basename "$dll_file")" =~ Unicode ]]; then
                    mkdir -p "$BUNDLE_DIR/share/nsis/Plugins/x86-unicode"
                    cp "$dll_file" "$BUNDLE_DIR/share/nsis/Plugins/x86-unicode/" 2>/dev/null || true
                else
                    mkdir -p "$BUNDLE_DIR/share/nsis/Plugins/x86-ansi"
                    cp "$dll_file" "$BUNDLE_DIR/share/nsis/Plugins/x86-ansi/" 2>/dev/null || true
                fi
                ;;
        esac
    done
    
    # Install header files
    find "$extract_dir" -type f -name "*.nsh" 2>/dev/null | while read -r nsh_file; do
        cp "$nsh_file" "$BUNDLE_DIR/share/nsis/Include/" 2>/dev/null || true
    done
    
    find "$extract_dir" -type f -name "*.nsi" \
        ! -iname '*example*' \
        ! -iname '*test*' \
        ! -iname '*demo*' \
        2>/dev/null | while read -r nsi_file; do
        cp "$nsi_file" "$BUNDLE_DIR/share/nsis/Include/" 2>/dev/null || true
    done
    
    echo "  ✓ $plugin_name"
done

# =============================================================================
# Apply Language File Patches
# =============================================================================

echo ""
echo "🔧 Applying language file patches..."

FIXES_DIR="$BASE_DIR/assets/nsis-lang-fixes"
LANG_FILES_DIR="$BUNDLE_DIR/share/nsis/Contrib/Language files"

PATCHED_COUNT=0
ls -1 "$LANG_FILES_DIR"/*.n* >/dev/null 2>&1 || {
    echo "  ⚠️  No language files found to patch"
    exit 1
}
for fixfile in "$FIXES_DIR"/*; do
    [ -f "$fixfile" ] || continue
    
    fname=$(basename "$fixfile")
    target="$LANG_FILES_DIR/$fname"
    
    if [ -f "$target" ]; then
        echo "  → Patching $fname"
        {
            echo ""
            echo ""
            echo "; --- BEGIN FIXES ADDED ---"
            echo ""
            cat "$fixfile"
            echo ""
            echo "; --- END FIXES ADDED ---"
            echo ""
        } >> "$target"
        ((PATCHED_COUNT++)) || true
    fi
done

if [ $PATCHED_COUNT -gt 0 ]; then
    echo "  ✓ Patched $PATCHED_COUNT language files"
else
    echo "  ⚠️  No language files to patch"
    exit 1
fi

# =============================================================================
# Create Version Metadata
# =============================================================================

cat > "$BUNDLE_DIR/windows/VERSION.txt" <<EOF
Platform: Windows
Binary: makensis.exe (official pre-built)
Architecture: x86 (runs on all Windows via WoW64)
EOF

# =============================================================================
# Create Archive
# =============================================================================

echo ""
echo "📦 Creating base bundle archive..."

cd "$OUT_DIR"
tar -czf "${OUTPUT_ARCHIVE}" nsis-bundle

# =============================================================================
# Cleanup
# =============================================================================

rm -rf "$TEMP_DIR"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "================================================================"
echo "  ✅ Base Bundle Complete!"
echo "================================================================"
echo "  📁 Archive: $OUTPUT_ARCHIVE"
echo "  📊 Size:    $(du -h "$OUTPUT_ARCHIVE" | cut -f1)"

if [ -d "$BUNDLE_DIR/share/nsis/Plugins" ]; then
    plugin_count=$(find "$BUNDLE_DIR/share/nsis/Plugins" -name "*.dll" 2>/dev/null | wc -l | xargs)
    echo "  🔌 Plugins: $plugin_count DLLs"
fi

echo "================================================================"
echo ""
