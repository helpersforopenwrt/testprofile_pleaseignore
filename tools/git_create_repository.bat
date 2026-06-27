@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================
rem git_create_repository.bat
rem
rem Creates a new, empty GitHub repository described by
rem build_config.bat, then uploads the current project root.
rem
rem Requirements:
rem   Git for Windows
rem   GitHub CLI ("gh")
rem
rem Important:
rem   This preserves the current local Git history.
rem   If this folder was cloned from a template repository, that
rem   template history will also be pushed to the new repository.
rem ============================================================

call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Create GitHub repository
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Project root:
echo   %CD%
echo.

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

if not defined app.git.exe (
    echo ERROR: prepare.bat did not export app.git.exe.
    echo.
    pause
    exit /b 1
)

if not defined app.gh.exe (
    echo ERROR: prepare.bat did not export app.gh.exe.
    echo.
    pause
    exit /b 1
)

echo.
echo Git:
echo   %app.git.exe%
echo.
echo GitHub CLI:
echo   %app.gh.exe%
echo.

if not defined CFG_REPO_URL (
    echo ERROR: No GitHub repository URL is configured.
    echo.
    echo Add this to build_config.bat:
    echo   set "app.repo_url=https://github.com/OWNER/REPOSITORY.git"
    echo.
    pause
    exit /b 1
)

rem ------------------------------------------------------------
rem Convert the configured GitHub URL into OWNER/REPOSITORY.
rem An explicit app.repo_slug value may be used as an override.
rem ------------------------------------------------------------

set "REPO_SLUG="
if defined app.repo_slug set "REPO_SLUG=%app.repo_slug%"

if not defined REPO_SLUG (
    for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$u=$env:CFG_REPO_URL.Trim(); if($u -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?/?$'){ Write-Output ($Matches.owner + '/' + $Matches.repo) }"`) do (
        set "REPO_SLUG=%%A"
    )
)

if not defined REPO_SLUG (
    echo ERROR: Could not determine OWNER/REPOSITORY from:
    echo   %CFG_REPO_URL%
    echo.
    echo Expected forms include:
    echo   https://github.com/OWNER/REPOSITORY.git
    echo   https://github.com/OWNER/REPOSITORY
    echo   git@github.com:OWNER/REPOSITORY.git
    echo.
    echo You may also set this explicitly:
    echo   set "app.repo_slug=OWNER/REPOSITORY"
    echo.
    pause
    exit /b 1
)

rem ------------------------------------------------------------
rem Repository visibility.
rem Safe default: private.
rem Supported values: private, public, internal.
rem ------------------------------------------------------------

set "REPO_VISIBILITY="
if defined app.repo_visibility set "REPO_VISIBILITY=%app.repo_visibility%"
if defined app.github_visibility set "REPO_VISIBILITY=%app.github_visibility%"

if not defined REPO_VISIBILITY (
    echo Repository visibility is not configured.
    echo.
    echo Choices:
    echo   private
    echo   public
    echo   internal
    echo.
    set /p "REPO_VISIBILITY=Visibility [private]: "
)

if not defined REPO_VISIBILITY set "REPO_VISIBILITY=private"

if /I "%REPO_VISIBILITY%"=="private" goto VisibilityOK
if /I "%REPO_VISIBILITY%"=="public" goto VisibilityOK
if /I "%REPO_VISIBILITY%"=="internal" goto VisibilityOK

echo.
echo ERROR: Unsupported repository visibility:
echo   %REPO_VISIBILITY%
echo.
echo Use private, public, or internal.
echo.
pause
exit /b 1

:VisibilityOK
set "VISIBILITY_FLAG=--%REPO_VISIBILITY%"

rem ------------------------------------------------------------
rem Authenticate with GitHub CLI.
rem ------------------------------------------------------------

echo Checking GitHub login...
"%app.gh.exe%" auth status --hostname github.com >nul 2>nul
if errorlevel 1 (
    echo.
    echo GitHub login is required.
    echo A browser window may open.
    echo.
    "%app.gh.exe%" auth login --hostname github.com --git-protocol https --web
    if errorlevel 1 (
        echo.
        echo ERROR: GitHub login failed or was cancelled.
        echo.
        pause
        exit /b 1
    )
)

echo.
echo Logged-in GitHub account:
"%app.gh.exe%" api user --jq ".login"
if errorlevel 1 (
    echo.
    echo ERROR: Could not verify the logged-in GitHub account.
    echo.
    pause
    exit /b 1
)

