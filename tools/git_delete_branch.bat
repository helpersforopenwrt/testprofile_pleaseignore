@echo off
:: ============================================================
:: git_delete_branch.bat
:: Deletes a non-current local branch and optionally its origin
:: branch. Unmerged local branches require force yes.
::
:: Usage:
::   call tools\git_delete_branch.bat feature/old
::   call tools\git_delete_branch.bat name feature/old remote yes
::   call tools\git_delete_branch.bat name feature/old force yes remote yes
::
:: Returns: 0 on success or cancellation
::          1 on repository, validation, safety, or deletion failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, findstr, :Main,
::           :ParseArgs, :NormalizeYesNo, :ValidateBranchPlan,
::           :ShowPlan, :DeleteBranch, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_delete_branch.name="
set "app.git_delete_branch.remote=no"
set "app.git_delete_branch.force=no"
set "app.git_delete_branch.current="
set "app.git_delete_branch.local.exists="
set "app.git_delete_branch.remote.exists="
set "app.git_delete_branch.merged="
set "app.git_delete_branch.other.worktree="
set "app.git_delete_branch.origin="
set "app.git_delete_branch.confirm="
set "app.git_delete_branch.help="
set "app.git_delete_branch.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_delete_branch.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_delete_branch.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_delete_branch.rc%
:: ============================================================
:: :Main
:: Parses options, prepares Git, validates the branch plan, displays
:: it, confirms deletion, and performs local and remote deletion.
::
:: Usage: call :Main [name BRANCH] [remote yes|no] [force yes|no]
::
:: Returns: 0 on success or cancellation
::          1 on repository, validation, safety, or deletion failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ValidateBranchPlan,
::           :ShowPlan, :DeleteBranch, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gdbm_ 2^>nul') do set "%%v="
if defined _gdbm_rc (set "_gdbm_rc=" & exit /b %_gdbm_rc%)
call :ParseArgs %*
set "_gdbm_rc=%errorlevel%"
if not "%_gdbm_rc%"=="0" goto :Main
if defined app.git_delete_branch.help goto :_Main_help
call :NormalizeYesNo app.git_delete_branch.remote
if errorlevel 1 (echo ERROR: remote must be yes or no. & set "_gdbm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_delete_branch.force
if errorlevel 1 (echo ERROR: force must be yes or no. & set "_gdbm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Delete Git branch
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gdbm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gdbm_rc=1" & goto :Main)
if not defined app.git_delete_branch.name set /p "app.git_delete_branch.name=Branch to delete: "
call :ValidateBranchPlan
if errorlevel 1 (set "_gdbm_rc=%errorlevel%" & goto :Main)
call :ShowPlan
if errorlevel 1 (set "_gdbm_rc=%errorlevel%" & goto :Main)
set /p "app.git_delete_branch.confirm=Type DELETE to continue: "
if "%app.git_delete_branch.confirm%"=="DELETE" goto :_Main_delete
echo.
echo Cancelled. Nothing was deleted.
set "_gdbm_rc=0" & goto :Main
:_Main_delete
call :DeleteBranch
set "_gdbm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gdbm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ValidateBranchPlan
:: Validates the branch name, current and linked-worktree usage,
:: local merge safety, origin reachability, and remote existence.
::
:: Usage: call :ValidateBranchPlan
::
:: Returns: 0 when deletion may proceed
::          1 when validation or safety checks fail
:: Requires: git, findstr
:: ============================================================
:ValidateBranchPlan
for /f "tokens=1 delims==" %%v in ('set gdbv_ 2^>nul') do set "%%v="
if defined _gdbv_rc (set "_gdbv_rc=" & exit /b %_gdbv_rc%)
if not defined app.git_delete_branch.name (echo ERROR: A branch name is required. & set "_gdbv_rc=1" & goto :ValidateBranchPlan)
git check-ref-format --branch "%app.git_delete_branch.name%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid branch name: & echo   %app.git_delete_branch.name% & set "_gdbv_rc=1" & goto :ValidateBranchPlan)
set "app.git_delete_branch.current="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_delete_branch.current=%%A"
if /I "%app.git_delete_branch.current%"=="%app.git_delete_branch.name%" (echo ERROR: The current branch cannot be deleted. & echo Switch to another branch first. & set "_gdbv_rc=1" & goto :ValidateBranchPlan)
set "app.git_delete_branch.local.exists="
git show-ref --verify --quiet "refs/heads/%app.git_delete_branch.name%"
if not errorlevel 1 set "app.git_delete_branch.local.exists=1"
if not defined app.git_delete_branch.local.exists goto :_ValidateBranchPlan_remote
set "app.git_delete_branch.other.worktree="
git worktree list --porcelain 2>nul | findstr.exe /I /X /L /C:"branch refs/heads/%app.git_delete_branch.name%" >nul
if not errorlevel 1 set "app.git_delete_branch.other.worktree=1"
if defined app.git_delete_branch.other.worktree (echo ERROR: The branch is checked out in another worktree: & echo   %app.git_delete_branch.name% & set "_gdbv_rc=1" & goto :ValidateBranchPlan)
git merge-base --is-ancestor "%app.git_delete_branch.name%" HEAD >nul 2>nul
if not errorlevel 1 set "app.git_delete_branch.merged=1"
if defined app.git_delete_branch.merged goto :_ValidateBranchPlan_remote
if /I "%app.git_delete_branch.force%"=="yes" goto :_ValidateBranchPlan_remote
echo.
echo ERROR: The local branch is not merged into the current branch.
echo.
echo Branch:
echo   %app.git_delete_branch.name%
echo.
echo Current branch:
if defined app.git_delete_branch.current (echo   %app.git_delete_branch.current%) else (echo   detached HEAD)
echo.
echo Nothing was deleted.
echo To delete it anyway, use force yes.
set "_gdbv_rc=1" & goto :ValidateBranchPlan
:_ValidateBranchPlan_remote
set "app.git_delete_branch.remote.exists="
if /I not "%app.git_delete_branch.remote%"=="yes" goto :_ValidateBranchPlan_presence
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_delete_branch.origin=%%A"
if not defined app.git_delete_branch.origin (echo ERROR: remote yes was requested, but origin is not configured. & set "_gdbv_rc=1" & goto :ValidateBranchPlan)
git ls-remote --heads origin >nul 2>nul
if errorlevel 1 (echo ERROR: origin could not be reached, so remote deletion safety cannot be verified. & set "_gdbv_rc=1" & goto :ValidateBranchPlan)
for /f "delims=" %%A in ('git ls-remote --heads origin "refs/heads/%app.git_delete_branch.name%" 2^>nul') do set "app.git_delete_branch.remote.exists=1"
:_ValidateBranchPlan_presence
if defined app.git_delete_branch.local.exists (set "_gdbv_rc=0" & goto :ValidateBranchPlan)
if /I "%app.git_delete_branch.remote%"=="yes" if defined app.git_delete_branch.remote.exists (set "_gdbv_rc=0" & goto :ValidateBranchPlan)
echo ERROR: Requested branch was not found in the selected locations:
echo   %app.git_delete_branch.name%
set "_gdbv_rc=1" & goto :ValidateBranchPlan
:: ============================================================
:: :ShowPlan
:: Displays local and remote deletion choices and recent commits.
::
:: Usage: call :ShowPlan
::
:: Returns: 0
:: Requires: git
:: ============================================================
:ShowPlan
echo.
echo Branch:
echo   %app.git_delete_branch.name%
echo.
echo Delete local branch:
if defined app.git_delete_branch.local.exists (echo   yes) else (echo   not present)
echo.
echo Delete origin branch:
if /I not "%app.git_delete_branch.remote%"=="yes" goto :_ShowPlan_remote_no
if defined app.git_delete_branch.remote.exists (echo   yes) else (echo   requested, but not present)
goto :_ShowPlan_warning
:_ShowPlan_remote_no
echo   no
:_ShowPlan_warning
echo.
if not defined app.git_delete_branch.merged if defined app.git_delete_branch.local.exists echo WARNING: force yes permits deletion of an unmerged local branch.
echo.
if not defined app.git_delete_branch.local.exists goto :_ShowPlan_done
echo Recent branch commits:
git log --oneline -5 "%app.git_delete_branch.name%" 2>nul
echo.
:_ShowPlan_done
exit /b 0
:: ============================================================
:: :DeleteBranch
:: Deletes the local branch first and then the requested remote
:: branch, clearly reporting partial success.
::
:: Usage: call :DeleteBranch
::
:: Returns: 0 on success
::          1 on local or remote deletion failure
:: Requires: git
:: ============================================================
:DeleteBranch
for /f "tokens=1 delims==" %%v in ('set gdbd_ 2^>nul') do set "%%v="
if defined _gdbd_rc (set "_gdbd_rc=" & exit /b %_gdbd_rc%)
if not defined app.git_delete_branch.local.exists goto :_DeleteBranch_remote
if /I "%app.git_delete_branch.force%"=="yes" goto :_DeleteBranch_local_force
git branch -d "%app.git_delete_branch.name%"
goto :_DeleteBranch_local_result
:_DeleteBranch_local_force
git branch -D "%app.git_delete_branch.name%"
:_DeleteBranch_local_result
if errorlevel 1 (echo ERROR: Local branch deletion failed. & set "_gdbd_rc=1" & goto :DeleteBranch)
:_DeleteBranch_remote
if /I not "%app.git_delete_branch.remote%"=="yes" goto :_DeleteBranch_done
if not defined app.git_delete_branch.remote.exists goto :_DeleteBranch_done
git push origin --delete "%app.git_delete_branch.name%"
if errorlevel 1 goto :_DeleteBranch_remote_failed
:_DeleteBranch_done
echo.
echo Branch deletion complete.
set "_gdbd_rc=0" & goto :DeleteBranch
:_DeleteBranch_remote_failed
echo ERROR: Remote branch deletion failed.
if defined app.git_delete_branch.local.exists echo The local branch was already deleted.
set "_gdbd_rc=1" & goto :DeleteBranch
:: ============================================================
:: :ParseArgs
:: Parses branch name, remote, force, and help arguments.
::
:: Usage: call :ParseArgs [name BRANCH] [remote yes|no] [force yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="name" goto :_ParseArgs_name
if /I "%~1"=="branch" goto :_ParseArgs_name
if /I "%~1"=="remote" goto :_ParseArgs_remote
if /I "%~1"=="force" goto :_ParseArgs_force
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_delete_branch.name (set "app.git_delete_branch.name=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_name
if "%~2"=="" (echo ERROR: name requires a branch name. & exit /b 2)
set "app.git_delete_branch.name=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_remote
if "%~2"=="" (echo ERROR: remote requires yes or no. & exit /b 2)
set "app.git_delete_branch.remote=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_force
if "%~2"=="" (echo ERROR: force requires yes or no. & exit /b 2)
set "app.git_delete_branch.force=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_delete_branch.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gdby_ 2^>nul') do set "%%v="
if defined _gdby_rc (set "_gdby_rc=" & exit /b %_gdby_rc%)
set "gdby_name=%~1"
call set "gdby_value=%%%gdby_name%%%"
if /I "%gdby_value%"=="y" set "%gdby_name%=yes"
if /I "%gdby_value%"=="yes" set "%gdby_name%=yes"
if /I "%gdby_value%"=="true" set "%gdby_name%=yes"
if /I "%gdby_value%"=="1" set "%gdby_name%=yes"
if /I "%gdby_value%"=="n" set "%gdby_name%=no"
if /I "%gdby_value%"=="no" set "%gdby_name%=no"
if /I "%gdby_value%"=="false" set "%gdby_name%=no"
if /I "%gdby_value%"=="0" set "%gdby_name%=no"
call set "gdby_value=%%%gdby_name%%%"
if /I "%gdby_value%"=="yes" (set "_gdby_rc=0" & goto :NormalizeYesNo)
if /I "%gdby_value%"=="no" (set "_gdby_rc=0" & goto :NormalizeYesNo)
set "_gdby_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays command usage.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_delete_branch.bat
echo.
echo Usage:
echo   git_delete_branch.bat feature/old
echo   git_delete_branch.bat name feature/old remote yes
echo   git_delete_branch.bat name feature/old force yes remote yes
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
