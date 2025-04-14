ARG IMAGE_VERSION=x86_64
FROM --platform=linux/$IMAGE_VERSION buildpack-deps:22.04-curl

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        libssl-dev \
        make \
        python3 \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        tar \
        unzip \
        wget \
        desktop-file-utils \
        p7zip-full \
        tree \
        bzip2 \
        python2 \
        zlib1g-dev \
        gcc \
        g++ \
        libc-dev \
        liblzma-dev \
        liblzo2-dev && \
    rm -rf /var/lib/apt/lists/*

COPY ./docker-scripts /usr/src/app/docker-scripts
COPY ./nsis-lang-fixes /usr/src/app/nsis-lang-fixes

# prepare makensis and build
RUN mkdir -p /tmp/scons && curl -L http://prdownloads.sourceforge.net/scons/scons-local-2.5.1.tar.gz | tar -xz -C /tmp/scons && \
    mkdir -p /tmp/nsis && curl -L https://sourceforge.net/projects/nsis/files/NSIS%203/3.04/nsis-3.04-src.tar.bz2/download | tar -xj -C /tmp/nsis --strip-components 1 && \
    cd /tmp/nsis && \
    python2 /tmp/scons/scons.py STRIP=0 SKIPSTUBS=all SKIPPLUGINS=all SKIPUTILS=all SKIPMISC=all NSIS_CONFIG_CONST_DATA_PATH=no NSIS_CONFIG_LOG=yes NSIS_MAX_STRLEN=8192 makensis
# RUN cp /tmp/nsis/makensis /usr/local/bin

RUN git clone --depth 1 --branch v1.5.0 https://github.com/facebook/zstd.git && cd zstd && make -j5 install && cd .. && \
    git clone --depth 1 --branch 4.5 https://github.com/plougher/squashfs-tools && cd squashfs-tools/squashfs-tools && \
    make -j5 XZ_SUPPORT=1 LZO_SUPPORT=1 ZSTD_SUPPORT=1 GZIP_SUPPORT=0 COMP_DEFAULT=zstd install

# Set the working directory
WORKDIR /usr/src/app
