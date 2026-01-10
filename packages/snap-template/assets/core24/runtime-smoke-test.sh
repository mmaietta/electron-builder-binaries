#!/bin/bash
# runtime-smoke-test.sh
# Minimal GTK + Electron runtime smoke test
# Verifies that libraries and environment are loadable

set -euo pipefail

TEMPLATE_DIR="${1:-.}"

echo "🔍 Running GTK/Electron runtime smoke test in $TEMPLATE_DIR"
echo "Platform: $(uname)"

# Step 1: Check GTK initialization
echo ""
echo "💚 GTK runtime test..."

# Find libgtk libraries
GTK_LIB=$(find "$TEMPLATE_DIR" -type f -name "libgtk-3.so*" -o -name "libgtk-4.so*" | head -n1)

if [ -z "$GTK_LIB" ]; then
    echo "⚠️ No GTK library found in template. Skipping GTK test."
else
    echo "Found GTK lib: $GTK_LIB"

    # Use ldd / otool to ensure all dependencies load
    if [[ "$(uname)" == "Darwin" ]]; then
        otool -L "$GTK_LIB"
    else
        ldd "$GTK_LIB"
    fi

    # Minimal GTK init test using python3 + gi
    if command -v python3 >/dev/null 2>&1; then
        python3 - <<PYTHON
import gi
try:
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk
    win = Gtk.Window()
    win.show()
    print("✅ GTK3 initialized successfully")
except Exception as e:
    print(f"❌ GTK runtime failed: {e}")
    exit(1)
PYTHON
    else
        echo "⚠️ python3 not found, skipping GTK gi test"
    fi
fi

# Step 2: Check Electron runtime (minimal Node test)
echo ""
echo "⚡ Electron runtime test..."

# Assume electron binary is staged in app/
ELECTRON_BIN=$(find "$TEMPLATE_DIR/app" -type f -name "electron" -perm +111 | head -n1)

if [ -z "$ELECTRON_BIN" ]; then
    echo "⚠️ Electron binary not found in template. Skipping Electron test."
else
    echo "Found Electron binary: $ELECTRON_BIN"
    # Run electron with --version to ensure it starts without crashing
    "$ELECTRON_BIN" --version || { echo "❌ Electron runtime failed"; exit 1; }
    echo "✅ Electron initialized successfully"
fi

echo ""
echo "✅ Runtime smoke test complete"
