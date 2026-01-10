#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

ALLOWLIST="$(pwd)/ld-allowlist.txt"
DENYLIST="$(pwd)/ld-denylist.txt"

FAIL=0

mapfile -t LIBS < <(
  find "$ROOT" -type f \( -name "*.so*" -o -perm -111 \) \
    -exec ldd {} \; 2>/dev/null \
    | awk '{print $1}' \
    | sort -u
)

for lib in "${LIBS[@]}"; do
  if grep -q "^$lib$" "$DENYLIST"; then
    echo "❌ Denied dependency detected: $lib"
    FAIL=1
  elif ! grep -q "^$lib$" "$ALLOWLIST"; then
    echo "⚠️  Unlisted dependency: $lib"
    FAIL=1
  fi
done

if [ "$FAIL" -eq 1 ]; then
  echo "❌ Allow/Deny validation FAILED"
  exit 1
fi

echo "✅ Allow/Deny validation passed"
