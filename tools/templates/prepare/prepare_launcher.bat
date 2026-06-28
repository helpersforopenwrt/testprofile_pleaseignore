@echo off
:: ============================================================
:: prepare_launcher.bat
:: Runs every eligible prepare_*.bat implementation alphabetically.
::
:: Active placement:
::   prepare.bat at the project root
::
:: Template storage:
::   tools\templates\prepare\prepare_launcher.bat
::
:: Copy the template to the project root and rename it prepare.bat.
:: The active launcher searches only its own directory. It never
:: discovers or runs templates under tools.
::
:: Ignored:
::   prepare_launcher.bat
::   prepare_config.bat
::   prepare_config_*.bat
::   the launcher's own filename
::
:: Every implementation receives the original arguments plus:
::   PREPARE_LAUNCHER_ACTIVE=1
::   PREPARE_PROJECT_ROOT
::   PREPARE_IMPLEMENTATION_DIR
::   PREPARE_SUFFIX
::   app.prepare.suffix
::
:: Prepare implementations are called in the current cmd.exe so
:: environment changes such as PATH additions return to the caller.
::
:: Color control:
::   PREPARE_LAUNCHER_COLOR=auto|always|never
::   NO_COLOR=1
::
:: Usage:
::   call prepare.bat [arguments]
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
set "app.prepare_launcher.self=%~nx0"
set "app.prepare_launcher.root="
set "app.prepare_launcher.dir="
set "app.prepare_launcher.candidate="
set "app.prepare_launcher.file="
set "app.prepare_launcher.suffix="
set "app.prepare_launcher.total=0"
set "app.prepare_launcher.skipped=0"
set "app.prepare_launcher.ok=0"
set "app.prepare_launcher.failed=0"
set "app.prepare_launcher.rc=0"
set "app.prepare_launcher.color.mode=%PREPARE_LAUNCHER_COLOR%"
if not defined app.prepare_launcher.color.mode set "app.prepare_launcher.color.mode=auto"
set "app.prepare_launcher.color.reset="
set "app.prepare_launcher.color.title="
set "app.prepare_launcher.color.info="
set "app.prepare_launcher.color.ok="
set "app.prepare_launcher.color.warn="
set "app.prepare_launcher.color.error="
call :InitColors
call :ResolvePaths
set "app.prepare_launcher.rc=%errorlevel%"
if "%app.prepare_launcher.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.prepare_launcher.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.prepare_launcher.rc%
:: ============================================================
:: :Main
:: Enumerates, runs, and summarizes prepare implementations.
::
:: Usage: call :Main [arguments]
::
:: Returns: aggregate launcher result
:: Requires: :RunCandidate, dir
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set plm_ 2^>nul') do set "%%v="
if defined _plm_rc (set "_plm_rc=" & exit /b %_plm_rc%)
set "app.prepare_launcher.total=0"
set "app.prepare_launcher.skipped=0"
set "app.prepare_launcher.ok=0"
set "app.prepare_launcher.failed=0"
set "app.prepare_launcher.rc=0"
echo.
echo %app.prepare_launcher.color.title%============================================================%app.prepare_launcher.color.reset%
echo %app.prepare_launcher.color.title% Prepare launcher%app.prepare_launcher.color.reset%
echo %app.prepare_launcher.color.title%============================================================%app.prepare_launcher.color.reset%
echo.
echo Project root:
echo   %app.prepare_launcher.root%
echo.
echo Implementation directory:
echo   %app.prepare_launcher.dir%
echo.
echo Arguments:
if "%~1"=="" goto :_Main_no_args
echo   %*
goto :_Main_args_done
:_Main_no_args
echo   none
:_Main_args_done
echo.
pushd "%app.prepare_launcher.root%" >nul 2>nul
if errorlevel 1 (echo %app.prepare_launcher.color.error%ERROR: Could not enter the project root.%app.prepare_launcher.color.reset% & set "_plm_rc=1" & goto :Main)
for /f "delims=" %%F in ('dir /b /a-d /on "%app.prepare_launcher.dir%\prepare_*.bat" 2^>nul') do (
set "app.prepare_launcher.candidate=%%F"
call :RunCandidate %*
)
popd
if not "%app.prepare_launcher.total%"=="0" goto :_Main_summary
echo %app.prepare_launcher.color.error%ERROR: No eligible prepare implementations were found.%app.prepare_launcher.color.reset%
echo.
echo Add project-root files such as:
echo   %app.prepare_launcher.root%\prepare_noop.bat
echo   %app.prepare_launcher.root%\prepare_androidjava.bat
echo   %app.prepare_launcher.root%\prepare_wintcc.bat
set "_plm_rc=1" & goto :Main
:_Main_summary
echo.
echo %app.prepare_launcher.color.title%============================================================%app.prepare_launcher.color.reset%
echo %app.prepare_launcher.color.title% Prepare summary%app.prepare_launcher.color.reset%
echo %app.prepare_launcher.color.title%============================================================%app.prepare_launcher.color.reset%
echo.
echo Implementations run: %app.prepare_launcher.total%
echo Succeeded:           %app.prepare_launcher.ok%
echo Failed:              %app.prepare_launcher.failed%
echo Ignored:             %app.prepare_launcher.skipped%
echo.
if "%app.prepare_launcher.failed%"=="0" goto :_Main_success
echo %app.prepare_launcher.color.error%One or more prepare implementations failed.%app.prepare_launcher.color.reset%
set "_plm_rc=%app.prepare_launcher.rc%" & goto :Main
:_Main_success
echo %app.prepare_launcher.color.ok%All prepare implementations completed successfully.%app.prepare_launcher.color.reset%
set "_plm_rc=0" & goto :Main
:: ============================================================
:: :ResolvePaths
:: Treats the launcher's own directory as the project root and the
:: only active prepare implementation directory.
::
:: Usage: call :ResolvePaths
::
:: Output:
::   app.prepare_launcher.root
::   app.prepare_launcher.dir
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ResolvePaths
for /f "tokens=1 delims==" %%v in ('set plp_ 2^>nul') do set "%%v="
if defined _plp_rc (set "_plp_rc=" & exit /b %_plp_rc%)
for %%A in ("%~dp0.") do set "app.prepare_launcher.root=%%~fA"
set "app.prepare_launcher.dir=%app.prepare_launcher.root%"
set "_plp_rc=0" & goto :ResolvePaths
:: ============================================================
:: :RunCandidate
:: Skips non-prepare files or calls one implementation in the
:: current cmd.exe so prepared environment values can propagate.
::
:: Usage: call :RunCandidate [forwarded arguments]
::
:: Returns: 0
:: Requires: :ShouldIgnore
:: ============================================================
:RunCandidate
for /f "tokens=1 delims==" %%v in ('set plr_ 2^>nul') do set "%%v="
if defined _plr_rc (set "_plr_rc=" & exit /b %_plr_rc%)
call :ShouldIgnore "%app.prepare_launcher.candidate%"
set "plr_ignore_rc=%errorlevel%"
if "%plr_ignore_rc%"=="0" goto :_RunCandidate_skip
set "app.prepare_launcher.suffix=%app.prepare_launcher.candidate:~8,-4%"
if defined app.prepare_launcher.suffix goto :_RunCandidate_run
echo %app.prepare_launcher.color.warn%[SKIP] Empty suffix: %app.prepare_launcher.candidate%%app.prepare_launcher.color.reset%
set /a app.prepare_launcher.skipped+=1 >nul
set "_plr_rc=0" & goto :RunCandidate
:_RunCandidate_skip
echo %app.prepare_launcher.color.info%[SKIP] %app.prepare_launcher.candidate%%app.prepare_launcher.color.reset%
set /a app.prepare_launcher.skipped+=1 >nul
set "_plr_rc=0" & goto :RunCandidate
:_RunCandidate_run
set /a app.prepare_launcher.total+=1 >nul
set "app.prepare_launcher.file=%app.prepare_launcher.dir%\%app.prepare_launcher.candidate%"
set "PREPARE_LAUNCHER_ACTIVE=1"
set "PREPARE_PROJECT_ROOT=%app.prepare_launcher.root%"
set "PREPARE_IMPLEMENTATION_DIR=%app.prepare_launcher.dir%"
set "PREPARE_SUFFIX=%app.prepare_launcher.suffix%"
set "app.prepare.suffix=%app.prepare_launcher.suffix%"
echo.
echo %app.prepare_launcher.color.info%[RUN ] %app.prepare_launcher.candidate%  suffix=%app.prepare_launcher.suffix%%app.prepare_launcher.color.reset%
echo.
call "%app.prepare_launcher.file%" %*
set "plr_child_rc=%errorlevel%"
set "PREPARE_LAUNCHER_ACTIVE="
set "PREPARE_PROJECT_ROOT="
set "PREPARE_IMPLEMENTATION_DIR="
set "PREPARE_SUFFIX="
set "app.prepare.suffix="
if "%plr_child_rc%"=="0" goto :_RunCandidate_ok
set /a app.prepare_launcher.failed+=1 >nul
if not "%app.prepare_launcher.rc%"=="0" goto :_RunCandidate_report_fail
set "app.prepare_launcher.rc=%plr_child_rc%"
:_RunCandidate_report_fail
echo.
echo %app.prepare_launcher.color.error%[FAIL] %app.prepare_launcher.candidate% returned %plr_child_rc%.%app.prepare_launcher.color.reset%
set "_plr_rc=0" & goto :RunCandidate
:_RunCandidate_ok
set /a app.prepare_launcher.ok+=1 >nul
echo.
echo %app.prepare_launcher.color.ok%[ OK ] %app.prepare_launcher.candidate%%app.prepare_launcher.color.reset%
set "_plr_rc=0" & goto :RunCandidate
:: ============================================================
:: :ShouldIgnore
:: Identifies launcher and configuration files.
::
:: Add future wrapper names to the exact checks below.
::
:: Usage: call :ShouldIgnore FILE_NAME
::
:: Returns: 0 to ignore, 1 to run
:: Requires: none
:: ============================================================
:ShouldIgnore
for /f "tokens=1 delims==" %%v in ('set pli_ 2^>nul') do set "%%v="
if defined _pli_rc (set "_pli_rc=" & exit /b %_pli_rc%)
set "pli_name=%~1"
if /I "%pli_name%"=="%app.prepare_launcher.self%" (set "_pli_rc=0" & goto :ShouldIgnore)
if /I "%pli_name%"=="prepare_launcher.bat" (set "_pli_rc=0" & goto :ShouldIgnore)
if /I "%pli_name%"=="prepare_config.bat" (set "_pli_rc=0" & goto :ShouldIgnore)
if /I "%pli_name:~0,15%"=="prepare_config_" (set "_pli_rc=0" & goto :ShouldIgnore)
set "_pli_rc=1" & goto :ShouldIgnore
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
for /f "tokens=1 delims==" %%v in ('set plc_ 2^>nul') do set "%%v="
if defined _plc_rc (set "_plc_rc=" & exit /b %_plc_rc%)
if defined NO_COLOR (set "_plc_rc=0" & goto :InitColors)
if /I "%app.prepare_launcher.color.mode%"=="never" (set "_plc_rc=0" & goto :InitColors)
if /I "%app.prepare_launcher.color.mode%"=="always" goto :_InitColors_enable
if defined WT_SESSION goto :_InitColors_enable
if defined ANSICON goto :_InitColors_enable
if /I "%ConEmuANSI%"=="ON" goto :_InitColors_enable
if defined TERM goto :_InitColors_enable
if defined COLORTERM goto :_InitColors_enable
set "_plc_rc=0" & goto :InitColors
:_InitColors_enable
set "plc_esc="
for /f "delims=#" %%E in ('"prompt #$E# & for %%B in (1) do rem"') do set "plc_esc=%%E"
if not defined plc_esc (set "_plc_rc=0" & goto :InitColors)
set "app.prepare_launcher.color.reset=%plc_esc%[0m"
set "app.prepare_launcher.color.title=%plc_esc%[96m"
set "app.prepare_launcher.color.info=%plc_esc%[94m"
set "app.prepare_launcher.color.ok=%plc_esc%[92m"
set "app.prepare_launcher.color.warn=%plc_esc%[93m"
set "app.prepare_launcher.color.error=%plc_esc%[91m"
set "_plc_rc=0" & goto :InitColors
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
