#!/usr/bin/env bash
# ============================================================================
# Common Utility Functions for Wine Build Scripts
# ============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Error handler
error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# Download file with checksum verification
# Usage: download_and_verify <url> <output_file> <expected_sha256>
download_and_verify() {
    local url="$1"
    local output="$2"
    local expected_checksum="$3"
    local filename
    filename="$(basename "$output")"
    
    log_info "Downloading $filename..."
    
    # Download with retry logic
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if curl -L --fail --progress-bar "$url" -o "$output"; then
            break
        fi
        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            log_warn "Download failed, retrying ($retry/$max_retries)..."
            sleep 2
        else
            error_exit "Failed to download $url after $max_retries attempts"
        fi
    done
    
    log_info "Verifying checksum for $filename..."
    
    # Calculate checksum based on available tool
    local actual_checksum
    if command -v sha256sum &> /dev/null; then
        actual_checksum=$(sha256sum "$output" | awk '{print $1}')
    elif command -v shasum &> /dev/null; then
        actual_checksum=$(shasum -a 256 "$output" | awk '{print $1}')
    else
        error_exit "No SHA256 checksum tool found (sha256sum or shasum)"
    fi
    
    # Compare checksums (case-insensitive)
    if [ "${actual_checksum,,}" = "${expected_checksum,,}" ]; then
        log_success "Checksum verified: $filename"
        return 0
    else
        log_error "Checksum verification failed for $filename"
        log_error "Expected: $expected_checksum"
        log_error "Received: $actual_checksum"
        rm -f "$output"
        return 1
    fi
}

# Extract archive
# Usage: extract_archive <archive_file> <destination_dir>
extract_archive() {
    local archive="$1"
    local dest="${2:-.}"
    local filename
    filename="$(basename "$archive")"
    
    log_info "Extracting $filename..."
    
    mkdir -p "$dest"
    
    case "$archive" in
        *.tar.xz)
            tar -xJf "$archive" -C "$dest"
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$dest"
            ;;
        *.tar.bz2|*.tbz2)
            tar -xjf "$archive" -C "$dest"
            ;;
        *.zip)
            unzip -q "$archive" -d "$dest"
            ;;
        *)
            error_exit "Unsupported archive format: $archive"
            ;;
    esac
    
    log_success "Extracted $filename"
}

# Check if command exists
# Usage: check_command <command_name> [package_name]
check_command() {
    local cmd="$1"
    local pkg="${2:-$1}"
    
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command '$cmd' not found"
        log_error "Please install: $pkg"
        return 1
    fi
    return 0
}

# Check multiple commands
# Usage: check_commands <cmd1> <cmd2> ...
check_commands() {
    local missing=()
    
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing[*]}"
        return 1
    fi
    return 0
}

# Get number of CPU cores
get_cpu_count() {
    local cores
    
    if [ "$(uname)" = "Darwin" ]; then
        cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
    else
        cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
    fi
    
    echo "$cores"
}

# Create directory structure for Wine distribution
# Usage: create_wine_dist_structure <output_dir>
create_wine_dist_structure() {
    local output_dir="$1"
    
    log_info "Creating distribution directory structure..."
    
    mkdir -p "$output_dir"/{bin,lib,lib64/wine,share/wine,wine-home}
    
    log_success "Directory structure created"
}

# Initialize Wine prefix
# Usage: init_wine_prefix <wine_binary> <prefix_dir>
init_wine_prefix() {
    local wine_bin="$1"
    local prefix_dir="$2"
    
    log_info "Initializing Wine prefix at: $prefix_dir"
    
    export WINEPREFIX="$prefix_dir"
    export WINEDEBUG=-all
    export DISPLAY="${DISPLAY:-:0.0}"  # Set dummy display if not set
    
    # Initialize Wine prefix
    "$wine_bin" wineboot --init 2>&1 | grep -v "fixme:" || true
    
    # Wait for initialization
    sleep 3
    
    # Stop Wine server
    "$wine_bin" wineserver -k 2>&1 | grep -v "fixme:" || true
    
    # Wait for shutdown
    sleep 2
    
    # Verify initialization
    if [ -d "$prefix_dir/dosdevices" ] && \
       [ -d "$prefix_dir/drive_c" ] && \
       [ -f "$prefix_dir/system.reg" ]; then
        log_success "Wine prefix initialized successfully"
        return 0
    else
        log_error "Wine prefix initialization failed"
        return 1
    fi
}

