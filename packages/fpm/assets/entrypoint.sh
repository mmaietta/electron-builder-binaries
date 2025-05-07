#!/bin/bash
set -e
ROOT=`dirname "$0"`
ROOT=`cd "$ROOT/.." && pwd`
eval "`\"$ROOT/bin/ruby_environment\"`"
# This script is used to set up the environment for Ruby applications.
# It sets up the necessary environment variables and paths for Ruby to run correctly.

# The exec command is injected into this script during `build.sh` (keep this script's trailing newline)

