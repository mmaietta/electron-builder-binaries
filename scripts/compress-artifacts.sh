#!/usr/bin/env bash
set -exuo pipefail
shopt -s nullglob

BASE_DIR=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
source "$BASE_DIR/utils.sh"


hashArtifact()
{
    ARCHIVE_NAME=$1
    CHECKSUM=$(shasum -a 512 "$ARTIFACTS_DIR/$ARCHIVE_NAME" | xxd -r -p | base64)
    EXPECTED="${2:-$CHECKSUM}"
    if [ "$CHECKSUM" != "$EXPECTED" ]; then
        echo "Checksum for $ARCHIVE_NAME does not match expected checksum"
        echo "Expected: $EXPECTED"
        echo "Actual: $CHECKSUM"
        exit 1
    else
        echo "Checksum for $ARCHIVE_NAME matches expected checksum"
    fi
    echo "$ARCHIVE_NAME: $CHECKSUM" >> "$ARTIFACTS_DIR/checksums.txt"
}

downloadArtifact()
{
    RELEASE_NAME=$1
    ARCHIVE_NAME="$2.7z"
    CHECKSUM=$3
    OUTPUT_NAME="${4:-$2}.7z"
    curl -L https://github.com/electron-userland/electron-builder-binaries/releases/download/$RELEASE_NAME/$ARCHIVE_NAME > "$ARTIFACTS_DIR/$OUTPUT_NAME"
    hashArtifact "$OUTPUT_NAME" "$CHECKSUM"
}

for FILEPATH in "$BUILD_OUT_DIR"/*; do
  NAME="$(basename "$FILEPATH")"
  DESTINATION_DIR="$ARTIFACTS_DIR/$NAME"

  rm -rf "$DESTINATION_DIR"
  cp -a "$FILEPATH" "$DESTINATION_DIR"

  for f in "$DESTINATION_DIR"/*; do
    [[ -e "$f" ]] || continue
    hashArtifact "$NAME/$(basename "$f")"
  done
done


sort "$ARTIFACTS_DIR/checksums.txt" -o "$ARTIFACTS_DIR/checksums.txt"
echo "Artifacts compressed and checksums generated in $ARTIFACTS_DIR"