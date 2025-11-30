# syntax=docker/dockerfile:experimental
ARG PLATFORM_ARCH=amd64
FROM --platform=${PLATFORM_ARCH} ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    git cmake build-essential pkg-config \
    libssl-dev libcurl4-openssl-dev libgsf-1-dev \
    p7zip-full zip curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# Install a modern pre-built CMake (3.17+)
ARG CMAKE_VERSION=3.28.3

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) cm_arch="x86_64" ;; \
      arm64) cm_arch="aarch64" ;; \
      i386)  cm_arch="i386" ;; \
      *) echo "Unsupported architecture: $arch"; exit 1 ;; \
    esac; \
    curl -sSL -o cmake.tar.gz \
      "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${cm_arch}.tar.gz"; \
    mkdir -p /opt/cmake; \
    tar -xzf cmake.tar.gz --strip-components=1 -C /opt/cmake; \
    rm cmake.tar.gz; \
    ln -sf /opt/cmake/bin/cmake /usr/local/bin/cmake; \
    ln -sf /opt/cmake/bin/ctest /usr/local/bin/ctest; \
    cmake --version

ARG OSSLSIGNCODE_VER=2.9
RUN git clone --depth 1 --branch ${OSSLSIGNCODE_VER} \
    https://github.com/mtrojnar/osslsigncode.git

WORKDIR /usr/src/osslsigncode/build
COPY ./assets/compiler-flags.sh /tmp/compiler-flags.sh

# CMake configure & build
ARG PLATFORM_ARCH
RUN cmake .. -DCMAKE_BUILD_TYPE=Release $(/tmp/compiler-flags.sh "${PLATFORM_ARCH}") \
    && make -j$(nproc)

# Output
WORKDIR /out/linux
COPY ./assets/patch-osslsigncode.sh /tmp/patch.sh
RUN bash /tmp/patch.sh /usr/src/osslsigncode/build/osslsigncode /out/linux/osslsigncode
