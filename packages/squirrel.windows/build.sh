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

echo "Retargeting .csproj files to .NET Framework 4.5.2..."
find . -name "*.csproj" -exec sed -i 's|<TargetFrameworkVersion>v4.5|<TargetFrameworkVersion>v4.5.2|g' {} +

echo "Retargeting .vcxproj files to PlatformToolset v143..."
find . -name "*.vcxproj" -exec sed -i 's|<PlatformToolset>v141|<PlatformToolset>v143|g' {} +

# echo "Restoring NuGet packages..."
# ./nuget.exe restore Squirrel.sln
# ./.nuget/NuGet.exe restore

echo "Restoring and building solution with MSBuild..."
MSBUILD_PATH="/c/Program Files/Microsoft Visual Studio/2022/Enterprise/MSBuild/Current/Bin/MSBuild.exe"
if [ ! -f "$MSBUILD_PATH" ]; then
  MSBUILD_PATH="/c/Program Files/Microsoft Visual Studio/2022/Community/MSBuild/Current/Bin/MSBuild.exe"
fi

"$MSBUILD_PATH" Squirrel.sln /t:Restore /p:Configuration=Release
"$MSBUILD_PATH" Squirrel.sln /p:Configuration=Release /m

# ./.nuget/NuGet.exe restore
# msbuild /p:Configuration=Release

echo $VERSION > $TMP_DIR/VERSION.txt

DESTINATION="$OUT_DIR/squirrel.windows-$VERSION-patched.7z"
7za a -mx=9 -mfb=64 "$DESTINATION" "$TMP_DIR"/*
