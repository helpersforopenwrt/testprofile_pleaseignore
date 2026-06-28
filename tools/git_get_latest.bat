@echo off
:: ============================================================
:: git_get_latest.bat
:: Fetches the current branch's configured upstream and applies only
:: a clean fast-forward update. It never creates a merge commit.
::
:: Usage:
::   call tools\git_get_latest.bat
::   call tools\git_get_latest.bat help
::
:: Returns: 0 when current, updated, ahead only, or help displayed
::          1 on dependency, repository, dirty-tree, fetch, tracking,
::            divergence, count, or fast-forward failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_get_latest.branch="
set "app.git_get_latest.upstream="
set "app.git_get_latest.remote="
set "app.git_get_latest.dirty="
set "app.git_get_latest.ahead="
set "app.git_get_latest.behind="
set "app.git_get_latest.help="
set "app.git_get_latest.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_get_latest.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_get_latest.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_get_latest.rc%
:: ============================================================
:: :Main
:: Parses arguments, prepares Git, requires a clean named branch with
:: tracking, fetches its remote, and fast-forwards when behind only.
::
:: Usage: call :Main [help]
::
:: Returns: 0 when current, updated, ahead only, or help displayed
::          1 on dependency, repository, dirty-tree, fetch, tracking,
::            divergence, count, or fast-forward failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gglm_ 2^>nul') do set "%%v="
if defined _gglm_rc (set "_gglm_rc=" & exit /b %_gglm_rc%)
call :ParseArgs %*
set "_gglm_rc=%errorlevel%"
if not "%_gglm_rc%"=="0" goto :Main
if defined app.git_get_latest.help goto :_Main_help
echo.
echo ============================================================
echo  Get latest from configured upstream
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gglm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gglm_rc=1" & goto :Main)
set "app.git_get_latest.branch="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_get_latest.branch=%%A"
if not defined app.git_get_latest.branch (echo ERROR: A named branch is not checked out. & set "_gglm_rc=1" & goto :Main)
set "app.git_get_latest.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_get_latest.dirty=1"
if defined app.git_get_latest.dirty goto :_Main_dirty
git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>nul
if errorlevel 1 goto :_Main_no_tracking
for /f "delims=" %%A in ('git rev-parse --abbrev-ref --symbolic-full-name @{u} 2^>nul') do set "app.git_get_latest.upstream=%%A"
for /f "delims=" %%A in ('git config --get "branch.%app.git_get_latest.branch%.remote" 2^>nul') do set "app.git_get_latest.remote=%%A"
if not defined app.git_get_latest.upstream goto :_Main_no_tracking
echo Current branch:
echo   %app.git_get_latest.branch%
echo.
echo Tracking branch:
echo   %app.git_get_latest.upstream%
echo.
if "%app.git_get_latest.remote%"=="." goto :_Main_count
if not defined app.git_get_latest.remote goto :_Main_fetch_default
git fetch --prune "%app.git_get_latest.remote%"
if errorlevel 1 (echo ERROR: Fetch failed for remote %app.git_get_latest.remote%. & set "_gglm_rc=1" & goto :Main)
goto :_Main_count
:_Main_fetch_default
git fetch --prune
if errorlevel 1 (echo ERROR: Fetch failed. & set "_gglm_rc=1" & goto :Main)
:_Main_count
set "app.git_get_latest.ahead="
set "app.git_get_latest.behind="
for /f "tokens=1,2" %%A in ('git rev-list --left-right --count HEAD...@{u} 2^>nul') do (
set "app.git_get_latest.ahead=%%A"
set "app.git_get_latest.behind=%%B"
)
if not defined app.git_get_latest.ahead (echo ERROR: Could not calculate upstream synchronization. & set "_gglm_rc=1" & goto :Main)
if not defined app.git_get_latest.behind (echo ERROR: Could not calculate upstream synchronization. & set "_gglm_rc=1" & goto :Main)
echo Synchronization:
echo   ahead:  %app.git_get_latest.ahead%
echo   behind: %app.git_get_latest.behind%
echo.
if "%app.git_get_latest.ahead%"=="0" goto :_Main_not_ahead
if "%app.git_get_latest.behind%"=="0" goto :_Main_ahead_only
echo ERROR: Local and upstream histories have diverged.
echo No automatic merge or rebase was attempted.
set "_gglm_rc=1" & goto :Main
:_Main_not_ahead
if "%app.git_get_latest.behind%"=="0" goto :_Main_current
git merge --ff-only @{u}
if errorlevel 1 (echo ERROR: Fast-forward update failed. & set "_gglm_rc=1" & goto :Main)
echo.
echo Updated successfully.
git status --short --branch
set "_gglm_rc=0" & goto :Main
:_Main_ahead_only
echo Local commits still need to be pushed.
echo Run:
echo   just_push.bat
set "_gglm_rc=0" & goto :Main
:_Main_current
echo Already up to date.
set "_gglm_rc=0" & goto :Main
:_Main_dirty
echo ERROR: The working tree has local changes.
echo Commit or stash them before getting latest.
echo.
git status --short
set "_gglm_rc=1" & goto :Main
:_Main_no_tracking
echo ERROR: No upstream branch is configured for:
echo   %app.git_get_latest.branch%
echo.
echo Publish or configure the branch before getting latest.
set "_gglm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gglm_rc=%errorlevel%" & goto :Main
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
set "app.git_get_latest.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays command usage and synchronization behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_get_latest.bat
echo.
echo Usage:
echo   git_get_latest.bat
echo.
echo The helper requires a clean named branch with an upstream.
echo It fetches the tracking remote and applies only:
echo   git merge --ff-only @{u}
echo.
echo Diverged histories are reported but never merged automatically.
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
