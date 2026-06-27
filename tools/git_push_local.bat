@echo off
setlocal EnableExtensions
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Push local commits to GitHub
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
    echo ERROR: No commits exist yet.
    pause
    exit /b 1
)
git remote get-url origin >nul 2>nul
if errorlevel 1 (
    echo ERROR: No origin remote is configured.
    echo Run tools\git_login.bat
    pause
    exit /b 1
)

set "CURRENT_BRANCH="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%A"
if not defined CURRENT_BRANCH set "CURRENT_BRANCH=%CFG_BRANCH%"

git status -sb
echo.

git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>nul
if errorlevel 1 (
    echo No upstream is configured. Creating it now...
    git push -u origin "%CURRENT_BRANCH%"
) else (
    git push
)

if errorlevel 1 (
    echo.
    echo ERROR: Push failed.
    echo Run just_status.bat for more information.
    pause
    exit /b 1
)

echo.
echo Push complete.
pause
exit /b 0
