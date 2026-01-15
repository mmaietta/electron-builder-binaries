#!/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${2:-${ROOT}/out}"
DMGBUILD_VERSION="${1:-}"  # Set to specific version like "==1.6.6" or leave empty for latest

echo "📦 Creating dmgbuild portable bundle..."

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

PACKAGE_SPEC="dmgbuild${DMGBUILD_VERSION}"
echo "⬇️  Installing ${PACKAGE_SPEC} and dependencies to ${OUT_DIR}..."

# Install with --no-cache-dir to ensure we get the latest package info from PyPI
# This prevents issues with stale pip cache
pip3 install \
    --target="${OUT_DIR}" \
    --upgrade \
    --no-cache-dir \
    "${PACKAGE_SPEC}" 2>&1 | tee /dev/stderr

echo "🔍 Discovering installed packages..."

# Discover all Python packages in out directory
PACKAGES=()
for dir in "${OUT_DIR}"/*/ ; do
    if [ -d "$dir" ]; then
        dirname=$(basename "$dir")
        # Skip special directories
        if [[ ! "$dirname" =~ ^(__pycache__|.*\.dist-info|.*\.egg-info|bin|.*\.data)$ ]]; then
            # Check if it has __init__.py or is a valid package
            if [ -f "$dir/__init__.py" ] || [ -f "$dir/__main__.py" ]; then
                PACKAGES+=("$dirname")
                echo "  📌 Found: $dirname"
            fi
        fi
    fi
done

echo "🔨 Generating dynamic entrypoint for ${#PACKAGES[@]} packages..."

# Generate the entrypoint dynamically based on discovered packages
# First, write the header
cat > "${OUT_DIR}/builder.py" << 'EOF'
#!/usr/bin/env python3
"""
Portable entrypoint for dmgbuild and all outed dependencies.

This entrypoint is dynamically generated based on the packages in the out directory.

Usage:
  python3 builder.py [args]           # Runs dmgbuild (default)
  python3 builder.py <package> [args] # Run specific package
  python3 builder.py list             # List all available packages
  python3 builder.py help             # Show help
"""
import sys
import os
from pathlib import Path


def setup_vendor_path():
    """Add out directory to Python path."""
    vendor_dir = Path(__file__).parent.resolve()
    if str(vendor_dir) not in sys.path:
        sys.path.insert(0, str(vendor_dir))
    return vendor_dir


# Package metadata - dynamically generated during build
PACKAGES = {
EOF

# Add each discovered package to the metadata
for pkg in "${PACKAGES[@]}"; do
    # Try to detect package type and features
    HAS_MAIN="False"
    HAS_CLI="False"
    
    if [ -f "${OUT_DIR}/${pkg}/__main__.py" ]; then
        HAS_MAIN="True"
    fi
    
    # Specific package descriptions
    case "$pkg" in
        dmgbuild)
            DESCRIPTION="Create DMG files for macOS"
            HAS_CLI="True"
            ;;
        ds_store)
            DESCRIPTION="DS_Store file manipulation"
            ;;
        mac_alias)
            DESCRIPTION="Mac alias file support"
            ;;
        biplist)
            DESCRIPTION="Binary plist operations"
            ;;
        *)
            DESCRIPTION="Python package: $pkg"
            ;;
    esac
    
    cat >> "${OUT_DIR}/builder.py" << EOF
    '$pkg': {
        'description': '$DESCRIPTION',
        'has_main': $HAS_MAIN,
        'has_cli': $HAS_CLI,
    },
EOF
done

# Now write the footer with the rest of the functions
cat >> "${OUT_DIR}/builder.py" << 'EOF'
}


def run_package_main(package_name):
    """Run a package's __main__.py if it exists."""
    try:
        module = __import__(package_name)
        
        # Check for __main__ module
        main_module = f"{package_name}.__main__"
        try:
            import importlib
            main = importlib.import_module(main_module)
            
            # Look for main() function
            if hasattr(main, 'main'):
                sys.exit(main.main())
            else:
                # Execute the module
                import runpy
                runpy.run_module(main_module, run_name='__main__')
        except (ImportError, AttributeError):
            print(f"❌ {package_name} doesn't have a runnable __main__.py", file=sys.stderr)
            print(f"💡 Try: python3 builder.py {package_name} --interactive", file=sys.stderr)
            sys.exit(1)
            
    except ImportError as e:
        print(f"❌ Failed to import {package_name}: {e}", file=sys.stderr)
        sys.exit(1)


def run_package_interactive(package_name):
    """Start an interactive session with the package loaded."""
    try:
        module = __import__(package_name)
        version = getattr(module, '__version__', 'unknown')
        
        print(f"📦 {package_name} version {version}")
        print(f"📝 {PACKAGES[package_name]['description']}")
        print(f"\nPackage loaded as '{package_name}' in interactive session")
        print("💡 Type 'dir({})' to see available items\n".format(package_name))
        
        # Create namespace with the module
        namespace = {package_name: module}
        
        # Add commonly used items from the module to top level
        for attr in dir(module):
            if not attr.startswith('_'):
                namespace[attr] = getattr(module, attr)
        
        import code
        code.interact(local=namespace, banner='')
        
    except ImportError as e:
        print(f"❌ Failed to import {package_name}: {e}", file=sys.stderr)
        sys.exit(1)


def list_packages():
    """List all available outed packages."""
    print("📦 Available outed packages:\n")
    
    # Get versions for all packages
    for name, info in sorted(PACKAGES.items()):
        try:
            module = __import__(name)
            version = getattr(module, '__version__', 'unknown')
        except:
            version = 'unknown'
        
        description = info['description']
        has_main = '🚀' if info['has_main'] else '📚'
        
        print(f"  {has_main} {name:20s} v{version:10s} - {description}")
    
    print(f"\n💡 Total packages: {len(PACKAGES)}")
    print("\n🚀 = Has CLI/main entry point")
    print("📚 = Library only (use --interactive)")


def show_help():
    """Show help message."""
    print(__doc__)
    print("\n📚 Available commands:")
    
    for name, info in sorted(PACKAGES.items()):
        status = "CLI" if info['has_main'] or info['has_cli'] else "interactive"
        print(f"  {name:15s} - {info['description']} ({status})")
    
    print("\n🛠️  Special commands:")
    print("  list           - List all outed packages")
    print("  help           - Show this help message")
    print("  <pkg> --interactive  - Start interactive session with package")
    
    print("\n💡 If no command is specified, dmgbuild is run by default")
    print("\n🚀 Examples:")
    print("  python3 builder.py -s settings.py MyApp MyApp.dmg")
    print("  python3 builder.py list")
    print("  python3 builder.py ds_store --interactive")


def main():
    """Main entrypoint router."""
    # Setup out path first
    setup_vendor_path()
    
    # Determine which tool to run
    if len(sys.argv) < 2:
        # No arguments - show help instead of trying to run dmgbuild without args
        show_help()
        sys.exit(0)
    
    command = sys.argv[1].lower()
    
    # Check if first arg looks like a flag/option (for default package)
    if command.startswith('-') or command.endswith('.py'):
        # It's an argument for the default package (dmgbuild)
        if 'dmgbuild' in PACKAGES:
            run_package_main('dmgbuild')
        else:
            print("❌ No default package available", file=sys.stderr)
            sys.exit(1)
    
    # Special commands
    if command in ['list', 'ls']:
        list_packages()
    
    elif command in ['help', '--help', '-h']:
        show_help()
    
    # Check if it's a known package
    elif command in PACKAGES:
        # Check for --interactive flag
        if '--interactive' in sys.argv or '-i' in sys.argv:
            run_package_interactive(command)
        else:
            # Remove package name from argv
            sys.argv = [sys.argv[0]] + sys.argv[2:]
            
            if PACKAGES[command]['has_main']:
                run_package_main(command)
            else:
                # Package doesn't have a CLI, suggest interactive mode
                print(f"💡 {command} is a library package without a CLI interface", file=sys.stderr)
                print(f"🔧 Try: python3 builder.py {command} --interactive", file=sys.stderr)
                sys.exit(1)
    
    else:
        print(f"❌ Unknown command: {command}", file=sys.stderr)
        print(f"💡 Run 'python3 builder.py help' for usage", file=sys.stderr)
        print(f"📦 Run 'python3 builder.py list' to see available packages", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
EOF

chmod +x "${OUT_DIR}/builder.py"

# Cleanup unnecessary files
echo "🧹 Cleaning up unnecessary files..."

# Remove __pycache__ directories
while IFS= read -r -d '' dir; do
    rm -rf "$dir"
done < <(find "${OUT_DIR}" -type d -name "__pycache__" -print0)

# Remove .dist-info directories
while IFS= read -r -d '' dir; do
    rm -rf "$dir"
done < <(find "${OUT_DIR}" -type d -name "*.dist-info" -print0)

# Remove .pyc files
while IFS= read -r -d '' file; do
    rm -f "$file"
done < <(find "${OUT_DIR}" -type f -name "*.pyc" -print0)

echo "✅ Bundle created at: ${OUT_DIR}"
echo ""
echo "📦 Discovered packages:"
for pkg in "${PACKAGES[@]}"; do
    echo "  • $pkg"
done

echo ""
echo "💡 Usage: python3 ${OUT_DIR}/builder.py [command] [arguments]"

# Show installed version
if command -v python3 &> /dev/null; then
    INSTALLED_VERSION=$(python3 -c "import sys; sys.path.insert(0, '${OUT_DIR}'); import dmgbuild; print(dmgbuild.__version__)" 2>/dev/null || echo "unknown")
    echo "📌 Installed dmgbuild version: ${INSTALLED_VERSION}"
fi

echo "  Testing entrypoint:"
python3 "${OUT_DIR}/builder.py" --help | head -n 10
echo "  Entrypoint test complete."

echo ""
echo "✅ Bundle is ready to use!"
echo ""
echo "🚀 Quick examples:"
echo "  python3 ${OUT_DIR}/builder.py -s settings.py MyApp MyApp.dmg"
echo "  python3 ${OUT_DIR}/builder.py list"
echo "  python3 ${OUT_DIR}/builder.py ds_store --interactive"
echo "  python3 ${OUT_DIR}/builder.py help"