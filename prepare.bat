@echo off
:setup
:: ============================================================
:: prepare.bat
:: Prepares Git and GitHub CLI for repository helper scripts.
::
:: Location:
::   Project root\prepare.bat
::
:: Batch style:
::   - no setlocal
::   - no delayed expansion
::   - documented functions
::   - one empty line between documented functions
::   - :setup, :main, and :end are structural labels
::
:: Exported values after success:
::   app.root
::   app.tools
::   app.git.exe
::   app.gh.exe
::   PATH updated for selected local tools
::
:: Important:
::   GetGit.bat and GetGithubCLI.bat also use app.* variables
::   without setlocal. They are therefore run in a child cmd.exe
::   so they cannot overwrite this script's environment.
:: ============================================================
cd /d "%~dp0"
for %%A in ("%CD%") do set "app.root=%%~fA"
set "app.tools.dir=tools"
if exist "%app.root%\build_config.bat" call "%app.root%\build_config.bat"
if defined app.tools_dir set "app.tools.dir=%app.tools_dir%"
for %%A in ("%app.root%\%app.tools.dir%") do set "app.tools=%%~fA"
set "app.get.git=%app.tools%\GetGit.bat"
set "app.get.github.cli=%app.tools%\GetGithubCLI.bat"
set "app.git.local.exe=%app.tools%\git\cmd\git.exe"
set "app.gh.local.exe=%app.tools%\gh\bin\gh.exe"
if defined app.get_git_script set "app.get.git=%app.get_git_script%"
if defined app.get_github_cli_script set "app.get.github.cli=%app.get_github_cli_script%"
if defined app.git_local_exe set "app.git.local.exe=%app.git_local_exe%"
if defined app.gh_local_exe set "app.gh.local.exe=%app.gh_local_exe%"
set "app.prepare.mode=repository"
set "app.prepare.force="
set "app.prepare.help="
set "app.prepare.rc=0"
set "app.git.exe="
set "app.gh.exe="
set "app.last.rc=0"
set "app.esc="
set "app.color.reset=0m"
set "app.color.red=31m"
set "app.color.green=32m"
set "app.color.yellow=33m"
set "app.color.cyan=36m"
:main
call :InitConsole
call :ParseArgs %*
set "app.prepare.rc=%errorlevel%"
if "%app.prepare.rc%"=="0" if defined app.prepare.help call :ShowHelp
if "%app.prepare.rc%"=="0" if defined app.prepare.help set "app.prepare.rc=%errorlevel%"
if "%app.prepare.rc%"=="0" if not defined app.prepare.help call :PrepareSelectedDependencies
if "%app.prepare.rc%"=="0" if not defined app.prepare.help set "app.prepare.rc=%errorlevel%"
:end
exit /b %app.prepare.rc%

:: ============================================================
:: Function: InitConsole
:: Usage: call :InitConsole
:: Purpose: initializes ANSI escape support.
:: Returns:
::   0 always
:: ============================================================
:InitConsole
call :SetESC app.esc
if errorlevel 1 set "app.esc="
if /I "%app.esc%"=="rem" set "app.esc="
exit /b 0

