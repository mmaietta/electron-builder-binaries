<#
.SYNOPSIS
  Downloads and packages NSIS for Windows with comprehensive plugin support.

.DESCRIPTION
  Downloads pre-built NSIS binaries for the specified architecture.
  Downloads and installs popular NSIS plugins from sourceforge.
  Creates a portable, self-contained bundle.

.PARAMETER Architecture
  Target architecture: x86 (default), x64, or arm64

.EXAMPLE
  .\nsis-windows.ps1 -Architecture x86
  .\nsis-windows.ps1 -Architecture x64
  .\nsis-windows.ps1 -Architecture arm64

.NOTES
  No compilation required - uses official NSIS releases.
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('x86', 'x64', 'arm64')]
    [string]$Architecture = 'x86'
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# =============================================================================
# Configuration
# =============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BaseDir = Split-Path -Parent $ScriptDir
$OutDir = Join-Path $BaseDir "out"
$NsisOutDir = Join-Path $OutDir "nsis"
$TempDir = Join-Path $OutDir "temp"
$BundleDir = Join-Path $NsisOutDir "nsis-bundle"

# Version configuration
$NsisVersion = if ($env:NSIS_VERSION) { $env:NSIS_VERSION } else { "3.10" }
$NsisBranch = if ($env:NSIS_BRANCH_OR_COMMIT) { $env:NSIS_BRANCH_OR_COMMIT } else { "v310" }

# NSIS download URL (official releases)
$NsisBaseUrl = "https://sourceforge.net/projects/nsis/files/NSIS%203/$NsisVersion"
$NsisZipUrl = "$NsisBaseUrl/nsis-$NsisVersion.zip/download"

$OutputArchive = "nsis-bundle-windows-$Architecture-$NsisBranch.zip"

# =============================================================================
# Banner
# =============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Windows NSIS Packager" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Version:        $NsisVersion" -ForegroundColor White
Write-Host "  Architecture:   $Architecture" -ForegroundColor White
Write-Host "  Output:         $NsisOutDir" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# Setup Directories
# =============================================================================

Write-Host "🧹 Setting up directories..." -ForegroundColor Yellow

if (Test-Path $TempDir) {
    Remove-Item -Recurse -Force $TempDir
}

New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
New-Item -ItemType Directory -Path $NsisOutDir -Force | Out-Null
New-Item -ItemType Directory -Path "$BundleDir\windows\$Architecture" -Force | Out-Null
New-Item -ItemType Directory -Path "$BundleDir\share" -Force | Out-Null

$PluginsDir = Join-Path $TempDir "plugins"
New-Item -ItemType Directory -Path $PluginsDir -Force | Out-Null

# =============================================================================
# Helper Functions
# =============================================================================

function Download-File {
    param (
        [string]$Url,
        [string]$OutFile,
        [string]$Description = ""
    )
    
    if ($Description) {
        Write-Host "  → $Description" -ForegroundColor Gray
    }
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutFile)
        return $true
    }
    catch {
        Write-Warning "Failed to download from $Url : $_"
        return $false
    }
}

# =============================================================================
# Download NSIS
# =============================================================================

Write-Host ""
Write-Host "📦 Downloading NSIS $NsisVersion..." -ForegroundColor Yellow

$nsisZip = Join-Path $TempDir "nsis-$NsisVersion.zip"

if (-not (Download-File -Url $NsisZipUrl -OutFile $nsisZip -Description "NSIS $NsisVersion archive")) {
    throw "Failed to download NSIS"
}

Write-Host "  → Extracting NSIS..." -ForegroundColor Gray
Expand-Archive -Path $nsisZip -DestinationPath $TempDir -Force

$nsisExtracted = Join-Path $TempDir "nsis-$NsisVersion"

if (-not (Test-Path $nsisExtracted)) {
    throw "NSIS extraction failed - directory not found: $nsisExtracted"
}

# =============================================================================
# Copy NSIS Files
# =============================================================================

