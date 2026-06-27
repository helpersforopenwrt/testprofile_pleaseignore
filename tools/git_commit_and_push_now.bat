@echo off
setlocal EnableExtensions
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Commit and push now
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
    echo Run tools\git_login.bat first.
    pause
    exit /b 1
)

set "DIRTY="
for /f "delims=" %%A in ('git status --porcelain') do set "DIRTY=1"

if not defined DIRTY (
    echo No local file changes to commit.
    echo Trying push in case commits are pending...
    echo.
    git push
    if errorlevel 1 (
        echo ERROR: Push failed.
        pause
        exit /b 1
    )
    echo Push complete.
    pause
    exit /b 0
)

git status --short
echo.
set "MSG="
set /p "MSG=Commit message, or press Enter for default: "
if not defined MSG set "MSG=Manual save %APP_DISPLAY_NAME% %DATE% %TIME%"

git add --all
if errorlevel 1 (
    echo ERROR: git add failed.
    pause
    exit /b 1
)

git commit -m "%MSG%"
if errorlevel 1 (
    echo ERROR: git commit failed.
    pause
    exit /b 1
)

git push
if errorlevel 1 (
    echo ERROR: Commit was saved locally, but push failed.
    pause
    exit /b 1
)

echo.
echo Commit and push complete.
pause
exit /b 0
