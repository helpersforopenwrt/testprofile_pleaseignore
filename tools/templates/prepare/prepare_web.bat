@echo off
:: ============================================================
:: prepare_web.bat
:: Generic preparation for framework-free website projects.
::
:: Intended projects:
::   - plain HTML, CSS, and JavaScript websites
::   - small PHP websites
::   - websites built by build_web.bat
::   - websites deployed by install_web.bat
::
:: This preparer locates and exposes tools that already exist. It does
:: not download software, install software, map network drives, prompt
:: for credentials, or call bootstrap.bat.
::
:: Preparation areas:
::   repository
::     Detects source control and repository provider.
::     Resolves Git for Git repositories.
::     Resolves GitHub CLI for GitHub repositories.
::
::   build
::     Resolves PowerShell.
::     Checks the configured or detected website entry file.
::     Resolves PHP according to app.web.php_lint.
::
::   deployment
::     Resolves Robocopy for folder deployment.
::     Checks a configured local, mapped-drive, or UNC destination.
::     Resolves configured custom deployment and verification scripts.
::     Checks common commands for scp, sftp, or rsync methods.
::
::   project
::     Runs documented customization points for framework-specific,
::     generated, local-server, credential-helper, or environment work.
::
:: Configuration order:
::   1. build_config.bat
::   2. build_config_web.bat when present
::
:: Primary configuration:
::   app.web.prepare.default_request=all
::   app.web.prepare.env_file=env.bat
::   app.web.prepare.check_destination=1
::   app.web.prepare.external_commands=
::   app.web.prepare.php_exe=
::   app.web.prepare.powershell_exe=
::   app.web.prepare.robocopy_exe=
::
:: Project customization points:
::   :CheckWebProjectReady
::   :PrepareWebProjectOperations
::   :ValidateWebProjectPreparation
::   :ApplyWebEnvironment
::   :WriteWebEnvironmentFile
::
:: Repository extension points:
::   :ResolveCustomSourceControlClient
::   :ResolveCustomRepositoryProviderClient
::
:: Active placement:
::   prepare_web.bat at the project root
::
:: Template storage:
::   tools\templates\prepare\prepare_web.bat
::
:: Usage:
::   call prepare_web.bat
::   call prepare_web.bat all
::   call prepare_web.bat repository
::   call prepare_web.bat build
::   call prepare_web.bat deployment
::   call prepare_web.bat install
::   call prepare_web.bat php
::   call prepare_web.bat project
::   call prepare_web.bat check
::   call prepare_web.bat force
::   call prepare_web.bat help
::
:: Returns: 0 when requested preparation is ready
::          1 when a required tool, file, destination, or script is missing
::          2 on invalid arguments or invalid configuration
::          config/custom operation exit code on failure
:: Requires: where.exe
:: ============================================================
:setup
set "app.prepare.web.rc=0"
set "app.prepare.web.root="
set "app.prepare.web.shared_config="
set "app.prepare.web.suffix_config="
set "app.prepare.web.request="
set "app.prepare.web.force="
set "app.prepare.web.check_only="
set "app.prepare.web.repository.url="
set "app.prepare.web.scm="
set "app.prepare.web.provider="
set "app.prepare.web.entry_file="
set "app.prepare.web.method_script="
set "app.prepare.web.verify_script="
set "app.prepare.web.destination.status="
set "app.prepare.web.custom.ready="
set "app.prepare.web.custom.check.rc=0"
set "app.web.git.exe="
set "app.web.github.cli="
set "app.web.powershell.exe="
set "app.web.php.exe="
set "app.web.robocopy.exe="
set "app.web.ssh.exe="
set "app.web.scp.exe="
set "app.web.sftp.exe="
set "app.web.rsync.exe="
set "app.prepare.suffix=web"
if not defined PREPARE_SUFFIX set "PREPARE_SUFFIX=web"
if defined PREPARE_PROJECT_ROOT set "app.prepare.web.root=%PREPARE_PROJECT_ROOT%"
if not defined app.prepare.web.root for %%A in ("%~dp0.") do set "app.prepare.web.root=%%~fA"
for %%A in ("%app.prepare.web.root%\.") do set "app.prepare.web.root=%%~fA"
:main
call :LoadConfiguration
set "app.prepare.web.rc=%errorlevel%"
if not "%app.prepare.web.rc%"=="0" goto :end
call :SetDefaults
call :ParseArguments %*
set "app.prepare.web.rc=%errorlevel%"
if not "%app.prepare.web.rc%"=="0" goto :end
if /I "%app.prepare.web.request%"=="help" call :ShowHelp
if /I "%app.prepare.web.request%"=="help" set "app.prepare.web.rc=%errorlevel%"
if /I "%app.prepare.web.request%"=="help" goto :end
cd /d "%app.prepare.web.root%"
set "app.prepare.web.rc=%errorlevel%"
if "%app.prepare.web.rc%"=="0" goto :_main_environment
echo.
echo ERROR: Could not enter the project root:
echo   "%app.prepare.web.root%"
echo.
set "app.prepare.web.rc=1"
goto :end
:_main_environment
call :ApplyConfiguredEnvironmentFile
set "app.prepare.web.rc=%errorlevel%"
if not "%app.prepare.web.rc%"=="0" goto :end
call :ShowHeader
call :DispatchPreparation
set "app.prepare.web.rc=%errorlevel%"
if not "%app.prepare.web.rc%"=="0" goto :end
call :ApplyWebEnvironment
set "app.prepare.web.rc=%errorlevel%"
if not "%app.prepare.web.rc%"=="0" goto :end
if defined app.prepare.web.check_only goto :_main_summary
call :WriteWebEnvironmentFile
set "app.prepare.web.rc=%errorlevel%"
if not "%app.prepare.web.rc%"=="0" goto :end
:_main_summary
call :ShowSummary
set "app.prepare.web.rc=%errorlevel%"
:end
exit /b %app.prepare.web.rc%
:: ============================================================
:: :LoadConfiguration
:: Loads build_config.bat and then optional build_config_web.bat.
::
:: Usage: call :LoadConfiguration
::
:: Returns: 0 when configuration succeeds
::          1 when shared configuration is missing
::          config exit code when a config fails
:: Requires: build_config.bat
:: ============================================================
:LoadConfiguration
set "app.prepare.web.shared_config=%app.prepare.web.root%\build_config.bat"
set "app.prepare.web.suffix_config=%app.prepare.web.root%\build_config_web.bat"
if exist "%app.prepare.web.shared_config%" goto :_LoadConfiguration_shared
echo.
echo ERROR: Shared build configuration was not found:
echo   "%app.prepare.web.shared_config%"
echo.
exit /b 1
:_LoadConfiguration_shared
call "%app.prepare.web.shared_config%"
set "lc_rc=%errorlevel%"
if "%lc_rc%"=="0" goto :_LoadConfiguration_suffix
echo.
echo ERROR: Shared build configuration failed:
echo   "%app.prepare.web.shared_config%"
echo.
exit /b %lc_rc%
:_LoadConfiguration_suffix
if not exist "%app.prepare.web.suffix_config%" exit /b 0
call "%app.prepare.web.suffix_config%"
set "lc_rc=%errorlevel%"
if "%lc_rc%"=="0" exit /b 0
echo.
echo ERROR: Web configuration failed:
echo   "%app.prepare.web.suffix_config%"
echo.
exit /b %lc_rc%
:: ============================================================
:: :SetDefaults
:: Applies generic web preparation defaults after configuration.
::
:: Usage: call :SetDefaults
::
:: Returns: 0
:: Requires: none
:: ============================================================
:SetDefaults
if not defined app.web.prepare.default_request set "app.web.prepare.default_request=all"
if not defined app.prepare.web.request set "app.prepare.web.request=%app.web.prepare.default_request%"
if not defined app.web.prepare.title set "app.web.prepare.title=%app.display_name% website preparation"
if not defined app.web.prepare.title set "app.web.prepare.title=Website preparation"
if not defined app.web.prepare.description set "app.web.prepare.description=Framework-free website tools are ready."
if not defined app.web.prepare.env_file set "app.web.prepare.env_file=%app.web.install.env_file%"
if not defined app.web.prepare.env_file set "app.web.prepare.env_file=env.bat"
if not defined app.web.prepare.check_destination set "app.web.prepare.check_destination=1"
if not defined app.web.prepare.external_commands set "app.web.prepare.external_commands="
if not defined app.web.prepare.tools_dir set "app.web.prepare.tools_dir=%app.tools_dir%"
if not defined app.web.prepare.tools_dir set "app.web.prepare.tools_dir=tools"
if not defined app.web.php_lint set "app.web.php_lint=auto"
if not defined app.web.install.method set "app.web.install.method=folder"
if not defined app.web.install.create_destination set "app.web.install.create_destination=1"
if not defined app.web.install.method_script set "app.web.install.method_script="
if not defined app.web.install.verify_script set "app.web.install.verify_script="
if not defined app.web.install.destination set "app.web.install.destination="
if not defined app.web.require_entry set "app.web.require_entry=1"
exit /b 0
:: ============================================================
:: :ParseArguments
:: Parses one preparation request and optional force/check flags.
::
:: Usage: call :ParseArguments %*
::
:: Accepted requests:
::   all, repository, build, deployment, install, php, project,
::   check, force, help
::
:: Returns: 0 on success, 2 on invalid syntax
:: Requires: none
:: ============================================================
:ParseArguments
if "%~1"=="" exit /b 0
if /I "%~1"=="all" (set "app.prepare.web.request=all" & shift & goto :ParseArguments)
if /I "%~1"=="repository" (set "app.prepare.web.request=repository" & shift & goto :ParseArguments)
if /I "%~1"=="git" (set "app.prepare.web.request=repository" & shift & goto :ParseArguments)
if /I "%~1"=="github" (set "app.prepare.web.request=repository" & shift & goto :ParseArguments)
if /I "%~1"=="build" (set "app.prepare.web.request=build" & shift & goto :ParseArguments)
if /I "%~1"=="deployment" (set "app.prepare.web.request=deployment" & shift & goto :ParseArguments)
if /I "%~1"=="install" (set "app.prepare.web.request=deployment" & shift & goto :ParseArguments)
if /I "%~1"=="php" (set "app.prepare.web.request=php" & shift & goto :ParseArguments)
if /I "%~1"=="project" (set "app.prepare.web.request=project" & shift & goto :ParseArguments)
if /I "%~1"=="check" (set "app.prepare.web.request=all" & set "app.prepare.web.check_only=1" & shift & goto :ParseArguments)
if /I "%~1"=="force" (set "app.prepare.web.request=all" & set "app.prepare.web.force=1" & shift & goto :ParseArguments)
if /I "%~1"=="help" (set "app.prepare.web.request=help" & shift & goto :ParseArguments)
if /I "%~1"=="--help" (set "app.prepare.web.request=help" & shift & goto :ParseArguments)
if /I "%~1"=="/help" (set "app.prepare.web.request=help" & shift & goto :ParseArguments)
if /I "%~1"=="/?" (set "app.prepare.web.request=help" & shift & goto :ParseArguments)
echo.
echo ERROR: Unknown prepare_web argument:
echo   %~1
echo.
exit /b 2
:: ============================================================
:: :ApplyConfiguredEnvironmentFile
:: Applies the optional configured environment batch file first.
::
:: Usage: call :ApplyConfiguredEnvironmentFile
::
:: Returns: environment file result, or 0 when absent
:: Requires: optional env.bat
:: ============================================================
:ApplyConfiguredEnvironmentFile
set "acef_file=%app.web.prepare.env_file%"
if not defined acef_file exit /b 0
if exist "%acef_file%" goto :_ApplyConfiguredEnvironmentFile_call
if exist "%app.prepare.web.root%\%acef_file%" set "acef_file=%app.prepare.web.root%\%acef_file%"
if not exist "%acef_file%" exit /b 0
:_ApplyConfiguredEnvironmentFile_call
call "%acef_file%"
set "acef_rc=%errorlevel%"
if "%acef_rc%"=="0" exit /b 0
echo.
echo ERROR: Environment file failed:
echo   "%acef_file%"
echo.
exit /b %acef_rc%
:: ============================================================
:: :ShowHeader
:: Prints the requested preparation area.
::
:: Usage: call :ShowHeader
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHeader
echo.
echo ============================================================
echo  %app.web.prepare.title%
echo ============================================================
echo.
echo Project root:
echo   %app.prepare.web.root%
echo.
echo Suffix:
echo   web
echo.
echo Request:
echo   %app.prepare.web.request%
if defined app.prepare.web.force echo.
if defined app.prepare.web.force echo Forced project preparation:
if defined app.prepare.web.force echo   enabled
if defined app.prepare.web.check_only echo.
if defined app.prepare.web.check_only echo Check-only mode:
if defined app.prepare.web.check_only echo   enabled
echo.
exit /b 0
:: ============================================================
:: :ShowHelp
:: Prints preparation requests, policies, and customization points.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo prepare_web.bat
echo.
echo Usage:
echo   prepare_web.bat
echo   prepare_web.bat all
echo   prepare_web.bat repository
echo   prepare_web.bat build
echo   prepare_web.bat deployment
echo   prepare_web.bat install
echo   prepare_web.bat php
echo   prepare_web.bat project
echo   prepare_web.bat check
echo   prepare_web.bat force
echo   prepare_web.bat help
echo.
echo Repository preparation:
echo   Resolves Git and GitHub CLI only when repository detection
echo   requires them.
echo.
echo Build preparation:
echo   Requires PowerShell.
echo   Checks the website entry file.
echo   Applies app.web.php_lint=auto, required, or off.
echo.
echo Deployment preparation:
echo   folder requires Robocopy.
echo   scp requires scp.exe and ssh.exe.
echo   sftp requires sftp.exe and ssh.exe.
echo   rsync requires rsync.exe and normally ssh.exe.
echo   custom methods require app.web.install.method_script.
echo.
echo Destination checking:
echo   app.web.prepare.check_destination=%app.web.prepare.check_destination%
echo   No destination is created or modified by prepare_web.bat.
echo.
echo Custom project lifecycle:
echo   :CheckWebProjectReady
echo   :PrepareWebProjectOperations
echo   :ValidateWebProjectPreparation
echo   :ApplyWebEnvironment
echo   :WriteWebEnvironmentFile
echo.
echo No software is downloaded or installed automatically.
echo bootstrap.bat is never called.
echo.
exit /b 0
:: ============================================================
:: :DispatchPreparation
:: Runs the preparation workflow selected by app.prepare.web.request.
::
:: Usage: call :DispatchPreparation
::
:: Returns: first nonzero child result
:: Requires: preparation functions below
:: ============================================================
:DispatchPreparation
if /I "%app.prepare.web.request%"=="repository" call :PrepareRepository
if /I "%app.prepare.web.request%"=="repository" exit /b %errorlevel%
if /I "%app.prepare.web.request%"=="build" call :PrepareBuildTools
if /I "%app.prepare.web.request%"=="build" exit /b %errorlevel%
if /I "%app.prepare.web.request%"=="deployment" call :PrepareDeploymentTools
if /I "%app.prepare.web.request%"=="deployment" exit /b %errorlevel%
if /I "%app.prepare.web.request%"=="php" call :PreparePhp
if /I "%app.prepare.web.request%"=="php" exit /b %errorlevel%
if /I "%app.prepare.web.request%"=="project" call :RunWebProjectPreparation
if /I "%app.prepare.web.request%"=="project" exit /b %errorlevel%
if /I not "%app.prepare.web.request%"=="all" exit /b 2
call :PrepareRepository
set "dp_rc=%errorlevel%"
if not "%dp_rc%"=="0" exit /b %dp_rc%
call :PrepareBuildTools
set "dp_rc=%errorlevel%"
if not "%dp_rc%"=="0" exit /b %dp_rc%
call :PrepareDeploymentTools
set "dp_rc=%errorlevel%"
if not "%dp_rc%"=="0" exit /b %dp_rc%
call :RunWebProjectPreparation
set "dp_rc=%errorlevel%"
exit /b %dp_rc%
:: ============================================================
:: :PrepareRepository
:: Detects repository technology and resolves required clients.
::
:: Usage: call :PrepareRepository
::
:: Returns: 0 when ready, 1 when a required client is missing
:: Requires: :DetectRepository, :ResolveGit, :ResolveGitHubCli
:: ============================================================
:PrepareRepository
call :DetectRepository
set "pr_rc=%errorlevel%"
if not "%pr_rc%"=="0" exit /b %pr_rc%
if /I "%app.prepare.web.scm%"=="none" exit /b 0
if /I "%app.prepare.web.scm%"=="git" goto :_PrepareRepository_git
call :ResolveCustomSourceControlClient
set "pr_rc=%errorlevel%"
if not "%pr_rc%"=="0" exit /b %pr_rc%
goto :_PrepareRepository_provider
:_PrepareRepository_git
call :ResolveGit
set "pr_rc=%errorlevel%"
if "%pr_rc%"=="0" goto :_PrepareRepository_provider
echo ERROR: Git is required for this repository but was not found.
echo Expected PATH or bundled location:
echo   "%app.prepare.web.root%\%app.web.prepare.tools_dir%\git\cmd\git.exe"
exit /b 1
:_PrepareRepository_provider
if /I "%app.prepare.web.provider%"=="none" exit /b 0
if /I "%app.prepare.web.provider%"=="generic" exit /b 0
if /I "%app.prepare.web.provider%"=="github" goto :_PrepareRepository_github
call :ResolveCustomRepositoryProviderClient
set "pr_rc=%errorlevel%"
exit /b %pr_rc%
:_PrepareRepository_github
call :ResolveGitHubCli
set "pr_rc=%errorlevel%"
if "%pr_rc%"=="0" exit /b 0
echo ERROR: GitHub CLI is required for this GitHub repository but was not found.
echo Expected PATH or bundled location:
echo   "%app.prepare.web.root%\%app.web.prepare.tools_dir%\gh\bin\gh.exe"
exit /b 1
:: ============================================================
:: :DetectRepository
:: Determines source control, provider, and repository URL.
::
:: Detection order:
::   explicit app.repository.* settings
::   Git origin URL when Git is available
::   app.repo_url
::   .git project metadata
::
:: Usage: call :DetectRepository
::
:: Output:
::   app.prepare.web.scm
::   app.prepare.web.provider
::   app.prepare.web.repository.url
::
:: Returns: 0
:: Requires: optional git.exe, findstr.exe
:: ============================================================
:DetectRepository
set "app.prepare.web.repository.url="
set "app.prepare.web.scm="
set "app.prepare.web.provider="
if defined app.repository.scm set "app.prepare.web.scm=%app.repository.scm%"
if not defined app.prepare.web.scm if defined app.scm set "app.prepare.web.scm=%app.scm%"
if defined app.repository.provider set "app.prepare.web.provider=%app.repository.provider%"
if not defined app.prepare.web.provider if defined app.repo_provider set "app.prepare.web.provider=%app.repo_provider%"
if defined app.repository.url set "app.prepare.web.repository.url=%app.repository.url%"
if not defined app.prepare.web.repository.url if defined app.repo_url set "app.prepare.web.repository.url=%app.repo_url%"
where git.exe >nul 2>nul
if errorlevel 1 goto :_DetectRepository_metadata
set "dr_origin="
for /f "usebackq delims=" %%U in (`git.exe remote get-url origin 2^>nul`) do if not defined dr_origin set "dr_origin=%%U"
if defined dr_origin set "app.prepare.web.repository.url=%dr_origin%"
:_DetectRepository_metadata
if not defined app.prepare.web.scm if exist "%app.prepare.web.root%\.git\" set "app.prepare.web.scm=git"
if not defined app.prepare.web.scm if defined app.prepare.web.repository.url set "app.prepare.web.scm=git"
if not defined app.prepare.web.scm set "app.prepare.web.scm=none"
if defined app.prepare.web.provider goto :_DetectRepository_export
if not defined app.prepare.web.repository.url goto :_DetectRepository_generic
echo(%app.prepare.web.repository.url%| findstr /I /C:"github.com" >nul
if not errorlevel 1 (set "app.prepare.web.provider=github" & goto :_DetectRepository_export)
echo(%app.prepare.web.repository.url%| findstr /I /C:"gitlab.com" >nul
if not errorlevel 1 (set "app.prepare.web.provider=gitlab" & goto :_DetectRepository_export)
echo(%app.prepare.web.repository.url%| findstr /I /C:"bitbucket.org" >nul
if not errorlevel 1 (set "app.prepare.web.provider=bitbucket" & goto :_DetectRepository_export)
echo(%app.prepare.web.repository.url%| findstr /I /C:"codeberg.org" >nul
if not errorlevel 1 (set "app.prepare.web.provider=codeberg" & goto :_DetectRepository_export)
:_DetectRepository_generic
if /I "%app.prepare.web.scm%"=="none" (set "app.prepare.web.provider=none" & goto :_DetectRepository_export)
set "app.prepare.web.provider=generic"
:_DetectRepository_export
set "app.repository.scm=%app.prepare.web.scm%"
set "app.repository.provider=%app.prepare.web.provider%"
if defined app.prepare.web.repository.url set "app.repository.url=%app.prepare.web.repository.url%"
exit /b 0
:: ============================================================
:: :PrepareBuildTools
:: Resolves PowerShell, checks website layout, and applies PHP policy.
::
:: Usage: call :PrepareBuildTools
::
:: Returns: first nonzero child result
:: Requires: :ResolvePowerShell, :CheckWebsiteLayout, :PreparePhp
:: ============================================================
:PrepareBuildTools
call :ResolvePowerShell
set "pbt_rc=%errorlevel%"
if "%pbt_rc%"=="0" goto :_PrepareBuildTools_layout
echo ERROR: PowerShell is required by build_web.bat and install_web.bat.
exit /b 1
:_PrepareBuildTools_layout
call :CheckWebsiteLayout
set "pbt_rc=%errorlevel%"
if not "%pbt_rc%"=="0" exit /b %pbt_rc%
call :PreparePhp
set "pbt_rc=%errorlevel%"
exit /b %pbt_rc%
:: ============================================================
:: :CheckWebsiteLayout
:: Detects or verifies the configured website entry file.
::
:: Usage: call :CheckWebsiteLayout
::
:: Output:
::   app.prepare.web.entry_file
::
:: Returns: 0 when acceptable, 1 when a required entry is missing
:: Requires: none
:: ============================================================
:CheckWebsiteLayout
set "app.prepare.web.entry_file=%app.web.entry_file%"
if not defined app.prepare.web.entry_file if exist "%app.prepare.web.root%\index.php" set "app.prepare.web.entry_file=index.php"
if not defined app.prepare.web.entry_file if exist "%app.prepare.web.root%\index.html" set "app.prepare.web.entry_file=index.html"
if not defined app.prepare.web.entry_file if exist "%app.prepare.web.root%\index.htm" set "app.prepare.web.entry_file=index.htm"
if not "%app.web.require_entry%"=="1" exit /b 0
if defined app.prepare.web.entry_file if exist "%app.prepare.web.root%\%app.prepare.web.entry_file%" exit /b 0
echo ERROR: Required website entry file was not found.
if defined app.prepare.web.entry_file echo   "%app.prepare.web.root%\%app.prepare.web.entry_file%"
if not defined app.prepare.web.entry_file echo   Configure app.web.entry_file in build_config_web.bat.
exit /b 1
:: ============================================================
:: :PreparePhp
:: Resolves php.exe according to app.web.php_lint.
::
:: auto:
::   PHP is optional; missing PHP produces a warning when PHP files exist.
::
:: required:
::   PHP is required when PHP files exist.
::
:: off:
::   PHP is not resolved.
::
:: Usage: call :PreparePhp
::
:: Returns: 0 when acceptable, 1 when required PHP is missing,
::          2 when app.web.php_lint is invalid
:: Requires: :ResolvePhp
:: ============================================================
:PreparePhp
if /I "%app.web.php_lint%"=="off" exit /b 0
if /I "%app.web.php_lint%"=="auto" goto :_PreparePhp_detect
if /I "%app.web.php_lint%"=="required" goto :_PreparePhp_detect
echo ERROR: app.web.php_lint must be auto, required, or off.
exit /b 2
:_PreparePhp_detect
set "pp_php_files="
for /R "%app.prepare.web.root%" %%F in (*.php) do if not defined pp_php_files set "pp_php_files=1"
if not defined pp_php_files exit /b 0
call :ResolvePhp
set "pp_rc=%errorlevel%"
if "%pp_rc%"=="0" exit /b 0
if /I "%app.web.php_lint%"=="required" goto :_PreparePhp_required
echo WARNING: PHP files exist, but php.exe was not found.
echo PHP linting will be skipped because app.web.php_lint=auto.
echo.
exit /b 0
:_PreparePhp_required
echo ERROR: PHP files exist, app.web.php_lint=required, and php.exe was not found.
echo Configure app.web.prepare.php_exe or place PHP in PATH.
exit /b 1
:: ============================================================
:: :PrepareDeploymentTools
:: Resolves folder or configured external deployment requirements.
::
:: Usage: call :PrepareDeploymentTools
::
:: Returns: first nonzero child result
:: Requires: deployment helper functions
:: ============================================================
:PrepareDeploymentTools
if /I "%app.web.install.method%"=="folder" goto :_PrepareDeploymentTools_folder
call :PrepareExternalDeploymentMethod
set "pdt_rc=%errorlevel%"
if not "%pdt_rc%"=="0" exit /b %pdt_rc%
goto :_PrepareDeploymentTools_verify
:_PrepareDeploymentTools_folder
call :ResolvePowerShell
set "pdt_rc=%errorlevel%"
if not "%pdt_rc%"=="0" (echo ERROR: PowerShell is required for folder deployment validation. & exit /b 1)
call :ResolveRobocopy
set "pdt_rc=%errorlevel%"
if "%pdt_rc%"=="0" goto :_PrepareDeploymentTools_destination
echo ERROR: Robocopy is required for folder website deployment.
exit /b 1
:_PrepareDeploymentTools_destination
call :CheckConfiguredDestination
set "pdt_rc=%errorlevel%"
if not "%pdt_rc%"=="0" exit /b %pdt_rc%
:_PrepareDeploymentTools_verify
if not defined app.web.install.verify_script goto :_PrepareDeploymentTools_extra
call :ResolveConfiguredScript "%app.web.install.verify_script%" app.prepare.web.verify_script
set "pdt_rc=%errorlevel%"
if "%pdt_rc%"=="0" goto :_PrepareDeploymentTools_extra
echo ERROR: Configured deployment verification script was not found:
echo   "%app.web.install.verify_script%"
exit /b 1
:_PrepareDeploymentTools_extra
call :CheckConfiguredExternalCommands
set "pdt_rc=%errorlevel%"
exit /b %pdt_rc%
:: ============================================================
:: :PrepareExternalDeploymentMethod
:: Resolves a configured method script and common method commands.
::
:: Recognized command checks:
::   scp   scp.exe and ssh.exe
::   sftp  sftp.exe and ssh.exe
::   rsync rsync.exe and ssh.exe
::
:: Other methods rely on their method script and optional
:: app.web.prepare.external_commands.
::
:: Usage: call :PrepareExternalDeploymentMethod
::
:: Returns: 0 when ready, 1 when a requirement is missing
:: Requires: :ResolveConfiguredScript and tool resolvers
:: ============================================================
:PrepareExternalDeploymentMethod
call :ResolveConfiguredScript "%app.web.install.method_script%" app.prepare.web.method_script
set "pedm_rc=%errorlevel%"
if "%pedm_rc%"=="0" goto :_PrepareExternalDeploymentMethod_commands
echo ERROR: Deployment method "%app.web.install.method%" requires a method script.
echo Configure:
echo   set "app.web.install.method_script=tools\deploy_%app.web.install.method%.bat"
exit /b 1
:_PrepareExternalDeploymentMethod_commands
if /I "%app.web.install.method%"=="scp" call :ResolveScpTools
if /I "%app.web.install.method%"=="scp" set "pedm_rc=%errorlevel%"
if /I "%app.web.install.method%"=="scp" exit /b %pedm_rc%
if /I "%app.web.install.method%"=="sftp" call :ResolveSftpTools
if /I "%app.web.install.method%"=="sftp" set "pedm_rc=%errorlevel%"
if /I "%app.web.install.method%"=="sftp" exit /b %pedm_rc%
if /I "%app.web.install.method%"=="rsync" call :ResolveRsyncTools
if /I "%app.web.install.method%"=="rsync" set "pedm_rc=%errorlevel%"
if /I "%app.web.install.method%"=="rsync" exit /b %pedm_rc%
exit /b 0
:: ============================================================
:: :CheckConfiguredDestination
:: Checks an optional folder destination without creating it.
::
:: A missing destination is not an error during preparation because a
:: command-line destination may be supplied later.
::
:: When configured:
::   existing destination = ready
::   missing destination with existing parent and create_destination=1 = ready
::   otherwise = unavailable
::
:: Usage: call :CheckConfiguredDestination
::
:: Output:
::   app.prepare.web.destination.status
::
:: Returns: 0 when absent/ready, 1 when configured but unavailable
:: Requires: PowerShell
:: ============================================================
:CheckConfiguredDestination
set "app.prepare.web.destination.status=not configured"
if not "%app.web.prepare.check_destination%"=="1" (set "app.prepare.web.destination.status=check disabled" & exit /b 0)
if not defined app.web.install.destination exit /b 0
set "WEB_PREPARE_DESTINATION=%app.web.install.destination%"
set "WEB_PREPARE_CREATE_DESTINATION=%app.web.install.create_destination%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $d=$env:WEB_PREPARE_DESTINATION; if(Test-Path -LiteralPath $d -PathType Container){exit 0}; if($env:WEB_PREPARE_CREATE_DESTINATION -eq '1'){ $p=Split-Path -Parent $d; if([string]::IsNullOrWhiteSpace($p)){exit 2}; if(Test-Path -LiteralPath $p -PathType Container){exit 0} }; exit 1"
set "ccd_rc=%errorlevel%"
set "WEB_PREPARE_DESTINATION="
set "WEB_PREPARE_CREATE_DESTINATION="
if "%ccd_rc%"=="0" (set "app.prepare.web.destination.status=ready" & exit /b 0)
set "app.prepare.web.destination.status=unavailable"
echo ERROR: Configured website deployment destination is unavailable:
echo   "%app.web.install.destination%"
echo.
echo For a mapped drive such as T:\, connect or map the share before
echo deployment. prepare_web.bat does not map drives or request credentials.
exit /b 1
:: ============================================================
:: :CheckConfiguredExternalCommands
:: Checks additional space-separated commands from:
::   app.web.prepare.external_commands
::
:: Example:
::   set "app.web.prepare.external_commands=curl.exe jq.exe"
::
:: Usage: call :CheckConfiguredExternalCommands
::
:: Returns: 0 when all are available, 1 otherwise
:: Requires: :RequireCommand
:: ============================================================
:CheckConfiguredExternalCommands
if not defined app.web.prepare.external_commands exit /b 0
set "ccec_failed="
for %%C in (%app.web.prepare.external_commands%) do call :RequireCommand "%%~C"
if defined ccec_failed exit /b 1
exit /b 0
:: ============================================================
:: :RequireCommand
:: Requires one command from PATH.
::
:: Usage: call :RequireCommand "command.exe"
::
:: Returns: 0 when found, 1 when missing
:: Requires: where.exe
:: ============================================================
:RequireCommand
where "%~1" >nul 2>nul
if not errorlevel 1 exit /b 0
echo ERROR: Required web preparation command was not found:
echo   %~1
set "ccec_failed=1"
exit /b 1
:: ============================================================
:: :RunWebProjectPreparation
:: Runs the customizable project preparation lifecycle.
::
:: Check return convention:
::   0 already ready
::   1 preparation operations are needed
::   greater than 1 check failure
::
:: force runs operations even when the check reports ready.
::
:: Usage: call :RunWebProjectPreparation
::
:: Returns: first nonzero custom result
:: Requires: project customization functions
:: ============================================================
:RunWebProjectPreparation
call :CheckWebProjectReady
set "rwpp_check_rc=%errorlevel%"
set "app.prepare.web.custom.check.rc=%rwpp_check_rc%"
if "%rwpp_check_rc%"=="0" set "app.prepare.web.custom.ready=1"
if defined app.prepare.web.check_only if "%rwpp_check_rc%"=="0" goto :_RunWebProjectPreparation_validate
if defined app.prepare.web.check_only exit /b %rwpp_check_rc%
if defined app.prepare.web.force goto :_RunWebProjectPreparation_operations
if "%rwpp_check_rc%"=="0" goto :_RunWebProjectPreparation_validate
if "%rwpp_check_rc%"=="1" goto :_RunWebProjectPreparation_operations
exit /b %rwpp_check_rc%
:_RunWebProjectPreparation_operations
call :PrepareWebProjectOperations
set "rwpp_rc=%errorlevel%"
if not "%rwpp_rc%"=="0" exit /b %rwpp_rc%
:_RunWebProjectPreparation_validate
call :ValidateWebProjectPreparation
set "rwpp_rc=%errorlevel%"
if not "%rwpp_rc%"=="0" exit /b %rwpp_rc%
set "app.prepare.web.custom.ready=1"
exit /b 0
:: ============================================================
:: :CheckWebProjectReady
:: PROJECT CUSTOMIZATION POINT.
::
:: Check framework-specific tools, generated files, local-server
:: configuration, writable runtime paths, Composer dependencies, npm
:: dependencies, or other project preparation state.
::
:: Do not download, install, or modify anything here.
::
:: Usage: call :CheckWebProjectReady
::
:: Returns: 0 when ready
::          1 when :PrepareWebProjectOperations should run
::          greater than 1 when the check itself fails
:: Requires: project-specific checks when customized
:: ============================================================
:CheckWebProjectReady
exit /b 0
:: ============================================================
:: :PrepareWebProjectOperations
:: PROJECT CUSTOMIZATION POINT.
::
:: Put deliberate framework-specific preparation operations here.
:: Examples:
::   - run Composer install
::   - run npm install
::   - generate local configuration from a safe template
::   - generate assets or caches
::   - initialize a local writable runtime file
::
:: Do not embed or print secrets. Prefer environment variables or
:: ignored local files.
::
:: Usage: call :PrepareWebProjectOperations
::
:: Returns: 0 on success, nonzero on failure
:: Requires: project-specific tools when customized
:: ============================================================
:PrepareWebProjectOperations
exit /b 0
:: ============================================================
:: :ValidateWebProjectPreparation
:: PROJECT CUSTOMIZATION POINT.
::
:: Verify the result after project preparation or during check-only
:: mode. Confirm required generated files, dependencies, permissions,
:: or framework state.
::
:: Usage: call :ValidateWebProjectPreparation
::
:: Returns: 0 when valid, nonzero otherwise
:: Requires: project-specific output when customized
:: ============================================================
:ValidateWebProjectPreparation
exit /b 0
:: ============================================================
:: :ApplyWebEnvironment
:: PROJECT CUSTOMIZATION POINT.
::
:: Applies resolved tool directories and optional project environment
:: values to the current cmd.exe. The prepare launcher must call this
:: implementation in the current process for PATH changes to propagate.
::
:: Default behavior:
::   - sets PHP_HOME when php.exe was resolved
::   - prepends PHP, GitHub CLI, OpenSSH, and rsync directories as needed
::
:: Usage: call :ApplyWebEnvironment
::
:: Returns: 0
:: Requires: :PrependToolDirectory
:: ============================================================
:ApplyWebEnvironment
if defined app.web.php.exe for %%A in ("%app.web.php.exe%") do set "PHP_HOME=%%~dpA"
if defined PHP_HOME if "%PHP_HOME:~-1%"=="\" set "PHP_HOME=%PHP_HOME:~0,-1%"
if defined app.web.php.exe call :PrependToolDirectory "%app.web.php.exe%"
if defined app.web.git.exe call :PrependToolDirectory "%app.web.git.exe%"
if defined app.web.github.cli call :PrependToolDirectory "%app.web.github.cli%"
if defined app.web.ssh.exe call :PrependToolDirectory "%app.web.ssh.exe%"
if defined app.web.scp.exe call :PrependToolDirectory "%app.web.scp.exe%"
if defined app.web.sftp.exe call :PrependToolDirectory "%app.web.sftp.exe%"
if defined app.web.rsync.exe call :PrependToolDirectory "%app.web.rsync.exe%"
exit /b 0
:: ============================================================
:: :WriteWebEnvironmentFile
:: PROJECT CUSTOMIZATION POINT.
::
:: Optionally write app.web.prepare.env_file so later shells can load
:: persistent project-specific tool paths. The generic implementation
:: intentionally writes nothing.
::
:: Never write credentials, tokens, passwords, or private keys into a
:: tracked environment file.
::
:: Usage: call :WriteWebEnvironmentFile
::
:: Returns: 0
:: Requires: project-specific implementation when customized
:: ============================================================
:WriteWebEnvironmentFile
exit /b 0
:: ============================================================
:: :ResolvePowerShell
:: Resolves powershell.exe from configured, PATH, or system locations.
::
:: Usage: call :ResolvePowerShell
::
:: Output:
::   app.web.powershell.exe
::
:: Returns: 0 when found, 1 when missing
:: Requires: :UseTool
:: ============================================================
:ResolvePowerShell
set "app.web.powershell.exe="
if defined app.web.prepare.powershell_exe call :UseTool "%app.web.prepare.powershell_exe%" app.web.powershell.exe
if defined app.web.powershell.exe exit /b 0
for /f "delims=" %%P in ('where powershell.exe 2^>nul') do if not defined app.web.powershell.exe set "app.web.powershell.exe=%%~fP"
if defined app.web.powershell.exe exit /b 0
call :UseTool "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" app.web.powershell.exe
if defined app.web.powershell.exe exit /b 0
exit /b 1
:: ============================================================
:: :ResolveRobocopy
:: Resolves robocopy.exe from configured, PATH, or system locations.
::
:: Usage: call :ResolveRobocopy
::
:: Output:
::   app.web.robocopy.exe
::
:: Returns: 0 when found, 1 when missing
:: Requires: :UseTool
:: ============================================================
:ResolveRobocopy
set "app.web.robocopy.exe="
if defined app.web.prepare.robocopy_exe call :UseTool "%app.web.prepare.robocopy_exe%" app.web.robocopy.exe
if defined app.web.robocopy.exe exit /b 0
for /f "delims=" %%P in ('where robocopy.exe 2^>nul') do if not defined app.web.robocopy.exe set "app.web.robocopy.exe=%%~fP"
if defined app.web.robocopy.exe exit /b 0
call :UseTool "%SystemRoot%\System32\robocopy.exe" app.web.robocopy.exe
if defined app.web.robocopy.exe exit /b 0
exit /b 1
:: ============================================================
:: :ResolvePhp
:: Resolves php.exe from configured, bundled, PATH, and common locations.
::
:: Usage: call :ResolvePhp
::
:: Output:
::   app.web.php.exe
::
:: Returns: 0 when found, 1 when missing
:: Requires: :UseTool
:: ============================================================
:ResolvePhp
set "app.web.php.exe="
if defined app.web.prepare.php_exe call :UseTool "%app.web.prepare.php_exe%" app.web.php.exe
if defined app.web.php.exe exit /b 0
for /f "delims=" %%P in ('where php.exe 2^>nul') do if not defined app.web.php.exe set "app.web.php.exe=%%~fP"
if defined app.web.php.exe exit /b 0
call :UseTool "%app.prepare.web.root%\%app.web.prepare.tools_dir%\php\php.exe" app.web.php.exe
if defined app.web.php.exe exit /b 0
call :UseTool "%app.prepare.web.root%\%app.web.prepare.tools_dir%\php.exe" app.web.php.exe
if defined app.web.php.exe exit /b 0
call :UseTool "C:\php\php.exe" app.web.php.exe
if defined app.web.php.exe exit /b 0
call :UseTool "C:\xampp\php\php.exe" app.web.php.exe
if defined app.web.php.exe exit /b 0
call :UseTool "%ProgramFiles%\PHP\php.exe" app.web.php.exe
if defined app.web.php.exe exit /b 0
call :UseTool "%LocalAppData%\Programs\PHP\php.exe" app.web.php.exe
if defined app.web.php.exe exit /b 0
exit /b 1
:: ============================================================
:: :ResolveGit
:: Resolves git.exe from PATH, bundled, and common locations.
::
:: Usage: call :ResolveGit
::
:: Output:
::   app.web.git.exe
::
:: Returns: 0 when found, 1 when missing
:: Requires: :UseTool
:: ============================================================
:ResolveGit
set "app.web.git.exe="
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined app.web.git.exe set "app.web.git.exe=%%~fG"
if defined app.web.git.exe exit /b 0
call :UseTool "%app.prepare.web.root%\%app.web.prepare.tools_dir%\git\cmd\git.exe" app.web.git.exe
if defined app.web.git.exe exit /b 0
call :UseTool "%ProgramFiles%\Git\cmd\git.exe" app.web.git.exe
if defined app.web.git.exe exit /b 0
call :UseTool "%LocalAppData%\Programs\Git\cmd\git.exe" app.web.git.exe
if defined app.web.git.exe exit /b 0
exit /b 1
:: ============================================================
:: :ResolveGitHubCli
:: Resolves gh.exe from PATH, bundled, and common locations.
::
:: Usage: call :ResolveGitHubCli
::
:: Output:
::   app.web.github.cli
::
:: Returns: 0 when found, 1 when missing
:: Requires: :UseTool
:: ============================================================
:ResolveGitHubCli
set "app.web.github.cli="
for /f "delims=" %%G in ('where gh.exe 2^>nul') do if not defined app.web.github.cli set "app.web.github.cli=%%~fG"
if defined app.web.github.cli exit /b 0
call :UseTool "%app.prepare.web.root%\%app.web.prepare.tools_dir%\gh\bin\gh.exe" app.web.github.cli
if defined app.web.github.cli exit /b 0
call :UseTool "%app.prepare.web.root%\%app.web.prepare.tools_dir%\gh\gh.exe" app.web.github.cli
if defined app.web.github.cli exit /b 0
call :UseTool "%app.prepare.web.root%\%app.web.prepare.tools_dir%\gh.exe" app.web.github.cli
if defined app.web.github.cli exit /b 0
call :UseTool "%ProgramFiles%\GitHub CLI\gh.exe" app.web.github.cli
if defined app.web.github.cli exit /b 0
call :UseTool "%LocalAppData%\Programs\GitHub CLI\gh.exe" app.web.github.cli
if defined app.web.github.cli exit /b 0
exit /b 1
:: ============================================================
:: :ResolveScpTools
:: Resolves scp.exe and ssh.exe for the scp method.
::
:: Usage: call :ResolveScpTools
::
:: Returns: 0 when both are found, 1 otherwise
:: Requires: :ResolveOpenSshTool
:: ============================================================
:ResolveScpTools
call :ResolveOpenSshTool scp.exe app.web.scp.exe
set "rst_rc=%errorlevel%"
if not "%rst_rc%"=="0" (echo ERROR: scp.exe was not found. & exit /b 1)
call :ResolveOpenSshTool ssh.exe app.web.ssh.exe
set "rst_rc=%errorlevel%"
if not "%rst_rc%"=="0" (echo ERROR: ssh.exe was not found. & exit /b 1)
exit /b 0
:: ============================================================
:: :ResolveSftpTools
:: Resolves sftp.exe and ssh.exe for the sftp method.
::
:: Usage: call :ResolveSftpTools
::
:: Returns: 0 when both are found, 1 otherwise
:: Requires: :ResolveOpenSshTool
:: ============================================================
:ResolveSftpTools
call :ResolveOpenSshTool sftp.exe app.web.sftp.exe
set "rst_rc=%errorlevel%"
if not "%rst_rc%"=="0" (echo ERROR: sftp.exe was not found. & exit /b 1)
call :ResolveOpenSshTool ssh.exe app.web.ssh.exe
set "rst_rc=%errorlevel%"
if not "%rst_rc%"=="0" (echo ERROR: ssh.exe was not found. & exit /b 1)
exit /b 0
:: ============================================================
:: :ResolveRsyncTools
:: Resolves rsync.exe and optionally ssh.exe for the rsync method.
::
:: Usage: call :ResolveRsyncTools
::
:: Returns: 0 when rsync is found, 1 otherwise
:: Requires: :UseTool, :ResolveOpenSshTool
:: ============================================================
:ResolveRsyncTools
set "app.web.rsync.exe="
if defined app.web.prepare.rsync_exe call :UseTool "%app.web.prepare.rsync_exe%" app.web.rsync.exe
if not defined app.web.rsync.exe for /f "delims=" %%R in ('where rsync.exe 2^>nul') do if not defined app.web.rsync.exe set "app.web.rsync.exe=%%~fR"
if not defined app.web.rsync.exe call :UseTool "%app.prepare.web.root%\%app.web.prepare.tools_dir%\rsync\rsync.exe" app.web.rsync.exe
if not defined app.web.rsync.exe (echo ERROR: rsync.exe was not found. & exit /b 1)
call :ResolveOpenSshTool ssh.exe app.web.ssh.exe >nul 2>nul
exit /b 0
:: ============================================================
:: :ResolveOpenSshTool
:: Resolves one OpenSSH executable from PATH, bundled, or Windows.
::
:: Usage: call :ResolveOpenSshTool tool.exe outputVariable
::
:: Returns: 0 when found, 1 otherwise
:: Requires: :UseTool
:: ============================================================
:ResolveOpenSshTool
set "rost_name=%~1"
set "rost_output=%~2"
set "rost_found="
set "rost_value="
for /f "delims=" %%S in ('where "%rost_name%" 2^>nul') do if not defined rost_found set "rost_found=%%~fS"
if defined rost_found set "%rost_output%=%rost_found%"
if defined rost_found exit /b 0
call :UseTool "%app.prepare.web.root%\%app.web.prepare.tools_dir%\openssh\%rost_name%" %rost_output%
call set "rost_value=%%%rost_output%%%"
if defined rost_value exit /b 0
call :UseTool "%SystemRoot%\System32\OpenSSH\%rost_name%" %rost_output%
call set "rost_value=%%%rost_output%%%"
if defined rost_value exit /b 0
exit /b 1
:: ============================================================
:: :ResolveConfiguredScript
:: Resolves an absolute script or one relative to the project root.
::
:: Usage: call :ResolveConfiguredScript "path" outputVariable
::
:: Returns: 0 when found, 1 when missing
:: Requires: none
:: ============================================================
:ResolveConfiguredScript
set "rcs_input=%~1"
set "rcs_output=%~2"
set "rcs_value="
if not defined rcs_input exit /b 1
set "%rcs_output%="
if exist "%rcs_input%" for %%A in ("%rcs_input%") do set "%rcs_output%=%%~fA"
call set "rcs_value=%%%rcs_output%%%"
if defined rcs_value exit /b 0
set "rcs_value="
if exist "%app.prepare.web.root%\%rcs_input%" for %%A in ("%app.prepare.web.root%\%rcs_input%") do set "%rcs_output%=%%~fA"
call set "rcs_value=%%%rcs_output%%%"
if defined rcs_value exit /b 0
exit /b 1
:: ============================================================
:: :ResolveCustomSourceControlClient
:: REPOSITORY EXTENSION POINT.
::
:: Add support for Mercurial, Subversion, Fossil, or another source
:: control client here.
::
:: Usage: call :ResolveCustomSourceControlClient
::
:: Returns: 0 when supported/ready, 1 when unsupported or missing
:: Requires: project-specific implementation
:: ============================================================
:ResolveCustomSourceControlClient
echo ERROR: No web preparer is registered for source control:
echo   %app.prepare.web.scm%
exit /b 1
:: ============================================================
:: :ResolveCustomRepositoryProviderClient
:: REPOSITORY EXTENSION POINT.
::
:: Add GitLab, Bitbucket, Codeberg, or another provider-specific CLI
:: requirement here. Generic Git repositories require no provider CLI.
::
:: Usage: call :ResolveCustomRepositoryProviderClient
::
:: Returns: 0 when no provider CLI is needed or when ready
::          1 when a required provider client is unsupported/missing
:: Requires: project-specific implementation
:: ============================================================
:ResolveCustomRepositoryProviderClient
if /I "%app.prepare.web.provider%"=="gitlab" exit /b 0
if /I "%app.prepare.web.provider%"=="bitbucket" exit /b 0
if /I "%app.prepare.web.provider%"=="codeberg" exit /b 0
echo ERROR: No web preparer is registered for repository provider:
echo   %app.prepare.web.provider%
exit /b 1
:: ============================================================
:: :UseTool
:: Selects an existing executable and prepends its directory to PATH.
::
:: Usage: call :UseTool "exe path" outputVariable
::
:: Returns: 0 when selected, 1 when missing
:: Requires: :PrependPathIfMissing
:: ============================================================
:UseTool
set "ut_file=%~1"
set "ut_output=%~2"
if not exist "%ut_file%" exit /b 1
for %%A in ("%ut_file%") do set "ut_file=%%~fA"
set "%ut_output%=%ut_file%"
call :PrependToolDirectory "%ut_file%"
exit /b 0
:: ============================================================
:: :PrependToolDirectory
:: Prepends the parent directory of one executable to PATH if missing.
::
:: Usage: call :PrependToolDirectory "exe path"
::
:: Returns: 0
:: Requires: :PrependPathIfMissing
:: ============================================================
:PrependToolDirectory
if not exist "%~1" exit /b 0
for %%A in ("%~1") do set "ptd_dir=%%~dpA"
if "%ptd_dir:~-1%"=="\" set "ptd_dir=%ptd_dir:~0,-1%"
call :PrependPathIfMissing "%ptd_dir%"
exit /b 0
:: ============================================================
:: :PrependPathIfMissing
:: Prepends one directory unless PATH already contains it.
::
:: Usage: call :PrependPathIfMissing "directory"
::
:: Returns: 0
:: Requires: findstr.exe
:: ============================================================
:PrependPathIfMissing
if "%~1"=="" exit /b 0
path | findstr /I /L /C:"%~1" >nul 2>nul
if errorlevel 1 set "PATH=%~1;%PATH%"
exit /b 0
:: ============================================================
:: :ShowSummary
:: Prints repository, web tool, and deployment readiness.
::
:: Usage: call :ShowSummary
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowSummary
echo ============================================================
echo  Website preparation complete
echo ============================================================
echo.
echo Source control:
if defined app.prepare.web.scm echo   %app.prepare.web.scm%
if not defined app.prepare.web.scm echo   not checked
echo.
echo Repository provider:
if defined app.prepare.web.provider echo   %app.prepare.web.provider%
if not defined app.prepare.web.provider echo   not checked
echo.
echo Repository URL:
if defined app.prepare.web.repository.url echo   %app.prepare.web.repository.url%
if not defined app.prepare.web.repository.url echo   not configured or not checked
echo.
echo Website entry:
if defined app.prepare.web.entry_file echo   %app.prepare.web.entry_file%
if not defined app.prepare.web.entry_file echo   not checked or not required
echo.
echo PHP lint policy:
echo   %app.web.php_lint%
echo.
echo Deployment method:
echo   %app.web.install.method%
echo.
echo Deployment destination:
if defined app.web.install.destination echo   %app.web.install.destination%
if not defined app.web.install.destination echo   not configured
echo.
echo Destination status:
if defined app.prepare.web.destination.status echo   %app.prepare.web.destination.status%
if not defined app.prepare.web.destination.status echo   not checked
echo.
if defined app.web.git.exe echo Git:
if defined app.web.git.exe echo   %app.web.git.exe%
if defined app.web.github.cli echo GitHub CLI:
if defined app.web.github.cli echo   %app.web.github.cli%
if defined app.web.powershell.exe echo PowerShell:
if defined app.web.powershell.exe echo   %app.web.powershell.exe%
if defined app.web.php.exe echo PHP:
if defined app.web.php.exe echo   %app.web.php.exe%
if defined app.web.robocopy.exe echo Robocopy:
if defined app.web.robocopy.exe echo   %app.web.robocopy.exe%
if defined app.web.ssh.exe echo SSH:
if defined app.web.ssh.exe echo   %app.web.ssh.exe%
if defined app.web.scp.exe echo SCP:
if defined app.web.scp.exe echo   %app.web.scp.exe%
if defined app.web.sftp.exe echo SFTP:
if defined app.web.sftp.exe echo   %app.web.sftp.exe%
if defined app.web.rsync.exe echo rsync:
if defined app.web.rsync.exe echo   %app.web.rsync.exe%
if defined app.prepare.web.method_script echo Deployment script:
if defined app.prepare.web.method_script echo   %app.prepare.web.method_script%
if defined app.prepare.web.verify_script echo Verification script:
if defined app.prepare.web.verify_script echo   %app.prepare.web.verify_script%
echo.
echo %app.web.prepare.description%
echo.
exit /b 0
