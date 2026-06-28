@echo off
:: ============================================================
:: git_create_repository.bat
:: Creates a new GitHub repository, preserves existing local history,
:: updates build_config.bat, configures remotes, and pushes a branch.
::
:: Usage:
::   call tools\git_create_repository.bat
::   call tools\git_create_repository.bat owner OWNER name REPOSITORY
::   call tools\git_create_repository.bat owner OWNER name REPOSITORY visibility public
::   call tools\git_create_repository.bat owner OWNER name REPOSITORY source OWNER/SOURCE
::
:: Returns: 0 on success or cancellation
::          1 on dependency, validation, local preparation, creation,
::            remote configuration, or push failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, gh, PowerShell, :Main,
::           :ParseArgs, :AuthenticateGitHub, :ResolveTarget,
::           :ResolveSource, :ResolveVisibility, :ResolveBranch,
::           :ShowPlan, :InitializeLocalGit, :EnsureGitIdentity,
::           :UpdateBuildConfig, :RestoreBuildConfig,
::           :CreateLocalCommit, :CreateGitHubRepository,
::           :ConfigureRemotes, :PushBranch, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_create_repo.owner="
set "app.git_create_repo.name="
set "app.git_create_repo.slug="
set "app.git_create_repo.url="
set "app.git_create_repo.visibility="
set "app.git_create_repo.branch="
set "app.git_create_repo.message="
set "app.git_create_repo.source.input="
set "app.git_create_repo.source.slug="
set "app.git_create_repo.source.web="
set "app.git_create_repo.source.url="
set "app.git_create_repo.config.slug="
set "app.git_create_repo.existing.origin="
set "app.git_create_repo.existing.origin.slug="
set "app.git_create_repo.login="
set "app.git_create_repo.owner.type="
set "app.git_create_repo.current.branch="
set "app.git_create_repo.confirm="
set "app.git_create_repo.has.head="
set "app.git_create_repo.has.staged="
set "app.git_create_repo.git.name="
set "app.git_create_repo.git.email="
set "app.git_create_repo.input="
set "app.git_create_repo.timestamp="
set "app.git_create_repo.logs="
set "app.git_create_repo.backup="
set "app.git_create_repo.created="
set "app.git_create_repo.help="
set "app.git_create_repo.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_create_repo.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_create_repo.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_create_repo.rc%
:: ============================================================
:: :Main
:: Parses options, prepares dependencies, resolves and confirms the
:: plan, prepares local Git/configuration, creates the GitHub
:: repository, configures remotes, and pushes the branch.
::
:: Usage: call :Main [owner OWNER] [name REPOSITORY] [source REPOSITORY] [visibility VALUE] [branch NAME] [message TEXT]
::
:: Returns: 0 on success or cancellation
::          1 on dependency, validation, local preparation, creation,
::            remote configuration, or push failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :AuthenticateGitHub, :ResolveTarget,
::           :ResolveSource, :ResolveVisibility, :ResolveBranch,
::           :ShowPlan, :InitializeLocalGit, :EnsureGitIdentity,
::           :UpdateBuildConfig, :RestoreBuildConfig,
::           :CreateLocalCommit, :CreateGitHubRepository,
::           :ConfigureRemotes, :PushBranch, :ShowHelp
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcrm_ 2^>nul') do set "%%v="
if defined _gcrm_rc (set "_gcrm_rc=" & exit /b %_gcrm_rc%)
call :ParseArgs %*
set "_gcrm_rc=%errorlevel%"
if not "%_gcrm_rc%"=="0" goto :Main
if defined app.git_create_repo.help goto :_Main_help
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
if not exist "%CD%\prepare.bat" (echo ERROR: prepare.bat was not found in the project root. & set "_gcrm_rc=1" & goto :Main)
echo Preparing Git and GitHub CLI...
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_gcrm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git is unavailable after preparation. & set "_gcrm_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI is unavailable after preparation. & set "_gcrm_rc=1" & goto :Main)
where powershell.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Windows PowerShell is unavailable. & set "_gcrm_rc=1" & goto :Main)
call :AuthenticateGitHub
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
call :ResolveTarget
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
call :ResolveSource
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
call :ResolveVisibility
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
call :ResolveBranch
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
gh repo view "%app.git_create_repo.slug%" >nul 2>nul
if not errorlevel 1 (echo. & echo ERROR: The target GitHub repository already exists: & echo   https://github.com/%app.git_create_repo.slug% & echo. & echo Nothing was created or overwritten. & set "_gcrm_rc=1" & goto :Main)
call :ShowPlan
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
set /p "app.git_create_repo.confirm=Type CREATE to continue: "
if "%app.git_create_repo.confirm%"=="CREATE" goto :_Main_local
echo.
echo Cancelled.
set "_gcrm_rc=0" & goto :Main
:_Main_local
call :InitializeLocalGit
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
call :EnsureGitIdentity
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
call :UpdateBuildConfig
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
call :CreateLocalCommit
if not errorlevel 1 goto :_Main_remote
call :RestoreBuildConfig
git reset >nul 2>nul
set "_gcrm_rc=1" & goto :Main
:_Main_remote
call :CreateGitHubRepository
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
set "app.git_create_repo.created=1"
call :ConfigureRemotes
if errorlevel 1 goto :_Main_created_error
call :PushBranch
if errorlevel 1 goto :_Main_created_error
echo.
echo ============================================================
echo  Repository created successfully
echo ============================================================
echo.
echo GitHub:
echo   https://github.com/%app.git_create_repo.slug%
echo.
echo Remotes:
git remote -v
echo.
echo Latest commit:
git log -1 --oneline
echo.
set "_gcrm_rc=0" & goto :Main
:_Main_created_error
echo.
echo The GitHub repository now exists and was not deleted:
echo   https://github.com/%app.git_create_repo.slug%
echo.
set "_gcrm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gcrm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :AuthenticateGitHub
:: Logs in when necessary, resolves the authenticated account, and
:: configures Git HTTPS authentication.
::
:: Usage: call :AuthenticateGitHub
::
:: Output:
::   app.git_create_repo.login  authenticated GitHub login
::
:: Returns: 0 on success
::          1 on authentication or setup failure
:: Requires: gh
:: ============================================================
:AuthenticateGitHub
for /f "tokens=1 delims==" %%v in ('set gcra_ 2^>nul') do set "%%v="
if defined _gcra_rc (set "_gcra_rc=" & exit /b %_gcra_rc%)
echo.
echo Checking GitHub login...
gh auth status --hostname github.com >nul 2>nul
if not errorlevel 1 goto :_AuthenticateGitHub_account
echo GitHub login is required.
echo A browser window will open for secure login.
echo.
gh auth login --hostname github.com --git-protocol https --web
if errorlevel 1 (echo ERROR: GitHub login failed or was cancelled. & set "_gcra_rc=1" & goto :AuthenticateGitHub)
:_AuthenticateGitHub_account
set "app.git_create_repo.login="
for /f "delims=" %%A in ('gh api user --jq ".login" 2^>nul') do set "app.git_create_repo.login=%%A"
if not defined app.git_create_repo.login (echo ERROR: Could not determine the logged-in GitHub account. & set "_gcra_rc=1" & goto :AuthenticateGitHub)
echo Logged in as:
echo   %app.git_create_repo.login%
echo.
gh auth setup-git --hostname github.com >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI could not configure Git authentication. & set "_gcra_rc=1" & goto :AuthenticateGitHub)
set "_gcra_rc=0" & goto :AuthenticateGitHub
:: ============================================================
:: :ResolveTarget
:: Resolves and validates the target owner and repository name from
:: arguments, project configuration, or authenticated account.
::
:: Usage: call :ResolveTarget
::
:: Output:
::   app.git_create_repo.slug  OWNER/REPOSITORY
::   app.git_create_repo.url   HTTPS Git URL
::
:: Returns: 0 on success
::          1 on missing or unauthorized target
:: Requires: gh, PowerShell
:: ============================================================
:ResolveTarget
for /f "tokens=1 delims==" %%v in ('set gcrt_ 2^>nul') do set "%%v="
if defined _gcrt_rc (set "_gcrt_rc=" & exit /b %_gcrt_rc%)
if defined app.repo_slug set "app.git_create_repo.config.slug=%app.repo_slug%"
if defined app.git_create_repo.config.slug goto :_ResolveTarget_owner
if not defined CFG_REPO_URL goto :_ResolveTarget_owner
set "GCR_PARSE_URL=%CFG_REPO_URL%"
for /f "delims=" %%A in ('powershell -NoProfile -Command "$u=$env:GCR_PARSE_URL; if($u -match 'github\.com[:/](?<o>[^/]+)/(?<r>[^/]+?)(?:\.git)?/?$'){Write-Output ($Matches.o+'/'+$Matches.r)}" 2^>nul') do set "app.git_create_repo.config.slug=%%A"
set "GCR_PARSE_URL="
:_ResolveTarget_owner
if defined app.git_create_repo.owner goto :_ResolveTarget_name
if defined app.git_create_repo.config.slug for /f "tokens=1 delims=/" %%A in ("%app.git_create_repo.config.slug%") do set "app.git_create_repo.owner=%%A"
if not defined app.git_create_repo.owner set "app.git_create_repo.owner=%app.git_create_repo.login%"
:_ResolveTarget_name
if defined app.git_create_repo.name goto :_ResolveTarget_compose
if defined app.git_create_repo.config.slug for /f "tokens=2 delims=/" %%A in ("%app.git_create_repo.config.slug%") do set "app.git_create_repo.name=%%A"
if not defined app.git_create_repo.name set "app.git_create_repo.name=%APP_NAME%"
if not defined app.git_create_repo.name set /p "app.git_create_repo.name=New repository name: "
:_ResolveTarget_compose
if not defined app.git_create_repo.owner (echo ERROR: Repository owner is required. & set "_gcrt_rc=1" & goto :ResolveTarget)
if not defined app.git_create_repo.name (echo ERROR: Repository name is required. & set "_gcrt_rc=1" & goto :ResolveTarget)
set "app.git_create_repo.slug=%app.git_create_repo.owner%/%app.git_create_repo.name%"
set "app.git_create_repo.url=https://github.com/%app.git_create_repo.slug%.git"
set "app.git_create_repo.owner.type="
for /f "delims=" %%A in ('gh api "users/%app.git_create_repo.owner%" --jq ".type" 2^>nul') do set "app.git_create_repo.owner.type=%%A"
if not defined app.git_create_repo.owner.type (echo ERROR: Target account or organization was not found: & echo   %app.git_create_repo.owner% & set "_gcrt_rc=1" & goto :ResolveTarget)
if /I "%app.git_create_repo.owner.type%"=="User" if /I not "%app.git_create_repo.owner%"=="%app.git_create_repo.login%" goto :_ResolveTarget_wrong_user
set "_gcrt_rc=0" & goto :ResolveTarget
:_ResolveTarget_wrong_user
echo ERROR: You are logged in as %app.git_create_repo.login%.
echo Creating a repository for %app.git_create_repo.owner% requires logging in as that user.
echo Organizations may be targeted when your account has permission.
set "_gcrt_rc=1" & goto :ResolveTarget
:: ============================================================
:: :ResolveSource
:: Resolves an optional source repository from an argument, upstream,
:: or an existing origin different from the new target.
::
:: Usage: call :ResolveSource
::
:: Returns: 0 when resolved or absent
::          1 when the selected source is invalid or invisible
:: Requires: git, gh, PowerShell
:: ============================================================
:ResolveSource
for /f "tokens=1 delims==" %%v in ('set gcrs_ 2^>nul') do set "%%v="
if defined _gcrs_rc (set "_gcrs_rc=" & exit /b %_gcrs_rc%)
if defined app.git_create_repo.source.input goto :_ResolveSource_normalize
for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "app.git_create_repo.source.input=%%A"
if defined app.git_create_repo.source.input goto :_ResolveSource_normalize
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_create_repo.existing.origin=%%A"
if not defined app.git_create_repo.existing.origin (set "_gcrs_rc=0" & goto :ResolveSource)
set "GCR_PARSE_URL=%app.git_create_repo.existing.origin%"
for /f "delims=" %%A in ('powershell -NoProfile -Command "$u=$env:GCR_PARSE_URL; if($u -match 'github\.com[:/](?<o>[^/]+)/(?<r>[^/]+?)(?:\.git)?/?$'){Write-Output ($Matches.o+'/'+$Matches.r)}" 2^>nul') do set "app.git_create_repo.existing.origin.slug=%%A"
set "GCR_PARSE_URL="
if /I "%app.git_create_repo.existing.origin.slug%"=="%app.git_create_repo.slug%" (set "_gcrs_rc=0" & goto :ResolveSource)
set "app.git_create_repo.source.input=%app.git_create_repo.existing.origin%"
:_ResolveSource_normalize
set "app.git_create_repo.source.slug="
set "app.git_create_repo.source.web="
for /f "delims=" %%A in ('gh repo view "%app.git_create_repo.source.input%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_create_repo.source.slug=%%A"
for /f "delims=" %%A in ('gh repo view "%app.git_create_repo.source.input%" --json url --jq ".url" 2^>nul') do set "app.git_create_repo.source.web=%%A"
if not defined app.git_create_repo.source.slug (echo ERROR: Source repository was not found or is not visible: & echo   %app.git_create_repo.source.input% & set "_gcrs_rc=1" & goto :ResolveSource)
if /I "%app.git_create_repo.source.slug%"=="%app.git_create_repo.slug%" goto :_ResolveSource_same
set "app.git_create_repo.source.url=%app.git_create_repo.source.web%.git"
set "_gcrs_rc=0" & goto :ResolveSource
:_ResolveSource_same
set "app.git_create_repo.source.slug="
set "app.git_create_repo.source.web="
set "app.git_create_repo.source.url="
set "_gcrs_rc=0" & goto :ResolveSource
:: ============================================================
:: :ResolveVisibility
:: Resolves and validates repository visibility.
::
:: Usage: call :ResolveVisibility
::
:: Returns: 0 when private, public, or internal
::          1 otherwise
:: Requires: none
:: ============================================================
:ResolveVisibility
for /f "tokens=1 delims==" %%v in ('set gcrv_ 2^>nul') do set "%%v="
if defined _gcrv_rc (set "_gcrv_rc=" & exit /b %_gcrv_rc%)
if defined app.git_create_repo.visibility goto :_ResolveVisibility_validate
if defined app.repo_visibility set "app.git_create_repo.visibility=%app.repo_visibility%"
if defined app.github_visibility set "app.git_create_repo.visibility=%app.github_visibility%"
if defined app.git_create_repo.visibility goto :_ResolveVisibility_validate
echo Repository visibility:
echo   private
echo   public
echo   internal
echo.
set /p "app.git_create_repo.visibility=Visibility [private]: "
if not defined app.git_create_repo.visibility set "app.git_create_repo.visibility=private"
:_ResolveVisibility_validate
if /I "%app.git_create_repo.visibility%"=="private" (set "app.git_create_repo.visibility=private" & set "_gcrv_rc=0" & goto :ResolveVisibility)
if /I "%app.git_create_repo.visibility%"=="public" (set "app.git_create_repo.visibility=public" & set "_gcrv_rc=0" & goto :ResolveVisibility)
if /I "%app.git_create_repo.visibility%"=="internal" (set "app.git_create_repo.visibility=internal" & set "_gcrv_rc=0" & goto :ResolveVisibility)
echo ERROR: Visibility must be private, public, or internal.
set "_gcrv_rc=1" & goto :ResolveVisibility
:: ============================================================
:: :ResolveBranch
:: Resolves the branch to publish from arguments, configuration,
:: current branch, or main.
::
:: Usage: call :ResolveBranch
::
:: Returns: 0 when the branch name is valid
::          1 when invalid
:: Requires: git
:: ============================================================
:ResolveBranch
for /f "tokens=1 delims==" %%v in ('set gcrb_ 2^>nul') do set "%%v="
if defined _gcrb_rc (set "_gcrb_rc=" & exit /b %_gcrb_rc%)
if defined app.git_create_repo.branch goto :_ResolveBranch_validate
if defined CFG_BRANCH set "app.git_create_repo.branch=%CFG_BRANCH%"
if defined app.git_create_repo.branch goto :_ResolveBranch_validate
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_create_repo.branch=%%A"
if not defined app.git_create_repo.branch set "app.git_create_repo.branch=main"
:_ResolveBranch_validate
git check-ref-format --branch "%app.git_create_repo.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid branch name: & echo   %app.git_create_repo.branch% & set "_gcrb_rc=1" & goto :ResolveBranch)
set "_gcrb_rc=0" & goto :ResolveBranch
:: ============================================================
:: :ShowPlan
:: Displays the target, visibility, branch, source, and local update
:: behavior before confirmation.
::
:: Usage: call :ShowPlan
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowPlan
echo.
echo ============================================================
echo  Planned repository
echo ============================================================
echo.
echo GitHub account:
echo   %app.git_create_repo.login%
echo.
echo New repository:
echo   %app.git_create_repo.slug%
echo.
echo Visibility:
echo   %app.git_create_repo.visibility%
echo.
echo Branch:
echo   %app.git_create_repo.branch%
echo.
if defined app.git_create_repo.source.slug goto :_ShowPlan_source
echo No source repository is configured.
echo Existing local Git history, if any, will be preserved.
goto :_ShowPlan_config
:_ShowPlan_source
echo Repository-copy source:
echo   %app.git_create_repo.source.slug%
echo.
echo Existing Git history will be preserved.
echo The source will become the upstream remote.
:_ShowPlan_config
echo.
echo build_config.bat will be updated before the commit.
echo The previous active repository settings will remain as comments.
echo.
exit /b 0
:: ============================================================
:: :InitializeLocalGit
:: Initializes Git when needed and ensures the requested branch is
:: checked out while preserving existing history.
::
:: Usage: call :InitializeLocalGit
::
:: Returns: 0 on success
::          1 on initialization or branch failure
:: Requires: git
:: ============================================================
:InitializeLocalGit
for /f "tokens=1 delims==" %%v in ('set gcri_ 2^>nul') do set "%%v="
if defined _gcri_rc (set "_gcri_rc=" & exit /b %_gcri_rc%)
git rev-parse --is-inside-work-tree >nul 2>nul
if not errorlevel 1 goto :_InitializeLocalGit_existing
git init -b "%app.git_create_repo.branch%" >nul 2>nul
if not errorlevel 1 (set "_gcri_rc=0" & goto :InitializeLocalGit)
git init
if errorlevel 1 (echo ERROR: git init failed. & set "_gcri_rc=1" & goto :InitializeLocalGit)
git symbolic-ref HEAD "refs/heads/%app.git_create_repo.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not select branch %app.git_create_repo.branch%. & set "_gcri_rc=1" & goto :InitializeLocalGit)
set "_gcri_rc=0" & goto :InitializeLocalGit
:_InitializeLocalGit_existing
set "app.git_create_repo.current.branch="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_create_repo.current.branch=%%A"
if defined app.git_create_repo.current.branch goto :_InitializeLocalGit_named
git show-ref --verify --quiet "refs/heads/%app.git_create_repo.branch%"
if not errorlevel 1 goto :_InitializeLocalGit_switch_existing
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (git symbolic-ref HEAD "refs/heads/%app.git_create_repo.branch%" >nul 2>nul) else (git switch -c "%app.git_create_repo.branch%" >nul 2>nul)
if errorlevel 1 (echo ERROR: Could not create branch %app.git_create_repo.branch%. & set "_gcri_rc=1" & goto :InitializeLocalGit)
set "_gcri_rc=0" & goto :InitializeLocalGit
:_InitializeLocalGit_switch_existing
git switch "%app.git_create_repo.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not switch to existing branch %app.git_create_repo.branch%. & set "_gcri_rc=1" & goto :InitializeLocalGit)
set "_gcri_rc=0" & goto :InitializeLocalGit
:_InitializeLocalGit_named
if /I "%app.git_create_repo.current.branch%"=="%app.git_create_repo.branch%" (set "_gcri_rc=0" & goto :InitializeLocalGit)
git show-ref --verify --quiet "refs/heads/%app.git_create_repo.branch%"
if not errorlevel 1 (echo ERROR: Target branch already exists locally: & echo   %app.git_create_repo.branch% & echo Switch to it or choose another branch before continuing. & set "_gcri_rc=1" & goto :InitializeLocalGit)
echo Renaming current branch:
echo   %app.git_create_repo.current.branch% to %app.git_create_repo.branch%
git branch -m "%app.git_create_repo.branch%"
if errorlevel 1 (echo ERROR: Could not rename the current branch. & set "_gcri_rc=1" & goto :InitializeLocalGit)
set "_gcri_rc=0" & goto :InitializeLocalGit
:: ============================================================
:: :EnsureGitIdentity
:: Resolves and stores local Git user.name and user.email.
::
:: Usage: call :EnsureGitIdentity
::
:: Returns: 0 on success
::          1 when identity is missing or cannot be stored
:: Requires: git
:: ============================================================
:EnsureGitIdentity
for /f "tokens=1 delims==" %%v in ('set gcre_ 2^>nul') do set "%%v="
if defined _gcre_rc (set "_gcre_rc=" & exit /b %_gcre_rc%)
for /f "delims=" %%A in ('git config --local --get user.name 2^>nul') do set "app.git_create_repo.git.name=%%A"
for /f "delims=" %%A in ('git config --local --get user.email 2^>nul') do set "app.git_create_repo.git.email=%%A"
if defined app.git_name set "app.git_create_repo.git.name=%app.git_name%"
if defined app.git_email set "app.git_create_repo.git.email=%app.git_email%"
if not defined app.git_create_repo.git.name for /f "delims=" %%A in ('git config --global --get user.name 2^>nul') do set "app.git_create_repo.git.name=%%A"
if not defined app.git_create_repo.git.email for /f "delims=" %%A in ('git config --global --get user.email 2^>nul') do set "app.git_create_repo.git.email=%%A"
set "app.git_create_repo.input="
set /p "app.git_create_repo.input=Git name [%app.git_create_repo.git.name%]: "
if defined app.git_create_repo.input set "app.git_create_repo.git.name=%app.git_create_repo.input%"
set "app.git_create_repo.input="
set /p "app.git_create_repo.input=Git email [%app.git_create_repo.git.email%]: "
if defined app.git_create_repo.input set "app.git_create_repo.git.email=%app.git_create_repo.input%"
if not defined app.git_create_repo.git.name (echo ERROR: Git name is required. & set "_gcre_rc=1" & goto :EnsureGitIdentity)
if not defined app.git_create_repo.git.email (echo ERROR: Git email is required. & set "_gcre_rc=1" & goto :EnsureGitIdentity)
git config --local user.name "%app.git_create_repo.git.name%"
if errorlevel 1 (echo ERROR: Could not store Git user.name. & set "_gcre_rc=1" & goto :EnsureGitIdentity)
git config --local user.email "%app.git_create_repo.git.email%"
if errorlevel 1 (echo ERROR: Could not store Git user.email. & set "_gcre_rc=1" & goto :EnsureGitIdentity)
set "_gcre_rc=0" & goto :EnsureGitIdentity
:: ============================================================
:: :UpdateBuildConfig
:: Backs up build_config.bat and replaces active repository settings,
:: preserving previous settings as comments.
::
:: Usage: call :UpdateBuildConfig
::
:: Output:
::   app.git_create_repo.backup  backup path
::
:: Returns: 0 on success
::          1 on backup or update failure
:: Requires: PowerShell, TOOLS_DIR
:: ============================================================
:UpdateBuildConfig
for /f "tokens=1 delims==" %%v in ('set gcru_ 2^>nul') do set "%%v="
if defined _gcru_rc (set "_gcru_rc=" & exit /b %_gcru_rc%)
if not exist "%CD%\build_config.bat" (echo ERROR: build_config.bat was not found. & set "_gcru_rc=1" & goto :UpdateBuildConfig)
for /f "delims=" %%A in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd.HHmmss" 2^>nul') do set "app.git_create_repo.timestamp=%%A"
if not defined app.git_create_repo.timestamp set "app.git_create_repo.timestamp=unknown"
set "app.git_create_repo.logs=%TOOLS_DIR%\logs"
if exist "%app.git_create_repo.logs%\" goto :_UpdateBuildConfig_backup
mkdir "%app.git_create_repo.logs%" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not create logs folder: & echo   %app.git_create_repo.logs% & set "_gcru_rc=1" & goto :UpdateBuildConfig)
:_UpdateBuildConfig_backup
set "app.git_create_repo.backup=%app.git_create_repo.logs%\build_config.before-create.%app.git_create_repo.timestamp%.bat"
copy /y "%CD%\build_config.bat" "%app.git_create_repo.backup%" >nul
if errorlevel 1 (echo ERROR: Could not back up build_config.bat. & set "_gcru_rc=1" & goto :UpdateBuildConfig)
set "GCR_CONFIG=%CD%\build_config.bat"
set "GCR_NEW_URL=%app.git_create_repo.url%"
set "GCR_NEW_SLUG=%app.git_create_repo.slug%"
set "GCR_SOURCE_URL=%app.git_create_repo.source.url%"
set "GCR_SOURCE_SLUG=%app.git_create_repo.source.slug%"
set "GCR_TIMESTAMP=%app.git_create_repo.timestamp%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:GCR_CONFIG; $a=[IO.File]::ReadAllLines($p); $o=New-Object 'System.Collections.Generic.List[string]'; $done=$false; foreach($x in $a){ if($x -match '^\s*set\s+\"app\.(repo_url|repo_slug|upstream_url|fork_source_url)='){ $o.Add('rem previous: '+$x) } elseif((-not $done)-and($x -match '^\s*exit\s+/b\s+0\s*$')){ $o.Add(''); $o.Add('rem ============================================================'); $o.Add('rem Repository settings added by git_create_repository.bat'); $o.Add('rem Timestamp: '+$env:GCR_TIMESTAMP); if($env:GCR_SOURCE_SLUG){$o.Add('rem Copied from: '+$env:GCR_SOURCE_SLUG)}; $o.Add('rem ============================================================'); $o.Add(''); $o.Add('set \"app.repo_url='+$env:GCR_NEW_URL+'\"'); $o.Add('set \"app.repo_slug='+$env:GCR_NEW_SLUG+'\"'); if($env:GCR_SOURCE_URL){$o.Add('set \"app.upstream_url='+$env:GCR_SOURCE_URL+'\"'); $o.Add('set \"app.fork_source_url='+$env:GCR_SOURCE_URL+'\"')}; $o.Add(''); $o.Add($x); $done=$true } else { $o.Add($x) } }; if(-not $done){throw 'exit /b 0 not found'}; [IO.File]::WriteAllLines($p,$o,(New-Object Text.UTF8Encoding($false)))"
set "gcru_update_rc=%errorlevel%"
set "GCR_CONFIG="
set "GCR_NEW_URL="
set "GCR_NEW_SLUG="
set "GCR_SOURCE_URL="
set "GCR_SOURCE_SLUG="
set "GCR_TIMESTAMP="
if "%gcru_update_rc%"=="0" (set "_gcru_rc=0" & goto :UpdateBuildConfig)
echo ERROR: Could not update build_config.bat.
call :RestoreBuildConfig
set "_gcru_rc=1" & goto :UpdateBuildConfig
:: ============================================================
:: :RestoreBuildConfig
:: Restores build_config.bat from the backup created by
:: :UpdateBuildConfig.
::
:: Usage: call :RestoreBuildConfig
::
:: Returns: 0 on success
::          1 when no backup exists or restore fails
:: Requires: copy
:: ============================================================
:RestoreBuildConfig
for /f "tokens=1 delims==" %%v in ('set gcrx_ 2^>nul') do set "%%v="
if defined _gcrx_rc (set "_gcrx_rc=" & exit /b %_gcrx_rc%)
if not defined app.git_create_repo.backup (echo ERROR: No build_config.bat backup is available. & set "_gcrx_rc=1" & goto :RestoreBuildConfig)
if not exist "%app.git_create_repo.backup%" (echo ERROR: build_config.bat backup was not found: & echo   %app.git_create_repo.backup% & set "_gcrx_rc=1" & goto :RestoreBuildConfig)
echo Restoring build_config.bat from:
echo   %app.git_create_repo.backup%
copy /y "%app.git_create_repo.backup%" "%CD%\build_config.bat" >nul
if errorlevel 1 (echo ERROR: build_config.bat restore failed. & set "_gcrx_rc=1" & goto :RestoreBuildConfig)
set "_gcrx_rc=0" & goto :RestoreBuildConfig
:: ============================================================
:: :CreateLocalCommit
:: Stages all files and creates a commit when needed, preserving an
:: existing unchanged HEAD.
::
:: Usage: call :CreateLocalCommit
::
:: Returns: 0 when a valid HEAD exists
::          1 on staging, empty initial project, or commit failure
:: Requires: git
:: ============================================================
:CreateLocalCommit
for /f "tokens=1 delims==" %%v in ('set gcrc_ 2^>nul') do set "%%v="
if defined _gcrc_rc (set "_gcrc_rc=" & exit /b %_gcrc_rc%)
git add --all
if errorlevel 1 (echo ERROR: git add failed. & set "_gcrc_rc=1" & goto :CreateLocalCommit)
set "app.git_create_repo.has.head="
set "app.git_create_repo.has.staged="
git rev-parse --verify HEAD >nul 2>nul
if not errorlevel 1 set "app.git_create_repo.has.head=1"
git diff --cached --quiet
if errorlevel 1 set "app.git_create_repo.has.staged=1"
if defined app.git_create_repo.has.head if not defined app.git_create_repo.has.staged (set "_gcrc_rc=0" & goto :CreateLocalCommit)
if not defined app.git_create_repo.has.head if not defined app.git_create_repo.has.staged (echo ERROR: The project has no files to commit. & set "_gcrc_rc=1" & goto :CreateLocalCommit)
if not defined app.git_create_repo.message set "app.git_create_repo.message=Create %app.git_create_repo.slug% repository"
git commit -m "%app.git_create_repo.message%"
if errorlevel 1 (echo ERROR: Could not create the local commit. & set "_gcrc_rc=1" & goto :CreateLocalCommit)
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: HEAD verification failed after commit. & set "_gcrc_rc=1" & goto :CreateLocalCommit)
set "_gcrc_rc=0" & goto :CreateLocalCommit
:: ============================================================
:: :CreateGitHubRepository
:: Creates the target GitHub repository with selected visibility.
::
:: Usage: call :CreateGitHubRepository
::
:: Returns: 0 on success
::          1 on GitHub CLI failure
:: Requires: gh
:: ============================================================
:CreateGitHubRepository
for /f "tokens=1 delims==" %%v in ('set gcrg_ 2^>nul') do set "%%v="
if defined _gcrg_rc (set "_gcrg_rc=" & exit /b %_gcrg_rc%)
echo.
echo Creating GitHub repository:
echo   %app.git_create_repo.slug%
echo.
if /I "%app.git_create_repo.visibility%"=="private" goto :_CreateGitHubRepository_private
if /I "%app.git_create_repo.visibility%"=="public" goto :_CreateGitHubRepository_public
gh repo create "%app.git_create_repo.slug%" --internal
goto :_CreateGitHubRepository_result
:_CreateGitHubRepository_private
gh repo create "%app.git_create_repo.slug%" --private
goto :_CreateGitHubRepository_result
:_CreateGitHubRepository_public
gh repo create "%app.git_create_repo.slug%" --public
:_CreateGitHubRepository_result
if errorlevel 1 goto :_CreateGitHubRepository_failed
set "_gcrg_rc=0" & goto :CreateGitHubRepository
:_CreateGitHubRepository_failed
echo.
echo ERROR: GitHub repository creation failed.
echo.
echo The local commit is safe.
echo build_config.bat names the intended repository.
echo Existing remotes were not changed.
set "_gcrg_rc=1" & goto :CreateGitHubRepository
:: ============================================================
:: :ConfigureRemotes
:: Configures optional upstream and the new origin repository.
::
:: Usage: call :ConfigureRemotes
::
:: Returns: 0 on success
::          1 on remote add or update failure
:: Requires: git
:: ============================================================
:ConfigureRemotes
for /f "tokens=1 delims==" %%v in ('set gcrf_ 2^>nul') do set "%%v="
if defined _gcrf_rc (set "_gcrf_rc=" & exit /b %_gcrf_rc%)
if not defined app.git_create_repo.source.url goto :_ConfigureRemotes_origin
git remote get-url upstream >nul 2>nul
if errorlevel 1 goto :_ConfigureRemotes_add_upstream
git remote set-url upstream "%app.git_create_repo.source.url%"
if errorlevel 1 (echo ERROR: Could not update upstream. & set "_gcrf_rc=1" & goto :ConfigureRemotes)
goto :_ConfigureRemotes_origin
:_ConfigureRemotes_add_upstream
git remote add upstream "%app.git_create_repo.source.url%"
if errorlevel 1 (echo ERROR: Could not add upstream. & set "_gcrf_rc=1" & goto :ConfigureRemotes)
:_ConfigureRemotes_origin
git remote get-url origin >nul 2>nul
if errorlevel 1 goto :_ConfigureRemotes_add_origin
git remote set-url origin "%app.git_create_repo.url%"
if errorlevel 1 (echo ERROR: Could not update origin. & set "_gcrf_rc=1" & goto :ConfigureRemotes)
set "_gcrf_rc=0" & goto :ConfigureRemotes
:_ConfigureRemotes_add_origin
git remote add origin "%app.git_create_repo.url%"
if errorlevel 1 (echo ERROR: Could not add origin. & set "_gcrf_rc=1" & goto :ConfigureRemotes)
set "_gcrf_rc=0" & goto :ConfigureRemotes
:: ============================================================
:: :PushBranch
:: Pushes the selected branch to origin and sets upstream tracking.
::
:: Usage: call :PushBranch
::
:: Returns: 0 on success
::          1 on push failure
:: Requires: git
:: ============================================================
:PushBranch
for /f "tokens=1 delims==" %%v in ('set gcrp_ 2^>nul') do set "%%v="
if defined _gcrp_rc (set "_gcrp_rc=" & exit /b %_gcrp_rc%)
echo.
echo Uploading branch:
echo   %app.git_create_repo.branch%
echo.
git push -u origin "%app.git_create_repo.branch%"
if not errorlevel 1 (set "_gcrp_rc=0" & goto :PushBranch)
echo.
echo ERROR: The repository was created, but the upload failed.
echo.
echo Repository:
echo   https://github.com/%app.git_create_repo.slug%
echo.
echo Retry later with:
echo   just_push.bat
set "_gcrp_rc=1" & goto :PushBranch
:: ============================================================
:: :ParseArgs
:: Parses owner, name, source, visibility, branch, message, and help.
::
:: Usage: call :ParseArgs [owner OWNER] [name REPOSITORY] [source REPOSITORY] [visibility VALUE] [branch NAME] [message TEXT]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="owner" goto :_ParseArgs_owner
if /I "%~1"=="name" goto :_ParseArgs_name
if /I "%~1"=="repo" goto :_ParseArgs_name
if /I "%~1"=="source" goto :_ParseArgs_source
if /I "%~1"=="visibility" goto :_ParseArgs_visibility
if /I "%~1"=="branch" goto :_ParseArgs_branch
if /I "%~1"=="message" goto :_ParseArgs_message
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_owner
if "%~2"=="" (echo ERROR: owner requires a value. & exit /b 2)
set "app.git_create_repo.owner=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_name
if "%~2"=="" (echo ERROR: name requires a value. & exit /b 2)
set "app.git_create_repo.name=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_source
if "%~2"=="" (echo ERROR: source requires a value. & exit /b 2)
set "app.git_create_repo.source.input=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_visibility
if "%~2"=="" (echo ERROR: visibility requires private, public, or internal. & exit /b 2)
set "app.git_create_repo.visibility=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_branch
if "%~2"=="" (echo ERROR: branch requires a value. & exit /b 2)
set "app.git_create_repo.branch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_message
if "%~2"=="" (echo ERROR: message requires a value. & exit /b 2)
set "app.git_create_repo.message=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_create_repo.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays command usage.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_create_repository.bat
echo.
echo Usage:
echo   git_create_repository.bat
echo   git_create_repository.bat owner OWNER name REPOSITORY
echo   git_create_repository.bat owner OWNER name REPOSITORY visibility public
echo   git_create_repository.bat owner OWNER name REPOSITORY source OWNER/SOURCE
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
