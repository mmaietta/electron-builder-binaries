ARG PLATFORM_ARCH=x86_64
ARG DOCKER_IMAGE_BASE=buildpack-deps:22.04-scm
ARG RUBY_PATH=/usr/local/
ARG RUBY_VERSION=3.4.3

FROM crazymax/7zip:17.05 AS zipper

FROM --platform=linux/$PLATFORM_ARCH $DOCKER_IMAGE_BASE AS base
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # python2 \
    # ruby-full \
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

WORKDIR /tmp/build-dir

# prepare makensis and build
# ARG NSIS_VERSION=3.11
# ARG SCONS_VERSION=4.9.1
# RUN mkdir -p /tmp/scons && curl -L http://prdownloads.sourceforge.net/scons/scons-local-$SCONS_VERSION.tar.gz | tar -xz -C /tmp/scons && \
#     mkdir -p /tmp/nsis && curl -L https://sourceforge.net/projects/nsis/files/NSIS%203/$NSIS_VERSION/nsis-$NSIS_VERSION-src.tar.bz2/download | tar -xj -C /tmp/nsis --strip-components 1 && \
#     cd /tmp/nsis && \
#     python3 /tmp/scons/scons.py STRIP=0 SKIPSTUBS=all SKIPPLUGINS=all SKIPUTILS=all SKIPMISC=all NSIS_CONFIG_CONST_DATA_PATH=no NSIS_CONFIG_LOG=yes NSIS_MAX_STRLEN=8192 makensis
# RUN cp /tmp/nsis/build/urelease/makensis/makensis /usr/local/bin

# zstd and mksquashfs
# ARG ZSTD_VERSION=1.5.0
# ARG SQUASHFS_VERSION=4.5
# RUN git clone --depth 1 --branch v$ZSTD_VERSION https://github.com/facebook/zstd.git && cd zstd && make -j5 install && cd .. && \
#     git clone --depth 1 --branch $SQUASHFS_VERSION https://github.com/plougher/squashfs-tools && cd squashfs-tools/squashfs-tools && \
#     make -j5 XZ_SUPPORT=1 LZO_SUPPORT=1 ZSTD_SUPPORT=1 GZIP_SUPPORT=0 COMP_DEFAULT=zstd install

# osslsigncode
# ARG OSSLSIGNCODE_VERSION=2.9
# RUN curl -L https://github.com/mtrojnar/osslsigncode/archive/refs/tags/$OSSLSIGNCODE_VERSION.zip -o f.zip && \ 
#     unzip f.zip && rm f.zip
# RUN cd osslsigncode-$OSSLSIGNCODE_VERSION && \
#     mkdir build && \
#     cd build && \
#     cmake -S .. && cmake --build .  && \ 
#     cp /tmp/build-dir/osslsigncode-$OSSLSIGNCODE_VERSION/build/osslsigncode /usr/local/bin/osslsigncode

# Add multilib if building i386 on x86_64
# RUN if [ "$PLATFORM_ARCH" = "386" ]; then \
#     dpkg --add-architecture i386 && \
#     apt-get update && \
#     apt-get install -y gcc-multilib g++-multilib; \
#     fi

# Install ruby
# ARG RUBY_VERSION=3_1_4
# WORKDIR /ruby
# RUN git clone --depth 1 --branch v$RUBY_VERSION https://github.com/ruby/ruby.git src
# WORKDIR /ruby/src
# # Configure based on architecture
# RUN autoconf && \
#     cp -v /usr/share/misc/config.* ./ && \
#     ARCH_FLAGS="" && \
#     if [ "$TARGETARCH" = "386" ]; then \
#     ARCH_FLAGS="--host=i386-linux-gnu CFLAGS='-m32' LDFLAGS='-m32'"; \
#     fi && \
#     eval ./configure \
#     --prefix=/ruby/install \
#     --disable-install-doc \
#     --enable-shared \
#     --disable-static \
#     $ARCH_FLAGS && \
#     make -j$(nproc) && \
#     make install

# # Patch rpath
# RUN patchelf --set-rpath '$ORIGIN/../lib' /ruby/install/bin/ruby


