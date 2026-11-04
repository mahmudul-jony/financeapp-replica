```bat
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

:: Get default version code from pubspec.yaml
set /a PUBSPEC_BUILD_NUM=1

for /f "tokens=2 delims=+" %%A in ('findstr /r "^version:" pubspec.yaml') do (
    set /a PUBSPEC_BUILD_NUM=%%A 2>nul
)

:: Get installed version code from phone
set /a PHONE_BUILD_NUM=0

for /f "tokens=1 delims= " %%A in ('"%ADB%" -s !DEVICE! shell dumpsys package %PACKAGE_NAME% 2^>nul ^| findstr /c:"versionCode="' ) do (
    for /f "tokens=2 delims==" %%B in ("%%A") do (
        set /a PHONE_BUILD_NUM=%%B 2>nul
    )
)

:: Calculate next version code
set /a TARGET_BUILD_NUM=PUBSPEC_BUILD_NUM

if !PHONE_BUILD_NUM! GEQ !TARGET_BUILD_NUM! (
    set /a TARGET_BUILD_NUM=PHONE_BUILD_NUM+1
)

echo ========================================
echo Pubspec Build Number: !PUBSPEC_BUILD_NUM!
echo Phone Build Number:   !PHONE_BUILD_NUM!
echo Next Build Number:    !TARGET_BUILD_NUM!
echo ========================================
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
call flutter build apk --release --build-number=!TARGET_BUILD_NUM!

if errorlevel 1 (
    echo.
    echo ERROR: Build failed!
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

:: Install update without uninstalling existing app
echo Installing app on phone...

"%ADB%" -s "!DEVICE!" install -r "%APK_PATH%"

if errorlevel 1 (
    echo.
    echo ERROR: Installation failed!
    echo.
    echo Check the installation error above.
    echo Do NOT uninstall the existing app yet.
    pause
    exit /b 1
)

echo.
echo ========================================
echo       SUCCESS: App Updated!
echo ========================================
echo.
pause
```