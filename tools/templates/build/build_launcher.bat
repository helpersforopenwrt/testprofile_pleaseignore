@echo off
:: ============================================================
:: build_launcher.bat
:: Runs every eligible build_*.bat implementation alphabetically.
::
:: Active placement:
::   build.bat at the project root
::
:: Template storage:
::   tools\templates\build\build_launcher.bat
::
:: Copy the template to the project root and rename it build.bat.
:: The active launcher searches only its own directory. It never
:: discovers or runs templates under tools.
::
:: Ignored:
::   build_launcher.bat
::   build_config.bat
::   build_config_*.bat
::   build_only.bat
::   build_without_push.bat
::   the launcher's own filename
::
:: Every child receives the original arguments plus:
::   BUILD_LAUNCHER_ACTIVE=1
::   BUILD_PROJECT_ROOT
::   BUILD_IMPLEMENTATION_DIR
::   BUILD_SUFFIX
::   app.build.suffix
::
:: Color control:
::   BUILD_LAUNCHER_COLOR=auto|always|never
::   NO_COLOR=1
::
:: Usage:
::   call build.bat [arguments]
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
set "app.build_launcher.self=%~nx0"
set "app.build_launcher.root="
set "app.build_launcher.dir="
set "app.build_launcher.candidate="
set "app.build_launcher.file="
set "app.build_launcher.suffix="
set "app.build_launcher.total=0"
set "app.build_launcher.skipped=0"
set "app.build_launcher.ok=0"
set "app.build_launcher.failed=0"
set "app.build_launcher.rc=0"
set "app.build_launcher.color.mode=%BUILD_LAUNCHER_COLOR%"
if not defined app.build_launcher.color.mode set "app.build_launcher.color.mode=auto"
set "app.build_launcher.color.reset="
set "app.build_launcher.color.title="
set "app.build_launcher.color.info="
set "app.build_launcher.color.ok="
set "app.build_launcher.color.warn="
set "app.build_launcher.color.error="
call :InitColors
call :ResolvePaths
set "app.build_launcher.rc=%errorlevel%"
if "%app.build_launcher.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.build_launcher.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.build_launcher.rc%
:: ============================================================
:: :Main
:: Enumerates, runs, and summarizes build implementations.
::
:: Usage: call :Main [arguments]
::
:: Returns: aggregate launcher result
:: Requires: :RunCandidate, dir
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set blm_ 2^>nul') do set "%%v="
if defined _blm_rc (set "_blm_rc=" & exit /b %_blm_rc%)
set "app.build_launcher.total=0"
set "app.build_launcher.skipped=0"
set "app.build_launcher.ok=0"
set "app.build_launcher.failed=0"
set "app.build_launcher.rc=0"
echo.
echo %app.build_launcher.color.title%============================================================%app.build_launcher.color.reset%
echo %app.build_launcher.color.title% Build launcher%app.build_launcher.color.reset%
echo %app.build_launcher.color.title%============================================================%app.build_launcher.color.reset%
echo.
echo Project root:
echo   %app.build_launcher.root%
echo.
echo Implementation directory:
echo   %app.build_launcher.dir%
echo.
echo Arguments:
if "%~1"=="" goto :_Main_no_args
echo   %*
goto :_Main_args_done
:_Main_no_args
echo   none
:_Main_args_done
echo.
pushd "%app.build_launcher.root%" >nul 2>nul
if errorlevel 1 (echo %app.build_launcher.color.error%ERROR: Could not enter the project root.%app.build_launcher.color.reset% & set "_blm_rc=1" & goto :Main)
for /f "delims=" %%F in ('dir /b /a-d /on "%app.build_launcher.dir%\build_*.bat" 2^>nul') do (
set "app.build_launcher.candidate=%%F"
call :RunCandidate %*
)
popd
if not "%app.build_launcher.total%"=="0" goto :_Main_summary
echo %app.build_launcher.color.error%ERROR: No eligible build implementations were found.%app.build_launcher.color.reset%
echo.
echo Add project-root files such as:
echo   %app.build_launcher.root%\build_noop.bat
echo   %app.build_launcher.root%\build_androidjava.bat
echo   %app.build_launcher.root%\build_wintcc.bat
set "_blm_rc=1" & goto :Main
:_Main_summary
echo.
echo %app.build_launcher.color.title%============================================================%app.build_launcher.color.reset%
echo %app.build_launcher.color.title% Build summary%app.build_launcher.color.reset%
echo %app.build_launcher.color.title%============================================================%app.build_launcher.color.reset%
echo.
echo Implementations run: %app.build_launcher.total%
echo Succeeded:           %app.build_launcher.ok%
echo Failed:              %app.build_launcher.failed%
echo Ignored:             %app.build_launcher.skipped%
echo.
if "%app.build_launcher.failed%"=="0" goto :_Main_success
echo %app.build_launcher.color.error%One or more build implementations failed.%app.build_launcher.color.reset%
set "_blm_rc=%app.build_launcher.rc%" & goto :Main
:_Main_success
echo %app.build_launcher.color.ok%All build implementations completed successfully.%app.build_launcher.color.reset%
set "_blm_rc=0" & goto :Main
:: ============================================================
:: :ResolvePaths
:: Treats the launcher's own directory as the project root and the
:: only active build implementation directory.
::
:: Usage: call :ResolvePaths
::
:: Output:
::   app.build_launcher.root
::   app.build_launcher.dir
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ResolvePaths
for /f "tokens=1 delims==" %%v in ('set blp_ 2^>nul') do set "%%v="
if defined _blp_rc (set "_blp_rc=" & exit /b %_blp_rc%)
for %%A in ("%~dp0.") do set "app.build_launcher.root=%%~fA"
set "app.build_launcher.dir=%app.build_launcher.root%"
set "_blp_rc=0" & goto :ResolvePaths
:: ============================================================
:: :RunCandidate
:: Skips non-build files or runs one build in an isolated cmd.exe.
::
:: Usage: call :RunCandidate [forwarded arguments]
::
:: Returns: 0
:: Requires: :ShouldIgnore, cmd.exe
:: ============================================================
:RunCandidate
for /f "tokens=1 delims==" %%v in ('set blr_ 2^>nul') do set "%%v="
if defined _blr_rc (set "_blr_rc=" & exit /b %_blr_rc%)
call :ShouldIgnore "%app.build_launcher.candidate%"
set "blr_ignore_rc=%errorlevel%"
if "%blr_ignore_rc%"=="0" goto :_RunCandidate_skip
set "app.build_launcher.suffix=%app.build_launcher.candidate:~6,-4%"
if defined app.build_launcher.suffix goto :_RunCandidate_run
echo %app.build_launcher.color.warn%[SKIP] Empty suffix: %app.build_launcher.candidate%%app.build_launcher.color.reset%
set /a app.build_launcher.skipped+=1 >nul
set "_blr_rc=0" & goto :RunCandidate
:_RunCandidate_skip
echo %app.build_launcher.color.info%[SKIP] %app.build_launcher.candidate%%app.build_launcher.color.reset%
set /a app.build_launcher.skipped+=1 >nul
set "_blr_rc=0" & goto :RunCandidate
:_RunCandidate_run
set /a app.build_launcher.total+=1 >nul
set "app.build_launcher.file=%app.build_launcher.dir%\%app.build_launcher.candidate%"
set "BUILD_LAUNCHER_ACTIVE=1"
set "BUILD_PROJECT_ROOT=%app.build_launcher.root%"
set "BUILD_IMPLEMENTATION_DIR=%app.build_launcher.dir%"
set "BUILD_SUFFIX=%app.build_launcher.suffix%"
set "app.build.suffix=%app.build_launcher.suffix%"
echo.
echo %app.build_launcher.color.info%[RUN ] %app.build_launcher.candidate%  suffix=%app.build_launcher.suffix%%app.build_launcher.color.reset%
echo.
"%ComSpec%" /d /c call "%app.build_launcher.file%" %*
set "blr_child_rc=%errorlevel%"
set "BUILD_LAUNCHER_ACTIVE="
set "BUILD_PROJECT_ROOT="
set "BUILD_IMPLEMENTATION_DIR="
set "BUILD_SUFFIX="
set "app.build.suffix="
if "%blr_child_rc%"=="0" goto :_RunCandidate_ok
set /a app.build_launcher.failed+=1 >nul
if not "%app.build_launcher.rc%"=="0" goto :_RunCandidate_report_fail
set "app.build_launcher.rc=%blr_child_rc%"
:_RunCandidate_report_fail
echo.
echo %app.build_launcher.color.error%[FAIL] %app.build_launcher.candidate% returned %blr_child_rc%.%app.build_launcher.color.reset%
set "_blr_rc=0" & goto :RunCandidate
:_RunCandidate_ok
set /a app.build_launcher.ok+=1 >nul
echo.
echo %app.build_launcher.color.ok%[ OK ] %app.build_launcher.candidate%%app.build_launcher.color.reset%
set "_blr_rc=0" & goto :RunCandidate
:: ============================================================
:: :ShouldIgnore
:: Identifies launcher, config, and wrapper files.
::
:: Add future wrapper names to the exact checks below.
::
:: Usage: call :ShouldIgnore FILE_NAME
::
:: Returns: 0 to ignore, 1 to run
:: Requires: none
:: ============================================================
:ShouldIgnore
for /f "tokens=1 delims==" %%v in ('set bli_ 2^>nul') do set "%%v="
if defined _bli_rc (set "_bli_rc=" & exit /b %_bli_rc%)
set "bli_name=%~1"
if /I "%bli_name%"=="%app.build_launcher.self%" (set "_bli_rc=0" & goto :ShouldIgnore)
if /I "%bli_name%"=="build_launcher.bat" (set "_bli_rc=0" & goto :ShouldIgnore)
if /I "%bli_name%"=="build_config.bat" (set "_bli_rc=0" & goto :ShouldIgnore)
if /I "%bli_name%"=="build_only.bat" (set "_bli_rc=0" & goto :ShouldIgnore)
if /I "%bli_name%"=="build_without_push.bat" (set "_bli_rc=0" & goto :ShouldIgnore)
if /I "%bli_name:~0,13%"=="build_config_" (set "_bli_rc=0" & goto :ShouldIgnore)
set "_bli_rc=1" & goto :ShouldIgnore
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
for /f "tokens=1 delims==" %%v in ('set blc_ 2^>nul') do set "%%v="
if defined _blc_rc (set "_blc_rc=" & exit /b %_blc_rc%)
if defined NO_COLOR (set "_blc_rc=0" & goto :InitColors)
if /I "%app.build_launcher.color.mode%"=="never" (set "_blc_rc=0" & goto :InitColors)
if /I "%app.build_launcher.color.mode%"=="always" goto :_InitColors_enable
if defined WT_SESSION goto :_InitColors_enable
if defined ANSICON goto :_InitColors_enable
if /I "%ConEmuANSI%"=="ON" goto :_InitColors_enable
if defined TERM goto :_InitColors_enable
if defined COLORTERM goto :_InitColors_enable
set "_blc_rc=0" & goto :InitColors
:_InitColors_enable
set "blc_esc="
for /f "delims=#" %%E in ('"prompt #$E# & for %%B in (1) do rem"') do set "blc_esc=%%E"
if not defined blc_esc (set "_blc_rc=0" & goto :InitColors)
set "app.build_launcher.color.reset=%blc_esc%[0m"
set "app.build_launcher.color.title=%blc_esc%[96m"
set "app.build_launcher.color.info=%blc_esc%[94m"
set "app.build_launcher.color.ok=%blc_esc%[92m"
set "app.build_launcher.color.warn=%blc_esc%[93m"
set "app.build_launcher.color.error=%blc_esc%[91m"
set "_blc_rc=0" & goto :InitColors
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
