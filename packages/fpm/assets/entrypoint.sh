#!/bin/env bash
# This script is used to set up the environment for Ruby applications.
# It sets up the necessary environment variables and paths for Ruby to run correctly.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export GEM_HOME="$ROOT/GEM_DIR" # GEM DIR var replaced with copied dir using `sed` in `build.sh`
export GEM_PATH="$GEM_HOME"
export RUBYLIB="$ROOT/lib:$ROOT/bin:$GEM_HOME:$GEM_HOME/bin:$GEM_HOME/GEM_ARCH_DIR"
export PATH="$RUBYLIB:$PATH"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$ROOT/lib"

export RUBYOPT='-W:no-deprecated'

"$ROOT/bin.real/ruby" "$ROOT/patch-rbconfig.rb"

GEMDIR=$(./lib/portable-ruby/bin.real/ruby -rrbconfig -e 'puts Gem.dir')
STD_LIB_DIR=$(./lib/portable-ruby/bin.real/ruby -rrbconfig -e 'puts RbConfig::CONFIG["rubylibdir"]')
SITE_LIB_DIR=$(./lib/portable-ruby/bin.real/ruby -rrbconfig -e 'puts RbConfig::CONFIG["sitelibdir"]')
VENDOR_LIB_DIR=$(./lib/portable-ruby/bin.real/ruby -rrbconfig -e 'puts RbConfig::CONFIG["vendorlibdir"]')
BIN_DIR=$(./lib/portable-ruby/bin.real/ruby -rrbconfig -e 'puts RbConfig::CONFIG["bindir"]')
RUBY_ARCHDIR=$(./lib/portable-ruby/bin.real/ruby -rrbconfig -e 'puts RbConfig::CONFIG["arch"]')

echo "GEMDIR: $GEMDIR"
echo "STD_LIB_DIR: $STD_LIB_DIR"
echo "SITE_LIB_DIR: $SITE_LIB_DIR"
echo "VENDOR_LIB_DIR: $VENDOR_LIB_DIR"
echo "BIN_DIR: $BIN_DIR"
echo "RUBY_ARCHDIR: $RUBY_ARCHDIR"
echo "GEM_HOME: $GEM_HOME"
echo "GEM_PATH: $GEM_PATH"
echo "PATH: $PATH"

# The exec command is injected into this script during `build.sh` (keep this script's trailing newline)

