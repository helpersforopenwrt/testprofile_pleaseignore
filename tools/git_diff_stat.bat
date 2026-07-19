@echo off
:: ============================================================
:: git_diff_stat.bat
:: Shows Git diff statistics without the full patch.
::
:: Usage:
::   call tools\git_diff_stat.bat
::   call tools\git_diff_stat.bat unstaged
::   call tools\git_diff_stat.bat staged
::   call tools\git_diff_stat.bat both
::
:: Returns: 0 on success, 1 on Git/repository failure,
::          2 on invalid arguments, or Git's first failure code
:: Requires: git.exe, where.exe, find.exe
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.diff_stat.mode=unstaged"
set "app.diff_stat.root="
set "app.diff_stat.rc=0"
if defined GIT_PROJECT_ROOT set "app.diff_stat.root=%GIT_PROJECT_ROOT%"
if not defined app.diff_stat.root for %%A in ("%~dp0..") do set "app.diff_stat.root=%%~fA"
call :ParseArgs %*
set "app.diff_stat.rc=%errorlevel%"
if not "%app.diff_stat.rc%"=="0" goto :end
call :ValidateRepo
set "app.diff_stat.rc=%errorlevel%"
if not "%app.diff_stat.rc%"=="0" goto :end
cd /d "%app.diff_stat.root%"
set "app.diff_stat.rc=%errorlevel%"
if not "%app.diff_stat.rc%"=="0" goto :end
echo.
echo ============================================================
echo  Git diff statistics
echo ============================================================
echo.
if /I "%app.diff_stat.mode%"=="staged" goto :staged
echo Unstaged changes:
git.exe --no-pager diff --stat
set "ds_one_rc=%errorlevel%"
if not "%ds_one_rc%"=="0" if "%app.diff_stat.rc%"=="0" set "app.diff_stat.rc=%ds_one_rc%"
echo.
if /I "%app.diff_stat.mode%"=="unstaged" goto :end
:staged
echo Staged changes:
git.exe --no-pager diff --cached --stat
set "ds_one_rc=%errorlevel%"
if not "%ds_one_rc%"=="0" if "%app.diff_stat.rc%"=="0" set "app.diff_stat.rc=%ds_one_rc%"
echo.
:end
call :PauseIfNeeded
exit /b %app.diff_stat.rc%
:: ============================================================
:: :ParseArgs
:: Parses unstaged, staged, or both.
::
:: Usage: call :ParseArgs [unstaged|staged|both]
::
:: Returns: 0 on success, 2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if not "%~2"=="" goto :_ParseArgs_invalid
if /I "%~1"=="unstaged" (set "app.diff_stat.mode=unstaged" & exit /b 0)
if /I "%~1"=="staged" (set "app.diff_stat.mode=staged" & exit /b 0)
if /I "%~1"=="both" (set "app.diff_stat.mode=both" & exit /b 0)
:_ParseArgs_invalid
echo ERROR: Expected unstaged, staged, or both.
exit /b 2
:: ============================================================
:: :ValidateRepo
:: Verifies Git and repository availability.
::
:: Usage: call :ValidateRepo
::
:: Returns: 0 when ready, 1 otherwise
:: Requires: git.exe, where.exe
:: ============================================================
:ValidateRepo
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: git.exe was not found in PATH. & exit /b 1)
git.exe -C "%app.diff_stat.root%" rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: Not a Git worktree: & echo   %app.diff_stat.root% & exit /b 1)
exit /b 0
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when directly launched by cmd.exe /c.
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
:: Detects an existing interactive console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 for an existing console, 1 for outer cmd.exe /c
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
