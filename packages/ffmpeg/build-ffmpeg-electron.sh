#!/bin/bash
set -e

# FFmpeg Cross-Compilation Script for Electron
# Builds FFmpeg binaries compatible with Electron for multiple platforms
# Uses native macOS builds when running on macOS, Docker Buildx for other platforms

FFMPEG_VERSION="8.0.1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${ROOT}/build"
OUTPUT_DIR="${SCRIPT_DIR}/ffmpeg"
DIST_DIR="${ROOT}/out/ffmpeg"

# Emoji output
log_info() { echo "ℹ️  $1"; }
log_warn() { echo "⚠️  $1"; }
log_error() { echo "❌ $1"; }
log_success() { echo "✅ $1"; }

# Detect host platform
detect_host_platform() {
    case "$(uname -s)" in
        Darwin)
            HOST_OS="darwin"
            HOST_ARCH="$(uname -m)"
            ;;
        Linux)
            HOST_OS="linux"
            HOST_ARCH="$(uname -m)"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            HOST_OS="windows"
            HOST_ARCH="$(uname -m)"
            ;;
        *)
            HOST_OS="unknown"
            HOST_ARCH="$(uname -m)"
            ;;
    esac
    
    log_info "🖥️  Host platform: ${HOST_OS}/${HOST_ARCH}"
}

# Create unified multi-platform Dockerfile for Linux
create_dockerfile_linux() {
    local dockerfile_path="${SCRIPT_DIR}/Dockerfile.linux"
    
    log_info "Creating Linux Dockerfile..."
    
    cat > "$dockerfile_path" <<'EOF'
FROM ubuntu:22.04 AS builder

ARG TARGETARCH
ARG TARGETOS=linux

ENV DEBIAN_FRONTEND=noninteractive
ENV TARGETOS=${TARGETOS}
ENV TARGETARCH=${TARGETARCH}

# Install base dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    yasm \
    nasm \
    git \
    wget \
    pkg-config \
    autoconf \
    automake \
    libtool \
    cmake \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY build-ffmpeg-docker.sh /build/build-ffmpeg.sh
RUN chmod +x /build/build-ffmpeg.sh

ARG FFMPEG_VERSION
ENV FFMPEG_VERSION=${FFMPEG_VERSION}
# Run the build script during image build
RUN /build/build-ffmpeg.sh

# Export stage - only contains output files
FROM scratch AS export
COPY --from=builder /build/output /
EOF
}

# Create Dockerfile for Windows cross-compilation
create_dockerfile_windows() {
    local dockerfile_path="${SCRIPT_DIR}/Dockerfile.windows"
    
    log_info "Creating Windows cross-compilation Dockerfile..."
    
    cat > "$dockerfile_path" <<'EOF'
FROM ubuntu:22.04 AS builder

ARG TARGETOS=windows
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV TARGETOS=${TARGETOS}
ENV TARGETARCH=${TARGETARCH}

# Install base dependencies and MinGW for Windows cross-compilation
RUN apt-get update && apt-get install -y \
    build-essential \
    mingw-w64 \
    yasm \
    nasm \
    git \
    wget \
    pkg-config \
    autoconf \
    automake \
    libtool \
    cmake \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY build-ffmpeg-docker.sh /build/build-ffmpeg.sh
RUN chmod +x /build/build-ffmpeg.sh

ARG FFMPEG_VERSION
ENV FFMPEG_VERSION=${FFMPEG_VERSION}

# Run the build script during image build
RUN /build/build-ffmpeg.sh

# Export stage - only contains output files
FROM scratch AS export
COPY --from=builder /build/output /
EOF
}

