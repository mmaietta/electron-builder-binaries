#!/bin/bash

set -euo pipefail

CWD=$(cd "$(dirname "$BASH_SOURCE")" && pwd)
source "$CWD/constants.sh"

GEM_LIST=("fpm -v 1.16.0" "ruby-xz") # Add other gems (with or without version arg) here
ENTRYPOINT_GEMS=("fpm")

# ===== Prepare folders =====
OUTPUT_DIR="$BASEDIR/out/fpm"
mkdir -p "$OUTPUT_DIR"

# ===== Create wrapper scripts =====
echo "🔨 Creating environment script..."
echo "  ✏️ ruby.env -> $INSTALL_DIR/ruby.env"
cat <<EOF >"$INSTALL_DIR/ruby.env"
#!/bin/bash
# Portable Ruby environment setup
RUBY_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/$RUBY_DIR_NAME" && pwd)"
RUBY_BIN="\$RUBY_DIR/bin"
export PATH="\$RUBY_BIN:\$PATH"
export GEM_HOME="\$RUBY_DIR/gems"
export GEM_PATH="\$GEM_HOME"
export RUBYLIB="\$RUBY_DIR/lib:\$RUBYLIB"
if [ "\$(uname)" = "Darwin" ]; then
    # Remove quarantine attribute on macOS
    # This is necessary to avoid the "ruby is damaged and can't be opened" error when running the ruby interpreter for the first time
    if grep -q "com.apple.quarantine" <<< "\$(xattr "\$RUBY_BIN/ruby")"; then
        xattr -d com.apple.quarantine "\$RUBY_BIN/ruby"
    fi
fi
EOF
chmod +x "$INSTALL_DIR/ruby.env"

# ===== Install gems =====
echo "💎 Installing gems..."
export PATH="$RUBY_PREFIX/bin:$PATH"
GEM_DIR="$RUBY_PREFIX/gems"
mkdir -p "$GEM_DIR"
export GEM_HOME="$GEM_DIR"
export GEM_PATH="$GEM_HOME"
for gem in "${GEM_LIST[@]}"; do
    gem_name=$(echo "$gem" | cut -d' ' -f1)
    echo "  ⤵️ Installing $gem_name"
    gem install --no-document $gem --quiet --env-shebang
done

echo "🔨 Creating entrypoint scripts for installed gems..."
for gem in "${ENTRYPOINT_GEMS[@]}"; do
    gem_name=$(echo "$gem" | cut -d' ' -f1)
    echo "  ✏️ $gem -> $INSTALL_DIR/$gem_name"
    cat <<EOF >"$INSTALL_DIR/$gem_name"
#!/bin/bash -e
# Portable Ruby environment setup
source "\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)/ruby.env"

exec "\$GEM_HOME/bin/$gem_name" "\$@"
EOF
    chmod +x "$INSTALL_DIR/$gem_name"
done

# ===== Patch Ruby and copy dependencies =====
echo "✂️ Stripping debug symbols..."
strip -x "$RUBY_PREFIX/bin/ruby"

