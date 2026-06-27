@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Create Git backup bundle
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.

where git >nul 2>nul
if errorlevel 1 (
    echo ERROR: git was not found in PATH.
    pause
    exit /b 1
)
if not exist ".git" (
    echo ERROR: This folder is not a Git repository.
    pause
    exit /b 1
)
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (
    echo ERROR: A Git bundle needs at least one commit.
    pause
    exit /b 1
)

set "DIRTY="
for /f "delims=" %%A in ('git status --porcelain') do set "DIRTY=1"
if defined DIRTY (
    echo WARNING: A Git bundle contains committed Git history only.
    echo It does not include uncommitted, untracked, or ignored files.
    echo.
    git status --short
    echo.
    set "CONTINUE="
    set /p "CONTINUE=Create the committed-history bundle anyway? [y/N]: "
    if /I not "!CONTINUE!"=="y" (
        echo Cancelled.
        pause
        exit /b 0
    )
)

set "SAFE_APP_NAME=%APP_NAME%"
set "SAFE_APP_NAME=!SAFE_APP_NAME: =_!"
set "SAFE_APP_NAME=!SAFE_APP_NAME:/=_!"
set "SAFE_APP_NAME=!SAFE_APP_NAME:\=_!"
set "SAFE_APP_NAME=!SAFE_APP_NAME::=_!"
set "SAFE_APP_NAME=!SAFE_APP_NAME:*=_!"
set "SAFE_APP_NAME=!SAFE_APP_NAME:?=_!"
set "SAFE_APP_NAME=!SAFE_APP_NAME:"=_!"
set "SAFE_APP_NAME=!SAFE_APP_NAME:<=_!"
set "SAFE_APP_NAME=!SAFE_APP_NAME:>=_!"
set "SAFE_APP_NAME=!SAFE_APP_NAME:|=_!"

set "BACKUP_DIR="
if defined app.git_backup_dir set "BACKUP_DIR=%app.git_backup_dir%"
if not defined BACKUP_DIR set "BACKUP_DIR=%USERPROFILE%\Desktop\!SAFE_APP_NAME!-git-backups"

for %%I in ("!BACKUP_DIR!") do set "BACKUP_DIR=%%~fI"
if not exist "!BACKUP_DIR!" mkdir "!BACKUP_DIR!"
if errorlevel 1 (
    echo ERROR: Could not create backup folder:
    echo   !BACKUP_DIR!
    pause
    exit /b 1
)

for /f "delims=" %%A in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd.HHmmss"') do set "STAMP=%%A"
if not defined STAMP set "STAMP=%RANDOM%-%RANDOM%"

set "BACKUP_FILE=!BACKUP_DIR!\!SAFE_APP_NAME!-!STAMP!.bundle"
git bundle create "!BACKUP_FILE!" --all
if errorlevel 1 (
    echo ERROR: Backup bundle failed.
    pause
    exit /b 1
)

echo.
echo Backup created:
echo   !BACKUP_FILE!
echo.
pause
exit /b 0
