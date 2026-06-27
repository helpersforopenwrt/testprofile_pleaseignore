@echo off
setlocal EnableExtensions
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  DANGEROUS: Discard local uncommitted changes
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
    echo ERROR: No commit exists to restore.
    pause
    exit /b 1
)

echo This will restore tracked files and delete untracked,
echo non-ignored files and folders.
echo.
git status --short
echo.
echo Files/folders that git clean would remove:
git clean -nd
echo.
set "CONFIRM="
set /p "CONFIRM=Type DISCARD to continue: "
if not "%CONFIRM%"=="DISCARD" (
    echo Cancelled.
    pause
    exit /b 0
)

git reset --hard HEAD
if errorlevel 1 (
    echo ERROR: git reset failed.
    pause
    exit /b 1
)
git clean -fd
if errorlevel 1 (
    echo ERROR: git clean failed.
    pause
    exit /b 1
)

echo.
echo Local uncommitted changes discarded.
git status -sb
echo.
pause
exit /b 0