# Create build script for inside Docker
create_docker_build_script() {
    local build_script="${SCRIPT_DIR}/build-ffmpeg-docker.sh"
    
    log_info "Creating Docker build script..."
    
    cat > "$build_script" <<'EOF'
#!/bin/bash
set -e

FFMPEG_VERSION=${FFMPEG_VERSION:-6.1}
PREFIX="/build/output"
TARGETOS=${TARGETOS:-linux}
TARGETARCH=${TARGETARCH:-amd64}

echo "🔨 Building FFmpeg ${FFMPEG_VERSION} for ${TARGETOS}/${TARGETARCH}..."

# Download FFmpeg
if [ ! -d "ffmpeg-${FFMPEG_VERSION}" ]; then
    echo "📥 Downloading FFmpeg ${FFMPEG_VERSION}..."
    wget -q "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
    tar xf "ffmpeg-${FFMPEG_VERSION}.tar.xz"
fi

cd "ffmpeg-${FFMPEG_VERSION}"

# Base configure flags
configure_flags="
    --prefix=${PREFIX}
    --enable-gpl
    --enable-version3
    --disable-doc
    --disable-debug
    --disable-shared
    --enable-static
    --disable-ffplay
    --disable-ffprobe
"

# Configure based on platform
case "${TARGETOS}" in
    linux)
        case "${TARGETARCH}" in
            amd64)
                echo "🐧 Configuring for Linux x64..."
                ./configure $configure_flags \
                    --arch=x86_64 \
                    --extra-cflags=-static \
                    --extra-ldflags=-static \
                    --pkg-config-flags=--static
                ;;
            arm64)
                echo "🐧 Configuring for Linux ARM64..."
                ./configure $configure_flags \
                    --arch=aarch64 \
                    --extra-cflags=-static \
                    --extra-ldflags=-static \
                    --pkg-config-flags=--static
                ;;
            *)
                echo "❌ Unsupported Linux architecture: ${TARGETARCH}"
                exit 1
                ;;
        esac
        ;;
    
    windows)
        echo "🪟 Configuring for Windows..."
        case "${TARGETARCH}" in
            amd64)
                ./configure $configure_flags \
                    --arch=x86_64 \
                    --target-os=mingw32 \
                    --enable-cross-compile \
                    --cross-prefix=x86_64-w64-mingw32- \
                    --disable-schannel \
                    --extra-cflags="-static" \
                    --extra-ldflags="-static" \
                    --pkg-config-flags=--static
                ;;
            *)
                echo "❌ Unsupported Windows architecture: ${TARGETARCH}"
                exit 1
                ;;
        esac
        ;;
    
    *)
        echo "❌ Unsupported target OS: ${TARGETOS}"
        exit 1
        ;;
esac

# Build
echo "⚙️  Compiling FFmpeg..."
make -j$(nproc)
make install

echo "✅ Build complete! Binaries are in ${PREFIX}"
ls -lh ${PREFIX}/bin/
EOF
    
    chmod +x "$build_script"
}

