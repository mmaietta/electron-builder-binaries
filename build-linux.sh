#!/usr/bin/env bash
set -e

CWD=$(cd "$(dirname "$0")" && pwd)

export ARCH=${ARCH:-$(uname -m)}
export OS_TARGET=${OS_TARGET:-$(uname | tr '[:upper:]' '[:lower:]')}
bash "$CWD/packages/fpm/build.sh"