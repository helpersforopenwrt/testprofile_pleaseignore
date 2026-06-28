@echo off
:: ============================================================
:: prepare_noop.bat
:: Generic baseline preparation for projects without a dedicated
:: build-system preparer.
::
:: Despite the "noop" suffix, repository preparation is functional:
::   - detects the source-control system
::   - detects the repository hosting provider
::   - ensures Git is available for Git repositories
::   - ensures GitHub CLI is available only for GitHub repositories
::   - exposes already-installed or locally bundled tools through PATH
::   - never downloads, installs, or invokes bootstrap helpers
::
:: Detection order:
::   1. explicit configuration variables
::   2. Git origin remote URL
::   3. app.repo_url
::   4. project metadata such as a .git directory
::
:: Optional configuration:
::   app.repository.scm=git
::   app.repository.provider=github
::   app.repo_url=https://github.com/owner/repository.git
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
::   call prepare_noop.bat [all|repository|git|github|help]
::
:: Returns: 0 when requested preparation is ready
::          1 when required software remains unavailable
::          config exit code when one fails
:: Requires: where.exe; Git only for Git repositories
:: ============================================================
:setup
set "app.prepare.noop.rc=0"
set "app.prepare.noop.root="
set "app.prepare.noop.request=%~1"
set "app.prepare.noop.arguments=%*"
set "app.prepare.noop.shared_config="
set "app.prepare.noop.suffix_config="
set "app.prepare.noop.repository.url="
set "app.prepare.noop.scm="
set "app.prepare.noop.provider="
set "app.prepare.noop.title="
set "app.prepare.noop.description="
set "app.prepare.suffix=noop"
if not defined PREPARE_SUFFIX set "PREPARE_SUFFIX=noop"
if not defined app.prepare.noop.request set "app.prepare.noop.request=all"
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
if not defined app.prepare.noop.title set "app.prepare.noop.title=%app.display_name% baseline preparation"
if not defined app.prepare.noop.title set "app.prepare.noop.title=Baseline project preparation"
if not defined app.prepare.noop.description set "app.prepare.noop.description=No build-system-specific preparation is required."
if /I "%app.prepare.noop.request%"=="help" goto :help
if /I "%app.prepare.noop.request%"=="--help" goto :help
if /I "%app.prepare.noop.request%"=="/help" goto :help
if /I "%app.prepare.noop.request%"=="/?" goto :help
cd /d "%app.prepare.noop.root%"
set "app.prepare.noop.rc=%errorlevel%"
if "%app.prepare.noop.rc%"=="0" goto :dispatch
echo.
echo ERROR: Could not enter the project root.
echo.
set "app.prepare.noop.rc=1"
goto :end
:dispatch
if /I "%app.prepare.noop.request%"=="repository" goto :repository
if /I "%app.prepare.noop.request%"=="git" goto :repository
if /I "%app.prepare.noop.request%"=="github" goto :repository
if /I "%app.prepare.noop.request%"=="all" goto :repository
goto :generic
:repository
call :PrepareRepository
set "app.prepare.noop.rc=%errorlevel%"
goto :end
:generic
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
echo   %app.prepare.noop.arguments%
echo.
echo Baseline preparation complete.
echo %app.prepare.noop.description%
echo.
set "app.prepare.noop.rc=0"
goto :end
:help
echo.
echo prepare_noop.bat
echo.
echo Usage:
echo   prepare_noop.bat
echo   prepare_noop.bat repository
echo   prepare_noop.bat git
echo   prepare_noop.bat github
echo.
echo Repository preparation detects the source-control system and
echo hosting provider before deciding which command-line tools are
echo required. GitHub CLI is required only for GitHub repositories.
echo No software is downloaded or installed automatically.
echo.
set "app.prepare.noop.rc=0"
:end
exit /b %app.prepare.noop.rc%
:: ============================================================
:: :PrepareRepository
:: Detects repository technology and ensures the required tools.
::
:: Usage: call :PrepareRepository
::
:: Returns: 0 when ready
::          1 when required software is unavailable
:: Requires: :DetectRepository, :ResolveGit, :ResolveGitHubCli
:: ============================================================
:PrepareRepository
for /f "tokens=1 delims==" %%v in ('set prp_ 2^>nul') do set "%%v="
if defined _prp_rc (set "_prp_rc=" & exit /b %_prp_rc%)
call :DetectRepository
echo.
echo ============================================================
echo  %app.prepare.noop.title%
echo ============================================================
echo.
echo Project root:
echo   %app.prepare.noop.root%
echo.
echo Source control:
echo   %app.prepare.noop.scm%
echo.
echo Repository provider:
echo   %app.prepare.noop.provider%
echo.
echo Repository URL:
if defined app.prepare.noop.repository.url goto :_PrepareRepository_show_url
echo   not configured
goto :_PrepareRepository_tools
:_PrepareRepository_show_url
echo   %app.prepare.noop.repository.url%
:_PrepareRepository_tools
echo.
if /I not "%app.prepare.noop.scm%"=="git" goto :_PrepareRepository_non_git
call :ResolveGit
if not errorlevel 1 goto :_PrepareRepository_provider
echo ERROR: Git is required for this repository but was not found.
echo Install Git or place a bundled copy at:
echo   "%app.prepare.noop.root%\tools\git\cmd\git.exe"
set "_prp_rc=1" & goto :PrepareRepository
:_PrepareRepository_provider
if /I not "%app.prepare.noop.provider%"=="github" goto :_PrepareRepository_ready
call :ResolveGitHubCli
if not errorlevel 1 goto :_PrepareRepository_ready
echo ERROR: GitHub CLI is required for this GitHub repository but was not found.
echo Install GitHub CLI or place a bundled copy at one of:
echo   "%app.prepare.noop.root%\tools\gh\bin\gh.exe"
echo   "%app.prepare.noop.root%\tools\gh\gh.exe"
echo   "%app.prepare.noop.root%\tools\gh.exe"
set "_prp_rc=1" & goto :PrepareRepository
:_PrepareRepository_non_git
if /I "%app.prepare.noop.scm%"=="none" echo No source-control client is required.
if /I not "%app.prepare.noop.scm%"=="none" echo No baseline preparer is registered for source control "%app.prepare.noop.scm%".
:_PrepareRepository_ready
echo.
echo Repository preparation complete.
if defined app.git.exe echo Git: %app.git.exe%
if defined app.github.cli echo GitHub CLI: %app.github.cli%
echo.
set "_prp_rc=0" & goto :PrepareRepository
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
::
:: Returns: 0
:: Requires: git.exe when available, findstr.exe
:: ============================================================
:DetectRepository
for /f "tokens=1 delims==" %%v in ('set prd_ 2^>nul') do set "%%v="
if defined _prd_rc (set "_prd_rc=" & exit /b %_prd_rc%)
if defined app.repository.scm set "app.prepare.noop.scm=%app.repository.scm%"
if not defined app.prepare.noop.scm if defined app.scm set "app.prepare.noop.scm=%app.scm%"
if defined app.repository.provider set "app.prepare.noop.provider=%app.repository.provider%"
if not defined app.prepare.noop.provider if defined app.repo_provider set "app.prepare.noop.provider=%app.repo_provider%"
if defined app.repo_url set "app.prepare.noop.repository.url=%app.repo_url%"
where git.exe >nul 2>nul
if errorlevel 1 goto :_DetectRepository_metadata
for /f "usebackq delims=" %%U in (`git remote get-url origin 2^>nul`) do if not defined prd_origin set "prd_origin=%%U"
if defined prd_origin set "app.prepare.noop.repository.url=%prd_origin%"
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
set "_prd_rc=0" & goto :DetectRepository
:: ============================================================
:: :ResolveGit
:: Finds Git in PATH or known local/system locations and exports it.
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
for /f "tokens=1 delims==" %%v in ('set prg_ 2^>nul') do set "%%v="
if defined _prg_rc (set "_prg_rc=" & exit /b %_prg_rc%)
set "app.git.exe="
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined app.git.exe set "app.git.exe=%%~fG"
if defined app.git.exe (set "_prg_rc=0" & goto :ResolveGit)
call :UseTool "%app.prepare.noop.root%\tools\git\cmd\git.exe" app.git.exe
if not errorlevel 1 (set "_prg_rc=0" & goto :ResolveGit)
call :UseTool "%ProgramFiles%\Git\cmd\git.exe" app.git.exe
if not errorlevel 1 (set "_prg_rc=0" & goto :ResolveGit)
call :UseTool "%LocalAppData%\Programs\Git\cmd\git.exe" app.git.exe
if not errorlevel 1 (set "_prg_rc=0" & goto :ResolveGit)
set "_prg_rc=1" & goto :ResolveGit
:: ============================================================
:: :ResolveGitHubCli
:: Finds GitHub CLI in PATH or known local/system locations.
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
for /f "tokens=1 delims==" %%v in ('set prh_ 2^>nul') do set "%%v="
if defined _prh_rc (set "_prh_rc=" & exit /b %_prh_rc%)
set "app.github.cli="
for /f "delims=" %%G in ('where gh.exe 2^>nul') do if not defined app.github.cli set "app.github.cli=%%~fG"
if defined app.github.cli (set "_prh_rc=0" & goto :ResolveGitHubCli)
call :UseTool "%app.prepare.noop.root%\tools\gh\bin\gh.exe" app.github.cli
if not errorlevel 1 (set "_prh_rc=0" & goto :ResolveGitHubCli)
call :UseTool "%app.prepare.noop.root%\tools\gh\gh.exe" app.github.cli
if not errorlevel 1 (set "_prh_rc=0" & goto :ResolveGitHubCli)
call :UseTool "%app.prepare.noop.root%\tools\gh.exe" app.github.cli
if not errorlevel 1 (set "_prh_rc=0" & goto :ResolveGitHubCli)
call :UseTool "%ProgramFiles%\GitHub CLI\gh.exe" app.github.cli
if not errorlevel 1 (set "_prh_rc=0" & goto :ResolveGitHubCli)
call :UseTool "%LocalAppData%\Programs\GitHub CLI\gh.exe" app.github.cli
if not errorlevel 1 (set "_prh_rc=0" & goto :ResolveGitHubCli)
set "_prh_rc=1" & goto :ResolveGitHubCli
:: ============================================================
:: :UseTool
:: Selects an executable and prepends its directory to PATH.
::
:: Usage: call :UseTool "EXE_PATH" outputVariable
::
:: Returns: 0 when executable exists, 1 when missing
:: Requires: none
:: ============================================================
:UseTool
for /f "tokens=1 delims==" %%v in ('set pru_ 2^>nul') do set "%%v="
if defined _pru_rc (set "_pru_rc=" & exit /b %_pru_rc%)
set "pru_file=%~1"
set "pru_out=%~2"
if not exist "%pru_file%" (set "_pru_rc=1" & goto :UseTool)
for %%A in ("%pru_file%") do set "pru_dir=%%~dpA"
set "PATH=%pru_dir%;%PATH%"
set "%pru_out%=%pru_file%"
set "_pru_rc=0" & goto :UseTool
