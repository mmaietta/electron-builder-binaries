#!/bin/bash
set -e

echo "Offline Snap Doctor Report"
echo "=========================="
echo ""

echo "Snapcraft:"
snapcraft version || true
echo ""

echo "Snapd:"
snap version || true
echo ""

echo "Installed bases:"
snap list | grep '^core' || true
echo ""

echo "Build environment:"
if command -v lxc >/dev/null; then
  echo "LXD images:"
  lxc image list || true
else
  echo "Multipass VMs:"
  multipass list || true
fi
echo ""

echo "Template contents:"
find . -maxdepth 1 -type d
