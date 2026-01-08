# NSIS Cross-Platform Builder

A comprehensive build system for creating static, portable NSIS (Nullsoft Scriptable Install System) binaries for macOS, Linux, and Windows with extensive plugin support.

## Features

- **Multi-platform support**: Build for macOS, Linux, and Windows
- **Static compilation**: All dependencies (zlib, bzip2, lzma) statically linked
- **Comprehensive plugins**: Automatically downloads and installs popular NSIS plugins
- **Portable bundles**: Self-contained archives ready to use anywhere
- **Docker-based Linux builds**: Consistent, reproducible builds
- **Configurable versions**: Easy version pinning via environment variables

## Requirements

### macOS
- Xcode Command Line Tools
- Homebrew
- 7-Zip (installed via Homebrew)

### Linux
- Docker (for containerized builds)
- Or native: build-essential, mingw-w64, scons, git, curl, unzip, p7zip

### Windows
- Visual Studio 2022 with MSVC v143 build tools
- Python 3.x
- SCons (`pip install scons`)
- CMake (>= 3.21)
- Git

## Quick Start

### Build for Current Platform

```bash
./build.sh
```

### Build for Specific Platform

```bash
# macOS
./build.sh mac

# Linux
./build.sh linux

# Windows (run on Windows)
./build.sh windows
```

### Clean Build

```bash
CLEAN_BUILD=true ./build.sh
```

## Configuration

Configure build versions using environment variables:

```bash
export NSIS_VERSION="3.11"
export NSIS_BRANCH_OR_COMMIT="v311"
export ZLIB_VERSION="1.3.1"

./build.sh
```

## Output Structure

After building, you'll find:

```
out/nsis/
├── nsis-bundle-mac-v311.zip        # macOS bundle
├── nsis-bundle-linux-v311.zip      # Linux bundle
└── nsis-bundle-windows-v311.zip    # Windows bundle
```

Each bundle contains:

```
nsis-bundle/
├── mac/makensis                    # macOS binary
├── linux/makensis                  # Linux binary
├── win32/makensis.exe              # Windows binary
└── share/nsis/                     # Shared NSIS data
    ├── Contrib/                    # Contrib modules
    ├── Include/                    # Header files
    ├── Plugins/                    # Plugin DLLs
    │   ├── x86-ansi/
    │   └── x86-unicode/
    └── Stubs/                      # Installer stubs
```

## Included Plugins

The build system automatically includes these popular plugins:

- **nsProcess**: Process control and management
- **UAC**: User Account Control elevation
- **WinShell**: Shell integration utilities
- **nsJSON**: JSON parsing and manipulation
- **nsArray**: Array data structures
- **INetC**: Internet/HTTP client

## Platform-Specific Notes

### macOS

The macOS build uses Homebrew's `makensis` package and includes:
- Native ARM64 or x86_64 binary
- Complete NSIS data tree
- All standard and additional plugins

### Linux

The Linux build uses Docker to create:
- Linux native binary (x86_64)
- Windows cross-compiled binaries (Win32)
- Shared NSIS data tree with plugins

### Windows

The Windows build creates:
- Native x86 binary with static linking
- All dependencies compiled from source
- Enhanced with custom SCons flags for optimal configuration

## Usage

### Extract a Bundle

```bash
unzip nsis-bundle-mac-v311.zip
cd nsis-bundle
```

### Set NSISDIR Environment Variable

```bash
export NSISDIR="$(pwd)/share/nsis"
```

### Run makensis

```bash
# macOS
./mac/makensis your-script.nsi

# Linux
./linux/makensis your-script.nsi

# Windows
win32\makensis.exe your-script.nsi
```

## Advanced Usage

### Docker-based Linux Build (from any platform)

```bash
docker run --rm -v $(pwd):/work -w /work ubuntu:22.04 bash -c "
  apt-get update && apt-get install -y bash curl git
  ./build.sh linux
"
```

### Custom Plugin Installation

To add more plugins, modify the plugin download section in:
- `assets/nsis-mac.sh` (macOS)
- `assets/nsis-linux.sh` (Dockerfile section)
- `assets/nsis-windows.ps1` (Windows)

Add plugin URLs to the download list:

```bash
download_plugin "PluginName" "http://nsis.sourceforge.net/mediawiki/images/X/XX/Plugin.zip"
```

## Troubleshooting

### macOS: "Command Line Tools not found"

```bash
xcode-select --install
```

### Linux: "Docker not found"

```bash
# Ubuntu/Debian
sudo apt-get install docker.io

# Fedora
sudo dnf install docker
```

### Windows: "Visual Studio not found"

Install Visual Studio 2022 with:
- Desktop development with C++
- MSVC v143 build tools
- CMake tools

### Plugin extraction fails

Ensure 7-Zip is installed:
- **macOS**: `brew install p7zip`
- **Linux**: `apt-get install p7zip-full`
- **Windows**: Download from https://7-zip.org

## Contributing

To add support for additional plugins:

1. Find the plugin on https://nsis.sourceforge.io/Category:Plugins
2. Add the download URL to the plugin lists in build scripts
3. Test the build on your target platform
4. Submit a pull request

## License

This build system is provided as-is. NSIS itself is licensed under the zlib/libpng license.

## Resources

- [NSIS Official Website](https://nsis.sourceforge.io/)
- [NSIS Documentation](https://nsis.sourceforge.io/Docs/)
- [NSIS Plugins](https://nsis.sourceforge.io/Category:Plugins)
- [NSIS GitHub Repository](https://github.com/kichik/nsis)

## Version History

- **v1.0.0**: Initial release with support for macOS, Linux, and Windows
  - NSIS 3.11
  - zlib 1.3.1
  - 6 core plugins included