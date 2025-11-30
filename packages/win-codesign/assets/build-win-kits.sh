#!/usr/bin/env bash
set -euxo pipefail
CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$CWD/out/win-codesign"

echo "📦 Creating Windows Kits bundle..."

ASSETS_BUNDLE_DIR="$OUTPUT_DIR/windows-kits-bundle"
ASSETS_ZIP="$OUTPUT_DIR/windows-kits.zip"
rm -rf "$ASSETS_BUNDLE_DIR"
mkdir -p "$ASSETS_BUNDLE_DIR"

# Copy appxAssets + windows-kits
cp -a "$OUTPUT_DIR/appxAssets" "$ASSETS_BUNDLE_DIR/appxAssets"
node "$CWD/assets/collect-windows-kits.js"

# Create version metadata
cat > "$ASSETS_BUNDLE_DIR/VERSION.txt" <<EOF
bundle: windows-kits
created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# Create VERSION.txt
{
    echo "bundle: windows-kits"
    echo "created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "Windows Kits version:"
    cat "$OUTPUT_DIR/windows-kits/VERSION.txt"
} > "$ASSETS_BUNDLE_DIR/VERSION.txt"

# Create ZIP archive
echo "📦 Zipping appxAssets + windows-kits..."
cd "$ASSETS_BUNDLE_DIR"
zip -r -9 "$ASSETS_ZIP" .

echo "✅ Created bundle: $ASSETS_ZIP"
echo ""

rm -rf "$ASSETS_BUNDLE_DIR"