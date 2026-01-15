#!/bin/bash
set -euo pipefail

# dmgbuild portable bundler (dual-arch, isolated pyenv roots)
#
# Output:
#   dmgbuild-bundle-arm64-<version>.tar.gz
#   dmgbuild-bundle-x86_64-<version>.tar.gz

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/dist}"
PYTHON_VERSION="${2:-3.11.8}"
DMGBUILD_VERSION="${3:-1.6.6}"

PYENV_ROOT_ARM="$HOME/.pyenv-arm64"
PYENV_ROOT_X86="$HOME/.pyenv-x86_64"

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

mkdir -p "${OUTPUT_DIR}"

build_arch() {
  local ARCH="$1"
  local PYENV_ROOT
  local PYENV_CMD
  local ARCHFLAGS
  local PYTHON_BIN

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🏗️  Building ${ARCH}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "$ARCH" == "arm64" ]]; then
    PYENV_ROOT="${PYENV_ROOT_ARM}"
    PYENV_CMD="pyenv"
    ARCHFLAGS="-arch arm64"
  else
    PYENV_ROOT="${PYENV_ROOT_X86}"
    PYENV_CMD="arch -x86_64 pyenv"
    ARCHFLAGS="-arch x86_64"
  fi

  export PYENV_ROOT
  export ARCHFLAGS
  export PYTHON_CONFIGURE_OPTS="--enable-optimizations"

  mkdir -p "${PYENV_ROOT}"

  ${PYENV_CMD} install --skip-existing "${PYTHON_VERSION}"

  PYTHON_BIN="${PYENV_ROOT}/versions/${PYTHON_VERSION}/bin/python3"

  if [[ ! -x "${PYTHON_BIN}" ]]; then
    echo "❌ Python binary not found: ${PYTHON_BIN}"
    exit 1
  fi

  WORKDIR="$(mktemp -d)"
  TOOLING_DIR="${WORKDIR}/tooling"

  mkdir -p "${TOOLING_DIR}"

  echo "🐍 Python: $(${PYTHON_BIN} --version)"

  "${PYTHON_BIN}" -m venv "${WORKDIR}/venv"
  source "${WORKDIR}/venv/bin/activate"

  pip install --upgrade pip --quiet
  pip install --no-cache-dir "dmgbuild==${DMGBUILD_VERSION}"

  mkdir -p "${TOOLING_DIR}/python/bin"
  cp "${WORKDIR}/venv/bin/python3" "${TOOLING_DIR}/python/bin/python3"
  chmod +x "${TOOLING_DIR}/python/bin/python3"

  SITE_PACKAGES="$(find "${WORKDIR}/venv/lib" -type d -name site-packages | head -n1)"
  mkdir -p "${TOOLING_DIR}/site-packages"
  cp -R "${SITE_PACKAGES}/"* "${TOOLING_DIR}/site-packages/"

  # Cleanup
  find "${TOOLING_DIR}/site-packages" -name "__pycache__" -exec rm -rf {} + || true
  find "${TOOLING_DIR}/site-packages" -name "*.dist-info" -exec rm -rf {} + || true
  find "${TOOLING_DIR}/site-packages" -name "*.egg-info" -exec rm -rf {} + || true
  find "${TOOLING_DIR}/site-packages" -name "tests" -exec rm -rf {} + || true

  # VERSION.txt
  {
    echo "Architecture: ${ARCH}"
    echo "Python: ${PYTHON_VERSION}"
    echo "dmgbuild: ${DMGBUILD_VERSION}"
    echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
  } > "${TOOLING_DIR}/VERSION.txt"

  # builder.sh
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

  ARCHIVE="dmgbuild-bundle-${ARCH}-${DMGBUILD_VERSION}.tar.gz"
  ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE}"

  tar -czf "${ARCHIVE_PATH}" -C "${WORKDIR}" tooling
  shasum -a 256 "${ARCHIVE_PATH}" > "${ARCHIVE_PATH}.sha256"

  echo "✅ Created ${ARCHIVE}"

  rm -rf "${WORKDIR}"
  unset PYENV_ROOT ARCHFLAGS PYTHON_CONFIGURE_OPTS
}

build_arch arm64
build_arch x86_64

echo ""
echo "🎉 Bundles created in ${OUTPUT_DIR}"
