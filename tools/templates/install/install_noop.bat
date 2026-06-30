@echo off
:: ============================================================
:: install_noop.bat
:: Generic installation implementation and modifiable template.
::
:: This file models a complete installer lifecycle while remaining
:: harmless until project-specific operations are implemented.
::
:: Install lifecycle:
::   1. load shared and suffix-specific configuration
::   2. parse install mode and source selection arguments
::   3. apply the optional project environment file
::   4. check installer prerequisites
::   5. resolve and validate an install source
::   6. optionally run build.bat when a required source is missing
::   7. resolve the installation destination
::   8. show the installation plan
::   9. optionally request confirmation
::  10. run project-specific installation operations
::  11. validate the installed result
::  12. write uninstall or rollback guidance
::  13. optionally run the installed program
::
:: Uninstall lifecycle:
::   1. check uninstall prerequisites
::   2. resolve the installed destination
::   3. show the uninstall plan
::   4. optionally request confirmation
::   5. run project-specific uninstall operations
::   6. validate the uninstalled result
::
:: This template does not copy, install, register, deploy, remove,
:: launch, or otherwise modify project files by default.
::
:: Primary install customization points:
::   :CheckInstallPrerequisites
::   :ResolveInstallSource
::   :ValidateInstallSource
::   :ResolveInstallDestination
::   :InstallOperations
::   :ValidateInstalledResult
::   :RunInstalledProgram
::   :WriteUninstallInstructions
::   :RollbackFailedInstallation
::
:: Primary uninstall customization points:
::   :CheckUninstallPrerequisites
::   :UninstallOperations
::   :ValidateUninstalledResult
::
:: Configuration order:
::   1. build_config.bat when present
::   2. build_config_noop.bat when present
::
:: Optional configuration:
::   app.install.noop.default_mode=install
::   app.install.noop.title=Project installer
::   app.install.noop.description=Installation description
::   app.install.noop.build_dir_prefix=build
::   app.install.noop.artifact_name=
::   app.install.noop.destination=
::   app.install.noop.require_source=0
::   app.install.noop.auto_build=0
::   app.install.noop.confirm_install=0
::   app.install.noop.confirm_uninstall=1
::   app.install.noop.env_file=env.bat
::   app.install.noop.log_enabled=0
::   app.install.noop.log_dir=install_logs
::
:: Active placement:
::   install_noop.bat at the project root
::
:: Template storage:
::   tools\templates\install\install_noop.bat
::
:: Usage:
::   call install_noop.bat
::   call install_noop.bat install
::   call install_noop.bat run
::   call install_noop.bat check
::   call install_noop.bat plan
::   call install_noop.bat uninstall
::   call install_noop.bat artifact path\to\artifact
::   call install_noop.bat build build_YYYY-MM-DD.HHhmm.ss
::   call install_noop.bat help
::
:: Returns: 0 on success or help
::          1 on setup, source, install, validation, or uninstall failure
::          2 on an invalid command-line argument
::          config/custom operation exit code on failure
:: Requires: optional PowerShell when install logging is enabled
:: ============================================================
:setup
set "app.install.noop.rc=0"
set "app.install.noop.root="
set "app.install.noop.shared_config="
set "app.install.noop.suffix_config="
set "app.install.noop.arguments=%*"
set "app.install.noop.mode="
set "app.install.noop.title="
set "app.install.noop.description="
set "app.install.noop.build_dir_prefix="
set "app.install.noop.artifact_name="
set "app.install.noop.destination="
set "app.install.noop.require_source="
set "app.install.noop.auto_build="
set "app.install.noop.confirm_install="
set "app.install.noop.confirm_uninstall="
set "app.install.noop.env_file="
set "app.install.noop.log_enabled="
set "app.install.noop.log_dir="
set "app.install.noop.log="
set "app.install.noop.timestamp="
set "app.install.noop.request.artifact="
set "app.install.noop.request.build="
set "app.install.noop.source.artifact="
set "app.install.noop.source.build="
set "app.install.noop.source.description="
set "app.install.noop.build.ran="
set "app.install.noop.install.started="
set "app.install.noop.install.complete="
set "app.install.noop.uninstall.started="
set "app.install.noop.uninstall.complete="
set "app.install.noop.confirm.answer="
set "app.install.suffix=noop"
if not defined INSTALL_SUFFIX set "INSTALL_SUFFIX=noop"
if defined INSTALL_PROJECT_ROOT set "app.install.noop.root=%INSTALL_PROJECT_ROOT%"
if not defined app.install.noop.root for %%A in ("%~dp0.") do set "app.install.noop.root=%%~fA"
for %%A in ("%app.install.noop.root%\.") do set "app.install.noop.root=%%~fA"
:main
call :LoadConfiguration
set "app.install.noop.rc=%errorlevel%"
if not "%app.install.noop.rc%"=="0" goto :end
call :SetDefaults
call :ParseArguments %*
set "app.install.noop.rc=%errorlevel%"
if not "%app.install.noop.rc%"=="0" goto :end
if /I "%app.install.noop.mode%"=="help" call :ShowHelp
if /I "%app.install.noop.mode%"=="help" set "app.install.noop.rc=%errorlevel%"
if /I "%app.install.noop.mode%"=="help" goto :end
cd /d "%app.install.noop.root%"
set "app.install.noop.rc=%errorlevel%"
if "%app.install.noop.rc%"=="0" goto :_main_environment
echo.
echo ERROR: Could not enter the project root:
echo   "%app.install.noop.root%"
echo.
set "app.install.noop.rc=1"
goto :end
:_main_environment
call :ApplyEnvironmentFile
set "app.install.noop.rc=%errorlevel%"
if not "%app.install.noop.rc%"=="0" goto :end
call :ShowHeader
if /I "%app.install.noop.mode%"=="check" call :CheckOnly
if /I "%app.install.noop.mode%"=="check" set "app.install.noop.rc=%errorlevel%"
if /I "%app.install.noop.mode%"=="check" goto :end
if /I "%app.install.noop.mode%"=="plan" call :PlanOnly
if /I "%app.install.noop.mode%"=="plan" set "app.install.noop.rc=%errorlevel%"
if /I "%app.install.noop.mode%"=="plan" goto :end
if /I "%app.install.noop.mode%"=="uninstall" call :RunUninstall
if /I "%app.install.noop.mode%"=="uninstall" set "app.install.noop.rc=%errorlevel%"
if /I "%app.install.noop.mode%"=="uninstall" goto :end
call :RunInstall
set "app.install.noop.rc=%errorlevel%"
:end
exit /b %app.install.noop.rc%
:: ============================================================
:: :LoadConfiguration
:: Loads build_config.bat and then build_config_noop.bat.
::
:: Usage: call :LoadConfiguration
::
:: Returns: 0 when configuration succeeds
::          config exit code when one fails
:: Requires: optional build_config.bat and build_config_noop.bat
:: ============================================================
:LoadConfiguration
set "app.install.noop.shared_config=%app.install.noop.root%\build_config.bat"
set "app.install.noop.suffix_config=%app.install.noop.root%\build_config_noop.bat"
if not exist "%app.install.noop.shared_config%" goto :_LoadConfiguration_suffix
call "%app.install.noop.shared_config%"
set "lc_rc=%errorlevel%"
if "%lc_rc%"=="0" goto :_LoadConfiguration_suffix
echo.
echo ERROR: Shared configuration failed:
echo   "%app.install.noop.shared_config%"
echo.
exit /b %lc_rc%
:_LoadConfiguration_suffix
if not exist "%app.install.noop.suffix_config%" exit /b 0
call "%app.install.noop.suffix_config%"
set "lc_rc=%errorlevel%"
if "%lc_rc%"=="0" exit /b 0
echo.
echo ERROR: No-op configuration failed:
echo   "%app.install.noop.suffix_config%"
echo.
exit /b %lc_rc%
:: ============================================================
:: :SetDefaults
:: Applies generic installer defaults after configuration loads.
::
:: Usage: call :SetDefaults
::
:: Returns: 0
:: Requires: none
:: ============================================================
:SetDefaults
if not defined app.install.noop.default_mode set "app.install.noop.default_mode=install"
if not defined app.install.noop.mode set "app.install.noop.mode=%app.install.noop.default_mode%"
if not defined app.install.noop.title set "app.install.noop.title=%app.display_name% installation template"
if not defined app.install.noop.title set "app.install.noop.title=Generic installation template"
if not defined app.install.noop.description set "app.install.noop.description=No project-specific installation operations are configured."
if not defined app.install.noop.build_dir_prefix set "app.install.noop.build_dir_prefix=build"
if not defined app.install.noop.require_source set "app.install.noop.require_source=0"
if not defined app.install.noop.auto_build set "app.install.noop.auto_build=0"
if not defined app.install.noop.confirm_install set "app.install.noop.confirm_install=0"
if not defined app.install.noop.confirm_uninstall set "app.install.noop.confirm_uninstall=1"
if not defined app.install.noop.env_file set "app.install.noop.env_file=env.bat"
if not defined app.install.noop.log_enabled set "app.install.noop.log_enabled=0"
if not defined app.install.noop.log_dir set "app.install.noop.log_dir=install_logs"
exit /b 0
:: ============================================================
:: :ParseArguments
:: Parses install mode and optional source selection.
::
:: Usage: call :ParseArguments %*
::
:: Accepted modes:
::   install, run, check, plan, uninstall, help
::
:: Source selection:
::   artifact FILE
::   file FILE
::   build FOLDER
::
:: Returns: 0 on success, 2 on invalid syntax
:: Requires: none
:: ============================================================
:ParseArguments
if "%~1"=="" exit /b 0
if /I "%~1"=="install" (set "app.install.noop.mode=install" & shift & goto :ParseArguments)
if /I "%~1"=="run" (set "app.install.noop.mode=run" & shift & goto :ParseArguments)
if /I "%~1"=="check" (set "app.install.noop.mode=check" & shift & goto :ParseArguments)
if /I "%~1"=="plan" (set "app.install.noop.mode=plan" & shift & goto :ParseArguments)
if /I "%~1"=="uninstall" (set "app.install.noop.mode=uninstall" & shift & goto :ParseArguments)
if /I "%~1"=="remove" (set "app.install.noop.mode=uninstall" & shift & goto :ParseArguments)
if /I "%~1"=="artifact" goto :_ParseArguments_artifact
if /I "%~1"=="file" goto :_ParseArguments_artifact
if /I "%~1"=="build" goto :_ParseArguments_build
if /I "%~1"=="help" (set "app.install.noop.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="--help" (set "app.install.noop.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="/help" (set "app.install.noop.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="/?" (set "app.install.noop.mode=help" & shift & goto :ParseArguments)
echo.
echo ERROR: Unknown install_noop argument:
echo   %~1
echo.
exit /b 2
:_ParseArguments_artifact
if not "%~2"=="" goto :_ParseArguments_artifact_value
echo.
echo ERROR: %~1 requires an artifact file path.
echo.
exit /b 2
:_ParseArguments_artifact_value
set "app.install.noop.request.artifact=%~2"
shift
shift
goto :ParseArguments
:_ParseArguments_build
if not "%~2"=="" goto :_ParseArguments_build_value
echo.
echo ERROR: build requires a build folder path.
echo.
exit /b 2
:_ParseArguments_build_value
set "app.install.noop.request.build=%~2"
shift
shift
goto :ParseArguments
:: ============================================================
:: :ApplyEnvironmentFile
:: Applies the configured project environment file when present.
:: This occurs inside the isolated install implementation process.
::
:: Usage: call :ApplyEnvironmentFile
::
:: Returns: env file exit code, or 0 when absent
:: Requires: optional configured environment batch file
:: ============================================================
:ApplyEnvironmentFile
set "aef_file=%app.install.noop.root%\%app.install.noop.env_file%"
if not exist "%aef_file%" exit /b 0
call "%aef_file%"
set "aef_rc=%errorlevel%"
if "%aef_rc%"=="0" exit /b 0
echo.
echo ERROR: Environment file failed:
echo   "%aef_file%"
echo.
exit /b %aef_rc%
:: ============================================================
:: :ShowHeader
:: Prints the selected project, suffix, and install mode.
::
:: Usage: call :ShowHeader
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHeader
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
echo Mode:
echo   %app.install.noop.mode%
echo.
exit /b 0
:: ============================================================
:: :ShowHelp
:: Prints installer usage, lifecycle, and customization points.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo install_noop.bat
echo.
echo Usage:
echo   install_noop.bat
echo   install_noop.bat install
echo   install_noop.bat run
echo   install_noop.bat check
echo   install_noop.bat plan
echo   install_noop.bat uninstall
echo   install_noop.bat artifact path\to\artifact
echo   install_noop.bat build build_YYYY-MM-DD.HHhmm.ss
echo   install_noop.bat help
echo.
echo Install customization:
echo   :CheckInstallPrerequisites
echo   :ResolveInstallSource
echo   :ValidateInstallSource
echo   :ResolveInstallDestination
echo   :InstallOperations
echo   :ValidateInstalledResult
echo   :RunInstalledProgram
echo   :WriteUninstallInstructions
echo   :RollbackFailedInstallation
echo.
echo Uninstall customization:
echo   :CheckUninstallPrerequisites
echo   :UninstallOperations
echo   :ValidateUninstalledResult
echo.
echo Source behavior:
echo   A requested artifact or build folder is honored first.
echo   Otherwise the newest %app.install.noop.build_dir_prefix%_* folder is selected.
echo   A configured artifact name is resolved inside that folder.
echo   Source validation is optional unless require_source=1.
echo.
echo Safe defaults:
echo   No install or uninstall confirmation is requested for the
echo   no-op operation unless enabled in configuration.
echo   No files are copied, installed, registered, removed, or run.
echo   Logging is disabled unless app.install.noop.log_enabled=1.
echo.
exit /b 0
:: ============================================================
:: :CheckOnly
:: Checks install prerequisites, source resolution, source validity,
:: and destination resolution without installing anything.
::
:: Usage: call :CheckOnly
::
:: Returns: first nonzero child result
:: Requires: install customization functions
:: ============================================================
:CheckOnly
call :CheckInstallPrerequisites
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
call :EnsureInstallSource
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
call :ResolveInstallDestination
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
echo Installation check complete.
echo.
call :ShowResolvedInstallValues
exit /b 0
:: ============================================================
:: :PlanOnly
:: Resolves and prints the install plan without confirmation,
:: logging, installation, validation, or run operations.
::
:: Usage: call :PlanOnly
::
:: Returns: first nonzero child result
:: Requires: install customization functions
:: ============================================================
:PlanOnly
call :CheckInstallPrerequisites
set "po_rc=%errorlevel%"
if not "%po_rc%"=="0" exit /b %po_rc%
call :EnsureInstallSource
set "po_rc=%errorlevel%"
if not "%po_rc%"=="0" exit /b %po_rc%
call :ResolveInstallDestination
set "po_rc=%errorlevel%"
if not "%po_rc%"=="0" exit /b %po_rc%
call :ShowInstallPlan
exit /b 0
:: ============================================================
:: :RunInstall
:: Executes the complete install lifecycle.
::
:: Usage: call :RunInstall
::
:: Returns: first nonzero child result
:: Requires: install customization functions
:: ============================================================
:RunInstall
call :CheckInstallPrerequisites
set "ri_rc=%errorlevel%"
if not "%ri_rc%"=="0" exit /b %ri_rc%
call :EnsureInstallSource
set "ri_rc=%errorlevel%"
if not "%ri_rc%"=="0" exit /b %ri_rc%
call :ResolveInstallDestination
set "ri_rc=%errorlevel%"
if not "%ri_rc%"=="0" exit /b %ri_rc%
call :ShowInstallPlan
call :ConfirmInstall
set "ri_rc=%errorlevel%"
if not "%ri_rc%"=="0" exit /b %ri_rc%
call :InitializeInstallLog
set "ri_rc=%errorlevel%"
if not "%ri_rc%"=="0" exit /b %ri_rc%
set "app.install.noop.install.started=1"
call :InstallOperations
set "ri_rc=%errorlevel%"
if not "%ri_rc%"=="0" goto :_RunInstall_rollback
call :ValidateInstalledResult
set "ri_rc=%errorlevel%"
if not "%ri_rc%"=="0" goto :_RunInstall_rollback
set "app.install.noop.install.complete=1"
call :WriteUninstallInstructions
set "ri_rc=%errorlevel%"
if not "%ri_rc%"=="0" exit /b %ri_rc%
if /I not "%app.install.noop.mode%"=="run" goto :_RunInstall_success
call :RunInstalledProgram
set "ri_rc=%errorlevel%"
if not "%ri_rc%"=="0" exit /b %ri_rc%
:_RunInstall_success
call :ReportInstallSuccess
exit /b 0
:_RunInstall_rollback
call :RollbackFailedInstallation "%ri_rc%"
set "ri_rollback_rc=%errorlevel%"
if "%ri_rollback_rc%"=="0" exit /b %ri_rc%
echo WARNING: Rollback also failed with exit code %ri_rollback_rc%.
exit /b %ri_rc%
:: ============================================================
:: :RunUninstall
:: Executes the complete uninstall lifecycle.
::
:: Usage: call :RunUninstall
::
:: Returns: first nonzero child result
:: Requires: uninstall customization functions
:: ============================================================
:RunUninstall
call :CheckUninstallPrerequisites
set "ru_rc=%errorlevel%"
if not "%ru_rc%"=="0" exit /b %ru_rc%
call :ResolveInstallDestination
set "ru_rc=%errorlevel%"
if not "%ru_rc%"=="0" exit /b %ru_rc%
call :ShowUninstallPlan
call :ConfirmUninstall
set "ru_rc=%errorlevel%"
if not "%ru_rc%"=="0" exit /b %ru_rc%
call :InitializeInstallLog
set "ru_rc=%errorlevel%"
if not "%ru_rc%"=="0" exit /b %ru_rc%
set "app.install.noop.uninstall.started=1"
call :UninstallOperations
set "ru_rc=%errorlevel%"
if not "%ru_rc%"=="0" exit /b %ru_rc%
call :ValidateUninstalledResult
set "ru_rc=%errorlevel%"
if not "%ru_rc%"=="0" exit /b %ru_rc%
set "app.install.noop.uninstall.complete=1"
call :ReportUninstallSuccess
exit /b 0
:: ============================================================
:: :CheckInstallPrerequisites
:: INSTALL CUSTOMIZATION POINT.
::
:: Verify installer-side requirements before resolving an artifact.
:: Examples include administrator rights, deployment tools, package
:: managers, adb, service managers, destination permissions, or
:: required operating-system features.
::
:: Do not install or modify anything in this function.
::
:: Usage: call :CheckInstallPrerequisites
::
:: Returns: 0 when ready, nonzero on failure
:: Requires: project-specific tools when customized
:: ============================================================
:CheckInstallPrerequisites
exit /b 0
:: ============================================================
:: :EnsureInstallSource
:: Resolves and validates the source. When validation fails and
:: auto_build=1, runs build.bat once unless an explicit source was
:: requested, then resolves and validates again.
::
:: Usage: call :EnsureInstallSource
::
:: Returns: 0 when source is acceptable, nonzero otherwise
:: Requires: :ResolveInstallSource, :ValidateInstallSource,
::           :BuildMissingInstallSource
:: ============================================================
:EnsureInstallSource
call :ResolveInstallSource
set "eis_rc=%errorlevel%"
if not "%eis_rc%"=="0" exit /b %eis_rc%
call :ValidateInstallSource
set "eis_rc=%errorlevel%"
if "%eis_rc%"=="0" exit /b 0
if not "%app.install.noop.auto_build%"=="1" exit /b %eis_rc%
if defined app.install.noop.request.artifact exit /b %eis_rc%
if defined app.install.noop.request.build exit /b %eis_rc%
call :BuildMissingInstallSource
set "eis_rc=%errorlevel%"
if not "%eis_rc%"=="0" exit /b %eis_rc%
call :ResolveInstallSource
set "eis_rc=%errorlevel%"
if not "%eis_rc%"=="0" exit /b %eis_rc%
call :ValidateInstallSource
set "eis_rc=%errorlevel%"
exit /b %eis_rc%
:: ============================================================
:: :ResolveInstallSource
:: INSTALL CUSTOMIZATION POINT.
::
:: Default behavior:
::   - honors an explicit artifact path
::   - honors an explicit build folder
::   - otherwise selects the newest build_* folder
::   - resolves app.install.noop.artifact_name inside that folder
::
:: Customize this function for package feeds, archives, installers,
:: device packages, network locations, or other artifact layouts.
::
:: Usage: call :ResolveInstallSource
::
:: Output:
::   app.install.noop.source.artifact
::   app.install.noop.source.build
::   app.install.noop.source.description
::
:: Returns: 0; validity is checked separately
:: Requires: :SelectNewestBuildFolder
:: ============================================================
:ResolveInstallSource
set "app.install.noop.source.artifact="
set "app.install.noop.source.build="
set "app.install.noop.source.description="
if defined app.install.noop.request.artifact goto :_ResolveInstallSource_artifact
if defined app.install.noop.request.build goto :_ResolveInstallSource_build
call :SelectNewestBuildFolder
goto :_ResolveInstallSource_artifact_from_build
:_ResolveInstallSource_artifact
for %%A in ("%app.install.noop.request.artifact%") do set "app.install.noop.source.artifact=%%~fA"
for %%A in ("%app.install.noop.source.artifact%") do set "app.install.noop.source.build=%%~dpA"
if defined app.install.noop.source.build if "%app.install.noop.source.build:~-1%"=="\" set "app.install.noop.source.build=%app.install.noop.source.build:~0,-1%"
set "app.install.noop.source.description=requested artifact"
exit /b 0
:_ResolveInstallSource_build
for %%A in ("%app.install.noop.request.build%") do set "app.install.noop.source.build=%%~fA"
set "app.install.noop.source.description=requested build folder"
:_ResolveInstallSource_artifact_from_build
if not defined app.install.noop.source.build exit /b 0
if not defined app.install.noop.artifact_name exit /b 0
for %%A in ("%app.install.noop.source.build%\%app.install.noop.artifact_name%") do set "app.install.noop.source.artifact=%%~fA"
exit /b 0
:: ============================================================
:: :SelectNewestBuildFolder
:: Selects the newest alphabetically sorted build_* folder.
:: Timestamped build folder names sort newest first with /o-n.
::
:: Usage: call :SelectNewestBuildFolder
::
:: Output:
::   app.install.noop.source.build
::   app.install.noop.source.description
::
:: Returns: 0
:: Requires: dir
:: ============================================================
:SelectNewestBuildFolder
for /f "delims=" %%D in ('dir /b /ad /o-n "%app.install.noop.root%\%app.install.noop.build_dir_prefix%_*" 2^>nul') do call :UseBuildFolderIfUnset "%%D"
exit /b 0
:: ============================================================
:: :UseBuildFolderIfUnset
:: Records the first build folder supplied by SelectNewestBuildFolder.
::
:: Usage: call :UseBuildFolderIfUnset "folder name"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:UseBuildFolderIfUnset
if defined app.install.noop.source.build exit /b 0
for %%A in ("%app.install.noop.root%\%~1") do set "app.install.noop.source.build=%%~fA"
set "app.install.noop.source.description=newest dated build folder"
exit /b 0
:: ============================================================
:: :ValidateInstallSource
:: INSTALL CUSTOMIZATION POINT.
::
:: Default validation enforces explicit requests and configured
:: source requirements. Projects should add artifact-specific checks
:: such as file type, signature, checksum, manifest, architecture,
:: version, or completeness.
::
:: Usage: call :ValidateInstallSource
::
:: Returns: 0 when acceptable, 1 when source is missing
:: Requires: none
:: ============================================================
:ValidateInstallSource
if defined app.install.noop.request.artifact if not exist "%app.install.noop.source.artifact%" goto :_ValidateInstallSource_missing_artifact
if defined app.install.noop.request.build if not exist "%app.install.noop.source.build%\" goto :_ValidateInstallSource_missing_build
if "%app.install.noop.require_source%"=="1" if not defined app.install.noop.source.build if not defined app.install.noop.source.artifact goto :_ValidateInstallSource_required
if defined app.install.noop.artifact_name if defined app.install.noop.source.build if not exist "%app.install.noop.source.artifact%" goto :_ValidateInstallSource_missing_named
exit /b 0
:_ValidateInstallSource_missing_artifact
echo ERROR: Requested install artifact was not found:
echo   "%app.install.noop.source.artifact%"
echo.
exit /b 1
:_ValidateInstallSource_missing_build
echo ERROR: Requested build folder was not found:
echo   "%app.install.noop.source.build%"
echo.
exit /b 1
:_ValidateInstallSource_required
echo ERROR: An install source is required, but none was found.
echo.
exit /b 1
:_ValidateInstallSource_missing_named
echo ERROR: Expected install artifact was not found:
echo   "%app.install.noop.source.artifact%"
echo.
exit /b 1
:: ============================================================
:: :BuildMissingInstallSource
:: INSTALL CUSTOMIZATION POINT.
::
:: Default behavior calls root build.bat when auto_build=1 and a
:: required implicit source is missing. Customize arguments when the
:: project needs a particular build target or mode.
::
:: Usage: call :BuildMissingInstallSource
::
:: Returns: 0 when build succeeds, nonzero otherwise
:: Requires: build.bat
:: ============================================================
:BuildMissingInstallSource
if exist "%app.install.noop.root%\build.bat" goto :_BuildMissingInstallSource_run
echo ERROR: Install source is missing and build.bat was not found.
echo.
exit /b 1
:_BuildMissingInstallSource_run
echo Running build.bat because a required install source is missing.
echo.
call "%app.install.noop.root%\build.bat"
set "bmis_rc=%errorlevel%"
if not "%bmis_rc%"=="0" exit /b %bmis_rc%
set "app.install.noop.build.ran=1"
exit /b 0
:: ============================================================
:: :ResolveInstallDestination
:: INSTALL CUSTOMIZATION POINT.
::
:: Resolve the final installation destination here. The default
:: leaves the destination unconfigured because this template performs
:: no real deployment.
::
:: Usage: call :ResolveInstallDestination
::
:: Output:
::   app.install.noop.destination
::
:: Returns: 0 when destination is acceptable, nonzero on failure
:: Requires: project-specific destination logic when customized
:: ============================================================
:ResolveInstallDestination
:: Example:
:: if not defined app.install.noop.destination set "app.install.noop.destination=%LocalAppData%\Programs\MyApp"
exit /b 0
:: ============================================================
:: :ShowResolvedInstallValues
:: Prints source and destination values resolved by the template.
::
:: Usage: call :ShowResolvedInstallValues
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowResolvedInstallValues
echo Install source:
if defined app.install.noop.source.build echo   Build folder: %app.install.noop.source.build%
if not defined app.install.noop.source.build echo   Build folder: not selected
if defined app.install.noop.source.artifact echo   Artifact: %app.install.noop.source.artifact%
if not defined app.install.noop.source.artifact echo   Artifact: not selected
if defined app.install.noop.source.description echo   Selection: %app.install.noop.source.description%
echo.
echo Destination:
if defined app.install.noop.destination echo   %app.install.noop.destination%
if not defined app.install.noop.destination echo   not configured
echo.
exit /b 0
:: ============================================================
:: :ShowInstallPlan
:: Prints the complete installation plan before confirmation.
::
:: Usage: call :ShowInstallPlan
::
:: Returns: 0
:: Requires: :ShowResolvedInstallValues
:: ============================================================
:ShowInstallPlan
echo ============================================================
echo  Installation plan
echo ============================================================
echo.
call :ShowResolvedInstallValues
echo Operations:
echo   1. Validate installer prerequisites.
echo   2. Validate the selected install source.
echo   3. Deploy project files in :InstallOperations.
echo   4. Validate the installed result.
echo   5. Write uninstall or rollback guidance.
if /I "%app.install.noop.mode%"=="run" echo   6. Run the installed program.
echo.
echo Current template action:
echo   no files will be copied, installed, registered, or changed
echo.
exit /b 0
:: ============================================================
:: :ConfirmInstall
:: Optionally requests explicit INSTALL confirmation.
:: Confirmation is disabled by default for the harmless no-op.
::
:: Usage: call :ConfirmInstall
::
:: Returns: 0 when confirmed or disabled, 130 when cancelled
:: Requires: set /p when enabled
:: ============================================================
:ConfirmInstall
if not "%app.install.noop.confirm_install%"=="1" exit /b 0
set "app.install.noop.confirm.answer="
set /p "app.install.noop.confirm.answer=Type INSTALL to continue: "
if "%app.install.noop.confirm.answer%"=="INSTALL" exit /b 0
echo.
echo Installation cancelled before changes were made.
echo.
exit /b 130
:: ============================================================
:: :InitializeInstallLog
:: Creates an optional timestamped log. Logging is disabled by
:: default so the no-op template does not create files.
::
:: Usage: call :InitializeInstallLog
::
:: Output:
::   app.install.noop.timestamp
::   app.install.noop.log
::
:: Returns: 0 when disabled or ready, 1 on setup failure
:: Requires: PowerShell only when logging is enabled
:: ============================================================
:InitializeInstallLog
if not "%app.install.noop.log_enabled%"=="1" exit /b 0
where powershell.exe >nul 2>nul
if not errorlevel 1 goto :_InitializeInstallLog_timestamp
echo ERROR: PowerShell is required when install logging is enabled.
exit /b 1
:_InitializeInstallLog_timestamp
set "app.install.noop.timestamp="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Date).ToString('yyyy-MM-dd.HH''h''mm.ss')"`) do if not defined app.install.noop.timestamp set "app.install.noop.timestamp=%%A"
if defined app.install.noop.timestamp goto :_InitializeInstallLog_folder
echo ERROR: Could not create the install timestamp.
exit /b 1
:_InitializeInstallLog_folder
if not exist "%app.install.noop.root%\%app.install.noop.log_dir%\" mkdir "%app.install.noop.root%\%app.install.noop.log_dir%" >nul 2>nul
if exist "%app.install.noop.root%\%app.install.noop.log_dir%\" goto :_InitializeInstallLog_file
echo ERROR: Could not create install log directory:
echo   "%app.install.noop.root%\%app.install.noop.log_dir%"
exit /b 1
:_InitializeInstallLog_file
set "app.install.noop.log=%app.install.noop.root%\%app.install.noop.log_dir%\%app.install.noop.mode%.%app.install.noop.timestamp%.log"
>"%app.install.noop.log%" echo %app.install.noop.title%
>>"%app.install.noop.log%" echo Mode: %app.install.noop.mode%
>>"%app.install.noop.log%" echo Root: %app.install.noop.root%
>>"%app.install.noop.log%" echo Source build: %app.install.noop.source.build%
>>"%app.install.noop.log%" echo Source artifact: %app.install.noop.source.artifact%
>>"%app.install.noop.log%" echo Destination: %app.install.noop.destination%
if exist "%app.install.noop.log%" exit /b 0
echo ERROR: Could not create install log:
echo   "%app.install.noop.log%"
exit /b 1
:: ============================================================
:: :InstallOperations
:: INSTALL CUSTOMIZATION POINT.
::
:: Put actual copy, deployment, registration, package installation,
:: shortcut creation, service setup, or device installation commands
:: here. Use the resolved values:
::   app.install.noop.source.build
::   app.install.noop.source.artifact
::   app.install.noop.destination
::
:: Record enough state for :RollbackFailedInstallation to undo a
:: partially completed operation.
::
:: Usage: call :InstallOperations
::
:: Returns: 0 when installation succeeds, nonzero on failure
:: Requires: project-specific tools when customized
:: ============================================================
:InstallOperations
echo Installation operations:
echo   No project-specific installation operations are configured.
echo.
call :WriteInstallLog "No project-specific installation operations are configured."
exit /b 0
:: ============================================================
:: :ValidateInstalledResult
:: INSTALL CUSTOMIZATION POINT.
::
:: Verify the deployed files, registrations, package state, service,
:: shortcut, application version, device package, or launch target.
::
:: Usage: call :ValidateInstalledResult
::
:: Returns: 0 when installed result is valid, nonzero otherwise
:: Requires: project-specific installed output when customized
:: ============================================================
:ValidateInstalledResult
exit /b 0
:: ============================================================
:: :WriteUninstallInstructions
:: INSTALL CUSTOMIZATION POINT.
::
:: Optionally create or print uninstall/rollback guidance after a
:: successful installation. Keep generated guidance outside source
:: control unless it is intended to be committed.
::
:: Usage: call :WriteUninstallInstructions
::
:: Returns: 0 on success, nonzero on failure
:: Requires: project-specific guidance when customized
:: ============================================================
:WriteUninstallInstructions
exit /b 0
:: ============================================================
:: :RunInstalledProgram
:: INSTALL CUSTOMIZATION POINT.
::
:: Start the installed program after successful validation when mode
:: is "run". The default no-op does not launch anything.
::
:: Usage: call :RunInstalledProgram
::
:: Returns: 0 when launched or intentionally skipped
::          nonzero when launch was requested but failed
:: Requires: project-specific executable or launch command
:: ============================================================
:RunInstalledProgram
echo Run requested:
echo   No installed program launch command is configured.
echo.
exit /b 0
:: ============================================================
:: :RollbackFailedInstallation
:: INSTALL CUSTOMIZATION POINT.
::
:: Undo a partial installation after :InstallOperations or
:: :ValidateInstalledResult fails. The original failure code is %~1.
:: Rollback should not overwrite or delete pre-existing user data.
::
:: Usage: call :RollbackFailedInstallation failureCode
::
:: Returns: 0 when rollback succeeds or nothing must be undone
::          nonzero when rollback itself fails
:: Requires: project-specific rollback state when customized
:: ============================================================
:RollbackFailedInstallation
if not defined app.install.noop.install.started exit /b 0
if defined app.install.noop.install.complete exit /b 0
echo Installation failed with exit code %~1.
echo No rollback operations are configured.
echo.
call :WriteInstallLog "Installation failed; no rollback operations are configured."
exit /b 0
:: ============================================================
:: :ReportInstallSuccess
:: Prints the completed install summary.
::
:: Usage: call :ReportInstallSuccess
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ReportInstallSuccess
echo ============================================================
echo  Installation complete
echo ============================================================
echo.
call :ShowResolvedInstallValues
echo %app.install.noop.description%
echo No files were copied, installed, registered, or changed by the
echo default :InstallOperations implementation.
if defined app.install.noop.log echo.
if defined app.install.noop.log echo Log:
if defined app.install.noop.log echo   %app.install.noop.log%
echo.
call :WriteInstallLog "Installation lifecycle completed successfully."
exit /b 0
:: ============================================================
:: :CheckUninstallPrerequisites
:: UNINSTALL CUSTOMIZATION POINT.
::
:: Verify that uninstall tools, permissions, registration state, and
:: destination information are available before removal.
::
:: Usage: call :CheckUninstallPrerequisites
::
:: Returns: 0 when ready, nonzero on failure
:: Requires: project-specific uninstall tools when customized
:: ============================================================
:CheckUninstallPrerequisites
exit /b 0
:: ============================================================
:: :ShowUninstallPlan
:: Prints the uninstall plan before optional confirmation.
::
:: Usage: call :ShowUninstallPlan
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowUninstallPlan
echo ============================================================
echo  Uninstall plan
echo ============================================================
echo.
echo Destination:
if defined app.install.noop.destination echo   %app.install.noop.destination%
if not defined app.install.noop.destination echo   not configured
echo.
echo Operations:
echo   1. Remove project-specific installed files or registrations.
echo   2. Preserve user data unless explicitly configured otherwise.
echo   3. Validate that the installed result was removed.
echo.
echo Current template action:
echo   no files, registrations, services, or user data will be removed
echo.
exit /b 0
:: ============================================================
:: :ConfirmUninstall
:: Optionally requests explicit UNINSTALL confirmation.
:: Confirmation defaults to enabled because real removal is higher
:: risk than installation.
::
:: Usage: call :ConfirmUninstall
::
:: Returns: 0 when confirmed or disabled, 130 when cancelled
:: Requires: set /p when enabled
:: ============================================================
:ConfirmUninstall
if not "%app.install.noop.confirm_uninstall%"=="1" exit /b 0
set "app.install.noop.confirm.answer="
set /p "app.install.noop.confirm.answer=Type UNINSTALL to continue: "
if "%app.install.noop.confirm.answer%"=="UNINSTALL" exit /b 0
echo.
echo Uninstall cancelled before changes were made.
echo.
exit /b 130
:: ============================================================
:: :UninstallOperations
:: UNINSTALL CUSTOMIZATION POINT.
::
:: Remove only project-owned deployed files, registrations, services,
:: shortcuts, packages, or device applications. Preserve user data
:: unless the project clearly documents and confirms its removal.
::
:: Usage: call :UninstallOperations
::
:: Returns: 0 when uninstall succeeds, nonzero on failure
:: Requires: project-specific installed state when customized
:: ============================================================
:UninstallOperations
echo Uninstall operations:
echo   No project-specific uninstall operations are configured.
echo.
call :WriteInstallLog "No project-specific uninstall operations are configured."
exit /b 0
:: ============================================================
:: :ValidateUninstalledResult
:: UNINSTALL CUSTOMIZATION POINT.
::
:: Verify that project-owned installed output was removed while
:: required user data remains intact.
::
:: Usage: call :ValidateUninstalledResult
::
:: Returns: 0 when uninstall result is valid, nonzero otherwise
:: Requires: project-specific installed state when customized
:: ============================================================
:ValidateUninstalledResult
exit /b 0
:: ============================================================
:: :ReportUninstallSuccess
:: Prints the completed uninstall summary.
::
:: Usage: call :ReportUninstallSuccess
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ReportUninstallSuccess
echo ============================================================
echo  Uninstall complete
echo ============================================================
echo.
echo %app.install.noop.description%
echo No files, registrations, services, or user data were removed by
echo the default :UninstallOperations implementation.
if defined app.install.noop.log echo.
if defined app.install.noop.log echo Log:
if defined app.install.noop.log echo   %app.install.noop.log%
echo.
call :WriteInstallLog "Uninstall lifecycle completed successfully."
exit /b 0
:: ============================================================
:: :WriteInstallLog
:: Appends a plain-text line when optional logging is active.
::
:: Usage: call :WriteInstallLog "message"
::
:: Returns: 0
:: Requires: optional initialized app.install.noop.log
:: ============================================================
:WriteInstallLog
if defined app.install.noop.log if exist "%app.install.noop.log%" >>"%app.install.noop.log%" echo %~1
exit /b 0
