@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Git status check
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
    echo.
    pause
    exit /b 1
)

if not exist ".git" (
    echo ERROR: This folder is not a Git repository.
    echo.
    echo Run:
    echo   tools\git_login.bat
    echo.
    pause
    exit /b 1
)

set "CURRENT_BRANCH="
set "ORIGIN_URL="
set "DIRTY="
set "HAS_HEAD="
set "AHEAD=0"
set "BEHIND=0"

for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%A"
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "ORIGIN_URL=%%A"
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "DIRTY=1"

git rev-parse --verify HEAD >nul 2>nul
if not errorlevel 1 set "HAS_HEAD=1"

echo Branch:
if defined CURRENT_BRANCH (echo   %CURRENT_BRANCH%) else echo   no current branch detected
echo.
echo Origin remote:
if defined ORIGIN_URL (echo   %ORIGIN_URL%) else echo   not configured
echo.
if defined CFG_REPO_URL (
    echo Repo URL from build_config.bat:
    echo   %CFG_REPO_URL%
    echo.
)

echo Local status:
git status -sb
echo.

if not defined HAS_HEAD (
    echo ============================================================
    echo  Recommendation
    echo ============================================================
    echo.
    echo No commits exist yet.
    if defined DIRTY (
        echo.
        echo Recommended:
        echo   just_commit.bat
    )
    echo.
    pause
    exit /b 0
)

if not defined ORIGIN_URL (
    echo ============================================================
    echo  Recommendation
    echo ============================================================
    echo.
    echo No origin remote is configured.
    echo.
    echo Recommended:
    echo   tools\git_login.bat
    echo.
    pause
    exit /b 1
)

echo Checking GitHub...
git fetch --quiet
if errorlevel 1 (
    echo.
    echo WARNING: Could not contact GitHub.
    echo Local status above is still useful.
    echo.
    pause
    exit /b 1
)

git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>nul
if errorlevel 1 (
    echo.
    echo No upstream branch is configured.
    echo.
    echo Usually fix with:
    if defined CURRENT_BRANCH (
        echo   git push -u origin %CURRENT_BRANCH%
    ) else (
        echo   git push -u origin %CFG_BRANCH%
    )
    echo.
    pause
    exit /b 1
)

for /f "tokens=1,2" %%A in ('git rev-list --left-right --count HEAD...@{u} 2^>nul') do (
    set "AHEAD=%%A"
    set "BEHIND=%%B"
)

echo.
echo ============================================================
echo  Recommendation
echo ============================================================
echo.

if defined DIRTY (
    echo You have local file changes.
    echo.
    echo Commit them with:
    echo   just_commit.bat
    echo.
    echo Do not get latest until changes are committed or discarded.
) else (
    if !AHEAD! EQU 0 if !BEHIND! EQU 0 echo Everything is clean and synchronized.
    if !AHEAD! GTR 0 if !BEHIND! EQU 0 (
        echo Local commits need to be pushed.
        echo.
        echo Recommended:
        echo   just_push.bat
    )
    if !AHEAD! EQU 0 if !BEHIND! GTR 0 (
        echo GitHub has newer commits.
        echo.
        echo Recommended:
        echo   just_getlatest.bat
    )
    if !AHEAD! GTR 0 if !BEHIND! GTR 0 (
        echo Local Git and GitHub have both changed.
        echo Do not auto-merge until you inspect both histories.
        echo.
        echo Recommended first:
        echo   tools\git_backup_bundle.bat
    )
)

echo.
echo Ahead of GitHub: !AHEAD!
echo Behind GitHub:  !BEHIND!
echo.
pause
exit /b 0
