@echo off
:: ============================================================
:: git_switch_branch.bat
:: Safely switches to an existing local branch or creates a local
:: tracking branch for an existing branch on origin.
::
:: Usage:
::   call tools\git_switch_branch.bat
::   call tools\git_switch_branch.bat BRANCH_NAME
::   call tools\git_switch_branch.bat name BRANCH_NAME fetch no
::   call tools\git_switch_branch.bat name BRANCH_NAME allowdirty yes
::
:: Returns: 0 on successful switch, no-op, cancellation, or help
::          1 on preparation, repository, branch, status, or switch failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_switch_branch.name="
set "app.git_switch_branch.fetch=yes"
set "app.git_switch_branch.allowdirty=no"
set "app.git_switch_branch.current="
set "app.git_switch_branch.dirty="
set "app.git_switch_branch.kind="
set "app.git_switch_branch.confirm="
set "app.git_switch_branch.help="
set "app.git_switch_branch.rc=0"
call "%~dp0_common.bat" init
set "app.git_switch_branch.rc=%errorlevel%"
if "%app.git_switch_branch.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_switch_branch.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_switch_branch.rc%
:: ============================================================
:: :Main
:: Validates repository and working-tree state, refreshes origin when
:: requested, locates the target branch, confirms, and switches safely.
::
:: Usage: call :Main [name BRANCH] [fetch yes|no] [allowdirty yes|no]
::
:: Returns: 0 on successful switch, no-op, cancellation, or help
::          1 on preparation, repository, branch, status, or switch failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gsbm_ 2^>nul') do set "%%v="
if defined _gsbm_rc (set "_gsbm_rc=" & exit /b %_gsbm_rc%)
call :ParseArgs %*
set "_gsbm_rc=%errorlevel%"
if not "%_gsbm_rc%"=="0" goto :Main
if defined app.git_switch_branch.help goto :_Main_help
call :NormalizeYesNo app.git_switch_branch.fetch
if errorlevel 1 (echo ERROR: fetch must be yes or no. & set "_gsbm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_switch_branch.allowdirty
if errorlevel 1 (echo ERROR: allowdirty must be yes or no. & set "_gsbm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Switch Git branch
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gsbm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gsbm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gsbm_rc=1" & goto :Main)
set "app.git_switch_branch.current="
set "app.git_switch_branch.dirty="
set "app.git_switch_branch.kind="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_switch_branch.current=%%A"
if /I "%app.git_switch_branch.fetch%"=="yes" goto :_Main_fetch
goto :_Main_name
:_Main_fetch
echo Fetching origin...
git fetch --prune --quiet origin
set "_gsbm_fetch_rc=%errorlevel%"
if "%_gsbm_fetch_rc%"=="0" goto :_Main_name
echo WARNING: origin could not be fetched.
echo Local branches and existing remote-tracking references will still be checked.
echo.
:_Main_name
if defined app.git_switch_branch.name goto :_Main_name_ready
echo Local branches:
git branch -vv
set "_gsbm_list_rc=%errorlevel%"
if not "%_gsbm_list_rc%"=="0" (echo ERROR: Could not list local branches. & set "_gsbm_rc=1" & goto :Main)
echo.
echo Remote branches:
git branch -r
set "_gsbm_list_rc=%errorlevel%"
if not "%_gsbm_list_rc%"=="0" (echo ERROR: Could not list remote branches. & set "_gsbm_rc=1" & goto :Main)
echo.
set /p "app.git_switch_branch.name=Branch to switch to: "
:_Main_name_ready
if not defined app.git_switch_branch.name (echo ERROR: A branch name is required. & set "_gsbm_rc=1" & goto :Main)
git check-ref-format --branch "%app.git_switch_branch.name%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid branch name: & echo   %app.git_switch_branch.name% & set "_gsbm_rc=1" & goto :Main)
if /I "%app.git_switch_branch.current%"=="%app.git_switch_branch.name%" goto :_Main_already
git status --porcelain >nul 2>nul
if errorlevel 1 (echo ERROR: Git status failed. & set "_gsbm_rc=1" & goto :Main)
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_switch_branch.dirty=1"
if not defined app.git_switch_branch.dirty goto :_Main_find
if /I "%app.git_switch_branch.allowdirty%"=="yes" goto :_Main_dirty_allowed
echo.
echo ERROR: The working tree has uncommitted changes.
echo.
git status --short
echo.
echo Commit or stash the changes before switching branches.
echo To deliberately carry them across, use:
echo   git_switch_branch.bat name "%app.git_switch_branch.name%" allowdirty yes
set "_gsbm_rc=1" & goto :Main
:_Main_dirty_allowed
echo.
echo WARNING: Uncommitted changes will be carried across if Git permits it.
git status --short
echo.
:_Main_find
git show-ref --verify --quiet "refs/heads/%app.git_switch_branch.name%"
if not errorlevel 1 (set "app.git_switch_branch.kind=local" & goto :_Main_found)
git show-ref --verify --quiet "refs/remotes/origin/%app.git_switch_branch.name%"
if not errorlevel 1 (set "app.git_switch_branch.kind=origin" & goto :_Main_found)
echo.
echo ERROR: Branch was not found locally or on origin:
echo   %app.git_switch_branch.name%
echo.
echo To create a new branch, run:
echo   just_newbranch.bat "%app.git_switch_branch.name%"
set "_gsbm_rc=1" & goto :Main
:_Main_found
echo.
echo Current branch:
if defined app.git_switch_branch.current goto :_Main_current_named
echo   detached HEAD
goto :_Main_current_done
:_Main_current_named
echo   %app.git_switch_branch.current%
:_Main_current_done
echo.
echo Target branch:
echo   %app.git_switch_branch.name%
echo.
echo Source:
echo   %app.git_switch_branch.kind%
echo.
set /p "app.git_switch_branch.confirm=Type SWITCH to continue: "
if "%app.git_switch_branch.confirm%"=="SWITCH" goto :_Main_switch
echo.
echo Cancelled. Nothing was changed.
set "_gsbm_rc=0" & goto :Main
:_Main_switch
if /I "%app.git_switch_branch.kind%"=="origin" goto :_Main_switch_origin
git switch "%app.git_switch_branch.name%"
set "_gsbm_rc=%errorlevel%"
if "%_gsbm_rc%"=="0" goto :_Main_success
echo git switch failed. Trying git checkout...
git checkout "%app.git_switch_branch.name%"
set "_gsbm_rc=%errorlevel%"
goto :_Main_result
:_Main_switch_origin
git switch --track -c "%app.git_switch_branch.name%" "origin/%app.git_switch_branch.name%"
set "_gsbm_rc=%errorlevel%"
if "%_gsbm_rc%"=="0" goto :_Main_success
echo git switch failed. Trying git checkout...
git checkout -b "%app.git_switch_branch.name%" --track "origin/%app.git_switch_branch.name%"
set "_gsbm_rc=%errorlevel%"
:_Main_result
if "%_gsbm_rc%"=="0" goto :_Main_success
echo.
echo ERROR: Git could not switch branches.
echo No destructive recovery was attempted.
set "_gsbm_rc=1" & goto :Main
:_Main_success
echo.
echo ============================================================
echo  Branch switched
echo ============================================================
echo.
git status --short --branch
set "_gsbm_status_rc=%errorlevel%"
if not "%_gsbm_status_rc%"=="0" echo WARNING: The switch succeeded, but Git status could not be displayed.
echo.
set "_gsbm_rc=0" & goto :Main
:_Main_already
echo.
echo Already on branch:
echo   %app.git_switch_branch.name%
set "_gsbm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_gsbm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses target branch, fetch, dirty-tree override, and help.
::
:: Usage: call :ParseArgs [name BRANCH] [fetch yes|no] [allowdirty yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="name" goto :_ParseArgs_name
if /I "%~1"=="branch" goto :_ParseArgs_name
if /I "%~1"=="fetch" goto :_ParseArgs_fetch
if /I "%~1"=="allowdirty" goto :_ParseArgs_dirty
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_switch_branch.name (set "app.git_switch_branch.name=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_name
if "%~2"=="" (echo ERROR: name requires a branch name. & exit /b 2)
set "app.git_switch_branch.name=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_fetch
if "%~2"=="" (echo ERROR: fetch requires yes or no. & exit /b 2)
set "app.git_switch_branch.fetch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_dirty
if "%~2"=="" (echo ERROR: allowdirty requires yes or no. & exit /b 2)
set "app.git_switch_branch.allowdirty=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_switch_branch.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gsby_ 2^>nul') do set "%%v="
if defined _gsby_rc (set "_gsby_rc=" & exit /b %_gsby_rc%)
set "gsby_name=%~1"
call set "gsby_value=%%%gsby_name%%%"
if /I "%gsby_value%"=="y" set "%gsby_name%=yes"
if /I "%gsby_value%"=="yes" set "%gsby_name%=yes"
if /I "%gsby_value%"=="true" set "%gsby_name%=yes"
if /I "%gsby_value%"=="1" set "%gsby_name%=yes"
if /I "%gsby_value%"=="n" set "%gsby_name%=no"
if /I "%gsby_value%"=="no" set "%gsby_name%=no"
if /I "%gsby_value%"=="false" set "%gsby_name%=no"
if /I "%gsby_value%"=="0" set "%gsby_name%=no"
call set "gsby_value=%%%gsby_name%%%"
if /I "%gsby_value%"=="yes" (set "_gsby_rc=0" & goto :NormalizeYesNo)
if /I "%gsby_value%"=="no" (set "_gsby_rc=0" & goto :NormalizeYesNo)
set "_gsby_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays safe local and origin branch-switch behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_switch_branch.bat
echo.
echo Usage:
echo   git_switch_branch.bat
echo   git_switch_branch.bat feature/name
echo   git_switch_branch.bat name feature/name fetch no
echo   git_switch_branch.bat name feature/name allowdirty yes
echo.
echo The helper switches only to an existing local branch or an
echo existing origin branch. It does not create unrelated branches.
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
