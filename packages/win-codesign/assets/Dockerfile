ARG PLATFORM_ARCH=amd64
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ----------------------------
# Install build dependencies
# ----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git pkg-config curl ca-certificates \
    libssl-dev libcurl4-openssl-dev libgsf-1-dev \
    p7zip-full zip \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Cross-compilers per arch
# ----------------------------
RUN if [ "$PLATFORM_ARCH" = "amd64" ]; then \
        apt-get update && apt-get install -y gcc-multilib g++-multilib; \
    elif [ "$PLATFORM_ARCH" = "i386" ]; then \
        dpkg --add-architecture i386 && \
        apt-get update && apt-get install -y gcc-multilib g++-multilib libc6-dev-i386; \
    elif [ "$PLATFORM_ARCH" = "arm64" ]; then \
        apt-get update && apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu; \
    fi && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Prepare workdir
# ----------------------------
WORKDIR /usr/src

# Clone OSSLSIGNCODE
ARG OSSLSIGNCODE_VER=2.9
RUN git clone --depth 1 --branch ${OSSLSIGNCODE_VER} https://github.com/mtrojnar/osslsigncode.git

WORKDIR /usr/src/osslsigncode/build

# Copy cross-compile flags script
COPY ./assets/compiler-flags.sh /tmp/compiler-flags.sh
RUN chmod +x /tmp/compiler-flags.sh

# ----------------------------
# Build
# ----------------------------
ARG PLATFORM_ARCH
RUN cmake .. -DCMAKE_BUILD_TYPE=Release $(/tmp/compiler-flags.sh "$PLATFORM_ARCH") \
    && make -j$(nproc)

# ----------------------------
# Output
# ----------------------------
WORKDIR /out/linux
COPY ./assets/patch-osslsigncode.sh /tmp/patch.sh
RUN bash /tmp/patch.sh /usr/src/osslsigncode/build/osslsigncode /out/linux/osslsigncode
