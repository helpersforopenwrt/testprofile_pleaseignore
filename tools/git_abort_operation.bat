@echo off
:: ============================================================
:: git_abort_operation.bat
:: Detects and aborts an in-progress merge, rebase, cherry-pick,
:: or revert operation.
::
:: Usage:
::   call tools\git_abort_operation.bat
::   call tools\git_abort_operation.bat operation merge
::
:: Returns: 0 on success, cancellation, or no active operation
::          1 on repository or Git failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main,
::           :ParseArgs, :DetectOperation, :NormalizeOperation,
::           :AbortOperation, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_abort_operation.operation="
set "app.git_abort_operation.detected="
set "app.git_abort_operation.gitdir="
set "app.git_abort_operation.confirm="
set "app.git_abort_operation.help="
set "app.git_abort_operation.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_abort_operation.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_abort_operation.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_abort_operation.rc%
:: ============================================================
:: :Main
:: Parses arguments, detects the active operation, confirms the
:: destructive action, and invokes the matching Git abort command.
::
:: Usage: call :Main [operation merge|rebase|cherry-pick|revert]
::
:: Returns: 0 on success, cancellation, or no active operation
::          1 on repository or Git failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :DetectOperation, :NormalizeOperation,
::           :AbortOperation, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gaom_ 2^>nul') do set "%%v="
if defined _gaom_rc (set "_gaom_rc=" & exit /b %_gaom_rc%)
call :ParseArgs %*
if errorlevel 1 (set "_gaom_rc=%errorlevel%" & goto :Main)
if defined app.git_abort_operation.help goto :_Main_help
echo.
echo ============================================================
echo  Abort in-progress Git operation
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gaom_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gaom_rc=1" & goto :Main)
for /f "delims=" %%A in ('git rev-parse --absolute-git-dir 2^>nul') do set "app.git_abort_operation.gitdir=%%A"
if not defined app.git_abort_operation.gitdir (echo ERROR: Git directory could not be determined. & set "_gaom_rc=1" & goto :Main)
call :DetectOperation
if errorlevel 1 (set "_gaom_rc=%errorlevel%" & goto :Main)
if not defined app.git_abort_operation.operation set "app.git_abort_operation.operation=%app.git_abort_operation.detected%"
if not defined app.git_abort_operation.operation (echo No supported in-progress operation was detected. & set "_gaom_rc=0" & goto :Main)
call :NormalizeOperation
if errorlevel 1 (set "_gaom_rc=2" & goto :Main)
if /I "%app.git_abort_operation.operation%"=="%app.git_abort_operation.detected%" goto :_Main_confirm
if not defined app.git_abort_operation.detected (echo ERROR: The requested operation is not active: & echo   %app.git_abort_operation.operation% & set "_gaom_rc=1" & goto :Main)
echo ERROR: Requested operation does not match the detected operation.
echo   requested: %app.git_abort_operation.operation%
echo   detected:  %app.git_abort_operation.detected%
set "_gaom_rc=1" & goto :Main
:_Main_confirm
echo.
echo Detected operation:
echo   %app.git_abort_operation.operation%
echo.
echo Current status:
echo.
git status --short --branch
echo.
echo Unresolved files:
git diff --name-only --diff-filter=U
echo.
echo WARNING: Aborting discards changes made as part of the active
echo operation and returns to Git's recorded pre-operation state.
echo.
set /p "app.git_abort_operation.confirm=Type ABORT to continue: "
if not "%app.git_abort_operation.confirm%"=="ABORT" (echo. & echo Cancelled. The operation remains active. & set "_gaom_rc=0" & goto :Main)
call :AbortOperation
set "_gaom_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gaom_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :DetectOperation
:: Detects a supported operation from files in the Git directory.
::
:: Usage: call :DetectOperation
::
:: Output:
::   app.git_abort_operation.detected  detected operation name
::
:: Returns: 0
:: Requires: app.git_abort_operation.gitdir
:: ============================================================
:DetectOperation
for /f "tokens=1 delims==" %%v in ('set gaod_ 2^>nul') do set "%%v="
if defined _gaod_rc (set "_gaod_rc=" & exit /b %_gaod_rc%)
set "app.git_abort_operation.detected="
if exist "%app.git_abort_operation.gitdir%\MERGE_HEAD" set "app.git_abort_operation.detected=merge"
if exist "%app.git_abort_operation.gitdir%\rebase-merge\" set "app.git_abort_operation.detected=rebase"
if exist "%app.git_abort_operation.gitdir%\rebase-apply\" set "app.git_abort_operation.detected=rebase"
if exist "%app.git_abort_operation.gitdir%\CHERRY_PICK_HEAD" set "app.git_abort_operation.detected=cherry-pick"
if exist "%app.git_abort_operation.gitdir%\REVERT_HEAD" set "app.git_abort_operation.detected=revert"
set "_gaod_rc=0" & goto :DetectOperation
:: ============================================================
:: :NormalizeOperation
:: Normalizes and validates the requested operation name.
::
:: Usage: call :NormalizeOperation
::
:: Input:
::   app.git_abort_operation.operation  requested operation
::
:: Output:
::   app.git_abort_operation.operation  normalized operation
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:NormalizeOperation
for /f "tokens=1 delims==" %%v in ('set gaon_ 2^>nul') do set "%%v="
if defined _gaon_rc (set "_gaon_rc=" & exit /b %_gaon_rc%)
if /I "%app.git_abort_operation.operation%"=="merge" set "app.git_abort_operation.operation=merge"
if /I "%app.git_abort_operation.operation%"=="rebase" set "app.git_abort_operation.operation=rebase"
if /I "%app.git_abort_operation.operation%"=="cherry-pick" set "app.git_abort_operation.operation=cherry-pick"
if /I "%app.git_abort_operation.operation%"=="cherrypick" set "app.git_abort_operation.operation=cherry-pick"
if /I "%app.git_abort_operation.operation%"=="revert" set "app.git_abort_operation.operation=revert"
if "%app.git_abort_operation.operation%"=="merge" (set "_gaon_rc=0" & goto :NormalizeOperation)
if "%app.git_abort_operation.operation%"=="rebase" (set "_gaon_rc=0" & goto :NormalizeOperation)
if "%app.git_abort_operation.operation%"=="cherry-pick" (set "_gaon_rc=0" & goto :NormalizeOperation)
if "%app.git_abort_operation.operation%"=="revert" (set "_gaon_rc=0" & goto :NormalizeOperation)
echo ERROR: operation must be merge, rebase, cherry-pick, or revert.
set "_gaon_rc=1" & goto :NormalizeOperation
:: ============================================================
:: :AbortOperation
:: Runs the Git abort command for the normalized active operation.
::
:: Usage: call :AbortOperation
::
:: Returns: 0 on success
::          1 on Git failure
:: Requires: git, app.git_abort_operation.operation
:: ============================================================
:AbortOperation
for /f "tokens=1 delims==" %%v in ('set gaoa_ 2^>nul') do set "%%v="
if defined _gaoa_rc (set "_gaoa_rc=" & exit /b %_gaoa_rc%)
if "%app.git_abort_operation.operation%"=="merge" goto :_AbortOperation_merge
if "%app.git_abort_operation.operation%"=="rebase" goto :_AbortOperation_rebase
if "%app.git_abort_operation.operation%"=="cherry-pick" goto :_AbortOperation_cherrypick
if "%app.git_abort_operation.operation%"=="revert" goto :_AbortOperation_revert
echo ERROR: Unsupported operation.
set "_gaoa_rc=1" & goto :AbortOperation
:_AbortOperation_merge
git merge --abort
goto :_AbortOperation_result
:_AbortOperation_rebase
git rebase --abort
goto :_AbortOperation_result
:_AbortOperation_cherrypick
git cherry-pick --abort
goto :_AbortOperation_result
:_AbortOperation_revert
git revert --abort
:_AbortOperation_result
if errorlevel 1 (echo. & echo ERROR: Git could not abort the operation. & echo Review git status before making further changes. & set "_gaoa_rc=1" & goto :AbortOperation)
echo.
echo Operation aborted successfully.
echo.
git status --short --branch
set "_gaoa_rc=0" & goto :AbortOperation
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
if not defined app.git_abort_operation.operation (set "app.git_abort_operation.operation=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_operation
if "%~2"=="" (echo ERROR: operation requires a name. & exit /b 2)
set "app.git_abort_operation.operation=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_abort_operation.help=1"
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
echo git_abort_operation.bat
echo.
echo Usage:
echo   git_abort_operation.bat
echo   git_abort_operation.bat operation merge
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
