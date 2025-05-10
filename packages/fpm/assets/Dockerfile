ARG TARGETARCH=x86_64
ARG RUBY_VERSION=3.4.3

# We need to use bookworm instead of 22.04 in order to be able to compile i386
# TARGETARCH correpsonds to multi-arch image. Options can be found here:
# https://hub.docker.com/layers/library/buildpack-deps/bookworm-curl/images/sha256-66af74907dbbf8b0b007f1364cfb5533d82b0914d637c5301d66debd326b5bf0
FROM --platform=linux/${TARGETARCH} buildpack-deps:bookworm-curl AS build

ENV DEBIAN_FRONTEND=noninteractive

# ---- Build stage ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ruby-dev \
    autoconf \
    bison \
    build-essential \
    bzip2 \
    ca-certificates \
    cmake \
    curl \
    desktop-file-utils \
    file \
    g++ \
    gcc \
    git \
    libc-dev \
    libffi-dev \
    libgdbm-dev \
    liblzma-dev \
    liblzo2-dev \
    libreadline-dev \
    libssl-dev \
    libyaml-dev \
    make \
    p7zip-full \
    patchelf \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    rsync \
    rpm \
    tar \
    tree \
    unzip \
    wget \
    zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Enable 32-bit cross compilation if needed
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "386" ]; then \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y gcc-multilib g++-multilib && \
    rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR /tmp/assets
COPY ./assets/ /tmp/assets/

ARG RUBY_VERSION
RUN chmod +x /tmp/assets/compile-portable-ruby.sh && \
    export RUBY_VERSION=${RUBY_VERSION} && \
    export TARGETARCH=${TARGETARCH} && \
    bash /tmp/assets/compile-portable-ruby.sh