# FROM --platform=linux/$PLATFORM_ARCH $DOCKER_IMAGE_BASE AS build
# ARG RUBY_PATH
# ARG RUBY_VERSION
# ENV DEBIAN_FRONTEND=noninteractive
# RUN apt-get update -yqq && \
#     apt-get install -yqq --no-install-recommends \
#     patchelf \
#     rsync \
#     && \
#     rm -rf /var/lib/apt/lists/*

# RUN git clone git://github.com/rbenv/ruby-build.git $RUBY_PATH/plugins/ruby-build \
#     &&  $RUBY_PATH/plugins/ruby-build/install.sh
# RUN ruby-build $RUBY_VERSION $RUBY_PATH

# Set Ruby version
ENV RUBY_VERSION=3.4.0
# ENV RUBY_PREFIX=/opt/ruby

# Build and install Ruby from source
RUN curl -L https://cache.ruby-lang.org/pub/ruby/3.4/ruby-$RUBY_VERSION.tar.gz | tar xz && \
    cd ruby-$RUBY_VERSION && \
    autoconf && \
    # cp -v /usr/share/misc/config.* ./ && \
    # Configure based on architecture
    ARCH_FLAGS="" && \
    if [ "$PLATFORM_ARCH" = "386" ]; then \
        ARCH_FLAGS="--host=i386-linux-gnu CFLAGS='-m32' LDFLAGS='-m32'"; \
    fi && \
    eval ./configure \
    # --prefix=$RUBY_PREFIX \
    --disable-install-doc \
    --enable-shared \
    --disable-static \
    --enable-load-relative \
    $ARCH_FLAGS \
    && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && rm -rf ruby-$RUBY_VERSION
ENV PATH="/opt/ruby/bin:$PATH"

# RUN curl -L https://rubygems.org/rubygems/rubygems-3.5.6.tgz | tar xz && \
#     cd rubygems-3.5.6 && \
#     ruby setup.rb && \
#     gem update --system && \
# cd .. && rm -rf rubygems-3.5.6
# RUN gem install bundler -v 2.6.2 --no-document --quiet
# RUN gem install ostruct logger --no-document --quiet

COPY --from=zipper /usr/local/bin/7z* /tmp/zipper/
ENV PATH="/tmp/zipper:${PATH}"

# node modules needed for docker to access pnpm dependency submodule
COPY ./node_modules /usr/src/app/node_modules
COPY ./scripts/utils.sh /usr/src/app/scripts/utils.sh
COPY ./packages/fpm /usr/src/app/packages/fpm

WORKDIR /usr/src/app
RUN bash ./packages/fpm/build.sh fpm.7z

# FROM --platform=linux/$PLATFORM_ARCH buildpack-deps:bookworm-curl AS runtime
# ENV DEBIAN_FRONTEND=noninteractive
# # Install dependencies
# RUN apt-get update -yqq && \
#     apt-get install file gdb patchelf tree -yqq \
#     && rm -rf /var/lib/apt/lists/*

# COPY --from=zipper /usr/local/bin/7z* /usr/local/bin/
# COPY --from=ruby /usr/src/app/out/fpm.7z /usr/src/app/out/fpm.7z
# COPY --from=ruby /usr/src/app/ruby_user_bundle.tar.gz /usr/src/app/ruby_user_bundle.tar.gz
# COPY --from=ruby /tmp/fpm /tmp/fpm

# # build scripts
# WORKDIR /usr/src/app
# COPY ./docker-scripts /usr/src/app/docker-scripts

# build resources
# COPY ./packages/nsis-lang-fixes /usr/src/app/packages/nsis-lang-fixes

# RUN sh ./docker-scripts/nsis-windows.sh
# RUN sh ./docker-scripts/nsis-plugins.sh
# RUN sh ./docker-scripts/wix-toolset-x64.sh
# RUN sh ./docker-scripts/appimage-openjpeg-x64.sh
# RUN sh ./docker-scripts/squirrel-windows.sh
# RUN sh ./docker-scripts/appImage-packages-x64.sh
# RUN sh ./docker-scripts/appImage-packages-ia32.sh
# RUN sh ./docker-scripts/win-codesign-tools.sh


# COPY ./scripts/utils.sh /usr/src/app/scripts/utils.sh
# # node modules needed for docker to access pnpm dependency submodule
# COPY ./node_modules /usr/src/app/node_modules
# COPY ./packages/fpm /usr/src/app/packages/fpm
# RUN bash ./packages/fpm/build.sh