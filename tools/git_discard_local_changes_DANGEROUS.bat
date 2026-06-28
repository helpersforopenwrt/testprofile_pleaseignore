@echo off
:: ============================================================
:: git_discard_local_changes_DANGEROUS.bat
:: Permanently restores tracked files to HEAD and deletes untracked,
:: non-ignored files and folders. Ignored files are preserved.
::
:: Usage:
::   call tools\git_discard_local_changes_DANGEROUS.bat
::   call tools\git_discard_local_changes_DANGEROUS.bat help
::
:: Returns: 0 on success, cancellation, or no local changes
::          1 on Git, repository, reset, or clean failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :ShowPlan, :DiscardChanges, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_discard.dirty="
set "app.git_discard.confirm="
set "app.git_discard.help="
set "app.git_discard.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_discard.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_discard.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_discard.rc%
:: ============================================================
:: :Main
:: Parses arguments, prepares and validates Git, previews all affected
:: paths, requires typed confirmation, and discards local changes.
::
:: Usage: call :Main [help]
::
:: Returns: 0 on success, cancellation, or no local changes
::          1 on Git, repository, reset, or clean failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :ShowPlan, :DiscardChanges, :ShowHelp,
::           prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gddm_ 2^>nul') do set "%%v="
if defined _gddm_rc (set "_gddm_rc=" & exit /b %_gddm_rc%)
call :ParseArgs %*
set "_gddm_rc=%errorlevel%"
if not "%_gddm_rc%"=="0" goto :Main
if defined app.git_discard.help goto :_Main_help
echo.
echo ============================================================
echo  DANGEROUS: Discard local uncommitted changes
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gddm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gddm_rc=1" & goto :Main)
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: No commit exists to restore. & set "_gddm_rc=1" & goto :Main)
set "app.git_discard.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_discard.dirty=1"
if defined app.git_discard.dirty goto :_Main_plan
echo No tracked or untracked local changes were found.
set "_gddm_rc=0" & goto :Main
:_Main_plan
call :ShowPlan
if errorlevel 1 (set "_gddm_rc=%errorlevel%" & goto :Main)
set /p "app.git_discard.confirm=Type DISCARD to continue: "
if "%app.git_discard.confirm%"=="DISCARD" goto :_Main_discard
echo.
echo Cancelled. Nothing was changed.
set "_gddm_rc=0" & goto :Main
:_Main_discard
call :DiscardChanges
set "_gddm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gddm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ShowPlan
:: Displays tracked changes and the exact untracked paths that
:: git clean would delete.
::
:: Usage: call :ShowPlan
::
:: Returns: 0 on successful preview
::          1 when status or clean preview fails
:: Requires: git
:: ============================================================
:ShowPlan
for /f "tokens=1 delims==" %%v in ('set gdds_ 2^>nul') do set "%%v="
if defined _gdds_rc (set "_gdds_rc=" & exit /b %_gdds_rc%)
echo This permanently performs:
echo   git reset --hard HEAD
echo   git clean -fd
echo.
echo Tracked changes will be restored to HEAD.
echo Untracked, non-ignored files and folders will be deleted.
echo Ignored files and nested Git repositories will be preserved.
echo.
echo Current status:
git status --short
if errorlevel 1 (echo ERROR: git status failed. & set "_gdds_rc=1" & goto :ShowPlan)
echo.
echo Files and folders that git clean would remove:
git clean -nd
if errorlevel 1 (echo ERROR: git clean preview failed. & set "_gdds_rc=1" & goto :ShowPlan)
echo.
set "_gdds_rc=0" & goto :ShowPlan
:: ============================================================
:: :DiscardChanges
:: Restores tracked files to HEAD, deletes untracked non-ignored
:: paths, and reports partial completion if cleaning fails.
::
:: Usage: call :DiscardChanges
::
:: Returns: 0 on success
::          1 on reset or clean failure
:: Requires: git
:: ============================================================
:DiscardChanges
for /f "tokens=1 delims==" %%v in ('set gddd_ 2^>nul') do set "%%v="
if defined _gddd_rc (set "_gddd_rc=" & exit /b %_gddd_rc%)
git reset --hard HEAD
if errorlevel 1 (echo ERROR: git reset --hard HEAD failed. & set "_gddd_rc=1" & goto :DiscardChanges)
git clean -fd
if errorlevel 1 goto :_DiscardChanges_clean_failed
set "gddd_remaining="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "gddd_remaining=1"
if defined gddd_remaining goto :_DiscardChanges_remaining
echo.
echo Local uncommitted changes were discarded.
git status --short --branch
echo.
set "_gddd_rc=0" & goto :DiscardChanges
:_DiscardChanges_remaining
echo.
echo WARNING: The reset and clean commands completed, but protected
echo untracked content remains, such as a nested Git repository.
echo.
git status --short --branch
echo.
set "_gddd_rc=1" & goto :DiscardChanges
:_DiscardChanges_clean_failed
echo ERROR: git clean -fd failed.
echo Tracked changes were already restored to HEAD.
echo Review remaining untracked files with:
echo   git status --short
set "_gddd_rc=1" & goto :DiscardChanges
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
set "app.git_discard.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays command usage and destructive behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_discard_local_changes_DANGEROUS.bat
echo.
echo Usage:
echo   git_discard_local_changes_DANGEROUS.bat
echo.
echo This permanently restores tracked files to HEAD and deletes
echo untracked, non-ignored files and folders after DISCARD confirmation.
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
