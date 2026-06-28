@echo off
:: ============================================================
:: git_fork.bat
:: Creates or reuses a true GitHub fork for a different owner. When
:: source and target owners match, delegates to repository creation
:: because GitHub does not support same-owner forks.
::
:: Usage:
::   call tools\git_fork.bat
::   call tools\git_fork.bat source OWNER/REPO owner TARGET_OWNER
::   call tools\git_fork.bat source OWNER/REPO owner TARGET_OWNER name NEW_NAME
::   call tools\git_fork.bat source OWNER/REPO owner SAME_OWNER name COPY_NAME
::
:: Returns: 0 on successful configuration, delegated success, cancellation,
::            or help
::          1 on dependency, authentication, source, target, repository,
::            fork, permission, configuration, or remote failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, gh, PowerShell,
::           git_create_repository.bat, :Main, :AuthenticateGitHub,
::           :ResolveSource, :ResolveTarget, :ValidateTrueForkTarget,
::           :ValidateLocalRepository, :ShowTrueForkPlan, :EnsureTrueFork,
::           :ValidateExistingFork, :WaitForRepository, :CaptureRemotes,
::           :ConfigureForkRemotes, :RestoreRemotes, :TrySetTracking,
::           :UpdateBuildConfig, :RestoreBuildConfig, :DelegateCopy,
::           :ParseArgs, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_fork.source.input="
set "app.git_fork.source.slug="
set "app.git_fork.source.owner="
set "app.git_fork.source.name="
set "app.git_fork.source.web="
set "app.git_fork.source.url="
set "app.git_fork.target.owner="
set "app.git_fork.target.type="
set "app.git_fork.target.name="
set "app.git_fork.target.slug="
set "app.git_fork.target.url="
set "app.git_fork.initial.slug="
set "app.git_fork.visibility="
set "app.git_fork.login="
set "app.git_fork.confirm="
set "app.git_fork.current.branch="
set "app.git_fork.current.origin="
set "app.git_fork.current.origin.slug="
set "app.git_fork.current.origin.parent="
set "app.git_fork.current.origin.source="
set "app.git_fork.current.upstream="
set "app.git_fork.current.upstream.slug="
set "app.git_fork.current.upstream.parent="
set "app.git_fork.current.upstream.source="
set "app.git_fork.can.push="
set "app.git_fork.dirty="
set "app.git_fork.help="
set "app.git_fork.backup="
set "app.git_fork.logs="
set "app.git_fork.timestamp="
set "app.git_fork.existing.fork="
set "app.git_fork.existing.parent="
set "app.git_fork.existing.source="
set "app.git_fork.check.slug="
set "app.git_fork.original.origin.exists="
set "app.git_fork.original.origin.url="
set "app.git_fork.original.upstream.exists="
set "app.git_fork.original.upstream.url="
set "app.git_fork.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_fork.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_fork.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_fork.rc%
:: ============================================================
:: :Main
:: Resolves source and target repositories, delegates same-owner
:: copies, or creates and transactionally configures a true fork.
::
:: Usage: call :Main [source REPO] [owner OWNER] [name NAME] [visibility VALUE]
::
:: Returns: 0 on successful configuration, delegated success, cancellation,
::            or help
::          1 on dependency, authentication, source, target, repository,
::            fork, permission, configuration, or remote failure
::          2 on invalid arguments
:: Requires: :AuthenticateGitHub, :ResolveSource, :ResolveTarget,
::           :ValidateTrueForkTarget, :ValidateLocalRepository,
::           :ShowTrueForkPlan, :EnsureTrueFork, :CaptureRemotes,
::           :UpdateBuildConfig, :ConfigureForkRemotes,
::           :RestoreBuildConfig, :RestoreRemotes, :TrySetTracking,
::           :DelegateCopy, :ParseArgs, :ShowHelp
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gfm_ 2^>nul') do set "%%v="
if defined _gfm_rc (set "_gfm_rc=" & exit /b %_gfm_rc%)
call :ParseArgs %*
set "_gfm_rc=%errorlevel%"
if not "%_gfm_rc%"=="0" goto :Main
if defined app.git_fork.help goto :_Main_help
echo.
echo ============================================================
echo  Fork or copy GitHub repository
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
if exist "%CD%\prepare.bat" goto :_Main_prepare
echo ERROR: prepare.bat was not found in the project root.
set "_gfm_rc=1" & goto :Main
:_Main_prepare
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_gfm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git is unavailable after preparation. & set "_gfm_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI is unavailable after preparation. & set "_gfm_rc=1" & goto :Main)
where powershell.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Windows PowerShell is unavailable. & set "_gfm_rc=1" & goto :Main)
call :AuthenticateGitHub
if errorlevel 1 (set "_gfm_rc=%errorlevel%" & goto :Main)
call :ResolveSource
if errorlevel 1 (set "_gfm_rc=%errorlevel%" & goto :Main)
call :ResolveTarget
if errorlevel 1 (set "_gfm_rc=%errorlevel%" & goto :Main)
if /I "%app.git_fork.target.owner%"=="%app.git_fork.source.owner%" goto :_Main_copy
call :ValidateTrueForkTarget
if errorlevel 1 (set "_gfm_rc=%errorlevel%" & goto :Main)
call :ValidateLocalRepository
if errorlevel 1 (set "_gfm_rc=%errorlevel%" & goto :Main)
call :ShowTrueForkPlan
set /p "app.git_fork.confirm=Type FORK to continue: "
if "%app.git_fork.confirm%"=="FORK" goto :_Main_create
echo.
echo Cancelled. Nothing was changed.
set "_gfm_rc=0" & goto :Main
:_Main_create
call :EnsureTrueFork
if errorlevel 1 (set "_gfm_rc=%errorlevel%" & goto :Main)
for /f "delims=" %%A in ('gh api "repos/%app.git_fork.target.slug%" --jq ".permissions.push" 2^>nul') do set "app.git_fork.can.push=%%A"
if /I not "%app.git_fork.can.push%"=="true" goto :_Main_no_push
call :CaptureRemotes
call :UpdateBuildConfig
if errorlevel 1 goto :_Main_config_failed
call :ConfigureForkRemotes
if errorlevel 1 goto :_Main_remote_failed
call :TrySetTracking
echo.
echo ============================================================
echo  Fork configured successfully
echo ============================================================
echo.
echo Source:
echo   %app.git_fork.source.slug%
echo.
echo Fork:
echo   %app.git_fork.target.slug%
echo.
echo Remotes:
git remote -v
echo.
echo build_config.bat was updated.
echo Backup:
echo   %app.git_fork.backup%
echo.
echo The configuration change is not committed yet.
echo Review it, then run:
echo   just_diff.bat
echo   just_commit.bat "Configure fork %app.git_fork.target.slug%"
echo   just_push.bat
echo.
set "_gfm_rc=0" & goto :Main
:_Main_no_push
echo ERROR: The logged-in account cannot push to the resulting fork:
echo   %app.git_fork.target.slug%
echo.
echo The fork remains on GitHub, but local configuration was not changed.
set "_gfm_rc=1" & goto :Main
:_Main_config_failed
echo.
echo ERROR: The fork exists, but build_config.bat could not be updated.
echo Local remotes were not changed.
echo Fork:
echo   https://github.com/%app.git_fork.target.slug%
set "_gfm_rc=1" & goto :Main
:_Main_remote_failed
call :RestoreBuildConfig
call :RestoreRemotes
echo.
echo ERROR: The fork exists, but local remote configuration failed.
echo build_config.bat and the original remotes were restored where possible.
echo Fork:
echo   https://github.com/%app.git_fork.target.slug%
set "_gfm_rc=1" & goto :Main
:_Main_copy
call :DelegateCopy
set "_gfm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gfm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :AuthenticateGitHub
:: Authenticates GitHub CLI when necessary and configures Git
:: credential integration.
::
:: Usage: call :AuthenticateGitHub
::
:: Output:
::   app.git_fork.login  authenticated GitHub login
::
:: Returns: 0 when authenticated
::          1 on login, account, or credential-setup failure
:: Requires: gh
:: ============================================================
:AuthenticateGitHub
for /f "tokens=1 delims==" %%v in ('set gfa_ 2^>nul') do set "%%v="
if defined _gfa_rc (set "_gfa_rc=" & exit /b %_gfa_rc%)
echo Checking GitHub login...
gh auth status --hostname github.com >nul 2>nul
if not errorlevel 1 goto :_AuthenticateGitHub_ready
echo GitHub login is required.
echo A browser window will open for secure login.
echo.
gh auth login --hostname github.com --git-protocol https --web
if errorlevel 1 (echo ERROR: GitHub login failed or was cancelled. & set "_gfa_rc=1" & goto :AuthenticateGitHub)
:_AuthenticateGitHub_ready
for /f "delims=" %%A in ('gh api user --jq ".login" 2^>nul') do set "app.git_fork.login=%%A"
if not defined app.git_fork.login (echo ERROR: Could not determine the logged-in GitHub account. & set "_gfa_rc=1" & goto :AuthenticateGitHub)
gh auth setup-git --hostname github.com >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI could not configure Git authentication. & set "_gfa_rc=1" & goto :AuthenticateGitHub)
echo Logged in as:
echo   %app.git_fork.login%
echo.
set "_gfa_rc=0" & goto :AuthenticateGitHub
:: ============================================================
:: :ResolveSource
:: Resolves the source repository from arguments, project settings,
:: upstream, origin, or an interactive prompt.
::
:: Usage: call :ResolveSource
::
:: Output:
::   app.git_fork.source.slug, owner, name, web, and URL
::
:: Returns: 0 when resolved
::          1 when missing or inaccessible
:: Requires: git, gh
:: ============================================================
:ResolveSource
for /f "tokens=1 delims==" %%v in ('set gfs_ 2^>nul') do set "%%v="
if defined _gfs_rc (set "_gfs_rc=" & exit /b %_gfs_rc%)
if defined app.git_fork.source.input goto :_ResolveSource_normalize
if defined app.fork_source_url set "app.git_fork.source.input=%app.fork_source_url%"
if defined app.git_fork.source.input goto :_ResolveSource_normalize
if defined app.upstream_url set "app.git_fork.source.input=%app.upstream_url%"
if defined app.git_fork.source.input goto :_ResolveSource_normalize
if defined CFG_REPO_URL set "app.git_fork.source.input=%CFG_REPO_URL%"
if defined app.git_fork.source.input goto :_ResolveSource_normalize
for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "app.git_fork.source.input=%%A"
if defined app.git_fork.source.input goto :_ResolveSource_normalize
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_fork.source.input=%%A"
if defined app.git_fork.source.input goto :_ResolveSource_normalize
set /p "app.git_fork.source.input=Source repository URL or OWNER/REPOSITORY: "
:_ResolveSource_normalize
if not defined app.git_fork.source.input (echo ERROR: A source repository is required. & set "_gfs_rc=1" & goto :ResolveSource)
for /f "delims=" %%A in ('gh repo view "%app.git_fork.source.input%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_fork.source.slug=%%A"
for /f "delims=" %%A in ('gh repo view "%app.git_fork.source.input%" --json name --jq ".name" 2^>nul') do set "app.git_fork.source.name=%%A"
for /f "delims=" %%A in ('gh repo view "%app.git_fork.source.input%" --json url --jq ".url" 2^>nul') do set "app.git_fork.source.web=%%A"
if not defined app.git_fork.source.slug (echo ERROR: Source repository was not found or is not visible: & echo   %app.git_fork.source.input% & set "_gfs_rc=1" & goto :ResolveSource)
for /f "tokens=1 delims=/" %%A in ("%app.git_fork.source.slug%") do set "app.git_fork.source.owner=%%A"
set "app.git_fork.source.url=%app.git_fork.source.web%.git"
set "_gfs_rc=0" & goto :ResolveSource
:: ============================================================
:: :ResolveTarget
:: Resolves and validates the target owner, repository name, and
:: optional same-owner copy visibility.
::
:: Usage: call :ResolveTarget
::
:: Output:
::   app.git_fork.target.owner, type, name, slug, and URL
::
:: Returns: 0 when resolved
::          1 when the target or visibility is invalid
:: Requires: gh
:: ============================================================
:ResolveTarget
for /f "tokens=1 delims==" %%v in ('set gft_ 2^>nul') do set "%%v="
if defined _gft_rc (set "_gft_rc=" & exit /b %_gft_rc%)
if defined app.git_fork.target.owner goto :_ResolveTarget_owner
set /p "app.git_fork.target.owner=Target owner or organization [%app.git_fork.login%]: "
if not defined app.git_fork.target.owner set "app.git_fork.target.owner=%app.git_fork.login%"
:_ResolveTarget_owner
for /f "delims=" %%A in ('gh api "users/%app.git_fork.target.owner%" --jq ".type" 2^>nul') do set "app.git_fork.target.type=%%A"
if not defined app.git_fork.target.type (echo ERROR: Target account or organization was not found: & echo   %app.git_fork.target.owner% & set "_gft_rc=1" & goto :ResolveTarget)
if defined app.git_fork.target.name goto :_ResolveTarget_name
set /p "app.git_fork.target.name=Target repository name [%app.git_fork.source.name%]: "
if not defined app.git_fork.target.name set "app.git_fork.target.name=%app.git_fork.source.name%"
:_ResolveTarget_name
if not defined app.git_fork.target.name (echo ERROR: Target repository name is required. & set "_gft_rc=1" & goto :ResolveTarget)
if not defined app.git_fork.visibility goto :_ResolveTarget_compose
if /I "%app.git_fork.visibility%"=="private" goto :_ResolveTarget_compose
if /I "%app.git_fork.visibility%"=="public" goto :_ResolveTarget_compose
if /I "%app.git_fork.visibility%"=="internal" goto :_ResolveTarget_compose
echo ERROR: Visibility must be private, public, or internal.
set "_gft_rc=1" & goto :ResolveTarget
:_ResolveTarget_compose
set "app.git_fork.target.slug=%app.git_fork.target.owner%/%app.git_fork.target.name%"
set "app.git_fork.target.url=https://github.com/%app.git_fork.target.slug%.git"
set "app.git_fork.initial.slug=%app.git_fork.target.owner%/%app.git_fork.source.name%"
set "_gft_rc=0" & goto :ResolveTarget
:: ============================================================
:: :ValidateTrueForkTarget
:: Ensures a personal fork targets the logged-in user. Organization
:: targets remain subject to GitHub permission and policy checks.
::
:: Usage: call :ValidateTrueForkTarget
::
:: Returns: 0 when allowed
::          1 when a different personal account was requested
:: Requires: none
:: ============================================================
:ValidateTrueForkTarget
if /I not "%app.git_fork.target.type%"=="User" exit /b 0
if /I "%app.git_fork.target.owner%"=="%app.git_fork.login%" exit /b 0
echo ERROR: You are logged in as %app.git_fork.login%.
echo A personal fork for %app.git_fork.target.owner% requires that account.
echo Organizations may be targeted when your account has permission.
exit /b 1
:: ============================================================
:: :ValidateLocalRepository
:: Requires a clean committed worktree and verifies that origin or
:: upstream resolves to the selected source repository.
::
:: Usage: call :ValidateLocalRepository
::
:: Returns: 0 when the checkout matches the source
::          1 on repository, dirty-tree, HEAD, or source mismatch
:: Requires: git, gh
:: ============================================================
:ValidateLocalRepository
for /f "tokens=1 delims==" %%v in ('set gfl_ 2^>nul') do set "%%v="
if defined _gfl_rc (set "_gfl_rc=" & exit /b %_gfl_rc%)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gfl_rc=1" & goto :ValidateLocalRepository)
set "app.git_fork.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_fork.dirty=1"
if defined app.git_fork.dirty goto :_ValidateLocalRepository_dirty
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: The local repository has no commits. & set "_gfl_rc=1" & goto :ValidateLocalRepository)
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_fork.current.origin=%%A"
for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "app.git_fork.current.upstream=%%A"
if defined app.git_fork.current.origin for /f "delims=" %%A in ('gh repo view "%app.git_fork.current.origin%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_fork.current.origin.slug=%%A"
if defined app.git_fork.current.upstream for /f "delims=" %%A in ('gh repo view "%app.git_fork.current.upstream%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_fork.current.upstream.slug=%%A"
if defined app.git_fork.current.origin.slug for /f "delims=" %%A in ('gh api "repos/%app.git_fork.current.origin.slug%" --jq ".parent.full_name // empty" 2^>nul') do set "app.git_fork.current.origin.parent=%%A"
if defined app.git_fork.current.origin.slug for /f "delims=" %%A in ('gh api "repos/%app.git_fork.current.origin.slug%" --jq ".source.full_name // empty" 2^>nul') do set "app.git_fork.current.origin.source=%%A"
if defined app.git_fork.current.upstream.slug for /f "delims=" %%A in ('gh api "repos/%app.git_fork.current.upstream.slug%" --jq ".parent.full_name // empty" 2^>nul') do set "app.git_fork.current.upstream.parent=%%A"
if defined app.git_fork.current.upstream.slug for /f "delims=" %%A in ('gh api "repos/%app.git_fork.current.upstream.slug%" --jq ".source.full_name // empty" 2^>nul') do set "app.git_fork.current.upstream.source=%%A"
if /I "%app.git_fork.current.origin.slug%"=="%app.git_fork.source.slug%" (set "_gfl_rc=0" & goto :ValidateLocalRepository)
if /I "%app.git_fork.current.origin.parent%"=="%app.git_fork.source.slug%" (set "_gfl_rc=0" & goto :ValidateLocalRepository)
if /I "%app.git_fork.current.origin.source%"=="%app.git_fork.source.slug%" (set "_gfl_rc=0" & goto :ValidateLocalRepository)
if /I "%app.git_fork.current.upstream.slug%"=="%app.git_fork.source.slug%" (set "_gfl_rc=0" & goto :ValidateLocalRepository)
if /I "%app.git_fork.current.upstream.parent%"=="%app.git_fork.source.slug%" (set "_gfl_rc=0" & goto :ValidateLocalRepository)
if /I "%app.git_fork.current.upstream.source%"=="%app.git_fork.source.slug%" (set "_gfl_rc=0" & goto :ValidateLocalRepository)
echo ERROR: The current checkout does not appear to belong to the source.
echo Selected source:
echo   %app.git_fork.source.slug%
echo.
echo Resolved origin:
if defined app.git_fork.current.origin.slug (echo   %app.git_fork.current.origin.slug%) else (echo   unavailable)
echo.
echo Resolved upstream:
if defined app.git_fork.current.upstream.slug (echo   %app.git_fork.current.upstream.slug%) else (echo   unavailable)
set "_gfl_rc=1" & goto :ValidateLocalRepository
:_ValidateLocalRepository_dirty
echo ERROR: The working tree has local changes.
echo Commit or stash them before configuring a fork.
echo.
git status --short
set "_gfl_rc=1" & goto :ValidateLocalRepository
:: ============================================================
:: :ShowTrueForkPlan
:: Displays the true-fork creation, optional rename, remote changes,
:: and build configuration update.
::
:: Usage: call :ShowTrueForkPlan
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowTrueForkPlan
echo.
echo ============================================================
echo  Planned true fork
echo ============================================================
echo.
echo Source:
echo   %app.git_fork.source.slug%
echo.
echo Fork owner:
echo   %app.git_fork.target.owner%
echo.
echo Final fork:
echo   %app.git_fork.target.slug%
echo.
echo Local remotes after success:
echo   origin   = %app.git_fork.target.url%
echo   upstream = %app.git_fork.source.url%
echo.
if not defined app.git_fork.visibility goto :_ShowTrueForkPlan_name
echo Note: visibility is ignored for a true fork because GitHub
echo determines it from source visibility and organization policy.
echo.
:_ShowTrueForkPlan_name
if /I "%app.git_fork.target.name%"=="%app.git_fork.source.name%" goto :_ShowTrueForkPlan_config
echo GitHub will first create:
echo   %app.git_fork.initial.slug%
echo and then rename it to:
echo   %app.git_fork.target.slug%
echo.
:_ShowTrueForkPlan_config
echo build_config.bat will preserve previous repository settings as comments.
echo.
exit /b 0
:: ============================================================
:: :EnsureTrueFork
:: Reuses a valid existing fork, creates a new personal or organization
:: fork, waits for visibility, and performs an optional rename.
::
:: Usage: call :EnsureTrueFork
::
:: Returns: 0 when the final fork is ready
::          1 on collision, creation, validation, wait, or rename failure
:: Requires: :ValidateExistingFork, :WaitForRepository, gh
:: ============================================================
:EnsureTrueFork
for /f "tokens=1 delims==" %%v in ('set gfe_ 2^>nul') do set "%%v="
if defined _gfe_rc (set "_gfe_rc=" & exit /b %_gfe_rc%)
gh repo view "%app.git_fork.target.slug%" >nul 2>nul
if errorlevel 1 goto :_EnsureTrueFork_initial
call :ValidateExistingFork "%app.git_fork.target.slug%"
set "_gfe_rc=%errorlevel%" & goto :EnsureTrueFork
:_EnsureTrueFork_initial
gh repo view "%app.git_fork.initial.slug%" >nul 2>nul
if errorlevel 1 goto :_EnsureTrueFork_create
call :ValidateExistingFork "%app.git_fork.initial.slug%"
if errorlevel 1 (set "_gfe_rc=1" & goto :EnsureTrueFork)
goto :_EnsureTrueFork_rename
:_EnsureTrueFork_create
echo.
echo Creating fork:
echo   %app.git_fork.initial.slug%
echo.
if /I "%app.git_fork.target.type%"=="Organization" goto :_EnsureTrueFork_create_org
gh repo fork "%app.git_fork.source.slug%" --clone=false --remote=false
if errorlevel 1 (echo ERROR: GitHub could not create the personal fork. & echo The account may already have another fork in this network. & set "_gfe_rc=1" & goto :EnsureTrueFork)
goto :_EnsureTrueFork_wait
:_EnsureTrueFork_create_org
gh repo fork "%app.git_fork.source.slug%" --org "%app.git_fork.target.owner%" --clone=false --remote=false
if errorlevel 1 (echo ERROR: GitHub could not create the organization fork. & echo Check organization permission and fork policy. & set "_gfe_rc=1" & goto :EnsureTrueFork)
:_EnsureTrueFork_wait
call :WaitForRepository "%app.git_fork.initial.slug%"
if errorlevel 1 (set "_gfe_rc=1" & goto :EnsureTrueFork)
:_EnsureTrueFork_rename
if /I "%app.git_fork.target.name%"=="%app.git_fork.source.name%" goto :_EnsureTrueFork_validate
echo.
echo Renaming fork to:
echo   %app.git_fork.target.slug%
echo.
gh repo rename "%app.git_fork.target.name%" --repo "%app.git_fork.initial.slug%" --yes
if errorlevel 1 goto :_EnsureTrueFork_rename_failed
call :WaitForRepository "%app.git_fork.target.slug%"
if errorlevel 1 (set "_gfe_rc=1" & goto :EnsureTrueFork)
:_EnsureTrueFork_validate
call :ValidateExistingFork "%app.git_fork.target.slug%"
set "_gfe_rc=%errorlevel%" & goto :EnsureTrueFork
:_EnsureTrueFork_rename_failed
echo ERROR: The fork exists but could not be renamed.
echo Current fork:
echo   %app.git_fork.initial.slug%
set "_gfe_rc=1" & goto :EnsureTrueFork
:: ============================================================
:: :ValidateExistingFork
:: Verifies that an existing repository is a fork whose parent or
:: network source matches the selected source repository.
::
:: Usage: call :ValidateExistingFork "OWNER/REPO"
::
:: Returns: 0 when it belongs to the source network
::          1 when it is absent, not a fork, or belongs elsewhere
:: Requires: gh
:: ============================================================
:ValidateExistingFork
for /f "tokens=1 delims==" %%v in ('set gfv_ 2^>nul') do set "%%v="
if defined _gfv_rc (set "_gfv_rc=" & exit /b %_gfv_rc%)
set "app.git_fork.check.slug=%~1"
set "app.git_fork.existing.fork="
set "app.git_fork.existing.parent="
set "app.git_fork.existing.source="
for /f "delims=" %%A in ('gh api "repos/%app.git_fork.check.slug%" --jq ".fork" 2^>nul') do set "app.git_fork.existing.fork=%%A"
for /f "delims=" %%A in ('gh api "repos/%app.git_fork.check.slug%" --jq ".parent.full_name" 2^>nul') do set "app.git_fork.existing.parent=%%A"
for /f "delims=" %%A in ('gh api "repos/%app.git_fork.check.slug%" --jq ".source.full_name" 2^>nul') do set "app.git_fork.existing.source=%%A"
if /I not "%app.git_fork.existing.fork%"=="true" goto :_ValidateExistingFork_fail
if /I "%app.git_fork.existing.parent%"=="%app.git_fork.source.slug%" (set "_gfv_rc=0" & goto :ValidateExistingFork)
if /I "%app.git_fork.existing.source%"=="%app.git_fork.source.slug%" (set "_gfv_rc=0" & goto :ValidateExistingFork)
:_ValidateExistingFork_fail
echo ERROR: Existing repository is not a fork of:
echo   %app.git_fork.source.slug%
echo Repository:
echo   %app.git_fork.check.slug%
set "_gfv_rc=1" & goto :ValidateExistingFork
:: ============================================================
:: :WaitForRepository
:: Polls GitHub until a newly created or renamed repository becomes
:: visible, up to approximately thirty seconds.
::
:: Usage: call :WaitForRepository "OWNER/REPO"
::
:: Returns: 0 when visible
::          1 after timeout
:: Requires: gh, timeout
:: ============================================================
:WaitForRepository
for /f "tokens=1 delims==" %%v in ('set gfw_ 2^>nul') do set "%%v="
if defined _gfw_rc (set "_gfw_rc=" & exit /b %_gfw_rc%)
set "gfw_slug=%~1"
set "gfw_count=0"
:_WaitForRepository_loop
gh repo view "%gfw_slug%" >nul 2>nul
if not errorlevel 1 (set "_gfw_rc=0" & goto :WaitForRepository)
set /a gfw_count+=1
if %gfw_count% GEQ 15 goto :_WaitForRepository_timeout
timeout /t 2 /nobreak >nul
goto :_WaitForRepository_loop
:_WaitForRepository_timeout
echo ERROR: Repository did not become available:
echo   %gfw_slug%
set "_gfw_rc=1" & goto :WaitForRepository
:: ============================================================
:: :CaptureRemotes
:: Records whether origin and upstream exist and their original URLs
:: before local configuration changes.
::
:: Usage: call :CaptureRemotes
::
:: Returns: 0
:: Requires: git
:: ============================================================
:CaptureRemotes
set "app.git_fork.original.origin.exists="
set "app.git_fork.original.origin.url="
set "app.git_fork.original.upstream.exists="
set "app.git_fork.original.upstream.url="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_fork.original.origin.url=%%A"
if defined app.git_fork.original.origin.url set "app.git_fork.original.origin.exists=1"
for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "app.git_fork.original.upstream.url=%%A"
if defined app.git_fork.original.upstream.url set "app.git_fork.original.upstream.exists=1"
exit /b 0
:: ============================================================
:: :ConfigureForkRemotes
:: Sets or creates upstream for the source and origin for the fork.
::
:: Usage: call :ConfigureForkRemotes
::
:: Returns: 0 when configured
::          1 on a Git remote failure
:: Requires: git
:: ============================================================
:ConfigureForkRemotes
git remote get-url upstream >nul 2>nul
if errorlevel 1 goto :_ConfigureForkRemotes_add_upstream
git remote set-url upstream "%app.git_fork.source.url%"
if errorlevel 1 exit /b 1
goto :_ConfigureForkRemotes_origin
:_ConfigureForkRemotes_add_upstream
git remote add upstream "%app.git_fork.source.url%"
if errorlevel 1 exit /b 1
:_ConfigureForkRemotes_origin
git remote get-url origin >nul 2>nul
if errorlevel 1 goto :_ConfigureForkRemotes_add_origin
git remote set-url origin "%app.git_fork.target.url%"
if errorlevel 1 exit /b 1
exit /b 0
:_ConfigureForkRemotes_add_origin
git remote add origin "%app.git_fork.target.url%"
if errorlevel 1 exit /b 1
exit /b 0
:: ============================================================
:: :RestoreRemotes
:: Restores original origin and upstream URLs or removes remotes that
:: were newly added during a failed configuration attempt.
::
:: Usage: call :RestoreRemotes
::
:: Returns: 0 when restoration succeeds
::          1 when one or more restoration commands fail
:: Requires: git
:: ============================================================
:RestoreRemotes
for /f "tokens=1 delims==" %%v in ('set gfr_ 2^>nul') do set "%%v="
if defined _gfr_rc (set "_gfr_rc=" & exit /b %_gfr_rc%)
set "gfr_failed="
if defined app.git_fork.original.origin.exists goto :_RestoreRemotes_origin_set
git remote get-url origin >nul 2>nul
if errorlevel 1 goto :_RestoreRemotes_upstream
git remote remove origin >nul 2>nul
if errorlevel 1 set "gfr_failed=1"
goto :_RestoreRemotes_upstream
:_RestoreRemotes_origin_set
git remote set-url origin "%app.git_fork.original.origin.url%" >nul 2>nul
if errorlevel 1 set "gfr_failed=1"
:_RestoreRemotes_upstream
if defined app.git_fork.original.upstream.exists goto :_RestoreRemotes_upstream_set
git remote get-url upstream >nul 2>nul
if errorlevel 1 goto :_RestoreRemotes_result
git remote remove upstream >nul 2>nul
if errorlevel 1 set "gfr_failed=1"
goto :_RestoreRemotes_result
:_RestoreRemotes_upstream_set
git remote set-url upstream "%app.git_fork.original.upstream.url%" >nul 2>nul
if errorlevel 1 set "gfr_failed=1"
:_RestoreRemotes_result
if defined gfr_failed (set "_gfr_rc=1" & goto :RestoreRemotes)
set "_gfr_rc=0" & goto :RestoreRemotes
:: ============================================================
:: :TrySetTracking
:: When the current branch already exists on the fork, sets its
:: upstream to origin. Failure is reported as a warning only.
::
:: Usage: call :TrySetTracking
::
:: Returns: 0
:: Requires: git
:: ============================================================
:TrySetTracking
set "app.git_fork.current.branch="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_fork.current.branch=%%A"
if not defined app.git_fork.current.branch exit /b 0
git fetch --quiet origin
if errorlevel 1 (echo WARNING: Could not fetch the new origin to configure tracking. & exit /b 0)
git show-ref --verify --quiet "refs/remotes/origin/%app.git_fork.current.branch%"
if errorlevel 1 (echo WARNING: origin does not yet contain %app.git_fork.current.branch%; tracking was not changed. & exit /b 0)
git branch --set-upstream-to="origin/%app.git_fork.current.branch%" "%app.git_fork.current.branch%" >nul 2>nul
if errorlevel 1 echo WARNING: The branch was not configured to track origin.
exit /b 0
:: ============================================================
:: :UpdateBuildConfig
:: Backs up build_config.bat, comments previous active repository
:: settings, and inserts the fork and source settings.
::
:: Usage: call :UpdateBuildConfig
::
:: Returns: 0 when updated
::          1 on backup, directory, or PowerShell failure
:: Requires: PowerShell, copy, mkdir
:: ============================================================
:UpdateBuildConfig
for /f "tokens=1 delims==" %%v in ('set gfu_ 2^>nul') do set "%%v="
if defined _gfu_rc (set "_gfu_rc=" & exit /b %_gfu_rc%)
if exist "%CD%\build_config.bat" goto :_UpdateBuildConfig_timestamp
echo ERROR: build_config.bat was not found.
set "_gfu_rc=1" & goto :UpdateBuildConfig
:_UpdateBuildConfig_timestamp
for /f "delims=" %%A in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyy-MM-dd.HHmmss"') do set "app.git_fork.timestamp=%%A"
if not defined app.git_fork.timestamp set "app.git_fork.timestamp=unknown"
if defined TOOLS_DIR (set "app.git_fork.logs=%TOOLS_DIR%\logs") else (set "app.git_fork.logs=%CD%\tools\logs")
if exist "%app.git_fork.logs%\" goto :_UpdateBuildConfig_backup
mkdir "%app.git_fork.logs%" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not create logs folder: & echo   %app.git_fork.logs% & set "_gfu_rc=1" & goto :UpdateBuildConfig)
:_UpdateBuildConfig_backup
set "app.git_fork.backup=%app.git_fork.logs%\build_config.before-fork.%app.git_fork.timestamp%.bat"
copy /y "%CD%\build_config.bat" "%app.git_fork.backup%" >nul
if errorlevel 1 (echo ERROR: Could not back up build_config.bat. & set "_gfu_rc=1" & goto :UpdateBuildConfig)
set "GF_CONFIG=%CD%\build_config.bat"
set "GF_NEW_URL=%app.git_fork.target.url%"
set "GF_NEW_SLUG=%app.git_fork.target.slug%"
set "GF_SOURCE_URL=%app.git_fork.source.url%"
set "GF_SOURCE_SLUG=%app.git_fork.source.slug%"
set "GF_TIMESTAMP=%app.git_fork.timestamp%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:GF_CONFIG; $a=[IO.File]::ReadAllLines($p); $o=New-Object 'System.Collections.Generic.List[string]'; $done=$false; foreach($x in $a){ if($x -match '^\s*set\s+\"app\.(repo_url|repo_slug|upstream_url|fork_source_url)='){ $o.Add('rem previous: '+$x) } elseif((-not $done)-and($x -match '^\s*exit\s+/b\s+0\s*$')){ $o.Add(''); $o.Add('rem ============================================================'); $o.Add('rem Fork settings added by git_fork.bat'); $o.Add('rem Timestamp: '+$env:GF_TIMESTAMP); $o.Add('rem Source: '+$env:GF_SOURCE_SLUG); $o.Add('rem ============================================================'); $o.Add(''); $o.Add('set \"app.repo_url='+$env:GF_NEW_URL+'\"'); $o.Add('set \"app.repo_slug='+$env:GF_NEW_SLUG+'\"'); $o.Add('set \"app.upstream_url='+$env:GF_SOURCE_URL+'\"'); $o.Add('set \"app.fork_source_url='+$env:GF_SOURCE_URL+'\"'); $o.Add(''); $o.Add($x); $done=$true } else { $o.Add($x) } }; if(-not $done){throw 'exit /b 0 not found'}; [IO.File]::WriteAllLines($p,$o,(New-Object Text.UTF8Encoding($false)))"
set "gfu_update_rc=%errorlevel%"
set "GF_CONFIG="
set "GF_NEW_URL="
set "GF_NEW_SLUG="
set "GF_SOURCE_URL="
set "GF_SOURCE_SLUG="
set "GF_TIMESTAMP="
if "%gfu_update_rc%"=="0" (set "_gfu_rc=0" & goto :UpdateBuildConfig)
echo ERROR: Could not update build_config.bat.
call :RestoreBuildConfig
set "_gfu_rc=1" & goto :UpdateBuildConfig
:: ============================================================
:: :RestoreBuildConfig
:: Restores build_config.bat from the backup created for this fork
:: operation.
::
:: Usage: call :RestoreBuildConfig
::
:: Returns: 0 when restored or no backup exists
::          1 when copy fails
:: Requires: copy
:: ============================================================
:RestoreBuildConfig
if not defined app.git_fork.backup exit /b 0
if not exist "%app.git_fork.backup%" exit /b 0
copy /y "%app.git_fork.backup%" "%CD%\build_config.bat" >nul
if errorlevel 1 exit /b 1
exit /b 0
:: ============================================================
:: :DelegateCopy
:: Delegates a same-owner independent repository copy to
:: git_create_repository.bat with collected values.
::
:: Usage: call :DelegateCopy
::
:: Returns: git_create_repository.bat exit code
:: Requires: git_create_repository.bat
:: ============================================================
:DelegateCopy
for /f "tokens=1 delims==" %%v in ('set gfd_ 2^>nul') do set "%%v="
if defined _gfd_rc (set "_gfd_rc=" & exit /b %_gfd_rc%)
if /I "%app.git_fork.target.name%"=="%app.git_fork.source.name%" goto :_DelegateCopy_same
echo.
echo ============================================================
echo  Same-owner repository copy
echo ============================================================
echo.
echo Source owner and target owner are both:
echo   %app.git_fork.target.owner%
echo.
echo GitHub does not treat this as a fork.
echo A new independent repository will be created instead.
echo.
echo Source:
echo   %app.git_fork.source.slug%
echo.
echo New repository:
echo   %app.git_fork.target.slug%
echo.
if exist "%~dp0git_create_repository.bat" goto :_DelegateCopy_call
echo ERROR: Required helper was not found:
echo   %~dp0git_create_repository.bat
set "_gfd_rc=1" & goto :DelegateCopy
:_DelegateCopy_call
if defined app.git_fork.visibility goto :_DelegateCopy_visibility
if defined CFG_BRANCH goto :_DelegateCopy_branch
call "%~dp0git_create_repository.bat" owner "%app.git_fork.target.owner%" name "%app.git_fork.target.name%" source "%app.git_fork.source.slug%"
set "_gfd_rc=%errorlevel%" & goto :DelegateCopy
:_DelegateCopy_branch
call "%~dp0git_create_repository.bat" owner "%app.git_fork.target.owner%" name "%app.git_fork.target.name%" source "%app.git_fork.source.slug%" branch "%CFG_BRANCH%"
set "_gfd_rc=%errorlevel%" & goto :DelegateCopy
:_DelegateCopy_visibility
if defined CFG_BRANCH goto :_DelegateCopy_visibility_branch
call "%~dp0git_create_repository.bat" owner "%app.git_fork.target.owner%" name "%app.git_fork.target.name%" source "%app.git_fork.source.slug%" visibility "%app.git_fork.visibility%"
set "_gfd_rc=%errorlevel%" & goto :DelegateCopy
:_DelegateCopy_visibility_branch
call "%~dp0git_create_repository.bat" owner "%app.git_fork.target.owner%" name "%app.git_fork.target.name%" source "%app.git_fork.source.slug%" visibility "%app.git_fork.visibility%" branch "%CFG_BRANCH%"
set "_gfd_rc=%errorlevel%" & goto :DelegateCopy
:_DelegateCopy_same
echo ERROR: Source and target are the same repository:
echo   %app.git_fork.source.slug%
echo.
echo Use a different repository name for a same-owner copy.
set "_gfd_rc=1" & goto :DelegateCopy
:: ============================================================
:: :ParseArgs
:: Parses source, owner, name, visibility, and help arguments.
::
:: Usage: call :ParseArgs [source REPO] [owner OWNER] [name NAME] [visibility VALUE]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="source" goto :_ParseArgs_source
if /I "%~1"=="owner" goto :_ParseArgs_owner
if /I "%~1"=="target" goto :_ParseArgs_owner
if /I "%~1"=="name" goto :_ParseArgs_name
if /I "%~1"=="repo" goto :_ParseArgs_name
if /I "%~1"=="visibility" goto :_ParseArgs_visibility
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_source
if "%~2"=="" (echo ERROR: source requires a value. & exit /b 2)
set "app.git_fork.source.input=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_owner
if "%~2"=="" (echo ERROR: owner requires a value. & exit /b 2)
set "app.git_fork.target.owner=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_name
if "%~2"=="" (echo ERROR: name requires a value. & exit /b 2)
set "app.git_fork.target.name=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_visibility
if "%~2"=="" (echo ERROR: visibility requires private, public, or internal. & exit /b 2)
set "app.git_fork.visibility=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_fork.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays fork and same-owner-copy usage.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_fork.bat
echo.
echo Usage:
echo   git_fork.bat
echo   git_fork.bat owner TARGET_OWNER
echo   git_fork.bat owner TARGET_OWNER name NEW_NAME
echo   git_fork.bat source OWNER/REPO owner TARGET_OWNER
echo   git_fork.bat source OWNER/REPO owner SAME_OWNER name COPY_NAME
echo.
echo Different owner:
echo   Creates or reuses a true GitHub fork.
echo.
echo Same owner:
echo   Delegates an independent copy to git_create_repository.bat.
echo.
echo visibility applies only to the same-owner copy.
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
