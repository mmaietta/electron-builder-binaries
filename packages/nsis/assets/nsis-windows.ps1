<#
.SYNOPSIS
    Download, verify, extract, and build NSIS makensis.exe from source on Windows.
#>

param(
    [string]$NsisVersion = "3.11",
    [string]$Sha256      = "19e72062676ebdc67c11dc032ba80b979cdbffd3886c60b04bb442cdd401ff4b",
    [string]$OutDir      = "$PWD\nsis-src",
    [string]$BuildDir    = "$PWD\nsis-build"
)

$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------
# Build names and URLs
# ------------------------------------------------------------
$TarName = "nsis-$NsisVersion-src.tar.bz2"
$Tarball = Join-Path $OutDir $TarName
$Url     = "https://downloads.sourceforge.net/project/nsis/NSIS%203/$NsisVersion/" + $TarName + "?download"

Write-Host "`n==> Downloading NSIS $NsisVersion from $Url"

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
function Test-Bzip2Magic([string]$FilePath) {
    if (-not (Test-Path $FilePath)) { return $false }
    try {
        $fs  = [System.IO.File]::OpenRead($FilePath)
        $buf = New-Object byte[] 3
        $fs.Read($buf,0,3) | Out-Null
        $fs.Close()
        return ($buf[0] -eq 0x42 -and $buf[1] -eq 0x5A -and $buf[2] -eq 0x68) # “BZh”
    } catch { return $false }
}

# ------------------------------------------------------------
# Download with curl
# ------------------------------------------------------------
if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    throw "curl.exe not found; install or ensure it's in PATH."
}

& curl.exe -f -L -o $Tarball $Url

if (-not (Test-Bzip2Magic $Tarball)) {
    throw "Downloaded file is not a valid bzip2 archive (magic bytes failed)."
}

# ------------------------------------------------------------
# Verify SHA256
# ------------------------------------------------------------
$actual = (Get-FileHash -Algorithm SHA256 $Tarball).Hash.ToLower()
if ($actual -ne $Sha256.ToLower()) {
    throw "Checksum mismatch! Expected $Sha256, got $actual"
}
Write-Host "✓ SHA256 verified"

# ------------------------------------------------------------
# Extract
# ------------------------------------------------------------
Write-Host "==> Extracting source..."
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
}
tar -xjf $Tarball -C $BuildDir --strip-components=1

# ------------------------------------------------------------
# Build makensis.exe
# ------------------------------------------------------------
Write-Host "==> Building makensis.exe with SCons"
Push-Location $BuildDir
try {
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw "Python not found in PATH." }
    if (-not (Get-Command scons  -ErrorAction SilentlyContinue)) { throw "SCons not found in PATH (pip install scons)." }

    scons -c
    scons makensis
}
finally {
    Pop-Location
}

Write-Host "`n✓ makensis.exe built successfully!"
Write-Host "Location: $BuildDir\build\urelease\makensis.exe"
