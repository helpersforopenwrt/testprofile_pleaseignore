@echo off
:: ============================================================
:: git_create_branch.bat
:: Creates and switches to a new local branch and optionally pushes
:: it to origin with upstream tracking.
::
:: Usage:
::   call tools\git_create_branch.bat feature/my-change
::   call tools\git_create_branch.bat name feature/my-change start main
::   call tools\git_create_branch.bat name feature/my-change push yes
::   call tools\git_create_branch.bat name feature/my-change allowdirty yes
::
:: Returns: 0 on success or cancellation
::          1 on repository, safety, validation, creation, or push failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ResolvePushChoice, :ValidateBranchPlan,
::           :ShowPlan, :CreateBranch, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_create_branch.name="
set "app.git_create_branch.start="
set "app.git_create_branch.push="
set "app.git_create_branch.allowdirty=no"
set "app.git_create_branch.current="
set "app.git_create_branch.origin="
set "app.git_create_branch.dirty="
set "app.git_create_branch.remote.exists="
set "app.git_create_branch.input="
set "app.git_create_branch.confirm="
set "app.git_create_branch.help="
set "app.git_create_branch.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_create_branch.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_create_branch.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_create_branch.rc%
:: ============================================================
:: :Main
:: Parses options, prepares Git, resolves interactive choices,
:: validates the branch plan, confirms, creates, and optionally pushes.
::
:: Usage: call :Main [name BRANCH] [start REV] [push yes|no] [allowdirty yes|no]
::
:: Returns: 0 on success or cancellation
::          1 on repository, safety, validation, creation, or push failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ResolvePushChoice,
::           :ValidateBranchPlan, :ShowPlan, :CreateBranch,
::           :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcbm_ 2^>nul') do set "%%v="
if defined _gcbm_rc (set "_gcbm_rc=" & exit /b %_gcbm_rc%)
call :ParseArgs %*
set "_gcbm_rc=%errorlevel%"
if not "%_gcbm_rc%"=="0" goto :Main
if defined app.git_create_branch.help goto :_Main_help
call :NormalizeYesNo app.git_create_branch.allowdirty
if errorlevel 1 (echo ERROR: allowdirty must be yes or no. & set "_gcbm_rc=2" & goto :Main)
if defined app.git_create_branch.push goto :_Main_normalize_push
goto :_Main_prepare
:_Main_normalize_push
call :NormalizeYesNo app.git_create_branch.push
if errorlevel 1 (echo ERROR: push must be yes or no. & set "_gcbm_rc=2" & goto :Main)
:_Main_prepare
echo.
echo ============================================================
echo  Create a new Git branch
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
if not exist "%CD%\prepare.bat" (echo ERROR: prepare.bat was not found in the project root. & set "_gcbm_rc=1" & goto :Main)
echo Preparing Git...
call "%CD%\prepare.bat" git
if errorlevel 1 (echo. & echo ERROR: Git preparation failed. & set "_gcbm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo. & echo ERROR: Git was not found in PATH. & set "_gcbm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo. & echo ERROR: This folder is not inside a Git working tree. & set "_gcbm_rc=1" & goto :Main)
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo. & echo ERROR: The repository has no commits. & echo Create the first commit before creating another branch. & set "_gcbm_rc=1" & goto :Main)
if not defined app.git_create_branch.name set /p "app.git_create_branch.name=New branch name: "
call :ResolvePushChoice
if errorlevel 1 (set "_gcbm_rc=%errorlevel%" & goto :Main)
call :ValidateBranchPlan
if errorlevel 1 (set "_gcbm_rc=%errorlevel%" & goto :Main)
call :ShowPlan
if errorlevel 1 (set "_gcbm_rc=%errorlevel%" & goto :Main)
set /p "app.git_create_branch.confirm=Type CREATE to continue: "
if "%app.git_create_branch.confirm%"=="CREATE" goto :_Main_create
echo.
echo Cancelled. Nothing was changed.
set "_gcbm_rc=0" & goto :Main
:_Main_create
call :CreateBranch
set "_gcbm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gcbm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ResolvePushChoice
:: Prompts for the push choice when it was not supplied.
::
:: Usage: call :ResolvePushChoice
::
:: Output:
::   app.git_create_branch.push  yes or no
::
:: Returns: 0 when valid
::          2 when invalid
:: Requires: :NormalizeYesNo
:: ============================================================
:ResolvePushChoice
for /f "tokens=1 delims==" %%v in ('set gcbp_ 2^>nul') do set "%%v="
if defined _gcbp_rc (set "_gcbp_rc=" & exit /b %_gcbp_rc%)
if defined app.git_create_branch.push (set "_gcbp_rc=0" & goto :ResolvePushChoice)
echo.
set /p "app.git_create_branch.input=Push the new branch to origin and set upstream? [y/N]: "
if /I "%app.git_create_branch.input%"=="y" set "app.git_create_branch.push=yes"
if /I "%app.git_create_branch.input%"=="yes" set "app.git_create_branch.push=yes"
if not defined app.git_create_branch.push set "app.git_create_branch.push=no"
call :NormalizeYesNo app.git_create_branch.push
if errorlevel 1 (echo ERROR: push must be yes or no. & set "_gcbp_rc=2" & goto :ResolvePushChoice)
set "_gcbp_rc=0" & goto :ResolvePushChoice
:: ============================================================
:: :ValidateBranchPlan
:: Validates branch name, start revision, dirty-worktree policy,
:: origin requirements, and remote branch collisions.
::
:: Usage: call :ValidateBranchPlan
::
:: Returns: 0 when the plan is safe
::          1 when validation or safety checks fail
:: Requires: git
:: ============================================================
:ValidateBranchPlan
for /f "tokens=1 delims==" %%v in ('set gcbv_ 2^>nul') do set "%%v="
if defined _gcbv_rc (set "_gcbv_rc=" & exit /b %_gcbv_rc%)
if not defined app.git_create_branch.name (echo. & echo ERROR: A branch name is required. & set "_gcbv_rc=1" & goto :ValidateBranchPlan)
git check-ref-format --branch "%app.git_create_branch.name%" >nul 2>nul
if errorlevel 1 (echo. & echo ERROR: Invalid branch name: & echo   %app.git_create_branch.name% & set "_gcbv_rc=1" & goto :ValidateBranchPlan)
git show-ref --verify --quiet "refs/heads/%app.git_create_branch.name%"
if not errorlevel 1 (echo. & echo ERROR: A local branch already exists: & echo   %app.git_create_branch.name% & set "_gcbv_rc=1" & goto :ValidateBranchPlan)
if not defined app.git_create_branch.start set "app.git_create_branch.start=HEAD"
git rev-parse --verify "%app.git_create_branch.start%^^{commit}" >nul 2>nul
if errorlevel 1 (echo. & echo ERROR: Starting point was not found or is not a commit: & echo   %app.git_create_branch.start% & set "_gcbv_rc=1" & goto :ValidateBranchPlan)
set "app.git_create_branch.current="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_create_branch.current=%%A"
set "app.git_create_branch.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_create_branch.dirty=1"
if not defined app.git_create_branch.dirty goto :_ValidateBranchPlan_origin
if /I "%app.git_create_branch.allowdirty%"=="yes" goto :_ValidateBranchPlan_dirty_allowed
echo.
echo ERROR: The working tree has uncommitted changes.
echo.
git status --short
echo.
echo Nothing was changed.
echo Commit, stash, or discard those changes before creating the branch.
echo.
echo To deliberately carry them into the new branch, use:
echo   git_create_branch.bat name "%app.git_create_branch.name%" allowdirty yes
set "_gcbv_rc=1" & goto :ValidateBranchPlan
:_ValidateBranchPlan_dirty_allowed
echo.
echo WARNING: Uncommitted changes will carry into the new branch.
echo.
git status --short
:_ValidateBranchPlan_origin
set "app.git_create_branch.origin="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_create_branch.origin=%%A"
if /I not "%app.git_create_branch.push%"=="yes" (set "_gcbv_rc=0" & goto :ValidateBranchPlan)
if not defined app.git_create_branch.origin (echo. & echo ERROR: push was requested, but origin is not configured. & set "_gcbv_rc=1" & goto :ValidateBranchPlan)
git ls-remote --heads origin >nul 2>nul
if errorlevel 1 (echo. & echo ERROR: origin could not be reached. & set "_gcbv_rc=1" & goto :ValidateBranchPlan)
set "app.git_create_branch.remote.exists="
for /f "delims=" %%A in ('git ls-remote --heads origin "refs/heads/%app.git_create_branch.name%" 2^>nul') do set "app.git_create_branch.remote.exists=1"
if not defined app.git_create_branch.remote.exists (set "_gcbv_rc=0" & goto :ValidateBranchPlan)
echo.
echo ERROR: A branch with this name already exists on origin:
echo   %app.git_create_branch.name%
echo.
echo Use the branch-switch helper to work with the existing branch.
set "_gcbv_rc=1" & goto :ValidateBranchPlan
:: ============================================================
:: :ShowPlan
:: Displays the current branch, new branch, start point, push choice,
:: and dirty-worktree policy.
::
:: Usage: call :ShowPlan
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowPlan
echo.
echo ============================================================
echo  Planned branch
echo ============================================================
echo.
echo Current branch:
if defined app.git_create_branch.current goto :_ShowPlan_current
echo   detached HEAD
goto :_ShowPlan_new
:_ShowPlan_current
echo   %app.git_create_branch.current%
:_ShowPlan_new
echo.
echo New branch:
echo   %app.git_create_branch.name%
echo.
echo Starting point:
echo   %app.git_create_branch.start%
echo.
echo Push after creation:
echo   %app.git_create_branch.push%
echo.
if defined app.git_create_branch.dirty echo Uncommitted changes will carry into the new branch.
echo.
exit /b 0
:: ============================================================
:: :CreateBranch
:: Creates the branch with git switch or checkout fallback and
:: optionally pushes it to origin with upstream tracking.
::
:: Usage: call :CreateBranch
::
:: Returns: 0 on success
::          1 on local creation or push failure
:: Requires: git
:: ============================================================
:CreateBranch
for /f "tokens=1 delims==" %%v in ('set gcbc_ 2^>nul') do set "%%v="
if defined _gcbc_rc (set "_gcbc_rc=" & exit /b %_gcbc_rc%)
echo.
echo Creating branch:
echo   %app.git_create_branch.name%
echo.
git switch -c "%app.git_create_branch.name%" "%app.git_create_branch.start%"
if not errorlevel 1 goto :_CreateBranch_created
echo.
echo git switch failed. Trying the compatible git checkout form...
git checkout -b "%app.git_create_branch.name%" "%app.git_create_branch.start%"
if errorlevel 1 (echo. & echo ERROR: Could not create the new branch. & set "_gcbc_rc=1" & goto :CreateBranch)
:_CreateBranch_created
if /I "%app.git_create_branch.push%"=="yes" goto :_CreateBranch_push
echo.
echo ============================================================
echo  Local branch created
echo ============================================================
echo.
echo Current branch:
echo   %app.git_create_branch.name%
echo.
echo It has not been pushed.
echo To publish it later, run:
echo   just_push.bat
echo.
set "_gcbc_rc=0" & goto :CreateBranch
:_CreateBranch_push
echo.
echo Pushing and setting upstream:
echo   origin/%app.git_create_branch.name%
echo.
git push -u origin "%app.git_create_branch.name%"
if errorlevel 1 goto :_CreateBranch_push_failed
echo.
echo ============================================================
echo  Branch created and pushed
echo ============================================================
echo.
echo Local branch:
echo   %app.git_create_branch.name%
echo.
echo Tracking:
echo   origin/%app.git_create_branch.name%
echo.
set "_gcbc_rc=0" & goto :CreateBranch
:_CreateBranch_push_failed
echo.
echo ERROR: The branch was created locally, but the push failed.
echo.
echo Local branch:
echo   %app.git_create_branch.name%
echo.
echo Retry later with:
echo   just_push.bat
set "_gcbc_rc=1" & goto :CreateBranch
:: ============================================================
:: :ParseArgs
:: Parses branch name, start, push, allowdirty, and help arguments.
::
:: Usage: call :ParseArgs [name BRANCH] [start REV] [push yes|no] [allowdirty yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="name" goto :_ParseArgs_name
if /I "%~1"=="branch" goto :_ParseArgs_name
if /I "%~1"=="start" goto :_ParseArgs_start
if /I "%~1"=="from" goto :_ParseArgs_start
if /I "%~1"=="push" goto :_ParseArgs_push
if /I "%~1"=="allowdirty" goto :_ParseArgs_allowdirty
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_create_branch.name (set "app.git_create_branch.name=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_name
if "%~2"=="" (echo ERROR: name requires a branch name. & exit /b 2)
set "app.git_create_branch.name=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_start
if "%~2"=="" (echo ERROR: start requires a commit, tag, or branch. & exit /b 2)
set "app.git_create_branch.start=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_push
if "%~2"=="" (echo ERROR: push requires yes or no. & exit /b 2)
set "app.git_create_branch.push=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_allowdirty
if "%~2"=="" (echo ERROR: allowdirty requires yes or no. & exit /b 2)
set "app.git_create_branch.allowdirty=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_create_branch.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gcby_ 2^>nul') do set "%%v="
if defined _gcby_rc (set "_gcby_rc=" & exit /b %_gcby_rc%)
set "gcby_name=%~1"
call set "gcby_value=%%%gcby_name%%%"
if /I "%gcby_value%"=="y" set "%gcby_name%=yes"
if /I "%gcby_value%"=="yes" set "%gcby_name%=yes"
if /I "%gcby_value%"=="true" set "%gcby_name%=yes"
if /I "%gcby_value%"=="1" set "%gcby_name%=yes"
if /I "%gcby_value%"=="n" set "%gcby_name%=no"
if /I "%gcby_value%"=="no" set "%gcby_name%=no"
if /I "%gcby_value%"=="false" set "%gcby_name%=no"
if /I "%gcby_value%"=="0" set "%gcby_name%=no"
call set "gcby_value=%%%gcby_name%%%"
if /I "%gcby_value%"=="yes" (set "_gcby_rc=0" & goto :NormalizeYesNo)
if /I "%gcby_value%"=="no" (set "_gcby_rc=0" & goto :NormalizeYesNo)
set "_gcby_rc=1" & goto :NormalizeYesNo
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
echo git_create_branch.bat
echo.
echo Usage:
echo   git_create_branch.bat feature/my-change
echo   git_create_branch.bat name feature/my-change start main
echo   git_create_branch.bat name feature/my-change push yes
echo   git_create_branch.bat name feature/my-change allowdirty yes
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