Write-Host ""
Write-Host "📂 Organizing NSIS files..." -ForegroundColor Yellow

# Copy binary based on architecture
$makensisSource = Join-Path $nsisExtracted "makensis.exe"

if ($Architecture -eq "x86") {
    # Use the default makensis.exe (32-bit)
    Copy-Item $makensisSource "$BundleDir\windows\$Architecture\makensis.exe" -Force
}
elseif ($Architecture -eq "x64") {
    # For x64, we can use the same binary (it runs fine on x64)
    # NSIS doesn't provide separate x64 compiler binaries
    Copy-Item $makensisSource "$BundleDir\windows\$Architecture\makensis.exe" -Force
}
elseif ($Architecture -eq "arm64") {
    # ARM64 also uses the x86 binary (runs via emulation)
    Copy-Item $makensisSource "$BundleDir\windows\$Architecture\makensis.exe" -Force
}

# Copy share/nsis data
Write-Host "  → Copying NSIS data files..." -ForegroundColor Gray

$shareItems = @("Contrib", "Include", "Plugins", "Stubs")
foreach ($item in $shareItems) {
    $source = Join-Path $nsisExtracted $item
    if (Test-Path $source) {
        Copy-Item -Recurse -Force $source "$BundleDir\share\nsis\"
    }
}

# Remove unnecessary files
Remove-Item "$BundleDir\share\nsis\Contrib\Graphics\Checks" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$BundleDir\share\nsis\Contrib\Graphics\Header" -Recurse -Force -ErrorAction SilentlyContinue

# =============================================================================
# Download Additional Plugins
# =============================================================================

Write-Host ""
Write-Host "🔌 Downloading additional plugins..." -ForegroundColor Yellow

$Plugins = @(
    @{Name="NsProcess"; Url="https://nsis.sourceforge.io/mediawiki/images/1/18/NsProcess.zip"},
    @{Name="UAC"; Url="https://nsis.sourceforge.io/mediawiki/images/8/8f/UAC.zip"},
    @{Name="WinShell"; Url="https://nsis.sourceforge.io/mediawiki/images/5/54/WinShell.zip"},
    @{Name="NsJSON"; Url="https://nsis.sourceforge.io/mediawiki/images/5/5a/NsJSON.zip"},
    @{Name="NsArray"; Url="https://nsis.sourceforge.io/mediawiki/images/4/4c/NsArray.zip"},
    @{Name="INetC"; Url="https://nsis.sourceforge.io/mediawiki/images/c/c9/Inetc.zip"},
    @{Name="NsisMultiUser"; Url="https://nsis.sourceforge.io/mediawiki/images/5/5d/NsisMultiUser.zip"},
    @{Name="StdUtils"; Url="https://nsis.sourceforge.io/mediawiki/images/d/d2/StdUtils.2020-10-23.zip"}
)

$downloadedPlugins = @()

foreach ($plugin in $Plugins) {
    $zipFile = Join-Path $PluginsDir "$($plugin.Name).zip"
    
    if (Download-File -Url $plugin.Url -OutFile $zipFile -Description $plugin.Name) {
        $downloadedPlugins += $plugin
    }
}

Write-Host "  ✓ Downloaded $($downloadedPlugins.Count) plugins" -ForegroundColor Green

# =============================================================================
# Install Plugins
# =============================================================================

Write-Host ""
Write-Host "🔧 Installing plugins..." -ForegroundColor Yellow

