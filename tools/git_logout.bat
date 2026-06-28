@echo off
:: ============================================================
:: git_logout.bat
:: Logs GitHub CLI out of github.com and asks Git's credential
:: helper to erase cached HTTPS credentials for github.com.
::
:: Usage:
::   call tools\git_logout.bat
::   call tools\git_logout.bat help
::
:: Returns: 0 on successful logout, already-logged-out cleanup,
::            cancellation, or help
::          1 on dependency or GitHub CLI logout failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, gh, :Main,
::           :RejectCredential, :CleanupTemp, :ParseArgs, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_logout.login="
set "app.git_logout.confirm="
set "app.git_logout.temp="
set "app.git_logout.reject.rc=0"
set "app.git_logout.gh.rc=0"
set "app.git_logout.help="
set "app.git_logout.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_logout.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_logout.rc=%errorlevel%"
:end
call :CleanupTemp
call :PauseIfNeeded
exit /b %app.git_logout.rc%
:: ============================================================
:: :Main
:: Prepares Git and GitHub CLI, confirms logout when authenticated,
:: erases cached HTTPS credentials, logs out, and verifies the result.
::
:: Usage: call :Main [help]
::
:: Returns: 0 on successful logout, already-logged-out cleanup,
::            cancellation, or help
::          1 on dependency or GitHub CLI logout failure
::          2 on invalid arguments
:: Requires: :RejectCredential, :ParseArgs, :ShowHelp,
::           prepare.bat, git, gh
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set glom_ 2^>nul') do set "%%v="
if defined _glom_rc (set "_glom_rc=" & exit /b %_glom_rc%)
call :ParseArgs %*
set "_glom_rc=%errorlevel%"
if not "%_glom_rc%"=="0" goto :Main
if defined app.git_logout.help goto :_Main_help
echo.
echo ============================================================
echo  GitHub logout
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
if exist "%CD%\prepare.bat" goto :_Main_prepare
echo ERROR: prepare.bat was not found in the project root:
echo   %CD%
set "_glom_rc=1" & goto :Main
:_Main_prepare
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_glom_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git is unavailable after preparation. & set "_glom_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI is unavailable after preparation. & set "_glom_rc=1" & goto :Main)
gh auth status --hostname github.com >nul 2>nul
if errorlevel 1 goto :_Main_already_out
for /f "delims=" %%A in ('gh api user --jq ".login" 2^>nul') do set "app.git_logout.login=%%A"
echo GitHub CLI is currently logged in.
if defined app.git_logout.login (echo Account: & echo   %app.git_logout.login%)
echo.
echo This will:
echo   log GitHub CLI out of github.com
echo   erase cached HTTPS Git credentials for github.com
echo.
echo It will keep:
echo   local repositories and files
echo   origin and other Git remotes
echo   local and global Git author settings
echo   the github.com browser session
echo.
set /p "app.git_logout.confirm=Type LOGOUT to continue: "
if "%app.git_logout.confirm%"=="LOGOUT" goto :_Main_reject
echo.
echo Cancelled. Nothing was changed.
set "_glom_rc=0" & goto :Main
:_Main_reject
call :RejectCredential
if not errorlevel 1 goto :_Main_logout
echo WARNING: Git credential rejection returned exit code %app.git_logout.reject.rc%.
echo GitHub CLI logout will still continue.
echo.
:_Main_logout
if defined app.git_logout.login goto :_Main_known
gh auth logout --hostname github.com
set "app.git_logout.gh.rc=%errorlevel%"
goto :_Main_check
:_Main_known
gh auth logout --hostname github.com --user "%app.git_logout.login%"
set "app.git_logout.gh.rc=%errorlevel%"
if "%app.git_logout.gh.rc%"=="0" goto :_Main_check
echo The account-specific logout command failed.
echo Trying the general GitHub logout command...
gh auth logout --hostname github.com
set "app.git_logout.gh.rc=%errorlevel%"
:_Main_check
if not "%app.git_logout.gh.rc%"=="0" goto :_Main_logout_failed
gh auth status --hostname github.com >nul 2>nul
if not errorlevel 1 goto :_Main_still_in
echo.
echo ============================================================
echo  Logout complete
echo ============================================================
echo.
echo GitHub CLI is logged out of github.com.
echo Git was asked to erase cached HTTPS credentials for github.com.
echo Repository files, remotes, branches, and Git author settings
echo were not changed.
echo.
echo Your browser may still be signed in to github.com.
set "_glom_rc=0" & goto :Main
:_Main_logout_failed
echo ERROR: GitHub CLI logout failed.
set "_glom_rc=1" & goto :Main
:_Main_still_in
echo ERROR: GitHub CLI still reports an authenticated account.
set "_glom_rc=1" & goto :Main
:_Main_already_out
echo GitHub CLI already appears to be logged out of github.com.
echo Asking Git to erase any cached HTTPS credential anyway...
call :RejectCredential
if not errorlevel 1 goto :_Main_already_done
echo WARNING: Git credential rejection returned exit code %app.git_logout.reject.rc%.
:_Main_already_done
echo.
echo Logout state is ready for testing.
echo Repository files and configuration were not changed.
set "_glom_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_glom_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :RejectCredential
:: Writes the Git credential-reject request to a temporary file and
:: feeds it to the configured credential helper without a pipeline.
::
:: Usage: call :RejectCredential
::
:: Output:
::   app.git_logout.reject.rc  git credential reject exit code
::
:: Returns: 0 when Git accepts the rejection request
::          1 when the temporary file or Git command fails
:: Requires: git, del
:: ============================================================
:RejectCredential
for /f "tokens=1 delims==" %%v in ('set glor_ 2^>nul') do set "%%v="
if defined _glor_rc (set "_glor_rc=" & exit /b %_glor_rc%)
set "app.git_logout.temp=%TEMP%\git-logout-credential-%RANDOM%-%RANDOM%.txt"
> "%app.git_logout.temp%" echo protocol=https
if errorlevel 1 (set "app.git_logout.reject.rc=1" & set "_glor_rc=1" & goto :RejectCredential)
>>"%app.git_logout.temp%" echo host=github.com
>>"%app.git_logout.temp%" echo.
git credential reject <"%app.git_logout.temp%"
set "app.git_logout.reject.rc=%errorlevel%"
del /q "%app.git_logout.temp%" >nul 2>nul
set "app.git_logout.temp="
if "%app.git_logout.reject.rc%"=="0" (set "_glor_rc=0" & goto :RejectCredential)
set "_glor_rc=1" & goto :RejectCredential
:: ============================================================
:: :CleanupTemp
:: Deletes an incomplete credential request file, when present.
::
:: Usage: call :CleanupTemp
::
:: Returns: 0
:: Requires: del
:: ============================================================
:CleanupTemp
if defined app.git_logout.temp del /q "%app.git_logout.temp%" >nul 2>nul
set "app.git_logout.temp="
exit /b 0
:: ============================================================
:: :ParseArgs
:: Parses the optional help argument.
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
set "app.git_logout.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays logout scope and preserved local state.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_logout.bat
echo.
echo Usage:
echo   git_logout.bat
echo.
echo The helper logs GitHub CLI out of github.com and rejects cached
echo HTTPS credentials. Repositories, remotes, branches, Git author
echo settings, and browser login are preserved.
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
