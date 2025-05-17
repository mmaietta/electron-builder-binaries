param (
  [string]$SquirrelVersion = "develop",
  [string]$PatchPath = ""
)

$ErrorActionPreference = "Stop"

# Paths
$repoRoot = "C:\s\Squirrel.Windows"
$nugetPath = "$repoRoot\vendor\nuget\src\Core"

# Clone develop branch
git clone --recursive --branch $SquirrelVersion https://github.com/Squirrel/Squirrel.Windows $repoRoot

# Optional: Apply patch
if ($PatchPath -and (Test-Path $PatchPath)) {
  git -C $repoRoot apply $PatchPath
}

# Install .NET 4.5 Developer Pack
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=397673&clcid=0x409" -OutFile "NDP45-DevPack.exe"
Start-Process -FilePath .\NDP45-DevPack.exe -ArgumentList "/quiet", "/norestart" -Wait
Remove-Item -Path .\NDP45-DevPack.exe

# Retarget .NET projects
Get-ChildItem -Recurse -Filter *.csproj -Path $repoRoot | ForEach-Object {
  (Get-Content $_.FullName) -replace 'v4\.5', 'v4.5.2' | Set-Content $_.FullName
}

# Retarget C++ toolset and Windows SDK
Get-ChildItem -Recurse -Filter *.vcxproj -Path $repoRoot | ForEach-Object {
  $file = $_.FullName
  $content = Get-Content $file
  $content = $content -replace '<PlatformToolset>v141</PlatformToolset>', '<PlatformToolset>v143</PlatformToolset>'
#   $content = $content -replace '<WindowsTargetPlatformVersion>8.1</WindowsTargetPlatformVersion>', '<WindowsTargetPlatformVersion>10.0.19041.0</WindowsTargetPlatformVersion>'
  Set-Content $file $content
}

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

# Final restore & build
cd $repoRoot
& $nugetExe restore
& "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe" .\Squirrel.sln /p:Configuration=Release
