ARG PLATFORM_ARCH=x86_64

FROM --platform=linux/${PLATFORM_ARCH} debian:buster AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

RUN sed -i 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' /etc/apt/sources.list \
    && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until \
    && apt-get update && apt-get install -y \
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

# Clone
ARG OSSLSIGNCODE_VER
WORKDIR /usr/src
RUN git clone --depth 1 --branch ${OSSLSIGNCODE_VER} https://github.com/mtrojnar/osslsigncode.git

WORKDIR /usr/src/osslsigncode/build

COPY ./assets/cross-compile-flags.sh /tmp/cross-compile-flags.sh

# CMake configure
ARG PLATFORM_ARCH
RUN cmake .. -DCMAKE_BUILD_TYPE=Release \
        $(/tmp/cross-compile-flags.sh "${PLATFORM_ARCH}")

RUN make -j$(nproc)

# Patch / output
WORKDIR /out/linux
COPY ./assets/patch-osslsigncode.sh /tmp/patch.sh

RUN bash /tmp/patch.sh \
    /usr/src/osslsigncode/build/osslsigncode \
    /out/linux/osslsigncode
