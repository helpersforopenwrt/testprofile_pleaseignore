@echo off
:: ============================================================
:: git_show_history.bat
:: Displays a concise decorated commit graph for current history
:: or all refs, with optional remote refresh and result limit.
::
:: Usage:
::   call tools\git_show_history.bat
::   call tools\git_show_history.bat limit 50
::   call tools\git_show_history.bat all yes
::   call tools\git_show_history.bat all yes fetch yes limit 50
::
:: Returns: 0 on successful display, empty history, or help
::          1 on preparation, repository, fetch, status, or log failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ValidatePositiveNumber, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_show_history.limit=30"
set "app.git_show_history.all=no"
set "app.git_show_history.fetch=no"
set "app.git_show_history.hascommit="
set "app.git_show_history.help="
set "app.git_show_history.rc=0"
call "%~dp0_common.bat" init
set "app.git_show_history.rc=%errorlevel%"
if "%app.git_show_history.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_show_history.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_show_history.rc%
:: ============================================================
:: :Main
:: Validates options, optionally refreshes refs, prints repository
:: status, and displays a bounded decorated commit graph.
::
:: Usage: call :Main [limit N] [all yes|no] [fetch yes|no]
::
:: Returns: 0 on successful display, empty history, or help
::          1 on preparation, repository, fetch, status, or log failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ValidatePositiveNumber,
::           :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gshwm_ 2^>nul') do set "%%v="
if defined _gshwm_rc (set "_gshwm_rc=" & exit /b %_gshwm_rc%)
call :ParseArgs %*
set "_gshwm_rc=%errorlevel%"
if not "%_gshwm_rc%"=="0" goto :Main
if defined app.git_show_history.help goto :_Main_help
call :NormalizeYesNo app.git_show_history.all
if errorlevel 1 (echo ERROR: all must be yes or no. & set "_gshwm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_show_history.fetch
if errorlevel 1 (echo ERROR: fetch must be yes or no. & set "_gshwm_rc=2" & goto :Main)
call :ValidatePositiveNumber "%app.git_show_history.limit%" limit
if errorlevel 1 (set "_gshwm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Recent Git history
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gshwm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gshwm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gshwm_rc=1" & goto :Main)
if /I "%app.git_show_history.fetch%"=="yes" goto :_Main_fetch
goto :_Main_history_check
:_Main_fetch
echo Fetching remote references...
git fetch --all --prune --quiet
if errorlevel 1 (echo ERROR: One or more remotes could not be fetched. & set "_gshwm_rc=1" & goto :Main)
echo.
:_Main_history_check
set "app.git_show_history.hascommit="
if /I "%app.git_show_history.all%"=="yes" goto :_Main_check_all
git rev-parse --verify HEAD >nul 2>nul
if not errorlevel 1 set "app.git_show_history.hascommit=1"
goto :_Main_history_ready
:_Main_check_all
for /f "delims=" %%A in ('git rev-list --all --max-count^=1 2^>nul') do set "app.git_show_history.hascommit=1"
:_Main_history_ready
if not defined app.git_show_history.hascommit goto :_Main_empty
echo Scope:
if /I "%app.git_show_history.all%"=="yes" goto :_Main_scope_all
echo   current HEAD history
goto :_Main_scope_done
:_Main_scope_all
echo   all local and remote refs
:_Main_scope_done
echo.
echo Maximum commits:
echo   %app.git_show_history.limit%
echo.
git status --short --branch
set "_gshwm_status_rc=%errorlevel%"
if not "%_gshwm_status_rc%"=="0" (echo ERROR: Git status failed. & set "_gshwm_rc=1" & goto :Main)
echo.
if /I "%app.git_show_history.all%"=="yes" goto :_Main_log_all
git log HEAD --oneline --decorate --graph --max-count=%app.git_show_history.limit%
set "_gshwm_rc=%errorlevel%"
goto :_Main_log_result
:_Main_log_all
git log --all --oneline --decorate --graph --max-count=%app.git_show_history.limit%
set "_gshwm_rc=%errorlevel%"
:_Main_log_result
echo.
if "%_gshwm_rc%"=="0" goto :Main
echo ERROR: Git history display failed.
set "_gshwm_rc=1" & goto :Main
:_Main_empty
echo No commits were found in the selected history scope.
set "_gshwm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_gshwm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses the result limit, all-ref scope, fetch, and help arguments.
::
:: Usage: call :ParseArgs [limit N] [all yes|no] [fetch yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="limit" goto :_ParseArgs_limit
if /I "%~1"=="all" goto :_ParseArgs_all
if /I "%~1"=="fetch" goto :_ParseArgs_fetch
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_limit
if "%~2"=="" (echo ERROR: limit requires a positive number. & exit /b 2)
set "app.git_show_history.limit=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_all
if "%~2"=="" (echo ERROR: all requires yes or no. & exit /b 2)
set "app.git_show_history.all=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_fetch
if "%~2"=="" (echo ERROR: fetch requires yes or no. & exit /b 2)
set "app.git_show_history.fetch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_show_history.help=1"
shift
goto :ParseArgs
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
for /f "tokens=1 delims==" %%v in ('set gshwy_ 2^>nul') do set "%%v="
if defined _gshwy_rc (set "_gshwy_rc=" & exit /b %_gshwy_rc%)
set "gshwy_name=%~1"
call set "gshwy_value=%%%gshwy_name%%%"
if /I "%gshwy_value%"=="y" set "%gshwy_name%=yes"
if /I "%gshwy_value%"=="yes" set "%gshwy_name%=yes"
if /I "%gshwy_value%"=="true" set "%gshwy_name%=yes"
if /I "%gshwy_value%"=="1" set "%gshwy_name%=yes"
if /I "%gshwy_value%"=="n" set "%gshwy_name%=no"
if /I "%gshwy_value%"=="no" set "%gshwy_name%=no"
if /I "%gshwy_value%"=="false" set "%gshwy_name%=no"
if /I "%gshwy_value%"=="0" set "%gshwy_name%=no"
call set "gshwy_value=%%%gshwy_name%%%"
if /I "%gshwy_value%"=="yes" (set "_gshwy_rc=0" & goto :NormalizeYesNo)
if /I "%gshwy_value%"=="no" (set "_gshwy_rc=0" & goto :NormalizeYesNo)
set "_gshwy_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ValidatePositiveNumber
:: Validates a positive whole number.
::
:: Usage: call :ValidatePositiveNumber "value" name
::
:: Returns: 0 when valid
::          1 when empty, nonnumeric, or zero
:: Requires: none
:: ============================================================
:ValidatePositiveNumber
for /f "tokens=1 delims==" %%v in ('set gshwn_ 2^>nul') do set "%%v="
if defined _gshwn_rc (set "_gshwn_rc=" & exit /b %_gshwn_rc%)
set "gshwn_value=%~1"
set "gshwn_name=%~2"
if not defined gshwn_value (echo ERROR: %gshwn_name% requires a positive number. & set "_gshwn_rc=1" & goto :ValidatePositiveNumber)
set "gshwn_invalid="
for /f "delims=0123456789" %%A in ("%gshwn_value%") do set "gshwn_invalid=%%A"
if defined gshwn_invalid (echo ERROR: %gshwn_name% must be a positive whole number. & set "_gshwn_rc=1" & goto :ValidatePositiveNumber)
if "%gshwn_value%"=="0" (echo ERROR: %gshwn_name% must be 1 or greater. & set "_gshwn_rc=1" & goto :ValidatePositiveNumber)
set "_gshwn_rc=0" & goto :ValidatePositiveNumber
:: ============================================================
:: :ShowHelp
:: Displays history scope, fetch, and result-limit behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_show_history.bat
echo.
echo Usage:
echo   git_show_history.bat
echo   git_show_history.bat limit 50
echo   git_show_history.bat all yes
echo   git_show_history.bat all yes fetch yes limit 50
echo.
echo all no shows current HEAD history. all yes includes every ref.
echo fetch yes refreshes remote-tracking references before display.
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
