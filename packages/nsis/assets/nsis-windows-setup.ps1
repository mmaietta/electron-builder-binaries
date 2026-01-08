<#
.SYNOPSIS
    Installs Python (latest 3.x) and SCons on Windows for building NSIS.

.NOTES
    Run this before running build-nsis.ps1
#>

param(
    [string]$PythonVersion = "3.12"   # You can pin a major.minor if you want
)

$ErrorActionPreference = 'Stop'

Write-Host "==> Checking for Python..."
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Python $PythonVersion via winget..."
    winget install --id Python.Python.$($PythonVersion.Replace('.','')) --source winget -e --silent
    Write-Host "Python installed."
} else {
    Write-Host "Python already installed: $(python --version)"
}

Write-Host "==> Making sure pip is present..."
python -m ensurepip --upgrade
python -m pip install --upgrade pip

Write-Host "==> Installing SCons with pip..."
python -m pip install --upgrade scons

Write-Host "==> Verifying installation..."
$pyver = python --version
$sconsver = scons --version
Write-Host "Python: $pyver"
Write-Host "SCons:  $sconsver"

Write-Host "`n✓ Python and SCons are ready!"
