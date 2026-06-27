@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================
rem git_login.bat
rem
rem Prepares Git and GitHub CLI, authenticates the user, verifies
rem access to the configured GitHub repository, configures a fork
rem when direct push access is unavailable, initializes local Git,
rem configures identity/remotes, and pushes when commits exist.
rem
rem Repository-level permission is checked through GitHub.
rem Branch-protection rules are checked by the eventual git push.
rem ============================================================

call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  GitHub login, permission, and origin setup
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.

rem ============================================================
rem Prepare dependencies
rem ============================================================

if not exist "%CD%\prepare.bat" (
    echo ERROR: prepare.bat was not found in the project root:
    echo   %CD%
    echo.
    pause
    exit /b 1
)

echo Preparing Git and GitHub CLI...
call "%CD%\prepare.bat" repository
if errorlevel 1 (
    echo.
    echo ERROR: Dependency preparation failed.
    echo.
    pause
    exit /b 1
)

where git.exe >nul 2>nul
if errorlevel 1 (
    echo.
    echo ERROR: Git is unavailable after preparation.
    echo.
    pause
    exit /b 1
)

where gh.exe >nul 2>nul
if errorlevel 1 (
    echo.
    echo ERROR: GitHub CLI is unavailable after preparation.
    echo.
    pause
    exit /b 1
)

rem ============================================================
rem Authenticate with GitHub
rem ============================================================

echo.
echo Checking GitHub login...
gh auth status --hostname github.com >nul 2>nul
if errorlevel 1 (
    echo GitHub login is required.
    echo A browser window will open for secure login.
    echo.
    gh auth login --hostname github.com --git-protocol https --web
    if errorlevel 1 (
        echo.
        echo ERROR: GitHub login failed or was cancelled.
        echo.
        pause
        exit /b 1
    )
)

set "GITHUB_LOGIN="
for /f "delims=" %%A in ('gh api user --jq ".login" 2^>nul') do set "GITHUB_LOGIN=%%A"

if not defined GITHUB_LOGIN (
    echo.
    echo ERROR: Could not determine the logged-in GitHub account.
    echo.
    pause
    exit /b 1
)

echo Logged in to GitHub as:
echo   !GITHUB_LOGIN!
echo.

echo Configuring Git to use the GitHub login...
gh auth setup-git --hostname github.com
if errorlevel 1 (
    echo.
    echo ERROR: GitHub CLI could not configure Git authentication.
    echo.
    pause
    exit /b 1
)

rem ============================================================
rem Resolve configured repository
rem ============================================================

set "FINAL_NAME="
set "FINAL_EMAIL="
set "FINAL_REPO_URL=%CFG_REPO_URL%"
set "FINAL_BRANCH=%CFG_BRANCH%"
set "EXISTING_ORIGIN="
set "CURRENT_BRANCH="
set "REPO_SLUG="
set "REPO_OWNER="
set "REPO_NAME="
set "CAN_PUSH="
set "USE_FORK="
set "FORK_SLUG="
set "FORK_URL="
set "TARGET_ORIGIN_URL="

if exist ".git" (
    for /f "delims=" %%A in ('git config --local --get user.name 2^>nul') do set "FINAL_NAME=%%A"
    for /f "delims=" %%A in ('git config --local --get user.email 2^>nul') do set "FINAL_EMAIL=%%A"
    for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "EXISTING_ORIGIN=%%A"
    for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%A"
)

if defined app.git_name set "FINAL_NAME=%app.git_name%"
if defined app.git_email set "FINAL_EMAIL=%app.git_email%"

if not defined FINAL_NAME (
    for /f "delims=" %%A in ('git config --global --get user.name 2^>nul') do set "FINAL_NAME=%%A"
)

if not defined FINAL_EMAIL (
    for /f "delims=" %%A in ('git config --global --get user.email 2^>nul') do set "FINAL_EMAIL=%%A"
)

if not defined FINAL_REPO_URL if defined EXISTING_ORIGIN set "FINAL_REPO_URL=!EXISTING_ORIGIN!"
if not defined FINAL_BRANCH set "FINAL_BRANCH=main"
if defined CURRENT_BRANCH set "FINAL_BRANCH=!CURRENT_BRANCH!"

if not defined FINAL_REPO_URL (
    set /p "FINAL_REPO_URL=GitHub repository URL: "
)

if not defined FINAL_REPO_URL (
    echo.
    echo ERROR: A GitHub repository URL is required.
    echo.
    pause
    exit /b 1
)

echo Checking repository:
echo   !FINAL_REPO_URL!
echo.

