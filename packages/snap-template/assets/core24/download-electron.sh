#!/bin/bash
set -euo pipefail

ELECTRON_VERSION="${1:?Electron version required}"
BUILD_DIR="${2:-$(cd "$(dirname "$0")/../.." && pwd)}"

# Architectures to build for
ARCHITECTURES="x64 arm64 armv7l"

echo "=== Building Electron Templates for Multiple Architectures ==="
echo "Electron Version: $ELECTRON_VERSION"
echo "Architectures: $ARCHITECTURES"
echo ""

# Create output directory
TEMPLATES_DIR="$BUILD_DIR/electron-templates/v$ELECTRON_VERSION"
mkdir -p "$TEMPLATES_DIR"

# Map Electron arch to Docker platform
get_docker_platform() {
    case "$1" in
        x64) echo "linux/amd64" ;;
        arm64) echo "linux/arm64" ;;
        armv7l) echo "linux/arm/v7" ;;
        *) echo "unknown" ;;
    esac
}

# Create buildx builder
if ! docker buildx inspect multiarch >/dev/null 2>&1; then
    echo "Creating Docker buildx builder 'multiarch'..."
    docker buildx create --name multiarch --use
fi

# Build for each architecture
for ARCH in $ARCHITECTURES; do
    PLATFORM=$(get_docker_platform "$ARCH")
    OUT_DIR="$TEMPLATES_DIR/$ARCH"
    mkdir -p "$OUT_DIR"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Building for: $ARCH ($PLATFORM)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Create Dockerfile for this architecture
    cat > "$OUT_DIR/Dockerfile" <<DOCKERFILE_END
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    wget \
    unzip \
    file \
    binutils \
    dpkg-dev \
    apt-file \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Download and extract Electron 
RUN echo "Downloading: https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-${ARCH}.zip" && \
    wget -q "https://github.com/electron/electron/releases/download/v${ELECTRON_VERSION}/electron-v${ELECTRON_VERSION}-linux-${ARCH}.zip" -O electron.zip && \
    unzip -q electron.zip -d electron-bin && \
    rm electron.zip

# Analyze with readelf (works cross-arch)
RUN echo "=== Architecture Info ===" && \
    file electron-bin/electron && \
    echo "" && \
    echo "=== Required Shared Libraries (readelf) ===" && \
    readelf -d electron-bin/electron | grep NEEDED | awk '{print \$5}' | tr -d '[]' > libs-needed.txt && \
    cat libs-needed.txt && \
    echo ""

# Try ldd if same arch
RUN echo "=== Attempting ldd ===" && \
    (ldd electron-bin/electron > ldd-output.txt 2>&1 && echo "ldd succeeded" || echo "ldd failed (expected for cross-arch)") && \
    cat ldd-output.txt || true

