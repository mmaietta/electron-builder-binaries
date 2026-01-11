#!/bin/bash
set -eou pipefail

echo "Running offline preflight checks..."
echo "================================="

FAIL=0

check() {
  if ! eval "$1" >/dev/null 2>&1; then
    echo "❌ $2"
    FAIL=1
  else
    echo "✓ $2"
  fi
}

# snapcraft present
check "command -v snapcraft" "snapcraft installed"

# snapd running
check "snap version" "snapd available"

# base installed
check "snap list core24" "core24 base installed"

# no stage-packages
if grep -R "stage-packages" snapcraft.yaml >/dev/null 2>&1; then
  echo "❌ stage-packages detected (breaks offline builds)"
  FAIL=1
else
  echo "✓ no stage-packages detected"
fi

# no extensions
if grep -R "extensions:" snapcraft.yaml >/dev/null 2>&1; then
  echo "❌ extensions detected (breaks offline builds)"
  FAIL=1
else
  echo "✓ no extensions detected"
fi

# build environment exists
if snapcraft version | grep -q lxd; then
  check "lxc image list" "LXD image cache exists"
else
  check "multipass list" "Multipass VM exists"
fi

# offline flag reminder
echo ""
echo "Ensure you build with:"
echo "  snapcraft --offline"
echo ""

if [ "$FAIL" -eq 1 ]; then
  echo "================================="
  echo "❌ Offline preflight FAILED"
  exit 1
fi

echo "================================="
echo "✅ Offline preflight PASSED"
