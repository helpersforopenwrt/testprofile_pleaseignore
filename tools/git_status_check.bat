@echo off
:: ============================================================
:: git_status_check.bat
:: Reports local repository state, refreshes remote references when
:: requested, and recommends the next safe synchronization action.
::
:: Usage:
::   call tools\git_status_check.bat
::   call tools\git_status_check.bat fetch no
::
:: Returns: 0 when status is complete or the repository has no commits
::          1 on preparation, repository, status, fetch, origin, or tracking failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_status_check.fetch=yes"
set "app.git_status_check.branch="
set "app.git_status_check.origin="
set "app.git_status_check.tracking="
set "app.git_status_check.dirty="
set "app.git_status_check.has.head="
set "app.git_status_check.ahead=0"
set "app.git_status_check.behind=0"
set "app.git_status_check.help="
set "app.git_status_check.rc=0"
call "%~dp0_common.bat" init
set "app.git_status_check.rc=%errorlevel%"
if "%app.git_status_check.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_status_check.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_status_check.rc%
:: ============================================================
:: :Main
:: Validates the working tree, prints local state, optionally fetches
:: all remotes, compares HEAD with its tracking branch, and recommends
:: a safe next action.
::
:: Usage: call :Main [fetch yes|no]
::
:: Returns: 0 when status is complete or the repository has no commits
::          1 on preparation, repository, status, fetch, origin, or tracking failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gstm_ 2^>nul') do set "%%v="
if defined _gstm_rc (set "_gstm_rc=" & exit /b %_gstm_rc%)
call :ParseArgs %*
set "_gstm_rc=%errorlevel%"
if not "%_gstm_rc%"=="0" goto :Main
if defined app.git_status_check.help goto :_Main_help
call :NormalizeYesNo app.git_status_check.fetch
if errorlevel 1 (echo ERROR: fetch must be yes or no. & set "_gstm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Git status check
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gstm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gstm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gstm_rc=1" & goto :Main)
git status --porcelain >nul 2>nul
if errorlevel 1 (echo ERROR: Git status failed. & set "_gstm_rc=1" & goto :Main)
set "app.git_status_check.branch="
set "app.git_status_check.origin="
set "app.git_status_check.tracking="
set "app.git_status_check.dirty="
set "app.git_status_check.has.head="
set "app.git_status_check.ahead=0"
set "app.git_status_check.behind=0"
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_status_check.branch=%%A"
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_status_check.origin=%%A"
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_status_check.dirty=1"
git rev-parse --verify HEAD >nul 2>nul
if not errorlevel 1 set "app.git_status_check.has.head=1"
echo Branch:
if defined app.git_status_check.branch goto :_Main_branch_named
echo   detached HEAD or no current branch
goto :_Main_branch_done
:_Main_branch_named
echo   %app.git_status_check.branch%
:_Main_branch_done
echo.
echo Origin remote:
if defined app.git_status_check.origin goto :_Main_origin_present
echo   not configured
goto :_Main_origin_done
:_Main_origin_present
echo   %app.git_status_check.origin%
:_Main_origin_done
echo.
if not defined CFG_REPO_URL goto :_Main_config_done
echo Repository URL from build_config.bat:
echo   %CFG_REPO_URL%
echo.
:_Main_config_done
echo Local status:
git status --short --branch
set "_gstm_status_rc=%errorlevel%"
if not "%_gstm_status_rc%"=="0" (echo ERROR: Git status display failed. & set "_gstm_rc=1" & goto :Main)
echo.
if not defined app.git_status_check.has.head goto :_Main_no_head
if not defined app.git_status_check.origin goto :_Main_no_origin
if /I "%app.git_status_check.fetch%"=="yes" goto :_Main_fetch
goto :_Main_tracking
:_Main_fetch
echo Refreshing remote-tracking references...
git fetch --all --prune --quiet
set "_gstm_fetch_rc=%errorlevel%"
if "%_gstm_fetch_rc%"=="0" goto :_Main_tracking
echo.
echo WARNING: One or more remotes could not be fetched.
echo Local status above is still valid, but synchronization counts
echo were not calculated from potentially stale remote references.
set "_gstm_rc=1" & goto :Main
:_Main_tracking
git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>nul
if errorlevel 1 goto :_Main_no_tracking
for /f "delims=" %%A in ('git rev-parse --abbrev-ref --symbolic-full-name @{u} 2^>nul') do set "app.git_status_check.tracking=%%A"
git rev-list --left-right --count HEAD...@{u} >nul 2>nul
if errorlevel 1 (echo ERROR: Could not compare HEAD with its tracking branch. & set "_gstm_rc=1" & goto :Main)
for /f "tokens=1,2" %%A in ('git rev-list --left-right --count HEAD...@{u} 2^>nul') do (
set "app.git_status_check.ahead=%%A"
set "app.git_status_check.behind=%%B"
)
echo Tracking branch:
echo   %app.git_status_check.tracking%
echo.
echo ============================================================
echo  Recommendation
echo ============================================================
echo.
if defined app.git_status_check.dirty goto :_Main_recommend_dirty
if not "%app.git_status_check.ahead%"=="0" goto :_Main_recommend_ahead
if not "%app.git_status_check.behind%"=="0" goto :_Main_recommend_behind
echo Everything is clean and synchronized.
goto :_Main_counts
:_Main_recommend_dirty
echo You have local file changes.
echo.
echo Commit or stash them before getting latest:
echo   just_commit.bat
echo   just_stash.bat
goto :_Main_counts
:_Main_recommend_ahead
if not "%app.git_status_check.behind%"=="0" goto :_Main_recommend_diverged
echo Local commits need to be pushed.
echo.
echo Recommended:
echo   just_push.bat
goto :_Main_counts
:_Main_recommend_behind
echo The tracking branch has newer commits.
echo.
echo Recommended:
echo   just_getlatest.bat
goto :_Main_counts
:_Main_recommend_diverged
echo Local and tracked remote history have both changed.
echo Do not auto-merge until both histories are inspected.
echo.
echo Recommended first:
echo   tools\git_backup_bundle.bat
echo   tools\git_compare_branches.bat left HEAD right @{u} fetch no
:_Main_counts
echo.
echo Ahead of tracking branch:
echo   %app.git_status_check.ahead%
echo.
echo Behind tracking branch:
echo   %app.git_status_check.behind%
echo.
set "_gstm_rc=0" & goto :Main
:_Main_no_head
echo ============================================================
echo  Recommendation
echo ============================================================
echo.
echo No commits exist yet.
if not defined app.git_status_check.dirty goto :_Main_no_head_done
echo.
echo Recommended:
echo   just_commit.bat
:_Main_no_head_done
echo.
set "_gstm_rc=0" & goto :Main
:_Main_no_origin
echo ============================================================
echo  Recommendation
echo ============================================================
echo.
echo No origin remote is configured.
echo.
echo Recommended:
echo   tools\git_login.bat
echo.
set "_gstm_rc=1" & goto :Main
:_Main_no_tracking
echo.
echo No upstream tracking branch is configured.
echo.
echo Usually fix with:
if defined app.git_status_check.branch goto :_Main_tracking_named
echo   check out a named branch, then run git push -u origin BRANCH
goto :_Main_tracking_done
:_Main_tracking_named
echo   git push -u origin %app.git_status_check.branch%
:_Main_tracking_done
echo.
set "_gstm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gstm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses remote-refresh and help arguments.
::
:: Usage: call :ParseArgs [fetch yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="fetch" goto :_ParseArgs_fetch
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_fetch
if "%~2"=="" (echo ERROR: fetch requires yes or no. & exit /b 2)
set "app.git_status_check.fetch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_status_check.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gsty_ 2^>nul') do set "%%v="
if defined _gsty_rc (set "_gsty_rc=" & exit /b %_gsty_rc%)
set "gsty_name=%~1"
call set "gsty_value=%%%gsty_name%%%"
if /I "%gsty_value%"=="y" set "%gsty_name%=yes"
if /I "%gsty_value%"=="yes" set "%gsty_name%=yes"
if /I "%gsty_value%"=="true" set "%gsty_name%=yes"
if /I "%gsty_value%"=="1" set "%gsty_name%=yes"
if /I "%gsty_value%"=="n" set "%gsty_name%=no"
if /I "%gsty_value%"=="no" set "%gsty_name%=no"
if /I "%gsty_value%"=="false" set "%gsty_name%=no"
if /I "%gsty_value%"=="0" set "%gsty_name%=no"
call set "gsty_value=%%%gsty_name%%%"
if /I "%gsty_value%"=="yes" (set "_gsty_rc=0" & goto :NormalizeYesNo)
if /I "%gsty_value%"=="no" (set "_gsty_rc=0" & goto :NormalizeYesNo)
set "_gsty_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays status-refresh behavior and exit-code meaning.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_status_check.bat
echo.
echo Usage:
echo   git_status_check.bat
echo   git_status_check.bat fetch no
echo.
echo fetch yes refreshes all remote-tracking references before
echo calculating ahead and behind counts. Default: yes.
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
