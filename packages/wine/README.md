# Wine Build System

Simple bash scripts to build Wine from source for macOS and Linux.

## Quick Start

```bash
./build.sh
```

That's it! Wine will be built for your current platform.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WINE_VERSION` | Wine version to build | `9.0` |
| `OS_TARGET` | Target OS: `darwin` or `linux` | Auto-detect |
| `PLATFORM_ARCH` | Architecture: `x86_64` or `arm64` | Auto-detect |
| `BUILD_DIR` | Build output directory | `./build` |

## Examples

### Build for current platform
```bash
./build.sh
```

### Build Wine 8.0
```bash
WINE_VERSION=8.0 ./build.sh
```

### Build for macOS Intel
```bash
OS_TARGET=darwin PLATFORM_ARCH=x86_64 ./build.sh
```

### Build for macOS Apple Silicon
```bash
OS_TARGET=darwin PLATFORM_ARCH=arm64 ./build.sh
```

### Build for Linux x86_64 (requires Docker)
```bash
OS_TARGET=linux PLATFORM_ARCH=x86_64 ./build.sh
```

### Build for Linux ARM64 (requires Docker)
```bash
OS_TARGET=linux PLATFORM_ARCH=arm64 ./build.sh
```

## Prerequisites

### macOS
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install Homebrew dependencies
brew install mingw-w64 freetype libpng jpeg-turbo libtiff little-cms2 \
             libxml2 libxslt xz gnutls sdl2 faudio openal-soft
```

### Linux Builds (via Docker on macOS)
- Docker Desktop installed and running

## Output

Each build creates:
- `build/wine-{version}-{os}-{arch}/` - Wine installation
- `build/wine-{version}-{os}-{arch}.tar.gz` - Compressed archive

## Using Wine

After building:

```bash
cd build/wine-9.0-darwin-arm64
./wine-launcher.sh notepad
```

Or extract the archive anywhere:

```bash
tar -xzf build/wine-9.0-darwin-arm64.tar.gz
cd wine-9.0-darwin-arm64
./wine-launcher.sh your-windows-app.exe
```

## Project Structure

```
.
├── build.sh                # Main entry point
└── scripts/
    ├── build-mac.sh       # macOS build
    └── build-linux.sh     # Linux build (Docker)
```

## Supported Wine Versions

- Wine 9.0 ✅
- Wine 8.0 ✅

To add more versions, edit the `CHECKSUMS` array in the build scripts.

## License

Wine is free software released under the GNU LGPL.