@echo off
:: ============================================================
:: just_diff.bat
:: Shows changed files plus unstaged and staged diff summaries.
::
:: Usage: call tools\just_diff.bat
::
:: Returns: 0 on success
::          1 when Git is unavailable or the folder is not a worktree
:: Requires: _common.bat, git, :Main, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_diff.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_diff.rc=%errorlevel%"
goto :end
:main
call :Main
set "app.just_diff.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.just_diff.rc%
:: ============================================================
:: :Main
:: Validates Git and displays repository status plus unstaged and
:: staged diff summaries.
::
:: Usage: call :Main
::
:: Returns: 0 on success
::          1 on validation or Git command failure
:: Requires: git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set jdf_ 2^>nul') do set "%%v="
if defined _jdf_rc (set "_jdf_rc=" & exit /b %_jdf_rc%)
echo.
echo ============================================================
echo  Changed files and diff summary
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: git was not found in PATH. & set "_jdf_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_jdf_rc=1" & goto :Main)
echo Changed files:
git status --short
if errorlevel 1 (echo ERROR: git status failed. & set "_jdf_rc=1" & goto :Main)
echo.
echo Unstaged diff summary:
git diff --stat
if errorlevel 1 (echo ERROR: git diff failed. & set "_jdf_rc=1" & goto :Main)
echo.
echo Staged diff summary:
git diff --cached --stat
if errorlevel 1 (echo ERROR: git diff --cached failed. & set "_jdf_rc=1" & goto :Main)
echo.
set "_jdf_rc=0" & goto :Main
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
