param (
    [string]$SquirrelVersion = "develop",
    [string]$PatchPath = ""
)
$ErrorActionPreference = "Stop"

$repoRoot = "C:\s\Squirrel.Windows"
$buildScript = Join-Path $repoRoot "devbuild.cmd"

# --- Clone source
git clone --recursive https://github.com/Squirrel/Squirrel.Windows $repoRoot
Set-Location $repoRoot
git checkout $SquirrelVersion
git submodule update --init --recursive

# --- Optional patch
if ($PatchPath -and (Test-Path $PatchPath)) {
    Write-Host "`n🔧 Applying patch: $PatchPath"
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
Write-Host "`n✅ Build completed successfully!"

# --- Compress the output
$outputDir = Join-Path $repoRoot "build/artifacts/"
$archivePath = Join-Path $artifactDir "Squirrel.Windows-$SquirrelVersion.7z"
if (Test-Path $archivePath) {
    Remove-Item $archivePath -Force
}

Write-Host "`n📦 Compressing to: $archivePath"
& 7z a -t7z -mx=9 $archivePath $outputDir | Out-Null

Write-Host "`n✅ Done!"
Write-Host "🗂️ Archive located at: $archivePath"
Write-Host "📦 Archive size: $(Get-Item $archivePath).Length bytes"