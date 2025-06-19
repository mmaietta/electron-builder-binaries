# syntax=docker/dockerfile:1.4

ARG TARGET_ARCH=x86_64
ARG PLATFORM_ARCH=amd64
ARG RUBY_VERSION=3.4.3
ARG DOCKER_IMAGE=buildpack-deps:bookworm-curl

FROM --platform=linux/${PLATFORM_ARCH} ${PLATFORM_ARCH}/${DOCKER_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

# ---- Build stage ----
# Install build dependencies
RUN apt-get update -qq && apt-get install -yq \
    gcc g++ make autoconf bison git \
    libssl-dev libreadline-dev libyaml-dev \
    zlib1g-dev libffi-dev libgdbm-dev \
    file patchelf tar ruby-dev valgrind \
    openssl libz-dev libyaml-dev p7zip-full xz-utils \
    liblzma-dev

WORKDIR /tmp/assets

ARG RUBY_VERSION
ENV RUBY_VERSION=${RUBY_VERSION}

ARG TARGET_ARCH
ENV TARGET_ARCH=${TARGET_ARCH}

COPY ./assets/constants.sh /tmp/assets/constants.sh
COPY ./assets/compile-portable-ruby.sh /tmp/assets/compile-portable-ruby.sh
RUN bash /tmp/assets/compile-portable-ruby.sh

COPY ./assets/patch-portable-ruby.sh /tmp/assets/patch-portable-ruby.sh
RUN bash /tmp/assets/patch-portable-ruby.sh