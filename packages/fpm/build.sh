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

# copy ruby interpreter and libraries
RUBY_BIN="$(which ruby)"
# GEM_HOME="/tmp/.ruby_bundle_gems"
if [ "$(uname)" = "Darwin" ]; then
    # # MacOS
    # cp -a $(otool -L $RUBY_EXEC | grep -E 'libssl|libcrypto|libruby' | awk '{print $1}') $INTERPRETER/bin/
    # cp -a $(otool -L $RUBY_EXEC | grep -E 'libssl|libcrypto|libruby' | awk '{print $3}' | sed 's/\/usr\/local\///') $INTERPRETER/bin/
    # cp -a $(otool -L $RUBY_EXEC | grep -E 'libffi|libgmp|libreadline' | awk '{print $1}') $INTERPRETER/lib/
    # cp -a $(otool -L $RUBY_EXEC | grep -E 'libffi|libgmp|libreadline' | awk '{print $3}' | sed 's/\/usr\/local\///') $INTERPRETER/lib/
    # === CONFIG ===
    RUBY_REAL_BIN="$(greadlink -f "$RUBY_BIN" 2>/dev/null || realpath "$RUBY_BIN")"
    RUBY_PREFIX="$(readlink -f $(brew --prefix ruby))"
    BUNDLE_DIR=$TMP_DIR/lib

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
        echo "  [COPY] $bin"
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
        echo "  [COPY] $lib"
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
    RUBY_BIN="$(which ruby)"
    RUBY_REAL_BIN="$(readlink -f "$RUBY_BIN")"
    BUNDLE_DIR=$TMP_DIR/lib/ruby

    echo "[+] Ruby binary: $RUBY_REAL_BIN"

    # === CLEANUP ===
    rm -rf "$BUNDLE_DIR" "$ARCHIVE_PATH"
    LIB_DIR="$BUNDLE_DIR/lib"
    BIN_REAL_DIR="$BUNDLE_DIR/bin.real"
    mkdir -p "$BUNDLE_DIR/bin" "$BIN_REAL_DIR" "$LIB_DIR" "$BUNDLE_DIR/share"

    # === COPY RUBY BINARY ===
    echo "[+] Copying Ruby binary..."
    cp -a "$RUBY_REAL_BIN" "$BIN_REAL_DIR/ruby"

    echo "[+] Copying Ruby gems..."
    GEMS="bundle bundler irb" # puma rake redcarpet thin unicorn"
    GEM_COMMAND="gem install $GEMS --no-document --quiet"
    $GEM_COMMAND || sudo $GEM_COMMAND
    for bin in gem $GEMS; do
        echo "  ↳ Copying $bin"
        cp -aL "$(which $bin)" "$BIN_REAL_DIR/$bin"
    done

    echo "[+] Patching RPATH to use bundled lib/"
    patchelf --set-rpath '$ORIGIN/../lib' "$BIN_REAL_DIR/ruby"
    for bin in gem $GEMS; do
        patchelf --set-rpath '$ORIGIN/../lib' "$BIN_REAL_DIR/$bin"
    done
    # Find and copy all shared lib dependencies
    echo "[+] Collecting shared library dependencies..."
    ldd "$RUBY_REAL_BIN" | awk '/=>/ { print $3 }' | while read -r lib; do
        if [[ -n "$lib" && -f "$lib" ]]; then
            echo "  ↳ Copying $lib"
            cp -u "$lib" "$LIB_DIR/"
        fi
    done
    # Copy libruby*.so from LD_LIBRARY_PATH manually if missed
    if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
        find ${LD_LIBRARY_PATH//:/ } -name 'libruby-*.so*' -exec cp -u {} "$LIB_DIR/" \;
    fi
fi

# copy vendor files directly from the npm package
GIT_REPO_DIR=$TMP_DIR/lib/app
mkdir -p $GIT_REPO_DIR
cp -a $BASEDIR/packages/fpm/node_modules/fpm/{bin,lib,misc,templates} $GIT_REPO_DIR

VENDOR_DIR=$TMP_DIR/lib/vendor
mkdir -p $VENDOR_DIR/lib/fpm
cp -a $BASEDIR/packages/fpm/assets/.bundle $VENDOR_DIR/
cp -a $BASEDIR/packages/fpm/node_modules/fpm/{Gemfile*,fpm.gemspec} $VENDOR_DIR/
cp -a $BASEDIR/packages/fpm/node_modules/fpm/lib/fpm/version.rb $VENDOR_DIR/lib/fpm/version.rb

# export GEM_HOME
gem install bundle bundler --no-document --quiet || sudo gem install bundler --no-document --quiet
cd "$VENDOR_DIR"
bundle install
rm -rf "$VENDOR_DIR/**/cache"

# create entry scripts
ENTRY_SCRIPT=$TMP_DIR/fpm
echo "  [COPY] fpm entrypoint -> $ENTRY_SCRIPT"
cp "$BASEDIR/packages/fpm/assets/fpm" $ENTRY_SCRIPT
chmod +x $ENTRY_SCRIPT

mkdir -p $BUNDLE_DIR/bin $BIN_REAL_DIR
for bin in gem irb rake; do
    ENTRY_SCRIPT="$BUNDLE_DIR/bin/$bin"
    echo "  [COPY] $bin -> $ENTRY_SCRIPT"
    cp "$BASEDIR/packages/fpm/assets/entrypoint.sh" $ENTRY_SCRIPT
    echo "exec "\$ROOT/bin.real/ruby" "\$ROOT/bin.real/$bin" "\$@"" >>$ENTRY_SCRIPT
    chmod +x $ENTRY_SCRIPT
done

ENTRY_SCRIPT=$BUNDLE_DIR/bin/ruby_environment
echo "  [COPY] ruby_environment -> $ENTRY_SCRIPT"
cat $BASEDIR/packages/fpm/assets/ruby_environment | sed "s|RUBY_VERSION|$RUBY_VERSION|g" >$ENTRY_SCRIPT
chmod +x $ENTRY_SCRIPT

ENTRY_SCRIPT=$BUNDLE_DIR/bin/ruby
echo "  [COPY] ruby entrypoint -> $ENTRY_SCRIPT"
cp "$BASEDIR/packages/fpm/assets/entrypoint.sh" $ENTRY_SCRIPT
echo "exec "\$ROOT/bin.real/ruby" "\$@"" >>$ENTRY_SCRIPT
chmod +x $ENTRY_SCRIPT

ENTRY_SCRIPT=$BUNDLE_DIR/lib/restore_environment.rb
echo "  [COPY] restore_environment.rb -> $ENTRY_SCRIPT"
cp $BASEDIR/packages/fpm/assets/{restore_environment.rb,ca-bundle.crt} $BUNDLE_DIR/lib/
chmod +x $ENTRY_SCRIPT

GEM_DIR=$(ruby -e 'puts Gem.dir')
STD_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["rubylibdir"]')
SITE_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["sitelibdir"]')
VENDOR_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["vendorlibdir"]')
mkdir -p $TMP_DIR/lib/ruby/lib/ruby/gems $TMP_DIR/lib/ruby/lib/ruby/site_ruby $TMP_DIR/lib/ruby/lib/ruby/vendor_ruby
echo "  [COPY] $GEM_DIR -> $TMP_DIR/lib/ruby/lib/ruby/gems/$RUBY_VERSION"
cp -a $GEM_DIR $TMP_DIR/lib/ruby/lib/ruby/gems/$RUBY_VERSION
echo "  [COPY] $STD_LIB_DIR -> $TMP_DIR/lib/ruby/lib/ruby"
cp -a $STD_LIB_DIR $TMP_DIR/lib/ruby/lib/ruby
echo "  [COPY] $SITE_LIB_DIR -> $TMP_DIR/lib/ruby/lib/ruby/site_ruby"
cp -a $SITE_LIB_DIR $TMP_DIR/lib/ruby/lib/ruby/site_ruby || true
echo "  [COPY] $VENDOR_LIB_DIR -> $TMP_DIR/lib/ruby/lib/ruby/vendor_ruby"
cp -a $VENDOR_LIB_DIR $TMP_DIR/lib/ruby/lib/ruby/vendor_ruby || true

compressArtifact $OUTPUT_FILE $TMP_DIR
