@echo off
:: ============================================================
:: git_create_pull_request.bat
:: Pushes the current branch when requested and creates a GitHub
:: pull request against the configured target repository.
::
:: Usage:
::   call tools\git_create_pull_request.bat
::   call tools\git_create_pull_request.bat base main
::   call tools\git_create_pull_request.bat base main title "Add feature"
::   call tools\git_create_pull_request.bat draft yes push yes
::
:: Returns: 0 on success, cancellation, or an already-open PR
::          1 on repository, authentication, validation, push, or PR failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, gh, :Main, :ParseArgs,
::           :NormalizeYesNo, :EnsureGitHubAuthentication,
::           :LoadRepositoryContext, :ValidatePullRequest,
::           :ShowPlan, :CreatePullRequest, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_create_pr.base="
set "app.git_create_pr.title="
set "app.git_create_pr.body="
set "app.git_create_pr.draft=no"
set "app.git_create_pr.push=yes"
set "app.git_create_pr.current="
set "app.git_create_pr.dirty="
set "app.git_create_pr.origin="
set "app.git_create_pr.origin.slug="
set "app.git_create_pr.origin.owner="
set "app.git_create_pr.head.spec="
set "app.git_create_pr.login="
set "app.git_create_pr.target.input="
set "app.git_create_pr.target.slug="
set "app.git_create_pr.ahead="
set "app.git_create_pr.confirm="
set "app.git_create_pr.existing.url="
set "app.git_create_pr.remote.head="
set "app.git_create_pr.local.head="
set "app.git_create_pr.help="
set "app.git_create_pr.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :defaults
set "app.git_create_pr.rc=%errorlevel%"
goto :end
:defaults
if defined CFG_BRANCH set "app.git_create_pr.base=%CFG_BRANCH%"
if not defined app.git_create_pr.base set "app.git_create_pr.base=main"
:run
call :Main %*
set "app.git_create_pr.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_create_pr.rc%
:: ============================================================
:: :Main
:: Parses options, validates a clean named branch, authenticates
:: GitHub CLI, resolves repository context, confirms, pushes, and
:: creates the pull request.
::
:: Usage: call :Main [base BRANCH] [title TEXT] [body TEXT] [draft yes|no] [push yes|no]
::
:: Returns: 0 on success, cancellation, or an already-open PR
::          1 on repository, authentication, validation, push, or PR failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo,
::           :EnsureGitHubAuthentication, :LoadRepositoryContext,
::           :ValidatePullRequest, :ShowPlan, :CreatePullRequest,
::           :ShowHelp, prepare.bat, git, gh
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gprm_ 2^>nul') do set "%%v="
if defined _gprm_rc (set "_gprm_rc=" & exit /b %_gprm_rc%)
call :ParseArgs %*
set "_gprm_rc=%errorlevel%"
if not "%_gprm_rc%"=="0" goto :Main
if defined app.git_create_pr.help goto :_Main_help
call :NormalizeYesNo app.git_create_pr.draft
if errorlevel 1 (echo ERROR: draft must be yes or no. & set "_gprm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_create_pr.push
if errorlevel 1 (echo ERROR: push must be yes or no. & set "_gprm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Create GitHub pull request
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_gprm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gprm_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI was not found. & set "_gprm_rc=1" & goto :Main)
set "app.git_create_pr.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_create_pr.dirty=1"
if defined app.git_create_pr.dirty goto :_Main_dirty
set "app.git_create_pr.current="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_create_pr.current=%%A"
if not defined app.git_create_pr.current (echo ERROR: A named branch is not checked out. & set "_gprm_rc=1" & goto :Main)
if /I "%app.git_create_pr.current%"=="%app.git_create_pr.base%" (echo ERROR: Current branch and base branch are the same: & echo   %app.git_create_pr.base% & set "_gprm_rc=1" & goto :Main)
call :EnsureGitHubAuthentication
if errorlevel 1 (set "_gprm_rc=%errorlevel%" & goto :Main)
call :LoadRepositoryContext
if errorlevel 1 (set "_gprm_rc=%errorlevel%" & goto :Main)
call :ValidatePullRequest
if errorlevel 1 (set "_gprm_rc=%errorlevel%" & goto :Main)
if defined app.git_create_pr.existing.url goto :_Main_existing
call :ShowPlan
if errorlevel 1 (set "_gprm_rc=%errorlevel%" & goto :Main)
set /p "app.git_create_pr.confirm=Type PR to continue: "
if "%app.git_create_pr.confirm%"=="PR" goto :_Main_create
echo.
echo Cancelled. Nothing was changed.
set "_gprm_rc=0" & goto :Main
:_Main_create
call :CreatePullRequest
set "_gprm_rc=%errorlevel%" & goto :Main
:_Main_dirty
echo ERROR: The working tree has local changes.
echo Commit or stash them before creating a pull request.
echo.
git status --short
set "_gprm_rc=1" & goto :Main
:_Main_existing
echo.
echo An open pull request already exists:
echo   %app.git_create_pr.existing.url%
set "_gprm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_gprm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :EnsureGitHubAuthentication
:: Logs in when necessary, resolves the account login, and configures
:: Git HTTPS authentication.
::
:: Usage: call :EnsureGitHubAuthentication
::
:: Output:
::   app.git_create_pr.login  authenticated GitHub login
::
:: Returns: 0 on success
::          1 on login, account lookup, or setup failure
:: Requires: gh
:: ============================================================
:EnsureGitHubAuthentication
for /f "tokens=1 delims==" %%v in ('set gpra_ 2^>nul') do set "%%v="
if defined _gpra_rc (set "_gpra_rc=" & exit /b %_gpra_rc%)
gh auth status --hostname github.com >nul 2>nul
if not errorlevel 1 goto :_EnsureGitHubAuthentication_account
echo GitHub login is required.
echo A browser window will open for secure login.
gh auth login --hostname github.com --git-protocol https --web
if errorlevel 1 (echo ERROR: GitHub login failed or was cancelled. & set "_gpra_rc=1" & goto :EnsureGitHubAuthentication)
:_EnsureGitHubAuthentication_account
set "app.git_create_pr.login="
for /f "delims=" %%A in ('gh api user --jq ".login" 2^>nul') do set "app.git_create_pr.login=%%A"
if not defined app.git_create_pr.login (echo ERROR: Could not determine the logged-in GitHub account. & set "_gpra_rc=1" & goto :EnsureGitHubAuthentication)
gh auth setup-git --hostname github.com >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI could not configure Git authentication. & set "_gpra_rc=1" & goto :EnsureGitHubAuthentication)
set "_gpra_rc=0" & goto :EnsureGitHubAuthentication
:: ============================================================
:: :LoadRepositoryContext
:: Resolves origin, target repository, origin owner, and the PR head
:: specification after authentication is ready.
::
:: Usage: call :LoadRepositoryContext
::
:: Returns: 0 on success
::          1 when origin or target repository cannot be resolved
:: Requires: git, gh
:: ============================================================
:LoadRepositoryContext
for /f "tokens=1 delims==" %%v in ('set gprl_ 2^>nul') do set "%%v="
if defined _gprl_rc (set "_gprl_rc=" & exit /b %_gprl_rc%)
set "app.git_create_pr.origin="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_create_pr.origin=%%A"
if not defined app.git_create_pr.origin (echo ERROR: origin is not configured. & set "_gprl_rc=1" & goto :LoadRepositoryContext)
set "app.git_create_pr.origin.slug="
for /f "delims=" %%A in ('gh repo view "%app.git_create_pr.origin%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_create_pr.origin.slug=%%A"
if not defined app.git_create_pr.origin.slug (echo ERROR: Could not determine the origin GitHub repository. & set "_gprl_rc=1" & goto :LoadRepositoryContext)
for /f "tokens=1 delims=/" %%A in ("%app.git_create_pr.origin.slug%") do set "app.git_create_pr.origin.owner=%%A"
if defined app.upstream_url set "app.git_create_pr.target.input=%app.upstream_url%"
if not defined app.git_create_pr.target.input if defined app.fork_source_url set "app.git_create_pr.target.input=%app.fork_source_url%"
if not defined app.git_create_pr.target.input if defined CFG_REPO_URL set "app.git_create_pr.target.input=%CFG_REPO_URL%"
if not defined app.git_create_pr.target.input set "app.git_create_pr.target.input=%app.git_create_pr.origin%"
set "app.git_create_pr.target.slug="
for /f "delims=" %%A in ('gh repo view "%app.git_create_pr.target.input%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_create_pr.target.slug=%%A"
if not defined app.git_create_pr.target.slug (echo ERROR: Could not determine the pull request target repository. & set "_gprl_rc=1" & goto :LoadRepositoryContext)
set "app.git_create_pr.head.spec=%app.git_create_pr.current%"
if /I not "%app.git_create_pr.origin.slug%"=="%app.git_create_pr.target.slug%" set "app.git_create_pr.head.spec=%app.git_create_pr.origin.owner%:%app.git_create_pr.current%"
set "_gprl_rc=0" & goto :LoadRepositoryContext
:: ============================================================
:: :ValidatePullRequest
:: Fetches origin and base, verifies commits beyond base, validates
:: push=no remote state, derives a title, and checks for an open PR.
::
:: Usage: call :ValidatePullRequest
::
:: Returns: 0 when creation may continue or an open PR exists
::          1 on fetch, comparison, or remote-head failure
:: Requires: git, gh
:: ============================================================
:ValidatePullRequest
for /f "tokens=1 delims==" %%v in ('set gprv_ 2^>nul') do set "%%v="
if defined _gprv_rc (set "_gprv_rc=" & exit /b %_gprv_rc%)
git fetch --quiet origin
if errorlevel 1 (echo ERROR: Could not fetch origin. & set "_gprv_rc=1" & goto :ValidatePullRequest)
git fetch --quiet "%app.git_create_pr.target.input%" "%app.git_create_pr.base%"
if errorlevel 1 (echo ERROR: Could not fetch the base branch: & echo   %app.git_create_pr.target.slug%:%app.git_create_pr.base% & set "_gprv_rc=1" & goto :ValidatePullRequest)
set "app.git_create_pr.ahead="
for /f "delims=" %%A in ('git rev-list --count FETCH_HEAD..HEAD 2^>nul') do set "app.git_create_pr.ahead=%%A"
if not defined app.git_create_pr.ahead (echo ERROR: Commit comparison failed. & set "_gprv_rc=1" & goto :ValidatePullRequest)
if "%app.git_create_pr.ahead%"=="0" (echo ERROR: Current branch has no commits beyond the selected base branch. & set "_gprv_rc=1" & goto :ValidatePullRequest)
if defined app.git_create_pr.title goto :_ValidatePullRequest_remote
for /f "delims=" %%A in ('git log -1 --pretty^=%%s 2^>nul') do set "app.git_create_pr.title=%%A"
if not defined app.git_create_pr.title set "app.git_create_pr.title=Pull request from %app.git_create_pr.current%"
:_ValidatePullRequest_remote
if /I "%app.git_create_pr.push%"=="yes" goto :_ValidatePullRequest_existing
set "app.git_create_pr.remote.head="
set "app.git_create_pr.local.head="
for /f "tokens=1" %%A in ('git ls-remote --heads origin "refs/heads/%app.git_create_pr.current%" 2^>nul') do set "app.git_create_pr.remote.head=%%A"
for /f "delims=" %%A in ('git rev-parse HEAD 2^>nul') do set "app.git_create_pr.local.head=%%A"
if not defined app.git_create_pr.remote.head (echo ERROR: push is no, but the current branch is not on origin. & set "_gprv_rc=1" & goto :ValidatePullRequest)
if /I not "%app.git_create_pr.remote.head%"=="%app.git_create_pr.local.head%" (echo ERROR: push is no, but origin does not match the local branch. & echo Push the branch or use push yes. & set "_gprv_rc=1" & goto :ValidatePullRequest)
:_ValidatePullRequest_existing
set "app.git_create_pr.existing.url="
for /f "delims=" %%A in ('gh pr list --repo "%app.git_create_pr.target.slug%" --state open --head "%app.git_create_pr.head.spec%" --json url --jq ".[0].url" 2^>nul') do set "app.git_create_pr.existing.url=%%A"
set "_gprv_rc=0" & goto :ValidatePullRequest
:: ============================================================
:: :ShowPlan
:: Displays the authenticated account and pull-request plan.
::
:: Usage: call :ShowPlan
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowPlan
echo.
echo GitHub account:
echo   %app.git_create_pr.login%
echo.
echo Target repository:
echo   %app.git_create_pr.target.slug%
echo.
echo Base branch:
echo   %app.git_create_pr.base%
echo.
echo Head branch:
echo   %app.git_create_pr.head.spec%
echo.
echo Commits beyond base:
echo   %app.git_create_pr.ahead%
echo.
echo Title:
echo   %app.git_create_pr.title%
echo.
echo Draft:
echo   %app.git_create_pr.draft%
echo.
echo Push current branch first:
echo   %app.git_create_pr.push%
echo.
exit /b 0
:: ============================================================
:: :CreatePullRequest
:: Optionally pushes the current branch and creates the pull request.
::
:: Usage: call :CreatePullRequest
::
:: Returns: 0 on success
::          1 on push or creation failure
:: Requires: git, gh
:: ============================================================
:CreatePullRequest
for /f "tokens=1 delims==" %%v in ('set gprc_ 2^>nul') do set "%%v="
if defined _gprc_rc (set "_gprc_rc=" & exit /b %_gprc_rc%)
if /I "%app.git_create_pr.push%"=="no" goto :_CreatePullRequest_gh
git push -u origin "%app.git_create_pr.current%"
if errorlevel 1 (echo ERROR: Current branch could not be pushed. & set "_gprc_rc=1" & goto :CreatePullRequest)
:_CreatePullRequest_gh
if /I "%app.git_create_pr.draft%"=="yes" goto :_CreatePullRequest_draft
gh pr create --repo "%app.git_create_pr.target.slug%" --base "%app.git_create_pr.base%" --head "%app.git_create_pr.head.spec%" --title "%app.git_create_pr.title%" --body "%app.git_create_pr.body%"
goto :_CreatePullRequest_result
:_CreatePullRequest_draft
gh pr create --repo "%app.git_create_pr.target.slug%" --base "%app.git_create_pr.base%" --head "%app.git_create_pr.head.spec%" --title "%app.git_create_pr.title%" --body "%app.git_create_pr.body%" --draft
:_CreatePullRequest_result
if errorlevel 1 (echo ERROR: GitHub could not create the pull request. & set "_gprc_rc=1" & goto :CreatePullRequest)
echo.
echo Pull request created successfully.
set "_gprc_rc=0" & goto :CreatePullRequest
:: ============================================================
:: :ParseArgs
:: Parses base, title, body, draft, push, and help arguments.
::
:: Usage: call :ParseArgs [base BRANCH] [title TEXT] [body TEXT] [draft yes|no] [push yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="base" goto :_ParseArgs_base
if /I "%~1"=="title" goto :_ParseArgs_title
if /I "%~1"=="body" goto :_ParseArgs_body
if /I "%~1"=="draft" goto :_ParseArgs_draft
if /I "%~1"=="push" goto :_ParseArgs_push
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_base
if "%~2"=="" (echo ERROR: base requires a branch name. & exit /b 2)
set "app.git_create_pr.base=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_title
if "%~2"=="" (echo ERROR: title requires text. & exit /b 2)
set "app.git_create_pr.title=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_body
set "app.git_create_pr.body=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_draft
if "%~2"=="" (echo ERROR: draft requires yes or no. & exit /b 2)
set "app.git_create_pr.draft=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_push
if "%~2"=="" (echo ERROR: push requires yes or no. & exit /b 2)
set "app.git_create_pr.push=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_create_pr.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeYesNo
:: Normalizes a named variable to yes or no.
::
:: Usage: call :NormalizeYesNo variableName
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:NormalizeYesNo
for /f "tokens=1 delims==" %%v in ('set gpry_ 2^>nul') do set "%%v="
if defined _gpry_rc (set "_gpry_rc=" & exit /b %_gpry_rc%)
set "gpry_name=%~1"
call set "gpry_value=%%%gpry_name%%%"
if /I "%gpry_value%"=="y" set "%gpry_name%=yes"
if /I "%gpry_value%"=="yes" set "%gpry_name%=yes"
if /I "%gpry_value%"=="true" set "%gpry_name%=yes"
if /I "%gpry_value%"=="1" set "%gpry_name%=yes"
if /I "%gpry_value%"=="n" set "%gpry_name%=no"
if /I "%gpry_value%"=="no" set "%gpry_name%=no"
if /I "%gpry_value%"=="false" set "%gpry_name%=no"
if /I "%gpry_value%"=="0" set "%gpry_name%=no"
call set "gpry_value=%%%gpry_name%%%"
if /I "%gpry_value%"=="yes" (set "_gpry_rc=0" & goto :NormalizeYesNo)
if /I "%gpry_value%"=="no" (set "_gpry_rc=0" & goto :NormalizeYesNo)
set "_gpry_rc=1" & goto :NormalizeYesNo
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
echo git_create_pull_request.bat
echo.
echo Usage:
echo   git_create_pull_request.bat
echo   git_create_pull_request.bat base main
echo   git_create_pull_request.bat base main title "Add feature"
echo   git_create_pull_request.bat draft yes push yes
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
