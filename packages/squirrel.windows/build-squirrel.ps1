param (
  [string]$SquirrelVersion = "develop",
  [string]$PatchPath = ""
)

$ErrorActionPreference = "Stop"

# Paths
$repoRoot = "C:\s\Squirrel.Windows"
$nugetPath = "$repoRoot\vendor\nuget\src\Core"

# Clone branch
git clone --recursive --single-branch --depth 1 --branch $SquirrelVersion https://github.com/Squirrel/Squirrel.Windows $repoRoot

# Optional: Apply patch
if ($PatchPath -and (Test-Path $PatchPath)) {
  git -C $repoRoot apply $PatchPath
}

# Install .NET 4.5.2 Developer Pack
# Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=397673&clcid=0x409" -OutFile "NDP452-DevPack.exe"
# Start-Process -FilePath .\NDP452-DevPack.exe -ArgumentList "/quiet", "/norestart" -Wait
# Remove-Item -Path .\NDP452-DevPack.exe

# Retarget project files
Write-Host "Retargeting .csproj and .vcxproj files..."
Get-ChildItem -Recurse -Include *.csproj,*.vcxproj | ForEach-Object {
    (Get-Content $_.FullName) `
        -replace 'v4\.5(\.[0-9]*)?', 'v4.5.2' `
        -replace 'PlatformToolset>v141<', 'PlatformToolset>v143<' |
        Set-Content $_.FullName
}

# Retarget solution file
Write-Host "Retargeting .sln file..."
(Get-Content "$repoRoo\Squirrel.sln") `
    -replace 'v4\.5(\.[0-9]*)?', 'v4.5.2' |
    Set-Content "$repoRoo\Squirrel.sln"

# # Ensure NuGet is available
$nugetExe = "$repoRoot\.nuget\NuGet.exe"
# if (-not (Test-Path $nugetExe)) {
#   Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile $nugetExe
# }

# # Restore & add dependencies for vendored NuGet
# cd $nugetPath
# & $nugetExe install System.Data.Services.Client -Version 5.6.4 -OutputDirectory packages
# & $nugetExe install System.Spatial -Version 5.6.4 -OutputDirectory packages

# $coreProj = "$nugetPath\Core.csproj"
# $content = Get-Content $coreProj
# if (-not ($content -match "System.Data.Services.Client")) {
#   $ref = @'
#   <ItemGroup>
#     <Reference Include="System.Data.Services.Client">
#       <HintPath>packages\System.Data.Services.Client.5.6.4\lib\net45\System.Data.Services.Client.dll</HintPath>
#     </Reference>
#     <Reference Include="System.Spatial">
#       <HintPath>packages\System.Spatial.5.6.4\lib\net45\System.Spatial.dll</HintPath>
#     </Reference>
#   </ItemGroup>
# '@
#   $inserted = $false
#   $out = foreach ($line in $content) {
#     if (-not $inserted -and $line -match "<ItemGroup>") {
#       $inserted = $true
#       $line
#       $ref
#     } else {
#       $line
#     }
#   }
#   Set-Content $coreProj $out
# }

# Restore packages
Write-Host "Restoring NuGet packages..."
"$nugetExe" restore "$repoRoo\Squirrel.sln"

# Build the solution
Write-Host "Building..."
$msbuild = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe"
& "$msbuild" "$repoRoo\Squirrel.sln" /p:Configuration=Release /m

Write-Host "✅ Build completed successfully."