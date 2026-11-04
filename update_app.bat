
@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Finance App ADB Updater

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "PACKAGE_NAME=com.example.financeapp"
set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"
set "DEVICE="
set /a COUNT=0

echo ========================================
echo       Finance App ADB Updater
echo ========================================
echo.

:: Check required files
if not exist "%ADB%" (
    echo ERROR: ADB not found!
    pause
    exit /b 1
)

if not exist "pubspec.yaml" (
    echo ERROR: pubspec.yaml not found!
    pause
    exit /b 1
)

if not exist "android\key.properties" (
    echo ERROR: key.properties not found!
    pause
    exit /b 1
)

if not exist "android\app\upload-keystore.jks" (
    echo ERROR: Release keystore not found!
    pause
    exit /b 1
)

echo Release signing files found.
echo.

:: Detect connected phone
echo Checking connected devices...
echo.

for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do (
    if "%%B"=="device" (
        echo %%A | findstr /i /c:"emulator-" >nul
        if errorlevel 1 (
            echo %%A | findstr /c:":" >nul
            if not errorlevel 1 (
                set "DEVICE=%%A"
                set /a COUNT+=1
            ) else (
                echo %%A | findstr /i /c:"_adb-tls-connect._tcp" >nul
                if not errorlevel 1 (
                    if not defined DEVICE (
                        set "DEVICE=%%A"
                        set /a COUNT=1
                    )
                )
            )
        )
    )
)

if !COUNT! EQU 0 (
    echo ERROR: No connected phone found.
    pause
    exit /b 1
)

if !COUNT! GTR 1 (
    echo ERROR: Multiple phones connected.
    echo Please disconnect extra phones.
    pause
    exit /b 1
)

echo Target phone: !DEVICE!
echo.


:: Increment pubspec.yaml version code
echo Updating app version...

set "NEW_VERSION="

for /f "delims=" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='pubspec.yaml'; $c=[IO.File]::ReadAllText($p); $r='(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$'; $m=[regex]::Match($c,$r); if (-not $m.Success) { throw 'Invalid version format in pubspec.yaml' }; $n=[int]$m.Groups[2].Value + 1; $new=$m.Groups[1].Value + '+' + $n; $c=[regex]::Replace($c,$r,('version: ' + $new),1); [IO.File]::WriteAllText($p,$c,(New-Object System.Text.UTF8Encoding($false))); Write-Output $new"') do (
    set "NEW_VERSION=%%A"
)

if not defined NEW_VERSION (
    echo.
    echo ERROR: Version increment failed!
    pause
    exit /b 1
)

echo New App Version: !NEW_VERSION!
echo.

:: Generate launcher icons
echo Generating latest app launcher icons...
call dart run flutter_launcher_icons

if errorlevel 1 (
    echo.
    echo ERROR: Launcher icon generation failed!
    pause
    exit /b 1
)

:: Build signed release APK
echo.
echo Building Finance App with Release Signing...
call flutter build apk --release

if errorlevel 1 (
    echo.
    echo ERROR: Build failed!
    echo Version code has already been incremented.
    pause
    exit /b 1
)

:: Verify APK exists
if not exist "%APK_PATH%" (
    echo.
    echo ERROR: APK file not found!
    pause
    exit /b 1
)

echo.
echo APK build completed successfully.
echo.

:: Install update
echo Installing app on phone...

"%ADB%" -s "!DEVICE!" install -r "%APK_PATH%"

if errorlevel 1 (
    echo.
    echo ERROR: Installation failed!
    echo.
    echo Check the installation error above.
    pause
    exit /b 1
)

echo.
echo ========================================
echo       SUCCESS: App Updated!
echo       Version: !NEW_VERSION!
echo ========================================
echo.
pause
