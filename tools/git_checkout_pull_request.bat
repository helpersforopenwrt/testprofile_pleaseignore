@echo off
:: ============================================================
:: git_checkout_pull_request.bat
:: Checks out a GitHub pull request locally for review or testing.
::
:: Usage:
::   call tools\git_checkout_pull_request.bat number 12
::   call tools\git_checkout_pull_request.bat number 12 branch review-pr-12
::   call tools\git_checkout_pull_request.bat number 12 detach yes
::   call tools\git_checkout_pull_request.bat repo OWNER/REPO number 12
::
:: Returns: 0 on success or cancellation
::          1 on repository, authentication, safety, or checkout failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, gh, :Main, :ParseArgs,
::           :NormalizeYesNo, :ValidatePositiveNumber,
::           :ResolveRepository, :LoadPullRequest, :ValidateBranch,
::           :ShowPlan, :CheckoutPullRequest, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_checkout_pr.number="
set "app.git_checkout_pr.repo.input="
set "app.git_checkout_pr.repo.slug="
set "app.git_checkout_pr.branch="
set "app.git_checkout_pr.detach=no"
set "app.git_checkout_pr.allowclosed=no"
set "app.git_checkout_pr.state="
set "app.git_checkout_pr.title="
set "app.git_checkout_pr.url="
set "app.git_checkout_pr.dirty="
set "app.git_checkout_pr.current="
set "app.git_checkout_pr.confirm="
set "app.git_checkout_pr.help="
set "app.git_checkout_pr.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_checkout_pr.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_checkout_pr.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_checkout_pr.rc%
:: ============================================================
:: :Main
:: Parses options, validates repository and authentication state,
:: loads pull-request metadata, previews the checkout, and runs it.
::
:: Usage: call :Main number N [repo OWNER/REPO] [branch NAME] [detach yes|no] [allowclosed yes|no]
::
:: Returns: 0 on success or cancellation
::          1 on repository, authentication, safety, or checkout failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ValidatePositiveNumber,
::           :ResolveRepository, :LoadPullRequest, :ValidateBranch,
::           :ShowPlan, :CheckoutPullRequest, :ShowHelp, git, gh
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcpm_ 2^>nul') do set "%%v="
if defined _gcpm_rc (set "_gcpm_rc=" & exit /b %_gcpm_rc%)
call :ParseArgs %*
set "_gcpm_rc=%errorlevel%"
if not "%_gcpm_rc%"=="0" goto :Main
if defined app.git_checkout_pr.help goto :_Main_help
call :NormalizeYesNo app.git_checkout_pr.detach
if errorlevel 1 (echo ERROR: detach must be yes or no. & set "_gcpm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_checkout_pr.allowclosed
if errorlevel 1 (echo ERROR: allowclosed must be yes or no. & set "_gcpm_rc=2" & goto :Main)
if /I "%app.git_checkout_pr.detach%"=="yes" if defined app.git_checkout_pr.branch (echo ERROR: branch and detach yes cannot be used together. & set "_gcpm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Checkout GitHub pull request
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_gcpm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gcpm_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI was not found. & set "_gcpm_rc=1" & goto :Main)
gh auth status --hostname github.com >nul 2>nul
if errorlevel 1 goto :_Main_not_authenticated
set "app.git_checkout_pr.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_checkout_pr.dirty=1"
if defined app.git_checkout_pr.dirty goto :_Main_dirty
if not defined app.git_checkout_pr.number set /p "app.git_checkout_pr.number=Pull-request number: "
call :ValidatePositiveNumber "%app.git_checkout_pr.number%" number
if errorlevel 1 (set "_gcpm_rc=2" & goto :Main)
call :ResolveRepository
if errorlevel 1 (set "_gcpm_rc=%errorlevel%" & goto :Main)
call :LoadPullRequest
if errorlevel 1 (set "_gcpm_rc=%errorlevel%" & goto :Main)
call :ValidateBranch
if errorlevel 1 (set "_gcpm_rc=%errorlevel%" & goto :Main)
call :ShowPlan
if errorlevel 1 (set "_gcpm_rc=%errorlevel%" & goto :Main)
set /p "app.git_checkout_pr.confirm=Type CHECKOUT to continue: "
if "%app.git_checkout_pr.confirm%"=="CHECKOUT" goto :_Main_checkout
echo.
echo Cancelled. Nothing was changed.
set "_gcpm_rc=0" & goto :Main
:_Main_checkout
call :CheckoutPullRequest
set "_gcpm_rc=%errorlevel%" & goto :Main
:_Main_not_authenticated
echo ERROR: GitHub CLI is not logged in.
echo Run:
echo   just_login.bat
set "_gcpm_rc=1" & goto :Main
:_Main_dirty
echo ERROR: The working tree has local changes.
echo Commit or stash them before checking out a pull request.
echo.
git status --short
set "_gcpm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gcpm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ResolveRepository
:: Resolves the target GitHub repository from explicit arguments,
:: upstream configuration, project configuration, or origin.
::
:: Usage: call :ResolveRepository
::
:: Output:
::   app.git_checkout_pr.repo.input  selected repository input
::   app.git_checkout_pr.repo.slug   normalized OWNER/REPO
::
:: Returns: 0 on success
::          1 when no visible GitHub repository can be resolved
:: Requires: git, gh
:: ============================================================
:ResolveRepository
for /f "tokens=1 delims==" %%v in ('set gcprr_ 2^>nul') do set "%%v="
if defined _gcprr_rc (set "_gcprr_rc=" & exit /b %_gcprr_rc%)
if defined app.git_checkout_pr.repo.input goto :_ResolveRepository_view
if defined app.upstream_url set "app.git_checkout_pr.repo.input=%app.upstream_url%"
if defined app.git_checkout_pr.repo.input goto :_ResolveRepository_view
if defined app.fork_source_url set "app.git_checkout_pr.repo.input=%app.fork_source_url%"
if defined app.git_checkout_pr.repo.input goto :_ResolveRepository_view
if defined CFG_REPO_URL set "app.git_checkout_pr.repo.input=%CFG_REPO_URL%"
if defined app.git_checkout_pr.repo.input goto :_ResolveRepository_view
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_checkout_pr.repo.input=%%A"
if not defined app.git_checkout_pr.repo.input (echo ERROR: No GitHub repository is configured. & set "_gcprr_rc=1" & goto :ResolveRepository)
:_ResolveRepository_view
set "app.git_checkout_pr.repo.slug="
for /f "delims=" %%A in ('gh repo view "%app.git_checkout_pr.repo.input%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_checkout_pr.repo.slug=%%A"
if not defined app.git_checkout_pr.repo.slug (echo ERROR: Repository was not found or is not visible: & echo   %app.git_checkout_pr.repo.input% & set "_gcprr_rc=1" & goto :ResolveRepository)
set "_gcprr_rc=0" & goto :ResolveRepository
:: ============================================================
:: :LoadPullRequest
:: Loads state, title, and URL for the selected pull request and
:: enforces the allowclosed option.
::
:: Usage: call :LoadPullRequest
::
:: Output:
::   app.git_checkout_pr.state  pull-request state
::   app.git_checkout_pr.title  pull-request title
::   app.git_checkout_pr.url    pull-request URL
::
:: Returns: 0 when the pull request may be checked out
::          1 when unavailable or disallowed by state
:: Requires: gh
:: ============================================================
:LoadPullRequest
for /f "tokens=1 delims==" %%v in ('set gcprl_ 2^>nul') do set "%%v="
if defined _gcprl_rc (set "_gcprl_rc=" & exit /b %_gcprl_rc%)
set "app.git_checkout_pr.state="
set "app.git_checkout_pr.title="
set "app.git_checkout_pr.url="
for /f "delims=" %%A in ('gh pr view %app.git_checkout_pr.number% --repo "%app.git_checkout_pr.repo.slug%" --json state --jq ".state" 2^>nul') do set "app.git_checkout_pr.state=%%A"
for /f "delims=" %%A in ('gh pr view %app.git_checkout_pr.number% --repo "%app.git_checkout_pr.repo.slug%" --json title --jq ".title" 2^>nul') do set "app.git_checkout_pr.title=%%A"
for /f "delims=" %%A in ('gh pr view %app.git_checkout_pr.number% --repo "%app.git_checkout_pr.repo.slug%" --json url --jq ".url" 2^>nul') do set "app.git_checkout_pr.url=%%A"
if not defined app.git_checkout_pr.state (echo ERROR: Pull request was not found or is not visible: & echo   %app.git_checkout_pr.repo.slug%#%app.git_checkout_pr.number% & set "_gcprl_rc=1" & goto :LoadPullRequest)
if /I "%app.git_checkout_pr.state%"=="OPEN" (set "_gcprl_rc=0" & goto :LoadPullRequest)
if /I "%app.git_checkout_pr.allowclosed%"=="yes" (set "_gcprl_rc=0" & goto :LoadPullRequest)
echo ERROR: Pull request is not open.
echo   state: %app.git_checkout_pr.state%
echo.
echo To inspect it anyway, add:
echo   allowclosed yes
set "_gcprl_rc=1" & goto :LoadPullRequest
:: ============================================================
:: :ValidateBranch
:: Validates the optional local branch name.
::
:: Usage: call :ValidateBranch
::
:: Returns: 0 when absent or valid
::          2 when invalid
:: Requires: git
:: ============================================================
:ValidateBranch
for /f "tokens=1 delims==" %%v in ('set gcprb_ 2^>nul') do set "%%v="
if defined _gcprb_rc (set "_gcprb_rc=" & exit /b %_gcprb_rc%)
if not defined app.git_checkout_pr.branch (set "_gcprb_rc=0" & goto :ValidateBranch)
git check-ref-format --branch "%app.git_checkout_pr.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid local branch name: & echo   %app.git_checkout_pr.branch% & set "_gcprb_rc=2" & goto :ValidateBranch)
set "_gcprb_rc=0" & goto :ValidateBranch
:: ============================================================
:: :ShowPlan
:: Displays the selected pull request and checkout mode.
::
:: Usage: call :ShowPlan
::
:: Returns: 0 when details are displayed
::          1 when gh cannot display the pull request
:: Requires: git, gh
:: ============================================================
:ShowPlan
for /f "tokens=1 delims==" %%v in ('set gcprs_ 2^>nul') do set "%%v="
if defined _gcprs_rc (set "_gcprs_rc=" & exit /b %_gcprs_rc%)
set "app.git_checkout_pr.current="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_checkout_pr.current=%%A"
echo Repository:
echo   %app.git_checkout_pr.repo.slug%
echo.
echo Pull request:
echo   #%app.git_checkout_pr.number% %app.git_checkout_pr.title%
echo.
echo State:
echo   %app.git_checkout_pr.state%
echo.
if defined app.git_checkout_pr.url echo URL: %app.git_checkout_pr.url%
echo Current branch:
if defined app.git_checkout_pr.current goto :_ShowPlan_branch
echo   detached HEAD
goto :_ShowPlan_mode
:_ShowPlan_branch
echo   %app.git_checkout_pr.current%
:_ShowPlan_mode
echo.
if defined app.git_checkout_pr.branch echo Requested local branch: %app.git_checkout_pr.branch%
echo Detached checkout:
echo   %app.git_checkout_pr.detach%
echo.
echo Pull-request details:
echo.
gh pr view %app.git_checkout_pr.number% --repo "%app.git_checkout_pr.repo.slug%"
if errorlevel 1 (echo ERROR: Pull-request details could not be displayed. & set "_gcprs_rc=1" & goto :ShowPlan)
echo.
set "_gcprs_rc=0" & goto :ShowPlan
:: ============================================================
:: :CheckoutPullRequest
:: Runs gh pr checkout using the selected branch or detached mode.
::
:: Usage: call :CheckoutPullRequest
::
:: Returns: 0 on success
::          1 on checkout failure
:: Requires: gh, git
:: ============================================================
:CheckoutPullRequest
for /f "tokens=1 delims==" %%v in ('set gcprc_ 2^>nul') do set "%%v="
if defined _gcprc_rc (set "_gcprc_rc=" & exit /b %_gcprc_rc%)
if /I "%app.git_checkout_pr.detach%"=="yes" goto :_CheckoutPullRequest_detached
if defined app.git_checkout_pr.branch goto :_CheckoutPullRequest_named
gh pr checkout %app.git_checkout_pr.number% --repo "%app.git_checkout_pr.repo.slug%"
goto :_CheckoutPullRequest_result
:_CheckoutPullRequest_named
gh pr checkout %app.git_checkout_pr.number% --repo "%app.git_checkout_pr.repo.slug%" --branch "%app.git_checkout_pr.branch%"
goto :_CheckoutPullRequest_result
:_CheckoutPullRequest_detached
gh pr checkout %app.git_checkout_pr.number% --repo "%app.git_checkout_pr.repo.slug%" --detach
:_CheckoutPullRequest_result
if errorlevel 1 (echo. & echo ERROR: Pull-request checkout failed. & echo No force option was used. & set "_gcprc_rc=1" & goto :CheckoutPullRequest)
echo.
echo Pull request checked out successfully.
echo.
git status --short --branch
echo.
set "_gcprc_rc=0" & goto :CheckoutPullRequest
:: ============================================================
:: :ValidatePositiveNumber
:: Validates a positive integer argument.
::
:: Usage: call :ValidatePositiveNumber "value" argumentName
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:ValidatePositiveNumber
for /f "tokens=1 delims==" %%v in ('set gcprn_ 2^>nul') do set "%%v="
if defined _gcprn_rc (set "_gcprn_rc=" & exit /b %_gcprn_rc%)
set "gcprn_value=%~1"
set "gcprn_name=%~2"
set "gcprn_invalid="
if not defined gcprn_value (echo ERROR: %gcprn_name% requires a positive number. & set "_gcprn_rc=1" & goto :ValidatePositiveNumber)
for /f "delims=0123456789" %%A in ("%gcprn_value%") do set "gcprn_invalid=%%A"
if defined gcprn_invalid (echo ERROR: %gcprn_name% must be a positive number. & set "_gcprn_rc=1" & goto :ValidatePositiveNumber)
if "%gcprn_value%"=="0" (echo ERROR: %gcprn_name% must be 1 or greater. & set "_gcprn_rc=1" & goto :ValidatePositiveNumber)
set "_gcprn_rc=0" & goto :ValidatePositiveNumber
:: ============================================================
:: :ParseArgs
:: Parses pull-request checkout arguments.
::
:: Usage: call :ParseArgs [number N] [repo OWNER/REPO] [branch NAME] [detach yes|no] [allowclosed yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="number" goto :_ParseArgs_number
if /I "%~1"=="pr" goto :_ParseArgs_number
if /I "%~1"=="repo" goto :_ParseArgs_repo
if /I "%~1"=="branch" goto :_ParseArgs_branch
if /I "%~1"=="detach" goto :_ParseArgs_detach
if /I "%~1"=="allowclosed" goto :_ParseArgs_allowclosed
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_checkout_pr.number (set "app.git_checkout_pr.number=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_number
if "%~2"=="" (echo ERROR: number requires a pull-request number. & exit /b 2)
set "app.git_checkout_pr.number=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_repo
if "%~2"=="" (echo ERROR: repo requires OWNER/REPO or a URL. & exit /b 2)
set "app.git_checkout_pr.repo.input=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_branch
if "%~2"=="" (echo ERROR: branch requires a local branch name. & exit /b 2)
set "app.git_checkout_pr.branch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_detach
if "%~2"=="" (echo ERROR: detach requires yes or no. & exit /b 2)
set "app.git_checkout_pr.detach=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_allowclosed
if "%~2"=="" (echo ERROR: allowclosed requires yes or no. & exit /b 2)
set "app.git_checkout_pr.allowclosed=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_checkout_pr.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gcpry_ 2^>nul') do set "%%v="
if defined _gcpry_rc (set "_gcpry_rc=" & exit /b %_gcpry_rc%)
set "gcpry_name=%~1"
call set "gcpry_value=%%%gcpry_name%%%"
if /I "%gcpry_value%"=="y" set "%gcpry_name%=yes"
if /I "%gcpry_value%"=="yes" set "%gcpry_name%=yes"
if /I "%gcpry_value%"=="true" set "%gcpry_name%=yes"
if /I "%gcpry_value%"=="1" set "%gcpry_name%=yes"
if /I "%gcpry_value%"=="n" set "%gcpry_name%=no"
if /I "%gcpry_value%"=="no" set "%gcpry_name%=no"
if /I "%gcpry_value%"=="false" set "%gcpry_name%=no"
if /I "%gcpry_value%"=="0" set "%gcpry_name%=no"
call set "gcpry_value=%%%gcpry_name%%%"
if /I "%gcpry_value%"=="yes" (set "_gcpry_rc=0" & goto :NormalizeYesNo)
if /I "%gcpry_value%"=="no" (set "_gcpry_rc=0" & goto :NormalizeYesNo)
set "_gcpry_rc=1" & goto :NormalizeYesNo
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
echo git_checkout_pull_request.bat
echo.
echo Usage:
echo   git_checkout_pull_request.bat number 12
echo   git_checkout_pull_request.bat number 12 branch review-pr-12
echo   git_checkout_pull_request.bat number 12 detach yes
echo   git_checkout_pull_request.bat repo OWNER/REPO number 12
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
