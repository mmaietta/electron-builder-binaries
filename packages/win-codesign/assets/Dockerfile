# syntax=docker/dockerfile:1

ARG PLATFORM_ARCH=amd64
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CMAKE_VERSION=3.28.3
ENV PATH=/opt/cmake/bin:$PATH

# Update sources to old-releases since 18.04 is EOL
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' /etc/apt/sources.list \
    && sed -i 's|http://security.ubuntu.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' /etc/apt/sources.list

# Basic build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    libcurl4-openssl-dev \
    libgsf-1-dev \
    p7zip-full \
    zip \
    ca-certificates \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Conditional compiler packages
RUN if [ "$PLATFORM_ARCH" = "amd64" ]; then \
        apt-get update && apt-get install -y gcc-multilib g++-multilib && rm -rf /var/lib/apt/lists/* ; \
    elif [ "$PLATFORM_ARCH" = "i386" ]; then \
        apt-get update && apt-get install -y gcc-i686-linux-gnu g++-i686-linux-gnu && rm -rf /var/lib/apt/lists/* ; \
    elif [ "$PLATFORM_ARCH" = "arm64" ]; then \
        apt-get update && apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu && rm -rf /var/lib/apt/lists/* ; \
    fi

# Prebuilt CMake
RUN curl -sSL -o /tmp/cmake.tar.gz \
    https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz \
    && mkdir -p /opt/cmake \
    && tar --strip-components=1 -xzf /tmp/cmake.tar.gz -C /opt/cmake \
    && rm /tmp/cmake.tar.gz

# Setup workspace
WORKDIR /usr/src
ARG OSSLSIGNCODE_VER=2.9
RUN git clone --depth 1 --branch ${OSSLSIGNCODE_VER} https://github.com/mtrojnar/osslsigncode.git

WORKDIR /usr/src/osslsigncode/build

# Copy cross-compile flags script
COPY ./assets/compiler-flags.sh /tmp/compiler-flags.sh
RUN chmod +x /tmp/compiler-flags.sh

# Configure with CMake
ARG PLATFORM_ARCH
RUN cmake .. -DCMAKE_BUILD_TYPE=Release $(/tmp/compiler-flags.sh "${PLATFORM_ARCH}") \
    && make -j$(nproc)

# Copy patch script and output
WORKDIR /out/linux
COPY ./assets/patch-osslsigncode.sh /tmp/patch.sh
RUN bash /tmp/patch.sh /usr/src/osslsigncode/build/osslsigncode /out/linux/osslsigncode
