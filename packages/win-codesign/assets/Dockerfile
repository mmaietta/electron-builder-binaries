ARG PLATFORM_ARCH=x86_64

FROM --platform=linux/${PLATFORM_ARCH} debian:bullseye AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    pkg-config \
    curl \
    ca-certificates \
    libssl-dev \
    libcurl4-openssl-dev \
    libgsf-1-dev \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    gcc-i686-linux-gnu \
    g++-i686-linux-gnu \
    p7zip-full \
    zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# Install modern CMake
ARG CMAKE_VERSION=3.27.9
RUN curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-Linux-x86_64.sh \
 && chmod +x cmake-${CMAKE_VERSION}-Linux-x86_64.sh \
 && ./cmake-${CMAKE_VERSION}-Linux-x86_64.sh --skip-license --prefix=/usr/local \
 && rm cmake-${CMAKE_VERSION}-Linux-x86_64.sh

# Clone source
ARG OSSLSIGNCODE_VER
RUN git clone --depth 1 --branch ${OSSLSIGNCODE_VER} https://github.com/mtrojnar/osslsigncode.git

WORKDIR /usr/src/osslsigncode/build
COPY ./assets/cross-compile-flags.sh /tmp/compiler-flags.sh

ARG PLATFORM_ARCH
RUN cmake .. -DCMAKE_BUILD_TYPE=Release \
      $(/tmp/compiler-flags.sh "${PLATFORM_ARCH}")
RUN make -j$(nproc)

# Patch / output
WORKDIR /out/linux
COPY ./assets/patch-osslsigncode.sh /tmp/patch.sh

RUN bash /tmp/patch.sh \
    /usr/src/osslsigncode/build/osslsigncode \
    /out/linux/osslsigncode
