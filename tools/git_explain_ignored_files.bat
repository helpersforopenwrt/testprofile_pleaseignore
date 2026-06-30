@echo off
:: ============================================================
:: git_explain_ignored_files.bat
:: Explains whether supplied paths are ignored and shows the exact
:: ignore file, line number, and pattern responsible.
::
:: This is a read-only helper equivalent to:
::   git check-ignore -v -- PATH
::
:: Multiple paths may be checked in one call.
::
:: Usage:
::   call git_explain_ignored_files.bat PATH [PATH...]
::   call git_explain_ignored_files.bat help
::
:: Returns: 0 when all paths were checked
::          1 when Git or the repository is unavailable
::          2 when no path is supplied or an argument is invalid
::          first Git command error greater than 1 otherwise
:: Requires: git.exe, where.exe, find.exe
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_explain_ignored.rc=0"
set "app.git_explain_ignored.root="
set "app.git_explain_ignored.git="
set "app.git_explain_ignored.total=0"
set "app.git_explain_ignored.ignored=0"
set "app.git_explain_ignored.not_ignored=0"
set "app.git_explain_ignored.errors=0"
if defined GIT_PROJECT_ROOT set "app.git_explain_ignored.root=%GIT_PROJECT_ROOT%"
if not defined app.git_explain_ignored.root for %%A in ("%~dp0..") do set "app.git_explain_ignored.root=%%~fA"
for %%A in ("%app.git_explain_ignored.root%\.") do set "app.git_explain_ignored.root=%%~fA"
if /I "%~1"=="help" goto :help
if /I "%~1"=="--help" goto :help
if /I "%~1"=="/help" goto :help
if /I "%~1"=="/?" goto :help
if "%~1"=="" goto :missing
call :ResolveGit
set "app.git_explain_ignored.rc=%errorlevel%"
if not "%app.git_explain_ignored.rc%"=="0" goto :end
cd /d "%app.git_explain_ignored.root%"
set "app.git_explain_ignored.rc=%errorlevel%"
if "%app.git_explain_ignored.rc%"=="0" goto :_setup_repository
echo.
echo ERROR: Could not enter the project root:
echo   "%app.git_explain_ignored.root%"
echo.
set "app.git_explain_ignored.rc=1"
goto :end
:_setup_repository
git.exe rev-parse --is-inside-work-tree >nul 2>nul
set "app.git_explain_ignored.rc=%errorlevel%"
if "%app.git_explain_ignored.rc%"=="0" goto :run
echo.
echo ERROR: Project root is not inside a Git worktree:
echo   "%app.git_explain_ignored.root%"
echo.
set "app.git_explain_ignored.rc=1"
goto :end
:run
echo.
echo ============================================================
echo  Explain ignored files
echo ============================================================
echo.
echo Repository:
echo   %app.git_explain_ignored.root%
echo.
:next
if "%~1"=="" goto :summary
call :CheckOne "%~1"
shift
goto :next
:summary
echo ============================================================
echo  Ignore-check summary
echo ============================================================
echo.
echo Paths checked: %app.git_explain_ignored.total%
echo Ignored:       %app.git_explain_ignored.ignored%
echo Not ignored:   %app.git_explain_ignored.not_ignored%
echo Errors:        %app.git_explain_ignored.errors%
echo.
goto :end
:missing
echo.
echo ERROR: Supply at least one file or directory path.
echo.
echo Example:
echo   just_explain_ignored_files.bat tools\templates\build\build_web.bat
echo.
set "app.git_explain_ignored.rc=2"
goto :end
:help
echo.
echo git_explain_ignored_files.bat
echo.
echo Usage:
echo   just_explain_ignored_files.bat PATH [PATH...]
echo.
echo For every path, reports either:
echo   IGNORED with the matching ignore file, line, and pattern
echo   NOT IGNORED
echo.
echo The repository is not modified.
echo.
set "app.git_explain_ignored.rc=0"
:end
call :PauseIfNeeded
exit /b %app.git_explain_ignored.rc%
:: ============================================================
:: :CheckOne
:: Runs git check-ignore -v for one path.
::
:: Usage: call :CheckOne "path"
::
:: Returns: 0; records command errors in the aggregate result
:: Requires: git.exe
:: ============================================================
:CheckOne
set /a app.git_explain_ignored.total+=1 >nul
echo Path:
echo   %~1
echo.
git.exe check-ignore -v -- "%~1"
set "co_rc=%errorlevel%"
if "%co_rc%"=="0" goto :_CheckOne_ignored
if "%co_rc%"=="1" goto :_CheckOne_not_ignored
echo ERROR: git check-ignore failed with exit code %co_rc%.
echo.
set /a app.git_explain_ignored.errors+=1 >nul
if "%app.git_explain_ignored.rc%"=="0" set "app.git_explain_ignored.rc=%co_rc%"
exit /b 0
:_CheckOne_ignored
echo.
echo Result:
echo   IGNORED
echo.
set /a app.git_explain_ignored.ignored+=1 >nul
exit /b 0
:_CheckOne_not_ignored
echo Result:
echo   NOT IGNORED
echo.
set /a app.git_explain_ignored.not_ignored+=1 >nul
exit /b 0
:: ============================================================
:: :ResolveGit
:: Resolves git.exe from PATH.
::
:: Usage: call :ResolveGit
::
:: Returns: 0 when found, 1 when missing
:: Requires: where.exe
:: ============================================================
:ResolveGit
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined app.git_explain_ignored.git set "app.git_explain_ignored.git=%%~fG"
if defined app.git_explain_ignored.git exit /b 0
echo.
echo ERROR: git.exe was not found in PATH.
echo.
exit /b 1
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when this script is the outer cmd.exe /c target.
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
:: Detects whether execution is already inside an interactive console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 for an existing console
::          1 when app.launch.name is the outer cmd.exe /c target
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
