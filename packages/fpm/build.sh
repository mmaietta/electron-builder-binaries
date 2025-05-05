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
GEM_HOME="/tmp/.ruby_bundle_gems"
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
    # cd "$BUNDLE_DIR/ruby/bin"
    # for bin in ruby irb gem; do
    #     [[ -x "$bin" ]] || continue
    #     otool -L "$bin" | grep -v ":" | awk '{print $1}' | while read lib; do
    #         if [[ "$lib" == @* || "$lib" == /usr/* || "$lib" == /System/* ]]; then
    #             continue
    #         fi
    #         libname=$(basename "$lib")
    #         echo "  [REWRITE] $lib -> @loader_path/../lib/$libname"
    #         install_name_tool -change "$lib" "@loader_path/../lib/$libname" "$bin"
    #     done
    # done
    # cd ../../..

    mkdir -p "$BUNDLE_DIR/ruby/bin.real"
    GEMS="bundle bundler gem irb rake ruby"
    for bin in $GEMS; do
        echo "  [COPY] $bin"
        cp -av "$(which $bin)" "$BUNDLE_DIR/ruby/bin.real/"
        cp -avf "$(readlink -f "$(which $bin)")" "$BUNDLE_DIR/ruby/bin.real/"
    done
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
    GEM_COMMAND="gem install bundle bundler --no-document --quiet"
    $GEM_COMMAND || sudo $GEM_COMMAND

    echo "[+] Copying Ruby gems..."
    GEMS="bundle bundler gem irb rake ruby"
    for bin in $GEMS; do
        echo "  [COPY] $bin"
        cp -av "$(which $bin)" "$BUNDLE_DIR/bin.real/"
        cp -avf "$(readlink -f "$(which $bin)")" "$BUNDLE_DIR/bin.real/"
    done
    echo "[+] Patching RPATH to use bundled lib/"
    patchelf --set-rpath  '$ORIGIN/../lib' "$BUNDLE_DIR/bin.real/$(basename $RUBY_REAL_BIN)"

    # === COPY SHARED LIBRARIES ===
    echo "[+] Copying dynamic libraries..."
    ldd "$RUBY_REAL_BIN" | awk '{print $3}' | grep -v '^(' | while read lib; do
        if [[ ! "$lib" ]]; then
            # skip empty lines
            continue
        fi
        echo "  [COPY] $lib"
        cp -a "$lib" "$BUNDLE_DIR/lib/$(basename $lib)"
        realLib="$(readlink -f "$lib")"
        cp -avf "$realLib" "$BUNDLE_DIR/lib/$(basename $realLib)"
        # cp --parents -L "$lib" "$BUNDLE_DIR/lib/"
    done

    # === COPY RUBY STD LIB ===
    # STD_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["rubylibdir"]')
    # SITE_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["sitelibdir"]')
    # VENDOR_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["vendorlibdir"]')

    # echo "[+] Copying standard libraries..."
    # cp -a "$STD_LIB_DIR" "$BUNDLE_DIR/share/"
    # cp -a "$SITE_LIB_DIR" "$BUNDLE_DIR/share/" || true
    # cp -a "$VENDOR_LIB_DIR" "$BUNDLE_DIR/share/" || true
fi

# copy vendor files directly from the npm package
GIT_REPO_DIR=$TMP_DIR/lib/app
mkdir -p $GIT_REPO_DIR
cp -a $BASEDIR/packages/fpm/node_modules/fpm/{bin,lib,misc,templates} $GIT_REPO_DIR

mkdir -p $TMP_DIR/lib/vendor/lib/fpm
cp -a $BASEDIR/packages/fpm/vendor/.bundle $TMP_DIR/lib/vendor/
cp -a $BASEDIR/packages/fpm/node_modules/fpm/{Gemfile*,fpm.gemspec} $TMP_DIR/lib/vendor/
cp -a $BASEDIR/packages/fpm/node_modules/fpm/lib/fpm/version.rb $TMP_DIR/lib/vendor/lib/fpm/version.rb

