#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

rm -rf "$ROOT/out"
mkdir -p "$ROOT/out/dmg-builder"

bash "$ROOT/assets/build-python-runtime.sh" "$ROOT/out/python-runtime" "3.11.8" "1.6.6"
# bash "$ROOT/assets/bundle.sh" "$ROOT/out/dmg-builder" "3.11.8" "1.6.6" "$ROOT/out/python-runtime/python/bin/python3"