@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Verify GitHub clone
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

set "REMOTE_URL="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "REMOTE_URL=%%A"
if not defined REMOTE_URL set "REMOTE_URL=%CFG_REPO_URL%"
if not defined REMOTE_URL (
    echo ERROR: Could not determine the repository URL.
    pause
    exit /b 1
)

set "DIRTY="
for /f "delims=" %%A in ('git status --porcelain') do set "DIRTY=1"
if defined DIRTY (
    echo ERROR: Local files are not clean.
    echo Commit or discard changes before verification.
    pause
    exit /b 1
)

git fetch --quiet
if errorlevel 1 (
    echo ERROR: Could not fetch from GitHub.
    pause
    exit /b 1
)

git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>nul
if errorlevel 1 (
    echo ERROR: No upstream branch is configured.
    pause
    exit /b 1
)

set "AHEAD=0"
set "BEHIND=0"
for /f "tokens=1,2" %%A in ('git rev-list --left-right --count HEAD...@{u}') do (
    set "AHEAD=%%A"
    set "BEHIND=%%B"
)
if not "!AHEAD!"=="0" (
    echo ERROR: Local commits have not all been pushed.
    pause
    exit /b 1
)
if not "!BEHIND!"=="0" (
    echo ERROR: The local branch is behind GitHub.
    pause
    exit /b 1
)

set "LOCAL_HEAD="
for /f "delims=" %%A in ('git rev-parse HEAD') do set "LOCAL_HEAD=%%A"

set "SAFE_APP_NAME=%APP_NAME%"
set "SAFE_APP_NAME=!SAFE_APP_NAME: =_!"
set "TEST_DIR=%TEMP%\!SAFE_APP_NAME!-verify-clone-%RANDOM%-%RANDOM%"

git clone --branch "%CFG_BRANCH%" --single-branch "%REMOTE_URL%" "!TEST_DIR!"
if errorlevel 1 (
    echo ERROR: Test clone failed.
    pause
    exit /b 1
)

set "CLONED_HEAD="
for /f "delims=" %%A in ('git -C "!TEST_DIR!" rev-parse HEAD') do set "CLONED_HEAD=%%A"

if /I not "!LOCAL_HEAD!"=="!CLONED_HEAD!" (
    echo ERROR: Fresh clone HEAD does not match local HEAD.
    echo Local:  !LOCAL_HEAD!
    echo Clone:  !CLONED_HEAD!
    rmdir /s /q "!TEST_DIR!" >nul 2>nul
    pause
    exit /b 1
)

rmdir /s /q "!TEST_DIR!"
if errorlevel 1 (
    echo WARNING: Verification succeeded, but temporary folder cleanup failed:
    echo   !TEST_DIR!
    pause
    exit /b 1
)

echo.
echo Verification complete.
echo Fresh clone HEAD exactly matches local HEAD:
echo   !LOCAL_HEAD!
echo.
pause
exit /b 0
