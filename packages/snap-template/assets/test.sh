#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Functional Test for Electron Runtime Templates (Bash 3.2 compatible)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="/tmp/electron-runtime-test"
BUILD_DIR="$ROOT_DIR/build"
OUT_DIR="$ROOT_DIR/out/functional-test"

mkdir -p "$TMP_DIR" "$OUT_DIR"

TEMPLATES=("core22" "core24")
ARCHES=("amd64" "arm64")
UBUNTU_IMAGES=("22.04" "24.04")

# Results arrays (Bash 3.2 compatible)
RESULT_TEMPLATE=()
RESULT_ARCH=()
RESULT_STATUS=()

# =============================================================================
# Create shared base Arch Linux image for caching
# =============================================================================
BASE_IMAGE_NAME="electron-template-base"
BASE_DOCKERFILE="$TMP_DIR/Dockerfile.base"

cat > "$BASE_DOCKERFILE" <<'EOF'
FROM archlinux:latest

RUN pacman -Sy --noconfirm archlinux-keyring \
 && pacman -S --noconfirm gnupg base-devel git nodejs npm sudo xorg-server-xvfb squashfs-tools \
 && pacman -Scc --noconfirm \
 && rm -rf /var/lib/pacman/sync/* /var/cache/pacman/pkg/*

# Install pnpm/corepack
RUN npm install -g pnpm corepack && corepack enable

# Non-root user
RUN useradd -m builder && echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder
USER builder
WORKDIR /home/builder

EOF

docker buildx build --platform linux/amd64 -t "$BASE_IMAGE_NAME" -f "$BASE_DOCKERFILE" "$TMP_DIR"

# =============================================================================
# Helper: Run test for a single template + arch
# =============================================================================
run_test() {
    template="$1"
    arch="$2"
    ubuntu_ver="$3"

    echo ""
    echo "─────────────────────────────────────────────"
    echo "🔹 Testing template: $template | arch: $arch | Ubuntu: $ubuntu_ver"
    echo "─────────────────────────────────────────────"

    TEST_DIR="$TMP_DIR/$template-$arch"
    mkdir -p "$TEST_DIR"

    # Copy template into Docker build context
    cp -r "$BUILD_DIR/$template/electron-runtime-template/." "$TEST_DIR/"

    # Unique snap filename for caching
    SNAP_NAME="electron-runtime-template-${template}-${arch}-snap"

    # Generate Dockerfile for this test
    TEST_DOCKERFILE="$TEST_DIR/Dockerfile"
    cat > "$TEST_DOCKERFILE" <<EOF
FROM $BASE_IMAGE_NAME
WORKDIR /project

COPY . /project/template

# Pack template into a snap
RUN set -eux; \
    snapcraft pack template -o "/project/$SNAP_NAME.snap"; \
    ls -lh "/project/$SNAP_NAME.snap"

# Extract and run Electron
RUN set -eux; \
    SNAP_FILE="/project/$SNAP_NAME.snap"; \
    unsquashfs -q -d /project/squashfs-root "\$SNAP_FILE"; \
    ELECTRON_BIN="/project/squashfs-root/usr/bin/electron"; \
    if [ ! -x "\$ELECTRON_BIN" ]; then \
        echo "❌ Electron binary not found"; exit 1; \
    fi; \
    echo "🔹 Running Electron binary"; \
    Xvfb :99 & export DISPLAY=:99; \
    "\$ELECTRON_BIN" --version
EOF

    # Build container and capture exit code
    if docker buildx build --platform linux/amd64 -t "electron-template-test:$template-$arch" -f "$TEST_DOCKERFILE" "$TEST_DIR"; then
        status="PASS"
    else
        status="FAIL"
    fi

    # Append results
    RESULT_TEMPLATE=("${RESULT_TEMPLATE[@]}" "$template")
    RESULT_ARCH=("${RESULT_ARCH[@]}" "$arch")
    RESULT_STATUS=("${RESULT_STATUS[@]}" "$status")
}

# =============================================================================
# Main Loop
# =============================================================================
for t in "${!TEMPLATES[@]}"; do
    template="${TEMPLATES[$t]}"
    ubuntu_ver="${UBUNTU_IMAGES[$t]}"
    for arch in "${ARCHES[@]}"; do
        run_test "$template" "$arch" "$ubuntu_ver"
    done
done

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "================================================================"
echo "📊 Functional Test Summary"
echo "================================================================"
printf "%-30s | %-7s | %-5s\n" "Template" "Arch" "Result"
printf "%-30s-+-%-7s-+-%-5s\n" "------------------------------" "-------" "-----"
for i in $(seq 0 $((${#RESULT_TEMPLATE[@]}-1))); do
    printf "%-30s | %-7s | %-5s\n" "${RESULT_TEMPLATE[$i]}" "${RESULT_ARCH[$i]}" "${RESULT_STATUS[$i]}"
done
echo "================================================================"
