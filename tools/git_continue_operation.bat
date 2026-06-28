@echo off
:: ============================================================
:: git_continue_operation.bat
:: Detects and continues an in-progress merge, rebase, cherry-pick,
:: or revert after conflicts have been resolved and staged.
::
:: Usage:
::   call tools\git_continue_operation.bat
::   call tools\git_continue_operation.bat operation cherry-pick
::
:: Returns: 0 on success, cancellation, or no active operation
::          1 on repository, conflict, or Git failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :DetectOperation, :NormalizeOperation,
::           :ContinueOperation, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_continue.operation="
set "app.git_continue.detected="
set "app.git_continue.gitdir="
set "app.git_continue.conflicts="
set "app.git_continue.confirm="
set "app.git_continue.help="
set "app.git_continue.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_continue.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_continue.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_continue.rc%
:: ============================================================
:: :Main
:: Parses arguments, detects the active operation, verifies that no
:: unresolved conflicts remain, confirms, and continues it.
::
:: Usage: call :Main [operation merge|rebase|cherry-pick|revert]
::
:: Returns: 0 on success, cancellation, or no active operation
::          1 on repository, conflict, or Git failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :DetectOperation, :NormalizeOperation,
::           :ContinueOperation, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcom_ 2^>nul') do set "%%v="
if defined _gcom_rc (set "_gcom_rc=" & exit /b %_gcom_rc%)
call :ParseArgs %*
set "_gcom_rc=%errorlevel%"
if not "%_gcom_rc%"=="0" goto :Main
if defined app.git_continue.help goto :_Main_help
echo.
echo ============================================================
echo  Continue in-progress Git operation
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gcom_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gcom_rc=1" & goto :Main)
for /f "delims=" %%A in ('git rev-parse --absolute-git-dir 2^>nul') do set "app.git_continue.gitdir=%%A"
if not defined app.git_continue.gitdir (echo ERROR: Git directory could not be determined. & set "_gcom_rc=1" & goto :Main)
call :DetectOperation
if errorlevel 1 (set "_gcom_rc=%errorlevel%" & goto :Main)
if not defined app.git_continue.operation set "app.git_continue.operation=%app.git_continue.detected%"
if not defined app.git_continue.operation (echo No supported in-progress operation was detected. & set "_gcom_rc=0" & goto :Main)
call :NormalizeOperation
if errorlevel 1 (set "_gcom_rc=2" & goto :Main)
if /I "%app.git_continue.operation%"=="%app.git_continue.detected%" goto :_Main_conflicts
if not defined app.git_continue.detected (echo ERROR: The requested operation is not active: & echo   %app.git_continue.operation% & set "_gcom_rc=1" & goto :Main)
echo ERROR: Requested operation does not match the detected operation.
echo   requested: %app.git_continue.operation%
echo   detected:  %app.git_continue.detected%
set "_gcom_rc=1" & goto :Main
:_Main_conflicts
set "app.git_continue.conflicts="
for /f "delims=" %%A in ('git diff --name-only --diff-filter^=U 2^>nul') do set "app.git_continue.conflicts=1"
if defined app.git_continue.conflicts goto :_Main_unresolved
echo.
echo Detected operation:
echo   %app.git_continue.operation%
echo.
echo Current status:
echo.
git status --short --branch
echo.
echo No unresolved conflict markers are registered by Git.
echo Review the staged changes before continuing:
echo.
git diff --cached --stat
echo.
set /p "app.git_continue.confirm=Type CONTINUE to continue: "
if "%app.git_continue.confirm%"=="CONTINUE" goto :_Main_continue
echo.
echo Cancelled. The operation remains active.
set "_gcom_rc=0" & goto :Main
:_Main_continue
call :ContinueOperation
set "_gcom_rc=%errorlevel%" & goto :Main
:_Main_unresolved
echo.
echo ERROR: Unresolved conflicts remain:
echo.
git diff --name-only --diff-filter=U
echo.
echo Resolve each file, then stage it with git add before continuing.
echo To abandon the operation, run:
echo   tools\git_abort_operation.bat
set "_gcom_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gcom_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :DetectOperation
:: Detects a supported operation from files in the worktree-specific
:: Git directory.
::
:: Usage: call :DetectOperation
::
:: Output:
::   app.git_continue.detected  detected operation name
::
:: Returns: 0
:: Requires: app.git_continue.gitdir
:: ============================================================
:DetectOperation
for /f "tokens=1 delims==" %%v in ('set gcod_ 2^>nul') do set "%%v="
if defined _gcod_rc (set "_gcod_rc=" & exit /b %_gcod_rc%)
set "app.git_continue.detected="
if exist "%app.git_continue.gitdir%\MERGE_HEAD" set "app.git_continue.detected=merge"
if exist "%app.git_continue.gitdir%\rebase-merge\" set "app.git_continue.detected=rebase"
if exist "%app.git_continue.gitdir%\rebase-apply\" set "app.git_continue.detected=rebase"
if exist "%app.git_continue.gitdir%\CHERRY_PICK_HEAD" set "app.git_continue.detected=cherry-pick"
if exist "%app.git_continue.gitdir%\REVERT_HEAD" set "app.git_continue.detected=revert"
set "_gcod_rc=0" & goto :DetectOperation
:: ============================================================
:: :NormalizeOperation
:: Normalizes and validates the requested operation name.
::
:: Usage: call :NormalizeOperation
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:NormalizeOperation
for /f "tokens=1 delims==" %%v in ('set gcon_ 2^>nul') do set "%%v="
if defined _gcon_rc (set "_gcon_rc=" & exit /b %_gcon_rc%)
if /I "%app.git_continue.operation%"=="merge" set "app.git_continue.operation=merge"
if /I "%app.git_continue.operation%"=="rebase" set "app.git_continue.operation=rebase"
if /I "%app.git_continue.operation%"=="cherry-pick" set "app.git_continue.operation=cherry-pick"
if /I "%app.git_continue.operation%"=="cherrypick" set "app.git_continue.operation=cherry-pick"
if /I "%app.git_continue.operation%"=="revert" set "app.git_continue.operation=revert"
if "%app.git_continue.operation%"=="merge" (set "_gcon_rc=0" & goto :NormalizeOperation)
if "%app.git_continue.operation%"=="rebase" (set "_gcon_rc=0" & goto :NormalizeOperation)
if "%app.git_continue.operation%"=="cherry-pick" (set "_gcon_rc=0" & goto :NormalizeOperation)
if "%app.git_continue.operation%"=="revert" (set "_gcon_rc=0" & goto :NormalizeOperation)
echo ERROR: operation must be merge, rebase, cherry-pick, or revert.
set "_gcon_rc=1" & goto :NormalizeOperation
:: ============================================================
:: :ContinueOperation
:: Runs the Git continue command for the normalized active operation.
::
:: Usage: call :ContinueOperation
::
:: Returns: 0 on success
::          1 on Git failure
:: Requires: git
:: ============================================================
:ContinueOperation
for /f "tokens=1 delims==" %%v in ('set gcoc_ 2^>nul') do set "%%v="
if defined _gcoc_rc (set "_gcoc_rc=" & exit /b %_gcoc_rc%)
if "%app.git_continue.operation%"=="merge" goto :_ContinueOperation_merge
if "%app.git_continue.operation%"=="rebase" goto :_ContinueOperation_rebase
if "%app.git_continue.operation%"=="cherry-pick" goto :_ContinueOperation_cherrypick
if "%app.git_continue.operation%"=="revert" goto :_ContinueOperation_revert
echo ERROR: Unsupported operation.
set "_gcoc_rc=1" & goto :ContinueOperation
:_ContinueOperation_merge
git -c core.editor=true merge --continue
goto :_ContinueOperation_result
:_ContinueOperation_rebase
git -c core.editor=true rebase --continue
goto :_ContinueOperation_result
:_ContinueOperation_cherrypick
git -c core.editor=true cherry-pick --continue
goto :_ContinueOperation_result
:_ContinueOperation_revert
git -c core.editor=true revert --continue
:_ContinueOperation_result
if errorlevel 1 goto :_ContinueOperation_failed
echo.
echo Git operation continued successfully.
echo.
git status --short --branch
set "_gcoc_rc=0" & goto :ContinueOperation
:_ContinueOperation_failed
echo.
echo ERROR: Git could not continue the operation.
echo Review git status and any messages above.
echo.
echo To abandon the operation, run:
echo   tools\git_abort_operation.bat
set "_gcoc_rc=1" & goto :ContinueOperation
:: ============================================================
:: :ParseArgs
:: Parses operation and help arguments.
::
:: Usage: call :ParseArgs [operation NAME]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="operation" goto :_ParseArgs_operation
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_continue.operation (set "app.git_continue.operation=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_operation
if "%~2"=="" (echo ERROR: operation requires a name. & exit /b 2)
set "app.git_continue.operation=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_continue.help=1"
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
echo git_continue_operation.bat
echo.
echo Usage:
echo   git_continue_operation.bat
echo   git_continue_operation.bat operation cherry-pick
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
