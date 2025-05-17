param (
    [string]$SquirrelVersion = "2.0.1",
    [string]$PatchPath = ""
)
$ErrorActionPreference = "Stop"

$repoRoot = "C:\s\Squirrel.Windows"
$buildScript = Join-Path $repoRoot "devbuild.cmd"

# --- Clone source
git clone --recursive --branch $SquirrelVersion https://github.com/Squirrel/Squirrel.Windows $repoRoot
Set-Location $repoRoot

# --- Optional patch
if ($PatchPath -and (Test-Path $PatchPath)) {
    git apply $PatchPath
}

# Run the devbuild.cmd script (new build script post 2.0.1)
Push-Location $repoRoot
try {
    & $buildScript release
    if ($LASTEXITCODE -ne 0) {
        throw "devbuild.cmd failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

# Check if the release directory exists, and output the correct directory
$releaseDirs = Get-ChildItem -Path $repoRoot -Recurse -Directory | Where-Object { $_.Name -eq "Release" }

if ($releaseDirs.Count -eq 0) {
    throw "No 'Release' directory found in build output."
}

# Assuming you know the right Release directory structure now
$releaseDir = $releaseDirs[0].FullName

Write-Host "Found Release directory: $releaseDir"

# Create output directory if needed
$outputDir = "$PSScriptRoot\out\squirrel.windows"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force
}

# Compress all Release artifacts from bin folders
$zipPath = "$outputDir\squirrel.windows-$SquirrelVersion.zip"
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}

Write-Host "Compressing Release artifacts to $zipPath..."

& 7z a -t7z -mx=9 $zipPath "$releaseDir\*" | Out-Null
