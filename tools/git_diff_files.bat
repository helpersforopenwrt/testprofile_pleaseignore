@echo off
:: ============================================================
:: git_diff_files.bat
:: Shows Git diffs for selected paths.
::
:: Usage:
::   call tools\git_diff_files.bat PATH [PATH...]
::   call tools\git_diff_files.bat unstaged PATH [PATH...]
::   call tools\git_diff_files.bat staged PATH [PATH...]
::   call tools\git_diff_files.bat both PATH [PATH...]
::
:: Example:
::   call tools\git_diff_files.bat tools\bootstrap.bat
::
:: Returns: 0 on success, 1 on Git/repository failure,
::          2 on missing paths, or Git's first failure code
:: Requires: git.exe, where.exe, find.exe
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.diff_files.mode=unstaged"
set "app.diff_files.root="
set "app.diff_files.rc=0"
if defined GIT_PROJECT_ROOT set "app.diff_files.root=%GIT_PROJECT_ROOT%"
if not defined app.diff_files.root for %%A in ("%~dp0..") do set "app.diff_files.root=%%~fA"
call :ParseArgs %*
set "app.diff_files.rc=%errorlevel%"
if not "%app.diff_files.rc%"=="0" goto :end
call :ValidateRepo
set "app.diff_files.rc=%errorlevel%"
if not "%app.diff_files.rc%"=="0" goto :end
cd /d "%app.diff_files.root%"
set "app.diff_files.rc=%errorlevel%"
if not "%app.diff_files.rc%"=="0" goto :end
call :RunDiffs %*
set "app.diff_files.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.diff_files.rc%
:: ============================================================
:: :ParseArgs
:: Parses the optional mode and checks for paths.
::
:: Usage: call :ParseArgs [unstaged|staged|both] PATH [PATH...]
::
:: Returns: 0 on success, 2 when paths are missing
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" goto :_ParseArgs_missing
if /I "%~1"=="unstaged" goto :_ParseArgs_mode
if /I "%~1"=="staged" goto :_ParseArgs_mode
if /I "%~1"=="both" goto :_ParseArgs_mode
exit /b 0
:_ParseArgs_mode
set "app.diff_files.mode=%~1"
if "%~2"=="" goto :_ParseArgs_missing
exit /b 0
:_ParseArgs_missing
echo ERROR: Supply at least one path.
exit /b 2
:: ============================================================
:: :RunDiffs
:: Removes the optional mode and processes each path safely.
::
:: Usage: call :RunDiffs [unstaged|staged|both] PATH [PATH...]
::
:: Returns: first Git failure, or 0
:: Requires: :RunOnePath
:: ============================================================
:RunDiffs
if /I "%~1"=="unstaged" shift
if /I "%~1"=="staged" shift
if /I "%~1"=="both" shift
set "df_rc=0"
echo.
echo ============================================================
echo  Git diff for selected paths
echo ============================================================
echo.
:_RunDiffs_next
if "%~1"=="" exit /b %df_rc%
call :RunOnePath "%~1"
set "df_one_rc=%errorlevel%"
if not "%df_one_rc%"=="0" if "%df_rc%"=="0" set "df_rc=%df_one_rc%"
shift
goto :_RunDiffs_next
:: ============================================================
:: :RunOnePath
:: Runs the selected diff mode for one path.
::
:: Usage: call :RunOnePath "PATH"
::
:: Returns: first Git failure, or 0
:: Requires: git.exe
:: ============================================================
:RunOnePath
set "dop_rc=0"
echo Path:
echo   %~1
echo.
if /I "%app.diff_files.mode%"=="staged" goto :_RunOnePath_staged
echo Unstaged changes:
git.exe --no-pager diff -- "%~1"
set "dop_one_rc=%errorlevel%"
if not "%dop_one_rc%"=="0" if "%dop_rc%"=="0" set "dop_rc=%dop_one_rc%"
echo.
if /I "%app.diff_files.mode%"=="unstaged" exit /b %dop_rc%
:_RunOnePath_staged
echo Staged changes:
git.exe --no-pager diff --cached -- "%~1"
set "dop_one_rc=%errorlevel%"
if not "%dop_one_rc%"=="0" if "%dop_rc%"=="0" set "dop_rc=%dop_one_rc%"
echo.
exit /b %dop_rc%
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
git.exe -C "%app.diff_files.root%" rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: Not a Git worktree: & echo   %app.diff_files.root% & exit /b 1)
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
