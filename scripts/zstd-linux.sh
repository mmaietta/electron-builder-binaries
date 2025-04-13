#!/usr/bin/env bash
set -ex

# dependency for minimkube
# curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
# sudo dpkg -i minikube_latest_amd64.deb

# shellcheck disable=SC2046
# eval $(minikube -p minikube docker-env)

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cidFile="/tmp/zstd-build-container-id"
if test -f "$cidFile"; then
  echo "already running (removing $cidFile)"
  containerId=$(cat "$cidFile")
  docker rm "$containerId"
  unlink "$cidFile"
fi

cd "$BASEDIR../"
docker run --cidfile="$cidFile" buildpack-deps:bionic bash -c \
'git clone --depth 1 --branch v1.5.0 https://github.com/facebook/zstd.git && cd zstd && make -j5 install && cd .. &&
 git clone --depth 1 --branch 4.5 https://github.com/plougher/squashfs-tools && cd squashfs-tools/squashfs-tools &&
 apt-get update -y && apt-get install -y liblzo2-dev && make -j5 XZ_SUPPORT=1 LZO_SUPPORT=1 ZSTD_SUPPORT=1 GZIP_SUPPORT=0 COMP_DEFAULT=zstd install &&
 cp /usr/local/bin/mksquashfs /tmp/mksquashfs-64
 '

containerId=$(cat "$cidFile")
docker cp "$containerId":/usr/local/bin/zstd zstd/linux-x64/zstd
docker cp "$containerId":/tmp/mksquashfs-64 AppImage/linux-x64/mksquashfs
# docker cp "$containerId":/tmp/mksquashfs-32 AppImage/linux-ia32/mksquashfs
docker rm "$containerId"
unlink "$cidFile"

docker run --cidfile="$cidFile" i386/buildpack-deps:bionic bash -c \
'git clone --depth 1 --branch v1.5.0 https://github.com/facebook/zstd.git && cd zstd && make -j5 install && cd .. &&
 git clone --depth 1 --branch 4.5 https://github.com/plougher/squashfs-tools && cd squashfs-tools/squashfs-tools &&
 apt-get update -y && apt-get install -y liblzo2-dev && make -j5 XZ_SUPPORT=1 LZO_SUPPORT=1 ZSTD_SUPPORT=1 GZIP_SUPPORT=0 COMP_DEFAULT=zstd install &&
 cp /usr/local/bin/mksquashfs /tmp/mksquashfs-32
 '
containerId=$(cat "$cidFile")
docker cp "$containerId":/tmp/mksquashfs-32 AppImage/linux-ia32/mksquashfs
docker rm "$containerId"
unlink "$cidFile"
