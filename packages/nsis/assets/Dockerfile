FROM ubuntu:24.04

# ----------------------
# Install build tools
# ----------------------
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git python3 python3-pip scons mingw-w64 curl unzip make gcc g++ tree p7zip-full \
    && apt-get clean

# ----------------------
# Versions (passed as build args)
# ----------------------
ARG ZLIB_VERSION=1.3.1
ARG NSIS_BRANCH=v311

# ----------------------
# Environment
# ----------------------
ENV NSIS_SRC=/opt/nsis-src
ENV NSIS_BUILD=/opt/nsis-win32
ENV NSIS_BUILD64=/opt/nsis-win64
ENV NSIS_BUILD_LINUX=/opt/nsis-linux
ENV ZLIB_W32=/opt/zlib-win32
ENV ZLIB_W64=/opt/zlib-win64

ENV NSIS_MAX_STRLEN=8192
ENV NSIS_CONFIG_LOG=yes
ENV NSIS_CONFIG_CONST_DATA_PATH=no
ENV NSIS_CONFIG_USE_ELEVATE=yes
ENV NSIS_CONSOLE=yes

# ----------------------
# Clone NSIS
# ----------------------
WORKDIR /opt
RUN git clone --branch ${NSIS_BRANCH} https://github.com/kichik/nsis.git ${NSIS_SRC}

# ----------------------
# Download & extract zlib
# ----------------------
WORKDIR /tmp
RUN curl -LO https://zlib.net/zlib-${ZLIB_VERSION}.tar.gz && \
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
# Build zlib for Win64
# ----------------------
WORKDIR /tmp/zlib-${ZLIB_VERSION}-64
RUN mkdir -p ${ZLIB_W64} && \
    make -f win32/Makefile.gcc PREFIX=x86_64-w64-mingw32- SHARED_MODE=1 \
    BINARY_PATH=${ZLIB_W64}/bin INCLUDE_PATH=${ZLIB_W64}/include LIBRARY_PATH=${ZLIB_W64}/lib install && \
    cp ${ZLIB_W64}/lib/libz.dll.a ${ZLIB_W64}/lib/zlib1.lib

# ----------------------
# Build NSIS Win32
# ----------------------
WORKDIR ${NSIS_SRC}
ENV CC=i686-w64-mingw32-gcc \
    CXX=i686-w64-mingw32-g++ \
    CFLAGS="-I${ZLIB_W32}/include" \
    CXXFLAGS="-I${ZLIB_W32}/include" \
    LDFLAGS="-L${ZLIB_W32}/lib -lz"
RUN scons
RUN mkdir -p ${NSIS_BUILD}/Bin && \
    cp -r build/urelease/* ${NSIS_BUILD}/ && \
    cp ${ZLIB_W32}/bin/zlib1.dll ${NSIS_BUILD}/Bin/ && \
    cp build/urelease/makensis/makensis ${NSIS_BUILD}/Bin/makensis.exe && \
    cp build/urelease/Makensisw/makensisw.exe ${NSIS_BUILD}/Bin/makensisw.exe && \
    find ${NSIS_BUILD} \( -name "*.o" -o -name "*.obj" -o -name "*.map" -o -name "*.ilk" -o -name "*.pdb" -o -name "*.a" \) -delete

# ----------------------
# Build NSIS Win64
# ----------------------
WORKDIR ${NSIS_SRC}
ENV CC=x86_64-w64-mingw32-gcc \
    CXX=x86_64-w64-mingw32-g++ \
    CFLAGS="-I${ZLIB_W64}/include" \
    CXXFLAGS="-I${ZLIB_W64}/include" \
    LDFLAGS="-L${ZLIB_W64}/lib -lz"
RUN scons
RUN mkdir -p ${NSIS_BUILD64}/Bin && \
    cp -r build/urelease/* ${NSIS_BUILD64}/ && \
    cp ${ZLIB_W64}/bin/zlib1.dll ${NSIS_BUILD64}/Bin/ && \
    cp build/urelease/makensis/makensis ${NSIS_BUILD64}/Bin/makensis.exe && \
    cp build/urelease/Makensisw/makensisw.exe ${NSIS_BUILD64}/Bin/makensisw.exe && \
    find ${NSIS_BUILD64} \( -name "*.o" -o -name "*.obj" -o -name "*.map" -o -name "*.ilk" -o -name "*.pdb" -o -name "*.a" \) -delete

# ----------------------
# Build NSIS Linux makensis
# ----------------------
WORKDIR ${NSIS_SRC}
ENV CC=gcc CXX=g++
RUN scons SKIPSTUBS=all SKIPPLUGINS=all MAKENSIS_ONLY=1 SKIPUTILS=all && \
    mkdir -p ${NSIS_BUILD_LINUX}/Bin && \
    cp build/urelease/makensis/makensis ${NSIS_BUILD_LINUX}/Bin/makensis && \
    chmod +x ${NSIS_BUILD_LINUX}/Bin/makensis

# ----------------------
# Normalize Stubs to Homebrew-style nested layout
# ----------------------
RUN for DIR in /opt/nsis-win32/Stubs /opt/nsis-win64/Stubs; do \
      if [ -d "$DIR" ]; then \
        mkdir -p $DIR/zlib $DIR/bzip2 $DIR/lzma; \
        [ -f $DIR/zlib-x86-unicode ] && mv $DIR/zlib-x86-unicode $DIR/zlib/x86-unicode || true; \
        [ -f $DIR/bzip2-x86-unicode ] && mv $DIR/bzip2-x86-unicode $DIR/bzip2/x86-unicode || true; \
        [ -f $DIR/lzma-x86-unicode ] && mv $DIR/lzma-x86-unicode $DIR/lzma/x86-unicode || true; \
      fi; \
    done

# ----------------------
# Bundle all NSIS artifacts
# ----------------------
WORKDIR /out
RUN mkdir -p nsis-bundle/linux nsis-bundle/win32 nsis-bundle/win64 && \
    cp ${NSIS_BUILD_LINUX}/Bin/makensis nsis-bundle/linux/makensis && \
    cp -r ${NSIS_BUILD}/* nsis-bundle/win32/ && \
    cp -r ${NSIS_BUILD64}/* nsis-bundle/win64/ && \
    7za a -mx=9 -mfb=64 nsis-bundle-linux-win-${NSIS_BRANCH}.7z nsis-bundle

WORKDIR /out/nsis-bundle
CMD ["tree", "-L", "5"]
