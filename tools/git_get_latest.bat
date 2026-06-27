@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Get latest from GitHub
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

set "DIRTY="
for /f "delims=" %%A in ('git status --porcelain') do set "DIRTY=1"
if defined DIRTY (
    echo ERROR: You have local file changes.
    echo Commit or discard them before getting latest.
    echo.
    git status --short
    pause
    exit /b 1
)

git fetch
if errorlevel 1 (
    echo ERROR: Fetch failed.
    pause
    exit /b 1
)

git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>nul
if errorlevel 1 (
    echo ERROR: No upstream branch is configured.
    echo Run tools\git_login.bat
    pause
    exit /b 1
)

set "AHEAD=0"
set "BEHIND=0"
for /f "tokens=1,2" %%A in ('git rev-list --left-right --count HEAD...@{u}') do (
    set "AHEAD=%%A"
    set "BEHIND=%%B"
)

if !AHEAD! GTR 0 if !BEHIND! GTR 0 (
    echo ERROR: Local Git and GitHub have both changed.
    echo No automatic merge was attempted.
    pause
    exit /b 1
)

if !BEHIND! GTR 0 (
    git merge --ff-only @{u}
    if errorlevel 1 (
        echo ERROR: Fast-forward update failed.
        pause
        exit /b 1
    )
    echo.
    echo Updated successfully.
    pause
    exit /b 0
)

if !AHEAD! GTR 0 (
    echo Local commits still need to be pushed.
    echo Run just_push.bat
    pause
    exit /b 0
)

echo Already up to date.
pause
exit /b 0
