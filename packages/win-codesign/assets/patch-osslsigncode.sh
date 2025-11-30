#!/usr/bin/env bash
set -euo pipefail

CWD=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OSSLSIGNCODE_SRC="${1:-${OSSLSIGNCODE_SRC:-}}"
OUTPUT_DIR="${2:-$CWD/out/osslsigncode}"
PLATFORM_ARCH="${PLATFORM_ARCH:-$(uname -m)}"

# Prefer a sane tmpdir inside project unless TMPDIR explicitly set by user
if [[ -z "${TMPDIR:-}" ]]; then
  TMP_PREFIX="${CWD}/.tmp/osslsigncode-bundle-$$"
else
  TMP_PREFIX="${TMPDIR%/}/osslsigncode-bundle-$$"
fi

# Force system tools on macOS to avoid otool-classic issues
OTOOL="/usr/bin/otool"
INSTALL_NAME_TOOL="/usr/bin/install_name_tool"

if [[ -z "$OSSLSIGNCODE_SRC" ]]; then
  echo "Usage: $0 /path/to/osslsigncode [output-dir]"
  exit 2
fi

if [[ ! -x "$OSSLSIGNCODE_SRC" ]]; then
  echo "Error: osslsigncode binary not found or not executable: $OSSLSIGNCODE_SRC"
  exit 3
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "$TMP_PREFIX"
INSTALL_DIR="$TMP_PREFIX/install"
BIN_DIR="$INSTALL_DIR/bin"
LIB_DIR="$INSTALL_DIR/lib"
mkdir -p "$BIN_DIR" "$LIB_DIR"

echo "🛠 Building minimal osslsigncode bundle"
echo "  source binary: $OSSLSIGNCODE_SRC"
echo "  working tmp:   $TMP_PREFIX"

# Copy binary
cp -a "$OSSLSIGNCODE_SRC" "$BIN_DIR/osslsigncode"
chmod +x "$BIN_DIR/osslsigncode"

# --- Relative path calculator using grealpath ---
compute_loader_rel() {
  local file="$1"; local lib="$2"

  if ! command -v grealpath >/dev/null 2>&1; then
    echo "❌ grealpath not found. Install via: brew install coreutils"
    exit 5
  fi

  local file_dir
  file_dir=$(dirname "$(grealpath "$file")")

  local rel
  rel=$(grealpath --relative-to="$file_dir" "$lib")

  echo "@loader_path/$rel"
}

uname_s=$(uname -s)

# ================================================================
# Linux section — AUTODETECT ALL NON-SYSTEM LIBRARIES
# ================================================================
if [[ "$uname_s" == "Linux" ]]; then
  echo "🐧 Linux detected"

  ./bundle-linux-libs.sh "$BIN_DIR/osslsigncode" "$INSTALL_DIR"
fi

# ================================================================
# Stripping
# ================================================================
echo "✂ Stripping symbols"
# Only attempt to strip actual files (not symlinks). Use safe flags.
find "$INSTALL_DIR" -type f -print0 | while IFS= read -r -d '' f; do
  # skip small text files and VERSION.txt
  [[ ! -x "$f" && "$f" == *VERSION.txt ]] && continue
  # try to strip (best-effort)
  if command -v strip >/dev/null 2>&1; then
    strip --strip-unneeded "$f" 2>/dev/null || true
  fi
done

# ================================================================
# macOS adhoc signing
# ================================================================
if [[ "$uname_s" == "Darwin" ]]; then
  # macOS ad-hoc signing (best-effort)
  echo "🔏 Code signing binaries and libraries..."
  for f in "$BIN_DIR"/*; do
    /usr/bin/codesign --force --sign - "$f"
  done
  # verify signatures (should not print errors)
  /usr/bin/codesign -v --deep --strict "$BIN_DIR/osslsigncode"
fi

# ================================================================
# VERSION file
# ================================================================
OSSL_VER=$("$BIN_DIR/osslsigncode" --version 2>&1 | head -n1 || true)
{
  echo "osslsigncode: ${OSSL_VER:-unknown}"
  echo "platform: $uname_s"
  echo "created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} > "$INSTALL_DIR/VERSION.txt"

# Create entrypoint/launcher for convenience (sets library path at runtime)
WRAPPER="$INSTALL_DIR/osslsigncode"
cat > "$WRAPPER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin)
    # Remove quarantine attribute from the osslsigncode binary if present
    if grep -q "com.apple.quarantine" <<< "$(xattr "$HERE/bin/osslsigncode" 2>/dev/null || true)"; then
        xattr -d com.apple.quarantine "$HERE/bin/osslsigncode" || true
    fi

    export DYLD_FALLBACK_LIBRARY_PATH="$HERE/lib:${DYLD_FALLBACK_LIBRARY_PATH:-}"
    ;;
  Linux|GNU*)
    export LD_LIBRARY_PATH="$HERE/lib:${LD_LIBRARY_PATH:-}"
    export OPENSSL_MODULES="$HERE/lib/ossl-modules"
    ;;
esac

exec "$HERE/bin/osslsigncode" "$@"
EOF

chmod +x "$WRAPPER"

echo "  - Launch binary via: $WRAPPER --version"
echo "  - Or run: LD_LIBRARY_PATH=$OUTDIR/lib OPENSSL_MODULES=$OUTDIR/lib/ossl-modules $OUTDIR/bin/osslsigncode"

# ================================================================
# PACKAGING
# ================================================================
ARCHIVE_ARCH_SUFFIX=$(echo ${PLATFORM_ARCH:-$(uname -m)} | tr -d '/' | tr '[:upper:]' '[:lower:]')
ARCHIVE_NAME="win-codesign-$(uname -s | tr A-Z a-z)-$ARCHIVE_ARCH_SUFFIX.zip"

echo "📦 Creating ZIP bundle: $ARCHIVE_NAME"
(
  cd "$INSTALL_DIR"
  zip -r -9 "$OUTPUT_DIR/$ARCHIVE_NAME" . >/dev/null
)

rm -rf "$TMP_PREFIX"

echo "✅ Done!"
echo "Bundle at: $OUTPUT_DIR/$ARCHIVE_NAME"
