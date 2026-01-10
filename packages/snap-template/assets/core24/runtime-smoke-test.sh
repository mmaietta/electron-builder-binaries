#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

export LD_LIBRARY_PATH="$ROOT/usr/lib/x86_64-linux-gnu:$ROOT/lib/x86_64-linux-gnu"
export GTK_PATH="$ROOT/usr/lib/gtk-3.0"
export GSETTINGS_SCHEMA_DIR="$ROOT/usr/share/glib-2.0/schemas"

echo "🧪 GTK init test..."

cat << 'EOF' > /tmp/gtk-test.c
#include <gtk/gtk.h>
int main(int argc, char **argv) {
  gtk_init(&argc, &argv);
  return 0;
}
EOF

gcc /tmp/gtk-test.c -o /tmp/gtk-test \
  -I"$ROOT/usr/include/gtk-3.0" \
  -lgtk-3 || true

ldd /tmp/gtk-test | grep "not found" && exit 1

/tmp/gtk-test

echo "🧪 NSS load test..."

ldd "$ROOT/usr/lib/x86_64-linux-gnu/libnss3.so" | grep "not found" && exit 1

echo "✅ Runtime smoke test passed"