# Create native macOS build script
create_macos_build_script() {
    local build_script="${SCRIPT_DIR}/build-ffmpeg-macos.sh"
    
    log_info "Creating native macOS build script..."
    
    cat > "$build_script" <<'EOF'
#!/bin/bash
set -e

FFMPEG_VERSION=${FFMPEG_VERSION:-6.1}
TARGET_ARCH=${TARGET_ARCH:-$(uname -m)}
BUILD_DIR="${BUILD_DIR:-/tmp/ffmpeg-build-${TARGET_ARCH}}"
PREFIX="${OUTPUT_DIR}"

echo "🍎 Building FFmpeg ${FFMPEG_VERSION} for macOS ${TARGET_ARCH}..."

# Check dependencies
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is required for macOS builds. Install from https://brew.sh"
    exit 1
fi

# Install build dependencies if needed
echo "📦 Checking build dependencies..."
for dep in yasm nasm pkg-config; do
    if ! command -v $dep &> /dev/null; then
        echo "Installing $dep..."
        brew install $dep
    fi
done

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download FFmpeg
if [ ! -d "ffmpeg-${FFMPEG_VERSION}" ]; then
    echo "📥 Downloading FFmpeg ${FFMPEG_VERSION}..."
    curl -L "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" -o "ffmpeg-${FFMPEG_VERSION}.tar.xz"
    tar xf "ffmpeg-${FFMPEG_VERSION}.tar.xz"
fi

cd "ffmpeg-${FFMPEG_VERSION}"

# Determine architecture
if [ "$TARGET_ARCH" = "x64" ]; then
    ARCH_FLAGS="--arch=x86_64"
    MACOS_MIN_VERSION="10.13"
elif [ "$TARGET_ARCH" = "arm64" ]; then
    ARCH_FLAGS="--arch=arm64"
    MACOS_MIN_VERSION="11.0"
else
    echo "❌ Unsupported architecture: ${TARGET_ARCH}"
    exit 1
fi

# Configure
echo "⚙️  Configuring FFmpeg for macOS ${TARGET_ARCH}..."
./configure \
    --prefix="${PREFIX}" \
    ${ARCH_FLAGS} \
    --enable-gpl \
    --enable-version3 \
    --disable-doc \
    --disable-debug \
    --disable-shared \
    --enable-static \
    --disable-ffplay \
    --disable-ffprobe \
    --extra-cflags="-mmacosx-version-min=${MACOS_MIN_VERSION}" \
    --extra-ldflags="-mmacosx-version-min=${MACOS_MIN_VERSION}"

# Build
echo "🔨 Compiling FFmpeg..."
make -j$(sysctl -n hw.ncpu)
make install

echo "✅ Build complete! Binaries are in ${PREFIX}"
ls -lh "${PREFIX}/bin/"

# Strip binary
echo "🔪 Stripping binary..."
strip "${PREFIX}/bin/ffmpeg"

# Show binary info
echo "📊 Binary information:"
file "${PREFIX}/bin/ffmpeg"
otool -L "${PREFIX}/bin/ffmpeg"
EOF
    
    chmod +x "$build_script"
}

# Build natively on macOS
build_macos_native() {
    local target_arch=$1
    local output_name="macos-${target_arch}"
    
    log_info "🍎 Building FFmpeg for ${output_name} (native)..."
    
    # Check if we're on macOS
    if [ "$HOST_OS" != "darwin" ]; then
        log_error "Native macOS builds can only run on macOS"
        return 1
    fi
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}/${output_name}/bin"
    
    # Create build script if it doesn't exist
    if [ ! -f "${SCRIPT_DIR}/build-ffmpeg-macos.sh" ]; then
        create_macos_build_script
    fi
    
    # Run the build
    env \
        FFMPEG_VERSION="${FFMPEG_VERSION}" \
        TARGET_ARCH="${target_arch}" \
        OUTPUT_DIR="${OUTPUT_DIR}/${output_name}" \
        BUILD_DIR="${SCRIPT_DIR}/build-temp-${target_arch}" \
        bash "${SCRIPT_DIR}/build-ffmpeg-macos.sh"
    
    # Verify output
    if [ -f "${OUTPUT_DIR}/${output_name}/bin/ffmpeg" ]; then
        log_success "Successfully built FFmpeg for ${output_name}"
        return 0
    else
        log_error "Build failed for ${output_name}"
        return 1
    fi
}

# Setup buildx
setup_buildx() {
    log_info "Setting up Docker Buildx..."
    
    # Check if buildx is available
    if ! docker buildx version &> /dev/null; then
        log_error "Docker Buildx is not available. Please update Docker to a version that supports Buildx."
        exit 1
    fi
    
    # Create/use a builder instance
    if ! docker buildx inspect ffmpeg-builder &> /dev/null; then
        log_info "Creating new buildx builder instance..."
        docker buildx create --name ffmpeg-builder --driver docker-container --bootstrap --use
    else
        log_info "Using existing buildx builder instance..."
        docker buildx use ffmpeg-builder
    fi
    
    # Inspect to show supported platforms
    log_info "Supported platforms:"
    docker buildx inspect --bootstrap | grep "Platforms:" || true
}