"%app.gh.exe%" auth setup-git --hostname github.com >nul 2>nul
if errorlevel 1 (
    echo.
    echo WARNING: GitHub CLI could not configure Git authentication.
    echo The repository operation may still work with existing credentials.
    echo.
)

rem ------------------------------------------------------------
rem Refuse to overwrite an existing GitHub repository.
rem ------------------------------------------------------------

echo.
echo Checking whether the repository already exists...
"%app.gh.exe%" repo view "%REPO_SLUG%" >nul 2>nul
if not errorlevel 1 (
    echo.
    echo ERROR: This GitHub repository already exists:
    echo   https://github.com/%REPO_SLUG%
    echo.
    echo Nothing was created or overwritten.
    echo Change app.repo_url in build_config.bat to a new name.
    echo.
    pause
    exit /b 1
)

rem ------------------------------------------------------------
rem Inspect the current local repository and origin.
rem ------------------------------------------------------------

set "OLD_ORIGIN="
set "CURRENT_BRANCH="

if exist ".git" (
    for /f "delims=" %%A in ('"%app.git.exe%" remote get-url origin 2^>nul') do set "OLD_ORIGIN=%%A"
    for /f "delims=" %%A in ('"%app.git.exe%" branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%A"
)

if not defined CFG_BRANCH set "CFG_BRANCH=main"

echo.
echo ============================================================
echo  Planned operation
echo ============================================================
echo.
echo GitHub repository:
echo   %REPO_SLUG%
echo.
echo Visibility:
echo   %REPO_VISIBILITY%
echo.
echo Configured URL:
echo   %CFG_REPO_URL%
echo.
echo Branch to publish:
echo   %CFG_BRANCH%
echo.
echo Local history:
if exist ".git" (
    echo   Existing Git history will be preserved.
) else (
    echo   A new local Git repository will be initialized.
)
echo.
if defined OLD_ORIGIN (
    echo Current origin:
    echo   %OLD_ORIGIN%
    echo.
    echo After GitHub creates the new repository, origin will become:
    echo   %CFG_REPO_URL%
    echo.
)

echo This script will:
echo   stage all non-ignored files under the project root
echo   create a commit if one is needed
echo   create the new GitHub repository
echo   set origin to the configured URL
echo   push the configured branch
echo.
echo It will not overwrite an existing GitHub repository.
echo.

set "CONFIRM="
set /p "CONFIRM=Type CREATE to continue: "
if not "%CONFIRM%"=="CREATE" (
    echo.
    echo Cancelled.
    echo.
    pause
    exit /b 0
)

rem ------------------------------------------------------------
rem Initialize local Git if needed.
rem ------------------------------------------------------------

if not exist ".git" (
    echo.
    echo Initializing local Git repository...

    "%app.git.exe%" init -b "%CFG_BRANCH%" >nul 2>nul
    if errorlevel 1 (
        "%app.git.exe%" init
        if errorlevel 1 (
            echo.
            echo ERROR: git init failed.
            echo.
            pause
            exit /b 1
        )

        "%app.git.exe%" checkout -B "%CFG_BRANCH%"
        if errorlevel 1 (
            echo.
            echo ERROR: Could not create branch "%CFG_BRANCH%".
            echo.
            pause
            exit /b 1
        )
    )
)

rem ------------------------------------------------------------
rem Ensure there is a usable current branch.
rem ------------------------------------------------------------

set "CURRENT_BRANCH="
for /f "delims=" %%A in ('"%app.git.exe%" branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%A"

if not defined CURRENT_BRANCH (
    echo.
    echo Creating branch "%CFG_BRANCH%"...
    "%app.git.exe%" checkout -B "%CFG_BRANCH%"
    if errorlevel 1 (
        echo.
        echo ERROR: Could not create or switch to branch "%CFG_BRANCH%".
        echo.
        pause
        exit /b 1
    )
    set "CURRENT_BRANCH=%CFG_BRANCH%"
)

if /I not "%CURRENT_BRANCH%"=="%CFG_BRANCH%" (
    echo.
    echo Current local branch:
    echo   %CURRENT_BRANCH%
    echo Configured branch:
    echo   %CFG_BRANCH%
    echo.
    echo Renaming the current branch to "%CFG_BRANCH%"...

    "%app.git.exe%" branch -M "%CFG_BRANCH%"
    if errorlevel 1 (
        echo.
        echo ERROR: Could not rename the current branch.
        echo Resolve the local branch layout, then run this script again.
        echo.
        pause
        exit /b 1
    )

    set "CURRENT_BRANCH=%CFG_BRANCH%"
)

rem ------------------------------------------------------------
rem Stage and commit the current project when needed.
rem This occurs before GitHub repository creation, so a commit
rem failure does not leave an unwanted empty remote repository.
rem ------------------------------------------------------------

echo.
echo Staging current project files...
"%app.git.exe%" add --all
if errorlevel 1 (
    echo.
    echo ERROR: git add failed.
    echo.
    pause
    exit /b 1
)

set "HAS_HEAD="
"%app.git.exe%" rev-parse --verify HEAD >nul 2>nul
if not errorlevel 1 set "HAS_HEAD=1"

set "STAGED_CHANGES="
"%app.git.exe%" diff --cached --quiet
if errorlevel 1 set "STAGED_CHANGES=1"

if not defined HAS_HEAD set "STAGED_CHANGES=1"

if defined STAGED_CHANGES (
    set "INITIAL_MESSAGE="
    if defined app.initial_commit_message set "INITIAL_MESSAGE=!app.initial_commit_message!"
    if not defined INITIAL_MESSAGE set "INITIAL_MESSAGE=Create %APP_DISPLAY_NAME% repository"

    echo.
    echo Creating local commit:
    echo   !INITIAL_MESSAGE!
    echo.

    "%app.git.exe%" commit -m "!INITIAL_MESSAGE!"
    if errorlevel 1 (
        echo.
        echo ERROR: Could not create the local commit.
        echo.
        echo Confirm that Git user.name and user.email are configured.
        echo You may run:
        echo   git config --global user.name "Your Name"
        echo   git config --global user.email "you@example.com"
        echo.
        pause
        exit /b 1
    )
) else (
    echo.
    echo No new local commit is needed.
)

"%app.git.exe%" rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (
    echo.
    echo ERROR: No commit exists to upload.
    echo.
    pause
    exit /b 1
)

rem ------------------------------------------------------------
rem Create the empty repository on GitHub.
rem ------------------------------------------------------------

echo.
echo Creating GitHub repository:
echo   %REPO_SLUG%
echo.

"%app.gh.exe%" repo create "%REPO_SLUG%" %VISIBILITY_FLAG%
if errorlevel 1 (
    echo.
    echo ERROR: GitHub repository creation failed.
    echo.
    echo Possible causes:
    echo   the name was created by someone else
    echo   the logged-in account cannot create repositories for the owner
    echo   organization policy does not allow the selected visibility
    echo   network or GitHub service problem
    echo.
    echo Your local commit is safe and was not pushed.
    echo.
    pause
    exit /b 1
)

rem ------------------------------------------------------------
rem Point origin at the new repository.
rem ------------------------------------------------------------

echo.
echo Configuring origin...

"%app.git.exe%" remote get-url origin >nul 2>nul
if errorlevel 1 (
    "%app.git.exe%" remote add origin "%CFG_REPO_URL%"
) else (
    "%app.git.exe%" remote set-url origin "%CFG_REPO_URL%"
)

if errorlevel 1 (
    echo.
    echo ERROR: The GitHub repository was created, but origin could not be set.
    echo.
    echo Repository:
    echo   https://github.com/%REPO_SLUG%
    echo.
    echo Fix origin manually, then push:
    echo   git remote set-url origin "%CFG_REPO_URL%"
    echo   git push -u origin "%CFG_BRANCH%"
    echo.
    pause
    exit /b 1
)

rem ------------------------------------------------------------
rem Push the current branch to the new empty repository.
rem ------------------------------------------------------------

echo.
echo Uploading project to GitHub...
"%app.git.exe%" push -u origin "%CFG_BRANCH%"
if errorlevel 1 (
    echo.
    echo ERROR: The repository was created, but the upload failed.
    echo.
    echo Repository:
    echo   https://github.com/%REPO_SLUG%
    echo.
    echo The local commit is safe.
    echo After resolving the problem, retry with:
    echo   git push -u origin "%CFG_BRANCH%"
    echo.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Repository created successfully
echo ============================================================
echo.
echo GitHub:
echo   https://github.com/%REPO_SLUG%
echo.
echo Local origin:
"%app.git.exe%" remote get-url origin
echo.
echo Branch:
"%app.git.exe%" branch --show-current
echo.
echo Latest commit:
"%app.git.exe%" log -1 --oneline
echo.
pause
exit /b 0
