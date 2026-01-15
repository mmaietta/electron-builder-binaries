#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

rm -rf "$ROOT/out"
bash "$ROOT/assets/bundle.sh" "==1.6.2" "$ROOT/out/dmg-builder"