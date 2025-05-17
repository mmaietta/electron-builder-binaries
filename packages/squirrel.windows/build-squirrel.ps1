param (
    [string]$SquirrelVersion = "2.0.1",
    [string]$PatchPath = ""
)

# --- Setup paths
$repoRoot = "C:\s\Squirrel.Windows"
$nugetExe = "$repoRoot\.nuget\NuGet.exe"

# --- Clone source
git clone --recursive --single-branch --depth 1 --branch $SquirrelVersion https://github.com/Squirrel/Squirrel.Windows $repoRoot
Set-Location $repoRoot

# --- Optional patch
if ($PatchPath -and (Test-Path $PatchPath)) {
    git apply $PatchPath
}

# --- Force retarget to .NET Framework 4.5.2 and PlatformToolset v143
Write-Host "Retargeting project and solution files..."
Get-ChildItem $repoRoot -Recurse -Include *.csproj,*.vcxproj -File | ForEach-Object {
    (Get-Content $_.FullName -Raw) `
        -replace 'v4\.5(\.[0-9]*)?', 'v4.5.2' `
        -replace 'PlatformToolset>v141<', 'PlatformToolset>v143<' |
        Set-Content $_.FullName -Encoding UTF8
}
(Get-Content "$repoRoot\Squirrel.sln" -Raw) `
    -replace 'v4\.5(\.[0-9]*)?', 'v4.5.2' |
    Set-Content "$repoRoot\Squirrel.sln" -Encoding UTF8

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
& "$msbuild" "$repoRoot\Squirrel.sln" /p:Configuration=Release /p:PlatformToolset=v143 /m
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
Write-Host "✅ Build succeeded."
