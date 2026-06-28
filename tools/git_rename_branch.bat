@echo off
:: ============================================================
:: git_rename_branch.bat
:: Renames one local branch and can publish the new name. The old
:: origin branch is deleted only after the new branch pushes successfully.
::
:: Usage:
::   call tools\git_rename_branch.bat
::   call tools\git_rename_branch.bat new feature/new-name
::   call tools\git_rename_branch.bat old feature/old new feature/new push yes
::   call tools\git_rename_branch.bat new feature/new push yes deleteoldremote yes
::
:: Returns: 0 on successful rename, cancellation, or help
::          1 on preparation, repository, branch, fetch, rename, or push failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_rename_branch.old="
set "app.git_rename_branch.new="
set "app.git_rename_branch.push=no"
set "app.git_rename_branch.deleteoldremote=no"
set "app.git_rename_branch.current="
set "app.git_rename_branch.origin="
set "app.git_rename_branch.oldremote.exists="
set "app.git_rename_branch.confirm="
set "app.git_rename_branch.help="
set "app.git_rename_branch.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_rename_branch.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_rename_branch.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_rename_branch.rc%
:: ============================================================
:: :Main
:: Validates old and new names, checks remote collisions when pushing,
:: confirms the plan, renames locally, then performs requested remote work.
::
:: Usage: call :Main [old BRANCH] new BRANCH [push yes|no]
::        [deleteoldremote yes|no]
::
:: Returns: 0 on successful rename, cancellation, or help
::          1 on preparation, repository, branch, fetch, rename, or push failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set grbm_ 2^>nul') do set "%%v="
if defined _grbm_rc (set "_grbm_rc=" & exit /b %_grbm_rc%)
call :ParseArgs %*
set "_grbm_rc=%errorlevel%"
if not "%_grbm_rc%"=="0" goto :Main
if defined app.git_rename_branch.help goto :_Main_help
call :NormalizeYesNo app.git_rename_branch.push
if errorlevel 1 (echo ERROR: push must be yes or no. & set "_grbm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_rename_branch.deleteoldremote
if errorlevel 1 (echo ERROR: deleteoldremote must be yes or no. & set "_grbm_rc=2" & goto :Main)
if /I "%app.git_rename_branch.deleteoldremote%"=="yes" if /I not "%app.git_rename_branch.push%"=="yes" (echo ERROR: deleteoldremote yes requires push yes. & set "_grbm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Rename Git branch
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_grbm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_grbm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_grbm_rc=1" & goto :Main)
set "app.git_rename_branch.current="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_rename_branch.current=%%A"
if not defined app.git_rename_branch.old set "app.git_rename_branch.old=%app.git_rename_branch.current%"
if not defined app.git_rename_branch.old (echo ERROR: No current branch was found. Specify old explicitly. & set "_grbm_rc=1" & goto :Main)
if not defined app.git_rename_branch.new set /p "app.git_rename_branch.new=New branch name: "
if not defined app.git_rename_branch.new (echo ERROR: A new branch name is required. & set "_grbm_rc=1" & goto :Main)
if /I "%app.git_rename_branch.old%"=="%app.git_rename_branch.new%" (echo ERROR: Old and new branch names are the same. & set "_grbm_rc=2" & goto :Main)
git show-ref --verify --quiet "refs/heads/%app.git_rename_branch.old%"
if errorlevel 1 (echo ERROR: Local branch does not exist: & echo   %app.git_rename_branch.old% & set "_grbm_rc=1" & goto :Main)
git check-ref-format --branch "%app.git_rename_branch.new%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid new branch name: & echo   %app.git_rename_branch.new% & set "_grbm_rc=2" & goto :Main)
git show-ref --verify --quiet "refs/heads/%app.git_rename_branch.new%"
if not errorlevel 1 (echo ERROR: A local branch already uses the new name: & echo   %app.git_rename_branch.new% & set "_grbm_rc=1" & goto :Main)
if /I "%app.git_rename_branch.push%"=="yes" goto :_Main_remote_checks
goto :_Main_plan
:_Main_remote_checks
set "app.git_rename_branch.origin="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_rename_branch.origin=%%A"
if not defined app.git_rename_branch.origin (echo ERROR: push was requested, but origin is not configured. & set "_grbm_rc=1" & goto :Main)
echo Refreshing origin branch information...
git fetch --prune --quiet origin
if errorlevel 1 (echo ERROR: origin could not be fetched safely. & set "_grbm_rc=1" & goto :Main)
set "app.git_rename_branch.oldremote.exists="
git show-ref --verify --quiet "refs/remotes/origin/%app.git_rename_branch.old%"
if not errorlevel 1 set "app.git_rename_branch.oldremote.exists=1"
git show-ref --verify --quiet "refs/remotes/origin/%app.git_rename_branch.new%"
if not errorlevel 1 (echo ERROR: origin already has the new branch name: & echo   %app.git_rename_branch.new% & set "_grbm_rc=1" & goto :Main)
:_Main_plan
echo.
echo Old local branch:
echo   %app.git_rename_branch.old%
echo.
echo New local branch:
echo   %app.git_rename_branch.new%
echo.
echo Push new branch:
echo   %app.git_rename_branch.push%
echo.
echo Delete old origin branch:
echo   %app.git_rename_branch.deleteoldremote%
echo.
if /I "%app.git_rename_branch.deleteoldremote%"=="yes" if not defined app.git_rename_branch.oldremote.exists echo Note: origin/%app.git_rename_branch.old% was not found, so no old remote branch will be deleted.
echo.
set /p "app.git_rename_branch.confirm=Type RENAME to continue: "
if "%app.git_rename_branch.confirm%"=="RENAME" goto :_Main_rename
echo.
echo Cancelled. Nothing was changed.
set "_grbm_rc=0" & goto :Main
:_Main_rename
if /I "%app.git_rename_branch.current%"=="%app.git_rename_branch.old%" goto :_Main_rename_current
git branch -m "%app.git_rename_branch.old%" "%app.git_rename_branch.new%"
set "_grbm_rc=%errorlevel%"
goto :_Main_rename_result
:_Main_rename_current
git branch -m "%app.git_rename_branch.new%"
set "_grbm_rc=%errorlevel%"
:_Main_rename_result
if "%_grbm_rc%"=="0" goto :_Main_push
echo ERROR: Local branch rename failed.
set "_grbm_rc=1" & goto :Main
:_Main_push
if /I not "%app.git_rename_branch.push%"=="yes" goto :_Main_success
git push -u origin "%app.git_rename_branch.new%"
set "_grbm_rc=%errorlevel%"
if "%_grbm_rc%"=="0" goto :_Main_delete_old
echo.
echo ERROR: The branch was renamed locally, but pushing the new name failed.
echo Local branch now remains:
echo   %app.git_rename_branch.new%
set "_grbm_rc=1" & goto :Main
:_Main_delete_old
if /I not "%app.git_rename_branch.deleteoldremote%"=="yes" goto :_Main_success
if not defined app.git_rename_branch.oldremote.exists goto :_Main_success
git push origin --delete "%app.git_rename_branch.old%"
set "_grbm_rc=%errorlevel%"
if "%_grbm_rc%"=="0" goto :_Main_success
echo.
echo ERROR: The new branch was pushed, but deleting the old origin branch failed.
echo New branch:
echo   origin/%app.git_rename_branch.new%
echo Old branch still present:
echo   origin/%app.git_rename_branch.old%
set "_grbm_rc=1" & goto :Main
:_Main_success
echo.
echo Branch rename completed:
echo   %app.git_rename_branch.old% to %app.git_rename_branch.new%
echo.
git status --short --branch
set "_grbm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_grbm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses old and new branch names, push, remote deletion, and help.
::
:: Usage: call :ParseArgs [old BRANCH] new BRANCH [push yes|no]
::        [deleteoldremote yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="old" goto :_ParseArgs_old
if /I "%~1"=="new" goto :_ParseArgs_new
if /I "%~1"=="push" goto :_ParseArgs_push
if /I "%~1"=="deleteoldremote" goto :_ParseArgs_delete
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_old
if "%~2"=="" (echo ERROR: old requires a branch name. & exit /b 2)
set "app.git_rename_branch.old=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_new
if "%~2"=="" (echo ERROR: new requires a branch name. & exit /b 2)
set "app.git_rename_branch.new=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_push
if "%~2"=="" (echo ERROR: push requires yes or no. & exit /b 2)
set "app.git_rename_branch.push=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_delete
if "%~2"=="" (echo ERROR: deleteoldremote requires yes or no. & exit /b 2)
set "app.git_rename_branch.deleteoldremote=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_rename_branch.help=1"
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
for /f "tokens=1 delims==" %%v in ('set grby_ 2^>nul') do set "%%v="
if defined _grby_rc (set "_grby_rc=" & exit /b %_grby_rc%)
set "grby_name=%~1"
call set "grby_value=%%%grby_name%%%"
if /I "%grby_value%"=="y" set "%grby_name%=yes"
if /I "%grby_value%"=="yes" set "%grby_name%=yes"
if /I "%grby_value%"=="true" set "%grby_name%=yes"
if /I "%grby_value%"=="1" set "%grby_name%=yes"
if /I "%grby_value%"=="n" set "%grby_name%=no"
if /I "%grby_value%"=="no" set "%grby_name%=no"
if /I "%grby_value%"=="false" set "%grby_name%=no"
if /I "%grby_value%"=="0" set "%grby_name%=no"
call set "grby_value=%%%grby_name%%%"
if /I "%grby_value%"=="yes" (set "_grby_rc=0" & goto :NormalizeYesNo)
if /I "%grby_value%"=="no" (set "_grby_rc=0" & goto :NormalizeYesNo)
set "_grby_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays local rename, publication, and old-remote deletion behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_rename_branch.bat
echo.
echo Usage:
echo   git_rename_branch.bat new feature/new-name
echo   git_rename_branch.bat old feature/old new feature/new push yes
echo   git_rename_branch.bat new feature/new push yes deleteoldremote yes
echo.
echo The old remote branch is deleted only after the new branch pushes.
echo Partial remote failures are reported without hiding the local rename.
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