LIB_DIR="$RUBY_PREFIX/lib"
if [ "$(uname)" = "Darwin" ]; then
    echo "  🗑️ Removing dSYM files"
    find $RUBY_PREFIX -type d -name "*.dSYM" -exec rm -rf {} +

    echo "  🍎 Patching portable Ruby bundle for MacOS."

    SHARED_LIB_DIR="$LIB_DIR/shared"
    echo "  ⏩️ Copying shared libraries to $SHARED_LIB_DIR"
    mkdir -p "$SHARED_LIB_DIR"
    SHARED_LIBRARIES=(
        "$(brew --prefix openssl@3)/lib/*.dylib"
        "$(brew --prefix readline)/lib/*.dylib"
        "$(brew --prefix zlib)/lib/*.dylib"
        "$(brew --prefix libyaml)/lib/*.dylib"
        "$(brew --prefix xz)/lib/*.dylib"
        "$(brew --prefix gmp)/lib/*.dylib"
    )
    for pattern in "${SHARED_LIBRARIES[@]}"; do
        for filepath in $pattern; do
            dest="$SHARED_LIB_DIR/$(basename $filepath)"
            if [[ ! -f "$dest" ]]; then
                echo "    📝 Copying $filepath"
                cp -a "$filepath" "$dest"
            fi
        done
    done

    echo "  ✏️ Patching Ruby binary to look for the bundled libraries in $LIB_DIR"
    for dylib in "$SHARED_LIB_DIR"/*.dylib; do
        echo "    🩹 Patching $dylib to install_name: @executable_path/../lib/shared/$(basename $dylib)"
        install_name_tool -id "@executable_path/../lib/shared/$(basename $dylib)" "$dylib"
    done

    find "$RUBY_PREFIX" -type f \( -perm +111 \) -exec file {} \; | grep 'Mach-O' | cut -d: -f1 | while read bin; do
        for dylib in "$SHARED_LIB_DIR"/*.dylib; do
            base=$(basename "$dylib")
            echo "    🩹 Patching $dylib to install_name: @executable_path/../lib/shared/$base"
            install_name_tool -change "$base" "@executable_path/../lib/shared/$base" "$bin" || true
        done
        echo "  ✂️ Stripping debug symbols from $bin"
        strip -x "$bin" || true
    done
else
    echo "  🐧 Patching portable Ruby bundle for Linux."

    echo "  ⏩️ Copying shared libraries to $LIB_DIR"
    SHARED_LIBRARIES=(
        "libssl.so*"
        "libcrypto.so*"
        "libreadline.so*"
        "libz.so*"
        "libyaml-cpp.so*"
        "liblzma.so*"
    )
    for pattern in "${SHARED_LIBRARIES[@]}"; do
        find /usr/lib /lib -type f -name "$pattern" 2>/dev/null | while read -r filepath; do
            dest="$LIB_DIR/$(basename $filepath)"
            if [[ ! -f "$dest" ]]; then
                echo "    📝 Copying $filepath"
                cp -a "$filepath" "$dest"
            fi
        done
    done

    echo "  🔍 Scanning Ruby extensions for additional shared libraries..."
    IFS=$'\n'
    LDD_SEARCH_PATHS=("$RUBY_PREFIX/bin/ruby" $(find "$LIB_DIR/ruby" -type f -name '*.so'))
    unset IFS

    for ext_so in "${LDD_SEARCH_PATHS[@]}"; do
        if [[ ! -f "$ext_so" ]]; then
            echo "  ⏩️ Skipping $ext_so (not a file)"
            continue
        fi
        SO_DIR=$(dirname "$ext_so")
        REL_RPATH=$(realpath --relative-to="$SO_DIR" "$LIB_DIR")
        echo "    🩹 Patching $(realpath --relative-to="$RUBY_PREFIX" "$ext_so") to rpath: \$ORIGIN/$REL_RPATH"
        patchelf --set-rpath "\$ORIGIN/$REL_RPATH" "$ext_so"

        ldd "$ext_so" | awk '/=>/ { print $3 }' | while read -r dep; do
            if [[ -f "$dep" ]]; then
                dest="$LIB_DIR/$(basename $dep)"
                if [[ ! -f "$dest" ]]; then
                    echo "    📝 Copying $dep"
                    cp -u "$dep" "$LIB_DIR/"
                fi
            fi
        done
    done
fi

# ===== Create VERSION file =====
echo "🔨 Creating VERSION file..."
FPM_VERSION="$($INSTALL_DIR/fpm --version | cut -d' ' -f2)"
RUBY_VERSION_VERBOSE="$($RUBY_PREFIX/bin/ruby --version)"
echo "$RUBY_VERSION_VERBOSE" >$INSTALL_DIR/VERSION.txt
echo "fpm: $FPM_VERSION" >>$INSTALL_DIR/VERSION.txt

echo "🔨 Creating portable archive..."
cd "$INSTALL_DIR"
ARCHIVE_NAME="fpm-${FPM_VERSION}-ruby-${RUBY_VERSION}-$(uname -s | tr '[:upper:]' '[:lower:]')-${TARGET_ARCH:-$(uname -m)}.7z"

7za a -mx=9 -mfb=64 "$OUTPUT_DIR/$ARCHIVE_NAME" "$INSTALL_DIR"/*
echo "🚢 Portable Ruby $RUBY_VERSION built and bundled at:"
echo "  ⏭️ Directory: $OUTPUT_DIR"
echo "  ⏭️ Full Path: $OUTPUT_DIR/$ARCHIVE_NAME"
