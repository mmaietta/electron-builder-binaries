#!/usr/bin/env bash
set -euxo pipefail

# ----------------------------
# Configuration for ./assets build scripts
# ----------------------------
export OSSLSIGNCODE_VER="${OSSLSIGNCODE_VER:-2.9}"
export RCEDIT_VERSION="${RCEDIT_VERSION:-2.0.0}"
export PLATFORM_ARCH="${PLATFORM_ARCH:-x86_64}"
# ----------------------------

CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$CWD/out/win-codesign"

OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

if [ "$OS_TARGET" = "linux" ]; then
    echo "Detected Linux target."

    bash "$CWD/assets/build-linux.sh"
    
elif [ "$OS_TARGET" = "darwin" ]; then
    echo "Detected macOS target."

    bash "$CWD/assets/build-mac.sh"

else
    echo "Assuming Windows target."
    
    # ----------------------------
    # Download rcedit executables
    # ----------------------------
    mkdir -p "$OUTPUT_DIR/rcedit"
    curl -L "https://github.com/electron/rcedit/releases/download/v$RCEDIT_VERSION/rcedit-x64.exe" \
    -o "$OUTPUT_DIR/rcedit/rcedit-x64.exe"
    curl -L "https://github.com/electron/rcedit/releases/download/v$RCEDIT_VERSION/rcedit-x86.exe" \
    -o "$OUTPUT_DIR/rcedit/rcedit-x86.exe"
    # Append rcedit version info
    $OUTPUT_DIR/rcedit/rcedit-x64.exe "$OUTPUT_DIR/rcedit/rcedit-x64.exe" --get-version-string "FileVersion" >"$OUTPUT_DIR/rcedit/VERSION.txt"
    
    # ----------------------------
    # Download osslsigncode artifacts (Windows)
    # ----------------------------
    cd "$TMP_DIR"
    curl -L "https://github.com/mtrojnar/osslsigncode/releases/download/$OSSLSIGNCODE_VER/osslsigncode-$OSSLSIGNCODE_VER-windows-x64-mingw.zip" -o a.zip
    unzip a.zip -d a
    cp -r a/bin "$OUTPUT_DIR/osslsigncode/windows"
    rm -rf a a.zip
    # Write version info
    "$OUTPUT_DIR/osslsigncode/windows/osslsigncode.exe" --version >"$OUTPUT_DIR/osslsigncode/windows/VERSION.txt"
    
    # ----------------------------
    # Copy appx assets
    # ----------------------------
    cp -a "$CWD/assets/appxAssets" "$OUTPUT_DIR/appxAssets"
    node "$CWD/assets/appx.js"
fi
