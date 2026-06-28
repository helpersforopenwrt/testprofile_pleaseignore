@echo off
:: ============================================================
:: git_list_pull_requests.bat
:: Lists GitHub pull requests for the configured repository using
:: optional state, author, search, and limit filters.
::
:: Usage:
::   call tools\git_list_pull_requests.bat
::   call tools\git_list_pull_requests.bat state all
::   call tools\git_list_pull_requests.bat author @me
::   call tools\git_list_pull_requests.bat search "review-requested:@me"
::   call tools\git_list_pull_requests.bat repo OWNER/REPO limit 50
::
:: Returns: 0 on successful listing or help display
::          1 on dependency, authentication, repository, or listing failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, gh, :Main, :ResolveRepository,
::           :RunList, :ParseArgs, :NormalizeState, :ValidatePositiveNumber,
::           :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_list_pr.repo.input="
set "app.git_list_pr.repo.slug="
set "app.git_list_pr.state=open"
set "app.git_list_pr.author="
set "app.git_list_pr.search="
set "app.git_list_pr.limit=30"
set "app.git_list_pr.help="
set "app.git_list_pr.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_list_pr.rc=%errorlevel%"
goto :end
:run
if defined app.upstream_url set "app.git_list_pr.repo.input=%app.upstream_url%"
if not defined app.git_list_pr.repo.input if defined app.fork_source_url set "app.git_list_pr.repo.input=%app.fork_source_url%"
if not defined app.git_list_pr.repo.input set "app.git_list_pr.repo.input=%CFG_REPO_URL%"
call :Main %*
set "app.git_list_pr.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_list_pr.rc%
:: ============================================================
:: :Main
:: Parses filters, prepares dependencies, resolves the repository,
:: and lists matching GitHub pull requests.
::
:: Usage: call :Main [repo REPO] [state VALUE] [author LOGIN]
::        [search QUERY] [limit N]
::
:: Returns: 0 on successful listing or help display
::          1 on dependency, authentication, repository, or listing failure
::          2 on invalid arguments
:: Requires: :ResolveRepository, :RunList, :ParseArgs, :NormalizeState,
::           :ValidatePositiveNumber, :ShowHelp, prepare.bat, git, gh
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set glpm_ 2^>nul') do set "%%v="
if defined _glpm_rc (set "_glpm_rc=" & exit /b %_glpm_rc%)
call :ParseArgs %*
set "_glpm_rc=%errorlevel%"
if not "%_glpm_rc%"=="0" goto :Main
if defined app.git_list_pr.help goto :_Main_help
call :NormalizeState
if errorlevel 1 (set "_glpm_rc=2" & goto :Main)
call :ValidatePositiveNumber "%app.git_list_pr.limit%" limit
if errorlevel 1 (set "_glpm_rc=2" & goto :Main)
if /I "%app.git_list_pr.author%"=="me" set "app.git_list_pr.author=@me"
echo.
echo ============================================================
echo  List GitHub pull requests
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_glpm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_glpm_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI was not found in PATH. & set "_glpm_rc=1" & goto :Main)
gh auth status --hostname github.com >nul 2>nul
if errorlevel 1 goto :_Main_logged_out
call :ResolveRepository
if errorlevel 1 (set "_glpm_rc=%errorlevel%" & goto :Main)
echo Repository:
echo   %app.git_list_pr.repo.slug%
echo.
echo State:
echo   %app.git_list_pr.state%
echo.
echo Limit:
echo   %app.git_list_pr.limit%
echo.
if defined app.git_list_pr.author (echo Author: & echo   "%app.git_list_pr.author%" & echo.)
if defined app.git_list_pr.search (echo Search: & echo   "%app.git_list_pr.search%" & echo.)
call :RunList
set "_glpm_rc=%errorlevel%"
if "%_glpm_rc%"=="0" goto :Main
echo ERROR: GitHub pull-request listing failed.
goto :Main
:_Main_logged_out
echo ERROR: GitHub CLI is not logged in.
echo Run:
echo   just_login.bat
set "_glpm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_glpm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ResolveRepository
:: Resolves the configured repository to an OWNER/REPO slug, falling
:: back to origin when no project repository setting is available.
::
:: Usage: call :ResolveRepository
::
:: Output:
::   app.git_list_pr.repo.slug  resolved OWNER/REPO
::
:: Returns: 0 when resolved
::          1 when missing or inaccessible
:: Requires: git, gh
:: ============================================================
:ResolveRepository
for /f "tokens=1 delims==" %%v in ('set glpr_ 2^>nul') do set "%%v="
if defined _glpr_rc (set "_glpr_rc=" & exit /b %_glpr_rc%)
if defined app.git_list_pr.repo.input goto :_ResolveRepository_query
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_list_pr.repo.input=%%A"
:_ResolveRepository_query
if not defined app.git_list_pr.repo.input (echo ERROR: No GitHub repository is configured. & set "_glpr_rc=1" & goto :ResolveRepository)
for /f "delims=" %%A in ('gh repo view "%app.git_list_pr.repo.input%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_list_pr.repo.slug=%%A"
if not defined app.git_list_pr.repo.slug (echo ERROR: Repository was not found or is not visible: & echo   %app.git_list_pr.repo.input% & set "_glpr_rc=1" & goto :ResolveRepository)
set "_glpr_rc=0" & goto :ResolveRepository
:: ============================================================
:: :RunList
:: Runs gh pr list with only the optional filters that were
:: supplied, avoiding malformed empty command-line options.
::
:: Usage: call :RunList
::
:: Returns: GitHub CLI exit code
:: Requires: gh
:: ============================================================
:RunList
for /f "tokens=1 delims==" %%v in ('set rlp_ 2^>nul') do set "%%v="
if defined _rlp_rc (set "_rlp_rc=" & exit /b %_rlp_rc%)
set "rlp_key="
if defined app.git_list_pr.author (set "rlp_key=%rlp_key%1") else (set "rlp_key=%rlp_key%0")
if defined app.git_list_pr.search (set "rlp_key=%rlp_key%1") else (set "rlp_key=%rlp_key%0")
if "%rlp_key%"=="00" goto :_RunList_00
if "%rlp_key%"=="01" goto :_RunList_01
if "%rlp_key%"=="10" goto :_RunList_10
if "%rlp_key%"=="11" goto :_RunList_11
set "_rlp_rc=1" & goto :RunList
:_RunList_00
gh pr list --repo "%app.git_list_pr.repo.slug%" --state "%app.git_list_pr.state%" --limit %app.git_list_pr.limit%
set "_rlp_rc=%errorlevel%" & goto :RunList
:_RunList_01
gh pr list --repo "%app.git_list_pr.repo.slug%" --state "%app.git_list_pr.state%" --limit %app.git_list_pr.limit% --search "%app.git_list_pr.search%"
set "_rlp_rc=%errorlevel%" & goto :RunList
:_RunList_10
gh pr list --repo "%app.git_list_pr.repo.slug%" --state "%app.git_list_pr.state%" --limit %app.git_list_pr.limit% --author "%app.git_list_pr.author%"
set "_rlp_rc=%errorlevel%" & goto :RunList
:_RunList_11
gh pr list --repo "%app.git_list_pr.repo.slug%" --state "%app.git_list_pr.state%" --limit %app.git_list_pr.limit% --author "%app.git_list_pr.author%" --search "%app.git_list_pr.search%"
set "_rlp_rc=%errorlevel%" & goto :RunList
:: ============================================================
:: :ParseArgs
:: Parses repository and pull-request list filter arguments.
::
:: Usage: call :ParseArgs [repo REPO] [state VALUE] [author LOGIN]
::        [search QUERY] [limit N]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="repo" goto :_ParseArgs_repo
if /I "%~1"=="state" goto :_ParseArgs_state
if /I "%~1"=="author" goto :_ParseArgs_author
if /I "%~1"=="search" goto :_ParseArgs_search
if /I "%~1"=="limit" goto :_ParseArgs_limit
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_repo
if "%~2"=="" (echo ERROR: repo requires OWNER/REPO or a URL. & exit /b 2)
set "app.git_list_pr.repo.input=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_state
if "%~2"=="" (echo ERROR: state requires open, closed, merged, or all. & exit /b 2)
set "app.git_list_pr.state=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_author
if "%~2"=="" (echo ERROR: author requires a login or @me. & exit /b 2)
set "app.git_list_pr.author=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_search
if "%~2"=="" (echo ERROR: search requires an expression. & exit /b 2)
set "app.git_list_pr.search=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_limit
if "%~2"=="" (echo ERROR: limit requires a positive number. & exit /b 2)
set "app.git_list_pr.limit=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_list_pr.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeState
:: Normalizes and validates the pull-request state filter.
::
:: Usage: call :NormalizeState
::
:: Returns: 0 for open, closed, merged, or all
::          1 otherwise
:: Requires: none
:: ============================================================
:NormalizeState
if /I "%app.git_list_pr.state%"=="open" set "app.git_list_pr.state=open"
if /I "%app.git_list_pr.state%"=="closed" set "app.git_list_pr.state=closed"
if /I "%app.git_list_pr.state%"=="merged" set "app.git_list_pr.state=merged"
if /I "%app.git_list_pr.state%"=="all" set "app.git_list_pr.state=all"
if "%app.git_list_pr.state%"=="open" exit /b 0
if "%app.git_list_pr.state%"=="closed" exit /b 0
if "%app.git_list_pr.state%"=="merged" exit /b 0
if "%app.git_list_pr.state%"=="all" exit /b 0
echo ERROR: state must be open, closed, merged, or all.
exit /b 1
:: ============================================================
:: :ValidatePositiveNumber
:: Validates a required positive whole-number value.
::
:: Usage: call :ValidatePositiveNumber "value" name
::
:: Returns: 0 when valid
::          1 when empty, nonnumeric, or zero
:: Requires: none
:: ============================================================
:ValidatePositiveNumber
for /f "tokens=1 delims==" %%v in ('set glpn_ 2^>nul') do set "%%v="
if defined _glpn_rc (set "_glpn_rc=" & exit /b %_glpn_rc%)
set "glpn_value=%~1"
set "glpn_name=%~2"
if not defined glpn_value (echo ERROR: %glpn_name% requires a positive whole number. & set "_glpn_rc=1" & goto :ValidatePositiveNumber)
set "glpn_invalid="
for /f "delims=0123456789" %%A in ("%glpn_value%") do set "glpn_invalid=%%A"
if defined glpn_invalid (echo ERROR: %glpn_name% must be a positive whole number. & set "_glpn_rc=1" & goto :ValidatePositiveNumber)
if "%glpn_value%"=="0" (echo ERROR: %glpn_name% must be 1 or greater. & set "_glpn_rc=1" & goto :ValidatePositiveNumber)
set "_glpn_rc=0" & goto :ValidatePositiveNumber
:: ============================================================
:: :ShowHelp
:: Displays pull-request list filter usage.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_list_pull_requests.bat
echo.
echo Usage:
echo   git_list_pull_requests.bat
echo   git_list_pull_requests.bat state all
echo   git_list_pull_requests.bat author @me
echo   git_list_pull_requests.bat search "review-requested:@me"
echo   git_list_pull_requests.bat repo OWNER/REPO limit 50
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