:: ============================================================
:: Function: ParseArgs
:: Usage: call :ParseArgs %*
:: Purpose: parses dependency mode and control arguments.
:: Accepted modes:
::   repository   Git and GitHub CLI; default
::   all          Alias for repository
::   git          Git only
::   github       Git and GitHub CLI
:: Accepted controls:
::   force
::   alwaysdownload
::   help, /help, --help, /?
:: Returns:
::   0 success
::   2 invalid argument
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="repository" (set "app.prepare.mode=repository" & shift & goto :ParseArgs)
if /I "%~1"=="all" (set "app.prepare.mode=repository" & shift & goto :ParseArgs)
if /I "%~1"=="git" (set "app.prepare.mode=git" & shift & goto :ParseArgs)
if /I "%~1"=="github" (set "app.prepare.mode=github" & shift & goto :ParseArgs)
if /I "%~1"=="force" (set "app.prepare.force=1" & shift & goto :ParseArgs)
if /I "%~1"=="alwaysdownload" (set "app.prepare.force=1" & shift & goto :ParseArgs)
if /I "%~1"=="help" (set "app.prepare.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="/help" (set "app.prepare.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="--help" (set "app.prepare.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="/?" (set "app.prepare.help=1" & shift & goto :ParseArgs)
call :Red FAIL: unrecognized argument: %~1
exit /b 2

:: ============================================================
:: Function: ShowHelp
:: Usage: call :ShowHelp
:: Purpose: prints usage and active dependency paths.
:: Returns:
::   0 always
:: ============================================================
:ShowHelp
call :Green Repository helper prepare.bat
echo.
call :Yellow Usage:
echo   prepare.bat
echo   prepare.bat repository
echo   prepare.bat git
echo   prepare.bat github
echo   prepare.bat force
echo   prepare.bat help
echo.
call :Yellow Modes:
echo   repository   Prepare Git and GitHub CLI. This is the default.
echo   all          Alias for repository.
echo   git          Prepare Git only.
echo   github       Prepare Git and GitHub CLI.
echo.
call :Yellow Controls:
echo   force          Refresh local dependency copies.
echo   alwaysdownload Alias for force.
echo   help           Show this help.
echo.
call :Yellow Project:
echo   Root:  %app.root%
echo   Tools: %app.tools%
echo.
call :Yellow Install helpers:
echo   Git:       %app.get.git%
echo   GitHub CLI: %app.get.github.cli%
echo.
call :Yellow Expected local programs:
echo   Git:       %app.git.local.exe%
echo   GitHub CLI: %app.gh.local.exe%
exit /b 0

:: ============================================================
:: Function: PrepareSelectedDependencies
:: Usage: call :PrepareSelectedDependencies
:: Purpose: prepares dependencies selected by app.prepare.mode.
:: Returns:
::   0 selected dependencies ready
::   1 preparation failed
:: ============================================================
:PrepareSelectedDependencies
call :Cyan PREPARE: %app.prepare.mode%
call :EnsureGit
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" exit /b %app.last.rc%
if /I "%app.prepare.mode%"=="git" goto :PrepareSelectedDependenciesDone
call :EnsureGitHubCLI
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" exit /b %app.last.rc%
:PrepareSelectedDependenciesDone
call :Green OK: dependencies ready.
if defined app.git.exe call :Green Git: %app.git.exe%
if defined app.gh.exe call :Green GitHub CLI: %app.gh.exe%
exit /b 0

:: ============================================================
:: Function: EnsureGit
:: Usage: call :EnsureGit
:: Purpose: selects an existing Git or installs a local copy.
:: Selection:
::   1. Existing local tools\git copy
::   2. Git found in PATH
::   3. Install with tools\GetGit.bat
:: With force:
::   Refresh local Git with tools\GetGit.bat and select it.
:: Returns:
::   0 Git ready and app.git.exe set
::   1 Git unavailable or installation failed
:: ============================================================
:EnsureGit
set "app.git.exe="
if defined app.prepare.force goto :EnsureGitInstall
call :FindGit
if not errorlevel 1 goto :EnsureGitReady
:EnsureGitInstall
if not exist "%app.get.git%" call :Red FAIL: Git installer helper not found: %app.get.git%
if not exist "%app.get.git%" exit /b 1
call :Yellow DO: preparing local Git.
if defined app.prepare.force goto :EnsureGitInstallForce
cmd.exe /d /s /c ""%app.get.git%" root "%app.tools%""
goto :EnsureGitInstallResult
:EnsureGitInstallForce
cmd.exe /d /s /c ""%app.get.git%" force root "%app.tools%""
:EnsureGitInstallResult
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :Red FAIL: GetGit.bat returned exit code %app.last.rc%.
if not "%app.last.rc%"=="0" exit /b %app.last.rc%
call :FindGit
if errorlevel 1 call :Red FAIL: Git is still unavailable after preparation.
if errorlevel 1 exit /b 1
:EnsureGitReady
for %%A in ("%app.git.exe%") do call :PrependPathIfMissing "%%~dpA"
"%app.git.exe%" --version >nul 2>nul
if errorlevel 1 call :Red FAIL: selected Git executable did not run: %app.git.exe%
if errorlevel 1 exit /b 1
exit /b 0

:: ============================================================
:: Function: FindGit
:: Usage: call :FindGit
:: Purpose: finds local Git first, then Git from PATH.
:: Output:
::   app.git.exe
:: Returns:
::   0 found
::   1 missing
:: ============================================================
:FindGit
set "app.git.exe="
if exist "%app.git.local.exe%" set "app.git.exe=%app.git.local.exe%"
if defined app.git.exe exit /b 0
for /f "delims=" %%A in ('where git.exe 2^>nul') do if not defined app.git.exe set "app.git.exe=%%~fA"
if defined app.git.exe exit /b 0
exit /b 1

:: ============================================================
:: Function: EnsureGitHubCLI
:: Usage: call :EnsureGitHubCLI
:: Purpose: selects an existing GitHub CLI or installs a local copy.
:: Selection:
::   1. Existing local tools\gh copy
::   2. gh found in PATH
::   3. Install with tools\GetGithubCLI.bat
:: With force:
::   Refresh local GitHub CLI and select it.
:: Returns:
::   0 GitHub CLI ready and app.gh.exe set
::   1 GitHub CLI unavailable or installation failed
:: ============================================================
:EnsureGitHubCLI
set "app.gh.exe="
if defined app.prepare.force goto :EnsureGitHubCLIInstall
call :FindGitHubCLI
if not errorlevel 1 goto :EnsureGitHubCLIReady
:EnsureGitHubCLIInstall
if not exist "%app.get.github.cli%" call :Red FAIL: GitHub CLI installer helper not found: %app.get.github.cli%
if not exist "%app.get.github.cli%" exit /b 1
call :Yellow DO: preparing local GitHub CLI.
if defined app.prepare.force goto :EnsureGitHubCLIInstallForce
cmd.exe /d /s /c ""%app.get.github.cli%" root "%app.tools%""
goto :EnsureGitHubCLIInstallResult
:EnsureGitHubCLIInstallForce
cmd.exe /d /s /c ""%app.get.github.cli%" force root "%app.tools%""
:EnsureGitHubCLIInstallResult
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :Red FAIL: GetGithubCLI.bat returned exit code %app.last.rc%.
if not "%app.last.rc%"=="0" exit /b %app.last.rc%
call :FindGitHubCLI
if errorlevel 1 call :Red FAIL: GitHub CLI is still unavailable after preparation.
if errorlevel 1 exit /b 1
:EnsureGitHubCLIReady
for %%A in ("%app.gh.exe%") do call :PrependPathIfMissing "%%~dpA"
"%app.gh.exe%" --version >nul 2>nul
if errorlevel 1 call :Red FAIL: selected GitHub CLI executable did not run: %app.gh.exe%
if errorlevel 1 exit /b 1
exit /b 0

:: ============================================================
:: Function: FindGitHubCLI
:: Usage: call :FindGitHubCLI
:: Purpose: finds local GitHub CLI first, then gh from PATH.
:: Output:
::   app.gh.exe
:: Returns:
::   0 found
::   1 missing
:: ============================================================
:FindGitHubCLI
set "app.gh.exe="
if exist "%app.gh.local.exe%" set "app.gh.exe=%app.gh.local.exe%"
if defined app.gh.exe exit /b 0
for /f "delims=" %%A in ('where gh.exe 2^>nul') do if not defined app.gh.exe set "app.gh.exe=%%~fA"
if defined app.gh.exe exit /b 0
exit /b 1

:: ============================================================
:: Function: PrependPathIfMissing
:: Usage: call :PrependPathIfMissing "folder"
:: Purpose: prepends a folder when PATH does not already contain it.
:: Returns:
::   0 always
:: ============================================================
:PrependPathIfMissing
path | find /I "%~1" >nul 2>nul
if errorlevel 1 set "PATH=%~1;%PATH%"
exit /b 0

:: ============================================================
:: Function: SetESC
:: Usage: call :SetESC outputVariable
:: Purpose: captures the ANSI escape character into a variable.
:: Returns:
::   0 success
::   2 missing output variable
:: ============================================================
:SetESC
set "se.out=%~1"
if not defined se.out exit /b 2
for /f %%a in ('echo prompt $E^| cmd') do set "%se.out%=%%a"
set "se.out="
exit /b 0

:: ============================================================
:: Function: Green
:: Usage: call :Green message
:: Purpose: prints a green status line.
:: Returns:
::   0 always
:: ============================================================
:Green
if defined app.esc (echo %app.esc%[%app.color.green%%*%app.esc%[%app.color.reset%) else (echo %*)
exit /b 0

:: ============================================================
:: Function: Yellow
:: Usage: call :Yellow message
:: Purpose: prints a yellow status line.
:: Returns:
::   0 always
:: ============================================================
:Yellow
if defined app.esc (echo %app.esc%[%app.color.yellow%%*%app.esc%[%app.color.reset%) else (echo %*)
exit /b 0

:: ============================================================
:: Function: Red
:: Usage: call :Red message
:: Purpose: prints a red status line.
:: Returns:
::   0 always
:: ============================================================
:Red
if defined app.esc (echo %app.esc%[%app.color.red%%*%app.esc%[%app.color.reset%) else (echo %*)
exit /b 0

:: ============================================================
:: Function: Cyan
:: Usage: call :Cyan message
:: Purpose: prints a cyan status line.
:: Returns:
::   0 always
:: ============================================================
:Cyan
if defined app.esc (echo %app.esc%[%app.color.cyan%%*%app.esc%[%app.color.reset%) else (echo %*)
exit /b 0
