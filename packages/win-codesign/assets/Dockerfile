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

ARG CMAKE_VER=3.27.9
# Set a variable for cmake installation path
ENV CMAKE_INSTALL_DIR=/usr/local

# Only download prebuilt Kitware CMake for amd64 host
RUN if [ "$PLATFORM_ARCH" = "amd64" ]; then \
        CMAKE_VER=3.27.9 && \
        curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}-Linux-x86_64.sh && \
        chmod +x cmake-${CMAKE_VER}-Linux-x86_64.sh && \
        ./cmake-${CMAKE_VER}-Linux-x86_64.sh --skip-license --prefix=$CMAKE_INSTALL_DIR && \
        rm cmake-${CMAKE_VER}-Linux-x86_64.sh ; \
    else \
        # Build from source for i386/arm64
        CMAKE_VER=3.27.9 && \
        curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}.tar.gz && \
        tar xf cmake-${CMAKE_VER}.tar.gz && cd cmake-${CMAKE_VER} && \
        ./bootstrap --prefix=$CMAKE_INSTALL_DIR && \
        make -j$(nproc) && make install && cd .. && rm -rf cmake-${CMAKE_VER}* ; \
    fi

ENV PATH=$CMAKE_INSTALL_DIR/bin:$PATH

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
