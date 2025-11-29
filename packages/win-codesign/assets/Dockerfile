ARG PLATFORM_ARCH=x86_64

FROM --platform=linux/${PLATFORM_ARCH} buildpack-deps:22.04-curl AS builder

# Install cross-compilers (only used if building for arm64)
RUN apt-get update && apt-get install -y \
    git cmake build-essential \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    libssl-dev libcurl4-openssl-dev libgsf-1-dev \
    p7zip-full zip \
    && rm -rf /var/lib/apt/lists/*

# Clone
ARG OSSLSIGNCODE_VER
WORKDIR /usr/src
RUN git clone --depth 1 --branch ${OSSLSIGNCODE_VER} https://github.com/mtrojnar/osslsigncode.git

WORKDIR /usr/src/osslsigncode/build

COPY ./assets/cross-compile-flags.sh /tmp/cross-compile-flags.sh

# Use CMake cross flags
ARG PLATFORM_ARCH
RUN cmake .. -DCMAKE_BUILD_TYPE=Release \
        $(/tmp/cross-compile-flags.sh "${PLATFORM_ARCH}")
RUN make -j$(nproc)

# Output
WORKDIR /out/linux
COPY ./assets/patch-osslsigncode.sh /tmp/assets/patch-osslsigncode.sh

RUN bash /tmp/assets/patch-osslsigncode.sh \
    /usr/src/osslsigncode/build/osslsigncode /out/linux/osslsigncode