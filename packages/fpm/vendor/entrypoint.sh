#!/bin/bash
set -e
ROOT=`dirname "$0"`
ROOT=`cd "$ROOT/.." && pwd`
eval "`\"$ROOT/bin/ruby_environment\"`"

echo "paths: $LD_LIBRARY_PATH"
# command is injected into this script by build.sh

