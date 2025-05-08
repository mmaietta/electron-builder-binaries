#!/usr/bin/env bash
set -euo pipefail

BASEDIR=$(cd "$(dirname "$BASH_SOURCE")/../.." && pwd)
source $BASEDIR/scripts/utils.sh

TMP_DIR=/tmp/fpm
rm -rf $TMP_DIR
mkdir -p $TMP_DIR

# --------------------------------------------------------

BUNDLE_DIR=$TMP_DIR/lib/portable-ruby
rm -rf "$BUNDLE_DIR"

# copy vendor files directly from the npm package
echo "[+] Copying fpm files from pnpm install..."
GIT_REPO_DIR=$TMP_DIR/lib/app
mkdir -p $GIT_REPO_DIR
cp -a $BASEDIR/packages/fpm/node_modules/fpm/{bin,lib,misc,templates} $GIT_REPO_DIR

VENDOR_DIR=$TMP_DIR/lib/vendor
mkdir -p $VENDOR_DIR/lib/fpm
cp -a $BASEDIR/packages/fpm/assets/.bundle $VENDOR_DIR/
cp -a $BASEDIR/packages/fpm/node_modules/fpm/{Gemfile*,fpm.gemspec} $VENDOR_DIR/
cp -a $BASEDIR/packages/fpm/node_modules/fpm/lib/fpm/version.rb $VENDOR_DIR/lib/fpm/version.rb

LIB_DIR="$BUNDLE_DIR/lib"
BIN_REAL_DIR="$BUNDLE_DIR/bin.real"
mkdir -p "$BIN_REAL_DIR" "$LIB_DIR"

echo "[+] Installing Ruby deps..."
for gems in "bundler -v 2.6.2" "ostruct logger"; do
    echo "  ↳ Installing $gems"
    GEM_COMMAND="gem install $gems --no-document --quiet"
    $GEM_COMMAND || sudo $GEM_COMMAND
done
echo "[+] Installing fpm bundle..."
(cd "$VENDOR_DIR" && bundle install --path=. --without development test)
rm -rf "$VENDOR_DIR/**/cache"

# copy ruby interpreter and libraries
RUBY_BIN="$(which ruby)"
RUBY_REAL_BIN="$(readlink -f "$RUBY_BIN")"

GEM_DIR=$(ruby -e 'puts Gem.dir')
STD_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["rubylibdir"]')
SITE_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["sitelibdir"]')
VENDOR_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["vendorlibdir"]')
BIN_DIR=$(ruby -e 'puts RbConfig::CONFIG["bindir"]')