export GEM_HOME
gem install bundle bundler --no-document --quiet || sudo gem install bundler --no-document --quiet
cd $TMP_DIR/lib/vendor
bundle install
rm -rf "$TMP_DIR/lib/vendor/**/cache"

# create entry scripts
ENTRY_SCRIPT=$TMP_DIR/fpm
cat >$ENTRY_SCRIPT <<'EOL'
#!/bin/bash
set -e

# Figure out where this script is located.
SELFDIR="`dirname \"$0\"`"
SELFDIR="`cd \"$SELFDIR\" && pwd`"

# Tell Bundler where the Gemfile and gems are.
export BUNDLE_GEMFILE="$SELFDIR/lib/vendor/Gemfile"
unset BUNDLE_IGNORE_CONFIG

# Run the actual app using the bundled Ruby interpreter, with Bundler activated.
LIB_DIR="$SELFDIR/lib"
exec "$LIB_DIR/ruby/bin/ruby" -rbundler/setup "$LIB_DIR/app/bin/fpm" "$@"
EOL
chmod +x $ENTRY_SCRIPT

mkdir -p $BUNDLE_DIR/bin $BUNDLE_DIR/bin.real
for bin in gem irb rake; do
    ENTRY_SCRIPT="$BUNDLE_DIR/bin/$bin"
    echo "  [COPY] $bin -> $ENTRY_SCRIPT"
    cp "$BASEDIR/packages/fpm/vendor/entrypoint.sh" $ENTRY_SCRIPT
    echo "exec "\$ROOT/bin.real/ruby" "\$ROOT/bin.real/$bin" "\$@"" >> $ENTRY_SCRIPT
    chmod +x $ENTRY_SCRIPT
done

ENTRY_SCRIPT=$BUNDLE_DIR/bin/ruby_environment
echo "  [COPY] ruby_environment -> $ENTRY_SCRIPT"
cat $BASEDIR/packages/fpm/vendor/ruby_environment | sed "s|RUBY_VERSION|$RUBY_VERSION|g" > $ENTRY_SCRIPT
chmod +x $ENTRY_SCRIPT

ENTRY_SCRIPT=$BUNDLE_DIR/bin/ruby
echo "  [COPY] ruby entrypoint -> $ENTRY_SCRIPT"
cat $BASEDIR/packages/fpm/vendor/entrypoint.sh > $ENTRY_SCRIPT
echo "exec "\$ROOT/bin.real/ruby" "\$@"" >> $ENTRY_SCRIPT
chmod +x $ENTRY_SCRIPT

ENTRY_SCRIPT=$BUNDLE_DIR/lib/restore_environment.rb
echo "  [COPY] restore_environment.rb -> $ENTRY_SCRIPT"
cp $BASEDIR/packages/fpm/vendor/{restore_environment.rb,ca-bundle.crt} $BUNDLE_DIR/lib/
chmod +x $ENTRY_SCRIPT

GEM_DIR=$(ruby -e 'puts Gem.dir')
STD_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["rubylibdir"]')
SITE_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["sitelibdir"]')
VENDOR_LIB_DIR=$(ruby -e 'puts RbConfig::CONFIG["vendorlibdir"]')
mkdir -p $TMP_DIR/lib/ruby/lib/ruby/gems $TMP_DIR/lib/ruby/lib/ruby/site_ruby $TMP_DIR/lib/ruby/lib/ruby/vendor_ruby
cp -a $GEM_DIR $TMP_DIR/lib/ruby/lib/ruby/gems/$RUBY_VERSION
cp -a $STD_LIB_DIR $TMP_DIR/lib/ruby/lib/ruby
cp -a $SITE_LIB_DIR $TMP_DIR/lib/ruby/lib/ruby/site_ruby || true
cp -a $VENDOR_LIB_DIR $TMP_DIR/lib/ruby/lib/ruby/vendor_ruby || true

compressArtifact $OUTPUT_FILE $TMP_DIR