# Build using Docker for Linux/Windows
build_docker_platform() {
    local platform=$1
    local output_name=$2
    local dockerfile=$3
    
    local image_name="ffmpeg-electron:${output_name}"
    
    log_info "🐳 Building FFmpeg for ${output_name} using Docker..."
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}/${output_name}"
    
    # Determine build arguments based on platform
    local build_args=""
    local docker_platform=""
    
    case "$platform" in
        linux/amd64)
            build_args="--build-arg TARGETARCH=amd64 --build-arg TARGETOS=linux"
            docker_platform="linux/amd64"
            ;;
        linux/arm64)
            build_args="--build-arg TARGETARCH=arm64 --build-arg TARGETOS=linux"
            docker_platform="linux/arm64"
            ;;
        windows/amd64)
            build_args="--build-arg TARGETOS=windows --build-arg TARGETARCH=amd64"
            docker_platform="linux/amd64"  # Build container runs on Linux
            ;;
    esac
    
    # Build with buildx - the build script runs during image build now
    log_info "Building and compiling FFmpeg in one step..."
    docker buildx build \
        --platform "$docker_platform" \
        $build_args \
        --build-arg FFMPEG_VERSION="${FFMPEG_VERSION}" \
        --target export \
        --output "type=local,dest=${OUTPUT_DIR}/${output_name}" \
        -f "${SCRIPT_DIR}/${dockerfile}" \
        "${SCRIPT_DIR}"
    
    # Verify output
    if [ -f "${OUTPUT_DIR}/${output_name}/bin/ffmpeg" ] || [ -f "${OUTPUT_DIR}/${output_name}/bin/ffmpeg.exe" ]; then
        log_success "Successfully built FFmpeg for ${output_name}"
        return 0
    else
        log_error "Build failed for ${output_name}"
        return 1
    fi
}

# Build for a specific platform (router function)
build_platform() {
    local platform=$1
    
    case "$platform" in
        macos-x64|macos-arm64)
            if [ "$HOST_OS" = "darwin" ]; then
                local arch="${platform##*-}"
                build_macos_native "$arch"
            else
                log_warn "Skipping ${platform} - native macOS builds require macOS host"
                log_info "Run this script on macOS to build ${platform}"
                return 2
            fi
            ;;
        linux-x64)
            build_docker_platform "linux/amd64" "linux-x64" "Dockerfile.linux"
            ;;
        linux-arm64)
            build_docker_platform "linux/arm64" "linux-arm64" "Dockerfile.linux"
            ;;
        windows-x64)
            build_docker_platform "windows/amd64" "windows-x64" "Dockerfile.windows"
            ;;
        *)
            log_error "Unknown platform: $platform"
            return 1
            ;;
    esac
}

# Clean up buildx builder
cleanup_buildx() {
    if [ "$1" == "--remove-builder" ]; then
        log_info "Removing buildx builder instance..."
        docker buildx rm ffmpeg-builder 2>/dev/null || true
    fi
}

# Clean up build temp directories
cleanup_temp() {
    log_info "🧹 Cleaning up temporary build directories..."
    rm -rf "${SCRIPT_DIR}"/build-temp-*
}

