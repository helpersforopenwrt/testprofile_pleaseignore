@echo off
:: ============================================================
:: build_noop.bat
:: No-operation build implementation for demonstration projects.
::
:: Configuration order:
::   1. build_config.bat
::   2. build_config_noop.bat when present
::
:: The suffix-specific configuration supplements or overrides the
:: shared project configuration.
::
:: Active placement:
::   build_noop.bat at the project root
::
:: Template storage:
::   tools\templates\build\build_noop.bat
::
:: The root build launcher discovers this file automatically.
::
:: Usage:
::   call build_noop.bat [mode] [additional arguments]
::
:: Returns: 0 on success
::          1 when the project root or shared config cannot be loaded
::          shared/suffix config exit code when a config fails
:: Requires: build_config.bat
:: ============================================================
:setup
set "app.build.noop.rc=0"
set "app.build.noop.root="
set "app.build.noop.shared_config="
set "app.build.noop.suffix_config="
set "app.build.noop.mode="
set "app.build.noop.title="
set "app.build.noop.description="
set "app.build.suffix=noop"
if not defined BUILD_SUFFIX set "BUILD_SUFFIX=noop"
if defined BUILD_PROJECT_ROOT set "app.build.noop.root=%BUILD_PROJECT_ROOT%"
if not defined app.build.noop.root for %%A in ("%~dp0.") do set "app.build.noop.root=%%~fA"
for %%A in ("%app.build.noop.root%\.") do set "app.build.noop.root=%%~fA"
:load
set "app.build.noop.shared_config=%app.build.noop.root%\build_config.bat"
set "app.build.noop.suffix_config=%app.build.noop.root%\build_config_noop.bat"
if exist "%app.build.noop.shared_config%" goto :load_shared
echo.
echo ERROR: Shared build configuration was not found:
echo   "%app.build.noop.shared_config%"
echo.
set "app.build.noop.rc=1"
goto :end
:load_shared
call "%app.build.noop.shared_config%"
set "app.build.noop.rc=%errorlevel%"
if "%app.build.noop.rc%"=="0" goto :load_suffix
echo.
echo ERROR: Shared build configuration failed:
echo   "%app.build.noop.shared_config%"
echo.
goto :end
:load_suffix
if not exist "%app.build.noop.suffix_config%" goto :defaults
call "%app.build.noop.suffix_config%"
set "app.build.noop.rc=%errorlevel%"
if "%app.build.noop.rc%"=="0" goto :defaults
echo.
echo ERROR: No-op build configuration failed:
echo   "%app.build.noop.suffix_config%"
echo.
goto :end
:defaults
if not defined app.noop.default_mode set "app.noop.default_mode=%app.default_mode%"
if not defined app.noop.default_mode set "app.noop.default_mode=build"
if not defined app.noop.title set "app.noop.title=%app.display_name% demonstrator build"
if not defined app.noop.title set "app.noop.title=No-operation demonstrator build"
if not defined app.noop.description set "app.noop.description=This demonstrator has no source code to compile."
set "app.build.noop.mode=%~1"
if not defined app.build.noop.mode set "app.build.noop.mode=%app.noop.default_mode%"
cd /d "%app.build.noop.root%"
if errorlevel 1 (echo ERROR: Could not enter project root. & set "app.build.noop.rc=1" & goto :end)
echo.
echo ============================================================
echo  %app.noop.title%
echo ============================================================
echo.
echo Folder:
echo   %CD%
echo.
echo Suffix:
echo   noop
echo.
echo Mode:
echo   %app.build.noop.mode%
echo.
if /I "%app.build.noop.mode%"=="check" goto :check
if /I "%app.build.noop.mode%"=="help" goto :help
if /I "%app.build.noop.mode%"=="--help" goto :help
if /I "%app.build.noop.mode%"=="/help" goto :help
if /I "%app.build.noop.mode%"=="/?" goto :help
echo No-op build complete.
echo %app.noop.description%
if /I "%app.build.noop.mode%"=="nosync" echo No commit or push was performed.
echo.
set "app.build.noop.rc=0"
goto :end
:check
echo Configuration check complete.
echo %app.noop.description%
echo.
set "app.build.noop.rc=0"
goto :end
:help
echo Usage:
echo   build_noop.bat [build^|check^|nosync^|help]
echo.
echo All additional launcher arguments are accepted and ignored.
echo This implementation never compiles, installs, commits, or pushes.
echo.
set "app.build.noop.rc=0"
:end
exit /b %app.build.noop.rc%
