<#
.SYNOPSIS
  Builds static NSIS (makensis.exe) for Windows with comprehensive plugin support.

.DESCRIPTION
  Compiles NSIS from source with static linking of zlib, bzip2, and lzma.
  Downloads and installs popular NSIS plugins from sourceforge.
  Creates a portable, self-contained bundle.

.REQUIREMENTS
  - Visual Studio 2022 with MSVC v143 build tools
  - Python 3.x + pip
  - SCons (pip install scons)
  - CMake (>= 3.21)
  - Git
  - 7-Zip (optional, for plugin extraction)

.NOTES
  Run nsis-windows-setup.ps1 first to install Python and SCons if needed.
#>

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# =============================================================================
# Configuration
# =============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BaseDir = Split-Path -Parent $ScriptDir
$OutDir = Join-Path $BaseDir "out"
$BuildRoot = Join-Path $OutDir "build"
$InstallRoot = Join-Path $BuildRoot "install"
$BundleDir = Join-Path $OutDir "nsis\nsis-bundle"

# Version configuration
$NsisVersion = if ($env:NSIS_BRANCH_OR_COMMIT) { $env:NSIS_BRANCH_OR_COMMIT } else { "v311" }
$ZlibVersion = if ($env:ZLIB_VERSION) { $env:ZLIB_VERSION } else { "1.3.1" }
$Bzip2Version = "bzip2-1.0.8"
$LzmaVersion = "v5.6.2"

$OutputArchive = "nsis-bundle-windows-$NsisVersion.zip"

# =============================================================================
# Banner
# =============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Windows NSIS Builder" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Version:    $NsisVersion" -ForegroundColor White
Write-Host "  zlib:       $ZlibVersion" -ForegroundColor White
Write-Host "  Output:     $OutDir\nsis" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# Setup Build Directories
# =============================================================================

Write-Host "🧹 Cleaning build directories..." -ForegroundColor Yellow

if (Test-Path $BuildRoot) {
    Remove-Item -Recurse -Force $BuildRoot
}

New-Item -ItemType Directory -Path $BuildRoot -Force | Out-Null
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
New-Item -ItemType Directory -Path $BundleDir -Force | Out-Null

$ZlibSrc = Join-Path $BuildRoot "zlib"
$Bzip2Src = Join-Path $BuildRoot "bzip2"
$LzmaSrc = Join-Path $BuildRoot "lzma"
$NsisSrc = Join-Path $BuildRoot "nsis"
$PluginsDir = Join-Path $BuildRoot "plugins"

# =============================================================================
# Helper Functions
# =============================================================================

function Clone-Repo {
    param (
        [string]$RepoUrl,
        [string]$Tag,
        [string]$Dest
    )
    
    Write-Host "  → Cloning $RepoUrl @ $Tag" -ForegroundColor Gray
    
    git clone --branch $Tag --single-branch --depth=1 $RepoUrl $Dest 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone $RepoUrl"
    }
}