for /f "delims=" %%A in ('gh repo view "!FINAL_REPO_URL!" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "REPO_SLUG=%%A"

if not defined REPO_SLUG (
    echo ERROR: The configured repository was not found or is not visible
    echo to the logged-in GitHub account.
    echo.
    echo Account:
    echo   !GITHUB_LOGIN!
    echo.
    echo Repository:
    echo   !FINAL_REPO_URL!
    echo.
    echo For a repository that does not exist yet, use:
    echo   tools\git_create_repository.bat
    echo.
    pause
    exit /b 1
)

for /f "tokens=1,2 delims=/" %%A in ("!REPO_SLUG!") do (
    set "REPO_OWNER=%%A"
    set "REPO_NAME=%%B"
)

if not defined REPO_OWNER (
    echo ERROR: Could not determine the repository owner.
    pause
    exit /b 1
)

if not defined REPO_NAME (
    echo ERROR: Could not determine the repository name.
    pause
    exit /b 1
)

for /f "delims=" %%A in ('gh api "repos/!REPO_SLUG!" --jq ".permissions.push" 2^>nul') do set "CAN_PUSH=%%A"

if not defined CAN_PUSH (
    echo.
    echo ERROR: Could not determine repository permissions.
    echo.
    pause
    exit /b 1
)

echo Repository:
echo   !REPO_SLUG!
echo.

if /I "!CAN_PUSH!"=="true" (
    echo Access:
    echo   Direct push permission confirmed.
    set "TARGET_ORIGIN_URL=!FINAL_REPO_URL!"
) else (
    echo Access:
    echo   Read access confirmed, but direct push permission is unavailable.
    echo.
    call :ConfigureFork
    if errorlevel 1 (
        pause
        exit /b 1
    )
)

rem ============================================================
rem Initialize and configure local Git
rem ============================================================

if not exist ".git" (
    echo.
    set "MAKE_REPO="
    set /p "MAKE_REPO=Initialize a Git repository here? [Y/n]: "

    if /I "!MAKE_REPO!"=="n" (
        echo.
        echo Cancelled.
        echo.
        pause
        exit /b 1
    )

    echo.
    echo Initializing Git repository...

    git init -b "!FINAL_BRANCH!" >nul 2>nul
    if errorlevel 1 (
        git init
        if errorlevel 1 (
            echo.
            echo ERROR: git init failed.
            echo.
            pause
            exit /b 1
        )

        git checkout -B "!FINAL_BRANCH!"
        if errorlevel 1 (
            echo.
            echo ERROR: Could not create branch "!FINAL_BRANCH!".
            echo.
            pause
            exit /b 1
        )
    )
)

echo.
echo Git author identity:
echo.

set "INPUT="
set /p "INPUT=Git name [!FINAL_NAME!]: "
if defined INPUT set "FINAL_NAME=!INPUT!"

if not defined FINAL_NAME (
    echo.
    echo ERROR: Git name is required.
    echo.
    pause
    exit /b 1
)

set "INPUT="
set /p "INPUT=Git email [!FINAL_EMAIL!]: "
if defined INPUT set "FINAL_EMAIL=!INPUT!"

if not defined FINAL_EMAIL (
    echo.
    echo ERROR: Git email is required.
    echo.
    pause
    exit /b 1
)

git config --local user.name "!FINAL_NAME!"
if errorlevel 1 (
    echo.
    echo ERROR: Could not set local Git user.name.
    echo.
    pause
    exit /b 1
)

git config --local user.email "!FINAL_EMAIL!"
if errorlevel 1 (
    echo.
    echo ERROR: Could not set local Git user.email.
    echo.
    pause
    exit /b 1
)

rem ============================================================
rem Configure remotes
rem ============================================================

echo.
echo Configuring Git remotes...

if defined USE_FORK (
    git remote get-url upstream >nul 2>nul
    if errorlevel 1 (
        git remote add upstream "!FINAL_REPO_URL!"
    ) else (
        git remote set-url upstream "!FINAL_REPO_URL!"
    )

    if errorlevel 1 (
        echo.
        echo ERROR: Could not configure the upstream remote.
        echo.
        pause
        exit /b 1
    )
)

git remote get-url origin >nul 2>nul
if errorlevel 1 (
    git remote add origin "!TARGET_ORIGIN_URL!"
) else (
    git remote set-url origin "!TARGET_ORIGIN_URL!"
)

if errorlevel 1 (
    echo.
    echo ERROR: Could not configure the origin remote.
    echo.
    pause
    exit /b 1
)

set "CURRENT_BRANCH="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%A"

if not defined CURRENT_BRANCH (
    echo.
    echo Creating or switching to branch "!FINAL_BRANCH!"...
    git checkout -B "!FINAL_BRANCH!"
    if errorlevel 1 (
        echo.
        echo ERROR: Could not create or switch to branch "!FINAL_BRANCH!".
        echo.
        pause
        exit /b 1
    )
    set "CURRENT_BRANCH=!FINAL_BRANCH!"
)

rem ============================================================
rem Report setup
rem ============================================================

echo.
echo ============================================================
echo  GitHub setup summary
echo ============================================================
echo.
echo GitHub account:
echo   !GITHUB_LOGIN!
echo.
echo Repository:
echo   !REPO_SLUG!
echo.
if defined USE_FORK (
    echo Permission mode:
    echo   Fork workflow
    echo.
    echo origin:
    echo   !TARGET_ORIGIN_URL!
    echo.
    echo upstream:
    echo   !FINAL_REPO_URL!
) else (
    echo Permission mode:
    echo   Direct push
    echo.
    echo origin:
    echo   !TARGET_ORIGIN_URL!
)
echo.
echo Local branch:
echo   !CURRENT_BRANCH!
echo.
echo Local Git author:
echo   !FINAL_NAME! ^<!FINAL_EMAIL!^>
echo.

git status -sb
echo.
git remote -v
echo.

rem ============================================================
rem Push when a commit exists
rem ============================================================

git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (
    echo Login and repository permission setup are complete.
    echo.
    echo No commits exist yet, so there is nothing to push.
    echo.
    echo Next:
    echo   just_commit.bat
    echo   just_push.bat
    echo.
    pause
    exit /b 0
)

echo Pushing current branch and configuring upstream tracking...
git push -u origin "!CURRENT_BRANCH!"
if errorlevel 1 (
    echo.
    echo ERROR: Push failed.
    echo.
    echo Repository-level write permission was checked successfully,
    echo but a branch-protection rule, remote history, or another Git
    echo condition may have rejected this particular push.
    echo.
    echo Inspect the repository state with:
    echo   just_status.bat
    echo.
    pause
    exit /b 1
)

echo.
echo GitHub login, permission check, and push are complete.
echo.
pause
exit /b 0

rem ============================================================
rem Function: ConfigureFork
rem Purpose:
rem   Creates or reuses a personal fork when direct push access
rem   to the configured repository is unavailable.
rem Returns:
rem   0 fork ready and TARGET_ORIGIN_URL set
rem   1 fork setup failed or was cancelled
rem ============================================================

:ConfigureFork
set "FORK_CONFIRM="
set /p "FORK_CONFIRM=Create or use a fork under !GITHUB_LOGIN!? [Y/n]: "

if /I "!FORK_CONFIRM!"=="n" (
    echo.
    echo Cancelled. This account cannot push directly to !REPO_SLUG!.
    echo.
    exit /b 1
)

set "USE_FORK=1"
set "FORK_SLUG=!GITHUB_LOGIN!/!REPO_NAME!"
set "FORK_URL=https://github.com/!FORK_SLUG!.git"

echo.
echo Checking personal fork:
echo   !FORK_SLUG!
echo.

gh repo view "!FORK_SLUG!" >nul 2>nul
if errorlevel 1 goto :CreateFork

set "EXISTING_IS_FORK="
set "EXISTING_PARENT="
set "EXISTING_SOURCE="

for /f "delims=" %%A in ('gh api "repos/!FORK_SLUG!" --jq ".fork" 2^>nul') do set "EXISTING_IS_FORK=%%A"
for /f "delims=" %%A in ('gh api "repos/!FORK_SLUG!" --jq ".parent.full_name" 2^>nul') do set "EXISTING_PARENT=%%A"
for /f "delims=" %%A in ('gh api "repos/!FORK_SLUG!" --jq ".source.full_name" 2^>nul') do set "EXISTING_SOURCE=%%A"

if /I not "!EXISTING_IS_FORK!"=="true" (
    echo ERROR: !FORK_SLUG! already exists but is not a fork.
    echo Rename or remove that repository, or use an account that can
    echo push directly to !REPO_SLUG!.
    echo.
    exit /b 1
)

if /I "!EXISTING_PARENT!"=="!REPO_SLUG!" goto :ForkReady
if /I "!EXISTING_SOURCE!"=="!REPO_SLUG!" goto :ForkReady

echo ERROR: !FORK_SLUG! exists, but it is not a fork of:
echo   !REPO_SLUG!
echo.
exit /b 1

:CreateFork
echo Creating personal fork...
gh repo fork "!REPO_SLUG!" --clone=false --remote=false
if errorlevel 1 (
    echo.
    echo ERROR: GitHub could not create the fork.
    echo An empty repository cannot always be forked, and organization
    echo policy may also restrict forks.
    echo.
    exit /b 1
)

set "FORK_WAIT_COUNT=0"

:WaitForFork
set /a FORK_WAIT_COUNT+=1
gh repo view "!FORK_SLUG!" >nul 2>nul
if not errorlevel 1 goto :ForkReady

if !FORK_WAIT_COUNT! GEQ 15 (
    echo.
    echo ERROR: The fork was requested but did not become available.
    echo.
    exit /b 1
)

timeout /t 2 /nobreak >nul
goto :WaitForFork

:ForkReady
set "FORK_CAN_PUSH="
for /f "delims=" %%A in ('gh api "repos/!FORK_SLUG!" --jq ".permissions.push" 2^>nul') do set "FORK_CAN_PUSH=%%A"

if /I not "!FORK_CAN_PUSH!"=="true" (
    echo.
    echo ERROR: The logged-in account cannot push to its selected fork:
    echo   !FORK_SLUG!
    echo.
    exit /b 1
)

set "TARGET_ORIGIN_URL=!FORK_URL!"

echo Fork ready:
echo   !FORK_SLUG!
echo.
exit /b 0
