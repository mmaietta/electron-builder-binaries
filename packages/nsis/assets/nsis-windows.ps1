<#
.SYNOPSIS
    GitHub Actions-compatible script to compile NSIS with STRLEN=8192 and logging, then package it portably.
#>

$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# 1. Setup: Install Python & SCons
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python not found. Please ensure Python 3.x is preinstalled in the runner."
}

Write-Host "📦 Installing SCons..."
python -m pip install --upgrade pip
python -m pip install scons

# 2. Paths
$repoUrl     = "https://github.com/kichik/nsis.git"
$tag         = "v3.11"
$workDir     = "$PSScriptRoot\nsis-src"
$buildDir    = "$workDir\Build\urelease"
$packageRoot = "$PSScriptRoot\vendor"
$outputZip   = "$PSScriptRoot\nsis-3.11-strlen_8192-log.zip"

# 3. Cleanup old builds
Remove-Item $workDir,$packageRoot,$outputZip -Recurse -Force -ErrorAction SilentlyContinue

# 4. Clone NSIS repo
git clone $repoUrl $workDir
cd $workDir
git checkout $tag

# 5. Patch config.h
$config = "$workDir\Source\exehead\config.h"
(Get-Content $config) | ForEach-Object {
    if ($_ -match '#define NSIS_MAX_STRLEN') {
        '#define NSIS_MAX_STRLEN 8192'
    } elseif ($_ -match '#define NSIS_CONFIG_LOG') {
        '#define NSIS_CONFIG_LOG'
    } elseif ($_ -match '#define NSIS_SUPPORT_LOG') {
        '#define NSIS_SUPPORT_LOG'
    } elseif ($_ -match '^//\s*#define NSIS_(CONFIG|SUPPORT)_LOG') {
        $_.Replace('//', '')
    } else {
        $_
    }
} | Set-Content $config

# Add logging defs if missing
if (-not (Select-String -Path $config -Pattern 'NSIS_CONFIG_LOG')) {
    Add-Content $config "`n#define NSIS_CONFIG_LOG"
}
if (-not (Select-String -Path $config -Pattern 'NSIS_SUPPORT_LOG')) {
    Add-Content $config "`n#define NSIS_SUPPORT_LOG"
}

# 6. Build with SCons
Write-Host "🔧 Building makensis.exe with STRLEN=8192 and logging..."
scons SKIPPLUGINS=0 NSIS_MAX_STRLEN=8192 NSIS_CONFIG_LOG=yes

if (!(Test-Path "$buildDir\makensis.exe")) {
    throw "❌ Build failed: makensis.exe not found."
}

# 7. Create portable layout
Write-Host "📂 Assembling portable NSIS structure..."
$layout = @{
    "Bin"            = @("makensis.exe", "zlib1.dll")
    "Contrib"        = @("Contrib\*")
    "Include"        = @("Include\*")
    "Plugins"        = @("Plugins\*")
    "Stubs"          = @("Stubs\*")
    "Menu"           = @("Menu\*")
    "Modern UI"      = @("Contrib\Modern UI\*")
    "Modern UI 2"    = @("Contrib\Modern UI 2\*")
    "UIs"            = @("Contrib\UIs\*")
    "zip2exe"        = @("Contrib\zip2exe\*")
    "Language files" = @("Contrib\Language files\*")
}

foreach ($folder in $layout.Keys) {
    $target = Join-Path $packageRoot $folder
    $sources = $layout[$folder]
    foreach ($src in $sources) {
        $sourcePath = Join-Path $workDir $src
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Copy-Item $sourcePath -Destination $target -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 8. Copy binaries
Copy-Item "$buildDir\makensis.exe" "$packageRoot\Bin\" -Force
Copy-Item "$buildDir\NSIS.exe" "$packageRoot\" -Force -ErrorAction SilentlyContinue
Copy-Item "$buildDir\elevate.exe" "$packageRoot\" -Force -ErrorAction SilentlyContinue
Copy-Item "$buildDir\zlib1.dll" "$packageRoot\Bin\" -Force -ErrorAction SilentlyContinue
Copy-Item "$workDir\COPYING","$workDir\nsisconf.nsh" -Destination $packageRoot -Force -ErrorAction SilentlyContinue

# 9. Zip final output
Compress-Archive -Path $packageRoot -DestinationPath $outputZip -Force

Write-Host "`n✅ Done! NSIS portable package created: $outputZip"