# Clean all build artifacts and caches
clean_all() {
    log_info "🧹 Cleaning all build directories and artifacts..."
    
    # Remove output directories
    if [ -d "${OUTPUT_DIR}" ]; then
        log_info "Removing ${OUTPUT_DIR}..."
        rm -rf "${OUTPUT_DIR}"
    fi
    
    if [ -d "${DIST_DIR}" ]; then
        log_info "Removing ${DIST_DIR}..."
        rm -rf "${DIST_DIR}"
    fi
    
    # Remove temp build directories
    if ls "${SCRIPT_DIR}"/build-temp-* 1> /dev/null 2>&1; then
        log_info "Removing temporary build directories..."
        rm -rf "${SCRIPT_DIR}"/build-temp-*
    fi
    
    # Remove generated Dockerfiles
    if [ -f "${SCRIPT_DIR}/Dockerfile.linux" ]; then
        log_info "Removing Dockerfile.linux..."
        rm -f "${SCRIPT_DIR}/Dockerfile.linux"
    fi
    
    if [ -f "${SCRIPT_DIR}/Dockerfile.windows" ]; then
        log_info "Removing Dockerfile.windows..."
        rm -f "${SCRIPT_DIR}/Dockerfile.windows"
    fi
    
    # Remove build scripts
    if [ -f "${SCRIPT_DIR}/build-ffmpeg-docker.sh" ]; then
        log_info "Removing build-ffmpeg-docker.sh..."
        rm -f "${SCRIPT_DIR}/build-ffmpeg-docker.sh"
    fi
    
    if [ -f "${SCRIPT_DIR}/build-ffmpeg-macos.sh" ]; then
        log_info "Removing build-ffmpeg-macos.sh..."
        rm -f "${SCRIPT_DIR}/build-ffmpeg-macos.sh"
    fi
    
    # Remove Docker buildx cache if it exists
    if [ -d "${SCRIPT_DIR}/.buildx-cache" ]; then
        log_info "Removing Docker buildx cache..."
        rm -rf "${SCRIPT_DIR}/.buildx-cache"
    fi
    
    log_success "Clean complete!"
}

