@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Finance App ADB Updater

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "PACKAGE_NAME=com.example.financeapp"
set "DEVICE="
set /a COUNT=0

echo ========================================
echo       Finance App ADB Updater
echo ========================================
echo.

if not exist "%ADB%" (
    echo ERROR: ADB not found!
    pause
    exit /b 1
)

echo Checking connected devices...
echo.

for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do (
    if "%%B"=="device" (
        echo %%A | findstr /i /c:"emulator-" >nul
        if errorlevel 1 (
            set "DEVICE=%%A"
            set /a COUNT+=1
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

:: Get default version code from pubspec.yaml
set /a PUBSPEC_BUILD_NUM=1
for /f "tokens=2 delims=+" %%A in ('findstr /r "^version:" pubspec.yaml') do (
    set /a PUBSPEC_BUILD_NUM=%%A 2>nul
)

:: Get version code from phone via ADB
set /a PHONE_BUILD_NUM=0
for /f "tokens=1 delims= " %%A in ('"%ADB%" -s !DEVICE! shell dumpsys package %PACKAGE_NAME% 2^>nul ^| findstr /c:"versionCode="' ) do (
    for /f "tokens=2 delims==" %%B in ("%%A") do (
        set /a PHONE_BUILD_NUM=%%B 2>nul
    )
)

:: Match the highest version so we never downgrade and never artificially increment GitHub numbers
set /a TARGET_BUILD_NUM=PUBSPEC_BUILD_NUM
if !PHONE_BUILD_NUM! GTR !TARGET_BUILD_NUM! (
    set /a TARGET_BUILD_NUM=PHONE_BUILD_NUM
)

echo Generating latest app launcher icons...
call dart run flutter_launcher_icons

echo.
echo Target Build Number: !TARGET_BUILD_NUM! (Pubspec: !PUBSPEC_BUILD_NUM!, Phone: !PHONE_BUILD_NUM!)
echo Building Finance App...
call flutter build apk --release --build-number=!TARGET_BUILD_NUM!

if errorlevel 1 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo Installing app on phone...

"%ADB%" -s "!DEVICE!" install -r -d "build\app\outputs\flutter-apk\app-release.apk"

if errorlevel 1 (
    echo.
    echo ERROR: Installation failed!
    echo.
    echo Note: If error is INSTALL_FAILED_UPDATE_INCOMPATIBLE, please uninstall
    echo the existing app from your phone first (due to different signing keys).
    pause
    exit /b 1
)

echo.
echo SUCCESS: Finance App updated!
pause
