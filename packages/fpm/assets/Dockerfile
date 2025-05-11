# syntax=docker/dockerfile:1.4

ARG TARGETARCH=amd64
ARG RUBY_VERSION=3.4.3
# ARG DOCKER_IMAGE=buildpack-deps:bookworm-curl
ARG DOCKER_IMAGE=buildpack-deps:22.04-curl

FROM --platform=linux/x86_64 ${DOCKER_IMAGE} AS build

ENV DEBIAN_FRONTEND=noninteractive

# ---- Build stage ----
# Install build dependencies
RUN apt-get update -qq && apt-get install -yq \
    gcc g++ make autoconf bison git \
    libssl-dev libreadline-dev libyaml-dev \
    zlib1g-dev libffi-dev libgdbm-dev \
    file patchelf tar ruby-dev valgrind \
    openssl libz-dev libyaml-dev

# Enable 386 multilib toolchain if needed
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "386" ]; then \
    dpkg --add-architecture i386 && \
    apt-get update -qq && \
    apt-get install -yq \
    gcc-multilib g++-multilib valgrind:i386 libssl-dev:i386 \
    libc6-dev:i386 libgcc-11-dev:i386 libstdc++-11-dev:i386 \
    libz-dev:i386 libyaml-dev:i386; \
    fi

WORKDIR /tmp/assets
COPY ./assets/ /tmp/assets/

ARG RUBY_VERSION
RUN chmod +x /tmp/assets/compile-portable-ruby.sh && \
    export RUBY_VERSION=${RUBY_VERSION} && \
    export TARGETARCH=${TARGETARCH} && \
    bash /tmp/assets/compile-portable-ruby.sh