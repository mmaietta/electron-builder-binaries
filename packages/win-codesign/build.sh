#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Configuration
# ----------------------------
OSSLSIGNCODE_VER=2.9
RCEDIT_VERSION=2.0.0
# ----------------------------

CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
OUTPUT_DIR="$CWD/out/win-codesign"

# Clean up and prepare output directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/osslsigncode"

OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

if [ "$OS_TARGET" = "linux" ]; then
    echo "Detected Linux target."
    # ----------------------------
    # Build and extract osslsigncode (Linux)
    # ----------------------------
    docker build \
        --build-arg OSSLSIGNCODE_VER="$OSSLSIGNCODE_VER" \
        -f "$CWD/assets/Dockerfile" \
        -t osslsigncode-builder .

    docker create --name osslsigncode-container osslsigncode-builder
    docker cp osslsigncode-container:/osslsigncode-"$OSSLSIGNCODE_VER"-linux-static.7z .
    docker rm osslsigncode-container

    # Extract the Linux archive to output
    7za x "osslsigncode-$OSSLSIGNCODE_VER-linux-static.7z" -o"$OUTPUT_DIR/osslsigncode"
    rm "osslsigncode-$OSSLSIGNCODE_VER-linux-static.7z"

elif [ "$OS_TARGET" = "darwin" ]; then
    echo "Detected MacOS target."
    # ----------------------------
    # Download and extract osslsigncode (macOS)
    # ----------------------------
    cd "$TMP_DIR"
    curl -L "https://github.com/mtrojnar/osslsigncode/releases/download/$OSSLSIGNCODE_VER/osslsigncode-$OSSLSIGNCODE_VER-macOS.zip" -o a.zip
    7za x a.zip -oa
    cp -a a/bin "$OUTPUT_DIR/osslsigncode/darwin"
    rm -rf a a.zip

    # Write version info
    chmod +x "$OUTPUT_DIR/osslsigncode/darwin/osslsigncode"
    "$OUTPUT_DIR/osslsigncode/darwin/osslsigncode" --version >"$OUTPUT_DIR/osslsigncode/darwin/VERSION.txt"

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


    cd "$TMP_DIR"
    curl -L "https://github.com/mtrojnar/osslsigncode/releases/download/$OSSLSIGNCODE_VER/osslsigncode-$OSSLSIGNCODE_VER-windows-x64-mingw.zip" -o a.zip
    7za x a.zip -oa
    cp -a a/bin "$OUTPUT_DIR/osslsigncode/windows"
    rm -rf a a.zip
    chmod +x "$OUTPUT_DIR/osslsigncode/windows/osslsigncode.exe"
    # Write version info
    $OUTPUT_DIR/rcedit/rcedit-x64.exe "$OUTPUT_DIR/osslsigncode/windows/osslsigncode.exe" --get-version-string "FileVersion" >"$OUTPUT_DIR/osslsigncode/windows/VERSION.txt"

    # ----------------------------
    # Copy appx assets
    # ----------------------------
    cp -a "$CWD/assets/appxAssets" "$OUTPUT_DIR/appxAssets"
    node "$CWD/assets/appx.js"
fi
