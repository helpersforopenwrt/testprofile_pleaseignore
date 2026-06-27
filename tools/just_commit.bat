@echo off
setlocal EnableExtensions
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Commit local changes only
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
    echo No local changes to commit.
    pause
    exit /b 0
)

git status --short
echo.

set "MSG=%~1"
:AskMessage
if defined MSG goto HaveMessage
set /p "MSG=Commit message: "
if not defined MSG (
    echo Commit message is required.
    echo.
    goto AskMessage
)

:HaveMessage
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

echo.
echo Commit complete. It has not been pushed.
echo To push it, run just_push.bat
echo.
pause
exit /b 0
