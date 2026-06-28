@echo off
:: ============================================================
:: git_undo_last_commit.bat
:: Removes the latest local commit while preserving every file change.
:: Remote-tracking refs are refreshed by default before pushed-history checks.
::
:: Usage:
::   call tools\git_undo_last_commit.bat
::   call tools\git_undo_last_commit.bat mode soft
::   call tools\git_undo_last_commit.bat mode mixed allowdirty yes
::   call tools\git_undo_last_commit.bat mode mixed allowpushed yes
::   call tools\git_undo_last_commit.bat fetch no
::
:: Returns: 0 on successful undo, cancellation, or help
::          1 on preparation, repository, history, status, fetch, safety,
::            preview, or reset failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeMode, :NormalizeYesNo, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_undo_last_commit.mode=mixed"
set "app.git_undo_last_commit.allowdirty=no"
set "app.git_undo_last_commit.allowpushed=no"
set "app.git_undo_last_commit.fetch=yes"
set "app.git_undo_last_commit.dirty="
set "app.git_undo_last_commit.remote.ref="
set "app.git_undo_last_commit.pushed="
set "app.git_undo_last_commit.confirm="
set "app.git_undo_last_commit.help="
set "app.git_undo_last_commit.rc=0"
call "%~dp0_common.bat" init
set "app.git_undo_last_commit.rc=%errorlevel%"
if "%app.git_undo_last_commit.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_undo_last_commit.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_undo_last_commit.rc%
:: ============================================================
:: :Main
:: Validates reset mode and repository state, refreshes remote refs,
:: detects whether any remote-tracking branch contains HEAD, confirms,
:: and performs a mixed or soft reset to HEAD~1.
::
:: Usage: call :Main [mode mixed|soft] [allowdirty yes|no]
::        [allowpushed yes|no] [fetch yes|no]
::
:: Returns: 0 on successful undo, cancellation, or help
::          1 on preparation, repository, history, status, fetch, safety,
::            preview, or reset failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeMode, :NormalizeYesNo, :ShowHelp,
::           prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gulm_ 2^>nul') do set "%%v="
if defined _gulm_rc (set "_gulm_rc=" & exit /b %_gulm_rc%)
call :ParseArgs %*
set "_gulm_rc=%errorlevel%"
if not "%_gulm_rc%"=="0" goto :Main
if defined app.git_undo_last_commit.help goto :_Main_help
call :NormalizeMode
if errorlevel 1 (set "_gulm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_undo_last_commit.allowdirty
if errorlevel 1 (echo ERROR: allowdirty must be yes or no. & set "_gulm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_undo_last_commit.allowpushed
if errorlevel 1 (echo ERROR: allowpushed must be yes or no. & set "_gulm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_undo_last_commit.fetch
if errorlevel 1 (echo ERROR: fetch must be yes or no. & set "_gulm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Undo last local commit
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gulm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gulm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gulm_rc=1" & goto :Main)
git rev-parse --verify HEAD~1 >nul 2>nul
if errorlevel 1 goto :_Main_root
git status --porcelain >nul 2>nul
if errorlevel 1 (echo ERROR: Git status failed. & set "_gulm_rc=1" & goto :Main)
set "app.git_undo_last_commit.dirty="
set "app.git_undo_last_commit.remote.ref="
set "app.git_undo_last_commit.pushed="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_undo_last_commit.dirty=1"
if not defined app.git_undo_last_commit.dirty goto :_Main_fetch
if /I "%app.git_undo_last_commit.allowdirty%"=="yes" goto :_Main_dirty_allowed
echo.
echo ERROR: The working tree already has local changes.
echo.
git status --short
echo.
echo Commit or stash those changes first.
echo To deliberately combine them with the undone commit, use:
echo   git_undo_last_commit.bat mode %app.git_undo_last_commit.mode% allowdirty yes
set "_gulm_rc=1" & goto :Main
:_Main_dirty_allowed
echo.
echo WARNING: Existing changes will be combined with the undone commit.
git status --short
echo.
:_Main_fetch
if /I "%app.git_undo_last_commit.fetch%"=="no" goto :_Main_remote_check
echo Refreshing remote-tracking references...
git fetch --all --prune --quiet
set "_gulm_fetch_rc=%errorlevel%"
if "%_gulm_fetch_rc%"=="0" goto :_Main_remote_check
echo ERROR: Remote references could not be refreshed.
echo The pushed-history safety check was not performed with stale data.
echo Use fetch no only when operating deliberately without network access.
set "_gulm_rc=1" & goto :Main
:_Main_remote_check
git branch -r --contains HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: Remote-tracking references could not be inspected. & set "_gulm_rc=1" & goto :Main)
for /f "tokens=*" %%A in ('git branch -r --contains HEAD 2^>nul') do if not defined app.git_undo_last_commit.remote.ref set "app.git_undo_last_commit.remote.ref=%%A"
if not defined app.git_undo_last_commit.remote.ref goto :_Main_plan
set "app.git_undo_last_commit.pushed=1"
if /I "%app.git_undo_last_commit.allowpushed%"=="yes" goto :_Main_pushed_allowed
echo.
echo ERROR: The current last commit is contained by a remote-tracking ref:
echo   %app.git_undo_last_commit.remote.ref%
echo.
echo Undoing it rewrites local history but does not remove the remote commit.
echo A safer shared-history operation is:
echo   tools\git_revert_commit.bat commit HEAD
echo.
echo To proceed locally anyway, use:
echo   git_undo_last_commit.bat mode %app.git_undo_last_commit.mode% allowpushed yes
set "_gulm_rc=1" & goto :Main
:_Main_pushed_allowed
echo.
echo WARNING: The last commit is contained by a remote-tracking ref:
echo   %app.git_undo_last_commit.remote.ref%
echo.
echo This operation changes local history only.
echo The helper will not force-push.
:_Main_plan
echo.
echo Last commit:
git log -1 --oneline
set "_gulm_log_rc=%errorlevel%"
if not "%_gulm_log_rc%"=="0" (echo ERROR: Could not display the last commit. & set "_gulm_rc=1" & goto :Main)
echo.
echo Undo mode:
echo   %app.git_undo_last_commit.mode%
echo.
if /I "%app.git_undo_last_commit.mode%"=="soft" goto :_Main_soft_description
echo Result:
echo   the commit disappears locally
echo   its file changes remain unstaged
goto :_Main_description_done
:_Main_soft_description
echo Result:
echo   the commit disappears locally
echo   its file changes remain staged
:_Main_description_done
echo.
echo No files will be discarded.
echo No remote branch will be changed.
echo.
set /p "app.git_undo_last_commit.confirm=Type UNDO to continue: "
if "%app.git_undo_last_commit.confirm%"=="UNDO" goto :_Main_reset
echo.
echo Cancelled. Nothing was changed.
set "_gulm_rc=0" & goto :Main
:_Main_reset
if /I "%app.git_undo_last_commit.mode%"=="soft" goto :_Main_reset_soft
git reset --mixed HEAD~1
set "_gulm_rc=%errorlevel%"
goto :_Main_reset_result
:_Main_reset_soft
git reset --soft HEAD~1
set "_gulm_rc=%errorlevel%"
:_Main_reset_result
if "%_gulm_rc%"=="0" goto :_Main_success
echo.
echo ERROR: Git could not undo the last commit.
set "_gulm_rc=1" & goto :Main
:_Main_success
echo.
echo ============================================================
echo  Last commit undone locally
echo ============================================================
echo.
git status --short --branch
set "_gulm_status_rc=%errorlevel%"
if not "%_gulm_status_rc%"=="0" echo WARNING: The reset succeeded, but Git status could not be displayed.
echo.
if not defined app.git_undo_last_commit.pushed goto :_Main_success_done
echo WARNING: The remote still contains the old commit.
echo A normal push may be rejected because local history changed.
echo No force-push was attempted.
echo.
:_Main_success_done
set "_gulm_rc=0" & goto :Main
:_Main_root
echo.
echo ERROR: The last commit cannot be undone safely by this helper.
echo The repository may contain only its root commit.
set "_gulm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gulm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses reset mode, dirty and pushed overrides, fetch, and help.
::
:: Usage: call :ParseArgs [mode mixed|soft] [allowdirty yes|no]
::        [allowpushed yes|no] [fetch yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="mode" goto :_ParseArgs_mode
if /I "%~1"=="allowdirty" goto :_ParseArgs_dirty
if /I "%~1"=="allowpushed" goto :_ParseArgs_pushed
if /I "%~1"=="fetch" goto :_ParseArgs_fetch
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_mode
if "%~2"=="" (echo ERROR: mode requires mixed or soft. & exit /b 2)
set "app.git_undo_last_commit.mode=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_dirty
if "%~2"=="" (echo ERROR: allowdirty requires yes or no. & exit /b 2)
set "app.git_undo_last_commit.allowdirty=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_pushed
if "%~2"=="" (echo ERROR: allowpushed requires yes or no. & exit /b 2)
set "app.git_undo_last_commit.allowpushed=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_fetch
if "%~2"=="" (echo ERROR: fetch requires yes or no. & exit /b 2)
set "app.git_undo_last_commit.fetch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_undo_last_commit.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeMode
:: Normalizes and validates mixed or soft reset mode.
::
:: Usage: call :NormalizeMode
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:NormalizeMode
if /I "%app.git_undo_last_commit.mode%"=="mixed" set "app.git_undo_last_commit.mode=mixed"
if /I "%app.git_undo_last_commit.mode%"=="soft" set "app.git_undo_last_commit.mode=soft"
if "%app.git_undo_last_commit.mode%"=="mixed" exit /b 0
if "%app.git_undo_last_commit.mode%"=="soft" exit /b 0
echo ERROR: mode must be mixed or soft.
exit /b 1
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
for /f "tokens=1 delims==" %%v in ('set guly_ 2^>nul') do set "%%v="
if defined _guly_rc (set "_guly_rc=" & exit /b %_guly_rc%)
set "guly_name=%~1"
call set "guly_value=%%%guly_name%%%"
if /I "%guly_value%"=="y" set "%guly_name%=yes"
if /I "%guly_value%"=="yes" set "%guly_name%=yes"
if /I "%guly_value%"=="true" set "%guly_name%=yes"
if /I "%guly_value%"=="1" set "%guly_name%=yes"
if /I "%guly_value%"=="n" set "%guly_name%=no"
if /I "%guly_value%"=="no" set "%guly_name%=no"
if /I "%guly_value%"=="false" set "%guly_name%=no"
if /I "%guly_value%"=="0" set "%guly_name%=no"
call set "guly_value=%%%guly_name%%%"
if /I "%guly_value%"=="yes" (set "_guly_rc=0" & goto :NormalizeYesNo)
if /I "%guly_value%"=="no" (set "_guly_rc=0" & goto :NormalizeYesNo)
set "_guly_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays reset modes and local-history safety controls.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_undo_last_commit.bat
echo.
echo Usage:
echo   git_undo_last_commit.bat
echo   git_undo_last_commit.bat mode soft
echo   git_undo_last_commit.bat mode mixed allowdirty yes
echo   git_undo_last_commit.bat mode mixed allowpushed yes
echo   git_undo_last_commit.bat fetch no
echo.
echo mixed keeps changes unstaged. soft keeps them staged.
echo No hard reset and no force-push are performed.
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
