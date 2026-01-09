#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Electron core22 Runtime Template Builder (Docker buildx)
# =============================================================================
# Builds multi-arch (amd64 + arm64) runtime templates containing all
# shared libraries required by Electron snaps.
#
# Output:
#   out/electron-runtime-template/
#
# Requirements:
#   - Docker with buildx enabled
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$BASE_DIR/build/core22"
TEMPLATE_DIR="$BUILD_DIR/electron-runtime-template"
OUT_DIR="$BASE_DIR/out/snap-template"

IMAGE_NAME="electron-core22-runtime-builder"
BUILDER_NAME="electron-runtime-builder"

echo "📦 Electron core22 Runtime Template Builder"
echo "=========================================="
echo ""

# =============================================================================
# Prerequisites
# =============================================================================

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker is required but not installed"
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "❌ Docker buildx is required"
  exit 1
fi

# =============================================================================
# Setup
# =============================================================================

rm -rf "$TEMPLATE_DIR" "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# Ensure buildx builder exists
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  echo "🔧 Creating buildx builder: $BUILDER_NAME"
  docker buildx create --name "$BUILDER_NAME" --use
else
  docker buildx use "$BUILDER_NAME"
fi

docker buildx inspect --bootstrap >/dev/null

# =============================================================================
# Create Dockerfile
# =============================================================================

DOCKERFILE="$BUILD_DIR/Dockerfile.electron-runtime"

echo "📝 Writing Dockerfile..."

cat > "$DOCKERFILE" <<'EOF'
# syntax=docker/dockerfile:1.7

ARG TARGETARCH
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies Electron actually needs
RUN apt-get update && apt-get install -y --no-install-recommends \
    libappindicator3-1 \
    libindicator3-7 \
    libdbusmenu-glib4 \
    libdbusmenu-gtk3-4 \
    libxss1 \
    libnss3 \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Assemble runtime template (core22)
# =============================================================================
RUN set -eux; \
    case "$(uname -m)" in \
      x86_64) ARCH=x86_64-linux-gnu ;; \
      aarch64) ARCH=aarch64-linux-gnu ;; \
      *) echo "Unsupported architecture" && exit 1 ;; \
    esac; \
    \
    OUT="/out/usr/lib/$ARCH"; \
    mkdir -p "$OUT/nss"; \
    \
    # Core NSS shared libraries
    for lib in libnspr4 libnss3 libnssutil3 libplc4 libplds4 libsmime3 libssl3; do \
      cp -avL --remove-destination "/usr/lib/$ARCH/$lib.so" "$OUT/"; \
    done; \
    \
    # NSS runtime modules + integrity (.chk) files
    for name in libfreebl3 libfreeblpriv3 libsoftokn3 libnssckbi libnssdbm3; do \
      for dir in "/usr/lib/$ARCH" "/usr/lib/$ARCH/nss"; do \
        [ -f "$dir/$name.so" ]  && cp -avL --remove-destination "$dir/$name.so" "$OUT/nss/"; \
        [ -f "$dir/$name.chk" ] && cp -avL --remove-destination "$dir/$name.chk" "$OUT/nss/"; \
      done; \
    done; \
    \
    # Historical Electron symlinks
    [ -f "$OUT/nss/libfreebl3.so" ] && ln -sf nss/libfreebl3.so "$OUT/libfreebl3.so"; \
    [ -f "$OUT/nss/libfreeblpriv3.so" ] && ln -sf nss/libfreeblpriv3.so "$OUT/libfreeblpriv3.so"

FROM scratch
COPY --from=0 /out /
EOF

# =============================================================================
# Build & Extract (multi-platform)
# =============================================================================

echo ""
echo "🔨 Building runtime templates (amd64 + arm64)..."
echo "   This may take a few minutes on first run."
echo ""

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --output type=local,dest="$TEMPLATE_DIR" \
  -f "$DOCKERFILE" \
  "$BUILD_DIR"

tree -a "$TEMPLATE_DIR" || find "$TEMPLATE_DIR" -ls

# =============================================================================
# Package into tar.gz
# =============================================================================
TARFILE="$OUT_DIR/electron-core22-runtime-template.tar.gz"
(
    cd "$BUILD_DIR" || exit 1
    echo ""
    echo "📦 Packaging runtime template: $TARFILE"
    tar -czf "$TARFILE" "$(basename "$TEMPLATE_DIR")"
)

# =============================================================================
# Cleanup
# =============================================================================

rm -f "$DOCKERFILE"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "================================================================"
echo "  ✅ Electron core22 Runtime Templates Built"
echo "================================================================"
echo "  📁 Output directory:"
echo "     $TEMPLATE_DIR"
echo "     $TARFILE"
echo ""
echo "  📦 Architectures:"
echo "     - amd64 (x86_64-linux-gnu)"
echo "     - arm64 (aarch64-linux-gnu)"
echo ""
echo "  📌 Usage (Snapcraft):"
echo "     plugin: dump"
echo "     source: $TEMPLATE_DIR"
echo "================================================================"
echo ""
