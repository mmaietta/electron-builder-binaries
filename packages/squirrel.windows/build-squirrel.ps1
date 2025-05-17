param (
    [string]$SquirrelVersion = "2.0.1",
    [string]$PatchPath = ""
)
$ErrorActionPreference = "Stop"

# --- Setup paths
$repoRoot = "C:\s\Squirrel.Windows"
# $nugetExe = "$repoRoot\.nuget\NuGet.exe"
$buildScript = Join-Path $repoRoot "devbuild.cmd"

# --- Clone source
git clone --recursive --branch $SquirrelVersion https://github.com/Squirrel/Squirrel.Windows $repoRoot
Set-Location $repoRoot

# --- Optional patch
if ($PatchPath -and (Test-Path $PatchPath)) {
    git apply $PatchPath
}

# Run the devbuild.cmd script
Push-Location $repoRoot
try {
    & $buildScript
    if ($LASTEXITCODE -ne 0) {
        throw "devbuild.cmd failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

# Locate the Release output folder
$releaseDir = Join-Path $repoRoot "src\Squirrel\bin\Release"

# Verify the build output exists
if (-not (Test-Path $releaseDir)) {
    throw "Release directory not found: $releaseDir"
}

# Create output directory if needed
$outputDir = "$PSScriptRoot\out\squirrel.windows"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force
}

# Compress all Release artifacts from bin folders
$zipPath = "$outputDir\squirrel.windows.$SquirrelVersion.zip"
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}
Write-Host "Compressing Release artifacts to $zipPath..."
$releasePaths = Get-ChildItem -Recurse -Path "$repoRoot\src" -Filter Release | Where-Object { $_.PSIsContainer } | ForEach-Object { "$($_.FullName)\*" }

& 7z a -mx=9 -mfb=64 $zipPath $releasePaths

exit 0

# --- Force retarget to .NET Framework 4.5.2 and PlatformToolset v143
Write-Host "Retargeting project and solution files..."
Get-ChildItem $repoRoot -Recurse -Include *.csproj,*.vcxproj -File | ForEach-Object {
    (Get-Content $_.FullName -Raw) `
        -replace 'v4\.5(\.[0-9]*)*?', 'v4.5.2' `
        -replace 'PlatformToolset>v141<', 'PlatformToolset>v143<' |
        Set-Content $_.FullName -Encoding UTF8
}
(Get-Content "$repoRoot\Squirrel.sln" -Raw) `
    -replace 'v4\.5(\.[0-9]*)*?', 'v4.5.2' |
    Set-Content "$repoRoot\Squirrel.sln" -Encoding UTF8

Write-Host "Retargeting all project files to .NET Framework 4.5.2..."

# Handle SDK-style and legacy projects
Get-ChildItem $repoRoot -Recurse -Include *.csproj -File | ForEach-Object {
    $file = $_.FullName
    $content = Get-Content $file
    $originalContent = $content

    try {
        [xml]$projXml = Get-Content $file
        $changed = $false

        # Legacy style: <TargetFrameworkVersion>v4.5</TargetFrameworkVersion>
        $projXml.Project.PropertyGroup | ForEach-Object {
            if ($_.TargetFrameworkVersion -and $_.TargetFrameworkVersion -ne "v4.5.2") {
                $_.TargetFrameworkVersion = "v4.5.2"
                $changed = $true
            }
        }

        if ($changed) {
            $projXml.Save($file)
            Write-Host "Updated TargetFrameworkVersion: $file"
        }
    } catch {
        # SDK-style fallback: <TargetFramework>net45</TargetFramework>
        if ($content -match '<TargetFramework>net45</TargetFramework>') {
            $content = $content -replace '<TargetFramework>net45</TargetFramework>', '<TargetFramework>net452</TargetFramework>'
            Set-Content $file -Value $content
            Write-Host "Updated TargetFramework: $file"
        }
    }
}

Write-Host "Applying text-based fallback retargeting for net45 → net452..."

Get-ChildItem $repoRoot -Recurse -Include *.csproj -File | ForEach-Object {
    $filePath = $_.FullName
    $text = Get-Content $filePath -Raw
    if ($text -match '(<TargetFramework.*?>)net45(</TargetFramework>)') {
        Write-Host "Patching: $filePath"
        $text = $text -replace '(<TargetFramework.*?>)net45(</TargetFramework>)', '${1}net452${2}'
        Set-Content -Path $filePath -Value $text
    }
}

# --- Add missing package references (WCF Data Services)
Write-Host "Injecting missing package references..."
Get-ChildItem $repoRoot -Recurse -Include *.csproj -File | ForEach-Object {
    $file = $_.FullName
    $xml = [xml](Get-Content $file)
    $ns = @{ msb='http://schemas.microsoft.com/developer/msbuild/2003' }
    $hasRef = $xml.Project.ItemGroup.PackageReference | Where-Object { $_.Include -eq 'Microsoft.Data.Services.Client' }
    if (-not $hasRef) {
        $itemGroup = $xml.CreateElement("ItemGroup", $xml.Project.NamespaceURI)
        $pkg = $xml.CreateElement("PackageReference", $xml.Project.NamespaceURI)
        $pkg.SetAttribute("Include", "Microsoft.Data.Services.Client")
        $pkg.SetAttribute("Version", "5.8.4")
        $itemGroup.AppendChild($pkg) | Out-Null
        $xml.Project.AppendChild($itemGroup) | Out-Null
        $xml.Save($file)
    }
}

# --- Install .NET Framework Developer Pack
Write-Host "Installing .NET Framework 4.5.2 Developer Pack..."
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=397673&clcid=0x409" -OutFile "NDP452-DevPack.exe"
Start-Process -FilePath .\NDP452-DevPack.exe -ArgumentList "/quiet", "/norestart" -Wait
Remove-Item -Path .\NDP452-DevPack.exe

# --- Restore NuGet packages
Write-Host "Restoring NuGet packages..."
& $nugetExe restore "$repoRoot\Squirrel.sln"
Get-ChildItem $repoRoot -Recurse -Include *.csproj -File | ForEach-Object {
    & $nugetExe restore $_.FullName
}

# --- Build
Write-Host "Building with MSBuild..."
$msbuild = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe"
& "$msbuild" "$repoRoot\Squirrel.sln" /p:Configuration=Release /p:PlatformToolset=v143 /m /p:TreatWarningsAsErrors=false
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
Write-Host "✅ Build succeeded."

# Create output directory if needed
$outputDir = "$PSScriptRoot\out\squirrel.windows"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force
}

# Compress all Release artifacts from bin folders
$zipPath = "$outputDir\squirrel.windows.$SquirrelVersion.zip"
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}
Write-Host "Compressing Release artifacts to $zipPath..."
$releasePaths = Get-ChildItem -Recurse -Path "$repoRoot\src" -Filter Release | Where-Object { $_.PSIsContainer } | ForEach-Object { "$($_.FullName)\*" }

& 7z a $zipPath $releasePaths