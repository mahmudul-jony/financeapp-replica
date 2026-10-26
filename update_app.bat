@echo off
setlocal
title Finance App Updater

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"

echo ========================================
echo       Finance App ADB Updater
echo ========================================
echo.

if not exist "%ADB%" (
    echo ERROR: ADB not found at %ADB%!
    pause
    exit /b 1
)

echo Checking connected devices...
echo.

set "DEVICE="
set "FALLBACK_DEVICE="

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
        ) else (
            set "FALLBACK_DEVICE=%%A"
        )
    )
)

if not defined DEVICE (
    if defined FALLBACK_DEVICE (
        echo No Wi-Fi device found, using connected USB device: %FALLBACK_DEVICE%
        set "DEVICE=%FALLBACK_DEVICE%"
    ) else (
        echo ERROR: No connected phone found (Wi-Fi or USB).
        echo.
        echo Enable Wireless Debugging or connect your phone via USB first.
        pause
        exit /b 1
    )
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
echo Installing app on phone (preserving existing data)...
"%ADB%" -s "%DEVICE%" install -r -d "build\app\outputs\flutter-apk\app-release.apk"
if errorlevel 1 (
    echo.
    echo ERROR: Installation failed!
    echo Note: If error is INSTALL_FAILED_UPDATE_INCOMPATIBLE, the app on your phone
    echo is signed with a different certificate (e.g. GitHub Actions release key).
    pause
    exit /b 1
)

echo.
echo SUCCESS: Finance App updated!
pause
