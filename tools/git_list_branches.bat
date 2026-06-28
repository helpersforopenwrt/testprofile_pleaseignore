@echo off
:: ============================================================
:: git_list_branches.bat
:: Lists local and remote branches and can refresh remote-tracking
:: references without modifying working files or local commits.
::
:: Usage:
::   call tools\git_list_branches.bat
::   call tools\git_list_branches.bat scope local
::   call tools\git_list_branches.bat scope remote
::   call tools\git_list_branches.bat scope all fetch no
::
:: Returns: 0 on successful listing or help display
::          1 on dependency, repository, or branch-listing failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeScope, :NormalizeYesNo, :Warning, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_list_branches.scope=all"
set "app.git_list_branches.fetch=yes"
set "app.git_list_branches.current="
set "app.git_list_branches.help="
set "app.git_list_branches.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_list_branches.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_list_branches.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_list_branches.rc%
:: ============================================================
:: :Main
:: Parses options, prepares Git, optionally fetches all remotes, and
:: displays local and/or remote branch information.
::
:: Usage: call :Main [scope all|local|remote] [fetch yes|no]
::
:: Returns: 0 on successful listing or help display
::          1 on dependency, repository, or branch-listing failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeScope, :NormalizeYesNo, :Warning,
::           :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set glbm_ 2^>nul') do set "%%v="
if defined _glbm_rc (set "_glbm_rc=" & exit /b %_glbm_rc%)
call :ParseArgs %*
set "_glbm_rc=%errorlevel%"
if not "%_glbm_rc%"=="0" goto :Main
if defined app.git_list_branches.help goto :_Main_help
call :NormalizeScope
if errorlevel 1 (set "_glbm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_list_branches.fetch
if errorlevel 1 (echo ERROR: fetch must be yes or no. & set "_glbm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  List Git branches
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_glbm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_glbm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_glbm_rc=1" & goto :Main)
if /I not "%app.git_list_branches.fetch%"=="yes" goto :_Main_current
echo Fetching remote branch information...
git fetch --all --prune --quiet
if not errorlevel 1 goto :_Main_fetch_done
call :Warning "One or more remotes could not be fetched"
:_Main_fetch_done
echo.
:_Main_current
set "app.git_list_branches.current="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_list_branches.current=%%A"
echo Current branch:
if defined app.git_list_branches.current (echo   %app.git_list_branches.current%) else (echo   detached HEAD)
echo.
if /I "%app.git_list_branches.scope%"=="remote" goto :_Main_remote
echo ============================================================
echo  Local branches
echo ============================================================
echo.
git branch -vv
if errorlevel 1 (echo ERROR: Local branch listing failed. & set "_glbm_rc=1" & goto :Main)
echo.
if /I "%app.git_list_branches.scope%"=="local" goto :_Main_done
:_Main_remote
echo ============================================================
echo  Remote branches
echo ============================================================
echo.
git branch -r
if errorlevel 1 (echo ERROR: Remote branch listing failed. & set "_glbm_rc=1" & goto :Main)
echo.
:_Main_done
echo Helpful next commands:
echo.
echo   just_switch.bat BRANCH_NAME
echo   just_newbranch.bat NEW_BRANCH_NAME
echo.
set "_glbm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_glbm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses branch scope, fetch, and help arguments.
::
:: Usage: call :ParseArgs [scope all|local|remote] [fetch yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="scope" goto :_ParseArgs_scope
if /I "%~1"=="fetch" goto :_ParseArgs_fetch
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_scope
if "%~2"=="" (echo ERROR: scope requires all, local, or remote. & exit /b 2)
set "app.git_list_branches.scope=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_fetch
if "%~2"=="" (echo ERROR: fetch requires yes or no. & exit /b 2)
set "app.git_list_branches.fetch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_list_branches.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeScope
:: Normalizes and validates the configured branch-listing scope.
::
:: Usage: call :NormalizeScope
::
:: Returns: 0 for all, local, or remote
::          1 otherwise
:: Requires: none
:: ============================================================
:NormalizeScope
if /I "%app.git_list_branches.scope%"=="all" set "app.git_list_branches.scope=all"
if /I "%app.git_list_branches.scope%"=="local" set "app.git_list_branches.scope=local"
if /I "%app.git_list_branches.scope%"=="remote" set "app.git_list_branches.scope=remote"
if "%app.git_list_branches.scope%"=="all" exit /b 0
if "%app.git_list_branches.scope%"=="local" exit /b 0
if "%app.git_list_branches.scope%"=="remote" exit /b 0
echo ERROR: scope must be all, local, or remote.
exit /b 1
:: ============================================================
:: :NormalizeYesNo
:: Normalizes a named variable to yes or no.
::
:: Usage: call :NormalizeYesNo variableName
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:NormalizeYesNo
for /f "tokens=1 delims==" %%v in ('set glby_ 2^>nul') do set "%%v="
if defined _glby_rc (set "_glby_rc=" & exit /b %_glby_rc%)
set "glby_name=%~1"
call set "glby_value=%%%glby_name%%%"
if /I "%glby_value%"=="y" set "%glby_name%=yes"
if /I "%glby_value%"=="yes" set "%glby_name%=yes"
if /I "%glby_value%"=="true" set "%glby_name%=yes"
if /I "%glby_value%"=="1" set "%glby_name%=yes"
if /I "%glby_value%"=="n" set "%glby_name%=no"
if /I "%glby_value%"=="no" set "%glby_name%=no"
if /I "%glby_value%"=="false" set "%glby_name%=no"
if /I "%glby_value%"=="0" set "%glby_name%=no"
call set "glby_value=%%%glby_name%%%"
if /I "%glby_value%"=="yes" (set "_glby_rc=0" & goto :NormalizeYesNo)
if /I "%glby_value%"=="no" (set "_glby_rc=0" & goto :NormalizeYesNo)
set "_glby_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :Warning
:: Prints a warning message without changing the caller's result.
::
:: Usage: call :Warning "message"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:Warning
echo [WARNING] %~1
exit /b 0
:: ============================================================
:: :ShowHelp
:: Displays branch-listing usage and fetch behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_list_branches.bat
echo.
echo Usage:
echo   git_list_branches.bat
echo   git_list_branches.bat scope local
echo   git_list_branches.bat scope remote
echo   git_list_branches.bat scope all fetch no
echo.
echo Fetching updates remote-tracking references only.
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
