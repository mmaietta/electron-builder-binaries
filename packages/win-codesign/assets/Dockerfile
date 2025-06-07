ARG OSSLSIGNCODE_VER=2.9
# ----------------------------
# Stage 1: Build osslsigncode
# Force platform to x86_64 to ensure consistency across build systems/nodes
# ----------------------------
FROM --platform=linux/x86_64 buildpack-deps:22.04-curl AS builder

ARG OSSLSIGNCODE_VER

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    libssl-dev \
    libcurl4-openssl-dev \
    libgsf-1-dev \
    p7zip-full \
    && rm -rf /var/lib/apt/lists/*

# Clone and checkout osslsigncode
WORKDIR /usr/src
RUN git clone --depth 1 --branch $OSSLSIGNCODE_VER  https://github.com/mtrojnar/osslsigncode.git

# Build using CMake
WORKDIR /usr/src/osslsigncode/build
RUN cmake .. -DCMAKE_BUILD_TYPE=Release \
    && make -j$(nproc)

# Prepare output directory
RUN mkdir -p /out/linux && \
    cp /usr/src/osslsigncode/build/osslsigncode /out/linux/ \
    && /out/linux/osslsigncode --version > /out/linux/VERSION

# ----------------------------
# Package as .7z
# ----------------------------
WORKDIR /out
RUN 7z a /osslsigncode-${OSSLSIGNCODE_VER}-linux-static.7z linux/

# ----------------------------
# Final stage: deliver artifact
# ----------------------------
# FROM scratch
# ARG OSSLSIGNCODE_VER
# COPY --from=builder /osslsigncode-${OSSLSIGNCODE_VER}-linux-static.7z /
