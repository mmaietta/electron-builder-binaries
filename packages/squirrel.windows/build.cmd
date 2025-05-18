@echo off
setlocal enabledelayedexpansion

:: === Config ===
set "SQUIRREL_VERSION=2.0.1"
set "PATCH_PATH="
set "REPO_ROOT=C:\s\Squirrel.Windows"
set "ARTIFACT_DIR=%~dp0out\squirrel.windows"

:: === Clone source ===
echo.
echo 📥 Cloning Squirrel.Windows...
if exist "%REPO_ROOT%" rd /s /q "%REPO_ROOT%"
git clone --recursive https://github.com/Squirrel/Squirrel.Windows "%REPO_ROOT%" || exit /b 1
cd /d "%REPO_ROOT%"
git checkout %SQUIRREL_VERSION% || exit /b 1
git submodule update --init --recursive || exit /b 1

:: === Optional patch ===
if defined PATCH_PATH (
    if exist "%PATCH_PATH%" (
        echo.
        echo 🔧 Applying patch: %PATCH_PATH%
        git apply "%PATCH_PATH%" || exit /b 1
    )
)

:: === Run the official build ===
echo.
echo 🏗️ Running build_official.cmd...
cd /d "%REPO_ROOT%"

nuget restore .\Squirrel.sln || exit /b

msbuild -Restore .\Squirrel.sln -p:Configuration=Release -v:m -m -nr:false -bl:.\build\logs\build.binlog || exit /b

nuget pack Squirrel.nuspec -OutputDirectory ..\build\artifacts || exit /b


:: Layout electron-winstaller
::
:: The NPM package electron-winstaller allows developers to
:: build Windows installers for Electron apps using Squirrel
:: (https://github.com/electron/windows-installer)
::
:: The following copies the required files into a single folder
:: which can then be copied to the electron-winstaller/vendor folder
:: (either manually or in an automated way).

md ..\build\artifacts\electron-winstaller\vendor

copy ..\build\Release\net45\Update.exe ..\build\artifacts\electron-winstaller\vendor\Squirrel.exe || exit /b
copy ..\build\Release\net45\update.com ..\build\artifacts\electron-winstaller\vendor\Squirrel.com || exit /b
copy ..\build\Release\net45\Update.pdb ..\build\artifacts\electron-winstaller\vendor\Squirrel.pdb || exit /b
copy ..\build\Release\Win32\Setup.exe ..\build\artifacts\electron-winstaller\vendor || exit /b
copy ..\build\Release\Win32\Setup.pdb ..\build\artifacts\electron-winstaller\vendor || exit /b
copy ..\build\Release\net45\Update-Mono.exe ..\build\artifacts\electron-winstaller\vendor\Squirrel-Mono.exe || exit /b
copy ..\build\Release\net45\Update-Mono.pdb ..\build\artifacts\electron-winstaller\vendor\Squirrel-Mono.pdb || exit /b
copy ..\build\Release\Win32\StubExecutable.exe ..\build\artifacts\electron-winstaller\vendor || exit /b
copy ..\build\Release\net45\SyncReleases.exe ..\build\artifacts\electron-winstaller\vendor || exit /b
copy ..\build\Release\net45\SyncReleases.pdb ..\build\artifacts\electron-winstaller\vendor || exit /b
copy ..\build\Release\Win32\WriteZipToSetup.exe ..\build\artifacts\electron-winstaller\vendor || exit /b
copy ..\build\Release\Win32\WriteZipToSetup.pdb ..\build\artifacts\electron-winstaller\vendor || exit /b

echo.
echo ✅ Build completed successfully!

:: === Ensure output directory exists ===
if not exist "%ARTIFACT_DIR%" (
    mkdir "%ARTIFACT_DIR%"
)

:: === Compress the output ===
set "OUTPUT_DIR=%REPO_ROOT%\build\artifacts"
set "ARCHIVE_PATH=%ARTIFACT_DIR%\squirrel.windows-%SQUIRREL_VERSION%.7z"

if exist "%ARCHIVE_PATH%" (
    del /f /q "%ARCHIVE_PATH%"
)

echo.
echo 📦 Compressing to: %ARCHIVE_PATH%
7z a -t7z -mx=9 "%ARCHIVE_PATH%" "%OUTPUT_DIR%\*" >nul

if errorlevel 1 (
    echo ❌ Compression failed
    exit /b %errorlevel%
)

echo.
echo ✅ Done!
echo 🗂️ Archive located at: %ARCHIVE_PATH%

for %%F in ("%ARCHIVE_PATH%") do (
    echo 📦 Archive size: %%~zF bytes
)

endlocal
