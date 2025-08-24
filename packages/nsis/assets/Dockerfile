FROM ubuntu:24.04

# Set environment variables for zlib
ENV ZLIB_W32=/opt/zlib-w32
ENV ZLIB_W64=/opt/zlib-w64

# Install build dependencies
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git python3 python3-pip scons mingw-w64 curl unzip make gcc g++ \
    && apt-get clean

# Download and extract zlib 1.3.1
WORKDIR /tmp
RUN curl -sL https://zlib.net/zlib-1.3.1.tar.gz | tar xz

# Build zlib for Win32 (32-bit)
WORKDIR /tmp/zlib-1.3.1
RUN make distclean || true && \
    make -f win32/Makefile.gcc \
        PREFIX=i686-w64-mingw32- \
        SHARED_MODE=1 \
        BINARY_PATH=${ZLIB_W32}/bin \
        INCLUDE_PATH=${ZLIB_W32}/include \
        LIBRARY_PATH=${ZLIB_W32}/lib \
        install && \
    cp ${ZLIB_W32}/lib/libz.dll.a ${ZLIB_W32}/lib/zlib1.lib

# Build zlib for Win64 (64-bit)
RUN make distclean || true && \
    make -f win32/Makefile.gcc \
        PREFIX=x86_64-w64-mingw32- \
        SHARED_MODE=1 \
        BINARY_PATH=${ZLIB_W64}/bin \
        INCLUDE_PATH=${ZLIB_W64}/include \
        LIBRARY_PATH=${ZLIB_W64}/lib \
        install && \
    cp ${ZLIB_W64}/lib/libz.dll.a ${ZLIB_W64}/lib/zlib1.lib

# Clone NSIS
RUN git clone --branch v311 --depth 1 https://github.com/kichik/nsis.git /opt/nsis-src

# Patch NSIS config.h
WORKDIR /opt/nsis-src
RUN sed -i 's/^#define NSIS_MAX_STRLEN.*/#define NSIS_MAX_STRLEN 8192/' Source/exehead/config.h && \
    echo "#define NSIS_CONFIG_LOG" >> Source/exehead/config.h && \
    echo "#define NSIS_SUPPORT_LOG" >> Source/exehead/config.h

# Build NSIS 32-bit
RUN cp -r /opt/nsis-src /opt/nsis-win32
WORKDIR /opt/nsis-win32
RUN export CC=i686-w64-mingw32-gcc && \
    export CXX=i686-w64-mingw32-g++ && \
    export CFLAGS="-I${ZLIB_W32}/include" && \
    export LDFLAGS="-L${ZLIB_W32}/lib -lz" && \
    export ZLIB_W32=${ZLIB_W32} && \
    scons STRIP=0 \
        NSIS_MAX_STRLEN=8192 \
        NSIS_CONFIG_LOG=yes \
        NSIS_CONFIG_CONST_DATA_PATH=no && \
    mkdir -p /opt/nsis-builds/win32 && \
    find build -name makensis.exe -exec cp {} /opt/nsis-builds/win32/ \;

# Build NSIS 64-bit
RUN cp -r /opt/nsis-src /opt/nsis-win64
WORKDIR /opt/nsis-win64
RUN export CC=x86_64-w64-mingw32-gcc && \
    export CXX=x86_64-w64-mingw32-g++ && \
    export CFLAGS="-I${ZLIB_W64}/include" && \
    export LDFLAGS="-L${ZLIB_W64}/lib -lz" && \
    export ZLIB_W32=${ZLIB_W64} && \
    scons STRIP=0 \
        NSIS_MAX_STRLEN=8192 \
        NSIS_CONFIG_LOG=yes \
        NSIS_CONFIG_CONST_DATA_PATH=no && \
    mkdir -p /opt/nsis-builds/win64 && \
    find build -name makensis.exe -exec cp {} /opt/nsis-builds/win64/ \;

# List results
CMD ["ls", "-R", "/opt/nsis-builds"]
