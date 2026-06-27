@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Run project
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.

set "APP_RUN_COMMAND="
set "APP_RUN_FILE="
set "APP_OUTPUT_EXE="
set "APP_OUTPUT_APK="
set "APP_LAUNCH_ACTIVITY="
set "APP_ANDROID_SDK_DIR="
set "APP_ANDROID_SDK_FALLBACK_DIR="

if defined app.run_command set "APP_RUN_COMMAND=%app.run_command%"
if defined app.run_file set "APP_RUN_FILE=%app.run_file%"
if defined app.output_exe set "APP_OUTPUT_EXE=%app.output_exe%"
if defined app.output_apk set "APP_OUTPUT_APK=%app.output_apk%"
if defined app.launch_activity set "APP_LAUNCH_ACTIVITY=%app.launch_activity%"
if defined app.android_sdk_dir set "APP_ANDROID_SDK_DIR=%app.android_sdk_dir%"
if defined app.android_sdk_fallback_dir set "APP_ANDROID_SDK_FALLBACK_DIR=%app.android_sdk_fallback_dir%"

if defined APP_RUN_COMMAND (
    call %APP_RUN_COMMAND%
    exit /b %ERRORLEVEL%
)

if defined APP_RUN_FILE (
    if not exist "%APP_RUN_FILE%" (
        echo ERROR: app.run_file was not found:
        echo   %APP_RUN_FILE%
        pause
        exit /b 1
    )
    start "" "%CD%\%APP_RUN_FILE%"
    exit /b 0
)

if defined APP_OUTPUT_EXE (
    if not exist "%APP_OUTPUT_EXE%" (
        echo ERROR: app.output_exe was not found:
        echo   %APP_OUTPUT_EXE%
        pause
        exit /b 1
    )
    start "" "%CD%\%APP_OUTPUT_EXE%"
    exit /b 0
)

if defined APP_OUTPUT_APK (
    if not exist "%APP_OUTPUT_APK%" (
        echo ERROR: APK was not found:
        echo   %APP_OUTPUT_APK%
        pause
        exit /b 1
    )

    set "ADB_EXE="
    if defined APP_ANDROID_SDK_DIR if exist "%APP_ANDROID_SDK_DIR%\platform-tools\adb.exe" set "ADB_EXE=%APP_ANDROID_SDK_DIR%\platform-tools\adb.exe"
    if not defined ADB_EXE if defined APP_ANDROID_SDK_FALLBACK_DIR if exist "%APP_ANDROID_SDK_FALLBACK_DIR%\platform-tools\adb.exe" set "ADB_EXE=%APP_ANDROID_SDK_FALLBACK_DIR%\platform-tools\adb.exe"
    if not defined ADB_EXE (
        where adb >nul 2>nul
        if not errorlevel 1 set "ADB_EXE=adb"
    )
    if not defined ADB_EXE (
        echo ERROR: adb was not found.
        pause
        exit /b 1
    )

    "!ADB_EXE!" install -r "%APP_OUTPUT_APK%"
    if errorlevel 1 (
        echo ERROR: APK installation failed.
        pause
        exit /b 1
    )
    if defined APP_LAUNCH_ACTIVITY (
        "!ADB_EXE!" shell am start -n "%APP_LAUNCH_ACTIVITY%"
        if errorlevel 1 (
            echo ERROR: App launch failed.
            pause
            exit /b 1
        )
    )
    pause
    exit /b 0
)

echo This code-less demonstrator has no run target configured.
echo Configure app.run_command, app.run_file, app.output_exe,
echo or app.output_apk in build_config.bat for a runnable project.
echo.
pause
exit /b 0
