# syntax=docker/dockerfile:1
ARG PLATFORM_ARCH=amd64

# ============================================
# Stage 1: Determine Docker platform
# ============================================
FROM --platform=linux/amd64 alpine:3.18 AS platform-mapper
ARG PLATFORM_ARCH
RUN if [ "$PLATFORM_ARCH" = "amd64" ] || [ "$PLATFORM_ARCH" = "x86_64" ]; then \
        echo "linux/amd64" > /platform ; \
    elif [ "$PLATFORM_ARCH" = "arm64" ] || [ "$PLATFORM_ARCH" = "aarch64" ]; then \
        echo "linux/arm64" > /platform ; \
    elif [ "$PLATFORM_ARCH" = "i386" ] || [ "$PLATFORM_ARCH" = "ia32" ]; then \
        echo "linux/386" > /platform ; \
    else \
        echo "Unsupported architecture: $PLATFORM_ARCH" && exit 1 ; \
    fi

# ============================================
# Stage 2: Build osslsigncode natively
# ============================================
ARG PLATFORM_ARCH
FROM --platform=$TARGETPLATFORM ubuntu:20.04 AS builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG PLATFORM_ARCH
ARG OSSLSIGNCODE_VER=2.9
ARG CMAKE_VERSION=3.28.3

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/opt/cmake/bin:$PATH

RUN echo "Building on $BUILDPLATFORM for $TARGETPLATFORM (PLATFORM_ARCH=$PLATFORM_ARCH)"

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git build-essential pkg-config \
    libssl-dev libcurl4-openssl-dev libgsf-1-dev \
    p7zip-full zip ca-certificates xz-utils \
    patchelf file \
    && rm -rf /var/lib/apt/lists/*

# Install CMake (use appropriate version for platform)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        CMAKE_ARCH="x86_64" ; \
    elif [ "$ARCH" = "aarch64" ]; then \
        CMAKE_ARCH="aarch64" ; \
    elif [ "$ARCH" = "i686" ] || [ "$ARCH" = "i386" ]; then \
        CMAKE_ARCH="x86_64" ; \
    else \
        CMAKE_ARCH="$ARCH" ; \
    fi && \
    curl -sSL -o /tmp/cmake.tar.gz \
    https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${CMAKE_ARCH}.tar.gz \
    && mkdir -p /opt/cmake \
    && tar --strip-components=1 -xzf /tmp/cmake.tar.gz -C /opt/cmake \
    && rm /tmp/cmake.tar.gz

# Clone osslsigncode
WORKDIR /usr/src
RUN git clone --depth 1 --branch ${OSSLSIGNCODE_VER} \
    https://github.com/mtrojnar/osslsigncode.git

# Copy helper scripts
COPY ./assets/patch-osslsigncode.sh /tmp/patch-osslsigncode.sh
RUN chmod +x /tmp/patch-osslsigncode.sh

# Build osslsigncode (native build, no cross-compilation)
WORKDIR /usr/src/osslsigncode/build
RUN cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

# Verify the binary was built
RUN file /usr/src/osslsigncode/build/osslsigncode && \
    /usr/src/osslsigncode/build/osslsigncode --version || true

# Create portable bundle
WORKDIR /out/linux
RUN PLATFORM_ARCH="${PLATFORM_ARCH}" \
    bash /tmp/patch-osslsigncode.sh \
    /usr/src/osslsigncode/build/osslsigncode \
    /out/linux/osslsigncode

CMD ["/bin/bash"]