@echo off
:: ============================================================
:: git_doctor.bat
:: Diagnoses Git, GitHub CLI, project configuration, remotes,
:: tracking, ignored local dependencies, wrappers, and core helpers.
::
:: Usage:
::   call tools\git_doctor.bat
::   call tools\git_doctor.bat help
::
:: Returns: 0 when no required check fails
::          1 when one or more required checks fail
::          2 on invalid arguments
:: Requires: _common.bat, optional prepare.bat, git, optional gh,
::           :Main, :ParseArgs, :CheckProjectConfiguration,
::           :CheckDependencyPreparation, :CheckGit,
::           :CheckRemotesAndTracking, :CheckGitHub,
::           :CheckIgnoredDependencies, :CheckRootWrappers,
::           :CheckCoreFiles, :ShowResult, :Section, :OK,
::           :Warning, :Error, :NormalizeRepoURL,
::           :CheckIgnoredPath, :CheckRootWrapper,
::           :CheckRequiredFile, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_doctor.error.count=0"
set "app.git_doctor.warning.count=0"
set "app.git_doctor.git.exe="
set "app.git_doctor.git.version="
set "app.git_doctor.git.available="
set "app.git_doctor.gh.exe="
set "app.git_doctor.gh.version="
set "app.git_doctor.gh.available="
set "app.git_doctor.login="
set "app.git_doctor.repo.valid="
set "app.git_doctor.repo.root="
set "app.git_doctor.branch="
set "app.git_doctor.head="
set "app.git_doctor.identity.name="
set "app.git_doctor.identity.email="
set "app.git_doctor.origin.url="
set "app.git_doctor.origin.normalized="
set "app.git_doctor.config.normalized="
set "app.git_doctor.config.upstream="
set "app.git_doctor.upstream.url="
set "app.git_doctor.upstream.normalized="
set "app.git_doctor.config.upstream.normalized="
set "app.git_doctor.tracking="
set "app.git_doctor.tracking.remote="
set "app.git_doctor.ahead="
set "app.git_doctor.behind="
set "app.git_doctor.repo.slug="
set "app.git_doctor.repo.visibility="
set "app.git_doctor.can.push="
set "app.git_doctor.dirty="
set "app.git_doctor.wrapper.count=0"
set "app.git_doctor.help="
set "app.git_doctor.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_doctor.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_doctor.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_doctor.rc%
:: ============================================================
:: :Main
:: Parses arguments and runs all doctor sections before returning
:: the aggregate result.
::
:: Usage: call :Main [help]
::
:: Returns: 0 when no required check fails
::          1 when one or more required checks fail
::          2 on invalid arguments
:: Requires: :ParseArgs, :CheckProjectConfiguration,
::           :CheckDependencyPreparation, :CheckGit,
::           :CheckRemotesAndTracking, :CheckGitHub,
::           :CheckIgnoredDependencies, :CheckRootWrappers,
::           :CheckCoreFiles, :ShowResult, :ShowHelp
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gdm_ 2^>nul') do set "%%v="
if defined _gdm_rc (set "_gdm_rc=" & exit /b %_gdm_rc%)
call :ParseArgs %*
set "_gdm_rc=%errorlevel%"
if not "%_gdm_rc%"=="0" goto :Main
if defined app.git_doctor.help goto :_Main_help
echo.
echo ============================================================
echo  Git and GitHub doctor
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call :CheckProjectConfiguration
call :CheckDependencyPreparation
call :CheckGit
if defined app.git_doctor.repo.valid call :CheckRemotesAndTracking
if not defined app.git_doctor.repo.valid call :Warning "Remote and tracking checks were skipped because no working tree is available"
call :CheckGitHub
call :CheckIgnoredDependencies
call :CheckRootWrappers
call :CheckCoreFiles
call :ShowResult
set "_gdm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gdm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :CheckProjectConfiguration
:: Checks build_config.bat and required project configuration values.
::
:: Usage: call :CheckProjectConfiguration
::
:: Returns: 0
:: Requires: :Section, :OK, :Warning, :Error
:: ============================================================
:CheckProjectConfiguration
call :Section "Project configuration"
if exist "%CD%\build_config.bat" (call :OK "build_config.bat exists") else (call :Error "build_config.bat is missing")
if defined CFG_REPO_URL goto :_CheckProjectConfiguration_repo
call :Error "app.repo_url is not configured"
goto :_CheckProjectConfiguration_branch
:_CheckProjectConfiguration_repo
call :OK "app.repo_url is configured"
echo       %CFG_REPO_URL%
:_CheckProjectConfiguration_branch
if defined CFG_BRANCH goto :_CheckProjectConfiguration_branch_ok
call :Warning "app.git_branch is not configured; main will usually be assumed"
goto :_CheckProjectConfiguration_tools
:_CheckProjectConfiguration_branch_ok
call :OK "app.git_branch is configured"
echo       %CFG_BRANCH%
:_CheckProjectConfiguration_tools
if defined TOOLS_DIR goto :_CheckProjectConfiguration_tools_ok
call :Error "tools directory is not configured"
exit /b 0
:_CheckProjectConfiguration_tools_ok
call :OK "tools directory is configured"
echo       %TOOLS_DIR%
exit /b 0
:: ============================================================
:: :CheckDependencyPreparation
:: Runs prepare.bat repository when available.
::
:: Usage: call :CheckDependencyPreparation
::
:: Returns: 0
:: Requires: :Section, :OK, :Error
:: ============================================================
:CheckDependencyPreparation
call :Section "Dependency preparation"
if exist "%CD%\prepare.bat" goto :_CheckDependencyPreparation_run
call :Error "prepare.bat is missing"
exit /b 0
:_CheckDependencyPreparation_run
call "%CD%\prepare.bat" repository
if errorlevel 1 (call :Error "prepare.bat repository failed") else (call :OK "prepare.bat repository completed")
exit /b 0
:: ============================================================
:: :CheckGit
:: Checks Git availability, worktree identity, branch, HEAD, status,
:: identity, and staged and unstaged whitespace errors.
::
:: Usage: call :CheckGit
::
:: Returns: 0
:: Requires: :Section, :OK, :Warning, :Error, git
:: ============================================================
:CheckGit
call :Section "Git"
set "app.git_doctor.git.exe="
for /f "delims=" %%A in ('where git.exe 2^>nul') do if not defined app.git_doctor.git.exe set "app.git_doctor.git.exe=%%A"
if defined app.git_doctor.git.exe goto :_CheckGit_available
call :Error "Git was not found in PATH"
exit /b 0
:_CheckGit_available
set "app.git_doctor.git.available=1"
for /f "delims=" %%A in ('git --version 2^>nul') do set "app.git_doctor.git.version=%%A"
call :OK "Git is available"
echo       %app.git_doctor.git.exe%
if defined app.git_doctor.git.version echo       %app.git_doctor.git.version%
git rev-parse --is-inside-work-tree >nul 2>nul
if not errorlevel 1 goto :_CheckGit_worktree
call :Error "Current folder is not a Git working tree"
exit /b 0
:_CheckGit_worktree
set "app.git_doctor.repo.valid=1"
for /f "delims=" %%A in ('git rev-parse --show-toplevel 2^>nul') do set "app.git_doctor.repo.root=%%A"
call :OK "Current folder is inside a Git working tree"
if defined app.git_doctor.repo.root echo       %app.git_doctor.repo.root%
set "app.git_doctor.branch="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_doctor.branch=%%A"
if defined app.git_doctor.branch goto :_CheckGit_branch
call :Warning "No named branch is currently checked out"
goto :_CheckGit_head
:_CheckGit_branch
call :OK "Current branch"
echo       %app.git_doctor.branch%
if defined CFG_BRANCH if /I not "%app.git_doctor.branch%"=="%CFG_BRANCH%" goto :_CheckGit_branch_warning
goto :_CheckGit_head
:_CheckGit_branch_warning
call :Warning "Current branch differs from app.git_branch"
echo       configured: %CFG_BRANCH%
echo       current:    %app.git_doctor.branch%
:_CheckGit_head
git rev-parse --verify HEAD >nul 2>nul
if not errorlevel 1 goto :_CheckGit_head_ok
call :Warning "Repository has no commits yet"
goto :_CheckGit_status
:_CheckGit_head_ok
for /f "delims=" %%A in ('git rev-parse HEAD 2^>nul') do set "app.git_doctor.head=%%A"
call :OK "Repository has at least one commit"
if defined app.git_doctor.head echo       %app.git_doctor.head%
:_CheckGit_status
set "app.git_doctor.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_doctor.dirty=1"
if defined app.git_doctor.dirty goto :_CheckGit_dirty
call :OK "Working tree is clean"
goto :_CheckGit_identity
:_CheckGit_dirty
call :Warning "Working tree has local changes"
git status --short
:_CheckGit_identity
for /f "delims=" %%A in ('git config --get user.name 2^>nul') do set "app.git_doctor.identity.name=%%A"
for /f "delims=" %%A in ('git config --get user.email 2^>nul') do set "app.git_doctor.identity.email=%%A"
if defined app.git_doctor.identity.name goto :_CheckGit_name_ok
call :Warning "Git user.name is not configured"
goto :_CheckGit_email
:_CheckGit_name_ok
call :OK "Git user.name is configured"
echo       %app.git_doctor.identity.name%
:_CheckGit_email
if defined app.git_doctor.identity.email goto :_CheckGit_email_ok
call :Warning "Git user.email is not configured"
goto :_CheckGit_unstaged
:_CheckGit_email_ok
call :OK "Git user.email is configured"
echo       %app.git_doctor.identity.email%
:_CheckGit_unstaged
git diff --check >nul 2>nul
if errorlevel 1 (call :Warning "Unstaged changes contain whitespace errors") else (call :OK "Unstaged changes contain no whitespace errors")
git diff --cached --check >nul 2>nul
if errorlevel 1 (call :Warning "Staged changes contain whitespace errors") else (call :OK "Staged changes contain no whitespace errors")
exit /b 0
:: ============================================================
:: :CheckRemotesAndTracking
:: Checks origin and configured upstream consistency, fetches remote
:: references, checks branch tracking, and reports ahead and behind.
::
:: Usage: call :CheckRemotesAndTracking
::
:: Returns: 0
:: Requires: :Section, :OK, :Warning, :Error,
::           :NormalizeRepoURL, git
:: ============================================================
:CheckRemotesAndTracking
call :Section "Remotes and tracking"
set "app.git_doctor.origin.url="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_doctor.origin.url=%%A"
if defined app.git_doctor.origin.url goto :_CheckRemotes_origin
call :Error "origin remote is not configured"
goto :_CheckRemotes_upstream
:_CheckRemotes_origin
call :OK "origin remote exists"
echo       %app.git_doctor.origin.url%
if not defined CFG_REPO_URL goto :_CheckRemotes_origin_fetch
call :NormalizeRepoURL "%app.git_doctor.origin.url%" app.git_doctor.origin.normalized
call :NormalizeRepoURL "%CFG_REPO_URL%" app.git_doctor.config.normalized
if /I "%app.git_doctor.origin.normalized%"=="%app.git_doctor.config.normalized%" goto :_CheckRemotes_origin_match
call :Error "origin does not match app.repo_url"
echo       origin:       %app.git_doctor.origin.url%
echo       build_config: %CFG_REPO_URL%
goto :_CheckRemotes_origin_fetch
:_CheckRemotes_origin_match
call :OK "origin matches app.repo_url"
:_CheckRemotes_origin_fetch
git fetch --quiet origin
if errorlevel 1 (call :Error "Could not fetch origin") else (call :OK "Fetched origin successfully")
:_CheckRemotes_upstream
set "app.git_doctor.config.upstream="
if defined app.upstream_url set "app.git_doctor.config.upstream=%app.upstream_url%"
if not defined app.git_doctor.config.upstream if defined app.fork_source_url set "app.git_doctor.config.upstream=%app.fork_source_url%"
set "app.git_doctor.upstream.url="
for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "app.git_doctor.upstream.url=%%A"
if defined app.git_doctor.config.upstream goto :_CheckRemotes_upstream_required
if defined app.git_doctor.upstream.url goto :_CheckRemotes_upstream_unexpected
call :OK "No upstream remote is required by build_config.bat"
goto :_CheckRemotes_tracking
:_CheckRemotes_upstream_unexpected
call :Warning "upstream exists but build_config.bat has no upstream setting"
echo       %app.git_doctor.upstream.url%
goto :_CheckRemotes_upstream_fetch
:_CheckRemotes_upstream_required
if defined app.git_doctor.upstream.url goto :_CheckRemotes_upstream_compare
call :Error "build_config.bat defines an upstream source but the upstream remote is missing"
echo       configured: %app.git_doctor.config.upstream%
goto :_CheckRemotes_tracking
:_CheckRemotes_upstream_compare
call :OK "upstream remote exists"
echo       %app.git_doctor.upstream.url%
call :NormalizeRepoURL "%app.git_doctor.upstream.url%" app.git_doctor.upstream.normalized
call :NormalizeRepoURL "%app.git_doctor.config.upstream%" app.git_doctor.config.upstream.normalized
if /I "%app.git_doctor.upstream.normalized%"=="%app.git_doctor.config.upstream.normalized%" goto :_CheckRemotes_upstream_match
call :Error "upstream does not match the configured source repository"
echo       upstream:     %app.git_doctor.upstream.url%
echo       configured:   %app.git_doctor.config.upstream%
goto :_CheckRemotes_upstream_fetch
:_CheckRemotes_upstream_match
call :OK "upstream matches the configured source repository"
:_CheckRemotes_upstream_fetch
git fetch --quiet upstream
if errorlevel 1 (call :Warning "Could not fetch upstream") else (call :OK "Fetched upstream successfully")
:_CheckRemotes_tracking
if not defined app.git_doctor.branch (call :Warning "Tracking checks were skipped because no named branch is checked out" & exit /b 0)
git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>nul
if not errorlevel 1 goto :_CheckRemotes_tracking_ok
call :Warning "Current branch has no upstream tracking branch"
exit /b 0
:_CheckRemotes_tracking_ok
for /f "delims=" %%A in ('git rev-parse --abbrev-ref --symbolic-full-name @{u} 2^>nul') do set "app.git_doctor.tracking=%%A"
call :OK "Current branch has an upstream tracking branch"
echo       %app.git_doctor.tracking%
for /f "tokens=1 delims=/" %%A in ("%app.git_doctor.tracking%") do set "app.git_doctor.tracking.remote=%%A"
if /I "%app.git_doctor.tracking.remote%"=="origin" goto :_CheckRemotes_counts
if /I "%app.git_doctor.tracking.remote%"=="upstream" goto :_CheckRemotes_counts
if not defined app.git_doctor.tracking.remote goto :_CheckRemotes_counts
git fetch --quiet "%app.git_doctor.tracking.remote%"
if errorlevel 1 (call :Warning "Could not fetch the tracking remote") else (call :OK "Fetched the tracking remote successfully")
:_CheckRemotes_counts
set "app.git_doctor.ahead="
set "app.git_doctor.behind="
for /f "tokens=1,2" %%A in ('git rev-list --left-right --count HEAD...@{u} 2^>nul') do (
set "app.git_doctor.ahead=%%A"
set "app.git_doctor.behind=%%B"
)
if defined app.git_doctor.ahead goto :_CheckRemotes_counts_ok
call :Warning "Could not calculate ahead and behind counts"
exit /b 0
:_CheckRemotes_counts_ok
echo.
echo   Synchronization:
echo       ahead:  %app.git_doctor.ahead%
echo       behind: %app.git_doctor.behind%
if not "%app.git_doctor.ahead%"=="0" call :Warning "Local branch has commits that are not pushed"
if not "%app.git_doctor.behind%"=="0" call :Warning "Local branch is behind its tracking branch"
if "%app.git_doctor.ahead%"=="0" if "%app.git_doctor.behind%"=="0" call :OK "Local branch and tracking branch are synchronized"
exit /b 0
:: ============================================================
:: :CheckGitHub
:: Checks GitHub CLI availability, authentication, repository
:: visibility, visibility value, and direct push permission.
::
:: Usage: call :CheckGitHub
::
:: Returns: 0
:: Requires: :Section, :OK, :Warning, :Error, gh
:: ============================================================
:CheckGitHub
call :Section "GitHub CLI"
set "app.git_doctor.gh.exe="
for /f "delims=" %%A in ('where gh.exe 2^>nul') do if not defined app.git_doctor.gh.exe set "app.git_doctor.gh.exe=%%A"
if defined app.git_doctor.gh.exe goto :_CheckGitHub_available
call :Error "GitHub CLI was not found in PATH"
exit /b 0
:_CheckGitHub_available
set "app.git_doctor.gh.available=1"
for /f "delims=" %%A in ('gh --version 2^>nul') do if not defined app.git_doctor.gh.version set "app.git_doctor.gh.version=%%A"
call :OK "GitHub CLI is available"
echo       %app.git_doctor.gh.exe%
if defined app.git_doctor.gh.version echo       %app.git_doctor.gh.version%
gh auth status --hostname github.com >nul 2>nul
if not errorlevel 1 goto :_CheckGitHub_authenticated
call :Warning "GitHub CLI is not logged in"
echo       Run just_login.bat before GitHub operations.
exit /b 0
:_CheckGitHub_authenticated
for /f "delims=" %%A in ('gh api user --jq ".login" 2^>nul') do set "app.git_doctor.login=%%A"
call :OK "GitHub CLI is authenticated"
if defined app.git_doctor.login echo       %app.git_doctor.login%
if not defined CFG_REPO_URL exit /b 0
set "app.git_doctor.repo.slug="
for /f "delims=" %%A in ('gh repo view "%CFG_REPO_URL%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_doctor.repo.slug=%%A"
if defined app.git_doctor.repo.slug goto :_CheckGitHub_repo
call :Error "Configured GitHub repository was not found or is not visible"
echo       %CFG_REPO_URL%
exit /b 0
:_CheckGitHub_repo
for /f "delims=" %%A in ('gh repo view "%CFG_REPO_URL%" --json visibility --jq ".visibility" 2^>nul') do set "app.git_doctor.repo.visibility=%%A"
for /f "delims=" %%A in ('gh api "repos/%app.git_doctor.repo.slug%" --jq ".permissions.push" 2^>nul') do set "app.git_doctor.can.push=%%A"
call :OK "Configured GitHub repository is visible"
echo       %app.git_doctor.repo.slug%
if defined app.git_doctor.repo.visibility echo       visibility: %app.git_doctor.repo.visibility%
if /I "%app.git_doctor.can.push%"=="true" goto :_CheckGitHub_push
call :Warning "Logged-in account does not have direct push permission"
exit /b 0
:_CheckGitHub_push
call :OK "Logged-in account has push permission"
exit /b 0
:: ============================================================
:: :CheckIgnoredDependencies
:: Checks expected local-only paths against Git ignore rules.
::
:: Usage: call :CheckIgnoredDependencies
::
:: Returns: 0
:: Requires: :Section, :Warning, :CheckIgnoredPath, git
:: ============================================================
:CheckIgnoredDependencies
call :Section "Ignored local dependencies"
if defined app.git_doctor.repo.valid goto :_CheckIgnoredDependencies_run
call :Warning "Ignored-path checks were skipped because no working tree is available"
exit /b 0
:_CheckIgnoredDependencies_run
call :CheckIgnoredPath "tools\git"
call :CheckIgnoredPath "tools\gh"
call :CheckIgnoredPath "tools\downloads"
call :CheckIgnoredPath "tools\logs"
call :CheckIgnoredPath "prepare.log"
call :CheckIgnoredPath "env.bat"
exit /b 0
:: ============================================================
:: :CheckRootWrappers
:: Checks each root just_*.bat wrapper for a matching tools helper.
::
:: Usage: call :CheckRootWrappers
::
:: Returns: 0
:: Requires: :Section, :Warning, :CheckRootWrapper
:: ============================================================
:CheckRootWrappers
call :Section "Root helper wrappers"
set "app.git_doctor.wrapper.count=0"
for %%F in ("%CD%\just_*.bat") do if exist "%%~fF" call :CheckRootWrapper "%%~nxF"
if "%app.git_doctor.wrapper.count%"=="0" call :Warning "No root just_*.bat wrappers were found"
exit /b 0
:: ============================================================
:: :CheckCoreFiles
:: Checks only the shared and help files required by the current
:: integrated-pause architecture.
::
:: Usage: call :CheckCoreFiles
::
:: Returns: 0
:: Requires: :Section, :CheckRequiredFile
:: ============================================================
:CheckCoreFiles
call :Section "Core helper files"
call :CheckRequiredFile "tools\_common.bat"
call :CheckRequiredFile "tools\_call_helper.bat"
call :CheckRequiredFile "tools\git_help.bat"
call :CheckRequiredFile "tools\git_help_short.bat"
exit /b 0
:: ============================================================
:: :ShowResult
:: Displays aggregate error and warning counts and returns final
:: doctor status.
::
:: Usage: call :ShowResult
::
:: Returns: 0 when no required check fails
::          1 when one or more errors exist
:: Requires: :Section
:: ============================================================
:ShowResult
call :Section "Doctor result"
echo Errors:
echo   %app.git_doctor.error.count%
echo.
echo Warnings:
echo   %app.git_doctor.warning.count%
echo.
if "%app.git_doctor.error.count%"=="0" goto :_ShowResult_healthy
echo One or more required checks failed.
echo Review the ERROR lines above before relying on GitHub operations.
exit /b 1
:_ShowResult_healthy
echo No required check failed.
if "%app.git_doctor.warning.count%"=="0" (echo The project appears healthy.) else (echo The project is operational, with warnings noted above.)
exit /b 0
:: ============================================================
:: :Section
:: Prints a doctor section heading.
::
:: Usage: call :Section "title"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:Section
echo.
echo ============================================================
echo  %~1
echo ============================================================
echo.
exit /b 0
:: ============================================================
:: :OK
:: Prints a successful doctor check.
::
:: Usage: call :OK "message"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:OK
echo [OK]      %~1
exit /b 0
:: ============================================================
:: :Warning
:: Prints a warning and increments the warning counter.
::
:: Usage: call :Warning "message"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:Warning
echo [WARNING] %~1
set /a app.git_doctor.warning.count+=1
exit /b 0
:: ============================================================
:: :Error
:: Prints an error and increments the error counter.
::
:: Usage: call :Error "message"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:Error
echo [ERROR]   %~1
set /a app.git_doctor.error.count+=1
exit /b 0
:: ============================================================
:: :NormalizeRepoURL
:: Normalizes common GitHub HTTPS and SSH URL forms for comparison.
::
:: Usage: call :NormalizeRepoURL "URL" outputVariable
::
:: Output:
::   outputVariable  normalized URL without trailing slash or .git
::
:: Returns: 0
:: Requires: none
:: ============================================================
:NormalizeRepoURL
for /f "tokens=1 delims==" %%v in ('set gdn_ 2^>nul') do set "%%v="
if defined _gdn_rc (set "_gdn_rc=" & exit /b %_gdn_rc%)
set "gdn_value=%~1"
set "gdn_output=%~2"
set "gdn_value=%gdn_value:git@github.com:=https://github.com/%"
set "gdn_value=%gdn_value:ssh://git@github.com/=https://github.com/%"
if /I "%gdn_value:~-4%"==".git" set "gdn_value=%gdn_value:~0,-4%"
if "%gdn_value:~-1%"=="/" set "gdn_value=%gdn_value:~0,-1%"
if defined gdn_output set "%gdn_output%=%gdn_value%"
set "_gdn_rc=0" & goto :NormalizeRepoURL
:: ============================================================
:: :CheckIgnoredPath
:: Reports whether an existing local-only path is ignored.
::
:: Usage: call :CheckIgnoredPath "relative path"
::
:: Returns: 0
:: Requires: :OK, :Error, git
:: ============================================================
:CheckIgnoredPath
for /f "tokens=1 delims==" %%v in ('set gdi_ 2^>nul') do set "%%v="
if defined _gdi_rc (set "_gdi_rc=" & exit /b %_gdi_rc%)
set "gdi_path=%~1"
if exist "%gdi_path%" goto :_CheckIgnoredPath_exists
echo [INFO]    %gdi_path% is not present
set "_gdi_rc=0" & goto :CheckIgnoredPath
:_CheckIgnoredPath_exists
git check-ignore -q -- "%gdi_path%" >nul 2>nul
if errorlevel 1 (call :Error "%gdi_path% exists but is not ignored") else (call :OK "%gdi_path% is ignored")
set "_gdi_rc=0" & goto :CheckIgnoredPath
:: ============================================================
:: :CheckRootWrapper
:: Checks one root wrapper for a matching tools helper.
::
:: Usage: call :CheckRootWrapper "just_name.bat"
::
:: Returns: 0
:: Requires: :OK, :Error
:: ============================================================
:CheckRootWrapper
for /f "tokens=1 delims==" %%v in ('set gdw_ 2^>nul') do set "%%v="
if defined _gdw_rc (set "_gdw_rc=" & exit /b %_gdw_rc%)
set "gdw_name=%~1"
set /a app.git_doctor.wrapper.count+=1
if exist "%CD%\tools\%gdw_name%" goto :_CheckRootWrapper_ok
call :Error "%gdw_name% has no matching tools helper"
set "_gdw_rc=0" & goto :CheckRootWrapper
:_CheckRootWrapper_ok
call :OK "%gdw_name% has a matching tools helper"
set "_gdw_rc=0" & goto :CheckRootWrapper
:: ============================================================
:: :CheckRequiredFile
:: Checks one required helper file.
::
:: Usage: call :CheckRequiredFile "relative path"
::
:: Returns: 0
:: Requires: :OK, :Error
:: ============================================================
:CheckRequiredFile
if exist "%~1" (call :OK "%~1 exists") else (call :Error "%~1 is missing")
exit /b 0
:: ============================================================
:: :ParseArgs
:: Parses the optional help argument.
::
:: Usage: call :ParseArgs [help]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_help
set "app.git_doctor.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays doctor usage and exit-code behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_doctor.bat
echo.
echo Usage:
echo   git_doctor.bat
echo.
echo Exit codes:
echo   0  no required check failed
echo   1  one or more required checks failed
echo   2  invalid arguments
echo.
echo Warnings do not change the exit code.
echo.
exit /b 0
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when the outermost launcher is the cmd.exe /c target.
::
:: Usage: call :PauseIfNeeded
::
:: Returns: 0
:: Requires: :IsConsole
:: ============================================================
:PauseIfNeeded
for /f "tokens=1 delims==" %%v in ('set pif_ 2^>nul') do set "%%v="
if defined _pif_rc (set "_pif_rc=" & exit /b %_pif_rc%)
call :IsConsole
if not errorlevel 1 (set "_pif_rc=0" & goto :PauseIfNeeded)
echo.
pause
set "_pif_rc=0" & goto :PauseIfNeeded
:: ============================================================
:: :IsConsole
:: Detects whether the outermost launcher is running in an existing
:: interactive console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 when running in an existing console
::          1 when the outermost launcher is the cmd.exe /c target
:: Requires: find.exe
:: ============================================================
:IsConsole
setlocal EnableDelayedExpansion
set "ic_cmdline=!CMDCMDLINE!"
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I " /c " >nul
if errorlevel 1 (endlocal & exit /b 0)
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I "!app.launch.name!" >nul
if errorlevel 1 (endlocal & exit /b 0)
endlocal & exit /b 1
