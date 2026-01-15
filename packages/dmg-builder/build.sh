#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

rm -rf "$ROOT/out"
bash "$ROOT/assets/bundle.sh"  "$ROOT/out/dmg-builder" "==1.6.6"