# Main function
main() {
    log_info "🎬 FFmpeg Cross-Compilation Script for Electron"
    log_info "📦 FFmpeg Version: ${FFMPEG_VERSION}"
    
    # Detect host platform
    detect_host_platform
    
    # Handle clean command
    if [[ " $* " =~ " --clean " ]]; then
        clean_all
        exit 0
    fi
    
    # Create output directories
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$DIST_DIR"
    
    # Parse arguments
    local platforms=()
    local remove_builder=false
    local cleanup_temp_dirs=false
    local docker_needed=false
    
    for arg in "$@"; do
        case "$arg" in
            --remove-builder)
                remove_builder=true
                ;;
            --cleanup)
                cleanup_temp_dirs=true
                ;;
            --clean)
                # Handled earlier in main()
                ;;
            --all)
                platforms=("linux-x64" "linux-arm64" "windows-x64" "macos-x64" "macos-arm64")
                ;;
            linux-x64|linux-arm64|windows-x64)
                platforms+=("$arg")
                docker_needed=true
                ;;
            macos-x64|macos-arm64)
                platforms+=("$arg")
                ;;
            *)
                log_warn "Unknown argument: $arg"
                ;;
        esac
    done
    
    # Default to all platforms if none specified
    if [ ${#platforms[@]} -eq 0 ]; then
        platforms=("linux-x64" "linux-arm64" "windows-x64" "macos-x64" "macos-arm64")
        docker_needed=true
    fi
    
    # Check if Docker is needed and available
    if [ "$docker_needed" = true ] || [ ${#platforms[@]} -gt 0 ]; then
        for platform in "${platforms[@]}"; do
            if [[ "$platform" =~ ^(linux|windows) ]]; then
                docker_needed=true
                break
            fi
        done
    fi
    
    if [ "$docker_needed" = true ]; then
        if ! command -v docker &> /dev/null; then
            log_error "Docker is required for Linux/Windows builds but not found"
            exit 1
        fi
        
        # Create Docker-related files based on what's needed
        local need_linux=false
        local need_windows=false
        
        for platform in "${platforms[@]}"; do
            case "$platform" in
                linux-*) need_linux=true ;;
                windows-*) need_windows=true ;;
            esac
        done
        
        if [ "$need_linux" = true ]; then
            create_dockerfile_linux
        fi
        
        if [ "$need_windows" = true ]; then
            create_dockerfile_windows
        fi
        
        create_docker_build_script
        setup_buildx
    fi
    
    # Create macOS build script if macOS platforms are requested
    for platform in "${platforms[@]}"; do
        if [[ "$platform" =~ ^macos ]]; then
            create_macos_build_script
            break
        fi
    done
    
    # Build for each platform
    local failed_builds=()
    local skipped_builds=()
    
    for platform in "${platforms[@]}"; do
        log_info "🚀 Starting build for ${platform}..."
        build_result=$(build_platform "$platform")
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            log_success "Completed ${platform}"
        elif [ $exit_code -eq 2 ]; then
            log_warn "Skipped ${platform}"
            skipped_builds+=("$platform")
        else
            log_error "Failed ${platform}"
            failed_builds+=("$platform")
        fi
        echo ""
    done
    
    # Cleanup if requested
    if [ "$remove_builder" = true ] && [ "$docker_needed" = true ]; then
        cleanup_buildx --remove-builder
    fi
    
    if [ "$cleanup_temp_dirs" = true ]; then
        cleanup_temp
    fi
    
    log_info "🎉 Build process complete!"
    log_info "📁 Binaries are in: ${OUTPUT_DIR}"
    
    # Show summary
    echo ""
    log_info "📊 Build Summary:"
    for platform in "${platforms[@]}"; do
        local output_name="$platform"
        
        if [ -f "${OUTPUT_DIR}/${output_name}/bin/ffmpeg" ] || [ -f "${OUTPUT_DIR}/${output_name}/bin/ffmpeg.exe" ]; then
            cp -r "${OUTPUT_DIR}/${output_name}/bin" "${DIST_DIR}/${output_name}"
            echo "  ✅ ${output_name}"
        elif [[ " ${skipped_builds[@]} " =~ " ${platform} " ]]; then
            echo "  ⏭️  ${output_name} (skipped - requires macOS host)"
        else
            echo "  ❌ ${output_name}"
        fi
    done
    
    # Show skip message
    if [ ${#skipped_builds[@]} -gt 0 ]; then
        echo ""
        log_info "💡 To build macOS binaries, run this script on a macOS machine"
    fi
    
    # Return error if any builds failed
    if [ ${#failed_builds[@]} -gt 0 ]; then
        echo ""
        log_error "Some builds failed: ${failed_builds[*]}"
        exit 1
    fi
}

# Show usage
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: $0 [platforms...] [options]"
    echo ""
    echo "Platforms:"
    echo "  linux-x64       Build for Linux x64 (Docker)"
    echo "  linux-arm64     Build for Linux ARM64 (Docker)"
    echo "  windows-x64     Build for Windows x64 (Docker)"
    echo "  macos-x64       Build for macOS x64 (native on macOS, skipped elsewhere)"
    echo "  macos-arm64     Build for macOS ARM64 (native on macOS, skipped elsewhere)"
    echo "  --all           Build for all platforms"
    echo ""
    echo "Options:"
    echo "  --remove-builder  Remove buildx builder instance after completion"
    echo "  --cleanup         Remove temporary build directories"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                              # Build all platforms"
    echo "  $0 --all                        # Build all platforms (explicit)"
    echo "  $0 linux-x64                    # Build only Linux x64"
    echo "  $0 macos-x64 macos-arm64        # Build macOS binaries (requires macOS)"
    echo "  $0 linux-x64 windows-x64        # Build Linux and Windows (Docker)"
    echo "  $0 --all --remove-builder       # Build all and cleanup"
    echo ""
    echo "Build Methods:"
    echo "  - Linux/Windows: Uses Docker Buildx with QEMU"
    echo "  - macOS: Uses native compilation when run on macOS"
    echo "  - macOS builds are skipped when run on non-macOS systems"
    echo ""
    echo "Requirements:"
    echo "  - Docker with Buildx (for Linux/Windows builds)"
    echo "  - macOS with Homebrew (for macOS builds)"
    echo "  - QEMU (installed automatically by Docker)"
    exit 0
fi

main "$@"