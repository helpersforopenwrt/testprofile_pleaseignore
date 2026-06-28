@echo off
:: ============================================================
:: git_sync_fork.bat
:: Fast-forwards the selected local branch from upstream and
:: optionally fast-forwards the fork branch on origin.
::
:: Usage:
::   call tools\git_sync_fork.bat
::   call tools\git_sync_fork.bat branch main
::   call tools\git_sync_fork.bat branch main push no
::
:: Returns: 0 on successful synchronization, no-op, cancellation, or help
::          1 on preparation, repository, remote, tree, fetch, divergence,
::            merge, or push failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_sync_fork.branch="
set "app.git_sync_fork.push=yes"
set "app.git_sync_fork.current="
set "app.git_sync_fork.origin="
set "app.git_sync_fork.upstream="
set "app.git_sync_fork.dirty="
set "app.git_sync_fork.local.only=0"
set "app.git_sync_fork.upstream.only=0"
set "app.git_sync_fork.origin.only=0"
set "app.git_sync_fork.origin.behind=0"
set "app.git_sync_fork.origin.exists="
set "app.git_sync_fork.confirm="
set "app.git_sync_fork.help="
set "app.git_sync_fork.rc=0"
call "%~dp0_common.bat" init
set "app.git_sync_fork.rc=%errorlevel%"
if "%app.git_sync_fork.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_sync_fork.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_sync_fork.rc%
:: ============================================================
:: :Main
:: Requires a clean selected branch, fetches origin and upstream,
:: proves that local and origin can both fast-forward to upstream,
:: confirms, merges with --ff-only, and optionally pushes.
::
:: Usage: call :Main [branch NAME] [push yes|no]
::
:: Returns: 0 on successful synchronization, no-op, cancellation, or help
::          1 on preparation, repository, remote, tree, fetch, divergence,
::            merge, or push failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gsfm_ 2^>nul') do set "%%v="
if defined _gsfm_rc (set "_gsfm_rc=" & exit /b %_gsfm_rc%)
if defined app.git_sync_fork.branch goto :_Main_default_done
if defined CFG_BRANCH set "app.git_sync_fork.branch=%CFG_BRANCH%"
if not defined app.git_sync_fork.branch set "app.git_sync_fork.branch=main"
:_Main_default_done
call :ParseArgs %*
set "_gsfm_rc=%errorlevel%"
if not "%_gsfm_rc%"=="0" goto :Main
if defined app.git_sync_fork.help goto :_Main_help
call :NormalizeYesNo app.git_sync_fork.push
if errorlevel 1 (echo ERROR: push must be yes or no. & set "_gsfm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Synchronize fork from upstream
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gsfm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gsfm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gsfm_rc=1" & goto :Main)
git check-ref-format --branch "%app.git_sync_fork.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid branch name: & echo   %app.git_sync_fork.branch% & set "_gsfm_rc=2" & goto :Main)
set "app.git_sync_fork.current="
set "app.git_sync_fork.origin="
set "app.git_sync_fork.upstream="
set "app.git_sync_fork.dirty="
set "app.git_sync_fork.local.only=0"
set "app.git_sync_fork.upstream.only=0"
set "app.git_sync_fork.origin.only=0"
set "app.git_sync_fork.origin.behind=0"
set "app.git_sync_fork.origin.exists="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_sync_fork.origin=%%A"
for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "app.git_sync_fork.upstream=%%A"
if not defined app.git_sync_fork.origin (echo ERROR: origin is not configured. & set "_gsfm_rc=1" & goto :Main)
if not defined app.git_sync_fork.upstream (echo ERROR: upstream is not configured. & echo This helper is intended for fork repositories. & set "_gsfm_rc=1" & goto :Main)
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_sync_fork.current=%%A"
if /I "%app.git_sync_fork.current%"=="%app.git_sync_fork.branch%" goto :_Main_status
echo ERROR: The selected branch is not checked out.
echo   selected: %app.git_sync_fork.branch%
echo   current:  %app.git_sync_fork.current%
echo.
echo Switch first with:
echo   just_switch.bat "%app.git_sync_fork.branch%"
set "_gsfm_rc=1" & goto :Main
:_Main_status
git status --porcelain >nul 2>nul
if errorlevel 1 (echo ERROR: Git status failed. & set "_gsfm_rc=1" & goto :Main)
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_sync_fork.dirty=1"
if defined app.git_sync_fork.dirty goto :_Main_dirty
echo Fetching upstream...
git fetch --prune upstream
set "_gsfm_fetch_rc=%errorlevel%"
if not "%_gsfm_fetch_rc%"=="0" (echo ERROR: Could not fetch upstream. & set "_gsfm_rc=1" & goto :Main)
git show-ref --verify --quiet "refs/remotes/upstream/%app.git_sync_fork.branch%"
if errorlevel 1 (echo ERROR: upstream does not contain branch: & echo   %app.git_sync_fork.branch% & set "_gsfm_rc=1" & goto :Main)
echo Fetching origin...
git fetch --prune origin
set "_gsfm_fetch_rc=%errorlevel%"
if not "%_gsfm_fetch_rc%"=="0" (echo ERROR: Could not fetch origin. & set "_gsfm_rc=1" & goto :Main)
git rev-list --left-right --count "HEAD...upstream/%app.git_sync_fork.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not compare the local and upstream branches. & set "_gsfm_rc=1" & goto :Main)
for /f "tokens=1,2" %%A in ('git rev-list --left-right --count "HEAD...upstream/%app.git_sync_fork.branch%" 2^>nul') do (
set "app.git_sync_fork.local.only=%%A"
set "app.git_sync_fork.upstream.only=%%B"
)
if not "%app.git_sync_fork.local.only%"=="0" goto :_Main_local_diverged
git show-ref --verify --quiet "refs/remotes/origin/%app.git_sync_fork.branch%"
if errorlevel 1 goto :_Main_plan
set "app.git_sync_fork.origin.exists=1"
git rev-list --left-right --count "upstream/%app.git_sync_fork.branch%...origin/%app.git_sync_fork.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not compare upstream with origin. & set "_gsfm_rc=1" & goto :Main)
for /f "tokens=1,2" %%A in ('git rev-list --left-right --count "upstream/%app.git_sync_fork.branch%...origin/%app.git_sync_fork.branch%" 2^>nul') do (
set "app.git_sync_fork.origin.behind=%%A"
set "app.git_sync_fork.origin.only=%%B"
)
if not "%app.git_sync_fork.origin.only%"=="0" goto :_Main_origin_diverged
:_Main_plan
echo.
echo Upstream:
echo   %app.git_sync_fork.upstream%
echo.
echo Fork origin:
echo   %app.git_sync_fork.origin%
echo.
echo Branch:
echo   %app.git_sync_fork.branch%
echo.
echo Commits to fast-forward locally:
echo   %app.git_sync_fork.upstream.only%
echo.
echo Commits origin is behind upstream:
if defined app.git_sync_fork.origin.exists goto :_Main_origin_count
echo   origin branch does not exist yet
goto :_Main_origin_count_done
:_Main_origin_count
echo   %app.git_sync_fork.origin.behind%
:_Main_origin_count_done
echo.
echo Push synchronized branch to origin:
echo   %app.git_sync_fork.push%
echo.
if not "%app.git_sync_fork.upstream.only%"=="0" goto :_Main_confirm
if /I "%app.git_sync_fork.push%"=="no" goto :_Main_already
if not defined app.git_sync_fork.origin.exists goto :_Main_confirm
if not "%app.git_sync_fork.origin.behind%"=="0" goto :_Main_confirm
goto :_Main_already
:_Main_confirm
set /p "app.git_sync_fork.confirm=Type SYNC to continue: "
if "%app.git_sync_fork.confirm%"=="SYNC" goto :_Main_merge
echo.
echo Cancelled. Nothing was changed.
set "_gsfm_rc=0" & goto :Main
:_Main_merge
if "%app.git_sync_fork.upstream.only%"=="0" goto :_Main_after_merge
git merge --ff-only "upstream/%app.git_sync_fork.branch%"
set "_gsfm_rc=%errorlevel%"
if "%_gsfm_rc%"=="0" goto :_Main_after_merge
echo ERROR: Fast-forward merge failed.
echo No non-fast-forward merge was attempted.
set "_gsfm_rc=1" & goto :Main
:_Main_after_merge
if /I "%app.git_sync_fork.push%"=="no" goto :_Main_local_done
git push -u origin "%app.git_sync_fork.branch%"
set "_gsfm_rc=%errorlevel%"
if "%_gsfm_rc%"=="0" goto :_Main_pushed
echo ERROR: Local synchronization succeeded, but push failed.
echo No force-push was attempted.
set "_gsfm_rc=1" & goto :Main
:_Main_pushed
echo.
echo Fork branch synchronized and pushed:
echo   %app.git_sync_fork.branch%
set "_gsfm_rc=0" & goto :Main
:_Main_local_done
echo.
echo Local branch synchronized.
echo The fork on origin was not updated.
set "_gsfm_rc=0" & goto :Main
:_Main_already
echo.
echo No requested synchronization work remains.
set "_gsfm_rc=0" & goto :Main
:_Main_dirty
echo ERROR: The working tree has local changes.
echo Commit or stash them before synchronizing.
echo.
git status --short
set "_gsfm_rc=1" & goto :Main
:_Main_local_diverged
echo.
echo ERROR: Local %app.git_sync_fork.branch% contains commits not present upstream.
echo   local-only commits: %app.git_sync_fork.local.only%
echo   upstream-only:      %app.git_sync_fork.upstream.only%
echo.
echo Automatic synchronization was refused to avoid merging or
echo rewriting fork-specific work.
set "_gsfm_rc=1" & goto :Main
:_Main_origin_diverged
echo.
echo ERROR: origin/%app.git_sync_fork.branch% contains commits not present upstream.
echo   upstream-only commits: %app.git_sync_fork.origin.behind%
echo   origin-only commits:   %app.git_sync_fork.origin.only%
echo.
echo Automatic synchronization was refused because updating origin
echo would not be a proven fast-forward.
set "_gsfm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gsfm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses selected branch, push behavior, and help.
::
:: Usage: call :ParseArgs [branch NAME] [push yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="branch" goto :_ParseArgs_branch
if /I "%~1"=="push" goto :_ParseArgs_push
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_branch
if "%~2"=="" (echo ERROR: branch requires a name. & exit /b 2)
set "app.git_sync_fork.branch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_push
if "%~2"=="" (echo ERROR: push requires yes or no. & exit /b 2)
set "app.git_sync_fork.push=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_sync_fork.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gsfy_ 2^>nul') do set "%%v="
if defined _gsfy_rc (set "_gsfy_rc=" & exit /b %_gsfy_rc%)
set "gsfy_name=%~1"
call set "gsfy_value=%%%gsfy_name%%%"
if /I "%gsfy_value%"=="y" set "%gsfy_name%=yes"
if /I "%gsfy_value%"=="yes" set "%gsfy_name%=yes"
if /I "%gsfy_value%"=="true" set "%gsfy_name%=yes"
if /I "%gsfy_value%"=="1" set "%gsfy_name%=yes"
if /I "%gsfy_value%"=="n" set "%gsfy_name%=no"
if /I "%gsfy_value%"=="no" set "%gsfy_name%=no"
if /I "%gsfy_value%"=="false" set "%gsfy_name%=no"
if /I "%gsfy_value%"=="0" set "%gsfy_name%=no"
call set "gsfy_value=%%%gsfy_name%%%"
if /I "%gsfy_value%"=="yes" (set "_gsfy_rc=0" & goto :NormalizeYesNo)
if /I "%gsfy_value%"=="no" (set "_gsfy_rc=0" & goto :NormalizeYesNo)
set "_gsfy_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays fork synchronization and divergence protections.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_sync_fork.bat
echo.
echo Usage:
echo   git_sync_fork.bat
echo   git_sync_fork.bat branch main
echo   git_sync_fork.bat branch main push no
echo.
echo Local and origin branches must both be ancestors of upstream.
echo The helper uses only fast-forward merge and normal push operations.
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
