@echo off
:: ============================================================
:: git_diff_check.bat
:: Direct, read-only equivalent to Git whitespace checks.
::
:: Default behavior:
::   1. inspect changed files for line-ending mismatches
::   2. offer Fix, Skip once, or Ignore locally
::   3. run git diff --check
::   4. run git diff --cached --check
::
:: The Git commands use a one-command core.safecrlf=false override only
:: to avoid repeating conversion warnings already handled by the line-
:: ending helper. Whitespace errors are still reported by --check.
::
:: Modes:
::   both       unstaged and staged; default
::   unstaged   git diff --check
::   staged     git diff --cached --check
::   noprompt   skip line-ending prompt, then check both
::
:: Usage:
::   call git_diff_check.bat
::   call git_diff_check.bat both
::   call git_diff_check.bat unstaged
::   call git_diff_check.bat staged
::   call git_diff_check.bat noprompt
::   call git_diff_check.bat help
::
:: Returns: 0 when checks pass
::          1 when Git/repository is unavailable
::          2 on invalid arguments
::          first Git whitespace-check result otherwise
:: Requires: git.exe, git_normalize_line_endings.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_diff_check.rc=0"
set "app.git_diff_check.root="
set "app.git_diff_check.mode=both"
set "app.git_diff_check.prompt=1"
if defined GIT_PROJECT_ROOT set "app.git_diff_check.root=%GIT_PROJECT_ROOT%"
if not defined app.git_diff_check.root for %%A in ("%~dp0..") do set "app.git_diff_check.root=%%~fA"
for %%A in ("%app.git_diff_check.root%\.") do set "app.git_diff_check.root=%%~fA"
call :ParseArguments %*
set "app.git_diff_check.rc=%errorlevel%"
if not "%app.git_diff_check.rc%"=="0" goto :end
if /I "%app.git_diff_check.mode%"=="help" goto :help
where git.exe >nul 2>nul
if not errorlevel 1 goto :_setup_root
echo.
echo ERROR: git.exe was not found in PATH.
echo.
set "app.git_diff_check.rc=1"
goto :end
:_setup_root
cd /d "%app.git_diff_check.root%"
set "app.git_diff_check.rc=%errorlevel%"
if "%app.git_diff_check.rc%"=="0" goto :_setup_repository
echo.
echo ERROR: Could not enter the project root:
echo   "%app.git_diff_check.root%"
echo.
set "app.git_diff_check.rc=1"
goto :end
:_setup_repository
git.exe rev-parse --is-inside-work-tree >nul 2>nul
set "app.git_diff_check.rc=%errorlevel%"
if "%app.git_diff_check.rc%"=="0" goto :run
echo.
echo ERROR: Project root is not inside a Git worktree.
echo.
set "app.git_diff_check.rc=1"
goto :end
:run
if not "%app.git_diff_check.prompt%"=="1" goto :checks
call "%~dp0git_normalize_line_endings.bat" prompt changed
set "gdc_eol_rc=%errorlevel%"
if "%gdc_eol_rc%"=="0" goto :checks
if "%gdc_eol_rc%"=="3" goto :checks
set "app.git_diff_check.rc=%gdc_eol_rc%"
goto :end
:checks
echo.
echo ============================================================
echo  Git diff whitespace check
echo ============================================================
echo.
if /I "%app.git_diff_check.mode%"=="staged" goto :staged
echo Unstaged changes:
git.exe -c core.safecrlf=false --no-pager diff --check
set "gdc_rc=%errorlevel%"
if not "%gdc_rc%"=="0" if "%app.git_diff_check.rc%"=="0" set "app.git_diff_check.rc=%gdc_rc%"
echo.
if /I "%app.git_diff_check.mode%"=="unstaged" goto :result
:staged
echo Staged changes:
git.exe -c core.safecrlf=false --no-pager diff --cached --check
set "gdc_rc=%errorlevel%"
if not "%gdc_rc%"=="0" if "%app.git_diff_check.rc%"=="0" set "app.git_diff_check.rc=%gdc_rc%"
echo.
:result
if "%app.git_diff_check.rc%"=="0" echo All requested Git diff checks passed.
if not "%app.git_diff_check.rc%"=="0" echo One or more Git diff checks failed.
echo.
goto :end
:help
echo.
echo git_diff_check.bat
echo.
echo Usage:
echo   just_diff_check.bat
echo   just_diff_check.bat both
echo   just_diff_check.bat unstaged
echo   just_diff_check.bat staged
echo   just_diff_check.bat noprompt
echo.
echo This is the direct helper for:
echo   git diff --check
echo   git diff --cached --check
echo.
echo Your existing git_diff_check_files.bat remains the file-specific
echo version.
echo.
set "app.git_diff_check.rc=0"
:end
call :PauseIfNeeded
exit /b %app.git_diff_check.rc%
:: ============================================================
:: :ParseArguments
:: Parses the requested check mode.
::
:: Usage: call :ParseArguments %*
::
:: Returns: 0 on success, 2 on invalid syntax
:: Requires: none
:: ============================================================
:ParseArguments
if "%~1"=="" exit /b 0
if not "%~2"=="" goto :_ParseArguments_invalid
if /I "%~1"=="both" (set "app.git_diff_check.mode=both" & exit /b 0)
if /I "%~1"=="unstaged" (set "app.git_diff_check.mode=unstaged" & exit /b 0)
if /I "%~1"=="staged" (set "app.git_diff_check.mode=staged" & exit /b 0)
if /I "%~1"=="noprompt" (set "app.git_diff_check.mode=both" & set "app.git_diff_check.prompt=0" & exit /b 0)
if /I "%~1"=="help" (set "app.git_diff_check.mode=help" & exit /b 0)
if /I "%~1"=="--help" (set "app.git_diff_check.mode=help" & exit /b 0)
if /I "%~1"=="/help" (set "app.git_diff_check.mode=help" & exit /b 0)
if /I "%~1"=="/?" (set "app.git_diff_check.mode=help" & exit /b 0)
:_ParseArguments_invalid
echo.
echo ERROR: Invalid git_diff_check arguments.
echo.
exit /b 2
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
