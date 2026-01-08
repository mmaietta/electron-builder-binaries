#!/usr/bin/env bash
set -ex

CWD=$(cd "$(dirname "$0")" && pwd)

# squirrel.windows
# depends on git bash
bash "$CWD/packages/squirrel.windows/build.sh"