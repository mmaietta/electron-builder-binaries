param (
    [string]$SquirrelVersion = "develop",
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

$buildScript = Join-Path $repoRoot "src\build_official.cmd"
$artifactDir = Join-Path $PSScriptRoot "out\squirrel.windows"

# --- Ensure output directory exists
if (-not (Test-Path $artifactDir)) {
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
}

# --- Run the official build
Write-Host "`n🏗️ Running build_official.cmd..."
Push-Location $repoRoot
& $buildScript
$exitCode = $LASTEXITCODE
Pop-Location

if ($exitCode -ne 0) {
    Write-Error "❌ build_official.cmd failed with exit code $exitCode"
    exit $exitCode
}

# --- Locate a Release output folder
Write-Host "`n🔍 Searching for 'Release' build output..."
$releaseDirs = Get-ChildItem -Path $repoRoot -Recurse -Directory | Where-Object { $_.Name -eq "Release" }

if ($releaseDirs.Count -eq 0) {
    Write-Error "❌ No 'Release' folder found after build."
    exit 1
}

$releaseDir = $releaseDirs[0].FullName
Write-Host "📁 Found release directory: $releaseDir"

# --- Compress the output
$archivePath = Join-Path $artifactDir "Squirrel.Windows-$SquirrelVersion.7z"
if (Test-Path $archivePath) {
    Remove-Item $archivePath -Force
}

Write-Host "`n📦 Compressing to: $archivePath"
& 7z a -t7z -mx=9 $archivePath $releaseDirs | Out-Null

Write-Host "`n✅ Done!"
Write-Host "🗂️ Archive located at: $archivePath"
Write-Host "📦 Archive size: $(Get-Item $archivePath).Length bytes"