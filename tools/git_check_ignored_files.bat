@echo off
:: ============================================================
:: git_check_ignored_files.bat
:: Shows ignored and untracked files and checks expected local-only
:: dependency paths against .gitignore.
::
:: Usage:
::   call tools\git_check_ignored_files.bat
::   call tools\git_check_ignored_files.bat help
::
:: Returns: 0 when checks complete, including warning-only results
::          1 on Git or repository failure
::          2 on invalid arguments
:: Requires: _common.bat, git, :Main, :ParseArgs, :CheckLocalPath,
::           :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_check_ignored.warning="
set "app.git_check_ignored.help="
set "app.git_check_ignored.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_check_ignored.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_check_ignored.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_check_ignored.rc%
:: ============================================================
:: :Main
:: Validates Git, prints ignored status information, checks expected
:: local-only paths, and displays a commit recommendation.
::
:: Usage: call :Main [help]
::
:: Returns: 0 when checks complete
::          1 on Git or repository failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :CheckLocalPath, :ShowHelp, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcim_ 2^>nul') do set "%%v="
if defined _gcim_rc (set "_gcim_rc=" & exit /b %_gcim_rc%)
call :ParseArgs %*
set "_gcim_rc=%errorlevel%"
if not "%_gcim_rc%"=="0" goto :Main
if defined app.git_check_ignored.help goto :_Main_help
echo.
echo ============================================================
echo  Check ignored and untracked files
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
where git.exe >nul 2>nul
if errorlevel 1 goto :_Main_no_git
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 goto :_Main_not_worktree
echo ============================================================
echo  Git status, including ignored files
echo ============================================================
echo.
git status --short --ignored
if errorlevel 1 (echo ERROR: git status failed. & set "_gcim_rc=1" & goto :Main)
echo.
echo ============================================================
echo  What the prefixes mean
echo ============================================================
echo.
echo   !!  Ignored by .gitignore.
echo       These files will NOT be added by git add --all.
echo.
echo   ??  Untracked and NOT ignored.
echo       These files WILL be added by git add --all.
echo.
echo   M   A tracked file was modified.
echo   A   A file is staged to be added.
echo   D   A tracked file was deleted.
echo.
echo ============================================================
echo  Local dependency paths
echo ============================================================
echo.
set "app.git_check_ignored.warning="
call :CheckLocalPath "tools\git"
call :CheckLocalPath "tools\gh"
call :CheckLocalPath "tools\downloads"
call :CheckLocalPath "tools\logs"
call :CheckLocalPath "prepare.log"
call :CheckLocalPath "env.bat"
echo.
echo ============================================================
echo  Recommendation
echo ============================================================
echo.
if defined app.git_check_ignored.warning goto :_Main_warning
echo No existing local dependency path was found outside .gitignore.
echo.
echo Review the status listing before committing:
echo   entries beginning with !! are safely ignored
echo   entries beginning with ?? will be included by git add --all
set "_gcim_rc=0" & goto :Main
:_Main_warning
echo WARNING: One or more local-only paths exist but are not ignored.
echo.
echo Do not commit yet.
echo Update .gitignore, then run this script again.
set "_gcim_rc=0" & goto :Main
:_Main_no_git
echo ERROR: Git was not found in PATH.
echo.
echo Run:
echo   prepare.bat git
set "_gcim_rc=1" & goto :Main
:_Main_not_worktree
echo ERROR: This folder is not inside a Git working tree.
set "_gcim_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gcim_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :CheckLocalPath
:: Reports whether an existing local-only path is ignored.
::
:: Usage: call :CheckLocalPath "relative path"
::
:: Output:
::   app.git_check_ignored.warning  defined when a path is unignored
::
:: Returns: 0
:: Requires: git
:: ============================================================
:CheckLocalPath
for /f "tokens=1 delims==" %%v in ('set gcip_ 2^>nul') do set "%%v="
if defined _gcip_rc (set "_gcip_rc=" & exit /b %_gcip_rc%)
set "gcip_path=%~1"
if exist "%gcip_path%" goto :_CheckLocalPath_exists
echo [not present]  %gcip_path%
set "_gcip_rc=0" & goto :CheckLocalPath
:_CheckLocalPath_exists
git check-ignore -q -- "%gcip_path%" >nul 2>nul
if errorlevel 1 goto :_CheckLocalPath_warning
echo [ignored]      %gcip_path%
set "_gcip_rc=0" & goto :CheckLocalPath
:_CheckLocalPath_warning
echo [WARNING]      %gcip_path%
set "app.git_check_ignored.warning=1"
set "_gcip_rc=0" & goto :CheckLocalPath
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
set "app.git_check_ignored.help=1"
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
echo git_check_ignored_files.bat
echo.
echo Usage:
echo   git_check_ignored_files.bat
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
