@echo off

call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Check ignored and untracked files
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.

where git.exe >nul 2>nul
if errorlevel 1 (
    echo ERROR: Git was not found in PATH.
    echo.
    echo Run:
    echo   prepare.bat git
    echo.
    pause
    exit /b 1
)

if not exist ".git" (
    echo ERROR: This folder is not a Git repository.
    echo.
    echo Run:
    echo   git_login.bat
    echo.
    pause
    exit /b 1
)

echo ============================================================
echo  Git status, including ignored files
echo ============================================================
echo.
git status --short --ignored
echo.

echo ============================================================
echo  What the prefixes mean
echo ============================================================
echo.
echo   !!  Ignored by .gitignore.
echo       These files will NOT be added by git add --all.
echo.
echo   ??  Untracked and NOT ignored.
echo       These files WILL be added by git add --all.
echo.
echo   M   A tracked file was modified.
echo.
echo   A   A file is staged to be added.
echo.
echo   D   A tracked file was deleted.
echo.
echo The two status columns can also show staged and unstaged states.
echo.

echo ============================================================
echo  Local dependency folders
echo ============================================================
echo.
echo The following local-only paths should be ignored when they exist:
echo.
echo   tools\git\
echo   tools\gh\
echo   tools\downloads\
echo   tools\logs\
echo   prepare.log
echo   env.bat
echo.

set "gcif.warning="

call :CheckLocalPath "tools\git"
call :CheckLocalPath "tools\gh"
call :CheckLocalPath "tools\downloads"
call :CheckLocalPath "tools\logs"
call :CheckLocalPath "prepare.log"
call :CheckLocalPath "env.bat"

echo.
echo ============================================================
echo  Recommendation
echo ============================================================
echo.

if defined gcif.warning (
    echo WARNING: One or more local-only paths exist but are not ignored.
    echo.
    echo Do not commit yet.
    echo Update .gitignore, then run this script again.
) else (
    echo No existing local dependency path was found outside .gitignore.
    echo.
    echo Before committing, look through the status listing above:
    echo   entries beginning with !! are safely ignored
    echo   entries beginning with ?? will be included in the next commit
)

set "gcif.warning="
set "gcif.path="

echo.
pause
exit /b 0

:: ============================================================
:: Function: CheckLocalPath
:: Usage: call :CheckLocalPath "relative path"
:: Purpose:
::   Reports whether an existing local-only path is ignored.
:: Returns:
::   0 always
:: ============================================================

:CheckLocalPath
set "gcif.path=%~1"

if not exist "%gcif.path%" (
    echo [not present]  %gcif.path%
    set "gcif.path="
    exit /b 0
)

git check-ignore -q "%gcif.path%" >nul 2>nul
if not errorlevel 1 (
    echo [ignored]      %gcif.path%
    set "gcif.path="
    exit /b 0
)

echo [WARNING]      %gcif.path%
set "gcif.warning=1"
set "gcif.path="
exit /b 0