echo "[+] Merging core Ruby directories for easier env access..."
echo "  ↳ $GEM_DIR -> $BUNDLE_DIR/"
rsync -a "$GEM_DIR" "$BUNDLE_DIR/"
echo "  ↳ $STD_LIB_DIR -> $BUNDLE_DIR/"
rsync -a "$STD_LIB_DIR" "$BUNDLE_DIR/"
echo "  ↳ $SITE_LIB_DIR -> $BUNDLE_DIR/"
rsync -a "$SITE_LIB_DIR" "$BUNDLE_DIR/"
echo "  ↳ $VENDOR_LIB_DIR -> $BUNDLE_DIR/"
rsync -a "$VENDOR_LIB_DIR" "$BUNDLE_DIR/"
echo "  ↳ $BIN_DIR -> $BIN_REAL_DIR/"
rsync -a "$BIN_DIR"/* "$BIN_REAL_DIR/"

if [ "$(uname)" = "Darwin" ]; then
    # === CONFIG ===
    RUBY_REAL_BIN="$(greadlink -f "$RUBY_BIN" 2>/dev/null || realpath "$RUBY_BIN")"
    RUBY_PREFIX="$(readlink -f $(brew --prefix ruby))"
    BUNDLE_DIR=$TMP_DIR/portable-ruby
    BIN_REAL_DIR="$BUNDLE_DIR/bin.real"

    echo "[+] Ruby binary found: $RUBY_REAL_BIN"
    echo "[+] Ruby prefix: $RUBY_PREFIX"

    # === CLEANUP ===
    rm -rf "$BUNDLE_DIR"
    mkdir -p "$BUNDLE_DIR"

    # === COPY RUBY INSTALL TREE ===
    echo "[+] Copying Ruby installation..."
    cp -a "$RUBY_PREFIX" "$BUNDLE_DIR/ruby"

    echo "[+] Copying Ruby gems..."
    mkdir -p "$BUNDLE_DIR/ruby/bin.real"
    GEMS="bundle bundler gem irb rake ruby"
    for bin in $GEMS; do
        echo "  ↳ $bin"
        cp -aL "$(which $bin)" "$BUNDLE_DIR/ruby/bin.real/$bin"
    done

    # === EXTRACT SHARED LIB DEPENDENCIES ===
    echo "[+] Scanning Ruby binary for dynamic libraries..."
    mkdir -p "$BUNDLE_DIR/lib"

    otool -L "$RUBY_REAL_BIN" | grep -v ":" | awk '{print $1}' | while read lib; do
        if [[ "$lib" == /usr/lib/* || "$lib" == /System/* ]]; then
            echo "  [SKIP] System library: $lib"
            continue
        fi
        echo "  ↳ $lib"
        cp -f "$lib" "$BUNDLE_DIR/lib/$(basename $lib)"
    done

    # === PATCH BINARY PATHS ===
    # echo "[+] Patching Ruby binary install names..."
    # cd "$BUNDLE_DIR/ruby/bin"
    # for cmd in ruby irb gem; do
    #     bin="$BUNDLE_DIR/ruby/bin.real/$cmd"
    #     [[ -x "$bin" ]] || continue
    #     otool -L "$bin" | grep -v ":" | awk '{print $1}' | while read lib; do
    #         if [[ "$lib" == @* || "$lib" == /usr/* || "$lib" == /System/* ]]; then
    #             continue
    #         fi
    #         libname=$(basename "$lib")
    #         echo "  [REWRITE] $lib -> @loader_path/../lib/$libname"
    #         # install_name_tool -change "$lib" "@loader_path/../lib/$libname" "$bin"
    #     done
    #     install_name_tool -add_rpath @executable_path/../lib $bin
    # done
    # cd ../../..

    # for bin in ruby irb gem; do
    # install_name_tool -add_rpath @executable_path/../lib $BUNDLE_DIR/ruby/bin.real/$bin
    # done
else
    # Linux
    echo "[+] Patching RPATH to use bundled libraries..."
    patchelf --set-rpath '$ORIGIN/../lib' "$BIN_REAL_DIR/ruby"

    # Find and copy all shared lib dependencies
    echo "[+] Collecting shared library dependencies..."
    ldd "$RUBY_REAL_BIN" | awk '/=>/ { print $3 }' | while read -r lib; do
        if [[ -n "$lib" && -f "$lib" ]]; then
            echo "  ↳ Copying $lib"
            cp -u "$lib" "$LIB_DIR/"
            chmod 777 "$LIB_DIR/$(basename "$lib")"
        fi
    done
    # Copy libruby*.so from LD_LIBRARY_PATH manually if missed
    if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
        find ${LD_LIBRARY_PATH//:/ } -name 'libruby-*.so*' -exec cp -u {} "$LIB_DIR/" \;
    fi
fi

# create entry scripts
echo "[+] Creating entrypoint/wrapper scripts..."
ENTRY_SCRIPT=$TMP_DIR/fpm
echo "  ↳ fpm entrypoint -> $ENTRY_SCRIPT"
cat "$BASEDIR/packages/fpm/assets/fpm" | sed "s|GEM_DIR|$(basename "$GEM_DIR")|g" >$ENTRY_SCRIPT
chmod +x $ENTRY_SCRIPT

mkdir -p $BUNDLE_DIR/bin $BIN_REAL_DIR
for FILE in "$BIN_REAL_DIR"/*; do
    BIN=$(basename "$FILE")
    # Skip if not executable
    if [[ ! -x "$FILE" ]]; then
        echo "  [SKIP] $BIN"
        continue
    fi
    ENTRY_SCRIPT="$BUNDLE_DIR/bin/$BIN"
    echo "  ↳ $BIN -> $ENTRY_SCRIPT"
    cat "$BASEDIR/packages/fpm/assets/entrypoint.sh" | sed "s|GEM_DIR|$(basename "$GEM_DIR")|g" >$ENTRY_SCRIPT
    echo "exec \"\$ROOT/bin.real/ruby\" \"\$ROOT/bin.real/$BIN\" \"\$@\"" >>$ENTRY_SCRIPT
    chmod +x $ENTRY_SCRIPT
done

ENTRY_SCRIPT=$BUNDLE_DIR/bin/ruby
echo "  ↳ ruby entrypoint -> $ENTRY_SCRIPT"
cat "$BASEDIR/packages/fpm/assets/entrypoint.sh" | sed "s|GEM_DIR|$(basename "$GEM_DIR")|g" >$ENTRY_SCRIPT
echo "exec \"\$ROOT/bin.real/ruby\" \"\$@\"" >>$ENTRY_SCRIPT
chmod +x $ENTRY_SCRIPT

echo "[+} Creating VERSION file..."
RUBY=$TMP_DIR/lib/portable-ruby/bin.real/ruby
# RUBY_VERSION=$($RUBY --version)
# FPM_VERSION=$($TMP_DIR/fpm --version)
# echo "$RUBY_VERSION" > $TMP_DIR/VERSION.txt
# echo "Fpm: $FPM_VERSION" >> $TMP_DIR/VERSION.txt

# OUTPUT_FILE=${1:-"fpm-$FPM_VERSION-ruby$($RUBY -e 'puts RUBY_VERSION').7z"}
# echo "[+] Compressing files -> $OUTPUT_FILE"
# compressArtifact $OUTPUT_FILE $TMP_DIR