function Invoke-WithVCEnv {
    param (
        [string]$Arch,
        [string[]]$Commands
    )

    $VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    
    if (-not (Test-Path $VsWhere)) {
        throw "Visual Studio not found. Please install Visual Studio 2022 with C++ build tools."
    }
    
    $VsPath = & $VsWhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
    $VcVars = Join-Path $VsPath "VC\Auxiliary\Build\vcvarsall.bat"
    
    if (-not (Test-Path $VcVars)) {
        throw "vcvarsall.bat not found at $VcVars"
    }

    $tmpBat = [System.IO.Path]::GetTempFileName() + ".bat"
    
    try {
        Set-Content $tmpBat "@echo off"
        Add-Content $tmpBat "call `"$VcVars`" $Arch"
        
        foreach ($cmd in $Commands) {
            Add-Content $tmpBat $cmd
        }

        Write-Host "  → Running build commands ($Arch)..." -ForegroundColor Gray

        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$tmpBat`"" `
            -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$tmpBat.out" -RedirectStandardError "$tmpBat.err"

        $exitCode = $process.ExitCode
        
        if ($exitCode -ne 0) {
            $stderr = Get-Content "$tmpBat.err" -Raw
            $stdout = Get-Content "$tmpBat.out" -Raw
            throw "Build failed (exit code: $exitCode)`n$stderr`n$stdout"
        }
    }
    finally {
        Remove-Item $tmpBat -Force -ErrorAction SilentlyContinue
        Remove-Item "$tmpBat.out" -Force -ErrorAction SilentlyContinue
        Remove-Item "$tmpBat.err" -Force -ErrorAction SilentlyContinue
    }
}

function Download-File {
    param (
        [string]$Url,
        [string]$OutFile
    )
    
    Write-Host "    Downloading $(Split-Path $OutFile -Leaf)..." -ForegroundColor Gray
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
    }
    catch {
        Write-Warning "Failed to download from $Url"
        return $false
    }
    
    return $true
}

# =============================================================================
# Clone Source Repositories
# =============================================================================

Write-Host "📦 Cloning source repositories..." -ForegroundColor Yellow

Clone-Repo "https://github.com/madler/zlib.git" "v$ZlibVersion" $ZlibSrc
Clone-Repo "https://sourceware.org/git/bzip2.git" $Bzip2Version $Bzip2Src
Clone-Repo "https://git.tukaani.org/xz.git" $LzmaVersion $LzmaSrc
Clone-Repo "https://github.com/kichik/nsis.git" $NsisVersion $NsisSrc

# =============================================================================
# Build Dependencies
# =============================================================================

Write-Host ""
Write-Host "🔨 Building dependencies..." -ForegroundColor Yellow

# Build zlib
Write-Host "  Building zlib..." -ForegroundColor Cyan
Invoke-WithVCEnv -Arch "x86" -Commands @(
    "cd /d `"$ZlibSrc`"",
    "if exist build rmdir /s /q build",
    "mkdir build",
    "cd build",
    "cmake .. -A Win32 -DCMAKE_INSTALL_PREFIX=`"$InstallRoot\zlib`" -DBUILD_SHARED_LIBS=OFF",
    "cmake --build . --config Release --target INSTALL"
)

# Rename zlib files for NSIS compatibility
$zlibLib = Join-Path "$InstallRoot\zlib\lib" "zlib.lib"
$zlibDll = Join-Path "$InstallRoot\zlib\bin" "zlib.dll"

if (Test-Path $zlibLib) {
    Move-Item $zlibLib (Join-Path "$InstallRoot\zlib\lib" "zdll.lib") -Force
}

if (Test-Path $zlibDll) {
    Move-Item $zlibDll (Join-Path "$InstallRoot\zlib\bin" "zlib1.dll") -Force
}

# Build bzip2
Write-Host "  Building bzip2..." -ForegroundColor Cyan
Invoke-WithVCEnv -Arch "x86" -Commands @(
    "cd /d `"$Bzip2Src`"",
    "nmake -f makefile.msc clean",
    "nmake -f makefile.msc",
    "if not exist `"$InstallRoot\bzip2\lib`" mkdir `"$InstallRoot\bzip2\lib`"",
    "if not exist `"$InstallRoot\bzip2\include`" mkdir `"$InstallRoot\bzip2\include`"",
    "copy libbz2.lib `"$InstallRoot\bzip2\lib\`"",
    "copy bzlib.h `"$InstallRoot\bzip2\include\`""
)

# Build lzma/xz
Write-Host "  Building lzma..." -ForegroundColor Cyan
Invoke-WithVCEnv -Arch "x86" -Commands @(
    "cd /d `"$LzmaSrc`"",
    "if exist build rmdir /s /q build",
    "mkdir build",
    "cd build",
    "cmake .. -A Win32 -DCMAKE_INSTALL_PREFIX=`"$InstallRoot\lzma`" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF",
    "cmake --build . --config Release --target INSTALL"
)

# =============================================================================
# Build NSIS
# =============================================================================

Write-Host ""
Write-Host "🔨 Building NSIS..." -ForegroundColor Yellow

$SconsFlags = @(
    "ZLIB_W32=`"$InstallRoot\zlib`"",
    "BZIP2_PATH=`"$InstallRoot\bzip2`"",
    "LZMA_PATH=`"$InstallRoot\lzma`"",
    "NSIS_MAX_STRLEN=8192",
    "NSIS_CONFIG_LOG=yes",
    "NSIS_CONFIG_CONST_DATA_PATH=no",
    "NSIS_CONFIG_USE_ELEVATE=yes",
    "NSIS_CONSOLE=yes",
    "SKIPPLUGINS=VPatch/Source/Plugin"
) -join " "

Invoke-WithVCEnv -Arch "x86" -Commands @(
    "cd /d `"$NsisSrc`"",
    "scons $SconsFlags"
)

# =============================================================================
# Download Additional Plugins
# =============================================================================

Write-Host ""
Write-Host "🔌 Downloading additional plugins..." -ForegroundColor Yellow

New-Item -ItemType Directory -Path $PluginsDir -Force | Out-Null

$Plugins = @(
    @{Name="NsProcess"; Url="http://nsis.sourceforge.net/mediawiki/images/1/18/NsProcess.zip"},
    @{Name="UAC"; Url="http://nsis.sourceforge.net/mediawiki/images/8/8f/UAC.zip"},
    @{Name="WinShell"; Url="http://nsis.sourceforge.net/mediawiki/images/5/54/WinShell.zip"},
    @{Name="NsJSON"; Url="http://nsis.sourceforge.net/mediawiki/images/5/5a/NsJSON.zip"},
    @{Name="NsArray"; Url="http://nsis.sourceforge.net/mediawiki/images/4/4c/NsArray.zip"},
    @{Name="INetC"; Url="http://nsis.sourceforge.net/mediawiki/images/c/c9/Inetc.zip"}
)

foreach ($plugin in $Plugins) {
    $zipFile = Join-Path $PluginsDir "$($plugin.Name).zip"
    
    if (Download-File -Url $plugin.Url -OutFile $zipFile) {
        Write-Host "  → $($plugin.Name)" -ForegroundColor Green
    }
}

# =============================================================================
# Assemble Portable Bundle
# =============================================================================

Write-Host ""
Write-Host "📦 Assembling portable bundle..." -ForegroundColor Yellow

# Copy NSIS build output
Copy-Item -Recurse -Force "$NsisSrc\build\urelease\*" $BundleDir

# Extract and install plugins
if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
    foreach ($plugin in $Plugins) {
        $zipFile = Join-Path $PluginsDir "$($plugin.Name).zip"
        
        if (Test-Path $zipFile) {
            $extractDir = Join-Path $PluginsDir $plugin.Name
            
            try {
                Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force
                
                # Copy DLL files
                Get-ChildItem -Path $extractDir -Filter "*.dll" -Recurse | ForEach-Object {
                    $relativePath = $_.DirectoryName.Substring($extractDir.Length).TrimStart('\')
                    
                    if ($relativePath -match "x86-ansi|ansi") {
                        Copy-Item $_.FullName "$BundleDir\Plugins\x86-ansi\" -Force
                    }
                    elseif ($relativePath -match "x86-unicode|unicode") {
                        Copy-Item $_.FullName "$BundleDir\Plugins\x86-unicode\" -Force
                    }
                }
                
                # Copy include files
                Get-ChildItem -Path $extractDir -Filter "*.nsh" -Recurse | ForEach-Object {
                    Copy-Item $_.FullName "$BundleDir\Include\" -Force
                }
            }
            catch {
                Write-Warning "Failed to extract plugin: $($plugin.Name)"
            }
        }
    }
}

# =============================================================================
# Create Version Metadata
# =============================================================================

$versionInfo = @"
NSIS Version: $NsisVersion
zlib Version: $ZlibVersion
bzip2 Version: $Bzip2Version
lzma Version: $LzmaVersion
Build Date: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" -AsUTC)
Platform: Windows
Architecture: x86
Build System: MSVC v143
"@

Set-Content -Path "$BundleDir\VERSION.txt" -Value $versionInfo

# =============================================================================
# Create Archive
# =============================================================================

Write-Host ""
Write-Host "📦 Creating archive..." -ForegroundColor Yellow

$archivePath = Join-Path "$OutDir\nsis" $OutputArchive

if (Test-Path $archivePath) {
    Remove-Item $archivePath -Force
}

Compress-Archive -Path $BundleDir -DestinationPath $archivePath -CompressionLevel Optimal

# =============================================================================
# Summary
# =============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  ✅ Build Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  📁 Bundle: $archivePath" -ForegroundColor White
Write-Host "  📊 Size:   $([math]::Round((Get-Item $archivePath).Length / 1MB, 2)) MB" -ForegroundColor White

if (Test-Path "$BundleDir\Plugins") {
    $pluginCount = (Get-ChildItem "$BundleDir\Plugins" -Filter "*.dll" -Recurse).Count
    Write-Host "  🔌 Plugins: $pluginCount installed" -ForegroundColor White
}

Write-Host "================================================================" -ForegroundColor Green
Write-Host ""