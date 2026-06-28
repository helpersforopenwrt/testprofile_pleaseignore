@echo off
:: ============================================================
:: install_noop.bat
:: No-operation install implementation for demonstration projects.
::
:: This file intentionally does not install, copy, register, deploy,
:: or modify anything. It is a safe template for documenting a real
:: project's installation workflow before implementation.
::
:: Configuration order:
::   1. build_config.bat when present
::   2. build_config_noop.bat when present
::
:: Active placement:
::   install_noop.bat at the project root
::
:: Template storage:
::   tools\templates\install\install_noop.bat
::
:: Suggested real-install sections:
::   - validate build artifacts
::   - choose destination
::   - request confirmation
::   - create destination folders
::   - copy or deploy files
::   - register shortcuts or services
::   - verify the installation
::   - provide uninstall or rollback guidance
::
:: Usage:
::   call install_noop.bat [arguments]
::
:: Returns: 0 on success or help
::          config exit code when a loaded config fails
:: Requires: none
:: ============================================================
:setup
set "app.install.noop.rc=0"
set "app.install.noop.root="
set "app.install.noop.shared_config="
set "app.install.noop.suffix_config="
set "app.install.noop.arguments="
set "app.install.noop.title="
set "app.install.noop.description="
set "app.install.suffix=noop"
if not defined INSTALL_SUFFIX set "INSTALL_SUFFIX=noop"
if defined INSTALL_PROJECT_ROOT set "app.install.noop.root=%INSTALL_PROJECT_ROOT%"
if not defined app.install.noop.root for %%A in ("%~dp0.") do set "app.install.noop.root=%%~fA"
for %%A in ("%app.install.noop.root%\.") do set "app.install.noop.root=%%~fA"
set "app.install.noop.shared_config=%app.install.noop.root%\build_config.bat"
set "app.install.noop.suffix_config=%app.install.noop.root%\build_config_noop.bat"
if not exist "%app.install.noop.shared_config%" goto :load_suffix
call "%app.install.noop.shared_config%"
set "app.install.noop.rc=%errorlevel%"
if "%app.install.noop.rc%"=="0" goto :load_suffix
echo.
echo ERROR: Shared configuration failed:
echo   "%app.install.noop.shared_config%"
echo.
goto :end
:load_suffix
if not exist "%app.install.noop.suffix_config%" goto :defaults
call "%app.install.noop.suffix_config%"
set "app.install.noop.rc=%errorlevel%"
if "%app.install.noop.rc%"=="0" goto :defaults
echo.
echo ERROR: No-op configuration failed:
echo   "%app.install.noop.suffix_config%"
echo.
goto :end
:defaults
if not defined app.install.noop.title set "app.install.noop.title=%app.display_name% no-operation installer"
if not defined app.install.noop.title set "app.install.noop.title=No-operation installer"
if not defined app.install.noop.description set "app.install.noop.description=This project has no installation actions."
set "app.install.noop.arguments=%*"
if /I "%~1"=="help" goto :help
if /I "%~1"=="--help" goto :help
if /I "%~1"=="/help" goto :help
if /I "%~1"=="/?" goto :help
goto :run
:run
echo.
echo ============================================================
echo  %app.install.noop.title%
echo ============================================================
echo.
echo Project root:
echo   %app.install.noop.root%
echo.
echo Suffix:
echo   noop
echo.
echo Requested installation:
if defined app.install.noop.arguments goto :show_arguments
echo   default
goto :show_plan
:show_arguments
echo   %app.install.noop.arguments%
:show_plan
echo.
echo Installation plan:
echo   1. Validate the expected build artifact.
echo   2. Select or confirm an installation destination.
echo   3. Copy or deploy the required files.
echo   4. Create shortcuts or registrations when needed.
echo   5. Verify the installed result.
echo   6. Document uninstall or rollback steps.
echo.
echo No-op installation complete.
echo %app.install.noop.description%
echo No files were copied, installed, registered, or changed.
echo.
set "app.install.noop.rc=0"
goto :end
:help
echo.
echo install_noop.bat
echo.
echo Usage:
echo   install_noop.bat [arguments]
echo.
echo This implementation documents a possible installation flow
echo but intentionally performs no installation actions.
echo.
echo Replace the no-op section with project-specific validation,
echo confirmation, deployment, verification, and rollback logic.
echo.
set "app.install.noop.rc=0"
:end
exit /b %app.install.noop.rc%
