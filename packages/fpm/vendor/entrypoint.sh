#!/bin/bash
set -e
ROOT=`dirname "$0"`
ROOT=`cd "$ROOT/.." && pwd`
eval "`\"$ROOT/bin/ruby_environment\"`"

# command is injected into this script by build.sh

