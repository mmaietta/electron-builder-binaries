# ----------------------------
# Build osslsigncode for multiple architectures
# ----------------------------
ARG OSSLSIGNCODE_VER=2.9
ARG PLATFORM_ARCH=x86_64

FROM --platform=linux/${PLATFORM_ARCH} buildpack-deps:22.04-curl AS builder

ARG OSSLSIGNCODE_VER
ARG PLATFORM_ARCH

RUN apt-get update && apt-get install -y \
    git cmake build-essential \
    libssl-dev libcurl4-openssl-dev libgsf-1-dev \
    p7zip-full zip \
    qemu-user-static \
    && rm -rf /var/lib/apt/lists/*

# Clone osslsigncode
WORKDIR /usr/src
RUN git clone --depth 1 --branch $OSSLSIGNCODE_VER https://github.com/mtrojnar/osslsigncode.git

# Build
WORKDIR /usr/src/osslsigncode/build

# Use CMake cross-compilation flags for ARM64 if needed
RUN if [ "$PLATFORM_ARCH" = "arm64" ]; then \
        cmake .. -DCMAKE_BUILD_TYPE=Release \
                 -DCMAKE_SYSTEM_NAME=Linux \
                 -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
                 -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
                 -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ ; \
    else \
        cmake .. -DCMAKE_BUILD_TYPE=Release ; \
    fi

RUN make -j$(nproc)

# Output
WORKDIR /out/linux
COPY ./assets/patch-osslsigncode.sh /tmp/assets/patch-osslsigncode.sh

RUN bash /tmp/assets/patch-osslsigncode.sh \
    /usr/src/osslsigncode/build/osslsigncode /out/linux/osslsigncode
