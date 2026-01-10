#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

echo "🔧 Normalizing RPATHs..."

find "$ROOT" -type f -name "*.so*" | while read -r bin; do
  if file "$bin" | grep -q ELF; then
    CURRENT=$(patchelf --print-rpath "$bin" 2>/dev/null || true)

    if [ -n "$CURRENT" ]; then
      patchelf \
        --set-rpath '$ORIGIN:$ORIGIN/..:$ORIGIN/../lib:$ORIGIN/../../lib' \
        "$bin"
    fi
  fi
done

echo "✅ RPATH normalization complete"
