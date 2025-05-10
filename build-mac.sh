#!/usr/bin/env bash
set -ex

CWD=$(cd "$(dirname "$0")" && pwd)
export OS_TARGET="darwin"
bash "$CWD/packages/fpm/build.sh"