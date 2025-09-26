<#
.SYNOPSIS
  Builds a fully portable NSIS (makensis.exe) with static zlib, bzip2, and lzma
  on a Windows ARM64 VM (cross-compiling x64). Uses pinned release versions,
  custom SCons build flags, live build logging, and outputs a zipped portable bundle.

.REQUIREMENTS
  - Visual Studio 2022 with MSVC v143 x64 build tools
  - Python 3.x + pip
  - SCons (pip install scons)
  - CMake (>= 3.21)
  - Git
#>

$ErrorActionPreference = "Stop"

# Output + source directories
$BuildRoot   = "$PWD\out"
$InstallRoot = "$BuildRoot\install"
$ZlibSrc     = "$BuildRoot\zlib"
$Bzip2Src    = "$BuildRoot\bzip2"
$LzmaSrc     = "$BuildRoot\lzma"
$NsisSrc     = "$BuildRoot\nsis"
$PortableDir = "$BuildRoot\nsis-bundle"
$ZipFile     = "$BuildRoot\nsis-bundle-x64.zip"

# Reset build dir
if (Test-Path $BuildRoot) { Remove-Item -Recurse -Force $BuildRoot }
New-Item -ItemType Directory -Path $BuildRoot, $InstallRoot | Out-Null

# Helper: clone with error handling
function Clone-Repo {
    param (
        [string]$RepoUrl,
        [string]$Tag,
        [string]$Dest
    )
    Write-Host ">>> Cloning $RepoUrl @ $Tag"
    git clone --branch $Tag --single-branch --depth=1 $RepoUrl $Dest
    if ($LASTEXITCODE -ne 0) {
        throw "ERROR: git clone failed for $RepoUrl ($Tag)"
    }
}

Write-Host "=== Cloning pinned versions (shallow) ==="

Clone-Repo "https://github.com/madler/zlib.git"   "v1.3.1"     $ZlibSrc
Clone-Repo "https://sourceware.org/git/bzip2.git" "bzip2-1.0.8" $Bzip2Src
Clone-Repo "https://git.tukaani.org/xz.git"       "v5.6.2"     $LzmaSrc
Clone-Repo "https://github.com/kichik/nsis.git"   "v311"      $NsisSrc

Write-Host "=== Locating Visual Studio environment ==="
$VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$VsPath  = & $VsWhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
$VcVars  = Join-Path $VsPath "VC\Auxiliary\Build\vcvarsall.bat"

# Improved runner: live output, logs errors
function Invoke-WithVCEnv {
    param (
        [string]$Arch,
        [string[]]$Commands
    )

    $tmpBat = [System.IO.Path]::GetTempFileName() + ".bat"
    Set-Content $tmpBat "@echo off"
    Add-Content $tmpBat "call `"$VcVars`" $Arch"
    foreach ($cmd in $Commands) {
        Add-Content $tmpBat $cmd
    }

    Write-Host ">>> Running in VC env ($Arch):"
    foreach ($cmd in $Commands) { Write-Host "    $cmd" }

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "cmd.exe"
    $processInfo.Arguments = "/c `"$tmpBat`""
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError  = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $processInfo

    $stdErr = New-Object System.Text.StringBuilder

    # Start process *before* hooking events
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()

    Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
        if ($EventArgs.Data) { Write-Host $EventArgs.Data }
    } | Out-Null

    Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
        if ($EventArgs.Data) { Write-Host $EventArgs.Data -ForegroundColor Red; $stdErr.AppendLine($EventArgs.Data) | Out-Null }
    } | Out-Null

    $process.WaitForExit()
    $exitCode = $process.ExitCode
    Remove-Item $tmpBat -Force

    if ($exitCode -ne 0) {
        throw "ERROR in vcvarsall ($Arch)`nCommands:`n$($Commands -join "`n")`nExitCode: $exitCode`nStderr:`n$stdErr"
    }
}

### Build bzip2 (no CMake, use nmake)
Write-Host "=== Building bzip2 (x86, static, using nmake) ==="
Invoke-WithVCEnv -Arch "x86" -Commands @(
    "cd /d `"$Bzip2Src`"",
    "nmake -f makefile.msc clean",
    "nmake -f makefile.msc",
    "mkdir `"$InstallRoot\bzip2\lib`"",
    "mkdir `"$InstallRoot\bzip2\include`"",
    "copy bzip2.lib `"$InstallRoot\bzip2\lib\`"",
    "copy bzlib.h `"$InstallRoot\bzip2\include\`""
)

### Build lzma/xz
Write-Host "=== Building lzma (xz, x86, static) ==="
Invoke-WithVCEnv -Arch "x86" -Commands @(
    "cd /d `"$LzmaSrc`"",
    "mkdir build",
    "cd build",
    "cmake .. -A Win32 -DCMAKE_INSTALL_PREFIX=`"$InstallRoot\lzma`" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF",
    "cmake --build . --config Release --target INSTALL"
)


### Build zlib
Write-Host "=== Building zlib (x86, static) ==="
Invoke-WithVCEnv -Arch "x86" -Commands @(
    "cd /d `"$ZlibSrc`"",
    "mkdir build",
    "cd build",
    "cmake .. -A Win32 -DCMAKE_INSTALL_PREFIX=`"$InstallRoot\zlib`" -DBUILD_SHARED_LIBS=OFF",
    "cmake --build . --config Release --target INSTALL"
)
# Adjust zlib naming so NSIS detects it
$zlibLib = Join-Path "$InstallRoot\zlib\lib" "zlib.lib"
$zlibDll = Join-Path "$InstallRoot\zlib\bin" "zlib.dll"

if (Test-Path $zlibLib) {
    Rename-Item $zlibLib (Join-Path "$InstallRoot\zlib\lib" "zdll.lib") -Force
}

if (Test-Path $zlibDll) {
    Rename-Item $zlibDll (Join-Path "$InstallRoot\zlib\bin" "zlib1.dll") -Force
}

### Build NSIS with all libs + custom flags
Write-Host "=== Building NSIS with SCons (x64, static linking, custom flags) ==="
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

### Create portable bundle
Write-Host "=== Assembling portable NSIS bundle ==="
if (Test-Path $PortableDir) { Remove-Item -Recurse -Force $PortableDir }
New-Item -ItemType Directory -Path $PortableDir | Out-Null
Copy-Item -Recurse "$NsisSrc\build\urelease\*" $PortableDir

### Zip it
if (Test-Path $ZipFile) { Remove-Item -Force $ZipFile }
Compress-Archive -Path "$PortableDir\*" -DestinationPath $ZipFile

Write-Host "=== DONE! Portable NSIS bundle ready at: $PortableDir ==="
Write-Host "=== Zipped bundle: $ZipFile ==="
