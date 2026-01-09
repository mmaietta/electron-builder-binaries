#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Electron core24 Runtime Template Builder (Docker buildx)
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
OUT_DIR="$BASE_DIR/out"
TEMPLATE_DIR="$OUT_DIR/electron-runtime-template"

IMAGE_NAME="electron-core24-runtime-builder"
BUILDER_NAME="electron-runtime-builder"

echo "📦 Electron core24 Runtime Template Builder"
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

mkdir -p "$OUT_DIR"
rm -rf "$TEMPLATE_DIR"

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

DOCKERFILE="$OUT_DIR/Dockerfile.electron-runtime"

echo "📝 Writing Dockerfile..."

cat > "$DOCKERFILE" <<'EOF'
# syntax=docker/dockerfile:1.7

ARG TARGETARCH
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install only runtime dependencies Electron actually needs
RUN apt-get update && apt-get install -y --no-install-recommends \
    libappindicator3-1 \
    libindicator3-7 \
    libdbusmenu-glib4 \
    libdbusmenu-gtk3-4 \
    libxss1 \
    libnss3 \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Resolve multiarch directory
ARG TARGETARCH
RUN set -eux; \
    case "$(uname -m)" in \
      x86_64) ARCH=x86_64-linux-gnu ;; \
      aarch64) ARCH=aarch64-linux-gnu ;; \
      *) echo "Unsupported arch" && exit 1 ;; \
    esac; \
    echo "$ARCH" > /arch


# Assemble runtime template
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
    # Core NSS libs (always present)
    cp -av /usr/lib/$ARCH/libnspr4.so "$OUT/"; \
    cp -av /usr/lib/$ARCH/libnss3.so "$OUT/"; \
    cp -av /usr/lib/$ARCH/libnssutil3.so "$OUT/"; \
    cp -av /usr/lib/$ARCH/libplc4.so "$OUT/"; \
    cp -av /usr/lib/$ARCH/libplds4.so "$OUT/"; \
    cp -av /usr/lib/$ARCH/libsmime3.so "$OUT/"; \
    cp -av /usr/lib/$ARCH/libssl3.so "$OUT/"; \
    \
    # FreeBL modules (location varies)
    for lib in libfreebl3.so libfreeblpriv3.so; do \
      if [ -f "/usr/lib/$ARCH/$lib" ]; then \
        cp -av "/usr/lib/$ARCH/$lib" "$OUT/nss/"; \
      elif [ -f "/usr/lib/$ARCH/nss/$lib" ]; then \
        cp -av "/usr/lib/$ARCH/nss/$lib" "$OUT/nss/"; \
      fi; \
    done; \
    \
    # Create expected Electron symlinks if modules exist
    if [ -f "$OUT/nss/libfreebl3.so" ]; then \
      ln -sf nss/libfreebl3.so "$OUT/libfreebl3.so"; \
    fi; \
    if [ -f "$OUT/nss/libfreeblpriv3.so" ]; then \
      ln -sf nss/libfreeblpriv3.so "$OUT/libfreeblpriv3.so"; \
    fi

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

#   --platform linux/amd64 \
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --output type=local,dest="$TEMPLATE_DIR" \
  --progress=plain \
  -f "$DOCKERFILE" \
  "$OUT_DIR"

# =============================================================================
# Cleanup
# =============================================================================

rm -f "$DOCKERFILE"

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "================================================================"
echo "  ✅ Electron core24 Runtime Templates Built"
echo "================================================================"
echo "  📁 Output directory:"
echo "     $TEMPLATE_DIR"
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
