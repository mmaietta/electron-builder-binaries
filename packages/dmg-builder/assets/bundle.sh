#!/bin/bash
set -euo pipefail

# Bundle minimal Python runtime with dmgbuild
# Produces one tar.gz per architecture
#
# Output:
#   dmgbuild-bundle-<arch>-<version>.tar.gz

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/dist}"
PYTHON_VERSION="${2:-3.11.8}"
DMGBUILD_VERSION="${3:-1.6.6}"
PYTHON_PATH="${4:-}"

if [[ -n "${PYTHON_PATH}" ]]; then
  if [[ ! -x "${PYTHON_PATH}" ]]; then
    echo "❌ Specified Python path is not executable: ${PYTHON_PATH}"
    exit 1
  fi
  PYTHON_VERSION="$("${PYTHON_PATH}" --version | awk '{print $2}')"
fi

echo "🐍 dmgbuild portable bundler"
echo "📁 Output directory: ${OUTPUT_DIR}"
echo "🔢 Python version: ${PYTHON_VERSION}"
echo "📦 dmgbuild version: ${DMGBUILD_VERSION}"
echo ""

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ Must be run on macOS"
  exit 1
fi

if ! command -v pyenv >/dev/null; then
  echo "❌ pyenv is required"
  exit 1
fi

CURRENT_ARCH="$(uname -m)"

if [[ "$CURRENT_ARCH" == "arm64" ]]; then
  ARCHS=(arm64 x86_64)
elif [[ "$CURRENT_ARCH" == "x86_64" ]]; then
  ARCHS=(x86_64 arm64)
else
  echo "❌ Unsupported architecture: $CURRENT_ARCH"
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

build_arch() {
  local ARCH="$1"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🏗️  Building ${ARCH}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local WORKDIR
  WORKDIR="$(mktemp -d)"
  local TOOLING_DIR="${WORKDIR}/tooling"

  mkdir -p "${TOOLING_DIR}"

  export ARCHFLAGS="-arch ${ARCH}"
  export PYTHON_CONFIGURE_OPTS="--enable-optimizations"

  if ! pyenv versions --bare | grep -qx "${PYTHON_VERSION}"; then
    pyenv install "${PYTHON_VERSION}"
  fi

  cd "${WORKDIR}"
  pyenv local "${PYTHON_VERSION}"

  "$(pyenv which python3)" -m venv venv
  source venv/bin/activate

  pip install --upgrade pip --quiet
  pip install --no-cache-dir "dmgbuild==${DMGBUILD_VERSION}"

  mkdir -p "${TOOLING_DIR}/python/bin"
  cp venv/bin/python3 "${TOOLING_DIR}/python/bin/python3"
  chmod +x "${TOOLING_DIR}/python/bin/python3"

  SITE_PACKAGES="$(find venv/lib -type d -name site-packages | head -n1)"
  mkdir -p "${TOOLING_DIR}/site-packages"
  cp -R "${SITE_PACKAGES}/"* "${TOOLING_DIR}/site-packages/"

  # Cleanup
  find "${TOOLING_DIR}/site-packages" -name "__pycache__" -exec rm -rf {} + || true
  find "${TOOLING_DIR}/site-packages" -name "*.dist-info" -exec rm -rf {} + || true
  find "${TOOLING_DIR}/site-packages" -name "*.egg-info" -exec rm -rf {} + || true
  find "${TOOLING_DIR}/site-packages" -name "tests" -exec rm -rf {} + || true

  # VERSION.txt
  {
    echo "Python: ${PYTHON_VERSION}"
    echo "Architecture: ${ARCH}"
    echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
  } > "${TOOLING_DIR}/VERSION.txt"

  # builder.sh (arch-specific)
  cat > "${TOOLING_DIR}/builder.sh" <<EOF
#!/bin/bash
set -e
DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
export PYTHONPATH="\${DIR}/site-packages"
exec "\${DIR}/python/bin/python3" -m dmgbuild "\$@"
EOF
  chmod +x "${TOOLING_DIR}/builder.sh"

  # README
  cat > "${TOOLING_DIR}/README.md" <<EOF
# dmgbuild Portable (${ARCH})

Self-contained dmgbuild bundle.

## Usage
\`\`\`bash
./builder.sh -s settings.py "MyApp" MyApp.dmg
\`\`\`

Includes:
- Python ${PYTHON_VERSION}
- dmgbuild ${DMGBUILD_VERSION}
EOF

  deactivate
  cd "${SCRIPT_DIR}"

  ARCHIVE="dmgbuild-bundle-${ARCH}-${DMGBUILD_VERSION}.tar.gz"
  ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE}"

  tar -czf "${ARCHIVE_PATH}" -C "${WORKDIR}" tooling

  shasum -a 256 "${ARCHIVE_PATH}" > "${ARCHIVE_PATH}.sha256"

  echo "✅ Created ${ARCHIVE}"

  rm -rf "${WORKDIR}"
  unset ARCHFLAGS PYTHON_CONFIGURE_OPTS
}

for ARCH in "${ARCHS[@]}"; do
  build_arch "${ARCH}"
done

echo ""
echo "🎉 All bundles created in ${OUTPUT_DIR}"
