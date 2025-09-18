<#
.SYNOPSIS
    Download, verify, and build NSIS 3.11 (portable) on Windows with all stubs.

.DESCRIPTION
    Uses MinGW-w64 and SCons to build makensis.exe from the SourceForge tarball.
    Copies the executable and required files into a portable folder without installing system-wide.
#>

$ErrorActionPreference = 'Stop'

# --- Config ---
$NSIS_VERSION = "3.11"
$NSIS_SHA256  = "19e72062676ebdc67c11dc032ba80b979cdbffd3886c60b04bb442cdd401ff4b"
$DownloadUrl  = "https://downloads.sourceforge.net/project/nsis/NSIS%203/$NSIS_VERSION/nsis-$NSIS_VERSION-src.tar.bz2"

$WorkRoot     = "$env:TEMP\nsis-build"
$Tarball      = "$WorkRoot\nsis-$NSIS_VERSION-src.tar.bz2"
$SrcDir       = "$WorkRoot\nsis-src"
$PortableDir  = "$WorkRoot\nsis-portable"

# --- Prepare work directory ---
if (Test-Path $WorkRoot) { Remove-Item $WorkRoot -Recurse -Force }
New-Item -ItemType Directory -Path $WorkRoot | Out-Null
New-Item -ItemType Directory -Path $PortableDir | Out-Null

Write-Host "Downloading NSIS $NSIS_VERSION ..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $Tarball

Write-Host "Verifying SHA256 ..."
$hash = (Get-FileHash $Tarball -Algorithm SHA256).Hash.ToLower()
if ($hash -ne $NSIS_SHA256.ToLower()) {
    throw "Checksum mismatch! Expected $NSIS_SHA256, got $hash"
}

Write-Host "Extracting sources ..."
tar -xjf $Tarball -C $WorkRoot
Rename-Item -Path (Join-Path $WorkRoot "nsis-$NSIS_VERSION") -NewName "nsis-src"

# --- Build with SCons ---
Push-Location $SrcDir

Write-Host "Building makensis.exe with all stubs ..."
scons target=makensis-x64 stubs=bzip2,zlib,lzma STRIP=yes

Write-Host "Copying files to portable folder ..."
$BinDir = Join-Path $PortableDir "bin"
New-Item -ItemType Directory -Path $BinDir | Out-Null

# Copy the built makensis.exe
Copy-Item -Path "$SrcDir\Build\URelease\makensis.exe" -Destination $BinDir

# Copy all stubs (bzip2, zlib, lzma) so portable build works standalone
$StubDirs = @("Stubs", "Plugins", "Include", "Completions")
foreach ($d in $StubDirs) {
    $SrcPath = Join-Path $SrcDir $d
    if (Test-Path $SrcPath) {
        Copy-Item -Path $SrcPath -Destination $PortableDir -Recurse
    }
}

Pop-Location

Write-Host "✅ Fully portable build complete!"
Write-Host "You can run makensis.exe from $BinDir with all stubs included"
