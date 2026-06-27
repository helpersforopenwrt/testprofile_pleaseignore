@echo off
rem Internal helper. Call from another script:
rem   call "%~dp0_common.bat" init

if /I not "%~1"=="init" (
    echo ERROR: _common.bat is an internal helper.
    exit /b 2
)

set "PROJECT_ROOT="
set "PROJECT_MARKER="
set "PROJECT_START_DIR=%CD%"

for %%I in ("%CD%") do set "PROJECT_CURRENT_DIR=%%~fI"
for %%I in ("%CD%\..") do set "PROJECT_PARENT_DIR=%%~fI"

rem Prefer build_config.bat, even when build.bat is closer.
if exist "%PROJECT_CURRENT_DIR%\build_config.bat" (
    set "PROJECT_ROOT=%PROJECT_CURRENT_DIR%"
    set "PROJECT_MARKER=build_config.bat"
)

if not defined PROJECT_ROOT if exist "%PROJECT_PARENT_DIR%\build_config.bat" (
    set "PROJECT_ROOT=%PROJECT_PARENT_DIR%"
    set "PROJECT_MARKER=build_config.bat"
)

if not defined PROJECT_ROOT if exist "%PROJECT_CURRENT_DIR%\build.bat" (
    set "PROJECT_ROOT=%PROJECT_CURRENT_DIR%"
    set "PROJECT_MARKER=build.bat"
)

if not defined PROJECT_ROOT if exist "%PROJECT_PARENT_DIR%\build.bat" (
    set "PROJECT_ROOT=%PROJECT_PARENT_DIR%"
    set "PROJECT_MARKER=build.bat"
)

if not defined PROJECT_ROOT (
    echo.
    echo ERROR: Could not locate the project root.
    echo.
    echo Started in:
    echo   %PROJECT_START_DIR%
    echo.
    echo Looked for:
    echo   current folder\build_config.bat
    echo   parent folder\build_config.bat
    echo   current folder\build.bat
    echo   parent folder\build.bat
    echo.
    exit /b 1
)

cd /d "%PROJECT_ROOT%"
if errorlevel 1 (
    echo ERROR: Could not change to project root:
    echo   %PROJECT_ROOT%
    exit /b 1
)

set "APP_NAME=project"
set "APP_DISPLAY_NAME="
set "CFG_REPO_URL="
set "CFG_BRANCH=main"
set "APP_TOOLS_DIR=tools"

if exist "%PROJECT_ROOT%\build_config.bat" (
    call "%PROJECT_ROOT%\build_config.bat"
    if errorlevel 1 (
        echo ERROR: build_config.bat returned an error.
        exit /b 1
    )
)

if defined app.name set "APP_NAME=%app.name%"
if defined app.display_name set "APP_DISPLAY_NAME=%app.display_name%"
if not defined APP_DISPLAY_NAME set "APP_DISPLAY_NAME=%APP_NAME%"

if defined app.repo_url set "CFG_REPO_URL=%app.repo_url%"
if defined app.git_repo_url set "CFG_REPO_URL=%app.git_repo_url%"
if defined app.github_url set "CFG_REPO_URL=%app.github_url%"

if defined app.git_branch set "CFG_BRANCH=%app.git_branch%"
if defined app.branch set "CFG_BRANCH=%app.branch%"
if not defined CFG_BRANCH set "CFG_BRANCH=main"

if defined app.tools_dir set "APP_TOOLS_DIR=%app.tools_dir%"
if not defined APP_TOOLS_DIR set "APP_TOOLS_DIR=tools"

for %%I in ("%PROJECT_ROOT%\%APP_TOOLS_DIR%") do set "TOOLS_DIR=%%~fI"

exit /b 0
