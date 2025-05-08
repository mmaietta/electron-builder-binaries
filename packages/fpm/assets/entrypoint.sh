#!/bin/env bash
# This script is used to set up the environment for Ruby applications.
# It sets up the necessary environment variables and paths for Ruby to run correctly.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export GEM_HOME="$ROOT/GEM_DIR" # GEM DIR var replaced with copied dir using `sed` in `build.sh`
export GEM_PATH="$GEM_HOME"
export PATH="$ROOT/bin:$GEM_HOME/bin:$PATH"
export RUBYOPT='-W:no-deprecated'

# The exec command is injected into this script during `build.sh` (keep this script's trailing newline)

