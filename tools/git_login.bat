@echo off
:: ============================================================
:: git_login.bat
:: Authenticates GitHub CLI, verifies repository permissions,
:: initializes local Git when requested, configures identity and
:: remotes, and pushes the current branch when commits exist.
::
:: Usage:
::   call tools\git_login.bat
::   call tools\git_login.bat repo OWNER/REPO
::   call tools\git_login.bat repo URL branch main
::   call tools\git_login.bat help
::
:: Returns: 0 on successful setup, successful no-commit setup, or help
::          1 on dependency, authentication, repository, permission,
::            initialization, identity, remote, or push failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, gh, :Main, :Authenticate,
::           :ResolveRepository, :ResolveIdentity, :ConfigureFork,
::           :EnsureFork, :WaitForFork, :ShowPlan, :CaptureRemotes,
::           :ConfigureRemotes, :RestoreRemotes, :ParseArgs, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_login.repo.input="
set "app.git_login.repo.slug="
set "app.git_login.repo.owner="
set "app.git_login.repo.name="
set "app.git_login.repo.web="
set "app.git_login.repo.url="
set "app.git_login.branch="
set "app.git_login.login="
set "app.git_login.can.push="
set "app.git_login.use.fork="
set "app.git_login.fork.slug="
set "app.git_login.fork.url="
set "app.git_login.fork.create="
set "app.git_login.target.origin="
set "app.git_login.repo.exists="
set "app.git_login.repo.root="
set "app.git_login.current.branch="
set "app.git_login.existing.origin="
set "app.git_login.git.name="
set "app.git_login.git.email="
set "app.git_login.input="
set "app.git_login.confirm="
set "app.git_login.original.origin.exists="
set "app.git_login.original.origin.url="
set "app.git_login.original.upstream.exists="
set "app.git_login.original.upstream.url="
set "app.git_login.help="
set "app.git_login.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_login.rc=%errorlevel%"
goto :end
:run
if defined CFG_REPO_URL set "app.git_login.repo.input=%CFG_REPO_URL%"
if defined CFG_BRANCH set "app.git_login.branch=%CFG_BRANCH%"
call :Main %*
set "app.git_login.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_login.rc%
:: ============================================================
:: :Main
:: Coordinates authentication, repository and fork resolution,
:: local Git setup, remote configuration, and optional push.
::
:: Usage: call :Main [repo REPO] [branch BRANCH] [help]
::
:: Returns: 0 on successful setup, successful no-commit setup, or help
::          1 on dependency, authentication, repository, permission,
::            initialization, identity, remote, or push failure
::          2 on invalid arguments
:: Requires: :Authenticate, :ResolveRepository, :ResolveIdentity,
::           :ConfigureFork, :EnsureFork, :ShowPlan, :CaptureRemotes,
::           :ConfigureRemotes, :RestoreRemotes, :ParseArgs, :ShowHelp,
::           prepare.bat, git, gh
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set glm_ 2^>nul') do set "%%v="
if defined _glm_rc (set "_glm_rc=" & exit /b %_glm_rc%)
call :ParseArgs %*
set "_glm_rc=%errorlevel%"
if not "%_glm_rc%"=="0" goto :Main
if defined app.git_login.help goto :_Main_help
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
if exist "%CD%\prepare.bat" goto :_Main_prepare
echo ERROR: prepare.bat was not found in the project root:
echo   %CD%
set "_glm_rc=1" & goto :Main
:_Main_prepare
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_glm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git is unavailable after preparation. & set "_glm_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI is unavailable after preparation. & set "_glm_rc=1" & goto :Main)
call :Authenticate
if errorlevel 1 (set "_glm_rc=%errorlevel%" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 goto :_Main_no_repo
set "app.git_login.repo.exists=1"
for /f "delims=" %%A in ('git rev-parse --show-toplevel 2^>nul') do set "app.git_login.repo.root=%%A"
for %%A in ("%app.git_login.repo.root%") do set "app.git_login.repo.root=%%~fA"
if /I not "%app.git_login.repo.root%"=="%CD%" goto :_Main_wrong_root
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_login.current.branch=%%A"
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_login.existing.origin=%%A"
if defined app.git_login.current.branch set "app.git_login.branch=%app.git_login.current.branch%"
goto :_Main_resolve_repo
:_Main_wrong_root
echo ERROR: Run this helper from the Git worktree root:
echo   %app.git_login.repo.root%
set "_glm_rc=1" & goto :Main
:_Main_no_repo
set "app.git_login.repo.exists="
:_Main_resolve_repo
if not defined app.git_login.repo.input if defined app.git_login.existing.origin set "app.git_login.repo.input=%app.git_login.existing.origin%"
call :ResolveRepository
if errorlevel 1 (set "_glm_rc=%errorlevel%" & goto :Main)
if /I "%app.git_login.can.push%"=="true" goto :_Main_direct
call :ConfigureFork
if errorlevel 1 (set "_glm_rc=%errorlevel%" & goto :Main)
goto :_Main_branch
:_Main_direct
set "app.git_login.target.origin=%app.git_login.repo.url%"
:_Main_branch
if not defined app.git_login.branch set "app.git_login.branch=main"
git check-ref-format --branch "%app.git_login.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid branch name: & echo   %app.git_login.branch% & set "_glm_rc=1" & goto :Main)
call :ResolveIdentity
if errorlevel 1 (set "_glm_rc=%errorlevel%" & goto :Main)
call :ShowPlan
set /p "app.git_login.confirm=Type LOGIN to continue: "
if "%app.git_login.confirm%"=="LOGIN" goto :_Main_ensure_fork
echo.
echo Cancelled. Nothing was changed.
set "_glm_rc=0" & goto :Main
:_Main_ensure_fork
if not defined app.git_login.use.fork goto :_Main_initialize
call :EnsureFork
if errorlevel 1 (set "_glm_rc=%errorlevel%" & goto :Main)
:_Main_initialize
if defined app.git_login.repo.exists goto :_Main_identity
git init -b "%app.git_login.branch%" >nul 2>nul
if not errorlevel 1 goto :_Main_initialized
git init
if errorlevel 1 (echo ERROR: git init failed. & set "_glm_rc=1" & goto :Main)
git checkout -B "%app.git_login.branch%"
if errorlevel 1 (echo ERROR: Could not create branch %app.git_login.branch%. & set "_glm_rc=1" & goto :Main)
:_Main_initialized
set "app.git_login.repo.exists=1"
:_Main_identity
git config --local user.name "%app.git_login.git.name%"
if errorlevel 1 (echo ERROR: Could not set local Git user.name. & set "_glm_rc=1" & goto :Main)
git config --local user.email "%app.git_login.git.email%"
if errorlevel 1 (echo ERROR: Could not set local Git user.email. & set "_glm_rc=1" & goto :Main)
set "app.git_login.current.branch="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_login.current.branch=%%A"
if defined app.git_login.current.branch goto :_Main_remotes
git checkout -B "%app.git_login.branch%"
if errorlevel 1 (echo ERROR: Could not create or switch to branch %app.git_login.branch%. & set "_glm_rc=1" & goto :Main)
set "app.git_login.current.branch=%app.git_login.branch%"
:_Main_remotes
call :CaptureRemotes
call :ConfigureRemotes
if not errorlevel 1 goto :_Main_summary
call :RestoreRemotes
echo ERROR: Could not configure Git remotes.
echo Original remotes were restored where possible.
set "_glm_rc=1" & goto :Main
:_Main_summary
echo.
echo ============================================================
echo  GitHub setup summary
echo ============================================================
echo.
echo GitHub account:
echo   %app.git_login.login%
echo.
echo Repository:
echo   %app.git_login.repo.slug%
echo.
if defined app.git_login.use.fork goto :_Main_summary_fork
echo Permission mode:
echo   direct push
echo.
echo origin:
echo   %app.git_login.target.origin%
goto :_Main_summary_common
:_Main_summary_fork
echo Permission mode:
echo   fork workflow
echo.
echo origin:
echo   %app.git_login.target.origin%
echo.
echo upstream:
echo   %app.git_login.repo.url%
:_Main_summary_common
echo.
echo Local branch:
echo   %app.git_login.current.branch%
echo.
echo Local Git author:
echo   "%app.git_login.git.name% ^<%app.git_login.git.email%^>"
echo.
git status --short --branch
echo.
git remote -v
echo.
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 goto :_Main_no_head
echo Pushing current branch and configuring upstream tracking...
git push -u origin "%app.git_login.current.branch%"
if not errorlevel 1 goto :_Main_success
echo.
echo ERROR: Push failed.
echo Repository write permission was checked, but branch protection,
echo remote history, or another Git condition rejected this push.
echo.
echo Inspect the repository with:
echo   just_status.bat
set "_glm_rc=1" & goto :Main
:_Main_no_head
echo Login and repository setup are complete.
echo No commits exist yet, so there is nothing to push.
echo.
echo Next:
echo   just_commit.bat
echo   just_push.bat
set "_glm_rc=0" & goto :Main
:_Main_success
echo.
echo GitHub login, permission check, and push are complete.
set "_glm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_glm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :Authenticate
:: Authenticates GitHub CLI when necessary, determines the login,
:: and configures Git credential integration.
::
:: Usage: call :Authenticate
::
:: Output:
::   app.git_login.login  authenticated GitHub account
::
:: Returns: 0 when authenticated
::          1 on login, account, or credential-setup failure
:: Requires: gh
:: ============================================================
:Authenticate
for /f "tokens=1 delims==" %%v in ('set gla_ 2^>nul') do set "%%v="
if defined _gla_rc (set "_gla_rc=" & exit /b %_gla_rc%)
echo Checking GitHub login...
gh auth status --hostname github.com >nul 2>nul
if not errorlevel 1 goto :_Authenticate_ready
echo GitHub login is required.
echo A browser window will open for secure login.
gh auth login --hostname github.com --git-protocol https --web
if errorlevel 1 (echo ERROR: GitHub login failed or was cancelled. & set "_gla_rc=1" & goto :Authenticate)
:_Authenticate_ready
for /f "delims=" %%A in ('gh api user --jq ".login" 2^>nul') do set "app.git_login.login=%%A"
if not defined app.git_login.login (echo ERROR: Could not determine the logged-in GitHub account. & set "_gla_rc=1" & goto :Authenticate)
gh auth setup-git --hostname github.com >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI could not configure Git authentication. & set "_gla_rc=1" & goto :Authenticate)
echo Logged in as:
echo   %app.git_login.login%
echo.
set "_gla_rc=0" & goto :Authenticate
:: ============================================================
:: :ResolveRepository
:: Resolves the configured repository, canonical HTTPS URL, owner,
:: name, and push permission for the authenticated account.
::
:: Usage: call :ResolveRepository
::
:: Returns: 0 when resolved and visible
::          1 when missing, invisible, or permission data is unavailable
:: Requires: gh
:: ============================================================
:ResolveRepository
for /f "tokens=1 delims==" %%v in ('set glr_ 2^>nul') do set "%%v="
if defined _glr_rc (set "_glr_rc=" & exit /b %_glr_rc%)
if defined app.git_login.repo.input goto :_ResolveRepository_query
set /p "app.git_login.repo.input=GitHub repository URL or OWNER/REPO: "
:_ResolveRepository_query
if not defined app.git_login.repo.input (echo ERROR: A GitHub repository is required. & set "_glr_rc=1" & goto :ResolveRepository)
for /f "delims=" %%A in ('gh repo view "%app.git_login.repo.input%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_login.repo.slug=%%A"
for /f "delims=" %%A in ('gh repo view "%app.git_login.repo.input%" --json name --jq ".name" 2^>nul') do set "app.git_login.repo.name=%%A"
for /f "delims=" %%A in ('gh repo view "%app.git_login.repo.input%" --json url --jq ".url" 2^>nul') do set "app.git_login.repo.web=%%A"
if not defined app.git_login.repo.slug goto :_ResolveRepository_missing
for /f "tokens=1 delims=/" %%A in ("%app.git_login.repo.slug%") do set "app.git_login.repo.owner=%%A"
set "app.git_login.repo.url=%app.git_login.repo.web%.git"
for /f "delims=" %%A in ('gh api "repos/%app.git_login.repo.slug%" --jq ".permissions.push" 2^>nul') do set "app.git_login.can.push=%%A"
if not defined app.git_login.can.push (echo ERROR: Could not determine repository permissions. & set "_glr_rc=1" & goto :ResolveRepository)
echo Repository:
echo   %app.git_login.repo.slug%
echo.
set "_glr_rc=0" & goto :ResolveRepository
:_ResolveRepository_missing
echo ERROR: Repository was not found or is not visible:
echo   %app.git_login.repo.input%
echo.
echo For a repository that does not exist yet, use:
echo   tools\git_create_repository.bat
set "_glr_rc=1" & goto :ResolveRepository
:: ============================================================
:: :ResolveIdentity
:: Resolves Git author name and email from local settings, project
:: settings, global settings, and interactive input.
::
:: Usage: call :ResolveIdentity
::
:: Output:
::   app.git_login.git.name
::   app.git_login.git.email
::
:: Returns: 0 when both values are present
::          1 when either remains missing
:: Requires: git
:: ============================================================
:ResolveIdentity
for /f "tokens=1 delims==" %%v in ('set gli_ 2^>nul') do set "%%v="
if defined _gli_rc (set "_gli_rc=" & exit /b %_gli_rc%)
if not defined app.git_login.repo.exists goto :_ResolveIdentity_project
for /f "delims=" %%A in ('git config --local --get user.name 2^>nul') do set "app.git_login.git.name=%%A"
for /f "delims=" %%A in ('git config --local --get user.email 2^>nul') do set "app.git_login.git.email=%%A"
:_ResolveIdentity_project
if defined app.git_name set "app.git_login.git.name=%app.git_name%"
if defined app.git_email set "app.git_login.git.email=%app.git_email%"
if defined app.git_login.git.name goto :_ResolveIdentity_email
for /f "delims=" %%A in ('git config --global --get user.name 2^>nul') do set "app.git_login.git.name=%%A"
:_ResolveIdentity_email
if defined app.git_login.git.email goto :_ResolveIdentity_prompt
for /f "delims=" %%A in ('git config --global --get user.email 2^>nul') do set "app.git_login.git.email=%%A"
:_ResolveIdentity_prompt
echo Git author identity:
set "app.git_login.input="
set /p "app.git_login.input=Git name [%app.git_login.git.name%]: "
if defined app.git_login.input set "app.git_login.git.name=%app.git_login.input%"
set "app.git_login.input="
set /p "app.git_login.input=Git email [%app.git_login.git.email%]: "
if defined app.git_login.input set "app.git_login.git.email=%app.git_login.input%"
if not defined app.git_login.git.name (echo ERROR: Git name is required. & set "_gli_rc=1" & goto :ResolveIdentity)
if not defined app.git_login.git.email (echo ERROR: Git email is required. & set "_gli_rc=1" & goto :ResolveIdentity)
set "_gli_rc=0" & goto :ResolveIdentity
:: ============================================================
:: :ConfigureFork
:: Creates or reuses the authenticated user's personal fork when
:: direct push permission is unavailable.
::
:: Usage: call :ConfigureFork
::
:: Output:
::   app.git_login.use.fork
::   app.git_login.fork.slug
::   app.git_login.fork.url
::   app.git_login.target.origin
::
:: Returns: 0 when a writable fork is ready
::          1 on cancellation, collision, creation, wait, or permission failure
:: Requires: :WaitForFork, gh
:: ============================================================
:ConfigureFork
for /f "tokens=1 delims==" %%v in ('set glf_ 2^>nul') do set "%%v="
if defined _glf_rc (set "_glf_rc=" & exit /b %_glf_rc%)
echo Direct push permission is unavailable.
set "glf_confirm="
set /p "glf_confirm=Create or use a personal fork under %app.git_login.login%? [Y/n]: "
if /I "%glf_confirm%"=="n" (echo Cancelled. This account cannot push directly. & set "_glf_rc=1" & goto :ConfigureFork)
set "app.git_login.use.fork=1"
set "app.git_login.fork.slug=%app.git_login.login%/%app.git_login.repo.name%"
set "app.git_login.fork.url=https://github.com/%app.git_login.fork.slug%.git"
gh repo view "%app.git_login.fork.slug%" >nul 2>nul
if errorlevel 1 goto :_ConfigureFork_plan_create
set "glf_is_fork="
set "glf_parent="
set "glf_source="
for /f "delims=" %%A in ('gh api "repos/%app.git_login.fork.slug%" --jq ".fork" 2^>nul') do set "glf_is_fork=%%A"
for /f "delims=" %%A in ('gh api "repos/%app.git_login.fork.slug%" --jq ".parent.full_name // empty" 2^>nul') do set "glf_parent=%%A"
for /f "delims=" %%A in ('gh api "repos/%app.git_login.fork.slug%" --jq ".source.full_name // empty" 2^>nul') do set "glf_source=%%A"
if /I not "%glf_is_fork%"=="true" goto :_ConfigureFork_collision
if /I "%glf_parent%"=="%app.git_login.repo.slug%" goto :_ConfigureFork_permission
if /I "%glf_source%"=="%app.git_login.repo.slug%" goto :_ConfigureFork_permission
echo ERROR: Existing repository is not a fork of:
echo   %app.git_login.repo.slug%
echo Repository:
echo   %app.git_login.fork.slug%
set "_glf_rc=1" & goto :ConfigureFork
:_ConfigureFork_collision
echo ERROR: %app.git_login.fork.slug% already exists but is not a fork.
set "_glf_rc=1" & goto :ConfigureFork
:_ConfigureFork_plan_create
set "app.git_login.fork.create=1"
set "app.git_login.target.origin=%app.git_login.fork.url%"
echo A personal fork will be created after LOGIN confirmation:
echo   %app.git_login.fork.slug%
echo.
set "_glf_rc=0" & goto :ConfigureFork
:_ConfigureFork_permission
set "glf_can_push="
for /f "delims=" %%A in ('gh api "repos/%app.git_login.fork.slug%" --jq ".permissions.push" 2^>nul') do set "glf_can_push=%%A"
if /I not "%glf_can_push%"=="true" (echo ERROR: The account cannot push to the selected fork. & set "_glf_rc=1" & goto :ConfigureFork)
set "app.git_login.target.origin=%app.git_login.fork.url%"
echo Existing fork is ready:
echo   %app.git_login.fork.slug%
echo.
set "_glf_rc=0" & goto :ConfigureFork
:: ============================================================
:: :EnsureFork
:: Creates the planned personal fork only after LOGIN confirmation,
:: waits for visibility, and verifies push permission.
::
:: Usage: call :EnsureFork
::
:: Returns: 0 when the writable fork is ready
::          1 on creation, wait, or permission failure
:: Requires: :WaitForFork, gh
:: ============================================================
:EnsureFork
for /f "tokens=1 delims==" %%v in ('set gle_ 2^>nul') do set "%%v="
if defined _gle_rc (set "_gle_rc=" & exit /b %_gle_rc%)
if not defined app.git_login.fork.create goto :_EnsureFork_permission
echo Creating personal fork:
echo   %app.git_login.fork.slug%
gh repo fork "%app.git_login.repo.slug%" --clone=false --remote=false
if errorlevel 1 (echo ERROR: GitHub could not create the fork. & set "_gle_rc=1" & goto :EnsureFork)
call :WaitForFork
if errorlevel 1 (set "_gle_rc=%errorlevel%" & goto :EnsureFork)
set "app.git_login.fork.create="
:_EnsureFork_permission
set "gle_can_push="
for /f "delims=" %%A in ('gh api "repos/%app.git_login.fork.slug%" --jq ".permissions.push" 2^>nul') do set "gle_can_push=%%A"
if /I not "%gle_can_push%"=="true" (echo ERROR: The account cannot push to the selected fork. & set "_gle_rc=1" & goto :EnsureFork)
set "app.git_login.target.origin=%app.git_login.fork.url%"
set "_gle_rc=0" & goto :EnsureFork
:: ============================================================
:: :WaitForFork
:: Polls GitHub until the requested personal fork is visible, up to
:: approximately thirty seconds.
::
:: Usage: call :WaitForFork
::
:: Returns: 0 when visible
::          1 after timeout
:: Requires: gh, timeout
:: ============================================================
:WaitForFork
for /f "tokens=1 delims==" %%v in ('set glw_ 2^>nul') do set "%%v="
if defined _glw_rc (set "_glw_rc=" & exit /b %_glw_rc%)
set "glw_count=0"
:_WaitForFork_loop
gh repo view "%app.git_login.fork.slug%" >nul 2>nul
if not errorlevel 1 (set "_glw_rc=0" & goto :WaitForFork)
set /a glw_count+=1
if %glw_count% GEQ 15 goto :_WaitForFork_timeout
timeout /t 2 /nobreak >nul
goto :_WaitForFork_loop
:_WaitForFork_timeout
echo ERROR: The fork was requested but did not become available:
echo   %app.git_login.fork.slug%
set "_glw_rc=1" & goto :WaitForFork
:: ============================================================
:: :ShowPlan
:: Displays the local initialization, identity, remote, branch, and
:: push actions that confirmation will authorize.
::
:: Usage: call :ShowPlan
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowPlan
echo.
echo ============================================================
echo  Planned GitHub setup
echo ============================================================
echo.
echo GitHub account:
echo   %app.git_login.login%
echo.
echo Repository:
echo   %app.git_login.repo.slug%
echo.
if defined app.git_login.repo.exists (echo Local repository: & echo   use existing Git worktree) else (echo Local repository: & echo   initialize this project folder)
echo.
echo Branch:
echo   %app.git_login.branch%
echo.
echo Git author:
echo   "%app.git_login.git.name% ^<%app.git_login.git.email%^>"
echo.
if defined app.git_login.use.fork goto :_ShowPlan_fork
echo origin:
echo   %app.git_login.target.origin%
goto :_ShowPlan_push
:_ShowPlan_fork
if defined app.git_login.fork.create (echo Fork action: & echo   create %app.git_login.fork.slug%) else (echo Fork action: & echo   reuse %app.git_login.fork.slug%)
echo.
echo origin:
echo   %app.git_login.target.origin%
echo.
echo upstream:
echo   %app.git_login.repo.url%
:_ShowPlan_push
echo.
echo Existing commits will be pushed to origin with upstream tracking.
echo.
exit /b 0
:: ============================================================
:: :CaptureRemotes
:: Records original origin and upstream URLs before configuration.
::
:: Usage: call :CaptureRemotes
::
:: Returns: 0
:: Requires: git
:: ============================================================
:CaptureRemotes
set "app.git_login.original.origin.exists="
set "app.git_login.original.origin.url="
set "app.git_login.original.upstream.exists="
set "app.git_login.original.upstream.url="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_login.original.origin.url=%%A"
if defined app.git_login.original.origin.url set "app.git_login.original.origin.exists=1"
for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "app.git_login.original.upstream.url=%%A"
if defined app.git_login.original.upstream.url set "app.git_login.original.upstream.exists=1"
exit /b 0
:: ============================================================
:: :ConfigureRemotes
:: Sets origin to the writable target and, for a fork workflow,
:: upstream to the source repository.
::
:: Usage: call :ConfigureRemotes
::
:: Returns: 0 when configured
::          1 on a Git remote failure
:: Requires: git
:: ============================================================
:ConfigureRemotes
if not defined app.git_login.use.fork goto :_ConfigureRemotes_origin
git remote get-url upstream >nul 2>nul
if errorlevel 1 goto :_ConfigureRemotes_add_upstream
git remote set-url upstream "%app.git_login.repo.url%"
if errorlevel 1 exit /b 1
goto :_ConfigureRemotes_origin
:_ConfigureRemotes_add_upstream
git remote add upstream "%app.git_login.repo.url%"
if errorlevel 1 exit /b 1
:_ConfigureRemotes_origin
git remote get-url origin >nul 2>nul
if errorlevel 1 goto :_ConfigureRemotes_add_origin
git remote set-url origin "%app.git_login.target.origin%"
if errorlevel 1 exit /b 1
exit /b 0
:_ConfigureRemotes_add_origin
git remote add origin "%app.git_login.target.origin%"
if errorlevel 1 exit /b 1
exit /b 0
:: ============================================================
:: :RestoreRemotes
:: Restores original remote URLs or removes remotes newly added by a
:: failed configuration attempt.
::
:: Usage: call :RestoreRemotes
::
:: Returns: 0 when restoration succeeds
::          1 when one or more restoration commands fail
:: Requires: git
:: ============================================================
:RestoreRemotes
for /f "tokens=1 delims==" %%v in ('set glx_ 2^>nul') do set "%%v="
if defined _glx_rc (set "_glx_rc=" & exit /b %_glx_rc%)
set "glx_failed="
if defined app.git_login.original.origin.exists goto :_RestoreRemotes_origin_set
git remote get-url origin >nul 2>nul
if errorlevel 1 goto :_RestoreRemotes_upstream
git remote remove origin >nul 2>nul
if errorlevel 1 set "glx_failed=1"
goto :_RestoreRemotes_upstream
:_RestoreRemotes_origin_set
git remote set-url origin "%app.git_login.original.origin.url%" >nul 2>nul
if errorlevel 1 set "glx_failed=1"
:_RestoreRemotes_upstream
if defined app.git_login.original.upstream.exists goto :_RestoreRemotes_upstream_set
git remote get-url upstream >nul 2>nul
if errorlevel 1 goto :_RestoreRemotes_result
git remote remove upstream >nul 2>nul
if errorlevel 1 set "glx_failed=1"
goto :_RestoreRemotes_result
:_RestoreRemotes_upstream_set
git remote set-url upstream "%app.git_login.original.upstream.url%" >nul 2>nul
if errorlevel 1 set "glx_failed=1"
:_RestoreRemotes_result
if defined glx_failed (set "_glx_rc=1" & goto :RestoreRemotes)
set "_glx_rc=0" & goto :RestoreRemotes
:: ============================================================
:: :ParseArgs
:: Parses repository, branch, and help arguments.
::
:: Usage: call :ParseArgs [repo REPO] [branch BRANCH] [help]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="repo" goto :_ParseArgs_repo
if /I "%~1"=="url" goto :_ParseArgs_repo
if /I "%~1"=="branch" goto :_ParseArgs_branch
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_repo
if "%~2"=="" (echo ERROR: repo requires OWNER/REPO or a URL. & exit /b 2)
set "app.git_login.repo.input=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_branch
if "%~2"=="" (echo ERROR: branch requires a name. & exit /b 2)
set "app.git_login.branch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_login.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays login, repository, branch, fork, and push behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_login.bat
echo.
echo Usage:
echo   git_login.bat
echo   git_login.bat repo OWNER/REPO
echo   git_login.bat repo URL branch main
echo.
echo The helper authenticates GitHub CLI and confirms a LOGIN plan.
echo Direct push is used when permitted; otherwise a personal fork
echo can be created or reused. Existing commits are then pushed.
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
