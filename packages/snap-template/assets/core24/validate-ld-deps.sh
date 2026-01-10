#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
FAIL=0

echo "🔍 Validating ELF shared library dependencies..."

mapfile -t ELFS < <(find "$ROOT" -type f \( -name "*.so*" -o -perm -111 \) -exec file {} \; \
  | grep -E 'ELF .* (executable|shared object)' \
  | cut -d: -f1)

for bin in "${ELFS[@]}"; do
  if ! ldd "$bin" >/tmp/ldd.out 2>&1; then
    echo "❌ ldd failed: $bin"
    FAIL=1
    continue
  fi

  if grep -q "not found" /tmp/ldd.out; then
    echo "❌ Missing dependency in: $bin"
    grep "not found" /tmp/ldd.out
    FAIL=1
  fi
done

if [ "$FAIL" -eq 1 ]; then
  echo "❌ Dependency validation FAILED"
  exit 1
fi

echo "✅ All shared library dependencies resolved"
