@echo off
:: ============================================================
:: just_commit.bat
:: Commits all local changes without pushing them.
::
:: Usage: call tools\just_commit.bat ["commit message"]
::
:: Returns: 0 on success or when there is nothing to commit
::          1 on Git, repository, staging, or commit failure
:: Requires: _common.bat, git, :Main, :GetCommitMessage,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
set "app.launch.path=%~f0"
set "app.launch.name=%~nx0"
set "app.just_commit.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_commit.rc=%errorlevel%"
goto :end
:main
call :Main %*
set "app.just_commit.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.just_commit.rc%
:: ============================================================
:: :Main
:: Validates the repository, collects a commit message, stages all
:: changes, and creates one local commit without pushing it.
::
:: Usage: call :Main ["commit message"]
::
:: Returns: 0 on success or when there is nothing to commit
::          1 on failure
:: Requires: git, :GetCommitMessage
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set jcm_ 2^>nul') do set "%%v="
if defined _jcm_rc (set "_jcm_rc=" & exit /b %_jcm_rc%)
set "app.just_commit.message=%~1"
echo.
echo ============================================================
echo  Commit local changes only
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: git was not found in PATH. & set "_jcm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & echo Run tools\git_login.bat first. & set "_jcm_rc=1" & goto :Main)
set "jcm_dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "jcm_dirty=1"
if not defined jcm_dirty (echo No local changes to commit. & set "_jcm_rc=0" & goto :Main)
git status --short
echo.
call :GetCommitMessage
if errorlevel 1 (set "_jcm_rc=%errorlevel%" & goto :Main)
git add --all
if errorlevel 1 (echo ERROR: git add failed. & set "_jcm_rc=1" & goto :Main)
git commit -m "%app.just_commit.message%"
if errorlevel 1 (echo ERROR: git commit failed. & set "_jcm_rc=1" & goto :Main)
echo.
echo Commit complete. It has not been pushed.
echo To push it, run just_push.bat
echo.
set "_jcm_rc=0" & goto :Main
:: ============================================================
:: :GetCommitMessage
:: Uses the supplied commit message or prompts until one is entered.
::
:: Usage: call :GetCommitMessage
::
:: Input:
::   app.just_commit.message  optional existing commit message
::
:: Output:
::   app.just_commit.message  validated nonempty commit message
::
:: Returns: 0
:: Requires: none
:: ============================================================
:GetCommitMessage
for /f "tokens=1 delims==" %%v in ('set gcm_ 2^>nul') do set "%%v="
if defined _gcm_rc (set "_gcm_rc=" & exit /b %_gcm_rc%)
if defined app.just_commit.message (set "_gcm_rc=0" & goto :GetCommitMessage)
set /p "app.just_commit.message=Commit message: "
if defined app.just_commit.message (set "_gcm_rc=0" & goto :GetCommitMessage)
echo Commit message is required.
echo.
goto :GetCommitMessage
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when this script is the cmd.exe /c launch target.
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
:: Detects whether this script is running in an existing console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 when running in an existing console
::          1 when this script is the cmd.exe /c launch target
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
