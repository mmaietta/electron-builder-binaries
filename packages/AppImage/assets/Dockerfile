# Multi-platform Dockerfile for building AppImage tools
# Build with: docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t appimage-builder .

FROM --platform=$BUILDPLATFORM ubuntu:22.04 as builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    zlib1g-dev \
    liblzma-dev \
    liblz4-dev \
    libzstd-dev \
    liblzo2-dev \
    libglib2.0-dev \
    desktop-file-utils \
    cmake \
    file \
    && rm -rf /var/lib/apt/lists/*

# Clone squashfs-tools
WORKDIR /build
RUN git clone https://github.com/plougher/squashfs-tools.git && \
    cd squashfs-tools/squashfs-tools && \
    git checkout 4.6.1

# Copy build script and execute
COPY ./assets/appimage-linux.sh /build/
RUN chmod +x /build/appimage-linux.sh && \
    /build/appimage-linux.sh

# Final stage - create minimal output image
FROM scratch
ARG TARGETARCH
ARG TARGETVARIANT
COPY --from=builder /appimage-tools-${TARGETARCH}${TARGETVARIANT}.tar.gz /appimage-tools-${TARGETARCH}${TARGETVARIANT}.tar.gz