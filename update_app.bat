
@echo off
setlocal
title Finance App Updater

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"

echo ========================================
echo       Finance App Wi-Fi Updater
echo ========================================
echo.

if not exist "%ADB%" (
    echo ERROR: ADB not found!
    pause
    exit /b 1
)

echo Checking connected devices...
echo.

set "DEVICE="

for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do (
    if "%%B"=="device" (
        echo %%A | findstr /c:":" >nul
        if not errorlevel 1 (
            if defined DEVICE (
                echo ERROR: Multiple Wi-Fi devices found.
                pause
                exit /b 1
            )
            set "DEVICE=%%A"
        )
    )
)

if not defined DEVICE (
    echo ERROR: No Wi-Fi-connected phone found.
    echo.
    echo Enable Wireless Debugging and connect your phone first.
    pause
    exit /b 1
)

echo Target phone: %DEVICE%
echo.
echo Building Finance App...
call flutter build apk --release
if errorlevel 1 (
    echo.
    echo ERROR: Build failed!
    pause
    exit /b 1
)

echo.
echo Installing app on phone...
"%ADB%" -s "%DEVICE%" install -r "build\app\outputs\flutter-apk\app-release.apk"
if errorlevel 1 (
    echo.
    echo ERROR: Installation failed!
    pause
    exit /b 1
)

echo.
echo SUCCESS: Finance App updated!
pause
