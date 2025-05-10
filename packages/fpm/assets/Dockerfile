ARG TARGETARCH=x86_64
ARG RUBY_VERSION=3.4.3

FROM --platform=linux/${TARGETARCH} buildpack-deps:22.04-curl AS build

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
RUN if [ "$TARGETARCH" = "386" ]; then \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y gcc-multilib g++-multilib; \
    fi

ARG RUBY_VERSION
COPY ./assets/compile-portable-ruby.sh /tmp/assets/compile-portable-ruby.sh

WORKDIR /tmp/assets
RUN chmod +x /tmp/assets/compile-portable-ruby.sh && \
    export RUBY_VERSION=${RUBY_VERSION} && \
    bash /tmp/assets/compile-portable-ruby.sh

CMD ["echo 'FPM version: \$(fpm --version)' && echo 'Ruby version: \$(ruby -v)'"]