# Create launcher script
# Usage: create_launcher <output_file> <wine_dir>
create_launcher() {
    local output_file="$1"
    local wine_dir="$2"
    
    log_info "Creating launcher script: $output_file"
    
    cat > "$output_file" << 'LAUNCHER_EOF'
#!/usr/bin/env bash
# Wine Launcher Script
# Auto-generated by Wine build system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WINEPREFIX="${WINEPREFIX:-$SCRIPT_DIR/wine-home}"
export WINEDEBUG="${WINEDEBUG:--all}"

# Add Wine binaries to PATH
export PATH="$SCRIPT_DIR/bin:$PATH"

# Set library paths for Linux
if [ "$(uname)" = "Linux" ]; then
    export LD_LIBRARY_PATH="$SCRIPT_DIR/lib64:$SCRIPT_DIR/lib:${LD_LIBRARY_PATH:-}"
fi

# Set library paths for macOS
if [ "$(uname)" = "Darwin" ]; then
    export DYLD_LIBRARY_PATH="$SCRIPT_DIR/lib64:$SCRIPT_DIR/lib:${DYLD_LIBRARY_PATH:-}"
    export DYLD_FALLBACK_LIBRARY_PATH="$SCRIPT_DIR/lib64:$SCRIPT_DIR/lib:${DYLD_FALLBACK_LIBRARY_PATH:-}"
fi

# Determine Wine binary
if [ -f "$SCRIPT_DIR/bin/wine64" ]; then
    WINE_BIN="$SCRIPT_DIR/bin/wine64"
elif [ -f "$SCRIPT_DIR/bin/wine" ]; then
    WINE_BIN="$SCRIPT_DIR/bin/wine"
else
    echo "Error: Wine binary not found" >&2
    exit 1
fi

# Show help if no arguments
if [ $# -eq 0 ]; then
    echo "Usage: $(basename "$0") <windows_program.exe> [arguments...]"
    echo ""
    echo "Environment Variables:"
    echo "  WINEPREFIX   Wine prefix directory (default: $SCRIPT_DIR/wine-home)"
    echo "  WINEDEBUG    Wine debug options (default: -all)"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") notepad"
    echo "  $(basename "$0") winecfg"
    echo "  $(basename "$0") /path/to/application.exe"
    exit 0
fi

# Execute Wine
exec "$WINE_BIN" "$@"
LAUNCHER_EOF
    
    chmod +x "$output_file"
    log_success "Launcher script created"
}

# Create README for distribution
# Usage: create_readme <output_file> <wine_version> <os> <arch>
create_readme() {
    local output_file="$1"
    local wine_version="$2"
    local os="$3"
    local arch="$4"
    
    log_info "Creating README: $output_file"
    
    cat > "$output_file" << README_EOF
# Wine ${wine_version} - ${os^} ${arch}

This is a self-contained Wine installation with a pre-initialized Wine prefix.

## Build Information

- **Wine Version:** ${wine_version}
- **Platform:** ${os^}
- **Architecture:** ${arch}
- **Build Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Quick Start

### Running Windows Applications

\`\`\`bash
./wine-launcher.sh /path/to/windows/application.exe
\`\`\`

### Running Wine Built-in Programs

\`\`\`bash
# Wine configuration
./wine-launcher.sh winecfg

# Registry editor
./wine-launcher.sh regedit

# Notepad
./wine-launcher.sh notepad

# File manager
./wine-launcher.sh winefile
\`\`\`

## Advanced Usage

### Custom Wine Prefix

\`\`\`bash
export WINEPREFIX="/path/to/custom/prefix"
./wine-launcher.sh your-app.exe
\`\`\`

### Enable Debug Output

\`\`\`bash
export WINEDEBUG=warn+all
./wine-launcher.sh your-app.exe
\`\`\`

### Direct Binary Access

\`\`\`bash
export WINEPREFIX="\$(pwd)/wine-home"
./bin/wine64 your-app.exe
\`\`\`

## Directory Structure

- \`bin/\` - Wine executables and utilities
- \`lib/\` - 32-bit Wine libraries (if built)
- \`lib64/\` - 64-bit Wine libraries and DLLs
- \`share/wine/\` - Wine data files, fonts, and resources
- \`wine-home/\` - Pre-initialized Wine prefix (Windows C: drive)
- \`wine-launcher.sh\` - Convenience launcher script

## Wine Prefix Structure

The \`wine-home/\` directory contains:

- \`dosdevices/\` - DOS device mappings (C:, Z:, etc.)
- \`drive_c/\` - Windows C: drive with Program Files, Windows, etc.
- \`system.reg\` - System registry hive
- \`user.reg\` - User registry hive
- \`userdef.reg\` - User defaults registry hive

## Installing Windows Software

### Using Winetricks (if available)

\`\`\`bash
export WINEPREFIX="\$(pwd)/wine-home"
winetricks dotnet48
winetricks vcrun2019
\`\`\`

### Manual Installation

\`\`\`bash
./wine-launcher.sh /path/to/installer.exe
\`\`\`

## Troubleshooting

### Application Won't Start

1. Check if running in 32-bit or 64-bit mode:
   \`\`\`bash
   file /path/to/application.exe
   \`\`\`

2. Enable debug output:
   \`\`\`bash
   export WINEDEBUG=warn+all
   ./wine-launcher.sh your-app.exe
   \`\`\`

### Missing DLL Errors

Install required Windows components using the application's installer or winetricks.

### Graphics Issues

Try different graphics settings:
\`\`\`bash
./wine-launcher.sh winecfg
# Go to Graphics tab and adjust settings
\`\`\`

### Reset Wine Prefix

\`\`\`bash
rm -rf wine-home
export WINEPREFIX="\$(pwd)/wine-home"
./bin/wine64 wineboot --init
\`\`\`

## Environment Variables

- \`WINEPREFIX\` - Wine prefix directory (default: \`./wine-home\`)
- \`WINEDEBUG\` - Debug output level (default: \`-all\`)
- \`WINEARCH\` - Architecture (win32 or win64)
- \`DISPLAY\` - X11 display (Linux only)

## Additional Resources

- Wine Documentation: https://www.winehq.org/documentation
- Wine Wiki: https://wiki.winehq.org/
- Wine AppDB: https://appdb.winehq.org/

## License

Wine is free software released under the GNU LGPL.
See https://www.winehq.org/license for details.

## Support

For Wine support, visit:
- WineHQ Forums: https://forum.winehq.org/
- Wine Bugzilla: https://bugs.winehq.org/

---

Built with Wine build scripts
README_EOF
    
    log_success "README created"
}

# Print banner
print_banner() {
    echo "============================================================================"
    echo "$@"
    echo "============================================================================"
}

# Export functions for use in other scripts
export -f log_info log_success log_warn log_error error_exit
export -f download_and_verify extract_archive
export -f check_command check_commands get_cpu_count
export -f create_wine_dist_structure init_wine_prefix
export -f create_launcher create_readme print_banner