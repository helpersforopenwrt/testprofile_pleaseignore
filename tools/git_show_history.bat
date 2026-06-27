@echo off
setlocal EnableExtensions
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Recent Git history
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
    echo No commits exist yet.
    pause
    exit /b 0
)
git status -sb
echo.
git log --oneline --decorate --graph -30
echo.
pause
exit /b 0
