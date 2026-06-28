@echo off
:: ============================================================
:: git_clone_repository.bat
:: Clones a GitHub or Git repository into a new folder.
::
:: Usage:
::   call tools\git_clone_repository.bat
::   call tools\git_clone_repository.bat repo OWNER/REPO
::   call tools\git_clone_repository.bat repo URL destination C:\work\repo
::   call tools\git_clone_repository.bat repo OWNER/REPO branch main login no
::
:: Returns: 0 on success or cancellation
::          1 on dependency, authentication, destination, or clone failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, optional gh, :Main,
::           :ParseArgs, :NormalizeYesNo, :EnsureGitHubAuthentication,
::           :ResolveDestination, :ValidateDestination, :ShowPlan,
::           :CloneRepository, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_clone.repo="
set "app.git_clone.repo.name="
set "app.git_clone.destination="
set "app.git_clone.destination.full="
set "app.git_clone.branch="
set "app.git_clone.login=yes"
set "app.git_clone.confirm="
set "app.git_clone.help="
set "app.git_clone.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :defaults
set "app.git_clone.rc=%errorlevel%"
goto :end
:defaults
if defined CFG_REPO_URL set "app.git_clone.repo=%CFG_REPO_URL%"
if defined CFG_BRANCH set "app.git_clone.branch=%CFG_BRANCH%"
:run
call :Main %*
set "app.git_clone.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_clone.rc%
:: ============================================================
:: :Main
:: Parses options, prepares dependencies, resolves and validates the
:: destination, confirms the plan, and clones the repository.
::
:: Usage: call :Main [repo SOURCE] [destination FOLDER] [branch NAME] [login yes|no]
::
:: Returns: 0 on success or cancellation
::          1 on dependency, authentication, destination, or clone failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :EnsureGitHubAuthentication,
::           :ResolveDestination, :ValidateDestination, :ShowPlan,
::           :CloneRepository, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gclm_ 2^>nul') do set "%%v="
if defined _gclm_rc (set "_gclm_rc=" & exit /b %_gclm_rc%)
call :ParseArgs %*
set "_gclm_rc=%errorlevel%"
if not "%_gclm_rc%"=="0" goto :Main
if defined app.git_clone.help goto :_Main_help
call :NormalizeYesNo app.git_clone.login
if errorlevel 1 (echo ERROR: login must be yes or no. & set "_gclm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Clone repository
echo ============================================================
echo.
echo Source project:
echo   %APP_DISPLAY_NAME%
echo.
echo Current folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_gclm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gclm_rc=1" & goto :Main)
if not defined app.git_clone.repo set /p "app.git_clone.repo=Repository URL or OWNER/REPO: "
if not defined app.git_clone.repo (echo ERROR: A repository is required. & set "_gclm_rc=1" & goto :Main)
if /I "%app.git_clone.login%"=="yes" goto :_Main_login
goto :_Main_destination
:_Main_login
call :EnsureGitHubAuthentication
if errorlevel 1 (set "_gclm_rc=%errorlevel%" & goto :Main)
:_Main_destination
call :ResolveDestination
if errorlevel 1 (set "_gclm_rc=%errorlevel%" & goto :Main)
call :ValidateDestination
if errorlevel 1 (set "_gclm_rc=%errorlevel%" & goto :Main)
call :ShowPlan
if errorlevel 1 (set "_gclm_rc=%errorlevel%" & goto :Main)
set /p "app.git_clone.confirm=Type CLONE to continue: "
if "%app.git_clone.confirm%"=="CLONE" goto :_Main_clone
echo.
echo Cancelled. Nothing was cloned.
set "_gclm_rc=0" & goto :Main
:_Main_clone
call :CloneRepository
set "_gclm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gclm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :EnsureGitHubAuthentication
:: Ensures GitHub CLI is installed, logged in, and configured for
:: Git HTTPS authentication.
::
:: Usage: call :EnsureGitHubAuthentication
::
:: Returns: 0 on success
::          1 on missing GitHub CLI, login failure, or setup failure
:: Requires: gh
:: ============================================================
:EnsureGitHubAuthentication
for /f "tokens=1 delims==" %%v in ('set gcla_ 2^>nul') do set "%%v="
if defined _gcla_rc (set "_gcla_rc=" & exit /b %_gcla_rc%)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI is required when login is yes. & set "_gcla_rc=1" & goto :EnsureGitHubAuthentication)
gh auth status --hostname github.com >nul 2>nul
if not errorlevel 1 goto :_EnsureGitHubAuthentication_setup
echo GitHub login is required.
echo A browser window will open for secure login.
gh auth login --hostname github.com --git-protocol https --web
if errorlevel 1 (echo ERROR: GitHub login failed or was cancelled. & set "_gcla_rc=1" & goto :EnsureGitHubAuthentication)
:_EnsureGitHubAuthentication_setup
gh auth setup-git --hostname github.com >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI could not configure Git authentication. & set "_gcla_rc=1" & goto :EnsureGitHubAuthentication)
set "_gcla_rc=0" & goto :EnsureGitHubAuthentication
:: ============================================================
:: :ResolveDestination
:: Derives a repository folder name and resolves the absolute clone
:: destination.
::
:: Usage: call :ResolveDestination
::
:: Output:
::   app.git_clone.repo.name         derived repository name
::   app.git_clone.destination.full  absolute destination path
::
:: Returns: 0 on success
::          1 when a destination cannot be resolved
:: Requires: none
:: ============================================================
:ResolveDestination
for /f "tokens=1 delims==" %%v in ('set gclr_ 2^>nul') do set "%%v="
if defined _gclr_rc (set "_gclr_rc=" & exit /b %_gclr_rc%)
set "gclr_repo_path=%app.git_clone.repo:/=\%"
for %%A in ("%gclr_repo_path%") do set "app.git_clone.repo.name=%%~nA"
if not defined app.git_clone.repo.name set "app.git_clone.repo.name=repository"
if not defined app.git_clone.destination set "app.git_clone.destination=..\%app.git_clone.repo.name%"
for %%A in ("%app.git_clone.destination%") do set "app.git_clone.destination.full=%%~fA"
if not defined app.git_clone.destination.full (echo ERROR: Destination could not be resolved. & set "_gclr_rc=1" & goto :ResolveDestination)
set "_gclr_rc=0" & goto :ResolveDestination
:: ============================================================
:: :ValidateDestination
:: Refuses an existing non-empty destination folder.
::
:: Usage: call :ValidateDestination
::
:: Returns: 0 when absent or empty
::          1 when the destination is an existing file or non-empty folder
:: Requires: findstr
:: ============================================================
:ValidateDestination
for /f "tokens=1 delims==" %%v in ('set gcld_ 2^>nul') do set "%%v="
if defined _gcld_rc (set "_gcld_rc=" & exit /b %_gcld_rc%)
if not exist "%app.git_clone.destination.full%" (set "_gcld_rc=0" & goto :ValidateDestination)
if exist "%app.git_clone.destination.full%\" goto :_ValidateDestination_folder
echo ERROR: Destination exists and is not a folder:
echo   %app.git_clone.destination.full%
set "_gcld_rc=1" & goto :ValidateDestination
:_ValidateDestination_folder
dir /a /b "%app.git_clone.destination.full%" 2>nul | findstr . >nul
if errorlevel 1 (set "_gcld_rc=0" & goto :ValidateDestination)
echo ERROR: Destination folder already exists and is not empty:
echo   %app.git_clone.destination.full%
set "_gcld_rc=1" & goto :ValidateDestination
:: ============================================================
:: :ShowPlan
:: Displays the repository, destination, branch, and login mode.
::
:: Usage: call :ShowPlan
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowPlan
echo.
echo Repository:
echo   %app.git_clone.repo%
echo.
echo Destination:
echo   %app.git_clone.destination.full%
echo.
echo Branch:
if defined app.git_clone.branch goto :_ShowPlan_branch
echo   repository default branch
goto :_ShowPlan_login
:_ShowPlan_branch
echo   %app.git_clone.branch%
:_ShowPlan_login
echo.
echo GitHub login requested:
echo   %app.git_clone.login%
echo.
exit /b 0
:: ============================================================
:: :CloneRepository
:: Runs git clone, verifies HEAD, and displays the cloned status.
::
:: Usage: call :CloneRepository
::
:: Returns: 0 on success
::          1 on clone or verification failure
:: Requires: git
:: ============================================================
:CloneRepository
for /f "tokens=1 delims==" %%v in ('set gclc_ 2^>nul') do set "%%v="
if defined _gclc_rc (set "_gclc_rc=" & exit /b %_gclc_rc%)
if defined app.git_clone.branch goto :_CloneRepository_branch
git clone "%app.git_clone.repo%" "%app.git_clone.destination.full%"
goto :_CloneRepository_result
:_CloneRepository_branch
git clone --branch "%app.git_clone.branch%" --single-branch "%app.git_clone.repo%" "%app.git_clone.destination.full%"
:_CloneRepository_result
if errorlevel 1 (echo. & echo ERROR: Repository clone failed. & set "_gclc_rc=1" & goto :CloneRepository)
git -C "%app.git_clone.destination.full%" rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: Clone completed, but HEAD verification failed. & set "_gclc_rc=1" & goto :CloneRepository)
echo.
echo ============================================================
echo  Clone complete
echo ============================================================
echo.
echo Folder:
echo   %app.git_clone.destination.full%
echo.
echo Status:
git -C "%app.git_clone.destination.full%" status --short --branch
echo.
set "_gclc_rc=0" & goto :CloneRepository
:: ============================================================
:: :ParseArgs
:: Parses repository, destination, branch, login, and help options.
::
:: Usage: call :ParseArgs [repo SOURCE] [destination FOLDER] [branch NAME] [login yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="repo" goto :_ParseArgs_repo
if /I "%~1"=="url" goto :_ParseArgs_repo
if /I "%~1"=="destination" goto :_ParseArgs_destination
if /I "%~1"=="dest" goto :_ParseArgs_destination
if /I "%~1"=="branch" goto :_ParseArgs_branch
if /I "%~1"=="login" goto :_ParseArgs_login
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_repo
if "%~2"=="" (echo ERROR: repo requires a URL or OWNER/REPO. & exit /b 2)
set "app.git_clone.repo=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_destination
if "%~2"=="" (echo ERROR: destination requires a folder path. & exit /b 2)
set "app.git_clone.destination=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_branch
if "%~2"=="" (echo ERROR: branch requires a name. & exit /b 2)
set "app.git_clone.branch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_login
if "%~2"=="" (echo ERROR: login requires yes or no. & exit /b 2)
set "app.git_clone.login=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_clone.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeYesNo
:: Normalizes a named variable to yes or no.
::
:: Usage: call :NormalizeYesNo variableName
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:NormalizeYesNo
for /f "tokens=1 delims==" %%v in ('set gcly_ 2^>nul') do set "%%v="
if defined _gcly_rc (set "_gcly_rc=" & exit /b %_gcly_rc%)
set "gcly_name=%~1"
call set "gcly_value=%%%gcly_name%%%"
if /I "%gcly_value%"=="y" set "%gcly_name%=yes"
if /I "%gcly_value%"=="yes" set "%gcly_name%=yes"
if /I "%gcly_value%"=="true" set "%gcly_name%=yes"
if /I "%gcly_value%"=="1" set "%gcly_name%=yes"
if /I "%gcly_value%"=="n" set "%gcly_name%=no"
if /I "%gcly_value%"=="no" set "%gcly_name%=no"
if /I "%gcly_value%"=="false" set "%gcly_name%=no"
if /I "%gcly_value%"=="0" set "%gcly_name%=no"
call set "gcly_value=%%%gcly_name%%%"
if /I "%gcly_value%"=="yes" (set "_gcly_rc=0" & goto :NormalizeYesNo)
if /I "%gcly_value%"=="no" (set "_gcly_rc=0" & goto :NormalizeYesNo)
set "_gcly_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays command usage.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_clone_repository.bat
echo.
echo Usage:
echo   git_clone_repository.bat
echo   git_clone_repository.bat repo OWNER/REPO
echo   git_clone_repository.bat repo URL destination C:\work\repo
echo   git_clone_repository.bat repo OWNER/REPO branch main login no
echo.
exit /b 0
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
:: Detects whether the outermost launcher is running in an existing
:: interactive console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 when running in an existing console
::          1 when the outermost launcher is the cmd.exe /c target
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
