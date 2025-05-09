# syntax=docker/dockerfile:1.4

ARG TARGETARCH=x86_64
ARG RUBY_VERSION=3.1.4
FROM --platform=linux/${TARGETARCH} buildpack-deps:22.04-curl AS build

ENV DEBIAN_FRONTEND=noninteractive

# Install required build tools and dependencies
# RUN apt-get update && apt-get install -y \
#   gcc \
#   g++ \
#   autoconf \
#   bison \
#   git \
#   libssl-dev \
#   libreadline-dev \
#   libyaml-dev \
#   zlib1g-dev \
#   libffi-dev \
#   libgdbm-dev \
#   file \
#   patchelf \
#   tar \
#   && rm -rf /var/lib/apt/lists/*
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
WORKDIR /ruby
RUN git clone --depth 1 --branch "v3_1_4" https://github.com/ruby/ruby.git src
# RUN curl -L https://cache.ruby-lang.org/pub/ruby/3.4/ruby-$RUBY_VERSION.tar.gz | tar xz

WORKDIR /ruby/src
RUN autoconf
# && cp -v /usr/share/misc/config.* ./

# Configure and build Ruby with relocatable support
ENV RUBY_PREFIX=/ruby/install
RUN ARCH_FLAGS="" && \
    if [ "$TARGETARCH" = "386" ]; then \
      ARCH_FLAGS="--host=i386-linux-gnu CFLAGS='-m32' LDFLAGS='-m32'"; \
    fi && \
    ./autogen.sh && \
    ./configure \
      --prefix=$RUBY_PREFIX \
      --disable-install-doc \
      --enable-shared \
      --disable-static \
      --enable-load-relative \
      --with-openssl-dir=/usr/include/openssl \
      --with-baseruby=$(which ruby) \
      $ARCH_FLAGS && \
    make -j$(nproc) && \
    make install

# Patch ruby binary to use local lib path
RUN patchelf --set-rpath '$ORIGIN/../lib' $RUBY_PREFIX/bin/ruby
ARG TARGETARCH
# RUN cat << 'EOF' > /ruby/install/run_ruby.sh && \
#     #!/bin/bash
#     DIR="$(cd "$(dirname "$0")"; pwd)" \
#     source "$DIR/ruby.env" \
#     export LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH" \
#     exec "$DIR/bin/ruby" "$@" \
#     EOF
# RUN chmod +x /ruby/install/run_ruby.sh
ENV PATH="$RUBY_PREFIX/bin:$PATH"
RUN gem install --no-document fpm

# Create compressed portable archive
RUN tar -czvf /ruby-${RUBY_VERSION}-${TARGETARCH}.tar.gz -C $RUBY_PREFIX .

# ---- Runtime stage ----
FROM --platform=linux/${TARGETARCH} buildpack-deps:22.04-curl AS runtime
ARG RUBY_VERSION
ARG TARGETARCH
SHELL ["/bin/bash", "-c"]

COPY --from=build /ruby-${RUBY_VERSION}-${TARGETARCH}.tar.gz /
RUN mkdir /ruby && tar -xzf /ruby-${RUBY_VERSION}-${TARGETARCH}.tar.gz -C /ruby

# Get Ruby stdlib path (e.g. /ruby/install/lib/ruby/3.1.0)
# RUN RUBYLIB_PATH="$(/ruby/bin/ruby -e 'puts RbConfig::CONFIG["rubylibdir"]')" && \
#     echo "RUBYLIB=${RUBYLIB_PATH}" > /ruby/ruby.env

ENV PATH="/ruby/bin:$PATH"
# ENV RUBYLIB="/ruby/lib/ruby/3.4.0"
ENV RUBYLIB="/ruby/lib/ruby/${RUBY_VERSION%.*}.0"
ENV LD_LIBRARY_PATH="/ruby/lib"

CMD ["ruby", "-v"]
