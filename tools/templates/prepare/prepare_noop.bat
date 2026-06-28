@echo off
:: ============================================================
:: prepare_noop.bat
:: No-operation prepare implementation for demonstration projects.
::
:: This file performs no downloads, installations, or environment
:: changes. It accepts any forwarded prepare arguments and returns
:: success after reporting what would have been prepared.
::
:: Configuration order:
::   1. build_config.bat when present
::   2. build_config_noop.bat when present
::
:: Active placement:
::   prepare_noop.bat at the project root
::
:: Template storage:
::   tools\templates\prepare\prepare_noop.bat
::
:: Usage:
::   call prepare_noop.bat [arguments]
::
:: Returns: 0 on success or help
::          config exit code when a loaded config fails
:: Requires: none
:: ============================================================
:setup
set "app.prepare.noop.rc=0"
set "app.prepare.noop.root="
set "app.prepare.noop.shared_config="
set "app.prepare.noop.suffix_config="
set "app.prepare.noop.arguments="
set "app.prepare.noop.title="
set "app.prepare.noop.description="
set "app.prepare.suffix=noop"
if not defined PREPARE_SUFFIX set "PREPARE_SUFFIX=noop"
if defined PREPARE_PROJECT_ROOT set "app.prepare.noop.root=%PREPARE_PROJECT_ROOT%"
if not defined app.prepare.noop.root for %%A in ("%~dp0.") do set "app.prepare.noop.root=%%~fA"
for %%A in ("%app.prepare.noop.root%\.") do set "app.prepare.noop.root=%%~fA"
set "app.prepare.noop.shared_config=%app.prepare.noop.root%\build_config.bat"
set "app.prepare.noop.suffix_config=%app.prepare.noop.root%\build_config_noop.bat"
if not exist "%app.prepare.noop.shared_config%" goto :load_suffix
call "%app.prepare.noop.shared_config%"
set "app.prepare.noop.rc=%errorlevel%"
if "%app.prepare.noop.rc%"=="0" goto :load_suffix
echo.
echo ERROR: Shared configuration failed:
echo   "%app.prepare.noop.shared_config%"
echo.
goto :end
:load_suffix
if not exist "%app.prepare.noop.suffix_config%" goto :defaults
call "%app.prepare.noop.suffix_config%"
set "app.prepare.noop.rc=%errorlevel%"
if "%app.prepare.noop.rc%"=="0" goto :defaults
echo.
echo ERROR: No-op configuration failed:
echo   "%app.prepare.noop.suffix_config%"
echo.
goto :end
:defaults
if not defined app.prepare.noop.title set "app.prepare.noop.title=%app.display_name% no-operation preparation"
if not defined app.prepare.noop.title set "app.prepare.noop.title=No-operation preparation"
if not defined app.prepare.noop.description set "app.prepare.noop.description=This project requires no build-system preparation."
set "app.prepare.noop.arguments=%*"
if /I "%~1"=="help" goto :help
if /I "%~1"=="--help" goto :help
if /I "%~1"=="/help" goto :help
if /I "%~1"=="/?" goto :help
goto :run
:run
echo.
echo ============================================================
echo  %app.prepare.noop.title%
echo ============================================================
echo.
echo Project root:
echo   %app.prepare.noop.root%
echo.
echo Suffix:
echo   noop
echo.
echo Requested preparation:
if defined app.prepare.noop.arguments goto :show_arguments
echo   all
goto :show_result
:show_arguments
echo   %app.prepare.noop.arguments%
:show_result
echo.
echo No-op preparation complete.
echo %app.prepare.noop.description%
echo No files were downloaded, installed, or changed.
echo.
set "app.prepare.noop.rc=0"
goto :end
:help
echo.
echo prepare_noop.bat
echo.
echo Usage:
echo   prepare_noop.bat [arguments]
echo.
echo This implementation accepts every prepare mode and succeeds
echo without downloading, installing, or changing anything.
echo.
set "app.prepare.noop.rc=0"
:end
exit /b %app.prepare.noop.rc%
