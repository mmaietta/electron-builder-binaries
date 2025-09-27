FROM --platform=linux/amd64 debian:buster

# ----------------------
# Fix archived Buster repos + install build tools
# ----------------------
RUN sed -i 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' /etc/apt/sources.list \
    && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl git unzip make gcc g++ mingw-w64 p7zip-full zip tree \
        ca-certificates lsb-release \
        libssl-dev libffi-dev libbz2-dev libreadline-dev zlib1g-dev xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ----------------------
# Build Python 3.11 from source
# ----------------------
ARG PYTHON_VERSION=3.11.9
ARG PYTHON_SHA256=9b1e896523fc510691126c864406d9360a3d1e986acbda59cda57b5abda45b87
WORKDIR /tmp
RUN curl -O https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz \
    && echo "${PYTHON_SHA256}  Python-${PYTHON_VERSION}.tar.xz" | sha256sum -c - \
    && tar xf Python-${PYTHON_VERSION}.tar.xz \
    && cd Python-${PYTHON_VERSION} \
    && ./configure --enable-optimizations --prefix=/usr/local \
    && make -j$(nproc) \
    && make altinstall \
    && python3.11 --version \
    && python3.11 -m pip install --upgrade pip scons

# ----------------------
# Environment
# ----------------------
ENV NSIS_SRC=/opt/nsis-src
ENV NSIS_BUILD_LINUX=/opt/nsis-linux
ENV ZLIB_W32=/opt/zlib-win32

ENV NSIS_MAX_STRLEN=8192
ENV NSIS_CONFIG_LOG=yes
ENV NSIS_CONFIG_CONST_DATA_PATH=no
ENV NSIS_CONFIG_USE_ELEVATE=yes
ENV NSIS_CONSOLE=yes

# ----------------------
# Download & verify NSIS from SourceForge
# ----------------------
ARG NSIS_VERSION=3.11
ARG NSIS_SHA256=19e72062676ebdc67c11dc032ba80b979cdbffd3886c60b04bb442cdd401ff4b
WORKDIR /opt
RUN curl -sL -o nsis-${NSIS_VERSION}-src.tar.bz2 \
      https://downloads.sourceforge.net/project/nsis/NSIS%203/${NSIS_VERSION}/nsis-${NSIS_VERSION}-src.tar.bz2 && \
    echo "${NSIS_SHA256}  nsis-${NSIS_VERSION}-src.tar.bz2" | sha256sum -c - && \
    mkdir ${NSIS_SRC} && \
    tar xjf nsis-${NSIS_VERSION}-src.tar.bz2 -C ${NSIS_SRC} --strip-components=1

# ----------------------
# Download & verify zlib
# ----------------------
ARG ZLIB_VERSION=1.3.1
ARG ZLIB_SHA256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
WORKDIR /tmp
RUN curl -sL -o zlib-${ZLIB_VERSION}.tar.gz \
      https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz && \
    echo "${ZLIB_SHA256}  zlib-${ZLIB_VERSION}.tar.gz" | sha256sum -c - && \
    tar xf zlib-${ZLIB_VERSION}.tar.gz && \
    cp -r zlib-${ZLIB_VERSION} zlib-${ZLIB_VERSION}-32 && \
    cp -r zlib-${ZLIB_VERSION} zlib-${ZLIB_VERSION}-64


# ----------------------
# Build zlib for Win32
# ----------------------
WORKDIR /tmp/zlib-${ZLIB_VERSION}-32
RUN mkdir -p ${ZLIB_W32} && \
    make -f win32/Makefile.gcc PREFIX=i686-w64-mingw32- SHARED_MODE=1 \
    BINARY_PATH=${ZLIB_W32}/bin INCLUDE_PATH=${ZLIB_W32}/include LIBRARY_PATH=${ZLIB_W32}/lib install && \
    cp ${ZLIB_W32}/lib/libz.dll.a ${ZLIB_W32}/lib/zlib1.lib

# ----------------------
# Build NSIS Linux makensis
# ----------------------
WORKDIR ${NSIS_SRC}
RUN scons -c
RUN scons SKIPSTUBS=all SKIPPLUGINS=all MAKENSIS_ONLY=1 SKIPUTILS=all && \
    mkdir -p ${NSIS_BUILD_LINUX}/Bin && \
    cp build/urelease/makensis/makensis ${NSIS_BUILD_LINUX}/Bin/makensis && \
    chmod +x ${NSIS_BUILD_LINUX}/Bin/makensis

# ----------------------
# Bundle all NSIS artifacts
# ----------------------
WORKDIR /out
RUN mkdir -p nsis-bundle/linux && \
    cp ${NSIS_BUILD_LINUX}/Bin/makensis nsis-bundle/linux/makensis && \
    (cd nsis-bundle && zip -r -9 "../nsis-bundle-linux-${NSIS_VERSION}.zip" .)
