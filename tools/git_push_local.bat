@echo off
:: ============================================================
:: git_push_local.bat
:: Pushes existing commits from the current named branch. When no
:: upstream exists, origin is used and upstream tracking is created.
::
:: Usage:
::   call tools\git_push_local.bat
::   call tools\git_push_local.bat help
::
:: Returns: 0 on successful push or help
::          1 on preparation, repository, branch, remote, or push failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main,
::           :EnsureGitHubPushReady, :ParseArgs, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_push_local.branch="
set "app.git_push_local.upstream="
set "app.git_push_local.pushed.by.login="
set "app.git_push_local.help="
set "app.git_push_local.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_push_local.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_push_local.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_push_local.rc%
:: ============================================================
:: :Main
:: Validates Git, HEAD, origin, and the current named branch, then
:: pushes through existing tracking or creates origin tracking.
::
:: Usage: call :Main [help]
::
:: Returns: 0 on successful push or help
::          1 on preparation, repository, branch, remote, or push failure
::          2 on invalid arguments
:: Requires: :EnsureGitHubPushReady, :ParseArgs, :ShowHelp,
::           prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gplm_ 2^>nul') do set "%%v="
if defined _gplm_rc (set "_gplm_rc=" & exit /b %_gplm_rc%)
call :ParseArgs %*
set "_gplm_rc=%errorlevel%"
if not "%_gplm_rc%"=="0" goto :Main
if defined app.git_push_local.help goto :_Main_help
echo.
echo ============================================================
echo  Push local commits to GitHub
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gplm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gplm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gplm_rc=1" & goto :Main)
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: No commits exist yet. & set "_gplm_rc=1" & goto :Main)
git remote get-url origin >nul 2>nul
if errorlevel 1 goto :_Main_no_origin
set "app.git_push_local.branch="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_push_local.branch=%%A"
if not defined app.git_push_local.branch (echo ERROR: A named branch is not checked out. & set "_gplm_rc=1" & goto :Main)
git status --short --branch
if errorlevel 1 (echo ERROR: Git status failed. & set "_gplm_rc=1" & goto :Main)
echo.
set "app.git_push_local.pushed.by.login="
call :EnsureGitHubPushReady
set "gplm_auth_rc=%errorlevel%"
if not "%gplm_auth_rc%"=="0" (set "_gplm_rc=%gplm_auth_rc%" & goto :Main)
if defined app.git_push_local.pushed.by.login goto :_Main_success
set "app.git_push_local.upstream="
for /f "delims=" %%A in ('git rev-parse --abbrev-ref --symbolic-full-name @{u} 2^>nul') do set "app.git_push_local.upstream=%%A"
if defined app.git_push_local.upstream goto :_Main_push_tracking
echo No upstream is configured. Creating origin tracking for:
echo   %app.git_push_local.branch%
git push -u origin "%app.git_push_local.branch%"
set "_gplm_rc=%errorlevel%"
goto :_Main_result
:_Main_push_tracking
echo Pushing to configured upstream:
echo   %app.git_push_local.upstream%
git push
set "_gplm_rc=%errorlevel%"
:_Main_result
if "%_gplm_rc%"=="0" goto :_Main_success
echo.
echo ERROR: Push failed.
echo Run just_status.bat for more information.
set "_gplm_rc=1" & goto :Main
:_Main_success
echo.
echo Push complete.
set "_gplm_rc=0" & goto :Main
:_Main_no_origin
echo ERROR: No origin remote is configured.
echo Run:
echo   tools\git_login.bat
set "_gplm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gplm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :EnsureGitHubPushReady
:: Detects a github.com origin and verifies GitHub CLI credentials.
:: Successful preparation is silent. When authentication is absent
:: or unusable, just_login.bat performs login, setup, and the push.
::
:: Usage: call :EnsureGitHubPushReady
::
:: Output:
::   app.git_push_local.pushed.by.login=1 when just_login pushed
::
:: Returns: 0 when direct push is ready or just_login succeeded
::          just_login exit code when login or setup fails
:: Requires: prepare.bat when present, gh for GitHub, just_login.bat
:: ============================================================
:EnsureGitHubPushReady
for /f "tokens=1 delims==" %%v in ('set gplauth_ 2^>nul') do set "%%v="
if defined _gplauth_rc (set "_gplauth_rc=" & exit /b %_gplauth_rc%)
set "app.git_push_local.pushed.by.login="
set "gplauth_origin="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "gplauth_origin=%%A"
if not defined gplauth_origin (set "_gplauth_rc=0" & goto :EnsureGitHubPushReady)
echo(%gplauth_origin%| findstr /I /C:"github.com" >nul
if errorlevel 1 (set "_gplauth_rc=0" & goto :EnsureGitHubPushReady)
if exist "%CD%\prepare.bat" call "%CD%\prepare.bat" repository >nul 2>&1
where gh.exe >nul 2>nul
if errorlevel 1 goto :_EnsureGitHubPushReady_login
gh auth status --hostname github.com >nul 2>nul
if errorlevel 1 goto :_EnsureGitHubPushReady_login
gh auth setup-git --hostname github.com >nul 2>nul
if errorlevel 1 goto :_EnsureGitHubPushReady_login
set "_gplauth_rc=0" & goto :EnsureGitHubPushReady
:_EnsureGitHubPushReady_login
echo GitHub authentication is required before pushing.
echo Starting just_login.bat...
echo.
call "%~dp0just_login.bat"
set "gplauth_login_rc=%errorlevel%"
if "%gplauth_login_rc%"=="0" goto :_EnsureGitHubPushReady_done
echo ERROR: GitHub login or repository setup failed.
set "_gplauth_rc=%gplauth_login_rc%" & goto :EnsureGitHubPushReady
:_EnsureGitHubPushReady_done
set "app.git_push_local.pushed.by.login=1"
set "_gplauth_rc=0" & goto :EnsureGitHubPushReady
:: ============================================================
:: :ParseArgs
:: Accepts only the optional help argument.
::
:: Usage: call :ParseArgs [help]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_help
set "app.git_push_local.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays push and upstream-tracking behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_push_local.bat
echo.
echo Usage:
echo   git_push_local.bat
echo.
echo Existing upstream tracking is honored. Without tracking, the
echo current named branch is pushed to origin with -u.
echo For GitHub, a logged-out session delegates to just_login.bat.
echo Uncommitted files are not included in the push.
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
