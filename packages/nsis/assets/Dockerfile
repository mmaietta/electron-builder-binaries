FROM --platform=linux/amd64 debian:buster

# ----------------------
# Fix archived Buster repos + install build tools
# ----------------------
RUN sed -i 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' /etc/apt/sources.list \
    && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl git unzip make gcc g++ mingw-w64 p7zip-full tree \
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
ENV NSIS_BUILD=/opt/nsis-win32
ENV NSIS_BUILD64=/opt/nsis-win64
ENV NSIS_BUILD_LINUX=/opt/nsis-linux
ENV ZLIB_W32=/opt/zlib-win32
# ENV ZLIB_W64=/opt/zlib-win64

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

# # ----------------------
# # Build zlib for Win64
# # ----------------------
# WORKDIR /tmp/zlib-${ZLIB_VERSION}-64
# RUN mkdir -p ${ZLIB_W64} && \
#     make -f win32/Makefile.gcc PREFIX=x86_64-w64-mingw32- SHARED_MODE=1 \
#     BINARY_PATH=${ZLIB_W64}/bin INCLUDE_PATH=${ZLIB_W64}/include LIBRARY_PATH=${ZLIB_W64}/lib install && \
#     cp ${ZLIB_W64}/lib/libz.dll.a ${ZLIB_W64}/lib/zlib1.lib

# ----------------------
# Build NSIS Win32
# ----------------------
# WORKDIR ${NSIS_SRC}
# ENV CC=i686-w64-mingw32-gcc \
#     CXX=i686-w64-mingw32-g++ \
#     CFLAGS="-I${ZLIB_W32}/include" \
#     CXXFLAGS="-I${ZLIB_W32}/include" \
#     LDFLAGS="-L${ZLIB_W32}/lib -lz"
# RUN scons
# RUN mkdir -p ${NSIS_BUILD}/Bin && \
#     cp -r build/urelease/* ${NSIS_BUILD}/ && \
#     cp ${ZLIB_W32}/bin/zlib1.dll ${NSIS_BUILD}/Bin/ && \
#     cp build/urelease/makensis/makensis ${NSIS_BUILD}/Bin/makensis.exe && \
#     # cp build/urelease/Makensisw/makensisw.exe ${NSIS_BUILD}/Bin/makensisw.exe && \
#     find ${NSIS_BUILD} \( -name "*.o" -o -name "*.obj" -o -name "*.map" -o -name "*.ilk" -o -name "*.pdb" -o -name "*.a" \) -delete

# ---------------------------------------------------------
# Build NSIS for Windows (64-bit) with MinGW
# ---------------------------------------------------------

WORKDIR ${NSIS_SRC}

# ENV HOST=mingw \
#     ARCH=x86-64 \
#     CROSS_COMPILE=x86_64-w64-mingw32- \
#     STRIP=x86_64-w64-mingw32-strip \
    # CC=x86_64-w64-mingw32-gcc \
    # CXX=x86_64-w64-mingw32-g++ \
    # CFLAGS="-I${ZLIB_W64}/include" \
    # CXXFLAGS="-I${ZLIB_W64}/include" \
    # LDFLAGS="-L${ZLIB_W64}/lib -lz"

# RUN scons -c
# RUN scons CROSS=mingw ZLIB_W64=$ZLIB_W64 target=makensis-x64


# # Copy only if the output is a Windows PE binary
# RUN mkdir -p ${NSIS_BUILD64}/Bin && \
#     if file build/urelease/makensis/makensis | grep -q 'PE32'; then \
#         cp -r build/urelease/* ${NSIS_BUILD64}/ && \
#         cp ${ZLIB_W64}/bin/zlib1.dll ${NSIS_BUILD64}/Bin/ && \
#         cp build/urelease/makensis/makensis ${NSIS_BUILD64}/Bin/makensis.exe; \
#     else \
#         echo "❌ Build did not produce a Windows binary" && exit 1; \
#     fi

# RUN find ${NSIS_BUILD64} \
#       \( -name '*.o' -o -name '*.obj' -o -name '*.map' -o -name '*.ilk' \
#          -o -name '*.pdb' -o -name '*.a' \) -delete


# ----------------------
# Build NSIS Linux makensis
# ----------------------
WORKDIR ${NSIS_SRC}
# ENV CC=gcc CXX=g++
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
    # cp -r ${NSIS_BUILD}/* nsis-bundle/win32/ && \
    # cp -r ${NSIS_BUILD64}/* nsis-bundle/win64/ && \
    7za a -mx=9 -mfb=64 nsis-bundle-linux-win-${NSIS_VERSION}.7z nsis-bundle

# WORKDIR /out/nsis-bundle
# CMD ["file", "./win64/Bin/makensis.exe"]