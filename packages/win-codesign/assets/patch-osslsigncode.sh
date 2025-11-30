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
# macOS section
# ================================================================
if [[ "$uname_s" == "Darwin" ]]; then
  echo "🍎 macOS detected"

  if [[ ! -x "$OTOOL" ]]; then
    echo "❌ $OTOOL not found or not executable. Aborting."
    exit 6
  fi
  if [[ ! -x "$INSTALL_NAME_TOOL" ]]; then
    echo "❌ $INSTALL_NAME_TOOL not found or not executable. Aborting."
    exit 7
  fi

  deps=$("$OTOOL" -L "$BIN_DIR/osslsigncode" | awk 'NR>1 {print $1}')

  # These are the libs we allow bundling on macOS
  allow_prefixes=("libcrypto" "libssl" "libgmp" "libz" "liblzma" "libbz2")

  skip_regex='^/usr/lib/|^/System/Library/|^/System/Volumes/Preboot/|^/System/Library/Frameworks/'

  while read -r dep; do
    [[ -z "$dep" ]] && continue
    case "$dep" in
      @rpath/*|@loader_path/*|@executable_path/*) continue ;;
    esac
    if [[ "$dep" =~ $skip_regex ]]; then
      echo "  🔕 skip (system): $dep"
      continue
    fi

    base=$(basename "$dep")
    should_copy=false
    for p in "${allow_prefixes[@]}"; do
      [[ "$base" == "$p"* ]] && should_copy=true
    done

    if $should_copy && [[ -f "$dep" ]]; then
      dest="$LIB_DIR/$base"
      if [[ ! -f "$dest" ]]; then
        echo "  ➕ copy $dep -> $dest"
        cp -a "$dep" "$dest"
      fi
    fi
  done <<< "$deps"

  DEFAULT_RPATH="@executable_path/../lib"

  if ! "$OTOOL" -l "$BIN_DIR/osslsigncode" | grep -q LC_RPATH; then
    echo "  ➕ adding rpath $DEFAULT_RPATH"
    "$INSTALL_NAME_TOOL" -add_rpath "$DEFAULT_RPATH" "$BIN_DIR/osslsigncode" || true
  fi

  # Patch main binary absolute deps -> local copies (if present)
  abs_deps=$("$OTOOL" -L "$BIN_DIR/osslsigncode" | awk 'NR>1 {print $1}' | grep '^/' || true)
  while read -r dep; do
    [[ -z "$dep" ]] && continue
    base=$(basename "$dep")
    local_candidate="$LIB_DIR/$base"
    if [[ -f "$local_candidate" ]]; then
      rel=$(compute_loader_rel "$BIN_DIR/osslsigncode" "$local_candidate")
      echo "  🔁 patching $dep -> $rel"
      "$INSTALL_NAME_TOOL" -change "$dep" "$rel" "$BIN_DIR/osslsigncode" || true
    fi
  done <<< "$abs_deps"

  # Patch copied libs internal absolute refs -> local copies
  find "$LIB_DIR" -name '*.dylib' -print0 | while IFS= read -r -d '' f; do
    deps=$("$OTOOL" -L "$f" | awk 'NR>1 {print $1}' | grep '^/' || true)
    for dep in $deps; do
      base=$(basename "$dep")
      if [[ -f "$LIB_DIR/$base" ]]; then
        rel=$(compute_loader_rel "$f" "$LIB_DIR/$base")
        echo "    🔁 lib patch: $dep -> $rel"
        "$INSTALL_NAME_TOOL" -change "$dep" "$rel" "$f" || true
      fi
    done
  done

  # macOS ad-hoc signing (best-effort)
  echo "🔏 Code signing binaries and libraries..."
  for f in "$LIB_DIR"/*.dylib "$BIN_DIR"/*; do
    /usr/bin/codesign --force --sign - "$f" 2>/tmp/codesign.err || true
  done
  # verify signatures (should not print errors)
  /usr/bin/codesign -v --deep --strict "$BIN_DIR/osslsigncode"
fi


# ================================================================
# Linux section — AUTODETECT ALL NON-SYSTEM LIBRARIES
# ================================================================
if [[ "$uname_s" == "Linux" ]]; then
  echo "🐧 Linux detected"

  skip_regex='^(libc\.so|libm\.so|libdl\.so|libpthread\.so|librt\.so|ld-linux|linux-vdso|vdso)'

  # AUTODETECTED allowlist — use process substitution (no subshell loss)
  declare -A auto_allow=()
  while read -r line; do
    # line looks like: libfoo.so => /path/to/libfoo.so (0x...)
    if [[ "$line" =~ "=>" ]]; then
      libpath=$(echo "$line" | awk '{print $3}')
      [[ ! -f "$libpath" ]] && continue
      base=$(basename "$libpath")

      if [[ "$base" =~ $skip_regex ]]; then
        echo "  🔕 skip system: $base"
        continue
      fi

      echo "  ➕ auto-allow: $base -> $libpath"
      auto_allow["$base"]="$libpath"
    fi
  done < <(ldd "$BIN_DIR/osslsigncode" 2>/dev/null || true)

  for base in "${!auto_allow[@]}"; do
    src="${auto_allow[$base]}"
    echo "  📥 copy $src -> $LIB_DIR/$base"
    cp -aL "$src" "$LIB_DIR/$base"
    chmod 644 "$LIB_DIR/$base" || true
  done

  if command -v patchelf >/dev/null 2>&1; then
    echo "  🔧 setting binary rpath: \$ORIGIN/../lib"
    patchelf --set-rpath '$ORIGIN/../lib' "$BIN_DIR/osslsigncode" || true

    # Set rpath on copied libs as best-effort
    for libfile in "$LIB_DIR"/*; do
      [[ ! -f "$libfile" ]] && continue
      patchelf --set-rpath '$ORIGIN' "$libfile" 2>/dev/null || true
    done
  else
    echo "  ⚠️ patchelf not found; binary rpath won't be set. Install patchelf for full portability."
  fi
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
# VERSION file
# ================================================================
OSSL_VER=$("$BIN_DIR/osslsigncode" --version 2>&1 | head -n1 || true)
{
  echo "osslsigncode: ${OSSL_VER:-unknown}"
  echo "platform: $uname_s"
  echo "created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} > "$INSTALL_DIR/VERSION.txt"

# Create entrypoint/launcher for convenience (sets library path at runtime)
cat > "$INSTALL_DIR/osslsigncode" <<'EOF'
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
    ;;
esac

exec "$HERE/bin/osslsigncode" "$@"
EOF

chmod +x "$INSTALL_DIR/osslsigncode"


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
