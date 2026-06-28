@echo off
:: ============================================================
:: git_find_conflicts.bat
:: Reports unresolved Git conflicts and detects an active merge,
:: rebase, cherry-pick, or revert operation.
::
:: Usage:
::   call tools\git_find_conflicts.bat
::   call tools\git_find_conflicts.bat details no
::
:: Returns: 0 when no unresolved conflicts exist
::          1 when conflicts exist or a required check fails
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :DetectOperation, :ReportConflicts,
::           :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_find_conflicts.details=yes"
set "app.git_find_conflicts.gitdir="
set "app.git_find_conflicts.operation="
set "app.git_find_conflicts.conflicts="
set "app.git_find_conflicts.help="
set "app.git_find_conflicts.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_find_conflicts.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_find_conflicts.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_find_conflicts.rc%
:: ============================================================
:: :Main
:: Parses options, validates the working tree, detects the active
:: operation and unresolved index entries, and reports the result.
::
:: Usage: call :Main [details yes|no]
::
:: Returns: 0 when no unresolved conflicts exist
::          1 when conflicts exist or a required check fails
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :DetectOperation,
::           :ReportConflicts, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gfcm_ 2^>nul') do set "%%v="
if defined _gfcm_rc (set "_gfcm_rc=" & exit /b %_gfcm_rc%)
call :ParseArgs %*
set "_gfcm_rc=%errorlevel%"
if not "%_gfcm_rc%"=="0" goto :Main
if defined app.git_find_conflicts.help goto :_Main_help
call :NormalizeYesNo app.git_find_conflicts.details
if errorlevel 1 (echo ERROR: details must be yes or no. & set "_gfcm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Find Git conflicts
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gfcm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gfcm_rc=1" & goto :Main)
for /f "delims=" %%A in ('git rev-parse --absolute-git-dir 2^>nul') do set "app.git_find_conflicts.gitdir=%%A"
if not defined app.git_find_conflicts.gitdir (echo ERROR: Git directory could not be determined. & set "_gfcm_rc=1" & goto :Main)
call :DetectOperation
set "app.git_find_conflicts.conflicts="
for /f "delims=" %%A in ('git ls-files -u 2^>nul') do set "app.git_find_conflicts.conflicts=1"
call :ReportConflicts
set "_gfcm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gfcm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :DetectOperation
:: Detects a supported operation from the worktree-specific Git
:: directory.
::
:: Usage: call :DetectOperation
::
:: Output:
::   app.git_find_conflicts.operation  detected operation name
::
:: Returns: 0
:: Requires: app.git_find_conflicts.gitdir
:: ============================================================
:DetectOperation
for /f "tokens=1 delims==" %%v in ('set gfcd_ 2^>nul') do set "%%v="
if defined _gfcd_rc (set "_gfcd_rc=" & exit /b %_gfcd_rc%)
set "app.git_find_conflicts.operation="
if exist "%app.git_find_conflicts.gitdir%\MERGE_HEAD" set "app.git_find_conflicts.operation=merge"
if exist "%app.git_find_conflicts.gitdir%\rebase-merge\" set "app.git_find_conflicts.operation=rebase"
if exist "%app.git_find_conflicts.gitdir%\rebase-apply\" set "app.git_find_conflicts.operation=rebase"
if exist "%app.git_find_conflicts.gitdir%\CHERRY_PICK_HEAD" set "app.git_find_conflicts.operation=cherry-pick"
if exist "%app.git_find_conflicts.gitdir%\REVERT_HEAD" set "app.git_find_conflicts.operation=revert"
set "_gfcd_rc=0" & goto :DetectOperation
:: ============================================================
:: :ReportConflicts
:: Displays the active operation, unresolved paths, optional index
:: details and marker checks, and recovery guidance.
::
:: Usage: call :ReportConflicts
::
:: Returns: 0 when no unresolved conflicts exist
::          1 when unresolved conflicts exist
:: Requires: git
:: ============================================================
:ReportConflicts
for /f "tokens=1 delims==" %%v in ('set gfcr_ 2^>nul') do set "%%v="
if defined _gfcr_rc (set "_gfcr_rc=" & exit /b %_gfcr_rc%)
echo Active operation:
if defined app.git_find_conflicts.operation (echo   %app.git_find_conflicts.operation%) else (echo   none detected)
echo.
if not defined app.git_find_conflicts.conflicts goto :_ReportConflicts_none
echo ============================================================
echo  Unresolved files
echo ============================================================
echo.
git diff --name-only --diff-filter=U
echo.
echo Conflict status:
echo.
git status --short
echo.
if /I "%app.git_find_conflicts.details%"=="yes" goto :_ReportConflicts_details
goto :_ReportConflicts_guidance
:_ReportConflicts_details
echo ============================================================
echo  Unmerged index entries
echo ============================================================
echo.
git ls-files -u
echo.
echo ============================================================
echo  Conflict-marker and whitespace check
echo ============================================================
echo.
git diff --check
echo.
:_ReportConflicts_guidance
echo Resolve every file, remove conflict markers, and stage the result:
echo.
echo   git add FILE
echo.
if not defined app.git_find_conflicts.operation goto :_ReportConflicts_failed
echo Then continue with:
echo   tools\git_continue_operation.bat
echo.
echo Or abandon the operation with:
echo   tools\git_abort_operation.bat
echo.
:_ReportConflicts_failed
set "_gfcr_rc=1" & goto :ReportConflicts
:_ReportConflicts_none
echo No unresolved conflicts were found.
echo.
git status --short --branch
echo.
if not defined app.git_find_conflicts.operation goto :_ReportConflicts_clean
echo An operation is still active and appears ready for review.
echo Continue it with:
echo   tools\git_continue_operation.bat
echo.
:_ReportConflicts_clean
set "_gfcr_rc=0" & goto :ReportConflicts
:: ============================================================
:: :ParseArgs
:: Parses details and help arguments.
::
:: Usage: call :ParseArgs [details yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="details" goto :_ParseArgs_details
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_details
if "%~2"=="" (echo ERROR: details requires yes or no. & exit /b 2)
set "app.git_find_conflicts.details=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_find_conflicts.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gfcy_ 2^>nul') do set "%%v="
if defined _gfcy_rc (set "_gfcy_rc=" & exit /b %_gfcy_rc%)
set "gfcy_name=%~1"
call set "gfcy_value=%%%gfcy_name%%%"
if /I "%gfcy_value%"=="y" set "%gfcy_name%=yes"
if /I "%gfcy_value%"=="yes" set "%gfcy_name%=yes"
if /I "%gfcy_value%"=="true" set "%gfcy_name%=yes"
if /I "%gfcy_value%"=="1" set "%gfcy_name%=yes"
if /I "%gfcy_value%"=="n" set "%gfcy_name%=no"
if /I "%gfcy_value%"=="no" set "%gfcy_name%=no"
if /I "%gfcy_value%"=="false" set "%gfcy_name%=no"
if /I "%gfcy_value%"=="0" set "%gfcy_name%=no"
call set "gfcy_value=%%%gfcy_name%%%"
if /I "%gfcy_value%"=="yes" (set "_gfcy_rc=0" & goto :NormalizeYesNo)
if /I "%gfcy_value%"=="no" (set "_gfcy_rc=0" & goto :NormalizeYesNo)
set "_gfcy_rc=1" & goto :NormalizeYesNo
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
echo git_find_conflicts.bat
echo.
echo Usage:
echo   git_find_conflicts.bat
echo   git_find_conflicts.bat details no
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
