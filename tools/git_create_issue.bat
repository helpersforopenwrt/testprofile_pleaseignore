@echo off
:: ============================================================
:: git_create_issue.bat
:: Creates a GitHub issue in a configured or explicitly selected
:: repository.
::
:: Usage:
::   call tools\git_create_issue.bat title "Build fails on Windows"
::   call tools\git_create_issue.bat title "Bug" body "Steps..."
::   call tools\git_create_issue.bat title "Bug" labels "bug,windows"
::   call tools\git_create_issue.bat repo OWNER/REPO title "Bug"
::
:: Returns: 0 on success or cancellation
::          1 on dependency, authentication, repository, or creation failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, gh, :Main, :ParseArgs,
::           :ResolveRepository, :ShowPlan, :CreateIssue, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_create_issue.repo.input="
set "app.git_create_issue.repo.slug="
set "app.git_create_issue.title="
set "app.git_create_issue.body="
set "app.git_create_issue.labels="
set "app.git_create_issue.assignees="
set "app.git_create_issue.milestone="
set "app.git_create_issue.confirm="
set "app.git_create_issue.help="
set "app.git_create_issue.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_create_issue.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_create_issue.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_create_issue.rc%
:: ============================================================
:: :Main
:: Parses options, prepares dependencies, authenticates GitHub CLI,
:: resolves the repository, confirms the plan, and creates the issue.
::
:: Usage: call :Main [repo REPOSITORY] [title TEXT] [body TEXT] [labels LIST] [assignees LIST] [milestone NAME]
::
:: Returns: 0 on success or cancellation
::          1 on dependency, authentication, repository, or creation failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :ResolveRepository, :ShowPlan,
::           :CreateIssue, :ShowHelp, prepare.bat, gh
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcim_ 2^>nul') do set "%%v="
if defined _gcim_rc (set "_gcim_rc=" & exit /b %_gcim_rc%)
call :ParseArgs %*
set "_gcim_rc=%errorlevel%"
if not "%_gcim_rc%"=="0" goto :Main
if defined app.git_create_issue.help goto :_Main_help
echo.
echo ============================================================
echo  Create GitHub issue
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_gcim_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI was not found. & set "_gcim_rc=1" & goto :Main)
gh auth status --hostname github.com >nul 2>nul
if errorlevel 1 goto :_Main_not_authenticated
call :ResolveRepository
if errorlevel 1 (set "_gcim_rc=%errorlevel%" & goto :Main)
if not defined app.git_create_issue.title set /p "app.git_create_issue.title=Issue title: "
if not defined app.git_create_issue.title (echo ERROR: An issue title is required. & set "_gcim_rc=1" & goto :Main)
call :ShowPlan
if errorlevel 1 (set "_gcim_rc=%errorlevel%" & goto :Main)
set /p "app.git_create_issue.confirm=Type ISSUE to continue: "
if "%app.git_create_issue.confirm%"=="ISSUE" goto :_Main_create
echo.
echo Cancelled. No issue was created.
set "_gcim_rc=0" & goto :Main
:_Main_create
call :CreateIssue
set "_gcim_rc=%errorlevel%" & goto :Main
:_Main_not_authenticated
echo ERROR: GitHub CLI is not logged in.
echo Run:
echo   just_login.bat
set "_gcim_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gcim_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ResolveRepository
:: Resolves the target repository from explicit input, upstream
:: configuration, project configuration, or origin.
::
:: Usage: call :ResolveRepository
::
:: Output:
::   app.git_create_issue.repo.input  selected repository input
::   app.git_create_issue.repo.slug   normalized OWNER/REPO
::
:: Returns: 0 on success
::          1 when no visible repository can be resolved
:: Requires: git, gh
:: ============================================================
:ResolveRepository
for /f "tokens=1 delims==" %%v in ('set gcir_ 2^>nul') do set "%%v="
if defined _gcir_rc (set "_gcir_rc=" & exit /b %_gcir_rc%)
if defined app.git_create_issue.repo.input goto :_ResolveRepository_view
if defined app.upstream_url set "app.git_create_issue.repo.input=%app.upstream_url%"
if defined app.git_create_issue.repo.input goto :_ResolveRepository_view
if defined app.fork_source_url set "app.git_create_issue.repo.input=%app.fork_source_url%"
if defined app.git_create_issue.repo.input goto :_ResolveRepository_view
if defined CFG_REPO_URL set "app.git_create_issue.repo.input=%CFG_REPO_URL%"
if defined app.git_create_issue.repo.input goto :_ResolveRepository_view
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_create_issue.repo.input=%%A"
if not defined app.git_create_issue.repo.input (echo ERROR: No GitHub repository is configured. & set "_gcir_rc=1" & goto :ResolveRepository)
:_ResolveRepository_view
set "app.git_create_issue.repo.slug="
for /f "delims=" %%A in ('gh repo view "%app.git_create_issue.repo.input%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_create_issue.repo.slug=%%A"
if not defined app.git_create_issue.repo.slug (echo ERROR: Repository was not found or is not visible: & echo   %app.git_create_issue.repo.input% & set "_gcir_rc=1" & goto :ResolveRepository)
set "_gcir_rc=0" & goto :ResolveRepository
:: ============================================================
:: :ShowPlan
:: Displays the issue repository and supplied metadata.
::
:: Usage: call :ShowPlan
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowPlan
echo Repository:
echo   %app.git_create_issue.repo.slug%
echo.
echo Title:
echo   %app.git_create_issue.title%
echo.
if defined app.git_create_issue.body goto :_ShowPlan_body
echo Body:
echo   empty
goto :_ShowPlan_labels
:_ShowPlan_body
echo Body:
echo   supplied on command line
:_ShowPlan_labels
echo.
if defined app.git_create_issue.labels echo Labels: %app.git_create_issue.labels%
if defined app.git_create_issue.assignees echo Assignees: %app.git_create_issue.assignees%
if defined app.git_create_issue.milestone echo Milestone: %app.git_create_issue.milestone%
echo.
exit /b 0
:: ============================================================
:: :CreateIssue
:: Runs gh issue create with the supplied optional metadata.
::
:: Usage: call :CreateIssue
::
:: Returns: 0 on success
::          1 on GitHub CLI failure
:: Requires: gh
:: ============================================================
:CreateIssue
for /f "tokens=1 delims==" %%v in ('set gcic_ 2^>nul') do set "%%v="
if defined _gcic_rc (set "_gcic_rc=" & exit /b %_gcic_rc%)
if defined app.git_create_issue.labels goto :_CreateIssue_labels
if defined app.git_create_issue.assignees goto :_CreateIssue_assignees
if defined app.git_create_issue.milestone goto :_CreateIssue_milestone
gh issue create --repo "%app.git_create_issue.repo.slug%" --title "%app.git_create_issue.title%" --body "%app.git_create_issue.body%"
goto :_CreateIssue_result
:_CreateIssue_labels
if defined app.git_create_issue.assignees goto :_CreateIssue_labels_assignees
if defined app.git_create_issue.milestone goto :_CreateIssue_labels_milestone
gh issue create --repo "%app.git_create_issue.repo.slug%" --title "%app.git_create_issue.title%" --body "%app.git_create_issue.body%" --label "%app.git_create_issue.labels%"
goto :_CreateIssue_result
:_CreateIssue_labels_assignees
if defined app.git_create_issue.milestone goto :_CreateIssue_all
gh issue create --repo "%app.git_create_issue.repo.slug%" --title "%app.git_create_issue.title%" --body "%app.git_create_issue.body%" --label "%app.git_create_issue.labels%" --assignee "%app.git_create_issue.assignees%"
goto :_CreateIssue_result
:_CreateIssue_labels_milestone
gh issue create --repo "%app.git_create_issue.repo.slug%" --title "%app.git_create_issue.title%" --body "%app.git_create_issue.body%" --label "%app.git_create_issue.labels%" --milestone "%app.git_create_issue.milestone%"
goto :_CreateIssue_result
:_CreateIssue_assignees
if defined app.git_create_issue.milestone goto :_CreateIssue_assignees_milestone
gh issue create --repo "%app.git_create_issue.repo.slug%" --title "%app.git_create_issue.title%" --body "%app.git_create_issue.body%" --assignee "%app.git_create_issue.assignees%"
goto :_CreateIssue_result
:_CreateIssue_assignees_milestone
gh issue create --repo "%app.git_create_issue.repo.slug%" --title "%app.git_create_issue.title%" --body "%app.git_create_issue.body%" --assignee "%app.git_create_issue.assignees%" --milestone "%app.git_create_issue.milestone%"
goto :_CreateIssue_result
:_CreateIssue_milestone
gh issue create --repo "%app.git_create_issue.repo.slug%" --title "%app.git_create_issue.title%" --body "%app.git_create_issue.body%" --milestone "%app.git_create_issue.milestone%"
goto :_CreateIssue_result
:_CreateIssue_all
gh issue create --repo "%app.git_create_issue.repo.slug%" --title "%app.git_create_issue.title%" --body "%app.git_create_issue.body%" --label "%app.git_create_issue.labels%" --assignee "%app.git_create_issue.assignees%" --milestone "%app.git_create_issue.milestone%"
:_CreateIssue_result
if errorlevel 1 (echo. & echo ERROR: GitHub issue creation failed. & set "_gcic_rc=1" & goto :CreateIssue)
echo.
echo GitHub issue created successfully.
set "_gcic_rc=0" & goto :CreateIssue
:: ============================================================
:: :ParseArgs
:: Parses repository and issue metadata arguments.
::
:: Usage: call :ParseArgs [repo REPOSITORY] [title TEXT] [body TEXT] [labels LIST] [assignees LIST] [milestone NAME]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="repo" goto :_ParseArgs_repo
if /I "%~1"=="title" goto :_ParseArgs_title
if /I "%~1"=="body" goto :_ParseArgs_body
if /I "%~1"=="labels" goto :_ParseArgs_labels
if /I "%~1"=="label" goto :_ParseArgs_labels
if /I "%~1"=="assignees" goto :_ParseArgs_assignees
if /I "%~1"=="assignee" goto :_ParseArgs_assignees
if /I "%~1"=="milestone" goto :_ParseArgs_milestone
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_repo
if "%~2"=="" (echo ERROR: repo requires OWNER/REPO or a URL. & exit /b 2)
set "app.git_create_issue.repo.input=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_title
if "%~2"=="" (echo ERROR: title requires text. & exit /b 2)
set "app.git_create_issue.title=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_body
set "app.git_create_issue.body=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_labels
if "%~2"=="" (echo ERROR: labels requires a comma-separated value. & exit /b 2)
set "app.git_create_issue.labels=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_assignees
if "%~2"=="" (echo ERROR: assignees requires a comma-separated value. & exit /b 2)
set "app.git_create_issue.assignees=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_milestone
if "%~2"=="" (echo ERROR: milestone requires a name. & exit /b 2)
set "app.git_create_issue.milestone=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_create_issue.help=1"
shift
goto :ParseArgs
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
echo git_create_issue.bat
echo.
echo Usage:
echo   git_create_issue.bat title "Build fails on Windows"
echo   git_create_issue.bat title "Bug" body "Steps to reproduce"
echo   git_create_issue.bat title "Bug" labels "bug,windows"
echo   git_create_issue.bat repo OWNER/REPO title "Bug"
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
