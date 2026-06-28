@echo off
:: ============================================================
:: github_verify_clone.bat
:: Verifies that the configured GitHub repository can be cloned
:: into a temporary directory, then removes the temporary clone.
::
:: Usage:
::   call tools\github_verify_clone.bat
::   call tools\github_verify_clone.bat repo URL
::
:: Returns: 0 when cloning and cleanup succeed, or help is shown
::          1 on preparation, configuration, clone, validation, or cleanup failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.github_verify_clone.repo="
set "app.github_verify_clone.temp="
set "app.github_verify_clone.help="
set "app.github_verify_clone.rc=0"
call "%~dp0_common.bat" init
set "app.github_verify_clone.rc=%errorlevel%"
if "%app.github_verify_clone.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.github_verify_clone.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.github_verify_clone.rc%
:: ============================================================
:: :Main
:: Resolves the repository URL, prepares Git, performs a temporary
:: no-checkout clone, validates the clone, and removes it.
::
:: Usage: call :Main [repo URL]
::
:: Returns: 0 when cloning and cleanup succeed, or help is shown
::          1 on preparation, configuration, clone, validation, or cleanup failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gvcm_ 2^>nul') do set "%%v="
if defined _gvcm_rc (set "_gvcm_rc=" & exit /b %_gvcm_rc%)
call :ParseArgs %*
set "_gvcm_rc=%errorlevel%"
if not "%_gvcm_rc%"=="0" goto :Main
if defined app.github_verify_clone.help goto :_Main_help
if not defined app.github_verify_clone.repo set "app.github_verify_clone.repo=%CFG_REPO_URL%"
if not defined app.github_verify_clone.repo goto :_Main_no_repo
echo.
echo ============================================================
echo  Verify GitHub clone access
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Repository:
echo   %app.github_verify_clone.repo%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gvcm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gvcm_rc=1" & goto :Main)
set "app.github_verify_clone.temp=%TEMP%\github_verify_clone_%RANDOM%_%RANDOM%"
if exist "%app.github_verify_clone.temp%\" goto :_Main_temp_exists
echo Cloning into a temporary verification folder...
git clone --no-checkout --depth 1 "%app.github_verify_clone.repo%" "%app.github_verify_clone.temp%"
set "_gvcm_clone_rc=%errorlevel%"
if "%_gvcm_clone_rc%"=="0" goto :_Main_validate
echo.
echo ERROR: The repository could not be cloned.
if exist "%app.github_verify_clone.temp%\" rmdir /s /q "%app.github_verify_clone.temp%"
set "_gvcm_rc=1" & goto :Main
:_Main_validate
git -C "%app.github_verify_clone.temp%" rev-parse --is-inside-work-tree >nul 2>nul
set "_gvcm_validate_rc=%errorlevel%"
if "%_gvcm_validate_rc%"=="0" goto :_Main_cleanup
echo.
echo ERROR: Clone completed, but the temporary folder is not a valid worktree.
rmdir /s /q "%app.github_verify_clone.temp%"
set "_gvcm_rc=1" & goto :Main
:_Main_cleanup
rmdir /s /q "%app.github_verify_clone.temp%"
if not exist "%app.github_verify_clone.temp%\" goto :_Main_success
echo.
echo ERROR: Clone verification succeeded, but temporary cleanup failed:
echo   %app.github_verify_clone.temp%
set "_gvcm_rc=1" & goto :Main
:_Main_success
echo.
echo Clone verification succeeded.
echo The temporary clone was removed.
set "_gvcm_rc=0" & goto :Main
:_Main_no_repo
echo ERROR: No repository URL is configured.
echo Configure app.repo_url in build_config.bat or pass:
echo   github_verify_clone.bat repo URL
set "_gvcm_rc=1" & goto :Main
:_Main_temp_exists
echo ERROR: Temporary verification folder already exists:
echo   %app.github_verify_clone.temp%
set "_gvcm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gvcm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses an optional repository URL and help.
::
:: Usage: call :ParseArgs [repo URL]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="repo" goto :_ParseArgs_repo
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_repo
if "%~2"=="" (echo ERROR: repo requires a URL. & exit /b 2)
set "app.github_verify_clone.repo=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.github_verify_clone.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays temporary clone verification usage.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo github_verify_clone.bat
echo.
echo Usage:
echo   github_verify_clone.bat
echo   github_verify_clone.bat repo URL
echo.
echo The helper clones into a temporary directory, validates the
echo worktree, and removes the temporary clone.
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
