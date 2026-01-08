FROM ubuntu:22.04 AS builder

ARG NSIS_BRANCH_OR_COMMIT=v311
ARG NSIS_SHA256
ARG ZLIB_VERSION=1.3.1
ARG DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    mingw-w64 \
    scons \
    zlib1g-dev \
    libgdk-pixbuf2.0-dev \
    git \
    curl \
    unzip \
    p7zip-full \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Download and build zlib for Windows
RUN curl -L "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz" -o zlib.tar.gz \
    && tar xzf zlib.tar.gz \
    && cd "zlib-${ZLIB_VERSION}" \
    && CC=i686-w64-mingw32-gcc AR=i686-w64-mingw32-ar RANLIB=i686-w64-mingw32-ranlib ./configure --prefix=/build/zlib-win32 --static \
    && make && make install \
    && cd .. \
    && rm -rf "zlib-${ZLIB_VERSION}" zlib.tar.gz

# Clone NSIS
RUN git clone --branch ${NSIS_BRANCH_OR_COMMIT} --depth=1 https://github.com/kichik/nsis.git nsis

WORKDIR /build/nsis

# Build for Windows (32-bit and 64-bit)
RUN scons \
    SKIPSTUBS=all \
    SKIPPLUGINS=all \
    SKIPUTILS=all \
    SKIPMISC=all \
    NSIS_CONFIG_CONST_DATA_PATH=no \
    PREFIX=/build/install/win32 \
    VERSION=${NSIS_BRANCH_OR_COMMIT} \
    TARGET_ARCH=x86 \
    ZLIB_W32=/build/zlib-win32 \
    install-compiler

# Build for Linux (native)
RUN scons \
    SKIPSTUBS=all \
    SKIPPLUGINS=all \
    SKIPUTILS=all \
    SKIPMISC=all \
    NSIS_CONFIG_CONST_DATA_PATH=no \
    PREFIX=/build/install/linux \
    VERSION=${NSIS_BRANCH_OR_COMMIT} \
    install-compiler

# Download NSIS data files and plugins
RUN git clone --branch ${NSIS_BRANCH_OR_COMMIT} --depth=1 https://github.com/kichik/nsis.git /build/nsis-data

# Download additional plugins
WORKDIR /build/plugins
RUN curl -sL "http://nsis.sourceforge.net/mediawiki/images/1/18/NsProcess.zip" -o nsprocess.zip \
    && curl -sL "http://nsis.sourceforge.net/mediawiki/images/8/8f/UAC.zip" -o uac.zip \
    && curl -sL "http://nsis.sourceforge.net/mediawiki/images/5/54/WinShell.zip" -o winshell.zip \
    && curl -sL "http://nsis.sourceforge.net/mediawiki/images/5/5a/NsJSON.zip" -o nsjson.zip \
    && curl -sL "http://nsis.sourceforge.net/mediawiki/images/4/4c/NsArray.zip" -o nsarray.zip \
    && curl -sL "http://nsis.sourceforge.net/mediawiki/images/c/c9/Inetc.zip" -o inetc.zip

# Extract plugins
RUN for zip in *.zip; do \
        name=$(basename "$zip" .zip); \
        mkdir -p "$name"; \
        7z x "$zip" -o"$name" 2>/dev/null || unzip -q "$zip" -d "$name" || true; \
    done

# Organize bundle structure
WORKDIR /out
RUN mkdir -p nsis-bundle/linux nsis-bundle/win32 nsis-bundle/share/nsis

# Copy binaries
RUN ls -R /build/install && \
    cp /build/install/linux/makensis nsis-bundle/linux/ && \
    cp /build/install/win32/makensis nsis-bundle/win32/ && \
    chmod +x nsis-bundle/linux/makensis

# Copy NSIS data files
RUN ls /build/nsis-data && \
    cp -r /build/nsis-data/Contrib nsis-bundle/share/nsis/ && \
    cp -r /build/nsis-data/Include nsis-bundle/share/nsis/ && \
    cp -r /build/nsis-data/Plugins nsis-bundle/share/nsis/ || true && \
    cp -r /build/nsis-data/Stubs nsis-bundle/share/nsis/ || true

# Install additional plugins
RUN for plugin_dir in /build/plugins/*/; do \
        plugin_name=$(basename "$plugin_dir"); \
        echo "Installing plugin: $plugin_name"; \
        find "$plugin_dir" -name "*.dll" -path "*/x86-ansi/*" -exec cp {} nsis-bundle/share/nsis/Plugins/x86-ansi/ \; 2>/dev/null || true; \
        find "$plugin_dir" -name "*.dll" -path "*/x86-unicode/*" -exec cp {} nsis-bundle/share/nsis/Plugins/x86-unicode/ \; 2>/dev/null || true; \
        find "$plugin_dir" -name "*.dll" -path "*/ansi/*" -exec cp {} nsis-bundle/share/nsis/Plugins/x86-ansi/ \; 2>/dev/null || true; \
        find "$plugin_dir" -name "*.dll" -path "*/unicode/*" -exec cp {} nsis-bundle/share/nsis/Plugins/x86-unicode/ \; 2>/dev/null || true; \
        find "$plugin_dir" -name "*.nsh" -exec cp {} nsis-bundle/share/nsis/Include/ \; 2>/dev/null || true; \
        find "$plugin_dir" -name "*.nsi" -exec cp {} nsis-bundle/share/nsis/Include/ \; 2>/dev/null || true; \
    done

# Clean up docs and examples
RUN rm -rf nsis-bundle/share/nsis/Docs nsis-bundle/share/nsis/Examples

# Create version info
RUN echo "NSIS Version: ${NSIS_BRANCH_OR_COMMIT}" > nsis-bundle/linux/VERSION.txt && \
    echo "zlib Version: ${ZLIB_VERSION}" >> nsis-bundle/linux/VERSION.txt && \
    echo "Build Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> nsis-bundle/linux/VERSION.txt

# Package bundle
RUN cd /out && zip -r9q nsis-bundle-linux-${NSIS_BRANCH_OR_COMMIT}.zip nsis-bundle

# Final stage - just the output
FROM scratch AS output
COPY --from=builder /out/*.zip /