foreach ($plugin in $downloadedPlugins) {
    $zipFile = Join-Path $PluginsDir "$($plugin.Name).zip"
    
    if (Test-Path $zipFile) {
        $extractDir = Join-Path $PluginsDir $plugin.Name
        
        try {
            Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force
            
            # Copy DLL files to appropriate plugin directories
            Get-ChildItem -Path $extractDir -Filter "*.dll" -Recurse | ForEach-Object {
                $relativePath = $_.DirectoryName.Replace($extractDir, "").TrimStart('\')
                
                # Determine target directory based on path
                if ($relativePath -match "x86-ansi|\\ansi|Ansi") {
                    $target = "$BundleDir\share\nsis\Plugins\x86-ansi"
                    if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
                    Copy-Item $_.FullName $target -Force -ErrorAction SilentlyContinue
                }
                elseif ($relativePath -match "x86-unicode|\\unicode|Unicode") {
                    $target = "$BundleDir\share\nsis\Plugins\x86-unicode"
                    if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
                    Copy-Item $_.FullName $target -Force -ErrorAction SilentlyContinue
                }
                # If no specific path, copy to both
                elseif ($_.Name -match "W\.dll$") {
                    $target = "$BundleDir\share\nsis\Plugins\x86-unicode"
                    if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
                    Copy-Item $_.FullName $target -Force -ErrorAction SilentlyContinue
                }
                else {
                    $target = "$BundleDir\share\nsis\Plugins\x86-ansi"
                    if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
                    Copy-Item $_.FullName $target -Force -ErrorAction SilentlyContinue
                }
            }
            
            # Copy include files
            Get-ChildItem -Path $extractDir -Filter "*.nsh" -Recurse | ForEach-Object {
                Copy-Item $_.FullName "$BundleDir\share\nsis\Include\" -Force -ErrorAction SilentlyContinue
            }
            
            Get-ChildItem -Path $extractDir -Filter "*.nsi" -Recurse | Where-Object { $_.Name -notmatch "Example|Test" } | ForEach-Object {
                Copy-Item $_.FullName "$BundleDir\share\nsis\Include\" -Force -ErrorAction SilentlyContinue
            }
            
            Write-Host "  ✓ Installed $($plugin.Name)" -ForegroundColor Gray
        }
        catch {
            Write-Warning "Failed to install plugin: $($plugin.Name) - $_"
        }
    }
}

# =============================================================================
# Create Version Metadata
# =============================================================================

Write-Host ""
Write-Host "📝 Creating version metadata..." -ForegroundColor Yellow

$versionInfo = @"
NSIS Version: $NsisVersion
Branch/Tag: $NsisBranch
Build Date: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" -AsUTC)
Platform: Windows
Architecture: $Architecture
Plugins: $($downloadedPlugins.Count) additional plugins installed
"@

Set-Content -Path "$BundleDir\windows\$Architecture\VERSION.txt" -Value $versionInfo

# =============================================================================
# Create Archive
# =============================================================================

Write-Host ""
Write-Host "📦 Creating archive..." -ForegroundColor Yellow

$archivePath = Join-Path $NsisOutDir $OutputArchive

if (Test-Path $archivePath) {
    Remove-Item $archivePath -Force
}

# Create archive from bundle directory
Push-Location $NsisOutDir
Compress-Archive -Path "nsis-bundle\*" -DestinationPath $OutputArchive -CompressionLevel Optimal
Pop-Location

# Cleanup temp directory
Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue

# =============================================================================
# Summary
# =============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  ✅ Build Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  📁 Bundle:      $archivePath" -ForegroundColor White
Write-Host "  📊 Size:        $([math]::Round((Get-Item $archivePath).Length / 1MB, 2)) MB" -ForegroundColor White
Write-Host "  🏗️  Architecture: $Architecture" -ForegroundColor White

if (Test-Path "$BundleDir\share\nsis\Plugins") {
    $pluginCount = (Get-ChildItem "$BundleDir\share\nsis\Plugins" -Filter "*.dll" -Recurse).Count
    Write-Host "  🔌 Plugins:     $pluginCount DLLs" -ForegroundColor White
}

Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "📋 Bundle structure:" -ForegroundColor Cyan
Write-Host "   windows/$Architecture/makensis.exe" -ForegroundColor Gray
Write-Host "   windows/$Architecture/VERSION.txt" -ForegroundColor Gray
Write-Host "   share/nsis/" -ForegroundColor Gray
Write-Host ""