#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Configuration
# ----------------------------
OSSLSIGNCODE_VER="${OSSLSIGNCODE_VER:-2.9}"
RCEDIT_VERSION="${RCEDIT_VERSION:-2.0.0}"
# ----------------------------

CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
OUTPUT_DIR="$CWD/out/win-codesign"

# Clean up and prepare output directory
mkdir -p "$OUTPUT_DIR/osslsigncode"

OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}

if [ "$OS_TARGET" = "linux" ]; then
    echo "Detected Linux target."
    
    cidFile="/tmp/wincodesign-linux-container-id"
    cleanup() {
        if test -f "$cidFile"; then
            containerId=$(cat "$cidFile")
            echo "Stopping docker container $containerId."
            docker rm "$containerId"
            unlink "$cidFile"
        fi
    }
    # check if previous docker containers are still running based off of container lockfile
    cleanup
    
    # cleanup docker container on error
    f() {
        errorCode=$? # save the exit code as the first thing done in the trap function
        echo "error $errorCode"
        echo "the command executing at the time of the error was"
        echo "$BASH_COMMAND"
        echo "on line ${BASH_LINENO[0]}"
        
        cleanup
        
        exit $errorCode
    }
    trap f ERR
    
    # ----------------------------
    # Build and extract osslsigncode (Linux)
    # ----------------------------
    DOCKER_TAG="osslsigncode-builder"
    
    docker build \
    --build-arg OSSLSIGNCODE_VER="$OSSLSIGNCODE_VER" \
    -f "$CWD/assets/Dockerfile" \
    -t ${DOCKER_TAG} .
    
    docker run --cidfile="$cidFile" $DOCKER_TAG
    containerId=$(cat "$cidFile")
    docker cp "$containerId":/osslsigncode-"$OSSLSIGNCODE_VER"-linux-static.7z .
    
    # Extract the Linux archive to output
    rm -rf "$OUTPUT_DIR/osslsigncode/linux"
    7za x "osslsigncode-$OSSLSIGNCODE_VER-linux-static.7z" -o"$OUTPUT_DIR/osslsigncode"
    rm "osslsigncode-$OSSLSIGNCODE_VER-linux-static.7z"
    chmod +x "$OUTPUT_DIR/osslsigncode/linux/osslsigncode"
    
    cleanup
    
    elif [ "$OS_TARGET" = "darwin" ]; then
    echo "Detected MacOS target."
    # ----------------------------
    # Download and extract osslsigncode (macOS)
    # ----------------------------
    rm -rf "$OUTPUT_DIR/osslsigncode/darwin"
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
