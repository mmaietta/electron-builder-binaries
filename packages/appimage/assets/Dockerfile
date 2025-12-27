# Multi-platform Dockerfile for building AppImage tools
# Build with: docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t appimage-builder .

ARG TARGETPLATFORM=linux/amd64
ARG PLATFORM_PREFIX=

FROM --platform=amd64 buildpack-deps:22.04 AS builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
# RUN sed -i \
#   -e 's|http://archive.ubuntu.com/ubuntu|https://snapshot.ubuntu.com/archive.ubuntu.com/ubuntu/20240101T000000Z|g' \
#   -e 's|http://security.ubuntu.com/ubuntu|https://snapshot.ubuntu.com/archive.ubuntu.com/ubuntu/20240101T000000Z|g' \
#   /etc/apt/sources.list

# Replace sources.list with archive.ubuntu.com
RUN sed -i 's|http://ports.ubuntu.com/ubuntu-ports|http://archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list && \
    apt-get update || true && \
    apt-get install -y --no-install-recommends ubuntu-keyring gnupg ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install build dependencies
RUN rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && apt-get update -yq && apt-get install -y \
    autoconf \
    automake \
    build-essential \
    cmake \
    desktop-file-utils \
    file \
    gettext \
    git \
    libgconf-2-4 \
    libglib2.0-dev \
    liblz4-dev \
    liblzma-dev \
    liblzo2-dev \
    libnotify4 \
    libtool \
    libxss1 \
    libxtst6 \
    libzstd-dev \
    meson \
    ninja-build \
    pkg-config \
    tar \
    tree \
    wget \
    zlib1g-dev \    
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -eux; \
    case "$TARGETPLATFORM" in \
      "linux/386") \
        echo "📥 Downloading libappindicator1 from Ubuntu 18.04 archive (i386)..."; \
        cd /tmp; \
        wget -q http://archive.ubuntu.com/ubuntu/pool/universe/liba/libappindicator/libappindicator1_12.10.1+18.04.20180322.1-0ubuntu1_i386.deb; \
        wget -q http://archive.ubuntu.com/ubuntu/pool/universe/libi/libindicator/libindicator7_16.10.0+18.04.20180321.1-0ubuntu1_i386.deb; \
        mkdir -p /tmp/appind /tmp/ind; \
        dpkg -x libappindicator1_12.10.1+18.04.20180322.1-0ubuntu1_i386.deb /tmp/appind; \
        dpkg -x libindicator7_16.10.0+18.04.20180321.1-0ubuntu1_i386.deb /tmp/ind; \
        echo "   ✅ i386 libappindicator packages extracted"; \
        ;; \
      *) \
        echo "📥 Installing libappindicator3-1 & libindicator3-7..."; \
        apt-get update; \
        apt-get install -y --no-install-recommends \
          libappindicator3-1 \
          libindicator3-7; \
        ;; \
    esac; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*;


ARG SQUASHFS_TOOLS_VERSION_TAG="4.6.1"
COPY ./assets/build-appimage.sh /build/
RUN chmod +x /build/build-appimage.sh && \
    /build/build-appimage.sh

# Final stage - create minimal output image
FROM scratch
ARG TARGETARCH
ARG TARGETVARIANT
COPY --from=builder /appimage-tools-${TARGETARCH}${TARGETVARIANT}.tar.gz /appimage-tools-${TARGETARCH}${TARGETVARIANT}.tar.gz