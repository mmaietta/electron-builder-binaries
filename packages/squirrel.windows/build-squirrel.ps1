# Parameters
param(
    [string]$SquirrelVersion = "2.0.1",
    [string]$PatchPath = ""
)

# Paths
$repoRoot = "C:\s\Squirrel.Windows"
$nugetPath = "$repoRoot\vendor\nuget\src\Core"
$msbuild = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe"
$nugetExe = "$repoRoot\.nuget\NuGet.exe"

# Clone Squirrel.Windows repo
git clone --recursive --single-branch --depth 1 --branch $SquirrelVersion https://github.com/Squirrel/Squirrel.Windows $repoRoot
Set-Location $repoRoot

# Apply patch if present
if ($PatchPath -and (Test-Path $PatchPath)) {
    Write-Host "Applying patch..."
    git apply $PatchPath
}

# Retarget project files (.csproj and .vcxproj)
Write-Host "Retargeting project files to .NET 4.5.2 and platform toolset v143..."
Get-ChildItem -Recurse -Include *.csproj,*.vcxproj | ForEach-Object {
    (Get-Content $_.FullName -Raw) `
        -replace 'v4\.5(\.[0-9]*)?', 'v4.5.2' `
        -replace '<PlatformToolset>v141</PlatformToolset>', '<PlatformToolset>v143</PlatformToolset>' |
        Set-Content $_.FullName -Encoding UTF8
}

# Retarget .sln file
Write-Host "Retargeting solution file..."
(Get-Content .\Squirrel.sln -Raw) `
    -replace 'v4\.5(\.[0-9]*)?', 'v4.5.2' |
    Set-Content .\Squirrel.sln -Encoding UTF8

# Install .NET Framework 4.5.2 Developer Pack
Write-Host "Installing .NET Framework 4.5.2 Developer Pack..."
$devPackUrl = "https://go.microsoft.com/fwlink/?linkid=397673&clcid=0x409"
Invoke-WebRequest -Uri $devPackUrl -OutFile "NDP452-DevPack.exe"
Start-Process -FilePath ".\NDP452-DevPack.exe" -ArgumentList "/quiet", "/norestart" -Wait
Remove-Item -Force .\NDP452-DevPack.exe

# Restore NuGet packages
Write-Host "Restoring NuGet packages..."
& $nugetExe restore Squirrel.sln
# if ($LASTEXITCODE -ne 0) {
#     Write-Host "NuGet restore failed with exit code $LASTEXITCODE"
#     exit $LASTEXITCODE
# }

# Build solution
Write-Host "Building solution..."
& $msbuild Squirrel.sln /p:Configuration=Release /m
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "✅ Build completed successfully!"
