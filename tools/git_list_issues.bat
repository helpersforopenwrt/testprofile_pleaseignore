@echo off
:: ============================================================
:: git_list_issues.bat
:: Lists GitHub issues for the configured repository using optional
:: state, assignee, author, label, search, and limit filters.
::
:: Usage:
::   call tools\git_list_issues.bat
::   call tools\git_list_issues.bat state all
::   call tools\git_list_issues.bat assignee @me
::   call tools\git_list_issues.bat labels "bug,windows"
::   call tools\git_list_issues.bat search "no:assignee sort:created-desc"
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
set "app.git_list_issues.repo.input="
set "app.git_list_issues.repo.slug="
set "app.git_list_issues.state=open"
set "app.git_list_issues.assignee="
set "app.git_list_issues.author="
set "app.git_list_issues.labels="
set "app.git_list_issues.search="
set "app.git_list_issues.limit=30"
set "app.git_list_issues.help="
set "app.git_list_issues.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_list_issues.rc=%errorlevel%"
goto :end
:run
if defined app.upstream_url set "app.git_list_issues.repo.input=%app.upstream_url%"
if not defined app.git_list_issues.repo.input if defined app.fork_source_url set "app.git_list_issues.repo.input=%app.fork_source_url%"
if not defined app.git_list_issues.repo.input set "app.git_list_issues.repo.input=%CFG_REPO_URL%"
call :Main %*
set "app.git_list_issues.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_list_issues.rc%
:: ============================================================
:: :Main
:: Parses filters, prepares dependencies, resolves the repository,
:: and lists matching GitHub issues.
::
:: Usage: call :Main [repo REPO] [state VALUE] [assignee LOGIN]
::        [author LOGIN] [labels LIST] [search QUERY] [limit N]
::
:: Returns: 0 on successful listing or help display
::          1 on dependency, authentication, repository, or listing failure
::          2 on invalid arguments
:: Requires: :ResolveRepository, :RunList, :ParseArgs, :NormalizeState,
::           :ValidatePositiveNumber, :ShowHelp, prepare.bat, git, gh
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set glim_ 2^>nul') do set "%%v="
if defined _glim_rc (set "_glim_rc=" & exit /b %_glim_rc%)
call :ParseArgs %*
set "_glim_rc=%errorlevel%"
if not "%_glim_rc%"=="0" goto :Main
if defined app.git_list_issues.help goto :_Main_help
call :NormalizeState
if errorlevel 1 (set "_glim_rc=2" & goto :Main)
call :ValidatePositiveNumber "%app.git_list_issues.limit%" limit
if errorlevel 1 (set "_glim_rc=2" & goto :Main)
if /I "%app.git_list_issues.assignee%"=="me" set "app.git_list_issues.assignee=@me"
if /I "%app.git_list_issues.author%"=="me" set "app.git_list_issues.author=@me"
echo.
echo ============================================================
echo  List GitHub issues
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_glim_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_glim_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI was not found in PATH. & set "_glim_rc=1" & goto :Main)
gh auth status --hostname github.com >nul 2>nul
if errorlevel 1 goto :_Main_logged_out
call :ResolveRepository
if errorlevel 1 (set "_glim_rc=%errorlevel%" & goto :Main)
echo Repository:
echo   %app.git_list_issues.repo.slug%
echo.
echo State:
echo   %app.git_list_issues.state%
echo.
echo Limit:
echo   %app.git_list_issues.limit%
echo.
if defined app.git_list_issues.assignee (echo Assignee: & echo   "%app.git_list_issues.assignee%" & echo.)
if defined app.git_list_issues.author (echo Author: & echo   "%app.git_list_issues.author%" & echo.)
if defined app.git_list_issues.labels (echo Labels: & echo   "%app.git_list_issues.labels%" & echo.)
if defined app.git_list_issues.search (echo Search: & echo   "%app.git_list_issues.search%" & echo.)
call :RunList
set "_glim_rc=%errorlevel%"
if "%_glim_rc%"=="0" goto :Main
echo ERROR: GitHub issue listing failed.
goto :Main
:_Main_logged_out
echo ERROR: GitHub CLI is not logged in.
echo Run:
echo   just_login.bat
set "_glim_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_glim_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ResolveRepository
:: Resolves the configured repository to an OWNER/REPO slug, falling
:: back to origin when no project repository setting is available.
::
:: Usage: call :ResolveRepository
::
:: Output:
::   app.git_list_issues.repo.slug  resolved OWNER/REPO
::
:: Returns: 0 when resolved
::          1 when missing or inaccessible
:: Requires: git, gh
:: ============================================================
:ResolveRepository
for /f "tokens=1 delims==" %%v in ('set glir_ 2^>nul') do set "%%v="
if defined _glir_rc (set "_glir_rc=" & exit /b %_glir_rc%)
if defined app.git_list_issues.repo.input goto :_ResolveRepository_query
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_list_issues.repo.input=%%A"
:_ResolveRepository_query
if not defined app.git_list_issues.repo.input (echo ERROR: No GitHub repository is configured. & set "_glir_rc=1" & goto :ResolveRepository)
for /f "delims=" %%A in ('gh repo view "%app.git_list_issues.repo.input%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_list_issues.repo.slug=%%A"
if not defined app.git_list_issues.repo.slug (echo ERROR: Repository was not found or is not visible: & echo   %app.git_list_issues.repo.input% & set "_glir_rc=1" & goto :ResolveRepository)
set "_glir_rc=0" & goto :ResolveRepository
:: ============================================================
:: :RunList
:: Runs gh issue list with only the optional filters that were
:: supplied, avoiding malformed empty command-line options.
::
:: Usage: call :RunList
::
:: Returns: GitHub CLI exit code
:: Requires: gh
:: ============================================================
:RunList
for /f "tokens=1 delims==" %%v in ('set rli_ 2^>nul') do set "%%v="
if defined _rli_rc (set "_rli_rc=" & exit /b %_rli_rc%)
set "rli_key="
if defined app.git_list_issues.assignee (set "rli_key=%rli_key%1") else (set "rli_key=%rli_key%0")
if defined app.git_list_issues.author (set "rli_key=%rli_key%1") else (set "rli_key=%rli_key%0")
if defined app.git_list_issues.labels (set "rli_key=%rli_key%1") else (set "rli_key=%rli_key%0")
if defined app.git_list_issues.search (set "rli_key=%rli_key%1") else (set "rli_key=%rli_key%0")
if "%rli_key%"=="0000" goto :_RunList_0000
if "%rli_key%"=="0001" goto :_RunList_0001
if "%rli_key%"=="0010" goto :_RunList_0010
if "%rli_key%"=="0011" goto :_RunList_0011
if "%rli_key%"=="0100" goto :_RunList_0100
if "%rli_key%"=="0101" goto :_RunList_0101
if "%rli_key%"=="0110" goto :_RunList_0110
if "%rli_key%"=="0111" goto :_RunList_0111
if "%rli_key%"=="1000" goto :_RunList_1000
if "%rli_key%"=="1001" goto :_RunList_1001
if "%rli_key%"=="1010" goto :_RunList_1010
if "%rli_key%"=="1011" goto :_RunList_1011
if "%rli_key%"=="1100" goto :_RunList_1100
if "%rli_key%"=="1101" goto :_RunList_1101
if "%rli_key%"=="1110" goto :_RunList_1110
if "%rli_key%"=="1111" goto :_RunList_1111
set "_rli_rc=1" & goto :RunList
:_RunList_0000
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit%
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_0001
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --search "%app.git_list_issues.search%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_0010
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --label "%app.git_list_issues.labels%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_0011
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --label "%app.git_list_issues.labels%" --search "%app.git_list_issues.search%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_0100
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --author "%app.git_list_issues.author%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_0101
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --author "%app.git_list_issues.author%" --search "%app.git_list_issues.search%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_0110
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --author "%app.git_list_issues.author%" --label "%app.git_list_issues.labels%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_0111
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --author "%app.git_list_issues.author%" --label "%app.git_list_issues.labels%" --search "%app.git_list_issues.search%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_1000
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --assignee "%app.git_list_issues.assignee%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_1001
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --assignee "%app.git_list_issues.assignee%" --search "%app.git_list_issues.search%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_1010
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --assignee "%app.git_list_issues.assignee%" --label "%app.git_list_issues.labels%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_1011
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --assignee "%app.git_list_issues.assignee%" --label "%app.git_list_issues.labels%" --search "%app.git_list_issues.search%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_1100
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --assignee "%app.git_list_issues.assignee%" --author "%app.git_list_issues.author%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_1101
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --assignee "%app.git_list_issues.assignee%" --author "%app.git_list_issues.author%" --search "%app.git_list_issues.search%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_1110
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --assignee "%app.git_list_issues.assignee%" --author "%app.git_list_issues.author%" --label "%app.git_list_issues.labels%"
set "_rli_rc=%errorlevel%" & goto :RunList
:_RunList_1111
gh issue list --repo "%app.git_list_issues.repo.slug%" --state "%app.git_list_issues.state%" --limit %app.git_list_issues.limit% --assignee "%app.git_list_issues.assignee%" --author "%app.git_list_issues.author%" --label "%app.git_list_issues.labels%" --search "%app.git_list_issues.search%"
set "_rli_rc=%errorlevel%" & goto :RunList
:: ============================================================
:: :ParseArgs
:: Parses repository and issue-list filter arguments.
::
:: Usage: call :ParseArgs [repo REPO] [state VALUE] [assignee LOGIN]
::        [author LOGIN] [labels LIST] [search QUERY] [limit N]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="repo" goto :_ParseArgs_repo
if /I "%~1"=="state" goto :_ParseArgs_state
if /I "%~1"=="assignee" goto :_ParseArgs_assignee
if /I "%~1"=="author" goto :_ParseArgs_author
if /I "%~1"=="labels" goto :_ParseArgs_labels
if /I "%~1"=="label" goto :_ParseArgs_labels
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
set "app.git_list_issues.repo.input=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_state
if "%~2"=="" (echo ERROR: state requires open, closed, or all. & exit /b 2)
set "app.git_list_issues.state=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_assignee
if "%~2"=="" (echo ERROR: assignee requires a login or @me. & exit /b 2)
set "app.git_list_issues.assignee=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_author
if "%~2"=="" (echo ERROR: author requires a login or @me. & exit /b 2)
set "app.git_list_issues.author=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_labels
if "%~2"=="" (echo ERROR: labels requires a comma-separated value. & exit /b 2)
set "app.git_list_issues.labels=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_search
if "%~2"=="" (echo ERROR: search requires an expression. & exit /b 2)
set "app.git_list_issues.search=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_limit
if "%~2"=="" (echo ERROR: limit requires a positive number. & exit /b 2)
set "app.git_list_issues.limit=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_list_issues.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeState
:: Normalizes and validates the issue state filter.
::
:: Usage: call :NormalizeState
::
:: Returns: 0 for open, closed, or all
::          1 otherwise
:: Requires: none
:: ============================================================
:NormalizeState
if /I "%app.git_list_issues.state%"=="open" set "app.git_list_issues.state=open"
if /I "%app.git_list_issues.state%"=="closed" set "app.git_list_issues.state=closed"
if /I "%app.git_list_issues.state%"=="all" set "app.git_list_issues.state=all"
if "%app.git_list_issues.state%"=="open" exit /b 0
if "%app.git_list_issues.state%"=="closed" exit /b 0
if "%app.git_list_issues.state%"=="all" exit /b 0
echo ERROR: state must be open, closed, or all.
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
for /f "tokens=1 delims==" %%v in ('set glin_ 2^>nul') do set "%%v="
if defined _glin_rc (set "_glin_rc=" & exit /b %_glin_rc%)
set "glin_value=%~1"
set "glin_name=%~2"
if not defined glin_value (echo ERROR: %glin_name% requires a positive whole number. & set "_glin_rc=1" & goto :ValidatePositiveNumber)
set "glin_invalid="
for /f "delims=0123456789" %%A in ("%glin_value%") do set "glin_invalid=%%A"
if defined glin_invalid (echo ERROR: %glin_name% must be a positive whole number. & set "_glin_rc=1" & goto :ValidatePositiveNumber)
if "%glin_value%"=="0" (echo ERROR: %glin_name% must be 1 or greater. & set "_glin_rc=1" & goto :ValidatePositiveNumber)
set "_glin_rc=0" & goto :ValidatePositiveNumber
:: ============================================================
:: :ShowHelp
:: Displays issue-list filter usage.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_list_issues.bat
echo.
echo Usage:
echo   git_list_issues.bat
echo   git_list_issues.bat state all
echo   git_list_issues.bat assignee @me
echo   git_list_issues.bat labels "bug,windows"
echo   git_list_issues.bat search "no:assignee sort:created-desc"
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
