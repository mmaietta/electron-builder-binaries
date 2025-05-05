#!/usr/bin/env bash
set -e

OUTPUT_FILE=${1:-fpm.7z}

BASEDIR=$(cd "$(dirname "$BASH_SOURCE")/../.." && pwd)
source $BASEDIR/scripts/utils.sh

TMP_DIR=/tmp/fpm
rm -rf $TMP_DIR
mkdir -p $TMP_DIR

# --------------------------------------------------------

source $BASEDIR/packages/fpm/version.sh # exports RUBY_VERSION & FPM_VERSION
echo "RUBY_VERSION: $RUBY_VERSION"
echo "FPM_VERSION: $FPM_VERSION"

# rm -f $BASEDIR/Gemfile

# sudo might be needed for some systems (e.g. ubuntu GH runners)
# gem install bundler --no-document --quiet || sudo gem install bundler --no-document --quiet

# cd "$(dirname "$BASH_SOURCE")"
# # echo "\"ruby\" \"$RUBY_VERSION\"" >> Gemfile
# # echo "gem \"fpm\", \"$FPM_VERSION\"" >> Gemfile

# bundle config set path "$TMP_DIR/"
# bundle install

# --------------------------------------------------------
# rm -rf $TMP_DIR/ruby/$RUBY_VERSION/{build_info,cache,doc,extensions,doc,plugins,specifications,tests}
echo "Fpm: $FPM_VERSION" >$TMP_DIR/VERSION.txt
echo "Ruby: $RUBY_VERSION" >>$TMP_DIR/VERSION.txt

# copy vendor files directly from the npm package
GIT_REPO_DIR=$TMP_DIR/lib/app
mkdir -p $GIT_REPO_DIR
cp -a $BASEDIR/packages/fpm/node_modules/fpm/{bin,lib,misc,templates} $GIT_REPO_DIR

# copy ruby interpreter and libraries
BUNDLE_DIR=$TMP_DIR/lib/ruby
RUBY_BIN="$(which ruby)"
if [ "$(uname)" = "Darwin" ]; then
    # # MacOS
    # cp -a $(otool -L $RUBY_EXEC | grep -E 'libssl|libcrypto|libruby' | awk '{print $1}') $INTERPRETER/bin/
    # cp -a $(otool -L $RUBY_EXEC | grep -E 'libssl|libcrypto|libruby' | awk '{print $3}' | sed 's/\/usr\/local\///') $INTERPRETER/bin/
    # cp -a $(otool -L $RUBY_EXEC | grep -E 'libffi|libgmp|libreadline' | awk '{print $1}') $INTERPRETER/lib/
    # cp -a $(otool -L $RUBY_EXEC | grep -E 'libffi|libgmp|libreadline' | awk '{print $3}' | sed 's/\/usr\/local\///') $INTERPRETER/lib/
    # === CONFIG ===
    RUBY_REAL_BIN="$(greadlink -f "$RUBY_BIN" 2>/dev/null || realpath "$RUBY_BIN")"
    RUBY_PREFIX="$(readlink -f $(brew --prefix ruby))"

    echo "[+] Ruby binary found: $RUBY_REAL_BIN"
    echo "[+] Ruby prefix: $RUBY_PREFIX"

    # === CLEANUP ===
    rm -rf "$BUNDLE_DIR"
    mkdir -p "$BUNDLE_DIR"

    # === COPY RUBY INSTALL TREE ===
    echo "[+] Copying Ruby installation..."
    cp -a "$RUBY_PREFIX" "$BUNDLE_DIR/ruby"

    # === EXTRACT SHARED LIB DEPENDENCIES ===
    echo "[+] Scanning Ruby binary for dynamic libraries..."
    mkdir -p "$BUNDLE_DIR/lib"

    otool -L "$RUBY_REAL_BIN" | grep -v ":" | awk '{print $1}' | while read lib; do
        if [[ "$lib" == /usr/lib/* || "$lib" == /System/* ]]; then
            echo "  [SKIP] System library: $lib"
            continue
        fi
        echo "  [COPY] $lib"
        cp -f "$lib" "$BUNDLE_DIR/lib/"
    done

    # === PATCH BINARY PATHS ===
    echo "[+] Patching Ruby binary install names..."
    cd "$BUNDLE_DIR/ruby/bin"
    for bin in ruby irb gem; do
        [[ -x "$bin" ]] || continue
        otool -L "$bin" | grep -v ":" | awk '{print $1}' | while read lib; do
            if [[ "$lib" == @* || "$lib" == /usr/* || "$lib" == /System/* ]]; then
                continue
            fi
            libname=$(basename "$lib")
            echo "  [REWRITE] $lib -> @loader_path/../lib/$libname"
            install_name_tool -change "$lib" "@loader_path/../lib/$libname" "$bin"
        done
    done
    cd ../../..
else
    # Linux
    RUBY_BIN="$(which ruby)"
    RUBY_REAL_BIN="$(readlink -f "$RUBY_BIN")"

    echo "[+] Ruby binary: $RUBY_REAL_BIN"

    # === CLEANUP ===
    rm -rf "$BUNDLE_DIR" "$ARCHIVE_PATH"
    mkdir -p "$BUNDLE_DIR/bin" "$BUNDLE_DIR/lib" "$BUNDLE_DIR/share"

    # === COPY RUBY BINARY ===
    echo "[+] Copying Ruby binary..."
    cp "$RUBY_REAL_BIN" "$BUNDLE_DIR/bin/"
    # ln -sf "ruby" "$BUNDLE_DIR/bin/$(basename $RUBY_BIN)" # preserve symlink name

    # === COPY SHARED LIBRARIES ===
    echo "[+] Copying dynamic libraries..."
    ldd "$RUBY_REAL_BIN" | awk '{print $3}' | grep -v '^(' | while read lib; do
        if [[ ! "$lib" ]]; then
            # skip empty lines
            continue
        fi
        echo "  [COPY] $lib"
        cp -v --parents "$lib" "$BUNDLE_DIR/lib/"
    done

    # === COPY RUBY STD LIB ===
    STD_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["rubylibdir"]')
    SITE_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["sitelibdir"]')
    VENDOR_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["vendorlibdir"]')

    echo "[+] Copying standard libraries..."
    cp -a "$STD_LIB_DIR" "$BUNDLE_DIR/share/" || true
    cp -a "$SITE_LIB_DIR" "$BUNDLE_DIR/share/" || true
    cp -a "$VENDOR_LIB_DIR" "$BUNDLE_DIR/share/" || true
fi

# create entry script
cp -a $BASEDIR/packages/fpm/vendor $TMP_DIR/lib/vendor
cp -a $BASEDIR/packages/fpm/node_modules/fpm/{Gemfile*,.bundle,fpm.gemspec} $TMP_DIR/lib/vendor/
mkdir -p $TMP_DIR/lib/vendor/lib/fpm
cp -a $BASEDIR/packages/fpm/node_modules/fpm/lib/fpm/version.rb $TMP_DIR/lib/vendor/lib/fpm/version.rb
cp -a $BASEDIR/packages/fpm/fpm $TMP_DIR/fpm
chmod +x $TMP_DIR/fpm

compressArtifact $OUTPUT_FILE $TMP_DIR
