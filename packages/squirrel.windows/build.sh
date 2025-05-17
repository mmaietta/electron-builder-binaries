#!/usr/bin/env bash
set -ex

VERSION=2.0.1

BASE_DIR=$(cd "$(dirname "$BASH_SOURCE")" && pwd)

REPO_URL="https://github.com/Squirrel/Squirrel.Windows"
NUGET_EXE="https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"

export DOTNET_NOLOGO=true
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true
export DOTNET_CLI_TELEMETRY_OPTOUT=true
export NUGET_XMLDOC_MODE=skip

BASEDIR=$(cd "$(dirname "$0")" && pwd)

OUT_DIR=$BASEDIR/out/squirrel.windows
rm -rf $OUT_DIR
mkdir -p $OUT_DIR

TMP_DIR=/tmp/squirrel
rm -rf $TMP_DIR
mkdir $TMP_DIR
cd $TMP_DIR

git clone --single-branch --depth 1 --branch $VERSION --recursive https://github.com/squirrel/squirrel.windows

SRC_DIR=$TMP_DIR/squirrel.windows
cd $SRC_DIR
cp -a $BASEDIR/patches/* $SRC_DIR
git apply $SRC_DIR/*.patch

# echo "Downloading NuGet..."
# curl -L -o nuget.exe "$NUGET_EXE"

# Retarget .csproj to .NET Framework 4.5.2
find . -name '*.csproj' -exec sed -i 's|<TargetFrameworkVersion>v4.5</TargetFrameworkVersion>|<TargetFrameworkVersion>v4.5.2</TargetFrameworkVersion>|g' {} +

# Retarget .vcxproj to PlatformToolset v143
find . -name '*.vcxproj' -exec sed -i 's|<PlatformToolset>v141</PlatformToolset>|<PlatformToolset>v143</PlatformToolset>|g' {} +

# Restore and build
MSBUILD="/c/Program Files/Microsoft Visual Studio/2022/Enterprise/MSBuild/Current/Bin/MSBuild.exe"
if [ ! -f "$MSBUILD" ]; then
  MSBUILD="/c/Program Files/Microsoft Visual Studio/2022/Community/MSBuild/Current/Bin/MSBuild.exe"
fi

"$MSBUILD" Squirrel.sln /target:Restore /property:Configuration=Release
"$MSBUILD" Squirrel.sln /property:Configuration=Release /maxcpucount

# ./.nuget/NuGet.exe restore
# msbuild /p:Configuration=Release

echo $VERSION > $TMP_DIR/VERSION.txt

DESTINATION="$OUT_DIR/squirrel.windows-$VERSION-patched.7z"
7za a -mx=9 -mfb=64 "$DESTINATION" "$TMP_DIR"/*
