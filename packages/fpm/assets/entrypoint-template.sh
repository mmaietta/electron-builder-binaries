#!/bin/bash
# Wrapper to run portable Ruby
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUBY_DIR="$SCRIPT_DIR/ruby-install"
export PATH="$RUBY_DIR/bin:$PATH"
export GEM_HOME="$RUBY_DIR/gems"
export GEM_PATH="$GEM_HOME"
export RUBYLIB="$RUBY_DIR/lib:$RUBYLIB"

exec "$RUBY_DIR/bin/EXECUTABLE" "$@"
