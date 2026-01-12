#!/usr/bin/env bash
set -euo pipefail

############################################
# Inputs
############################################

ELECTRON_VERSION="${1:?Electron version required}"
BUILD_ROOT="${2:-$(cd "$(dirname "$0")/../.." && pwd)}"

ARCHES=(x64 arm64 armv7l)
OUT_ROOT="$BUILD_ROOT/electron-templates/v$ELECTRON_VERSION"

mkdir -p "$OUT_ROOT"

############################################
# Helpers
############################################

docker_platform() {
  case "$1" in
    x64)    echo linux/amd64 ;;
    arm64)  echo linux/arm64 ;;
    armv7l) echo linux/arm/v7 ;;
    *)      echo unknown ;;
  esac
}

# Render a Bash array into Dockerfile-safe continuation lines
render_pkg_block() {
  for pkg in "$@"; do
    printf "    %s \\\\\n" "$pkg"
  done
}

############################################
# Runtime allowlists (arrays)
############################################

# ---- Common Electron runtime deps (core24) ----
ALLOWLIST_COMMON=(
  libnss3
  libnspr4
  libxss1
)

ALLOWLIST_X64=( libasound2t64 )
ALLOWLIST_ARM64=( libasound2t64 )
ALLOWLIST_ARMV7L=( libasound2t64 )


############################################
# Hard excludes (analysis only)
############################################

EXCLUDE_REGEX='
^libc\.so
^libm\.so
^libpthread\.so
^libdl\.so
^ld-linux
^libgcc_s\.so
^libgtk
^libglib
^libgobject
^libgio
^libpango
^libcairo
^libatk
^libatspi
^libX11
^libxcb
^libdrm
^libexpat
'

############################################
# Docker buildx setup
############################################

if ! docker buildx inspect electron-multi >/dev/null 2>&1; then
  docker buildx create --name electron-multi --use
fi

############################################
# Main loop
############################################

for ARCH in "${ARCHES[@]}"; do
  PLATFORM="$(docker_platform "$ARCH")"
  ARCH_OUT="$OUT_ROOT/$ARCH"
  mkdir -p "$ARCH_OUT"

  # ---- Select arch-specific allowlist ----
  ALLOWLIST=("${ALLOWLIST_COMMON[@]}")

  case "$ARCH" in
    x64)    ALLOWLIST+=("${ALLOWLIST_X64[@]}") ;;
    arm64)  ALLOWLIST+=("${ALLOWLIST_ARM64[@]}") ;;
    armv7l) ALLOWLIST+=("${ALLOWLIST_ARMV7L[@]}") ;;
  esac

  ##########################################
  # Emit Dockerfile
  ##########################################

  cat > "$ARCH_OUT/Dockerfile" <<EOF
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /build

# ---- Base tools ----
RUN apt-get update && apt-get install -y \\
    wget \\
    unzip \\
    binutils \\
    dpkg-dev \\
    ca-certificates \\
 && rm -rf /var/lib/apt/lists/*

# ---- Download Electron ----
RUN wget -q https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-${ARCH}.zip \\
 && unzip -q electron-v${ELECTRON_VERSION}-linux-${ARCH}.zip -d electron \\
 && rm electron-v${ELECTRON_VERSION}-linux-${ARCH}.zip

# ---- Analyze ELF dependencies (diagnostic only) ----
RUN readelf -d electron/electron \\
  | awk '/NEEDED/ {print \$5}' \\
  | tr -d '[]' \\
  | sort -u > libs.all.txt

RUN grep -v -E "$(echo "$EXCLUDE_REGEX" | tr '\n' '|')" libs.all.txt \\
  > libs.filtered.txt || true

# ---- Install allowlisted runtime packages ----
RUN apt-get update && apt-get install -y \\
$(render_pkg_block "${ALLOWLIST[@]}")
 && rm -rf /var/lib/apt/lists/*

# ---- Extract runtime .so files only ----
RUN mkdir -p /template && \\
    for pkg in ${ALLOWLIST[*]}; do \\
      dpkg -L \$pkg | grep -E '\\\\.so' || true; \\
    done | sort -u > files.list

RUN while read -r f; do \\
      if [ -f "\$f" ]; then \\
        mkdir -p "/template/\$(dirname "\$f")" && \\
        cp -a "\$f" "/template/\$f"; \\
      fi; \\
    done < files.list

# ---- Always bundle Electron-specific libs ----
RUN mkdir -p /template/usr/lib && \\
    cp -a electron/libffmpeg.so /template/usr/lib/

# ---- Cleanup ----
RUN find /template -type l -delete && \\
    find /template -type f ! -name "*.so*" -delete && \\
    find /template -type d -empty -delete

# ---- Package template ----
RUN tar czf /build/electron-core24-template-${ARCH}.tar.gz -C /template .

CMD sh -c "\
  echo '=== Raw SONAMEs ==='; cat libs.all.txt; \\
  echo; \\
  echo '=== Filtered SONAMEs ==='; cat libs.filtered.txt; \\
  echo; \\
  echo '=== Allowlist packages ==='; echo '${ALLOWLIST[*]}'; \\
  echo; \\
  du -sh /build/electron-core24-template-${ARCH}.tar.gz \
"
EOF

  ##########################################
  # Build + extract
  ##########################################

  docker buildx build \
    --platform "$PLATFORM" \
    --load \
    -t electron-core24-${ARCH}:${ELECTRON_VERSION} \
    "$ARCH_OUT"

  CID=$(docker create electron-core24-${ARCH}:${ELECTRON_VERSION})
  mkdir -p "$ARCH_OUT/results"
  docker cp "$CID:/build/electron-core24-template-${ARCH}.tar.gz" \
    "$ARCH_OUT/results/"
  docker rm "$CID" >/dev/null
done

############################################
# Summary
############################################

SUMMARY="$OUT_ROOT/SUMMARY.md"
{
  echo "# Electron $ELECTRON_VERSION – core24 Runtime Templates"
  echo
  for ARCH in "${ARCHES[@]}"; do
    echo "## $ARCH"
    du -sh "$OUT_ROOT/$ARCH/results/"*.tar.gz 2>/dev/null || true
    echo
  done
} > "$SUMMARY"

echo "✓ Done"
echo "Templates written to: $OUT_ROOT"

echo "Summary:"
echo "Size: $(du -sh "$OUT_ROOT"/*/results/*.tar.gz)"
echo ""
cat "$SUMMARY"
