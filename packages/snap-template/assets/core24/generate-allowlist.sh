#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

echo "📜 Generating LD allowlist..."

mkdir -p "$(pwd)/generated"

find "$ROOT" -type f \( -name "*.so*" -o -perm -111 \) \
  -exec ldd {} \; 2>/dev/null \
  | awk '{print $1}' \
  | sort -u \
  | grep -v '^$' \
  > generated/ld-allowlist.txt

echo "✅ Allowlist written to generated/ld-allowlist.txt"
echo "ℹ️ Please review and merge into ld-allowlist.txt as needed."