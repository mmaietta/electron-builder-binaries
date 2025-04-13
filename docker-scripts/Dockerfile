# hardcoding `--platform` with a constant throws a warning during build.
# That's OK as this we override this during build scripts to extract multiple artifacts from each architecture.
FROM --platform=linux/x86_64 buildpack-deps:22.04-curl

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
        wget && \
        liblzo2-dev && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /usr/src/app

RUN apt-get update && \
    apt-get install -y \
        p7zip-full \
        tree \
        bzip2 \
        python2 \
        zlib1g-dev \
        gcc \
        g++ \
        libc-dev
# COPY 7za /usr/local/bin/7za
COPY ./docker-scripts /usr/src/app/docker-scripts
COPY ./nsis-lang-fixes /usr/src/app/nsis-lang-fixes

# # prepare makensis and build
# RUN mkdir -p /tmp/scons && curl -L http://prdownloads.sourceforge.net/scons/scons-local-2.5.1.tar.gz | tar -xz -C /tmp/scons && \
#     mkdir -p /tmp/nsis && curl -L https://sourceforge.net/projects/nsis/files/NSIS%203/3.04/nsis-3.04-src.tar.bz2/download | tar -xj -C /tmp/nsis --strip-components 1 && \
#     cd /tmp/nsis && \
#     python2 /tmp/scons/scons.py STRIP=0 SKIPSTUBS=all SKIPPLUGINS=all SKIPUTILS=all SKIPMISC=all NSIS_CONFIG_CONST_DATA_PATH=no NSIS_CONFIG_LOG=yes NSIS_MAX_STRLEN=8192 makensis && \
#     cp makensis /usr/local/bin
