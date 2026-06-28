@echo off
:: ============================================================
:: git_diff_check_files.bat
:: Checks unstaged whitespace errors for one or more Git pathspecs.
::
:: Usage:
::   git_diff_check_files.bat FILE [FILE ...]
::   git_diff_check_files.bat "path with spaces\file.txt"
::
:: Examples:
::   git_diff_check_files.bat tools\bootstrap.bat
::   git_diff_check_files.bat build.bat prepare.bat install.bat
::
:: Notes:
::   - quote paths that contain spaces or command characters
::   - untracked files are not included until Git tracks them
::   - no diff output means no whitespace errors were found
::
:: Returns: git diff --check exit code
::          2 for missing arguments or invalid environment
:: Requires: git.exe, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_diff_check_files.rc=0"
if "%~1"=="" goto :usage_error
where git.exe >nul 2>nul
set "app.git_diff_check_files.rc=%errorlevel%"
if "%app.git_diff_check_files.rc%"=="0" goto :check_repo
echo.
echo ERROR: git.exe was not found in PATH.
echo.
set "app.git_diff_check_files.rc=2"
goto :end
:check_repo
git rev-parse --is-inside-work-tree >nul 2>nul
set "app.git_diff_check_files.rc=%errorlevel%"
if "%app.git_diff_check_files.rc%"=="0" goto :run
echo.
echo ERROR: This folder is not inside a Git working tree.
echo.
set "app.git_diff_check_files.rc=2"
goto :end
:run
echo.
echo Checking unstaged whitespace for:
echo   %*
echo.
git diff --check -- %*
set "app.git_diff_check_files.rc=%errorlevel%"
if not "%app.git_diff_check_files.rc%"=="0" goto :failed
echo No whitespace errors were found.
echo.
goto :end
:failed
echo.
echo Whitespace errors were found, or Git could not check the pathspecs.
echo.
goto :end
:usage_error
echo.
echo Usage:
echo   %~nx0 FILE [FILE ...]
echo.
echo Example:
echo   %~nx0 tools\bootstrap.bat
echo.
set "app.git_diff_check_files.rc=2"
:end
call :PauseIfNeeded
exit /b %app.git_diff_check_files.rc%
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
:: Detects whether the helper is in an existing console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 for existing console, 1 for outer cmd.exe /c target
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
