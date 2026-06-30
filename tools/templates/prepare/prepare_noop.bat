@echo off
:: ============================================================
:: prepare_noop.bat
:: Generic baseline preparation implementation and template.
::
:: This file provides a complete preparation lifecycle even when a
:: project has no build-system-specific installer yet.
::
:: Preparation layers:
::   1. repository preparation
::      - detects source-control technology
::      - detects repository hosting provider
::      - resolves Git for Git repositories
::      - resolves GitHub CLI only for GitHub repositories
::      - exposes already-installed or bundled tools through PATH
::   2. project preparation
::      - checks whether project-specific tools are already ready
::      - runs customizable preparation operations when required
::      - validates the result
::      - applies environment variables and PATH changes
::      - optionally writes a reusable environment file
::
:: This template never downloads or installs software by default.
:: It never calls bootstrap.bat. Add deliberate project-specific
:: operations only inside the documented customization functions.
::
:: Repository detection order:
::   1. explicit configuration variables
::   2. Git origin remote URL
::   3. app.repo_url
::   4. project metadata such as a .git directory
::
:: Primary project customization points:
::   :CheckProjectPreparationReady
::   :PrepareProjectOperations
::   :ValidateProjectPreparation
::   :ApplyProjectEnvironment
::   :WriteProjectEnvironmentFile
::
:: Repository extension points:
::   :ResolveCustomSourceControlClient
::   :ResolveCustomRepositoryProviderClient
::
:: Configuration order:
::   1. build_config.bat when present
::   2. build_config_noop.bat when present
::
:: Optional configuration:
::   app.repository.scm=git
::   app.repository.provider=github
::   app.repo_url=https://github.com/owner/repository.git
::   app.prepare.noop.default_request=all
::   app.prepare.noop.title=Project preparation
::   app.prepare.noop.description=Preparation description
::   app.prepare.noop.tools_dir=tools
::   app.prepare.noop.env_file=env.bat
::
:: Active placement:
::   prepare_noop.bat at the project root
::
:: Template storage:
::   tools\templates\prepare\prepare_noop.bat
::
:: Usage:
::   call prepare_noop.bat
::   call prepare_noop.bat all
::   call prepare_noop.bat repository
::   call prepare_noop.bat project
::   call prepare_noop.bat check
::   call prepare_noop.bat force
::   call prepare_noop.bat help
::
:: Returns: 0 when requested preparation is ready
::          1 when required software remains unavailable
::          2 on an invalid command-line argument
::          config/custom operation exit code on failure
:: Requires: where.exe
::           Git only for Git repositories
::           GitHub CLI only for GitHub repositories
:: ============================================================
:setup
set "app.prepare.noop.rc=0"
set "app.prepare.noop.root="
set "app.prepare.noop.request="
set "app.prepare.noop.arguments=%*"
set "app.prepare.noop.force="
set "app.prepare.noop.shared_config="
set "app.prepare.noop.suffix_config="
set "app.prepare.noop.repository.url="
set "app.prepare.noop.scm="
set "app.prepare.noop.provider="
set "app.prepare.noop.title="
set "app.prepare.noop.description="
set "app.prepare.noop.tools_dir="
set "app.prepare.noop.env_file="
set "app.prepare.noop.project.check_rc=0"
set "app.prepare.suffix=noop"
if not defined PREPARE_SUFFIX set "PREPARE_SUFFIX=noop"
if defined PREPARE_PROJECT_ROOT set "app.prepare.noop.root=%PREPARE_PROJECT_ROOT%"
if not defined app.prepare.noop.root for %%A in ("%~dp0.") do set "app.prepare.noop.root=%%~fA"
for %%A in ("%app.prepare.noop.root%\.") do set "app.prepare.noop.root=%%~fA"
:main
call :LoadConfiguration
set "app.prepare.noop.rc=%errorlevel%"
if not "%app.prepare.noop.rc%"=="0" goto :end
call :SetDefaults
call :ParseArguments %*
set "app.prepare.noop.rc=%errorlevel%"
if not "%app.prepare.noop.rc%"=="0" goto :end
if /I "%app.prepare.noop.request%"=="help" call :ShowHelp
if /I "%app.prepare.noop.request%"=="help" set "app.prepare.noop.rc=%errorlevel%"
if /I "%app.prepare.noop.request%"=="help" goto :end
cd /d "%app.prepare.noop.root%"
set "app.prepare.noop.rc=%errorlevel%"
if "%app.prepare.noop.rc%"=="0" goto :_main_dispatch
echo.
echo ERROR: Could not enter the project root:
echo   "%app.prepare.noop.root%"
echo.
set "app.prepare.noop.rc=1"
goto :end
:_main_dispatch
call :ShowHeader
if /I "%app.prepare.noop.request%"=="repository" call :PrepareRepository
if /I "%app.prepare.noop.request%"=="repository" set "app.prepare.noop.rc=%errorlevel%"
if /I "%app.prepare.noop.request%"=="repository" goto :end
if /I "%app.prepare.noop.request%"=="project" call :PrepareProject
if /I "%app.prepare.noop.request%"=="project" set "app.prepare.noop.rc=%errorlevel%"
if /I "%app.prepare.noop.request%"=="project" goto :end
if /I "%app.prepare.noop.request%"=="check" call :CheckAll
if /I "%app.prepare.noop.request%"=="check" set "app.prepare.noop.rc=%errorlevel%"
if /I "%app.prepare.noop.request%"=="check" goto :end
call :PrepareAll
set "app.prepare.noop.rc=%errorlevel%"
:end
exit /b %app.prepare.noop.rc%
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
set "app.prepare.noop.shared_config=%app.prepare.noop.root%\build_config.bat"
set "app.prepare.noop.suffix_config=%app.prepare.noop.root%\build_config_noop.bat"
if not exist "%app.prepare.noop.shared_config%" goto :_LoadConfiguration_suffix
call "%app.prepare.noop.shared_config%"
set "lc_rc=%errorlevel%"
if "%lc_rc%"=="0" goto :_LoadConfiguration_suffix
echo.
echo ERROR: Shared configuration failed:
echo   "%app.prepare.noop.shared_config%"
echo.
exit /b %lc_rc%
:_LoadConfiguration_suffix
if not exist "%app.prepare.noop.suffix_config%" exit /b 0
call "%app.prepare.noop.suffix_config%"
set "lc_rc=%errorlevel%"
if "%lc_rc%"=="0" exit /b 0
echo.
echo ERROR: No-op configuration failed:
echo   "%app.prepare.noop.suffix_config%"
echo.
exit /b %lc_rc%
:: ============================================================
:: :SetDefaults
:: Applies generic preparation defaults after configuration loads.
::
:: Usage: call :SetDefaults
::
:: Returns: 0
:: Requires: none
:: ============================================================
:SetDefaults
if not defined app.prepare.noop.default_request set "app.prepare.noop.default_request=all"
if not defined app.prepare.noop.request set "app.prepare.noop.request=%app.prepare.noop.default_request%"
if not defined app.prepare.noop.title set "app.prepare.noop.title=%app.display_name% baseline preparation"
if not defined app.prepare.noop.title set "app.prepare.noop.title=Baseline project preparation"
if not defined app.prepare.noop.description set "app.prepare.noop.description=No build-system-specific preparation is required."
if not defined app.prepare.noop.tools_dir set "app.prepare.noop.tools_dir=tools"
if not defined app.prepare.noop.env_file set "app.prepare.noop.env_file=env.bat"
exit /b 0
:: ============================================================
:: :ParseArguments
:: Parses preparation scope and flags.
::
:: Usage: call :ParseArguments %*
::
:: Accepted scopes:
::   all
::   repository, git, github
::   project, tools
::   check
::   help
::
:: Accepted flags:
::   force
::   --force
::   /force
::
:: Returns: 0 on success, 2 on an unknown argument
:: Requires: none
:: ============================================================
:ParseArguments
if "%~1"=="" exit /b 0
if /I "%~1"=="all" (set "app.prepare.noop.request=all" & shift & goto :ParseArguments)
if /I "%~1"=="repository" (set "app.prepare.noop.request=repository" & shift & goto :ParseArguments)
if /I "%~1"=="git" (set "app.prepare.noop.request=repository" & shift & goto :ParseArguments)
if /I "%~1"=="github" (set "app.prepare.noop.request=repository" & shift & goto :ParseArguments)
if /I "%~1"=="project" (set "app.prepare.noop.request=project" & shift & goto :ParseArguments)
if /I "%~1"=="tools" (set "app.prepare.noop.request=project" & shift & goto :ParseArguments)
if /I "%~1"=="check" (set "app.prepare.noop.request=check" & shift & goto :ParseArguments)
if /I "%~1"=="force" (set "app.prepare.noop.force=1" & shift & goto :ParseArguments)
if /I "%~1"=="--force" (set "app.prepare.noop.force=1" & shift & goto :ParseArguments)
if /I "%~1"=="/force" (set "app.prepare.noop.force=1" & shift & goto :ParseArguments)
if /I "%~1"=="help" (set "app.prepare.noop.request=help" & shift & goto :ParseArguments)
if /I "%~1"=="--help" (set "app.prepare.noop.request=help" & shift & goto :ParseArguments)
if /I "%~1"=="/help" (set "app.prepare.noop.request=help" & shift & goto :ParseArguments)
if /I "%~1"=="/?" (set "app.prepare.noop.request=help" & shift & goto :ParseArguments)
echo.
echo ERROR: Unknown prepare_noop argument:
echo   %~1
echo.
exit /b 2
:: ============================================================
:: :ShowHeader
:: Prints the selected preparation request.
::
:: Usage: call :ShowHeader
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHeader
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
echo   %app.prepare.noop.request%
if defined app.prepare.noop.force echo.
if defined app.prepare.noop.force echo Force:
if defined app.prepare.noop.force echo   enabled
echo.
exit /b 0
:: ============================================================
:: :ShowHelp
:: Prints preparation scopes, lifecycle, and customization points.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo prepare_noop.bat
echo.
echo Usage:
echo   prepare_noop.bat
echo   prepare_noop.bat all
echo   prepare_noop.bat repository
echo   prepare_noop.bat project
echo   prepare_noop.bat check
echo   prepare_noop.bat force
echo   prepare_noop.bat project force
echo   prepare_noop.bat help
echo.
echo Scopes:
echo   all          Prepare repository tools, then project tools.
echo   repository   Detect SCM/provider and expose required clients.
echo   project      Run the project-specific preparation lifecycle.
echo   check        Check repository and project readiness only.
echo.
echo Flags:
echo   force        Run project preparation operations even when the
echo                readiness check already succeeds.
echo.
echo Project preparation lifecycle:
echo   1. :CheckProjectPreparationReady
echo   2. :PrepareProjectOperations when needed or forced
echo   3. :ValidateProjectPreparation
echo   4. :ApplyProjectEnvironment
echo   5. :WriteProjectEnvironmentFile
echo.
echo Repository extension points:
echo   :ResolveCustomSourceControlClient
echo   :ResolveCustomRepositoryProviderClient
echo.
echo This no-op template does not download or install anything.
echo It never calls bootstrap.bat.
echo.
exit /b 0
:: ============================================================
:: :PrepareAll
:: Prepares repository requirements and then project requirements.
::
:: Usage: call :PrepareAll
::
:: Returns: first nonzero child result
:: Requires: :PrepareRepository, :PrepareProject
:: ============================================================
:PrepareAll
call :PrepareRepository
set "pa_rc=%errorlevel%"
if not "%pa_rc%"=="0" exit /b %pa_rc%
call :PrepareProject
set "pa_rc=%errorlevel%"
exit /b %pa_rc%
:: ============================================================
:: :CheckAll
:: Checks repository clients and project preparation readiness
:: without running project preparation operations.
::
:: Usage: call :CheckAll
::
:: Returns: 0 when ready, nonzero otherwise
:: Requires: :CheckRepository, :CheckProjectPreparationReady
:: ============================================================
:CheckAll
call :CheckRepository
set "ca_rc=%errorlevel%"
if not "%ca_rc%"=="0" exit /b %ca_rc%
echo Project preparation check:
call :CheckProjectPreparationReady
set "ca_rc=%errorlevel%"
if "%ca_rc%"=="0" goto :_CheckAll_ready
if "%ca_rc%"=="1" goto :_CheckAll_not_ready
echo ERROR: Project readiness check failed with exit code %ca_rc%.
exit /b %ca_rc%
:_CheckAll_not_ready
echo   preparation required
echo.
exit /b 1
:_CheckAll_ready
echo   ready
echo.
echo All requested preparation checks passed.
echo.
exit /b 0
:: ============================================================
:: :CheckRepository
:: Detects repository technology and verifies required clients
:: without running project-specific preparation operations.
::
:: Usage: call :CheckRepository
::
:: Returns: repository tool resolution result
:: Requires: :DetectRepository, :ResolveRepositoryTools
:: ============================================================
:CheckRepository
call :DetectRepository
set "cr_rc=%errorlevel%"
if not "%cr_rc%"=="0" exit /b %cr_rc%
call :ShowRepositorySummary
call :ResolveRepositoryTools
set "cr_rc=%errorlevel%"
if not "%cr_rc%"=="0" exit /b %cr_rc%
echo Repository tools are ready.
if defined app.git.exe echo   Git: %app.git.exe%
if defined app.github.cli echo   GitHub CLI: %app.github.cli%
echo.
exit /b 0
:: ============================================================
:: :PrepareRepository
:: Detects the repository and exposes already-available clients.
:: No software is downloaded or installed.
::
:: Usage: call :PrepareRepository
::
:: Returns: 0 when ready, nonzero when a required client is missing
:: Requires: :CheckRepository
:: ============================================================
:PrepareRepository
call :CheckRepository
set "pr_rc=%errorlevel%"
if not "%pr_rc%"=="0" exit /b %pr_rc%
echo Repository preparation complete.
echo.
exit /b 0
:: ============================================================
:: :ShowRepositorySummary
:: Prints detected source-control and hosting information.
::
:: Usage: call :ShowRepositorySummary
::
:: Returns: 0
:: Requires: :DetectRepository
:: ============================================================
:ShowRepositorySummary
echo Repository:
echo.
echo   Source control:
echo     %app.prepare.noop.scm%
echo.
echo   Provider:
echo     %app.prepare.noop.provider%
echo.
echo   URL:
if defined app.prepare.noop.repository.url goto :_ShowRepositorySummary_url
echo     not configured
echo.
exit /b 0
:_ShowRepositorySummary_url
echo     %app.prepare.noop.repository.url%
echo.
exit /b 0
:: ============================================================
:: :DetectRepository
:: Determines source-control system, provider, and repository URL.
::
:: Usage: call :DetectRepository
::
:: Output:
::   app.prepare.noop.scm
::   app.prepare.noop.provider
::   app.prepare.noop.repository.url
::   app.repository.scm
::   app.repository.provider
::   app.repository.url
::
:: Returns: 0
:: Requires: optional git.exe, findstr.exe
:: ============================================================
:DetectRepository
set "app.prepare.noop.repository.url="
set "app.prepare.noop.scm="
set "app.prepare.noop.provider="
if defined app.repository.scm set "app.prepare.noop.scm=%app.repository.scm%"
if not defined app.prepare.noop.scm if defined app.scm set "app.prepare.noop.scm=%app.scm%"
if defined app.repository.provider set "app.prepare.noop.provider=%app.repository.provider%"
if not defined app.prepare.noop.provider if defined app.repo_provider set "app.prepare.noop.provider=%app.repo_provider%"
if defined app.repository.url set "app.prepare.noop.repository.url=%app.repository.url%"
if not defined app.prepare.noop.repository.url if defined app.repo_url set "app.prepare.noop.repository.url=%app.repo_url%"
set "dr_origin="
where git.exe >nul 2>nul
if errorlevel 1 goto :_DetectRepository_metadata
for /f "usebackq delims=" %%U in (`git.exe remote get-url origin 2^>nul`) do if not defined dr_origin set "dr_origin=%%U"
if defined dr_origin set "app.prepare.noop.repository.url=%dr_origin%"
:_DetectRepository_metadata
if not defined app.prepare.noop.scm if exist "%app.prepare.noop.root%\.git\" set "app.prepare.noop.scm=git"
if not defined app.prepare.noop.scm if defined app.prepare.noop.repository.url set "app.prepare.noop.scm=git"
if not defined app.prepare.noop.scm set "app.prepare.noop.scm=none"
if defined app.prepare.noop.provider goto :_DetectRepository_done
if not defined app.prepare.noop.repository.url goto :_DetectRepository_generic
echo(%app.prepare.noop.repository.url%| findstr /I /C:"github.com" >nul
if not errorlevel 1 (set "app.prepare.noop.provider=github" & goto :_DetectRepository_done)
echo(%app.prepare.noop.repository.url%| findstr /I /C:"gitlab.com" >nul
if not errorlevel 1 (set "app.prepare.noop.provider=gitlab" & goto :_DetectRepository_done)
echo(%app.prepare.noop.repository.url%| findstr /I /C:"bitbucket.org" >nul
if not errorlevel 1 (set "app.prepare.noop.provider=bitbucket" & goto :_DetectRepository_done)
echo(%app.prepare.noop.repository.url%| findstr /I /C:"codeberg.org" >nul
if not errorlevel 1 (set "app.prepare.noop.provider=codeberg" & goto :_DetectRepository_done)
:_DetectRepository_generic
if /I "%app.prepare.noop.scm%"=="none" (set "app.prepare.noop.provider=none" & goto :_DetectRepository_done)
set "app.prepare.noop.provider=generic"
:_DetectRepository_done
set "app.repository.scm=%app.prepare.noop.scm%"
set "app.repository.provider=%app.prepare.noop.provider%"
if defined app.prepare.noop.repository.url set "app.repository.url=%app.prepare.noop.repository.url%"
exit /b 0
:: ============================================================
:: :ResolveRepositoryTools
:: Resolves source-control client requirements first, then hosting
:: provider client requirements.
::
:: Usage: call :ResolveRepositoryTools
::
:: Returns: first nonzero child result
:: Requires: :ResolveSourceControlClient, :ResolveProviderClient
:: ============================================================
:ResolveRepositoryTools
call :ResolveSourceControlClient
set "rrt_rc=%errorlevel%"
if not "%rrt_rc%"=="0" exit /b %rrt_rc%
call :ResolveProviderClient
set "rrt_rc=%errorlevel%"
exit /b %rrt_rc%
:: ============================================================
:: :ResolveSourceControlClient
:: Dispatches required client resolution by source-control system.
::
:: Usage: call :ResolveSourceControlClient
::
:: Returns: 0 when ready, nonzero when required client is missing
:: Requires: :ResolveGit, :ResolveCustomSourceControlClient
:: ============================================================
:ResolveSourceControlClient
if /I "%app.prepare.noop.scm%"=="none" exit /b 0
if /I "%app.prepare.noop.scm%"=="git" goto :_ResolveSourceControlClient_git
call :ResolveCustomSourceControlClient "%app.prepare.noop.scm%"
set "rsc_rc=%errorlevel%"
exit /b %rsc_rc%
:_ResolveSourceControlClient_git
call :ResolveGit
set "rsc_rc=%errorlevel%"
if "%rsc_rc%"=="0" exit /b 0
echo ERROR: Git is required for this repository but was not found.
echo Install Git or place a bundled copy at:
echo   "%app.prepare.noop.root%\%app.prepare.noop.tools_dir%\git\cmd\git.exe"
echo.
exit /b 1
:: ============================================================
:: :ResolveProviderClient
:: Dispatches optional provider-specific client resolution.
:: GitHub requires gh.exe. Other recognized providers currently
:: have no mandatory provider CLI in this baseline template.
::
:: Usage: call :ResolveProviderClient
::
:: Returns: 0 when ready, nonzero when required client is missing
:: Requires: :ResolveGitHubCli, :ResolveCustomRepositoryProviderClient
:: ============================================================
:ResolveProviderClient
if /I "%app.prepare.noop.provider%"=="none" exit /b 0
if /I "%app.prepare.noop.provider%"=="generic" exit /b 0
if /I "%app.prepare.noop.provider%"=="github" goto :_ResolveProviderClient_github
call :ResolveCustomRepositoryProviderClient "%app.prepare.noop.provider%"
set "rpc_rc=%errorlevel%"
exit /b %rpc_rc%
:_ResolveProviderClient_github
call :ResolveGitHubCli
set "rpc_rc=%errorlevel%"
if "%rpc_rc%"=="0" exit /b 0
echo ERROR: GitHub CLI is required for this GitHub repository but was not found.
echo Install GitHub CLI or place a bundled copy at one of:
echo   "%app.prepare.noop.root%\%app.prepare.noop.tools_dir%\gh\bin\gh.exe"
echo   "%app.prepare.noop.root%\%app.prepare.noop.tools_dir%\gh\gh.exe"
echo   "%app.prepare.noop.root%\%app.prepare.noop.tools_dir%\gh.exe"
echo.
exit /b 1
:: ============================================================
:: :ResolveCustomSourceControlClient
:: REPOSITORY CUSTOMIZATION POINT.
::
:: Add resolution for non-Git source-control systems here.
:: The requested SCM name is provided as %~1.
::
:: Example systems:
::   mercurial
::   subversion
::   fossil
::
:: Usage: call :ResolveCustomSourceControlClient "scm"
::
:: Returns: 0 when no client is required or the client is ready
::          nonzero when the required client is unavailable
:: Requires: project-specific client when customized
:: ============================================================
:ResolveCustomSourceControlClient
echo WARNING: No baseline client resolver is configured for source control "%~1".
echo.
exit /b 0
:: ============================================================
:: :ResolveCustomRepositoryProviderClient
:: REPOSITORY CUSTOMIZATION POINT.
::
:: Add provider-specific CLI resolution here when a hosting website
:: requires one. The provider name is provided as %~1.
::
:: Recognized provider examples:
::   gitlab
::   bitbucket
::   codeberg
::
:: Usage: call :ResolveCustomRepositoryProviderClient "provider"
::
:: Returns: 0 when no provider CLI is required or it is ready
::          nonzero when a required provider CLI is unavailable
:: Requires: provider-specific client when customized
:: ============================================================
:ResolveCustomRepositoryProviderClient
exit /b 0
:: ============================================================
:: :ResolveGit
:: Finds Git in PATH or known bundled/system locations and exposes
:: the selected directory through PATH.
::
:: Usage: call :ResolveGit
::
:: Output:
::   app.git.exe
::   PATH may be prepended with the selected Git directory
::
:: Returns: 0 when found, 1 when missing
:: Requires: where.exe, :UseTool
:: ============================================================
:ResolveGit
set "app.git.exe="
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined app.git.exe set "app.git.exe=%%~fG"
if defined app.git.exe exit /b 0
call :UseTool "%app.prepare.noop.root%\%app.prepare.noop.tools_dir%\git\cmd\git.exe" app.git.exe
if not errorlevel 1 exit /b 0
call :UseTool "%ProgramFiles%\Git\cmd\git.exe" app.git.exe
if not errorlevel 1 exit /b 0
call :UseTool "%LocalAppData%\Programs\Git\cmd\git.exe" app.git.exe
if not errorlevel 1 exit /b 0
exit /b 1
:: ============================================================
:: :ResolveGitHubCli
:: Finds GitHub CLI in PATH or known bundled/system locations and
:: exposes the selected directory through PATH.
::
:: Usage: call :ResolveGitHubCli
::
:: Output:
::   app.github.cli
::   PATH may be prepended with the selected gh.exe directory
::
:: Returns: 0 when found, 1 when missing
:: Requires: where.exe, :UseTool
:: ============================================================
:ResolveGitHubCli
set "app.github.cli="
for /f "delims=" %%G in ('where gh.exe 2^>nul') do if not defined app.github.cli set "app.github.cli=%%~fG"
if defined app.github.cli exit /b 0
call :UseTool "%app.prepare.noop.root%\%app.prepare.noop.tools_dir%\gh\bin\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
call :UseTool "%app.prepare.noop.root%\%app.prepare.noop.tools_dir%\gh\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
call :UseTool "%app.prepare.noop.root%\%app.prepare.noop.tools_dir%\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
call :UseTool "%ProgramFiles%\GitHub CLI\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
call :UseTool "%LocalAppData%\Programs\GitHub CLI\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
exit /b 1
:: ============================================================
:: :UseTool
:: Selects an existing executable, prepends its directory to PATH
:: when needed, and writes the full path to an output variable.
::
:: Usage: call :UseTool "EXE_PATH" outputVariable
::
:: Returns: 0 when executable exists, 1 when missing
:: Requires: :PrependPathIfMissing
:: ============================================================
:UseTool
set "ut_file=%~1"
set "ut_out=%~2"
if not exist "%ut_file%" exit /b 1
for %%A in ("%ut_file%") do set "ut_dir=%%~dpA"
call :PrependPathIfMissing "%ut_dir%"
set "%ut_out%=%ut_file%"
exit /b 0
:: ============================================================
:: :PrepareProject
:: Runs the project-specific preparation lifecycle.
::
:: Readiness return convention:
::   :CheckProjectPreparationReady returns 0 when ready
::   :CheckProjectPreparationReady returns 1 when preparation is needed
::   values greater than 1 mean the readiness check itself failed
::
:: Usage: call :PrepareProject
::
:: Returns: 0 when ready, child error code on failure
:: Requires: project customization functions
:: ============================================================
:PrepareProject
echo Project preparation:
call :CheckProjectPreparationReady
set "pp_check_rc=%errorlevel%"
set "app.prepare.noop.project.check_rc=%pp_check_rc%"
if defined app.prepare.noop.force goto :_PrepareProject_run
if "%pp_check_rc%"=="0" goto :_PrepareProject_apply
if "%pp_check_rc%"=="1" goto :_PrepareProject_run
echo ERROR: Project readiness check failed with exit code %pp_check_rc%.
echo.
exit /b %pp_check_rc%
:_PrepareProject_run
echo   running project preparation operations
call :PrepareProjectOperations
set "pp_rc=%errorlevel%"
if not "%pp_rc%"=="0" goto :_PrepareProject_failed
call :ValidateProjectPreparation
set "pp_rc=%errorlevel%"
if not "%pp_rc%"=="0" goto :_PrepareProject_failed
:_PrepareProject_apply
call :ApplyProjectEnvironment
set "pp_rc=%errorlevel%"
if not "%pp_rc%"=="0" goto :_PrepareProject_failed
call :WriteProjectEnvironmentFile
set "pp_rc=%errorlevel%"
if not "%pp_rc%"=="0" goto :_PrepareProject_failed
if "%pp_check_rc%"=="0" if not defined app.prepare.noop.force echo   already ready; no preparation operations were needed
if not "%pp_check_rc%"=="0" echo   preparation operations completed
if defined app.prepare.noop.force echo   forced preparation operations completed
echo.
echo Project preparation complete.
echo %app.prepare.noop.description%
echo.
exit /b 0
:_PrepareProject_failed
echo ERROR: Project preparation failed with exit code %pp_rc%.
echo.
exit /b %pp_rc%
:: ============================================================
:: :CheckProjectPreparationReady
:: PROJECT CUSTOMIZATION POINT.
::
:: Check whether all project-specific compilers, SDKs, generators,
:: source files, manifests, or other prerequisites are already ready.
::
:: Do not download, install, or modify files in this function.
::
:: Usage: call :CheckProjectPreparationReady
::
:: Returns: 0 when already ready
::          1 when :PrepareProjectOperations should run
::          greater than 1 when the readiness check itself failed
:: Requires: project-specific files/tools when customized
:: ============================================================
:CheckProjectPreparationReady
:: Example:
:: if not exist "%app.prepare.noop.root%\tools\compiler\compiler.exe" exit /b 1
exit /b 0
:: ============================================================
:: :PrepareProjectOperations
:: PROJECT CUSTOMIZATION POINT.
::
:: Put deliberate project preparation operations here. Examples:
::   - call a dedicated downloader or package installer
::   - unpack a compiler or SDK
::   - generate required project files
::   - create tool junctions
::   - repair an incomplete local toolchain
::
:: This no-op template performs no operations by default.
:: It never calls bootstrap.bat.
::
:: Usage: call :PrepareProjectOperations
::
:: Returns: 0 when operations succeed, nonzero on failure
:: Requires: project-specific helpers when customized
:: ============================================================
:PrepareProjectOperations
echo   no project-specific preparation operations are configured
exit /b 0
:: ============================================================
:: :ValidateProjectPreparation
:: PROJECT CUSTOMIZATION POINT.
::
:: Verify that :PrepareProjectOperations produced everything needed.
:: A common implementation calls :CheckProjectPreparationReady and
:: converts a remaining "needs preparation" result into an error.
::
:: Usage: call :ValidateProjectPreparation
::
:: Returns: 0 when prepared output is valid, nonzero otherwise
:: Requires: project-specific files/tools when customized
:: ============================================================
:ValidateProjectPreparation
call :CheckProjectPreparationReady
set "vpp_rc=%errorlevel%"
if "%vpp_rc%"=="0" exit /b 0
if "%vpp_rc%"=="1" echo ERROR: Project requirements remain unavailable after preparation.
if "%vpp_rc%"=="1" exit /b 1
exit /b %vpp_rc%
:: ============================================================
:: :ApplyProjectEnvironment
:: PROJECT CUSTOMIZATION POINT.
::
:: Apply environment variables and PATH additions needed by callers.
:: Because prepare implementations are called in the current cmd.exe,
:: these changes remain available to just_login, just_logout, build,
:: install, and other calling helpers.
::
:: Usage: call :ApplyProjectEnvironment
::
:: Returns: 0 when environment setup succeeds
:: Requires: :PrependPathIfMissing when adding PATH entries
:: ============================================================
:ApplyProjectEnvironment
:: Example:
:: set "COMPILER_HOME=%app.prepare.noop.root%\tools\compiler"
:: call :PrependPathIfMissing "%COMPILER_HOME%\bin"
exit /b 0
:: ============================================================
:: :WriteProjectEnvironmentFile
:: PROJECT CUSTOMIZATION POINT.
::
:: Optionally write a reusable environment file such as env.bat.
:: Leave this function unchanged when persistent environment setup
:: is not needed. The configured path is:
::   %app.prepare.noop.root%\%app.prepare.noop.env_file%
::
:: Usage: call :WriteProjectEnvironmentFile
::
:: Returns: 0 when skipped or written successfully
:: Requires: project-specific environment values when customized
:: ============================================================
:WriteProjectEnvironmentFile
:: Example:
:: >"%app.prepare.noop.root%\%app.prepare.noop.env_file%" echo @echo off
:: >>"%app.prepare.noop.root%\%app.prepare.noop.env_file%" echo set "COMPILER_HOME=%%~dp0tools\compiler"
:: >>"%app.prepare.noop.root%\%app.prepare.noop.env_file%" echo set "PATH=%%COMPILER_HOME%%\bin;%%PATH%%"
exit /b 0
:: ============================================================
:: :PrependPathIfMissing
:: Prepends a directory to PATH only when it is not already present.
::
:: Usage: call :PrependPathIfMissing "directory"
::
:: Returns: 0
:: Requires: findstr.exe
:: ============================================================
:PrependPathIfMissing
set "ppm_dir=%~1"
if not defined ppm_dir exit /b 0
set "ppm_probe=;%PATH%;"
echo(%ppm_probe%| findstr /I /L /C:";%ppm_dir%;" >nul
if errorlevel 1 set "PATH=%ppm_dir%;%PATH%"
exit /b 0
