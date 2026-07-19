@echo off
:: ============================================================
:: prepare.bat
:: General repository and project preparation launcher.
::
:: Repository preparation belongs here because source-control and
:: hosting-provider tools are independent of project type.
::
:: This launcher:
::   - detects source control and repository provider
::   - resolves or installs Git for Git repositories
::   - resolves or installs GitHub CLI for GitHub repositories
::   - exposes selected tools through PATH
::   - never authenticates or logs in
::   - runs project-specific prepare_*.bat files alphabetically
::
:: Authentication remains explicit:
::   call just_login.bat
::
:: Active placement:
::   prepare.bat at the project root
::
:: Template storage:
::   tools\templates\prepare\prepare_launcher.bat
::
:: Ignored implementations:
::   prepare_launcher.bat
::   prepare_config.bat
::   prepare_config_*.bat
::   this launcher's filename
::
:: Project implementations are called in the current cmd.exe and
:: receive the original arguments plus:
::   PREPARE_LAUNCHER_ACTIVE=1
::   PREPARE_PROJECT_ROOT
::   PREPARE_IMPLEMENTATION_DIR
::   PREPARE_SUFFIX
::   app.prepare.suffix
::
:: Usage:
::   call prepare.bat
::   call prepare.bat all
::   call prepare.bat repository
::   call prepare.bat project
::   call prepare.bat check
::   call prepare.bat force
::   call prepare.bat help
::
:: Returns: 0 when requested preparation succeeds
::          1 when setup or required-tool preparation fails
::          first nonzero project implementation result otherwise
:: Requires: cmd.exe, where.exe, findstr.exe
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.prepare_launcher.self=%~nx0"
set "app.prepare_launcher.root="
set "app.prepare_launcher.dir="
set "app.prepare_launcher.request=all"
set "app.prepare_launcher.arguments=%*"
set "app.prepare_launcher.force="
set "app.prepare_launcher.candidate="
set "app.prepare_launcher.file="
set "app.prepare_launcher.suffix="
set "app.prepare_launcher.total=0"
set "app.prepare_launcher.skipped=0"
set "app.prepare_launcher.ok=0"
set "app.prepare_launcher.failed=0"
set "app.prepare_launcher.rc=0"
set "app.prepare_launcher.shared_config="
set "app.prepare_launcher.repository.url="
set "app.prepare_launcher.scm="
set "app.prepare_launcher.provider="
set "app.prepare_launcher.tools_dir=tools"
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
if not "%app.prepare_launcher.rc%"=="0" goto :end
call :LoadConfiguration
set "app.prepare_launcher.rc=%errorlevel%"
if not "%app.prepare_launcher.rc%"=="0" goto :end
call :ParseArguments %*
set "app.prepare_launcher.rc=%errorlevel%"
if not "%app.prepare_launcher.rc%"=="0" goto :end
call :Main %*
set "app.prepare_launcher.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.prepare_launcher.rc%
:: ============================================================
:: :Main
:: Dispatches repository preparation and project implementations.
::
:: Usage: call :Main [arguments]
::
:: Returns: requested preparation result
:: Requires: :ShowHelp, :PrepareRepository, :CheckRepository,
::           :RunProjectImplementations
:: ============================================================
:Main
if /I "%app.prepare_launcher.request%"=="help" call :ShowHelp
if /I "%app.prepare_launcher.request%"=="help" exit /b %errorlevel%
pushd "%app.prepare_launcher.root%" >nul 2>nul
if errorlevel 1 goto :_Main_root_error
if /I "%app.prepare_launcher.request%"=="repository" call :PrepareRepository
if /I "%app.prepare_launcher.request%"=="repository" set "pm_rc=%errorlevel%"
if /I "%app.prepare_launcher.request%"=="repository" goto :_Main_done
if /I "%app.prepare_launcher.request%"=="check" call :CheckRepository
if /I "%app.prepare_launcher.request%"=="check" set "pm_rc=%errorlevel%"
if /I "%app.prepare_launcher.request%"=="check" if not "%pm_rc%"=="0" goto :_Main_done
if /I "%app.prepare_launcher.request%"=="check" call :RunProjectImplementations %*
if /I "%app.prepare_launcher.request%"=="check" set "pm_rc=%errorlevel%"
if /I "%app.prepare_launcher.request%"=="check" goto :_Main_done
if /I "%app.prepare_launcher.request%"=="project" call :RunProjectImplementations %*
if /I "%app.prepare_launcher.request%"=="project" set "pm_rc=%errorlevel%"
if /I "%app.prepare_launcher.request%"=="project" goto :_Main_done
call :PrepareRepository
set "pm_rc=%errorlevel%"
if not "%pm_rc%"=="0" goto :_Main_done
call :RunProjectImplementations %*
set "pm_rc=%errorlevel%"
:_Main_done
popd >nul
exit /b %pm_rc%
:_Main_root_error
echo %app.prepare_launcher.color.error%ERROR: Could not enter the project root.%app.prepare_launcher.color.reset%
exit /b 1
:: ============================================================
:: :ParseArguments
:: Detects general preparation scope while preserving the original
:: arguments for project implementations.
::
:: Usage: call :ParseArguments [arguments]
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ParseArguments
if "%~1"=="" exit /b 0
if /I "%~1"=="all" set "app.prepare_launcher.request=all"
if /I "%~1"=="repository" set "app.prepare_launcher.request=repository"
if /I "%~1"=="git" set "app.prepare_launcher.request=repository"
if /I "%~1"=="github" set "app.prepare_launcher.request=repository"
if /I "%~1"=="project" set "app.prepare_launcher.request=project"
if /I "%~1"=="tools" set "app.prepare_launcher.request=project"
if /I "%~1"=="check" set "app.prepare_launcher.request=check"
if /I "%~1"=="help" set "app.prepare_launcher.request=help"
if /I "%~1"=="--help" set "app.prepare_launcher.request=help"
if /I "%~1"=="/help" set "app.prepare_launcher.request=help"
if /I "%~1"=="/?" set "app.prepare_launcher.request=help"
if /I "%~1"=="force" set "app.prepare_launcher.force=1"
if /I "%~1"=="--force" set "app.prepare_launcher.force=1"
if /I "%~1"=="/force" set "app.prepare_launcher.force=1"
shift
goto :ParseArguments
:: ============================================================
:: :ShowHelp
:: Prints scopes and authentication boundaries.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo prepare.bat
echo.
echo Usage:
echo   prepare.bat
echo   prepare.bat all
echo   prepare.bat repository
echo   prepare.bat project
echo   prepare.bat check
echo   prepare.bat force
echo   prepare.bat help
echo.
echo Scopes:
echo   all          Prepare repository tools, then project tools.
echo   repository   Resolve or install repository clients only.
echo   project      Run project-specific prepare_*.bat files only.
echo   check        Check repository and project readiness only.
echo.
echo Repository preparation never logs in.
echo Use just_login.bat when authentication is explicitly wanted.
echo.
exit /b 0
:: ============================================================
:: :ResolvePaths
:: Resolves the project root and implementation directory.
::
:: Usage: call :ResolvePaths
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ResolvePaths
for %%A in ("%~dp0.") do set "app.prepare_launcher.root=%%~fA"
set "app.prepare_launcher.dir=%app.prepare_launcher.root%"
set "app.prepare_launcher.shared_config=%app.prepare_launcher.root%\build_config.bat"
exit /b 0
:: ============================================================
:: :LoadConfiguration
:: Loads shared repository metadata when available.
::
:: Usage: call :LoadConfiguration
::
:: Returns: 0 when absent/successful, child result on failure
:: Requires: optional build_config.bat
:: ============================================================
:LoadConfiguration
if not exist "%app.prepare_launcher.shared_config%" exit /b 0
call "%app.prepare_launcher.shared_config%"
set "plc_rc=%errorlevel%"
if "%plc_rc%"=="0" exit /b 0
echo.
echo %app.prepare_launcher.color.error%ERROR: Shared configuration failed:%app.prepare_launcher.color.reset%
echo   "%app.prepare_launcher.shared_config%"
echo.
exit /b %plc_rc%
:: ============================================================
:: :PrepareRepository
:: Resolves or installs repository clients without authenticating.
::
:: Usage: call :PrepareRepository
::
:: Returns: 0 when repository machinery is ready
:: Requires: :DetectRepository, :ResolveSourceControlClient,
::           :ResolveProviderClient
:: ============================================================
:PrepareRepository
call :DetectRepository
set "pr_rc=%errorlevel%"
if not "%pr_rc%"=="0" exit /b %pr_rc%
call :ResolveSourceControlClient prepare
set "pr_rc=%errorlevel%"
if not "%pr_rc%"=="0" exit /b %pr_rc%
call :DetectRepository
set "pr_rc=%errorlevel%"
if not "%pr_rc%"=="0" exit /b %pr_rc%
call :ShowRepositorySummary
call :ResolveProviderClient prepare
set "pr_rc=%errorlevel%"
if not "%pr_rc%"=="0" exit /b %pr_rc%
call :ShowRepositoryToolsReady
echo Repository preparation complete.
echo Authentication was not requested or performed.
echo.
exit /b 0
:: ============================================================
:: :CheckRepository
:: Checks repository client readiness without installing software.
::
:: Usage: call :CheckRepository
::
:: Returns: 0 when repository machinery is ready
:: Requires: :DetectRepository, :ResolveSourceControlClient,
::           :ResolveProviderClient
:: ============================================================
:CheckRepository
call :DetectRepository
set "cr_rc=%errorlevel%"
if not "%cr_rc%"=="0" exit /b %cr_rc%
call :ResolveSourceControlClient check
set "cr_rc=%errorlevel%"
if not "%cr_rc%"=="0" exit /b %cr_rc%
call :DetectRepository
set "cr_rc=%errorlevel%"
if not "%cr_rc%"=="0" exit /b %cr_rc%
call :ShowRepositorySummary
call :ResolveProviderClient check
set "cr_rc=%errorlevel%"
if not "%cr_rc%"=="0" exit /b %cr_rc%
call :ShowRepositoryToolsReady
echo Repository readiness check passed.
echo.
exit /b 0
:: ============================================================
:: :DetectRepository
:: Detects source control, provider, and repository URL.
::
:: Usage: call :DetectRepository
::
:: Returns: 0
:: Requires: optional git.exe, findstr.exe
:: ============================================================
:DetectRepository
set "app.prepare_launcher.repository.url="
set "app.prepare_launcher.scm="
set "app.prepare_launcher.provider="
if defined app.repository.scm set "app.prepare_launcher.scm=%app.repository.scm%"
if not defined app.prepare_launcher.scm if defined app.scm set "app.prepare_launcher.scm=%app.scm%"
if defined app.repository.provider set "app.prepare_launcher.provider=%app.repository.provider%"
if not defined app.prepare_launcher.provider if defined app.repo_provider set "app.prepare_launcher.provider=%app.repo_provider%"
if defined app.repository.url set "app.prepare_launcher.repository.url=%app.repository.url%"
if not defined app.prepare_launcher.repository.url if defined app.repo_url set "app.prepare_launcher.repository.url=%app.repo_url%"
set "pdr_origin="
where git.exe >nul 2>nul
if errorlevel 1 goto :_DetectRepository_metadata
for /f "delims=" %%U in ('git.exe remote get-url origin 2^>nul') do if not defined pdr_origin set "pdr_origin=%%U"
if defined pdr_origin set "app.prepare_launcher.repository.url=%pdr_origin%"
:_DetectRepository_metadata
if not defined app.prepare_launcher.scm if exist "%app.prepare_launcher.root%\.git\" set "app.prepare_launcher.scm=git"
if not defined app.prepare_launcher.scm if defined app.prepare_launcher.repository.url set "app.prepare_launcher.scm=git"
if not defined app.prepare_launcher.scm set "app.prepare_launcher.scm=none"
if defined app.prepare_launcher.provider goto :_DetectRepository_done
if not defined app.prepare_launcher.repository.url goto :_DetectRepository_generic
echo(%app.prepare_launcher.repository.url%| findstr /I /C:"github.com" >nul
if not errorlevel 1 (set "app.prepare_launcher.provider=github" & goto :_DetectRepository_done)
echo(%app.prepare_launcher.repository.url%| findstr /I /C:"gitlab.com" >nul
if not errorlevel 1 (set "app.prepare_launcher.provider=gitlab" & goto :_DetectRepository_done)
echo(%app.prepare_launcher.repository.url%| findstr /I /C:"bitbucket.org" >nul
if not errorlevel 1 (set "app.prepare_launcher.provider=bitbucket" & goto :_DetectRepository_done)
echo(%app.prepare_launcher.repository.url%| findstr /I /C:"codeberg.org" >nul
if not errorlevel 1 (set "app.prepare_launcher.provider=codeberg" & goto :_DetectRepository_done)
:_DetectRepository_generic
if /I "%app.prepare_launcher.scm%"=="none" (set "app.prepare_launcher.provider=none" & goto :_DetectRepository_done)
set "app.prepare_launcher.provider=generic"
:_DetectRepository_done
set "app.repository.scm=%app.prepare_launcher.scm%"
set "app.repository.provider=%app.prepare_launcher.provider%"
if defined app.prepare_launcher.repository.url set "app.repository.url=%app.prepare_launcher.repository.url%"
exit /b 0
:: ============================================================
:: :ShowRepositorySummary
:: Prints detected repository information.
::
:: Usage: call :ShowRepositorySummary
::
:: Returns: 0
:: Requires: :DetectRepository
:: ============================================================
:ShowRepositorySummary
echo.
echo %app.prepare_launcher.color.title%============================================================%app.prepare_launcher.color.reset%
echo %app.prepare_launcher.color.title% Repository preparation%app.prepare_launcher.color.reset%
echo %app.prepare_launcher.color.title%============================================================%app.prepare_launcher.color.reset%
echo.
echo Project root:
echo   %app.prepare_launcher.root%
echo.
echo Source control:
echo   %app.prepare_launcher.scm%
echo.
echo Provider:
echo   %app.prepare_launcher.provider%
echo.
echo Repository URL:
if defined app.prepare_launcher.repository.url echo   %app.prepare_launcher.repository.url%
if not defined app.prepare_launcher.repository.url echo   not configured
echo.
exit /b 0
:: ============================================================
:: :ShowRepositoryToolsReady
:: Prints resolved repository client paths.
::
:: Usage: call :ShowRepositoryToolsReady
::
:: Returns: 0
:: Requires: resolved client variables
:: ============================================================
:ShowRepositoryToolsReady
echo Repository tools are ready.
if defined app.git.exe echo   Git: %app.git.exe%
if defined app.github.cli echo   GitHub CLI: %app.github.cli%
echo.
exit /b 0
:: ============================================================
:: :ResolveSourceControlClient
:: Resolves or installs the required source-control client.
::
:: Usage: call :ResolveSourceControlClient prepare^|check
::
:: Returns: 0 when ready, nonzero when missing
:: Requires: :ResolveGit, :InstallGit
:: ============================================================
:ResolveSourceControlClient
if /I "%app.prepare_launcher.scm%"=="none" exit /b 0
if /I "%app.prepare_launcher.scm%"=="git" goto :_ResolveSourceControlClient_git
call :ResolveCustomSourceControlClient "%app.prepare_launcher.scm%" "%~1"
exit /b %errorlevel%
:_ResolveSourceControlClient_git
call :ResolveGit
set "rsc_rc=%errorlevel%"
if "%rsc_rc%"=="0" exit /b 0
if /I "%~1"=="prepare" call :InstallGit
if /I "%~1"=="prepare" set "rsc_rc=%errorlevel%"
if /I "%~1"=="prepare" if "%rsc_rc%"=="0" exit /b 0
echo %app.prepare_launcher.color.error%ERROR: Git is required for this repository but was not found.%app.prepare_launcher.color.reset%
echo.
exit /b 1
:: ============================================================
:: :ResolveProviderClient
:: Resolves or installs the provider-specific client.
::
:: Usage: call :ResolveProviderClient prepare^|check
::
:: Returns: 0 when ready, nonzero when missing
:: Requires: :ResolveGitHubCli, :InstallGitHubCli
:: ============================================================
:ResolveProviderClient
if /I "%app.prepare_launcher.provider%"=="none" exit /b 0
if /I "%app.prepare_launcher.provider%"=="generic" exit /b 0
if /I "%app.prepare_launcher.provider%"=="github" goto :_ResolveProviderClient_github
call :ResolveCustomRepositoryProviderClient "%app.prepare_launcher.provider%" "%~1"
exit /b %errorlevel%
:_ResolveProviderClient_github
call :ResolveGitHubCli
set "rpc_rc=%errorlevel%"
if "%rpc_rc%"=="0" exit /b 0
if /I "%~1"=="prepare" call :InstallGitHubCli
if /I "%~1"=="prepare" set "rpc_rc=%errorlevel%"
if /I "%~1"=="prepare" if "%rpc_rc%"=="0" exit /b 0
echo %app.prepare_launcher.color.error%ERROR: GitHub CLI is required to make repository login machinery ready.%app.prepare_launcher.color.reset%
echo.
exit /b 1
:: ============================================================
:: :ResolveCustomSourceControlClient
:: Customization point for non-Git source control.
::
:: Usage: call :ResolveCustomSourceControlClient "scm" prepare^|check
::
:: Returns: 0 by default
:: Requires: none
:: ============================================================
:ResolveCustomSourceControlClient
echo %app.prepare_launcher.color.warn%WARNING: No client resolver is configured for source control "%~1".%app.prepare_launcher.color.reset%
echo.
exit /b 0
:: ============================================================
:: :ResolveCustomRepositoryProviderClient
:: Customization point for non-GitHub providers.
::
:: Usage: call :ResolveCustomRepositoryProviderClient "provider" prepare^|check
::
:: Returns: 0 by default
:: Requires: none
:: ============================================================
:ResolveCustomRepositoryProviderClient
exit /b 0
:: ============================================================
:: :ResolveGit
:: Finds Git and exposes its directory through PATH.
::
:: Usage: call :ResolveGit
::
:: Returns: 0 when found, 1 when missing
:: Requires: where.exe, :UseTool
:: ============================================================
:ResolveGit
set "app.git.exe="
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined app.git.exe set "app.git.exe=%%~fG"
if defined app.git.exe exit /b 0
call :UseTool "%app.prepare_launcher.root%\%app.prepare_launcher.tools_dir%\git\cmd\git.exe" app.git.exe
if not errorlevel 1 exit /b 0
call :UseTool "%TEMP%\tools\git\cmd\git.exe" app.git.exe
if not errorlevel 1 exit /b 0
call :UseTool "%ProgramFiles%\Git\cmd\git.exe" app.git.exe
if not errorlevel 1 exit /b 0
call :UseTool "%LocalAppData%\Programs\Git\cmd\git.exe" app.git.exe
if not errorlevel 1 exit /b 0
exit /b 1
:: ============================================================
:: :InstallGit
:: Runs tools\GetGit.bat and resolves Git afterward.
::
:: Usage: call :InstallGit
::
:: Returns: 0 when Git is ready, nonzero otherwise
:: Requires: tools\GetGit.bat, :ResolveGit
:: ============================================================
:InstallGit
set "pig_helper=%app.prepare_launcher.root%\%app.prepare_launcher.tools_dir%\GetGit.bat"
if exist "%pig_helper%" goto :_InstallGit_run
echo %app.prepare_launcher.color.error%ERROR: Git installer was not found:%app.prepare_launcher.color.reset%
echo   "%pig_helper%"
echo.
exit /b 1
:_InstallGit_run
echo Installing Git:
echo   "%pig_helper%"
echo.
pushd "%app.prepare_launcher.root%" >nul 2>nul
if errorlevel 1 exit /b 1
call "%pig_helper%"
set "pig_rc=%errorlevel%"
popd >nul
if not "%pig_rc%"=="0" exit /b %pig_rc%
call :ResolveGit
exit /b %errorlevel%
:: ============================================================
:: :ResolveGitHubCli
:: Finds GitHub CLI and exposes its directory through PATH.
::
:: Usage: call :ResolveGitHubCli
::
:: Returns: 0 when found, 1 when missing
:: Requires: where.exe, :UseTool
:: ============================================================
:ResolveGitHubCli
set "app.github.cli="
for /f "delims=" %%G in ('where gh.exe 2^>nul') do if not defined app.github.cli set "app.github.cli=%%~fG"
if defined app.github.cli exit /b 0
call :UseTool "%app.prepare_launcher.root%\%app.prepare_launcher.tools_dir%\gh\bin\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
call :UseTool "%app.prepare_launcher.root%\%app.prepare_launcher.tools_dir%\gh\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
call :UseTool "%app.prepare_launcher.root%\%app.prepare_launcher.tools_dir%\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
call :UseTool "%TEMP%\tools\gh\bin\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
call :UseTool "%ProgramFiles%\GitHub CLI\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
call :UseTool "%LocalAppData%\Programs\GitHub CLI\gh.exe" app.github.cli
if not errorlevel 1 exit /b 0
exit /b 1
:: ============================================================
:: :InstallGitHubCli
:: Runs tools\GetGithubCLI.bat and resolves gh.exe afterward.
:: It installs the client but never logs in.
::
:: Usage: call :InstallGitHubCli
::
:: Returns: 0 when GitHub CLI is ready, nonzero otherwise
:: Requires: tools\GetGithubCLI.bat, :ResolveGitHubCli
:: ============================================================
:InstallGitHubCli
set "pgh_helper=%app.prepare_launcher.root%\%app.prepare_launcher.tools_dir%\GetGithubCLI.bat"
if exist "%pgh_helper%" goto :_InstallGitHubCli_run
echo %app.prepare_launcher.color.error%ERROR: GitHub CLI installer was not found:%app.prepare_launcher.color.reset%
echo   "%pgh_helper%"
echo.
exit /b 1
:_InstallGitHubCli_run
echo Installing GitHub CLI:
echo   "%pgh_helper%"
echo.
pushd "%app.prepare_launcher.root%" >nul 2>nul
if errorlevel 1 exit /b 1
call "%pgh_helper%"
set "pgh_rc=%errorlevel%"
popd >nul
if not "%pgh_rc%"=="0" exit /b %pgh_rc%
call :ResolveGitHubCli
exit /b %errorlevel%
:: ============================================================
:: :UseTool
:: Selects an executable, prepends its directory to PATH, and sets
:: the requested output variable.
::
:: Usage: call :UseTool "EXE_PATH" outputVariable
::
:: Returns: 0 when found, 1 when missing
:: Requires: :PrependPathIfMissing
:: ============================================================
:UseTool
set "put_file=%~1"
set "put_out=%~2"
if not exist "%put_file%" exit /b 1
for %%A in ("%put_file%") do set "put_dir=%%~dpA"
call :PrependPathIfMissing "%put_dir%"
set "%put_out%=%put_file%"
exit /b 0
:: ============================================================
:: :PrependPathIfMissing
:: Prepends a directory to PATH when not already present.
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
:: ============================================================
:: :RunProjectImplementations
:: Runs and summarizes eligible project prepare implementations.
::
:: Usage: call :RunProjectImplementations [arguments]
::
:: Returns: aggregate implementation result
:: Requires: :RunCandidate, dir
:: ============================================================
:RunProjectImplementations
set "app.prepare_launcher.total=0"
set "app.prepare_launcher.skipped=0"
set "app.prepare_launcher.ok=0"
set "app.prepare_launcher.failed=0"
set "app.prepare_launcher.rc=0"
echo.
echo %app.prepare_launcher.color.title%============================================================%app.prepare_launcher.color.reset%
echo %app.prepare_launcher.color.title% Project preparation launcher%app.prepare_launcher.color.reset%
echo %app.prepare_launcher.color.title%============================================================%app.prepare_launcher.color.reset%
echo.
echo Project root:
echo   %app.prepare_launcher.root%
echo.
echo Arguments:
if "%~1"=="" echo   none
if not "%~1"=="" echo   %*
echo.
for /f "delims=" %%F in ('dir /b /a-d /on "%app.prepare_launcher.dir%\prepare_*.bat" 2^>nul') do (
set "app.prepare_launcher.candidate=%%F"
call :RunCandidate %*
)
if not "%app.prepare_launcher.total%"=="0" goto :_RunProjectImplementations_summary
echo %app.prepare_launcher.color.error%ERROR: No eligible project prepare implementations were found.%app.prepare_launcher.color.reset%
echo.
exit /b 1
:_RunProjectImplementations_summary
echo.
echo %app.prepare_launcher.color.title%============================================================%app.prepare_launcher.color.reset%
echo %app.prepare_launcher.color.title% Project prepare summary%app.prepare_launcher.color.reset%
echo %app.prepare_launcher.color.title%============================================================%app.prepare_launcher.color.reset%
echo.
echo Implementations run: %app.prepare_launcher.total%
echo Succeeded:           %app.prepare_launcher.ok%
echo Failed:              %app.prepare_launcher.failed%
echo Ignored:             %app.prepare_launcher.skipped%
echo.
if "%app.prepare_launcher.failed%"=="0" goto :_RunProjectImplementations_success
echo %app.prepare_launcher.color.error%One or more project prepare implementations failed.%app.prepare_launcher.color.reset%
exit /b %app.prepare_launcher.rc%
:_RunProjectImplementations_success
echo %app.prepare_launcher.color.ok%All project prepare implementations completed successfully.%app.prepare_launcher.color.reset%
exit /b 0
:: ============================================================
:: :RunCandidate
:: Calls one project prepare implementation in the current cmd.exe.
::
:: Usage: call :RunCandidate [forwarded arguments]
::
:: Returns: 0 so enumeration continues
:: Requires: :ShouldIgnore
:: ============================================================
:RunCandidate
call :ShouldIgnore "%app.prepare_launcher.candidate%"
set "prc_ignore_rc=%errorlevel%"
if "%prc_ignore_rc%"=="0" goto :_RunCandidate_skip
set "app.prepare_launcher.suffix=%app.prepare_launcher.candidate:~8,-4%"
if defined app.prepare_launcher.suffix goto :_RunCandidate_run
set /a app.prepare_launcher.skipped+=1 >nul
exit /b 0
:_RunCandidate_skip
echo %app.prepare_launcher.color.info%[SKIP] %app.prepare_launcher.candidate%%app.prepare_launcher.color.reset%
set /a app.prepare_launcher.skipped+=1 >nul
exit /b 0
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
set "prc_child_rc=%errorlevel%"
set "PREPARE_LAUNCHER_ACTIVE="
set "PREPARE_PROJECT_ROOT="
set "PREPARE_IMPLEMENTATION_DIR="
set "PREPARE_SUFFIX="
set "app.prepare.suffix="
if "%prc_child_rc%"=="0" goto :_RunCandidate_ok
set /a app.prepare_launcher.failed+=1 >nul
if not "%app.prepare_launcher.rc%"=="0" goto :_RunCandidate_report_fail
set "app.prepare_launcher.rc=%prc_child_rc%"
:_RunCandidate_report_fail
echo.
echo %app.prepare_launcher.color.error%[FAIL] %app.prepare_launcher.candidate% returned %prc_child_rc%.%app.prepare_launcher.color.reset%
exit /b 0
:_RunCandidate_ok
set /a app.prepare_launcher.ok+=1 >nul
echo.
echo %app.prepare_launcher.color.ok%[ OK ] %app.prepare_launcher.candidate%%app.prepare_launcher.color.reset%
exit /b 0
:: ============================================================
:: :ShouldIgnore
:: Identifies launcher and configuration files.
::
:: Usage: call :ShouldIgnore FILE_NAME
::
:: Returns: 0 to ignore, 1 to run
:: Requires: none
:: ============================================================
:ShouldIgnore
set "psi_name=%~1"
if /I "%psi_name%"=="%app.prepare_launcher.self%" exit /b 0
if /I "%psi_name%"=="prepare_launcher.bat" exit /b 0
if /I "%psi_name%"=="prepare_config.bat" exit /b 0
if /I "%psi_name:~0,15%"=="prepare_config_" exit /b 0
exit /b 1
:: ============================================================
:: :InitColors
:: Enables ANSI color when supported.
::
:: Usage: call :InitColors
::
:: Returns: 0
:: Requires: prompt
:: ============================================================
:InitColors
if defined NO_COLOR exit /b 0
if /I "%app.prepare_launcher.color.mode%"=="never" exit /b 0
if /I "%app.prepare_launcher.color.mode%"=="always" goto :_InitColors_enable
if defined WT_SESSION goto :_InitColors_enable
if defined ANSICON goto :_InitColors_enable
if /I "%ConEmuANSI%"=="ON" goto :_InitColors_enable
if defined TERM goto :_InitColors_enable
if defined COLORTERM goto :_InitColors_enable
exit /b 0
:_InitColors_enable
set "pic_esc="
for /f "delims=#" %%E in ('"prompt #$E# & for %%B in (1) do rem"') do set "pic_esc=%%E"
if not defined pic_esc exit /b 0
set "app.prepare_launcher.color.reset=%pic_esc%[0m"
set "app.prepare_launcher.color.title=%pic_esc%[96m"
set "app.prepare_launcher.color.info=%pic_esc%[94m"
set "app.prepare_launcher.color.ok=%pic_esc%[92m"
set "app.prepare_launcher.color.warn=%pic_esc%[93m"
set "app.prepare_launcher.color.error=%pic_esc%[91m"
exit /b 0
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when the outermost launcher is cmd.exe /c target.
::
:: Usage: call :PauseIfNeeded
::
:: Returns: 0
:: Requires: :IsConsole
:: ============================================================
:PauseIfNeeded
call :IsConsole
if not errorlevel 1 exit /b 0
echo.
pause
exit /b 0
:: ============================================================
:: :IsConsole
:: Detects an existing console versus outer cmd.exe /c execution.
::
:: Usage: call :IsConsole
::
:: Returns: 0 for existing console, 1 for outer cmd.exe /c target
:: Requires: find.exe
:: ============================================================
:IsConsole
setlocal EnableDelayedExpansion
set "pic_cmdline=!CMDCMDLINE!"
echo(!pic_cmdline!| "%SystemRoot%\System32\find.exe" /I " /c " >nul
if errorlevel 1 (endlocal & exit /b 0)
echo(!pic_cmdline!| "%SystemRoot%\System32\find.exe" /I "!app.launch.name!" >nul
if errorlevel 1 (endlocal & exit /b 0)
endlocal & exit /b 1
