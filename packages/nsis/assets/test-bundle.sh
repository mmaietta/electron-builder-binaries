#!/usr/bin/env bash
set -exuo pipefail

# ----------------------------------------
# Args (simulate matrix)
# ----------------------------------------
PLATFORM="${1:-}"
BINARY_PATH="${2:-}"
BUNDLE_PATH="${3:-./nsis}"

if [[ -z "$PLATFORM" || -z "$BINARY_PATH" ]]; then
  echo "Usage: $0 <platform> <binary-path>"
  echo "Example: $0 macOS-arm64 mac/arm64/makensis"
  exit 1
fi

echo "🧪 Testing NSIS bundle"
echo "Platform: $PLATFORM"
echo "Binary:   $BINARY_PATH"
echo

# ----------------------------------------
# Step: Extract bundle
# ----------------------------------------
echo "📦 Extracting bundle..."
cd $BUNDLE_PATH

shopt -s nullglob
archives=( *complete*.tar.gz )

if (( ${#archives[@]} == 0 )); then
  echo "ERROR: no *complete*.tar.gz files found"
  exit 1
fi

echo "Using archive: ${archives[0]}"
tar -xzf "${archives[0]}"
cd $BUNDLE_PATH/nsis-bundle

# ----------------------------------------
# Step: Test makensis binary
# ----------------------------------------
echo "🔍 Testing makensis binary..."

if [[ "$PLATFORM" == Windows* ]]; then
  "./$BINARY_PATH" -VERSION
else
  chmod +x "./$BINARY_PATH"
  "./$BINARY_PATH" -VERSION
fi

# ----------------------------------------
# Step: Create test script
# ----------------------------------------
echo "📝 Creating test.nsi..."

cat > test.nsi << 'EOF'
!include "MUI2.nsh"

Name "Test Installer"
OutFile "test-installer.exe"
InstallDir "$PROGRAMFILES\TestApp"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

Section "Main"
  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
SectionEnd
EOF

# ----------------------------------------
# Step: Compile test script
# ----------------------------------------
echo "⚙️  Compiling test installer..."

if [[ "$PLATFORM" == Windows* ]]; then
  "./$BINARY_PATH" test.nsi
else
  export NSISDIR="$(pwd)/share/nsis"
  "./$BINARY_PATH" test.nsi
fi

# ----------------------------------------
# Step: Verify output
# ----------------------------------------
echo "✅ Verifying output..."

if [[ -f test-installer.exe ]]; then
  echo "✅ Test compilation successful!"
  ls -lh test-installer.exe
else
  echo "❌ Test compilation failed – no output file"
  exit 1
fi

# ----------------------------------------
# Step: Test plugins
# ----------------------------------------
echo "🔌 Checking plugins..."

plugin_count="$(find share/nsis/Plugins -name "*.dll" 2>/dev/null | wc -l | tr -d ' ')"
echo "Found $plugin_count plugin DLLs"

if (( plugin_count < 20 )); then
  echo "⚠️  Warning: Expected more plugins"
else
  echo "✅ Plugin count looks good"
fi

echo
echo "🎉 Bundle test completed successfully for $PLATFORM"
