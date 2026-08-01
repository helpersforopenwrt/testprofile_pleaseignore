@echo off
:: Recover from a previously interrupted invocation in this cmd.exe.
set "_gla_rc="
set "_glb_rc="
set "_glc_rc="
set "_gle_rc="
set "_glf_rc="
set "_gli_rc="
set "_glm_rc="
set "_glp_rc="
set "_glr_rc="
set "_glw_rc="
set "_glx_rc="
set "APP_GH_DEVICE_URL="
:: ============================================================
:: git_login.bat
:: Authenticates GitHub CLI, verifies repository permissions,
:: initializes local Git when requested, configures identity and
:: remotes, and pushes the current branch when commits exist.
::
:: Usage:
::   call tools\git_login.bat
::   call tools\git_login.bat repo OWNER/REPO
::   call tools\git_login.bat repo URL branch main
::   call tools\git_login.bat browser 4 fork yes identity defaults push yes
::   call tools\git_login.bat authenticate browser 4 prepared yes pause no
::   call tools\git_login.bat authenticate browser 4a prepared yes pause no
::   call tools\git_login.bat help
::
:: Returns: 0 on successful setup, successful no-commit setup, or help
::          1 on dependency, authentication, repository, permission,
::            initialization, identity, remote, or push failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, gh, main, authenticate,
::           resolverepository, resolveidentity, configurefork,
::           ensurefork, waitforfork, showplan, captureremotes,
::           configureremotes, restoreremotes, parseargs, showhelp,
::           pauseifneeded, isconsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_login.repo.input="
set "app.git_login.repo.slug="
set "app.git_login.repo.owner="
set "app.git_login.repo.name="
set "app.git_login.repo.web="
set "app.git_login.repo.url="
set "app.git_login.branch="
set "app.git_login.login="
set "app.git_login.authenticate.only="
set "app.git_login.login.request=yes"
set "app.git_login.pause.request=yes"
set "app.git_login.can.push="
set "app.git_login.use.fork="
set "app.git_login.read.only="
set "app.git_login.fork.slug="
set "app.git_login.fork.url="
set "app.git_login.fork.create="
set "app.git_login.target.origin="
set "app.git_login.repo.exists="
set "app.git_login.repo.root="
set "app.git_login.current.branch="
set "app.git_login.existing.origin="
set "app.git_login.git.name="
set "app.git_login.git.email="
set "app.git_login.input="
set "app.git_login.input.status="
set "app.git_login.input.result="
set "app.git_login.input.timeout=20"
set "app.git_login.input.helper=%~dp0git_login_read_timed_input.ps1"
set "app.git_login.prepare.log="
set "app.git_login.prepare.rc=0"
set "app.git_login.prepared.request=no"
set "app.git_login.browser.choice="
set "app.git_login.browser.request=ask"
set "app.git_login.fork.request=ask"
set "app.git_login.identity.request=ask"
set "app.git_login.push.request=yes"
set "app.git_login.browser.preopened="
set "app.git_login.browser.noop="
set "app.git_login.browser.url=https://github.com/login/device"
set "app.git_login.original.origin.exists="
set "app.git_login.original.origin.url="
set "app.git_login.original.upstream.exists="
set "app.git_login.original.upstream.url="
set "app.git_login.help="
set "app.git_login.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_login.rc=%errorlevel%"
goto :end
:run
if defined CFG_REPO_URL set "app.git_login.repo.input=%CFG_REPO_URL%"
if defined CFG_BRANCH set "app.git_login.branch=%CFG_BRANCH%"
call :Main %*
set "app.git_login.rc=%errorlevel%"
:end
call :CleanupTemp
if /I not "%app.git_login.pause.request%"=="no" call :PauseIfNeeded
exit /b %app.git_login.rc%
:: ============================================================
:: Function Main
:: Coordinates authentication, optional authentication-only return,
:: repository and fork resolution, local Git setup, remote
:: configuration, and optional push.
::
:: Usage: call main [authenticate] [login MODE] [repo REPO] [branch BRANCH] [browser METHOD] [fork MODE] [identity MODE] [push MODE] [prepared MODE] [pause MODE] [help]
::
:: Returns: 0 on successful setup, successful no-commit setup, or help
::          1 on dependency, authentication, repository, permission,
::            initialization, identity, remote, or push failure
::          2 on invalid arguments
:: Requires: authenticate, resolverepository, resolveidentity,
::           configurefork, ensurefork, showplan, captureremotes,
::           configureremotes, restoreremotes, parseargs, showhelp,
::           prepare.bat, git, gh
:: Dependencies
::   ParseArgs CleanupTemp Authenticate ResolveRepository ConfigureFork ResolveIdentity ShowPlan EnsureFork CaptureRemotes ConfigureRemotes RestoreRemotes ShowHelp
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set glm_ 2^>nul') do set "%%v="
if defined _glm_rc (set "_glm_rc=" & exit /b %_glm_rc%)
call :ParseArgs %*
set "_glm_rc=%errorlevel%"
if not "%_glm_rc%"=="0" goto :Main
if defined app.git_login.help goto :_Main_help
echo.
echo ============================================================
if defined app.git_login.authenticate.only (echo  GitHub authentication) else (echo  GitHub login, permission, and origin setup)
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
if /I "%app.git_login.prepared.request%"=="yes" goto :_Main_prepare_ready
if exist "%CD%\prepare.bat" goto :_Main_prepare
echo ERROR: prepare.bat was not found in the project root:
echo   %CD%
set "_glm_rc=1" & goto :Main
:_Main_prepare
set "app.git_login.prepare.log=%TEMP%\git-login-prepare-%RANDOM%-%RANDOM%.log"
call "%CD%\prepare.bat" repository >"%app.git_login.prepare.log%" 2>&1
set "app.git_login.prepare.rc=%errorlevel%"
if "%app.git_login.prepare.rc%"=="0" goto :_Main_prepare_ready
echo ERROR: Dependency preparation failed.
echo.
if exist "%app.git_login.prepare.log%" type "%app.git_login.prepare.log%"
call :CleanupTemp
set "_glm_rc=1" & goto :Main
:_Main_prepare_ready
if exist "%app.git_login.prepare.log%" del /q "%app.git_login.prepare.log%" >nul 2>nul
set "app.git_login.prepare.log="
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git is unavailable after preparation. & set "_glm_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI is unavailable after preparation. & set "_glm_rc=1" & goto :Main)
call :Authenticate
if errorlevel 1 (set "_glm_rc=%errorlevel%" & goto :Main)
if defined app.git_login.authenticate.only (echo OK: GitHub authentication is ready. & set "_glm_rc=0" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 goto :_Main_no_repo
set "app.git_login.repo.exists=1"
for /f "delims=" %%A in ('git rev-parse --show-toplevel 2^>nul') do set "app.git_login.repo.root=%%A"
for %%A in ("%app.git_login.repo.root%") do set "app.git_login.repo.root=%%~fA"
if /I not "%app.git_login.repo.root%"=="%CD%" goto :_Main_wrong_root
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_login.current.branch=%%A"
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_login.existing.origin=%%A"
if defined app.git_login.current.branch set "app.git_login.branch=%app.git_login.current.branch%"
goto :_Main_resolve_repo
:_Main_wrong_root
echo ERROR: Run this helper from the Git worktree root:
echo   %app.git_login.repo.root%
set "_glm_rc=1" & goto :Main
:_Main_no_repo
set "app.git_login.repo.exists="
:_Main_resolve_repo
if not defined app.git_login.repo.input if defined app.git_login.existing.origin set "app.git_login.repo.input=%app.git_login.existing.origin%"
call :ResolveRepository
if errorlevel 1 (set "_glm_rc=%errorlevel%" & goto :Main)
if /I "%app.git_login.can.push%"=="true" goto :_Main_direct
call :ConfigureFork
if errorlevel 1 (set "_glm_rc=%errorlevel%" & goto :Main)
goto :_Main_branch
:_Main_direct
set "app.git_login.target.origin=%app.git_login.repo.url%"
:_Main_branch
if not defined app.git_login.branch set "app.git_login.branch=main"
git check-ref-format --branch "%app.git_login.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid branch name: & echo   %app.git_login.branch% & set "_glm_rc=1" & goto :Main)
call :ResolveIdentity
if errorlevel 1 (set "_glm_rc=%errorlevel%" & goto :Main)
call :ShowPlan
echo Continuing with GitHub setup...
echo.
:_Main_ensure_fork
if not defined app.git_login.use.fork goto :_Main_initialize
call :EnsureFork
if errorlevel 1 (set "_glm_rc=%errorlevel%" & goto :Main)
:_Main_initialize
if defined app.git_login.repo.exists goto :_Main_identity
git init -b "%app.git_login.branch%" >nul 2>nul
if not errorlevel 1 goto :_Main_initialized
git init
if errorlevel 1 (echo ERROR: git init failed. & set "_glm_rc=1" & goto :Main)
git checkout -B "%app.git_login.branch%"
if errorlevel 1 (echo ERROR: Could not create branch %app.git_login.branch%. & set "_glm_rc=1" & goto :Main)
:_Main_initialized
set "app.git_login.repo.exists=1"
:_Main_identity
git config --local user.name "%app.git_login.git.name%"
if errorlevel 1 (echo ERROR: Could not set local Git user.name. & set "_glm_rc=1" & goto :Main)
git config --local user.email "%app.git_login.git.email%"
if errorlevel 1 (echo ERROR: Could not set local Git user.email. & set "_glm_rc=1" & goto :Main)
set "app.git_login.current.branch="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_login.current.branch=%%A"
if defined app.git_login.current.branch goto :_Main_remotes
git checkout -B "%app.git_login.branch%"
if errorlevel 1 (echo ERROR: Could not create or switch to branch %app.git_login.branch%. & set "_glm_rc=1" & goto :Main)
set "app.git_login.current.branch=%app.git_login.branch%"
:_Main_remotes
call :CaptureRemotes
call :ConfigureRemotes
if not errorlevel 1 goto :_Main_summary
call :RestoreRemotes
echo ERROR: Could not configure Git remotes.
echo Original remotes were restored where possible.
set "_glm_rc=1" & goto :Main
:_Main_summary
echo.
echo ============================================================
echo  GitHub setup summary
echo ============================================================
echo.
echo GitHub account:
echo   %app.git_login.login%
echo.
echo Repository:
echo   %app.git_login.repo.slug%
echo.
if defined app.git_login.read.only goto :_Main_summary_read_only
if defined app.git_login.use.fork goto :_Main_summary_fork
echo Permission mode:
echo   direct push
echo.
echo origin:
echo   %app.git_login.target.origin%
goto :_Main_summary_common
:_Main_summary_read_only
echo Permission mode:
echo   read-only original repository
echo.
echo origin:
echo   %app.git_login.target.origin%
goto :_Main_summary_common
:_Main_summary_fork
echo Permission mode:
echo   fork workflow
echo.
echo origin:
echo   %app.git_login.target.origin%
echo.
echo upstream:
echo   %app.git_login.repo.url%
:_Main_summary_common
echo.
echo Local branch:
echo   %app.git_login.current.branch%
echo.
echo Local Git author:
echo   Name: %app.git_login.git.name%
echo   Email: %app.git_login.git.email%
echo.
git status --short --branch
echo.
git remote -v
echo.
if /I "%app.git_login.push.request%"=="no" goto :_Main_no_push
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 goto :_Main_no_head
echo Pushing current branch and configuring upstream tracking...
git push -u origin "%app.git_login.current.branch%"
if not errorlevel 1 goto :_Main_success
echo.
echo ERROR: Push failed.
echo Repository write permission was checked, but branch protection,
echo remote history, or another Git condition rejected this push.
echo.
echo Inspect the repository with:
echo   just_status.bat
set "_glm_rc=1" & goto :Main
:_Main_no_push
echo GitHub login and repository setup are complete.
echo Push was disabled by the command line.
set "_glm_rc=0" & goto :Main
:_Main_no_head
echo Login and repository setup are complete.
echo No commits exist yet, so there is nothing to push.
echo.
echo Next:
echo   just_commit.bat
echo   just_push.bat
set "_glm_rc=0" & goto :Main
:_Main_success
echo.
echo GitHub login, permission check, and push are complete.
set "_glm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_glm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: Function Authenticate
:: Reuses an active GitHub CLI login or runs the shared selectable
:: device-login flow. Authentication-only callers may request an
:: approval prompt before the browser-method menu.
::
:: Usage: call authenticate
::
:: Output: app.git_login.login
:: Returns: 0 when authenticated and Git credentials are configured
::          1 when login is declined, cancelled, or fails
:: Requires: gh, chooseloginbrowser, rundevicelogin
:: Dependencies
::   ChooseLoginBrowser RunDeviceLogin
:: ============================================================
:Authenticate
for /f "tokens=1 delims==" %%v in ('set gla_ 2^>nul') do set "%%v="
if defined _gla_rc (set "_gla_rc=" & exit /b %_gla_rc%)
echo Checking GitHub login...
gh auth status --hostname github.com >nul 2>nul
if not errorlevel 1 goto :_Authenticate_ready
echo GitHub login is required.
if /I "%app.git_login.login.request%"=="no" (echo ERROR: Login was disabled by the caller. & set "_gla_rc=1" & goto :Authenticate)
if /I not "%app.git_login.login.request%"=="ask" goto :_Authenticate_browser
if /I not "%app.git_login.browser.request%"=="ask" goto :_Authenticate_browser
echo Enter y to choose a login method, enter 1-4 now, or enter n to cancel.
echo Append a, for example 4a, to accept identity defaults when repository setup follows.
echo No response within %app.git_login.input.timeout% seconds defaults to n.
set "app.git_login.input="
set "app.git_login.input.status="
<nul set /p "=GitHub login? [y/N/1-4/1a-4a, %app.git_login.input.timeout%s]: "
call :ReadTimedLoginInput
if errorlevel 1 (echo ERROR: Timed GitHub login input failed. & set "_gla_rc=1" & goto :Authenticate)
if /I "%app.git_login.input.status%"=="timeout" echo TIMEOUT: No response; defaulting to no login.
if "%app.git_login.input%"=="1" set "app.git_login.browser.request=1"
if "%app.git_login.input%"=="2" set "app.git_login.browser.request=2"
if "%app.git_login.input%"=="3" set "app.git_login.browser.request=3"
if "%app.git_login.input%"=="4" set "app.git_login.browser.request=4"
if /I "%app.git_login.input%"=="1a" (set "app.git_login.browser.request=1" & set "app.git_login.identity.request=defaults")
if /I "%app.git_login.input%"=="2a" (set "app.git_login.browser.request=2" & set "app.git_login.identity.request=defaults")
if /I "%app.git_login.input%"=="3a" (set "app.git_login.browser.request=3" & set "app.git_login.identity.request=defaults")
if /I "%app.git_login.input%"=="4a" (set "app.git_login.browser.request=4" & set "app.git_login.identity.request=defaults")
if "%app.git_login.input%"=="1" goto :_Authenticate_browser
if "%app.git_login.input%"=="2" goto :_Authenticate_browser
if "%app.git_login.input%"=="3" goto :_Authenticate_browser
if "%app.git_login.input%"=="4" goto :_Authenticate_browser
if /I "%app.git_login.input%"=="1a" goto :_Authenticate_browser
if /I "%app.git_login.input%"=="2a" goto :_Authenticate_browser
if /I "%app.git_login.input%"=="3a" goto :_Authenticate_browser
if /I "%app.git_login.input%"=="4a" goto :_Authenticate_browser
if /I not "%app.git_login.input%"=="y" (echo Cancelled before authentication. & set "_gla_rc=1" & goto :Authenticate)
:_Authenticate_browser
echo.
set "APP_GH_DEVICE_URL=%app.git_login.browser.url%"
call :ChooseLoginBrowser
set "APP_GH_DEVICE_URL="
if errorlevel 1 (echo ERROR: Browser selection failed. & set "_gla_rc=1" & goto :Authenticate)
set "gla_clipboard="
gh auth login --help 2>nul | findstr /L /C:"--clipboard" >nul
if errorlevel 1 goto :_Authenticate_login
set "gla_clipboard=--clipboard"
echo GitHub CLI will copy the one-time device code to the clipboard.
echo.
:_Authenticate_login
call :RunDeviceLogin %gla_clipboard%
set "gla_login_rc=%errorlevel%"
if not "%gla_login_rc%"=="0" (echo ERROR: GitHub login failed or was cancelled. & set "_gla_rc=%gla_login_rc%" & goto :Authenticate)
:_Authenticate_ready
set "app.git_login.login="
for /f "delims=" %%A in ('gh api user --jq ".login" 2^>nul') do set "app.git_login.login=%%A"
if not defined app.git_login.login (echo ERROR: Could not determine the logged-in GitHub account. & set "_gla_rc=1" & goto :Authenticate)
gh auth setup-git --hostname github.com >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI could not configure Git authentication. & set "_gla_rc=1" & goto :Authenticate)
echo Logged in as:
echo   %app.git_login.login%
echo.
set "_gla_rc=0" & goto :Authenticate
:: ============================================================
:: Function ReadTimedLoginInput
:: Reads one console line with a timeout by using the shared
:: PowerShell helper. Empty input and timeout both return n.
::
:: Usage: call ReadTimedLoginInput
::
:: Output: app.git_login.input app.git_login.input.status
:: Returns: 0 when a result was read
::          1 when the helper was unavailable or failed
:: Requires: powershell.exe, git_login_read_timed_input.ps1
:: Dependencies
::   none
:: ============================================================
:ReadTimedLoginInput
set "app.git_login.input="
set "app.git_login.input.status="
set "app.git_login.input.result=%TEMP%\git_login_input_%RANDOM%_%RANDOM%.txt"
if not exist "%app.git_login.input.helper%" (echo. & echo ERROR: Timed-input helper was not found: & echo   %app.git_login.input.helper% & exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%app.git_login.input.helper%" -TimeoutSeconds %app.git_login.input.timeout% -DefaultValue n -ResultPath "%app.git_login.input.result%"
set "glti_rc=%errorlevel%"
if not "%glti_rc%"=="0" (if exist "%app.git_login.input.result%" del /q "%app.git_login.input.result%" >nul 2>nul & exit /b 1)
if not exist "%app.git_login.input.result%" exit /b 1
for /f "usebackq tokens=1,* delims=|" %%A in ("%app.git_login.input.result%") do (set "app.git_login.input.status=%%A" & set "app.git_login.input=%%B")
del /q "%app.git_login.input.result%" >nul 2>nul
set "app.git_login.input.result="
if not defined app.git_login.input set "app.git_login.input=n"
if not defined app.git_login.input.status set "app.git_login.input.status=input"
exit /b 0

:: ============================================================
:: Function ChooseLoginBrowser
:: Chooses how the GitHub device-login page is opened before gh
:: displays the one-time code. gh still owns code generation,
:: browser confirmation, authorization polling, and completion.
::
:: Usage: call chooseloginbrowser
::
:: Returns: 0
:: Requires: openprivatebrowser, start
:: Dependencies
::   OpenPrivateBrowser
:: ============================================================
:ChooseLoginBrowser
for /f "tokens=1 delims==" %%v in ('set glb_ 2^>nul') do set "%%v="
if defined _glb_rc (set "_glb_rc=" & exit /b %_glb_rc%)
echo Open the GitHub device-login page:
echo.
echo   1. Let GitHub CLI open the default browser after showing the code
echo   2. Open the default browser now
echo   3. Open the default browser in private mode now
echo   4. I will open the page myself
echo.
set "app.git_login.browser.choice="
set "app.git_login.browser.preopened="
if /I not "%app.git_login.browser.request%"=="ask" set "app.git_login.browser.choice=%app.git_login.browser.request%"
if defined app.git_login.browser.choice goto :_ChooseLoginBrowser_dispatch
set /p "app.git_login.browser.choice=Choice [1]: "
if not defined app.git_login.browser.choice set "app.git_login.browser.choice=1"
:_ChooseLoginBrowser_dispatch
if /I "%app.git_login.browser.choice%"=="1a" (set "app.git_login.browser.choice=1" & set "app.git_login.identity.request=defaults")
if /I "%app.git_login.browser.choice%"=="2a" (set "app.git_login.browser.choice=2" & set "app.git_login.identity.request=defaults")
if /I "%app.git_login.browser.choice%"=="3a" (set "app.git_login.browser.choice=3" & set "app.git_login.identity.request=defaults")
if /I "%app.git_login.browser.choice%"=="4a" (set "app.git_login.browser.choice=4" & set "app.git_login.identity.request=defaults")
if "%app.git_login.browser.choice%"=="1" goto :_ChooseLoginBrowser_cli
if "%app.git_login.browser.choice%"=="2" goto :_ChooseLoginBrowser_default
if "%app.git_login.browser.choice%"=="3" goto :_ChooseLoginBrowser_private
if "%app.git_login.browser.choice%"=="4" goto :_ChooseLoginBrowser_manual
echo.
echo Invalid choice. Enter 1, 2, 3, 4, or append a.
echo.
goto :ChooseLoginBrowser
:_ChooseLoginBrowser_cli
echo.
echo GitHub CLI will show the code, then offer to open the default browser.
echo.
set "_glb_rc=0" & goto :ChooseLoginBrowser
:_ChooseLoginBrowser_default
start "" "%app.git_login.browser.url%"
set "app.git_login.browser.preopened=1"
echo.
echo The device-login page was sent to the default browser.
echo GitHub CLI will poll without opening another tab.
echo.
set "_glb_rc=0" & goto :ChooseLoginBrowser
:_ChooseLoginBrowser_private
call :OpenPrivateBrowser
if not errorlevel 1 goto :_ChooseLoginBrowser_private_ready
echo.
echo Could not open a supported browser in private mode automatically.
echo Open this page in a private browser window:
echo   %app.git_login.browser.url%
echo.
set "app.git_login.browser.preopened=1"
echo GitHub CLI will poll without opening another tab.
echo.
set "_glb_rc=0" & goto :ChooseLoginBrowser
:_ChooseLoginBrowser_private_ready
set "app.git_login.browser.preopened=1"
echo.
echo The device-login page was opened in a private browser window.
echo GitHub CLI will poll without opening another tab.
echo.
set "_glb_rc=0" & goto :ChooseLoginBrowser
:_ChooseLoginBrowser_manual
set "app.git_login.browser.preopened=1"
echo.
echo Open this page:
echo   %app.git_login.browser.url%
echo.
echo GitHub CLI will poll without opening another tab.
echo.
set "_glb_rc=0" & goto :ChooseLoginBrowser
:: ============================================================
:: Function RunDeviceLogin
:: Runs gh's normal web-device flow. When the page was already
:: opened by the wrapper or user, automatically supplies the Enter
:: requested by gh and gives gh a temporary no-op browser command.
:: gh still generates the code, copies it when supported, polls
:: GitHub, and determines authentication completion.
::
:: Usage: call rundevicelogin [gh auth login options]
::
:: Returns: gh auth login exit code
:: Requires: gh
:: Dependencies
::   none
:: ============================================================
:RunDeviceLogin
for /f "tokens=1 delims==" %%v in ('set glr_ 2^>nul') do set "%%v="
if defined _glr_rc (set "_glr_rc=" & exit /b %_glr_rc%)
if not defined app.git_login.browser.preopened goto :_RunDeviceLogin_normal
set "glr_browser_was_defined="
if defined GH_BROWSER set "glr_browser_was_defined=1"
set "glr_browser_saved=%GH_BROWSER%"
set "app.git_login.browser.noop=%TEMP%\gh-browser-noop-%RANDOM%-%RANDOM%.cmd"
>"%app.git_login.browser.noop%" echo @exit /b 0
if not exist "%app.git_login.browser.noop%" (echo ERROR: Could not create temporary no-op browser command. & set "_glr_rc=1" & goto :RunDeviceLogin)
set "GH_BROWSER=%app.git_login.browser.noop%"
echo.| gh auth login --hostname github.com --git-protocol https --web %*
set "glr_login_rc=%errorlevel%"
if defined glr_browser_was_defined goto :_RunDeviceLogin_restore
set "GH_BROWSER="
goto :_RunDeviceLogin_cleanup
:_RunDeviceLogin_restore
set "GH_BROWSER=%glr_browser_saved%"
:_RunDeviceLogin_cleanup
if exist "%app.git_login.browser.noop%" del /q "%app.git_login.browser.noop%" >nul 2>nul
set "app.git_login.browser.noop="
set "_glr_rc=%glr_login_rc%" & goto :RunDeviceLogin
:_RunDeviceLogin_normal
gh auth login --hostname github.com --git-protocol https --web %*
set "_glr_rc=%errorlevel%" & goto :RunDeviceLogin
:: ============================================================
:: Function OpenPrivateBrowser
:: Opens the GitHub device page in a private window. It prefers
:: the configured default browser when its ProgId identifies Edge,
:: Chrome, Brave, or Firefox, then falls back to any installed one.
::
:: Usage: call openprivatebrowser
::
:: Returns: 0 when launched, 1 when no supported browser is found
:: Requires: reg.exe, start
:: Dependencies
::   FindPrivateEdge FindPrivateChrome FindPrivateBrave FindPrivateFirefox
:: ============================================================
:OpenPrivateBrowser
set "glp_prog="
set "glp_family="
set "glp_exe="
set "glp_arg="
for /f "tokens=3" %%A in ('reg query "HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" /v ProgId 2^>nul ^| findstr /I /C:"ProgId"') do set "glp_prog=%%A"
if not defined glp_prog goto :_OpenPrivateBrowser_any
echo(%glp_prog%| findstr /I /C:"MSEdge" >nul
if not errorlevel 1 set "glp_family=edge"
if defined glp_family goto :_OpenPrivateBrowser_family
echo(%glp_prog%| findstr /I /C:"Chrome" >nul
if not errorlevel 1 set "glp_family=chrome"
if defined glp_family goto :_OpenPrivateBrowser_family
echo(%glp_prog%| findstr /I /C:"Brave" >nul
if not errorlevel 1 set "glp_family=brave"
if defined glp_family goto :_OpenPrivateBrowser_family
echo(%glp_prog%| findstr /I /C:"Firefox" >nul
if not errorlevel 1 set "glp_family=firefox"
:_OpenPrivateBrowser_family
if /I "%glp_family%"=="edge" call :FindPrivateEdge
if defined glp_exe goto :_OpenPrivateBrowser_launch
if /I "%glp_family%"=="chrome" call :FindPrivateChrome
if defined glp_exe goto :_OpenPrivateBrowser_launch
if /I "%glp_family%"=="brave" call :FindPrivateBrave
if defined glp_exe goto :_OpenPrivateBrowser_launch
if /I "%glp_family%"=="firefox" call :FindPrivateFirefox
if defined glp_exe goto :_OpenPrivateBrowser_launch
:_OpenPrivateBrowser_any
call :FindPrivateEdge
if defined glp_exe goto :_OpenPrivateBrowser_launch
call :FindPrivateChrome
if defined glp_exe goto :_OpenPrivateBrowser_launch
call :FindPrivateBrave
if defined glp_exe goto :_OpenPrivateBrowser_launch
call :FindPrivateFirefox
if defined glp_exe goto :_OpenPrivateBrowser_launch
exit /b 1
:_OpenPrivateBrowser_launch
start "" "%glp_exe%" %glp_arg% "%app.git_login.browser.url%"
if errorlevel 1 exit /b 1
exit /b 0
:: ============================================================
:: Function FindPrivateEdge
:: Selects an installed Microsoft Edge executable.
::
:: Usage: call findprivateedge
::
:: Output: glp_exe, glp_arg
:: Returns: 0
:: Requires: none
:: Dependencies
::   none
:: ============================================================
:FindPrivateEdge
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set "glp_exe=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not defined glp_exe if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set "glp_exe=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if not defined glp_exe if exist "%LocalAppData%\Microsoft\Edge\Application\msedge.exe" set "glp_exe=%LocalAppData%\Microsoft\Edge\Application\msedge.exe"
if defined glp_exe set "glp_arg=--inprivate"
exit /b 0
:: ============================================================
:: Function FindPrivateChrome
:: Selects an installed Google Chrome executable.
::
:: Usage: call findprivatechrome
::
:: Output: glp_exe, glp_arg
:: Returns: 0
:: Requires: none
:: Dependencies
::   none
:: ============================================================
:FindPrivateChrome
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "glp_exe=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined glp_exe if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "glp_exe=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined glp_exe if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "glp_exe=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if defined glp_exe set "glp_arg=--incognito"
exit /b 0
:: ============================================================
:: Function FindPrivateBrave
:: Selects an installed Brave executable.
::
:: Usage: call findprivatebrave
::
:: Output: glp_exe, glp_arg
:: Returns: 0
:: Requires: none
:: Dependencies
::   none
:: ============================================================
:FindPrivateBrave
if exist "%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe" set "glp_exe=%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe"
if not defined glp_exe if exist "%ProgramFiles(x86)%\BraveSoftware\Brave-Browser\Application\brave.exe" set "glp_exe=%ProgramFiles(x86)%\BraveSoftware\Brave-Browser\Application\brave.exe"
if not defined glp_exe if exist "%LocalAppData%\BraveSoftware\Brave-Browser\Application\brave.exe" set "glp_exe=%LocalAppData%\BraveSoftware\Brave-Browser\Application\brave.exe"
if defined glp_exe set "glp_arg=--incognito"
exit /b 0
:: ============================================================
:: Function FindPrivateFirefox
:: Selects an installed Mozilla Firefox executable.
::
:: Usage: call findprivatefirefox
::
:: Output: glp_exe, glp_arg
:: Returns: 0
:: Requires: none
:: Dependencies
::   none
:: ============================================================
:FindPrivateFirefox
if exist "%ProgramFiles%\Mozilla Firefox\firefox.exe" set "glp_exe=%ProgramFiles%\Mozilla Firefox\firefox.exe"
if not defined glp_exe if exist "%ProgramFiles(x86)%\Mozilla Firefox\firefox.exe" set "glp_exe=%ProgramFiles(x86)%\Mozilla Firefox\firefox.exe"
if not defined glp_exe if exist "%LocalAppData%\Mozilla Firefox\firefox.exe" set "glp_exe=%LocalAppData%\Mozilla Firefox\firefox.exe"
if defined glp_exe set "glp_arg=-private-window"
exit /b 0
:: ============================================================
:: Function ResolveRepository
:: Resolves the configured repository, canonical HTTPS URL, owner,
:: name, and push permission for the authenticated account.
::
:: Usage: call resolverepository
::
:: Returns: 0 when resolved and visible
::          1 when missing, invisible, or permission data is unavailable
:: Requires: gh
:: Dependencies
::   none
:: ============================================================
:ResolveRepository
for /f "tokens=1 delims==" %%v in ('set glr_ 2^>nul') do set "%%v="
if defined _glr_rc (set "_glr_rc=" & exit /b %_glr_rc%)
if defined app.git_login.repo.input goto :_ResolveRepository_query
set /p "app.git_login.repo.input=GitHub repository URL or OWNER/REPO: "
:_ResolveRepository_query
if not defined app.git_login.repo.input (echo ERROR: A GitHub repository is required. & set "_glr_rc=1" & goto :ResolveRepository)
for /f "delims=" %%A in ('gh repo view "%app.git_login.repo.input%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_login.repo.slug=%%A"
for /f "delims=" %%A in ('gh repo view "%app.git_login.repo.input%" --json name --jq ".name" 2^>nul') do set "app.git_login.repo.name=%%A"
for /f "delims=" %%A in ('gh repo view "%app.git_login.repo.input%" --json url --jq ".url" 2^>nul') do set "app.git_login.repo.web=%%A"
if not defined app.git_login.repo.slug goto :_ResolveRepository_missing
for /f "tokens=1 delims=/" %%A in ("%app.git_login.repo.slug%") do set "app.git_login.repo.owner=%%A"
set "app.git_login.repo.url=%app.git_login.repo.web%.git"
for /f "delims=" %%A in ('gh api "repos/%app.git_login.repo.slug%" --jq ".permissions.push" 2^>nul') do set "app.git_login.can.push=%%A"
if not defined app.git_login.can.push (echo ERROR: Could not determine repository permissions. & set "_glr_rc=1" & goto :ResolveRepository)
echo Repository:
echo   %app.git_login.repo.slug%
echo.
set "_glr_rc=0" & goto :ResolveRepository
:_ResolveRepository_missing
echo ERROR: Repository was not found or is not visible:
echo   %app.git_login.repo.input%
echo.
echo For a repository that does not exist yet, use:
echo   tools\git_create_repository.bat
set "_glr_rc=1" & goto :ResolveRepository
:: ============================================================
:: Function ResolveIdentity
:: Resolves Git author name and email from repository-local values,
:: explicit project values, global Git values, and the authenticated
:: GitHub account. Missing GitHub email falls back to a noreply address.
::
:: Pressing Enter at either prompt accepts the displayed default.
:: The selected values are later written only to this repository.
::
:: Usage: call resolveidentity
::
:: Output:
::   app.git_login.git.name
::   app.git_login.git.email
::
:: Returns: 0 when both values are present
::          1 when either remains missing
:: Requires: git, authenticated gh for GitHub-derived defaults
:: Dependencies
::   none
:: ============================================================
:ResolveIdentity
for /f "tokens=1 delims==" %%v in ('set gli_ 2^>nul') do set "%%v="
if defined _gli_rc (set "_gli_rc=" & exit /b %_gli_rc%)
if not defined app.git_login.repo.exists goto :_ResolveIdentity_project
for /f "delims=" %%A in ('git config --local --get user.name 2^>nul') do set "app.git_login.git.name=%%A"
for /f "delims=" %%A in ('git config --local --get user.email 2^>nul') do set "app.git_login.git.email=%%A"
:_ResolveIdentity_project
if defined app.git_name set "app.git_login.git.name=%app.git_name%"
if defined app.git_email set "app.git_login.git.email=%app.git_email%"
if defined app.git_login.git.name goto :_ResolveIdentity_global_email
for /f "delims=" %%A in ('git config --global --get user.name 2^>nul') do set "app.git_login.git.name=%%A"
:_ResolveIdentity_global_email
if defined app.git_login.git.email goto :_ResolveIdentity_github_name
for /f "delims=" %%A in ('git config --global --get user.email 2^>nul') do set "app.git_login.git.email=%%A"
:_ResolveIdentity_github_name
if defined app.git_login.git.name goto :_ResolveIdentity_github_email
if defined app.git_login.login set "app.git_login.git.name=%app.git_login.login%"
:_ResolveIdentity_github_email
if defined app.git_login.git.email goto :_ResolveIdentity_prompt
for /f "delims=" %%A in ('gh api user --jq ".email // empty" 2^>nul') do if not defined app.git_login.git.email set "app.git_login.git.email=%%A"
if defined app.git_login.git.email goto :_ResolveIdentity_prompt
for /f "delims=" %%A in ('gh api user --jq ".id" 2^>nul') do if not defined gli_github_id set "gli_github_id=%%A"
if defined gli_github_id if defined app.git_login.login set "app.git_login.git.email=%gli_github_id%+%app.git_login.login%@users.noreply.github.com"
if not defined app.git_login.git.email if defined app.git_login.login set "app.git_login.git.email=%app.git_login.login%@users.noreply.github.com"
:_ResolveIdentity_prompt
echo Git author identity:
if /I "%app.git_login.identity.request%"=="defaults" goto :_ResolveIdentity_validate
set "app.git_login.input="
set /p "app.git_login.input=Git name [%app.git_login.git.name%]: "
if defined app.git_login.input set "app.git_login.git.name=%app.git_login.input%"
set "app.git_login.input="
set /p "app.git_login.input=Git email [%app.git_login.git.email%]: "
if defined app.git_login.input set "app.git_login.git.email=%app.git_login.input%"
:_ResolveIdentity_validate
if not defined app.git_login.git.name (echo ERROR: Git name is required. & set "_gli_rc=1" & goto :ResolveIdentity)
if not defined app.git_login.git.email (echo ERROR: Git email is required. & set "_gli_rc=1" & goto :ResolveIdentity)
echo   Name: %app.git_login.git.name%
echo   Email: %app.git_login.git.email%
set "_gli_rc=0" & goto :ResolveIdentity
:: ============================================================
:: Function ConfigureFork
:: Creates or reuses the authenticated user's personal fork when
:: direct push permission is unavailable, or configures read-only mode
:: when fork creation is declined.
::
:: Usage: call configurefork
::
:: Output:
::   app.git_login.use.fork
::   app.git_login.read.only
::   app.git_login.fork.slug
::   app.git_login.fork.url
::   app.git_login.target.origin
::
:: Returns: 0 when direct read-only or writable fork mode is ready
::          1 on collision, creation, wait, or permission failure
:: Requires: waitforfork, gh
:: Dependencies
::   none
:: ============================================================
:ConfigureFork
for /f "tokens=1 delims==" %%v in ('set glf_ 2^>nul') do set "%%v="
if defined _glf_rc (set "_glf_rc=" & exit /b %_glf_rc%)
echo Direct push permission is unavailable.
set "glf_confirm="
if /I "%app.git_login.fork.request%"=="no" goto :_ConfigureFork_declined
if /I "%app.git_login.fork.request%"=="yes" goto :_ConfigureFork_confirmed
set /p "glf_confirm=Create or use a personal fork under %app.git_login.login%? [Y/n]: "
if not defined glf_confirm goto :_ConfigureFork_confirmed
if /I "%glf_confirm%"=="y" goto :_ConfigureFork_confirmed
if /I "%glf_confirm%"=="yes" goto :_ConfigureFork_confirmed
if /I "%glf_confirm%"=="n" goto :_ConfigureFork_declined
if /I "%glf_confirm%"=="no" goto :_ConfigureFork_declined
echo Enter y or n.
goto :ConfigureFork
:_ConfigureFork_declined
set "app.git_login.target.origin=%app.git_login.repo.url%"
set "app.git_login.read.only=1"
set "app.git_login.push.request=no"
echo Fork skipped. origin will remain the original repository.
echo Push was disabled because this account cannot push directly.
echo.
set "_glf_rc=0" & goto :ConfigureFork
:_ConfigureFork_confirmed
set "app.git_login.use.fork=1"
set "app.git_login.fork.slug=%app.git_login.login%/%app.git_login.repo.name%"
set "app.git_login.fork.url=https://github.com/%app.git_login.fork.slug%.git"
gh repo view "%app.git_login.fork.slug%" >nul 2>nul
if errorlevel 1 goto :_ConfigureFork_plan_create
set "glf_is_fork="
set "glf_parent="
set "glf_source="
for /f "delims=" %%A in ('gh api "repos/%app.git_login.fork.slug%" --jq ".fork" 2^>nul') do set "glf_is_fork=%%A"
for /f "delims=" %%A in ('gh api "repos/%app.git_login.fork.slug%" --jq ".parent.full_name // empty" 2^>nul') do set "glf_parent=%%A"
for /f "delims=" %%A in ('gh api "repos/%app.git_login.fork.slug%" --jq ".source.full_name // empty" 2^>nul') do set "glf_source=%%A"
if /I not "%glf_is_fork%"=="true" goto :_ConfigureFork_collision
if /I "%glf_parent%"=="%app.git_login.repo.slug%" goto :_ConfigureFork_permission
if /I "%glf_source%"=="%app.git_login.repo.slug%" goto :_ConfigureFork_permission
echo ERROR: Existing repository is not a fork of:
echo   %app.git_login.repo.slug%
echo Repository:
echo   %app.git_login.fork.slug%
set "_glf_rc=1" & goto :ConfigureFork
:_ConfigureFork_collision
echo ERROR: %app.git_login.fork.slug% already exists but is not a fork.
set "_glf_rc=1" & goto :ConfigureFork
:_ConfigureFork_plan_create
set "app.git_login.fork.create=1"
set "app.git_login.target.origin=%app.git_login.fork.url%"
echo A personal fork will be created after LOGIN confirmation:
echo   %app.git_login.fork.slug%
echo.
set "_glf_rc=0" & goto :ConfigureFork
:_ConfigureFork_permission
set "glf_can_push="
for /f "delims=" %%A in ('gh api "repos/%app.git_login.fork.slug%" --jq ".permissions.push" 2^>nul') do set "glf_can_push=%%A"
if /I not "%glf_can_push%"=="true" (echo ERROR: The account cannot push to the selected fork. & set "_glf_rc=1" & goto :ConfigureFork)
set "app.git_login.target.origin=%app.git_login.fork.url%"
echo Existing fork is ready:
echo   %app.git_login.fork.slug%
echo.
set "_glf_rc=0" & goto :ConfigureFork
:: ============================================================
:: Function EnsureFork
:: Creates the planned personal fork through the GitHub API only
:: after LOGIN confirmation, waits for visibility, and verifies
:: push permission. It does not clone or modify Git remotes.
::
:: Usage: call ensurefork
::
:: Returns: 0 when the writable fork is ready
::          1 on creation, wait, or permission failure
:: Requires: waitforfork, gh
:: Dependencies
::   WaitForFork
:: ============================================================
:EnsureFork
for /f "tokens=1 delims==" %%v in ('set gle_ 2^>nul') do set "%%v="
if defined _gle_rc (set "_gle_rc=" & exit /b %_gle_rc%)
if not defined app.git_login.fork.create goto :_EnsureFork_permission
echo Creating personal fork:
echo   %app.git_login.fork.slug%
gh api --method POST "repos/%app.git_login.repo.slug%/forks" >nul
if errorlevel 1 (echo ERROR: GitHub could not create the fork. & set "_gle_rc=1" & goto :EnsureFork)
call :WaitForFork
if errorlevel 1 (set "_gle_rc=%errorlevel%" & goto :EnsureFork)
set "app.git_login.fork.create="
:_EnsureFork_permission
set "gle_can_push="
for /f "delims=" %%A in ('gh api "repos/%app.git_login.fork.slug%" --jq ".permissions.push" 2^>nul') do set "gle_can_push=%%A"
if /I not "%gle_can_push%"=="true" (echo ERROR: The account cannot push to the selected fork. & set "_gle_rc=1" & goto :EnsureFork)
set "app.git_login.target.origin=%app.git_login.fork.url%"
set "_gle_rc=0" & goto :EnsureFork
:: ============================================================
:: Function WaitForFork
:: Polls GitHub until the requested personal fork is visible, up to
:: approximately thirty seconds.
::
:: Usage: call waitforfork
::
:: Returns: 0 when visible
::          1 after timeout
:: Requires: gh, timeout
:: Dependencies
::   none
:: ============================================================
:WaitForFork
for /f "tokens=1 delims==" %%v in ('set glw_ 2^>nul') do set "%%v="
if defined _glw_rc (set "_glw_rc=" & exit /b %_glw_rc%)
set "glw_count=0"
:_WaitForFork_loop
gh repo view "%app.git_login.fork.slug%" >nul 2>nul
if not errorlevel 1 (set "_glw_rc=0" & goto :WaitForFork)
set /a glw_count+=1
if %glw_count% GEQ 15 goto :_WaitForFork_timeout
timeout /t 2 /nobreak >nul
goto :_WaitForFork_loop
:_WaitForFork_timeout
echo ERROR: The fork was requested but did not become available:
echo   %app.git_login.fork.slug%
set "_glw_rc=1" & goto :WaitForFork
:: ============================================================
:: Function ShowPlan
:: Displays the local initialization, identity, remote, branch, and
:: push actions that confirmation will authorize.
::
:: Usage: call showplan
::
:: Returns: 0
:: Requires: none
:: Dependencies
::   none
:: ============================================================
:ShowPlan
echo.
echo ============================================================
echo  Planned GitHub setup
echo ============================================================
echo.
echo GitHub account:
echo   %app.git_login.login%
echo.
echo Repository:
echo   %app.git_login.repo.slug%
echo.
if defined app.git_login.repo.exists (echo Local repository: & echo   use existing Git worktree) else (echo Local repository: & echo   initialize this project folder)
echo.
echo Branch:
echo   %app.git_login.branch%
echo.
echo Git author:
echo   Name: %app.git_login.git.name%
echo   Email: %app.git_login.git.email%
echo.
if defined app.git_login.read.only goto :_ShowPlan_read_only
if defined app.git_login.use.fork goto :_ShowPlan_fork
echo Permission mode:
echo   direct push
echo.
echo origin:
echo   %app.git_login.target.origin%
goto :_ShowPlan_push
:_ShowPlan_read_only
echo Permission mode:
echo   read-only original repository
echo.
echo origin:
echo   %app.git_login.target.origin%
goto :_ShowPlan_push
:_ShowPlan_fork
if defined app.git_login.fork.create (echo Fork action: & echo   create %app.git_login.fork.slug%) else (echo Fork action: & echo   reuse %app.git_login.fork.slug%)
echo.
echo origin:
echo   %app.git_login.target.origin%
echo.
echo upstream:
echo   %app.git_login.repo.url%
:_ShowPlan_push
echo.
if /I "%app.git_login.push.request%"=="yes" echo Existing commits will be pushed to origin with upstream tracking.
if /I "%app.git_login.push.request%"=="no" echo Existing commits will not be pushed.
echo.
exit /b 0
:: ============================================================
:: Function CaptureRemotes
:: Records original origin and upstream URLs before configuration.
::
:: Usage: call captureremotes
::
:: Returns: 0
:: Requires: git
:: Dependencies
::   none
:: ============================================================
:CaptureRemotes
set "app.git_login.original.origin.exists="
set "app.git_login.original.origin.url="
set "app.git_login.original.upstream.exists="
set "app.git_login.original.upstream.url="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_login.original.origin.url=%%A"
if defined app.git_login.original.origin.url set "app.git_login.original.origin.exists=1"
for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "app.git_login.original.upstream.url=%%A"
if defined app.git_login.original.upstream.url set "app.git_login.original.upstream.exists=1"
exit /b 0
:: ============================================================
:: Function ConfigureRemotes
:: Sets origin to the writable target and, for a fork workflow,
:: upstream to the source repository.
::
:: Usage: call configureremotes
::
:: Returns: 0 when configured
::          1 on a Git remote failure
:: Requires: git
:: Dependencies
::   none
:: ============================================================
:ConfigureRemotes
if not defined app.git_login.use.fork goto :_ConfigureRemotes_origin
git remote get-url upstream >nul 2>nul
if errorlevel 1 goto :_ConfigureRemotes_add_upstream
git remote set-url upstream "%app.git_login.repo.url%"
if errorlevel 1 exit /b 1
goto :_ConfigureRemotes_origin
:_ConfigureRemotes_add_upstream
git remote add upstream "%app.git_login.repo.url%"
if errorlevel 1 exit /b 1
:_ConfigureRemotes_origin
git remote get-url origin >nul 2>nul
if errorlevel 1 goto :_ConfigureRemotes_add_origin
git remote set-url origin "%app.git_login.target.origin%"
if errorlevel 1 exit /b 1
exit /b 0
:_ConfigureRemotes_add_origin
git remote add origin "%app.git_login.target.origin%"
if errorlevel 1 exit /b 1
exit /b 0
:: ============================================================
:: Function RestoreRemotes
:: Restores original remote URLs or removes remotes newly added by a
:: failed configuration attempt.
::
:: Usage: call restoreremotes
::
:: Returns: 0 when restoration succeeds
::          1 when one or more restoration commands fail
:: Requires: git
:: Dependencies
::   none
:: ============================================================
:RestoreRemotes
for /f "tokens=1 delims==" %%v in ('set glx_ 2^>nul') do set "%%v="
if defined _glx_rc (set "_glx_rc=" & exit /b %_glx_rc%)
set "glx_failed="
if defined app.git_login.original.origin.exists goto :_RestoreRemotes_origin_set
git remote get-url origin >nul 2>nul
if errorlevel 1 goto :_RestoreRemotes_upstream
git remote remove origin >nul 2>nul
if errorlevel 1 set "glx_failed=1"
goto :_RestoreRemotes_upstream
:_RestoreRemotes_origin_set
git remote set-url origin "%app.git_login.original.origin.url%" >nul 2>nul
if errorlevel 1 set "glx_failed=1"
:_RestoreRemotes_upstream
if defined app.git_login.original.upstream.exists goto :_RestoreRemotes_upstream_set
git remote get-url upstream >nul 2>nul
if errorlevel 1 goto :_RestoreRemotes_result
git remote remove upstream >nul 2>nul
if errorlevel 1 set "glx_failed=1"
goto :_RestoreRemotes_result
:_RestoreRemotes_upstream_set
git remote set-url upstream "%app.git_login.original.upstream.url%" >nul 2>nul
if errorlevel 1 set "glx_failed=1"
:_RestoreRemotes_result
if defined glx_failed (set "_glx_rc=1" & goto :RestoreRemotes)
set "_glx_rc=0" & goto :RestoreRemotes
:: ============================================================
:: Function ParseArgs
:: Parses repository, branch, browser, fork, identity, push, and help arguments.
::
:: Usage: call parseargs [repo REPO] [branch BRANCH] [browser METHOD] [fork MODE] [identity MODE] [push MODE] [prepared MODE] [help]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: Dependencies
::   none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="authenticate" goto :_ParseArgs_authenticate
if /I "%~1"=="auth" goto :_ParseArgs_authenticate
if /I "%~1"=="login" goto :_ParseArgs_login
if /I "%~1"=="repo" goto :_ParseArgs_repo
if /I "%~1"=="url" goto :_ParseArgs_repo
if /I "%~1"=="branch" goto :_ParseArgs_branch
if /I "%~1"=="browser" goto :_ParseArgs_browser
if /I "%~1"=="fork" goto :_ParseArgs_fork
if /I "%~1"=="identity" goto :_ParseArgs_identity
if /I "%~1"=="gitname" goto :_ParseArgs_gitname
if /I "%~1"=="gitemail" goto :_ParseArgs_gitemail
if /I "%~1"=="push" goto :_ParseArgs_push
if /I "%~1"=="prepared" goto :_ParseArgs_prepared
if /I "%~1"=="pause" goto :_ParseArgs_pause
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="-help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/h" goto :_ParseArgs_help
if /I "%~1"=="-h" goto :_ParseArgs_help
if /I "%~1"=="--h" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if /I "%~1"=="-?" goto :_ParseArgs_help
if /I "%~1"=="--?" goto :_ParseArgs_help
if /I "%~1"=="?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_authenticate
set "app.git_login.authenticate.only=1"
shift
goto :ParseArgs
:_ParseArgs_login
if "%~2"=="" (echo ERROR: login requires ask, yes, or no. & exit /b 2)
if /I "%~2"=="ask" set "app.git_login.login.request=ask"
if /I "%~2"=="yes" set "app.git_login.login.request=yes"
if /I "%~2"=="no" set "app.git_login.login.request=no"
if /I "%~2"=="ask" goto :_ParseArgs_login_ready
if /I "%~2"=="yes" goto :_ParseArgs_login_ready
if /I "%~2"=="no" goto :_ParseArgs_login_ready
echo ERROR: login requires ask, yes, or no.
exit /b 2
:_ParseArgs_login_ready
shift
shift
goto :ParseArgs
:_ParseArgs_repo
if "%~2"=="" (echo ERROR: repo requires OWNER/REPO or a URL. & exit /b 2)
set "app.git_login.repo.input=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_branch
if "%~2"=="" (echo ERROR: branch requires a name. & exit /b 2)
set "app.git_login.branch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_browser
if "%~2"=="" (echo ERROR: browser requires ask, 1-4, or 1a-4a. & exit /b 2)
if /I "%~2"=="ask" set "app.git_login.browser.request=ask"
if "%~2"=="1" set "app.git_login.browser.request=1"
if "%~2"=="2" set "app.git_login.browser.request=2"
if "%~2"=="3" set "app.git_login.browser.request=3"
if "%~2"=="4" set "app.git_login.browser.request=4"
if /I "%~2"=="1a" (set "app.git_login.browser.request=1" & set "app.git_login.identity.request=defaults")
if /I "%~2"=="2a" (set "app.git_login.browser.request=2" & set "app.git_login.identity.request=defaults")
if /I "%~2"=="3a" (set "app.git_login.browser.request=3" & set "app.git_login.identity.request=defaults")
if /I "%~2"=="4a" (set "app.git_login.browser.request=4" & set "app.git_login.identity.request=defaults")
if /I "%~2"=="ask" goto :_ParseArgs_browser_ready
if "%~2"=="1" goto :_ParseArgs_browser_ready
if "%~2"=="2" goto :_ParseArgs_browser_ready
if "%~2"=="3" goto :_ParseArgs_browser_ready
if "%~2"=="4" goto :_ParseArgs_browser_ready
if /I "%~2"=="1a" goto :_ParseArgs_browser_ready
if /I "%~2"=="2a" goto :_ParseArgs_browser_ready
if /I "%~2"=="3a" goto :_ParseArgs_browser_ready
if /I "%~2"=="4a" goto :_ParseArgs_browser_ready
echo ERROR: browser requires ask, 1-4, or 1a-4a.
exit /b 2
:_ParseArgs_browser_ready
shift
shift
goto :ParseArgs
:_ParseArgs_fork
if "%~2"=="" (echo ERROR: fork requires ask, yes, or no. & exit /b 2)
if /I "%~2"=="ask" set "app.git_login.fork.request=ask"
if /I "%~2"=="yes" set "app.git_login.fork.request=yes"
if /I "%~2"=="no" set "app.git_login.fork.request=no"
if /I "%~2"=="ask" goto :_ParseArgs_fork_ready
if /I "%~2"=="yes" goto :_ParseArgs_fork_ready
if /I "%~2"=="no" goto :_ParseArgs_fork_ready
echo ERROR: fork requires ask, yes, or no.
exit /b 2
:_ParseArgs_fork_ready
shift
shift
goto :ParseArgs
:_ParseArgs_identity
if "%~2"=="" (echo ERROR: identity requires ask or defaults. & exit /b 2)
if /I "%~2"=="ask" set "app.git_login.identity.request=ask"
if /I "%~2"=="defaults" set "app.git_login.identity.request=defaults"
if /I "%~2"=="ask" goto :_ParseArgs_identity_ready
if /I "%~2"=="defaults" goto :_ParseArgs_identity_ready
echo ERROR: identity requires ask or defaults.
exit /b 2
:_ParseArgs_identity_ready
shift
shift
goto :ParseArgs
:_ParseArgs_gitname
if "%~2"=="" (echo ERROR: gitname requires a value. & exit /b 2)
set "app.git_name=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_gitemail
if "%~2"=="" (echo ERROR: gitemail requires a value. & exit /b 2)
set "app.git_email=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_push
if "%~2"=="" (echo ERROR: push requires yes or no. & exit /b 2)
if /I "%~2"=="yes" set "app.git_login.push.request=yes"
if /I "%~2"=="no" set "app.git_login.push.request=no"
if /I "%~2"=="yes" goto :_ParseArgs_push_ready
if /I "%~2"=="no" goto :_ParseArgs_push_ready
echo ERROR: push requires yes or no.
exit /b 2
:_ParseArgs_push_ready
shift
shift
goto :ParseArgs
:_ParseArgs_prepared
if "%~2"=="" (echo ERROR: prepared requires yes or no. & exit /b 2)
if /I "%~2"=="yes" set "app.git_login.prepared.request=yes"
if /I "%~2"=="no" set "app.git_login.prepared.request=no"
if /I "%~2"=="yes" goto :_ParseArgs_prepared_ready
if /I "%~2"=="no" goto :_ParseArgs_prepared_ready
echo ERROR: prepared requires yes or no.
exit /b 2
:_ParseArgs_prepared_ready
shift
shift
goto :ParseArgs
:_ParseArgs_pause
if "%~2"=="" (echo ERROR: pause requires yes or no. & exit /b 2)
if /I "%~2"=="yes" set "app.git_login.pause.request=yes"
if /I "%~2"=="no" set "app.git_login.pause.request=no"
if /I "%~2"=="yes" goto :_ParseArgs_pause_ready
if /I "%~2"=="no" goto :_ParseArgs_pause_ready
echo ERROR: pause requires yes or no.
exit /b 2
:_ParseArgs_pause_ready
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_login.help=1"
exit /b 0
:: ============================================================
:: Function ShowHelp
:: Displays login, repository, branch, browser, fork, identity, and push behavior.
::
:: Usage: call showhelp
::
:: Returns: 0
:: Requires: none
:: Dependencies
::   none
:: ============================================================
:ShowHelp
echo.
echo git_login.bat
echo.
echo Usage:
echo   git_login.bat [OPTIONS]
echo.
echo Modes:
echo   authenticate          Authenticate only; do not change repository state
echo   auth                  Alias for authenticate
echo.
echo Options:
echo   login ask^|yes^|no    Approval behavior when authentication is missing
echo   repo OWNER/REPO
echo   repo URL
echo   branch NAME
echo   browser ask^|1^|2^|3^|4^|1a^|2a^|3a^|4a
echo   fork ask^|yes^|no
echo   identity ask^|defaults
echo   gitname NAME
echo   gitemail EMAIL
echo                        Supplying both values pre-fills local identity
echo   push yes^|no
echo   prepared yes^|no     Skip dependency preparation when already ready
echo   pause yes^|no        Enable or suppress direct-launch pause handling
echo.
echo Help aliases:
echo   help  /help  -help  --help  /h  -h  --h  /?  -?  --?  ?
echo.
echo Browser methods:
echo   Append a to any method to select identity defaults as well.
echo   Authentication-only callers already return before identity prompts.
echo   The initial GitHub login question times out after 20 seconds to no.
echo   1  Let GitHub CLI open the default browser
echo   2  Open the device page in the default browser first
echo   3  Open the device page in a private browser first
echo   4  Do not open a browser on this computer
echo.
echo authenticate returns after GitHub CLI authentication and credential setup.
echo The normal mode authenticates GitHub CLI and configures local Git identity
echo and repository remotes. Direct push is used when permitted; otherwise
echo a matching personal fork can be created or reused. fork no keeps a
echo read-only origin and disables push when direct permission is unavailable.
echo.
echo identity defaults accepts the derived GitHub identity without prompts.
echo push no configures login, identity, and remotes without pushing.
echo GitHub device authorization still requires browser interaction when login
echo is not already available.
echo.
exit /b 0
:: ============================================================
:: Function CleanupTemp
:: Removes temporary preparation logs.
::
:: Usage: call cleanuptemp
::
:: Returns: 0
:: Requires: none
:: Dependencies
::   none
:: ============================================================
:CleanupTemp
for /f "tokens=1 delims==" %%v in ('set glc_ 2^>nul') do set "%%v="
if defined _glc_rc (set "_glc_rc=" & exit /b %_glc_rc%)
if defined app.git_login.prepare.log del /q "%app.git_login.prepare.log%" >nul 2>nul
if defined app.git_login.browser.noop del /q "%app.git_login.browser.noop%" >nul 2>nul
set "app.git_login.prepare.log="
set "app.git_login.browser.noop="
set "APP_GH_DEVICE_URL="
set "_glc_rc=0" & goto :CleanupTemp
:: ============================================================
:: Function PauseIfNeeded
:: Pauses only when the outermost launcher is the cmd.exe /c target.
::
:: Usage: call pauseifneeded
::
:: Returns: 0
:: Requires: isconsole
:: Dependencies
::   IsConsole
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
:: Function IsConsole
:: Detects whether the outermost launcher is running in an existing
:: interactive console.
::
:: Usage: call isconsole
::
:: Returns: 0 when running in an existing console
::          1 when the outermost launcher is the cmd.exe /c target
:: Requires: find.exe
:: Dependencies
::   none
:: ============================================================
:IsConsole
setlocal EnableDelayedExpansion
set "ic_cmdline=!CMDCMDLINE!"
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I " /c " >nul
if errorlevel 1 (endlocal & exit /b 0)
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I "!app.launch.name!" >nul
if errorlevel 1 (endlocal & exit /b 0)
endlocal & exit /b 1
