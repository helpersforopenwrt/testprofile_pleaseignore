@echo off
setlocal EnableExtensions
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Changed files and diff summary
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

echo Changed files:
git status --short
echo.
echo Unstaged diff summary:
git diff --stat
echo.
echo Staged diff summary:
git diff --cached --stat
echo.
pause
exit /b 0
