@echo off
:: ============================================================
:: git_check_tracked_files.bat
:: Checks whether supplied paths are currently tracked by Git.
::
:: For untracked paths, it also reports whether the path is ignored,
:: not ignored, or missing from the working tree.
::
:: The core tracked-file check is equivalent to:
::   git ls-files --error-unmatch -- PATH
::
:: Multiple paths may be checked in one call.
::
:: Usage:
::   call git_check_tracked_files.bat PATH [PATH...]
::   call git_check_tracked_files.bat help
::
:: Returns: 0 when all paths were checked
::          1 when Git or the repository is unavailable
::          2 when no path is supplied or an argument is invalid
::          first unexpected Git command error otherwise
:: Requires: git.exe, where.exe, find.exe
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_check_tracked.rc=0"
set "app.git_check_tracked.root="
set "app.git_check_tracked.git="
set "app.git_check_tracked.total=0"
set "app.git_check_tracked.tracked=0"
set "app.git_check_tracked.untracked=0"
set "app.git_check_tracked.ignored=0"
set "app.git_check_tracked.missing=0"
set "app.git_check_tracked.errors=0"
if defined GIT_PROJECT_ROOT set "app.git_check_tracked.root=%GIT_PROJECT_ROOT%"
if not defined app.git_check_tracked.root for %%A in ("%~dp0..") do set "app.git_check_tracked.root=%%~fA"
for %%A in ("%app.git_check_tracked.root%\.") do set "app.git_check_tracked.root=%%~fA"
if /I "%~1"=="help" goto :help
if /I "%~1"=="--help" goto :help
if /I "%~1"=="/help" goto :help
if /I "%~1"=="/?" goto :help
if "%~1"=="" goto :missing
call :ResolveGit
set "app.git_check_tracked.rc=%errorlevel%"
if not "%app.git_check_tracked.rc%"=="0" goto :end
cd /d "%app.git_check_tracked.root%"
set "app.git_check_tracked.rc=%errorlevel%"
if "%app.git_check_tracked.rc%"=="0" goto :_setup_repository
echo.
echo ERROR: Could not enter the project root:
echo   "%app.git_check_tracked.root%"
echo.
set "app.git_check_tracked.rc=1"
goto :end
:_setup_repository
git.exe rev-parse --is-inside-work-tree >nul 2>nul
set "app.git_check_tracked.rc=%errorlevel%"
if "%app.git_check_tracked.rc%"=="0" goto :run
echo.
echo ERROR: Project root is not inside a Git worktree:
echo   "%app.git_check_tracked.root%"
echo.
set "app.git_check_tracked.rc=1"
goto :end
:run
echo.
echo ============================================================
echo  Check tracked files
echo ============================================================
echo.
echo Repository:
echo   %app.git_check_tracked.root%
echo.
:next
if "%~1"=="" goto :summary
call :CheckOne "%~1"
shift
goto :next
:summary
echo ============================================================
echo  Tracked-file summary
echo ============================================================
echo.
echo Paths checked:     %app.git_check_tracked.total%
echo Tracked:           %app.git_check_tracked.tracked%
echo Untracked:         %app.git_check_tracked.untracked%
echo Untracked ignored: %app.git_check_tracked.ignored%
echo Missing:           %app.git_check_tracked.missing%
echo Errors:            %app.git_check_tracked.errors%
echo.
goto :end
:missing
echo.
echo ERROR: Supply at least one file or directory path.
echo.
echo Example:
echo   just_check_tracked_files.bat tools\templates\build\build_web.bat
echo.
set "app.git_check_tracked.rc=2"
goto :end
:help
echo.
echo git_check_tracked_files.bat
echo.
echo Usage:
echo   just_check_tracked_files.bat PATH [PATH...]
echo.
echo Reports:
echo   TRACKED
echo   UNTRACKED AND IGNORED
echo   UNTRACKED AND NOT IGNORED
echo   MISSING
echo.
echo The repository is not modified.
echo.
set "app.git_check_tracked.rc=0"
:end
call :PauseIfNeeded
exit /b %app.git_check_tracked.rc%
:: ============================================================
:: :CheckOne
:: Checks one path against the Git index and working tree.
::
:: Usage: call :CheckOne "path"
::
:: Returns: 0; records unexpected errors in the aggregate result
:: Requires: git.exe
:: ============================================================
:CheckOne
set /a app.git_check_tracked.total+=1 >nul
echo Path:
echo   %~1
echo.
git.exe ls-files --error-unmatch -- "%~1" >nul 2>nul
set "co_tracked_rc=%errorlevel%"
if "%co_tracked_rc%"=="0" goto :_CheckOne_tracked
if not "%co_tracked_rc%"=="1" goto :_CheckOne_error
git.exe check-ignore -q -- "%~1"
set "co_ignore_rc=%errorlevel%"
if "%co_ignore_rc%"=="0" goto :_CheckOne_ignored
if not "%co_ignore_rc%"=="1" goto :_CheckOne_error_ignore
if exist "%~1" goto :_CheckOne_untracked
echo Result:
echo   MISSING
echo.
set /a app.git_check_tracked.missing+=1 >nul
exit /b 0
:_CheckOne_tracked
echo Result:
echo   TRACKED
echo.
set /a app.git_check_tracked.tracked+=1 >nul
exit /b 0
:_CheckOne_ignored
echo Result:
echo   UNTRACKED AND IGNORED
echo.
set /a app.git_check_tracked.untracked+=1 >nul
set /a app.git_check_tracked.ignored+=1 >nul
exit /b 0
:_CheckOne_untracked
echo Result:
echo   UNTRACKED AND NOT IGNORED
echo.
set /a app.git_check_tracked.untracked+=1 >nul
exit /b 0
:_CheckOne_error
echo ERROR: git ls-files failed with exit code %co_tracked_rc%.
echo.
set /a app.git_check_tracked.errors+=1 >nul
if "%app.git_check_tracked.rc%"=="0" set "app.git_check_tracked.rc=%co_tracked_rc%"
exit /b 0
:_CheckOne_error_ignore
echo ERROR: git check-ignore failed with exit code %co_ignore_rc%.
echo.
set /a app.git_check_tracked.errors+=1 >nul
if "%app.git_check_tracked.rc%"=="0" set "app.git_check_tracked.rc=%co_ignore_rc%"
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
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined app.git_check_tracked.git set "app.git_check_tracked.git=%%~fG"
if defined app.git_check_tracked.git exit /b 0
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