# Map library names to packages using apt-file
RUN apt-file update && \
    echo "=== Mapping Libraries to Packages ===" > library-mapping.txt && \
    while IFS= read -r lib; do \
        echo "Searching for: \$lib" >> library-mapping.txt; \
        apt-file search "/\$lib" 2>/dev/null | grep "usr/lib" | head -5 >> library-mapping.txt || echo "  Not found" >> library-mapping.txt; \
        echo "" >> library-mapping.txt; \
    done < libs-needed.txt && \
    cat library-mapping.txt && \
    rm -rf /var/lib/apt/lists/*

# Create final package list
RUN apt-file update && \
    while IFS= read -r lib; do \
        apt-file search "/\$lib" 2>/dev/null | grep -E "usr/lib.*\$lib" | cut -d: -f1 | head -1; \
    done < libs-needed.txt | sort -u | grep -v '^$' > final-packages.txt && \
    echo "=== Final Package List ===" && \
    cat final-packages.txt && \
    rm -rf /var/lib/apt/lists/*

# Download packages
RUN apt-file update && \
    mkdir -p /build/packages && \
    cd /build/packages && \
    while IFS= read -r pkg; do \
        if [ -n "\$pkg" ]; then \
            echo "Downloading: \$pkg"; \
            apt-get download "\$pkg" 2>/dev/null || echo "Failed to download: \$pkg"; \
        fi \
    done < /build/final-packages.txt && \
    rm -rf /var/lib/apt/lists/*

# Extract packages into template structure
RUN mkdir -p /build/template/usr/lib && \
    cd /build/packages && \
    for deb in *.deb; do \
        if [ -f "\$deb" ]; then \
            echo "Extracting: \$deb"; \
            dpkg-deb -x "\$deb" /build/template/; \
        fi \
    done

# Clean up template - keep only .so files
RUN echo "=== Cleaning Template ===" && \
    cd /build/template && \
    find . -type f ! -name "*.so*" -delete && \
    find . -type d -empty -delete && \
    echo "=== Template Structure ===" && \
    find . -name "*.so*" -type f | head -30

# Create tarball
RUN cd /build/template && \
    tar czf /build/electron-core24-template-${ARCH}.tar.gz . && \
    cd /build && \
    echo "=== Template Size ===" && \
    du -sh electron-core24-template-${ARCH}.tar.gz

# Verify key libraries
RUN echo "=== Verifying Key Libraries ===" && \
    cd /build/template && \
    for lib in libnss3.so libnspr4.so libXss.so libgtk-3.so; do \
        if find . -name "\$lib*" | grep -q .; then \
            echo "✓ Found: \$lib"; \
        else \
            echo "✗ Missing: \$lib"; \
        fi \
    done

CMD tar -czf - -C /build \
    electron-core24-template-${ARCH}.tar.gz && \
    cat /build/final-packages.txt && \
    cat /build/libs-needed.txt && \
    cat /build/ldd-output.txt && \
    cat /build/library-mapping.txt
DOCKERFILE_END

    # Build for specific platform
    echo "Building Docker image for $PLATFORM..."
    docker buildx build \
        --platform "$PLATFORM" \
        --load \
        -t "electron-analyzer-${ARCH}:${ELECTRON_VERSION}" \
        "$OUT_DIR"
    
    if [ $? -ne 0 ]; then
        echo "✗ Failed to build for $ARCH"
        continue
    fi
    
    # Extract results
    echo "Extracting analysis results..."
    CONTAINER_ID=$(docker create "electron-analyzer-${ARCH}:${ELECTRON_VERSION}")
    
    if [ -n "$CONTAINER_ID" ]; then
        mkdir -p "$OUT_DIR/results"
        docker cp "$CONTAINER_ID:/build/electron-core24-template-${ARCH}.tar.gz" "$OUT_DIR/results/" 2>/dev/null || true
        docker cp "$CONTAINER_ID:/build/final-packages.txt" "$OUT_DIR/results/" 2>/dev/null || true
        docker cp "$CONTAINER_ID:/build/libs-needed.txt" "$OUT_DIR/results/" 2>/dev/null || true
        docker cp "$CONTAINER_ID:/build/ldd-output.txt" "$OUT_DIR/results/" 2>/dev/null || true
        docker cp "$CONTAINER_ID:/build/library-mapping.txt" "$OUT_DIR/results/" 2>/dev/null || true
        
        docker rm "$CONTAINER_ID" > /dev/null 2>&1 || true
    fi
    
    # Show results
    echo ""
    echo "✓ Results for $ARCH:"
    if [ -f "$OUT_DIR/results/electron-core24-template-${ARCH}.tar.gz" ]; then
        TEMPLATE_SIZE=$(du -sh "$OUT_DIR/results/electron-core24-template-${ARCH}.tar.gz" | cut -f1)
        echo "  Template: $TEMPLATE_SIZE"
    fi
    if [ -f "$OUT_DIR/results/final-packages.txt" ]; then
        PACKAGE_COUNT=$(wc -l < "$OUT_DIR/results/final-packages.txt" | tr -d ' ')
        echo "  Packages: $PACKAGE_COUNT packages"
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ All architectures complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Results in: $TEMPLATES_DIR"
echo ""

# Create summary
SUMMARY="$TEMPLATES_DIR/SUMMARY.md"
cat > "$SUMMARY" <<SUMMARY_END
# Electron $ELECTRON_VERSION - Library Templates

Generated: $(date)

## Architectures

SUMMARY_END

for ARCH in $ARCHITECTURES; do
    OUT_DIR="$TEMPLATES_DIR/$ARCH"
    if [ -f "$OUT_DIR/results/final-packages.txt" ]; then
        cat >> "$SUMMARY" <<ARCH_SUMMARY_END

### $ARCH

**Required Libraries:**
\`\`\`
$(cat "$OUT_DIR/results/libs-needed.txt" 2>/dev/null || echo "N/A")
\`\`\`

**Required Packages:**
\`\`\`
$(cat "$OUT_DIR/results/final-packages.txt" 2>/dev/null || echo "N/A")
\`\`\`

**Template Size:** $(du -sh "$OUT_DIR/results/electron-core24-template-${ARCH}.tar.gz" 2>/dev/null | cut -f1 || echo "N/A")

ARCH_SUMMARY_END
    fi
done

echo "Summary written to: $SUMMARY"
cat "$SUMMARY"