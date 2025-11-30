# syntax=docker/dockerfile:1

ARG PLATFORM_ARCH=amd64
ARG OSSLSIGNCODE_VER=2.9
ARG CMAKE_VERSION=3.28.3

FROM ubuntu:20.04 AS builder

# Docker BuildKit automatically provides these when using --platform
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

# Our custom arch parameter
ARG PLATFORM_ARCH
ARG OSSLSIGNCODE_VER
ARG CMAKE_VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/opt/cmake/bin:$PATH

RUN echo "Building on $BUILDPLATFORM for $TARGETPLATFORM" && \
    echo "PLATFORM_ARCH=$PLATFORM_ARCH TARGETARCH=$TARGETARCH"

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git build-essential pkg-config \
    libssl-dev libcurl4-openssl-dev libgsf-1-dev \
    p7zip-full zip ca-certificates xz-utils \
    patchelf file \
    && rm -rf /var/lib/apt/lists/*

# Install CMake (detect architecture at runtime)
RUN ARCH=$(uname -m) && \
    echo "Detected architecture: $ARCH" && \
    if [ "$ARCH" = "x86_64" ]; then \
        CMAKE_ARCH="x86_64" ; \
    elif [ "$ARCH" = "aarch64" ]; then \
        CMAKE_ARCH="aarch64" ; \
    elif [ "$ARCH" = "i686" ] || [ "$ARCH" = "i386" ]; then \
        CMAKE_ARCH="x86_64" ; \
    else \
        echo "Unsupported CMake architecture: $ARCH" && exit 1 ; \
    fi && \
    echo "Downloading CMake for: $CMAKE_ARCH" && \
    curl -sSL -o /tmp/cmake.tar.gz \
    https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${CMAKE_ARCH}.tar.gz \
    && mkdir -p /opt/cmake \
    && tar --strip-components=1 -xzf /tmp/cmake.tar.gz -C /opt/cmake \
    && rm /tmp/cmake.tar.gz

# Verify CMake works
RUN cmake --version

# Clone osslsigncode
WORKDIR /usr/src
RUN git clone --depth 1 --branch ${OSSLSIGNCODE_VER} \
    https://github.com/mtrojnar/osslsigncode.git

# Copy helper scripts
COPY ./assets/compiler-flags.sh /tmp/compiler-flags.sh
RUN chmod +x /tmp/compiler-flags.sh
COPY ./assets/patch-osslsigncode.sh /tmp/patch-osslsigncode.sh
RUN chmod +x /tmp/patch-osslsigncode.sh

# Build osslsigncode (native build for the target platform)
WORKDIR /usr/src/osslsigncode/build
RUN echo "Starting native build for $(uname -m)" && \
    cmake .. -DCMAKE_BUILD_TYPE=Release $(/tmp/compiler-flags.sh "$PLATFORM_ARCH") && \
    make -j$(nproc)

# Verify the binary was built
RUN echo "Verifying binary..." && \
    file /usr/src/osslsigncode/build/osslsigncode && \
    /usr/src/osslsigncode/build/osslsigncode --version

# Create portable bundle
WORKDIR /out/linux
RUN echo "Creating portable bundle with PLATFORM_ARCH=$PLATFORM_ARCH" && \
    PLATFORM_ARCH="${PLATFORM_ARCH}" \
    bash /tmp/patch-osslsigncode.sh \
    /usr/src/osslsigncode/build/osslsigncode \
    /out/linux/osslsigncode

CMD ["/bin/bash"]