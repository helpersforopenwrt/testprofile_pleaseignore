@echo off
:: ============================================================
:: git_clean_preview.bat
:: Previews untracked or ignored files that Git clean could remove.
:: This helper never deletes files.
::
:: Usage:
::   call tools\git_clean_preview.bat
::   call tools\git_clean_preview.bat mode untracked
::   call tools\git_clean_preview.bat mode ignored
::   call tools\git_clean_preview.bat mode all
::
:: Returns: 0 on successful preview
::          1 on repository, status, or preview failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :ValidateMode, :RunPreview, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_clean_preview.mode=untracked"
set "app.git_clean_preview.help="
set "app.git_clean_preview.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_clean_preview.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_clean_preview.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_clean_preview.rc%
:: ============================================================
:: :Main
:: Parses and validates the mode, prepares Git, prints status, and
:: runs the selected dry-run Git clean command.
::
:: Usage: call :Main [mode untracked|ignored|all]
::
:: Returns: 0 on successful preview
::          1 on repository, status, or preview failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :ValidateMode, :RunPreview, :ShowHelp, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcpm_ 2^>nul') do set "%%v="
if defined _gcpm_rc (set "_gcpm_rc=" & exit /b %_gcpm_rc%)
call :ParseArgs %*
set "_gcpm_rc=%errorlevel%"
if not "%_gcpm_rc%"=="0" goto :Main
if defined app.git_clean_preview.help goto :_Main_help
call :ValidateMode
if errorlevel 1 (set "_gcpm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Git clean preview
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
echo Mode:
echo   %app.git_clean_preview.mode%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gcpm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gcpm_rc=1" & goto :Main)
echo Current status:
echo.
git status --short --ignored
if errorlevel 1 (echo ERROR: git status failed. & set "_gcpm_rc=1" & goto :Main)
echo.
echo ============================================================
echo  Preview only - nothing will be deleted
echo ============================================================
echo.
call :RunPreview
set "_gcpm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gcpm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ValidateMode
:: Validates the requested preview mode.
::
:: Usage: call :ValidateMode
::
:: Returns: 0 when mode is untracked, ignored, or all
::          1 otherwise
:: Requires: none
:: ============================================================
:ValidateMode
for /f "tokens=1 delims==" %%v in ('set gcpv_ 2^>nul') do set "%%v="
if defined _gcpv_rc (set "_gcpv_rc=" & exit /b %_gcpv_rc%)
if /I "%app.git_clean_preview.mode%"=="untracked" (set "app.git_clean_preview.mode=untracked" & set "_gcpv_rc=0" & goto :ValidateMode)
if /I "%app.git_clean_preview.mode%"=="ignored" (set "app.git_clean_preview.mode=ignored" & set "_gcpv_rc=0" & goto :ValidateMode)
if /I "%app.git_clean_preview.mode%"=="all" (set "app.git_clean_preview.mode=all" & set "_gcpv_rc=0" & goto :ValidateMode)
echo ERROR: mode must be untracked, ignored, or all.
set "_gcpv_rc=1" & goto :ValidateMode
:: ============================================================
:: :RunPreview
:: Runs the selected git clean dry-run command.
::
:: Usage: call :RunPreview
::
:: Returns: 0 on success
::          1 on git clean failure
:: Requires: git
:: ============================================================
:RunPreview
for /f "tokens=1 delims==" %%v in ('set gcpr_ 2^>nul') do set "%%v="
if defined _gcpr_rc (set "_gcpr_rc=" & exit /b %_gcpr_rc%)
if /I "%app.git_clean_preview.mode%"=="ignored" goto :_RunPreview_ignored
if /I "%app.git_clean_preview.mode%"=="all" goto :_RunPreview_all
git clean -nd
goto :_RunPreview_result
:_RunPreview_ignored
git clean -ndX
goto :_RunPreview_result
:_RunPreview_all
git clean -ndx
:_RunPreview_result
if errorlevel 1 (echo ERROR: Git clean preview failed. & set "_gcpr_rc=1" & goto :RunPreview)
echo.
echo No files were removed.
echo This project intentionally provides preview only.
echo.
set "_gcpr_rc=0" & goto :RunPreview
:: ============================================================
:: :ParseArgs
:: Parses mode and help arguments.
::
:: Usage: call :ParseArgs [mode untracked|ignored|all]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="mode" goto :_ParseArgs_mode
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_mode
if "%~2"=="" (echo ERROR: mode requires untracked, ignored, or all. & exit /b 2)
set "app.git_clean_preview.mode=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_clean_preview.help=1"
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
echo git_clean_preview.bat
echo.
echo Usage:
echo   git_clean_preview.bat
echo   git_clean_preview.bat mode ignored
echo   git_clean_preview.bat mode all
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
