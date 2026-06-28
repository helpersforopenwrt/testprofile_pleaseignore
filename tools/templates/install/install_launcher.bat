@echo off
:: ============================================================
:: install_launcher.bat
:: Runs every eligible install_*.bat implementation alphabetically.
::
:: Active placement:
::   install.bat at the project root
::
:: Template storage:
::   tools\templates\install\install_launcher.bat
::
:: Copy the template to the project root and rename it install.bat.
:: The active launcher searches only its own directory. It never
:: discovers or runs templates under tools.
::
:: Ignored:
::   install_launcher.bat
::   install_config.bat
::   install_config_*.bat
::   install_only.bat
::   install_without_build.bat
::   the launcher's own filename
::
:: Every child receives the original arguments plus:
::   INSTALL_LAUNCHER_ACTIVE=1
::   INSTALL_PROJECT_ROOT
::   INSTALL_IMPLEMENTATION_DIR
::   INSTALL_SUFFIX
::   app.install.suffix
::
:: Color control:
::   INSTALL_LAUNCHER_COLOR=auto|always|never
::   NO_COLOR=1
::
:: Usage:
::   call install.bat [arguments]
::
:: Returns: 0 when all implementations succeed
::          1 when setup fails or no implementation exists
::          first nonzero child exit code otherwise
:: Requires: cmd.exe, dir, find.exe, :Main, :ResolvePaths,
::           :RunCandidate, :ShouldIgnore, :InitColors,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.install_launcher.self=%~nx0"
set "app.install_launcher.root="
set "app.install_launcher.dir="
set "app.install_launcher.candidate="
set "app.install_launcher.file="
set "app.install_launcher.suffix="
set "app.install_launcher.total=0"
set "app.install_launcher.skipped=0"
set "app.install_launcher.ok=0"
set "app.install_launcher.failed=0"
set "app.install_launcher.rc=0"
set "app.install_launcher.color.mode=%INSTALL_LAUNCHER_COLOR%"
if not defined app.install_launcher.color.mode set "app.install_launcher.color.mode=auto"
set "app.install_launcher.color.reset="
set "app.install_launcher.color.title="
set "app.install_launcher.color.info="
set "app.install_launcher.color.ok="
set "app.install_launcher.color.warn="
set "app.install_launcher.color.error="
call :InitColors
call :ResolvePaths
set "app.install_launcher.rc=%errorlevel%"
if "%app.install_launcher.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.install_launcher.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.install_launcher.rc%
:: ============================================================
:: :Main
:: Enumerates, runs, and summarizes install implementations.
::
:: Usage: call :Main [arguments]
::
:: Returns: aggregate launcher result
:: Requires: :RunCandidate, dir
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set ilm_ 2^>nul') do set "%%v="
if defined _ilm_rc (set "_ilm_rc=" & exit /b %_ilm_rc%)
set "app.install_launcher.total=0"
set "app.install_launcher.skipped=0"
set "app.install_launcher.ok=0"
set "app.install_launcher.failed=0"
set "app.install_launcher.rc=0"
echo.
echo %app.install_launcher.color.title%============================================================%app.install_launcher.color.reset%
echo %app.install_launcher.color.title% Install launcher%app.install_launcher.color.reset%
echo %app.install_launcher.color.title%============================================================%app.install_launcher.color.reset%
echo.
echo Project root:
echo   %app.install_launcher.root%
echo.
echo Implementation directory:
echo   %app.install_launcher.dir%
echo.
echo Arguments:
if "%~1"=="" goto :_Main_no_args
echo   %*
goto :_Main_args_done
:_Main_no_args
echo   none
:_Main_args_done
echo.
pushd "%app.install_launcher.root%" >nul 2>nul
if errorlevel 1 (echo %app.install_launcher.color.error%ERROR: Could not enter the project root.%app.install_launcher.color.reset% & set "_ilm_rc=1" & goto :Main)
for /f "delims=" %%F in ('dir /b /a-d /on "%app.install_launcher.dir%\install_*.bat" 2^>nul') do (
set "app.install_launcher.candidate=%%F"
call :RunCandidate %*
)
popd
if not "%app.install_launcher.total%"=="0" goto :_Main_summary
echo %app.install_launcher.color.error%ERROR: No eligible install implementations were found.%app.install_launcher.color.reset%
echo.
echo Add project-root files such as:
echo   %app.install_launcher.root%\install_noop.bat
echo   %app.install_launcher.root%\install_androidjava.bat
echo   %app.install_launcher.root%\install_wintcc.bat
set "_ilm_rc=1" & goto :Main
:_Main_summary
echo.
echo %app.install_launcher.color.title%============================================================%app.install_launcher.color.reset%
echo %app.install_launcher.color.title% Install summary%app.install_launcher.color.reset%
echo %app.install_launcher.color.title%============================================================%app.install_launcher.color.reset%
echo.
echo Implementations run: %app.install_launcher.total%
echo Succeeded:           %app.install_launcher.ok%
echo Failed:              %app.install_launcher.failed%
echo Ignored:             %app.install_launcher.skipped%
echo.
if "%app.install_launcher.failed%"=="0" goto :_Main_success
echo %app.install_launcher.color.error%One or more install implementations failed.%app.install_launcher.color.reset%
set "_ilm_rc=%app.install_launcher.rc%" & goto :Main
:_Main_success
echo %app.install_launcher.color.ok%All install implementations completed successfully.%app.install_launcher.color.reset%
set "_ilm_rc=0" & goto :Main
:: ============================================================
:: :ResolvePaths
:: Treats the launcher's own directory as the project root and the
:: only active install implementation directory.
::
:: Usage: call :ResolvePaths
::
:: Output:
::   app.install_launcher.root
::   app.install_launcher.dir
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ResolvePaths
for /f "tokens=1 delims==" %%v in ('set ilp_ 2^>nul') do set "%%v="
if defined _ilp_rc (set "_ilp_rc=" & exit /b %_ilp_rc%)
for %%A in ("%~dp0.") do set "app.install_launcher.root=%%~fA"
set "app.install_launcher.dir=%app.install_launcher.root%"
set "_ilp_rc=0" & goto :ResolvePaths
:: ============================================================
:: :RunCandidate
:: Skips non-install files or runs one implementation in an
:: isolated cmd.exe.
::
:: Usage: call :RunCandidate [forwarded arguments]
::
:: Returns: 0
:: Requires: :ShouldIgnore, cmd.exe
:: ============================================================
:RunCandidate
for /f "tokens=1 delims==" %%v in ('set ilr_ 2^>nul') do set "%%v="
if defined _ilr_rc (set "_ilr_rc=" & exit /b %_ilr_rc%)
call :ShouldIgnore "%app.install_launcher.candidate%"
set "ilr_ignore_rc=%errorlevel%"
if "%ilr_ignore_rc%"=="0" goto :_RunCandidate_skip
set "app.install_launcher.suffix=%app.install_launcher.candidate:~8,-4%"
if defined app.install_launcher.suffix goto :_RunCandidate_run
echo %app.install_launcher.color.warn%[SKIP] Empty suffix: %app.install_launcher.candidate%%app.install_launcher.color.reset%
set /a app.install_launcher.skipped+=1 >nul
set "_ilr_rc=0" & goto :RunCandidate
:_RunCandidate_skip
echo %app.install_launcher.color.info%[SKIP] %app.install_launcher.candidate%%app.install_launcher.color.reset%
set /a app.install_launcher.skipped+=1 >nul
set "_ilr_rc=0" & goto :RunCandidate
:_RunCandidate_run
set /a app.install_launcher.total+=1 >nul
set "app.install_launcher.file=%app.install_launcher.dir%\%app.install_launcher.candidate%"
set "INSTALL_LAUNCHER_ACTIVE=1"
set "INSTALL_PROJECT_ROOT=%app.install_launcher.root%"
set "INSTALL_IMPLEMENTATION_DIR=%app.install_launcher.dir%"
set "INSTALL_SUFFIX=%app.install_launcher.suffix%"
set "app.install.suffix=%app.install_launcher.suffix%"
echo.
echo %app.install_launcher.color.info%[RUN ] %app.install_launcher.candidate%  suffix=%app.install_launcher.suffix%%app.install_launcher.color.reset%
echo.
"%ComSpec%" /d /c call "%app.install_launcher.file%" %*
set "ilr_child_rc=%errorlevel%"
set "INSTALL_LAUNCHER_ACTIVE="
set "INSTALL_PROJECT_ROOT="
set "INSTALL_IMPLEMENTATION_DIR="
set "INSTALL_SUFFIX="
set "app.install.suffix="
if "%ilr_child_rc%"=="0" goto :_RunCandidate_ok
set /a app.install_launcher.failed+=1 >nul
if not "%app.install_launcher.rc%"=="0" goto :_RunCandidate_report_fail
set "app.install_launcher.rc=%ilr_child_rc%"
:_RunCandidate_report_fail
echo.
echo %app.install_launcher.color.error%[FAIL] %app.install_launcher.candidate% returned %ilr_child_rc%.%app.install_launcher.color.reset%
set "_ilr_rc=0" & goto :RunCandidate
:_RunCandidate_ok
set /a app.install_launcher.ok+=1 >nul
echo.
echo %app.install_launcher.color.ok%[ OK ] %app.install_launcher.candidate%%app.install_launcher.color.reset%
set "_ilr_rc=0" & goto :RunCandidate
:: ============================================================
:: :ShouldIgnore
:: Identifies launcher, configuration, and wrapper files.
::
:: Add future wrapper names to the exact checks below.
::
:: Usage: call :ShouldIgnore FILE_NAME
::
:: Returns: 0 to ignore, 1 to run
:: Requires: none
:: ============================================================
:ShouldIgnore
for /f "tokens=1 delims==" %%v in ('set ili_ 2^>nul') do set "%%v="
if defined _ili_rc (set "_ili_rc=" & exit /b %_ili_rc%)
set "ili_name=%~1"
if /I "%ili_name%"=="%app.install_launcher.self%" (set "_ili_rc=0" & goto :ShouldIgnore)
if /I "%ili_name%"=="install_launcher.bat" (set "_ili_rc=0" & goto :ShouldIgnore)
if /I "%ili_name%"=="install_config.bat" (set "_ili_rc=0" & goto :ShouldIgnore)
if /I "%ili_name%"=="install_only.bat" (set "_ili_rc=0" & goto :ShouldIgnore)
if /I "%ili_name%"=="install_without_build.bat" (set "_ili_rc=0" & goto :ShouldIgnore)
if /I "%ili_name:~0,15%"=="install_config_" (set "_ili_rc=0" & goto :ShouldIgnore)
set "_ili_rc=1" & goto :ShouldIgnore
:: ============================================================
:: :InitColors
:: Enables ANSI color when supported or explicitly requested.
::
:: Usage: call :InitColors
::
:: Returns: 0
:: Requires: prompt
:: ============================================================
:InitColors
for /f "tokens=1 delims==" %%v in ('set ilc_ 2^>nul') do set "%%v="
if defined _ilc_rc (set "_ilc_rc=" & exit /b %_ilc_rc%)
if defined NO_COLOR (set "_ilc_rc=0" & goto :InitColors)
if /I "%app.install_launcher.color.mode%"=="never" (set "_ilc_rc=0" & goto :InitColors)
if /I "%app.install_launcher.color.mode%"=="always" goto :_InitColors_enable
if defined WT_SESSION goto :_InitColors_enable
if defined ANSICON goto :_InitColors_enable
if /I "%ConEmuANSI%"=="ON" goto :_InitColors_enable
if defined TERM goto :_InitColors_enable
if defined COLORTERM goto :_InitColors_enable
set "_ilc_rc=0" & goto :InitColors
:_InitColors_enable
set "ilc_esc="
for /f "delims=#" %%E in ('"prompt #$E# & for %%B in (1) do rem"') do set "ilc_esc=%%E"
if not defined ilc_esc (set "_ilc_rc=0" & goto :InitColors)
set "app.install_launcher.color.reset=%ilc_esc%[0m"
set "app.install_launcher.color.title=%ilc_esc%[96m"
set "app.install_launcher.color.info=%ilc_esc%[94m"
set "app.install_launcher.color.ok=%ilc_esc%[92m"
set "app.install_launcher.color.warn=%ilc_esc%[93m"
set "app.install_launcher.color.error=%ilc_esc%[91m"
set "_ilc_rc=0" & goto :InitColors
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
:: Detects whether the launcher is in an existing console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 for existing console, 1 for outer cmd.exe /c target
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
