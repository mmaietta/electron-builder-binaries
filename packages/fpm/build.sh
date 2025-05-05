#!/usr/bin/env bash
set -ex

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
    BUNDLE_DIR=$TMP_DIR/lib/ruby

    echo "[+] Ruby binary: $RUBY_REAL_BIN"

    # === CLEANUP ===
    rm -rf "$BUNDLE_DIR" "$ARCHIVE_PATH"
    mkdir -p "$BUNDLE_DIR/bin" "$BUNDLE_DIR/bin.real" "$BUNDLE_DIR/lib" "$BUNDLE_DIR/share"

    # === COPY RUBY BINARY ===
    echo "[+] Copying Ruby binary..."
    BINARIES=$(dirname "$RUBY_REAL_BIN")
    # cp -a "$BINARIES/gem" "$BUNDLE_DIR/bin/"
    # cp -a "$BINARIES/rake" "$BUNDLE_DIR/bin/"
    # cp -a "$BINARIES/irb" "$BUNDLE_DIR/bin/"
    # cp -a "$BINARIES/$(basename $(readlink -f irb))" "$BUNDLE_DIR/bin/"
    # cp -a "$BINARIES/ruby" "$BUNDLE_DIR/bin/"
    # cp -a "$BINARIES/$(basename $RUBY_REAL_BIN)" "$BUNDLE_DIR/bin/"
    # cd "$BUNDLE_DIR/bin"
    # ln -s "$(basename $RUBY_REAL_BIN)" ruby # preserve symlink name
    # ln -sf "ruby" "$BUNDLE_DIR/bin/$(basename $RUBY_BIN)" # preserve symlink name
    GEM_COMMAND=$(gem install bundle bundler nokogiri puma rackup redcarpet redcloth thin unicorn --no-document --quiet)
    $GEM_COMMAND || sudo $GEM_COMMAND
    # cp -a "$BINARIES/bundle" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/bundler" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/gem" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/irb" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/nokogiri" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/posix-spawn-benchmark" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/puma" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/pumactl" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/rackup" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/rake" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/redcarpet" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/redcloth" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/ruby" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/thin" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/unicorn" "$BUNDLE_DIR/bin.real/"
    # cp -a "$BINARIES/unicorn_rails" "$BUNDLE_DIR/bin.real/"

    GEMS="bundle bundler gem irb rake nokogiri posix-spawn-benchmark puma pumactl rackup redcarpet redcloth thin unicorn unicorn_rails"
    for bin in $GEMS; do
        cp -a "$BINARIES/$bin" "$BUNDLE_DIR/bin.real/"
    done
    for bin in gem irb rake; do
        ENTRY_SCRIPT=$BUNDLE_DIR/bin/$bin
        cat >$ENTRY_SCRIPT <<\EOL
#!/bin/bash
set -e
ROOT=`dirname "$0"`
ROOT=`cd "\$ROOT/.." && pwd`
eval "`\"\$ROOT/bin/ruby_environment\"`"
exec "\$ROOT/bin.real/ruby" "\$ROOT/bin.real/gem" "$@"
EOL
        chmod +x $ENTRY_SCRIPT
    done
    # === COPY SHARED LIBRARIES ===
    echo "[+] Copying dynamic libraries..."
    ldd "$RUBY_REAL_BIN" | awk '{print $3}' | grep -v '^(' | while read lib; do
        if [[ ! "$lib" ]]; then
            # skip empty lines
            continue
        fi
        echo "  [COPY] $lib"
        cp -af "$lib" "$BUNDLE_DIR/lib/$(basename $lib)"
        # cp -f --parents "$lib" "$BUNDLE_DIR/lib/"
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

# copy vendor files directly from the npm package
GIT_REPO_DIR=$TMP_DIR/lib/app
mkdir -p $GIT_REPO_DIR
cp -a $BASEDIR/packages/fpm/node_modules/fpm/{bin,lib,misc,templates} $GIT_REPO_DIR

cp -a $BASEDIR/packages/fpm/vendor $TMP_DIR/lib/vendor
cp -a $BASEDIR/packages/fpm/node_modules/fpm/{Gemfile*,fpm.gemspec} $TMP_DIR/lib/vendor/
mkdir -p $TMP_DIR/lib/vendor/lib/fpm
cp -a $BASEDIR/packages/fpm/node_modules/fpm/lib/fpm/version.rb $TMP_DIR/lib/vendor/lib/fpm/version.rb

gem install bundler --no-document --quiet || sudo gem install bundler --no-document --quiet
cd $TMP_DIR/lib/vendor
bundle install
rm -rf "$TMP_DIR/lib/vendor/**/cache"

# create entry script
ENTRY_SCRIPT=$TMP_DIR/fpm
# cp -a $BASEDIR/packages/fpm/fpm $TMP_DIR/fpm
cat >$ENTRY_SCRIPT <<'EOL'
#!/bin/bash
set -e

# Figure out where this script is located.
SELFDIR="`dirname \"$0\"`"
SELFDIR="`cd \"$SELFDIR\" && pwd`"

# Tell Bundler where the Gemfile and gems are.
export BUNDLE_GEMFILE="$SELFDIR/lib/vendor/Gemfile"
unset BUNDLE_IGNORE_CONFIG

DIR="$SELFDIR/lib"
# export LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH"
# RUBYLIB="$DIR/share"

# Run the actual app using the bundled Ruby interpreter, with Bundler activated.
LD_LIBRARY_PATH="$DIR/ruby/lib:$LD_LIBRARY_PATH" exec "$DIR/ruby/bin/ruby" -rbundler/setup "$DIR/app/bin/fpm" "$@"
EOL
chmod +x $ENTRY_SCRIPT

compressArtifact $OUTPUT_FILE $TMP_DIR
