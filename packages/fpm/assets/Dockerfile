ARG TARGETARCH=x86_64
ARG RUBY_VERSION=3.1.4

FROM --platform=linux/${TARGETARCH} buildpack-deps:22.04-curl AS build

ENV DEBIAN_FRONTEND=noninteractive
# SHELL ["/bin/bash", "-c"]

# ---- Build stage ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # python2 \
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

# Clone Ruby source
ARG RUBY_VERSION

COPY ./build-mac.sh /build-mac.sh
RUN chmod +x /build-mac.sh && \
    RUBY_VERSION=${RUBY_VERSION} bash /build-mac.sh

# # ---- Runtime stage ----
# FROM --platform=linux/${TARGETARCH} buildpack-deps:22.04-curl AS runtime
# ARG RUBY_VERSION
# ARG TARGETARCH
# SHELL ["/bin/bash", "-c"]

# COPY --from=build /ruby-${RUBY_VERSION}-${TARGETARCH}.tar.gz /
# RUN mkdir /ruby && tar -xzf /ruby-${RUBY_VERSION}-${TARGETARCH}.tar.gz -C /ruby

# ENV PATH="/ruby/bin:$PATH"
# ENV RUBYLIB="/ruby/lib/ruby/${RUBY_VERSION%.*}.0"
# ENV LD_LIBRARY_PATH="/ruby/lib"

# RUN FPM_VERSION=$(fpm --version | cut -d' ' -f2)
# RUN mv /ruby-${RUBY_VERSION}-${TARGETARCH}.tar.gz /fpm-${FPM_VERSION}-ruby-${RUBY_VERSION}-${TARGETARCH}.tar.gz

CMD ["echo 'FPM version: \$(fpm --version)' && echo 'Ruby version: \$(ruby -v)'"]
