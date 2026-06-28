@echo off
:: ============================================================
:: git_worktree_manage.bat
:: Lists, adds, removes, or prunes Git worktrees with explicit
:: validation and confirmation for every mutating action.
::
:: Usage:
::   call tools\git_worktree_manage.bat list
::   call tools\git_worktree_manage.bat add folder ..\feature branch feature/test
::   call tools\git_worktree_manage.bat add folder ..\new branch feature/new create yes
::   call tools\git_worktree_manage.bat add folder ..\inspect start origin/main detach yes
::   call tools\git_worktree_manage.bat remove folder ..\feature
::   call tools\git_worktree_manage.bat remove folder ..\feature force yes
::   call tools\git_worktree_manage.bat prune
::   call tools\git_worktree_manage.bat prune apply yes
::
:: Returns: 0 on successful action, preview, cancellation, or help
::          1 on preparation, repository, path, worktree, status, or Git failure
::          2 on invalid arguments or incompatible options
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeAction, :NormalizeYesNo, :FindRegisteredWorktree,
::           :CompareWorktreePath, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_worktree_manage.action=list"
set "app.git_worktree_manage.folder="
set "app.git_worktree_manage.folder.full="
set "app.git_worktree_manage.branch="
set "app.git_worktree_manage.start=HEAD"
set "app.git_worktree_manage.create=no"
set "app.git_worktree_manage.detach=no"
set "app.git_worktree_manage.force=no"
set "app.git_worktree_manage.apply=no"
set "app.git_worktree_manage.dirty="
set "app.git_worktree_manage.registered="
set "app.git_worktree_manage.candidate="
set "app.git_worktree_manage.current.root="
set "app.git_worktree_manage.current.root.full="
set "app.git_worktree_manage.confirm="
set "app.git_worktree_manage.help="
set "app.git_worktree_manage.rc=0"
call "%~dp0_common.bat" init
set "app.git_worktree_manage.rc=%errorlevel%"
if "%app.git_worktree_manage.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_worktree_manage.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_worktree_manage.rc%
:: ============================================================
:: :Main
:: Validates action options and repository state, then safely lists,
:: adds, removes, or previews/applies worktree pruning.
::
:: Usage: call :Main list|add|remove|prune [arguments]
::
:: Returns: 0 on successful action, preview, cancellation, or help
::          1 on preparation, repository, path, worktree, status, or Git failure
::          2 on invalid arguments or incompatible options
:: Requires: :ParseArgs, :NormalizeAction, :NormalizeYesNo,
::           :FindRegisteredWorktree, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gwmm_ 2^>nul') do set "%%v="
if defined _gwmm_rc (set "_gwmm_rc=" & exit /b %_gwmm_rc%)
call :ParseArgs %*
set "_gwmm_rc=%errorlevel%"
if not "%_gwmm_rc%"=="0" goto :Main
if defined app.git_worktree_manage.help goto :_Main_help
call :NormalizeAction
if errorlevel 1 (set "_gwmm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_worktree_manage.create
if errorlevel 1 (echo ERROR: create must be yes or no. & set "_gwmm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_worktree_manage.detach
if errorlevel 1 (echo ERROR: detach must be yes or no. & set "_gwmm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_worktree_manage.force
if errorlevel 1 (echo ERROR: force must be yes or no. & set "_gwmm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_worktree_manage.apply
if errorlevel 1 (echo ERROR: apply must be yes or no. & set "_gwmm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Manage Git worktrees
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gwmm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gwmm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gwmm_rc=1" & goto :Main)
if "%app.git_worktree_manage.action%"=="list" goto :_Main_list
if "%app.git_worktree_manage.action%"=="add" goto :_Main_add
if "%app.git_worktree_manage.action%"=="remove" goto :_Main_remove
if "%app.git_worktree_manage.action%"=="prune" goto :_Main_prune
echo ERROR: Unsupported action.
set "_gwmm_rc=2" & goto :Main
:_Main_list
git worktree list --porcelain
set "_gwmm_rc=%errorlevel%"
if "%_gwmm_rc%"=="0" goto :Main
echo ERROR: Git could not list worktrees.
set "_gwmm_rc=1" & goto :Main
:_Main_add
if not defined app.git_worktree_manage.folder set /p "app.git_worktree_manage.folder=New worktree folder: "
if not defined app.git_worktree_manage.folder (echo ERROR: A worktree folder is required. & set "_gwmm_rc=1" & goto :Main)
for %%A in ("%app.git_worktree_manage.folder%") do set "app.git_worktree_manage.folder.full=%%~fA"
call :FindRegisteredWorktree
set "_gwmm_find_rc=%errorlevel%"
if "%_gwmm_find_rc%"=="0" (echo ERROR: Target folder is already a registered worktree: & echo   %app.git_worktree_manage.folder.full% & set "_gwmm_rc=1" & goto :Main)
if "%_gwmm_find_rc%"=="2" (echo ERROR: Registered worktrees could not be inspected. & set "_gwmm_rc=1" & goto :Main)
if not exist "%app.git_worktree_manage.folder.full%\" goto :_Main_add_options
dir /b "%app.git_worktree_manage.folder.full%" 2>nul | "%SystemRoot%\System32\findstr.exe" . >nul
if errorlevel 1 goto :_Main_add_options
echo ERROR: Target folder exists and is not empty:
echo   %app.git_worktree_manage.folder.full%
set "_gwmm_rc=1" & goto :Main
:_Main_add_options
if /I "%app.git_worktree_manage.detach%"=="yes" if defined app.git_worktree_manage.branch (echo ERROR: branch cannot be combined with detach yes. & set "_gwmm_rc=2" & goto :Main)
if /I "%app.git_worktree_manage.create%"=="yes" if /I "%app.git_worktree_manage.detach%"=="yes" (echo ERROR: create yes cannot be combined with detach yes. & set "_gwmm_rc=2" & goto :Main)
if /I "%app.git_worktree_manage.create%"=="yes" if not defined app.git_worktree_manage.branch (echo ERROR: create yes requires branch. & set "_gwmm_rc=2" & goto :Main)
if /I "%app.git_worktree_manage.create%"=="no" if /I "%app.git_worktree_manage.detach%"=="no" if not defined app.git_worktree_manage.branch (echo ERROR: add requires an existing branch, create yes, or detach yes. & set "_gwmm_rc=2" & goto :Main)
if not defined app.git_worktree_manage.branch goto :_Main_add_start
git check-ref-format --branch "%app.git_worktree_manage.branch%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid branch name: & echo   %app.git_worktree_manage.branch% & set "_gwmm_rc=2" & goto :Main)
if /I "%app.git_worktree_manage.create%"=="yes" goto :_Main_add_create_check
git show-ref --verify --quiet "refs/heads/%app.git_worktree_manage.branch%"
if not errorlevel 1 goto :_Main_add_start
echo ERROR: Existing local branch was not found:
echo   %app.git_worktree_manage.branch%
echo.
echo To create it, use create yes and select a starting revision.
set "_gwmm_rc=1" & goto :Main
:_Main_add_create_check
git show-ref --verify --quiet "refs/heads/%app.git_worktree_manage.branch%"
if errorlevel 1 goto :_Main_add_start
echo ERROR: Local branch already exists:
echo   %app.git_worktree_manage.branch%
echo.
echo Omit create yes to add an existing branch.
set "_gwmm_rc=1" & goto :Main
:_Main_add_start
if /I "%app.git_worktree_manage.create%"=="yes" goto :_Main_validate_start
if /I "%app.git_worktree_manage.detach%"=="yes" goto :_Main_validate_start
if /I not "%app.git_worktree_manage.start%"=="HEAD" (echo ERROR: start applies only with create yes or detach yes. & set "_gwmm_rc=2" & goto :Main)
goto :_Main_add_plan
:_Main_validate_start
git rev-parse --verify "%app.git_worktree_manage.start%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Starting revision was not found: & echo   %app.git_worktree_manage.start% & set "_gwmm_rc=1" & goto :Main)
:_Main_add_plan
echo Action:
echo   add
echo.
echo Folder:
echo   %app.git_worktree_manage.folder.full%
echo.
if not defined app.git_worktree_manage.branch goto :_Main_add_branch_done
echo Branch:
echo   %app.git_worktree_manage.branch%
echo.
:_Main_add_branch_done
if /I "%app.git_worktree_manage.create%"=="yes" goto :_Main_add_show_start
if /I "%app.git_worktree_manage.detach%"=="yes" goto :_Main_add_show_start
goto :_Main_add_show_flags
:_Main_add_show_start
echo Starting revision:
echo   %app.git_worktree_manage.start%
echo.
:_Main_add_show_flags
echo Create branch:
echo   %app.git_worktree_manage.create%
echo.
echo Detached:
echo   %app.git_worktree_manage.detach%
echo.
set /p "app.git_worktree_manage.confirm=Type ADD to continue: "
if "%app.git_worktree_manage.confirm%"=="ADD" goto :_Main_add_apply
echo.
echo Cancelled. Nothing was changed.
set "_gwmm_rc=0" & goto :Main
:_Main_add_apply
if /I "%app.git_worktree_manage.detach%"=="yes" goto :_Main_add_detached
if /I "%app.git_worktree_manage.create%"=="yes" goto :_Main_add_create
git worktree add "%app.git_worktree_manage.folder.full%" "%app.git_worktree_manage.branch%"
set "_gwmm_rc=%errorlevel%"
goto :_Main_add_result
:_Main_add_create
git worktree add -b "%app.git_worktree_manage.branch%" "%app.git_worktree_manage.folder.full%" "%app.git_worktree_manage.start%"
set "_gwmm_rc=%errorlevel%"
goto :_Main_add_result
:_Main_add_detached
git worktree add --detach "%app.git_worktree_manage.folder.full%" "%app.git_worktree_manage.start%"
set "_gwmm_rc=%errorlevel%"
:_Main_add_result
if "%_gwmm_rc%"=="0" goto :_Main_add_success
echo ERROR: Worktree creation failed.
set "_gwmm_rc=1" & goto :Main
:_Main_add_success
echo.
echo Worktree created successfully.
git worktree list
set "_gwmm_list_rc=%errorlevel%"
if not "%_gwmm_list_rc%"=="0" echo WARNING: The worktree was created, but the updated list could not be displayed.
set "_gwmm_rc=0" & goto :Main
:_Main_remove
if not defined app.git_worktree_manage.folder set /p "app.git_worktree_manage.folder=Worktree folder to remove: "
if not defined app.git_worktree_manage.folder (echo ERROR: A worktree folder is required. & set "_gwmm_rc=1" & goto :Main)
for %%A in ("%app.git_worktree_manage.folder%") do set "app.git_worktree_manage.folder.full=%%~fA"
call :FindRegisteredWorktree
set "_gwmm_find_rc=%errorlevel%"
if "%_gwmm_find_rc%"=="0" goto :_Main_remove_current
if "%_gwmm_find_rc%"=="2" (echo ERROR: Registered worktrees could not be inspected. & set "_gwmm_rc=1" & goto :Main)
echo ERROR: Folder is not a registered worktree:
echo   %app.git_worktree_manage.folder.full%
set "_gwmm_rc=1" & goto :Main
:_Main_remove_current
set "app.git_worktree_manage.current.root="
set "app.git_worktree_manage.current.root.full="
for /f "delims=" %%A in ('git rev-parse --show-toplevel 2^>nul') do set "app.git_worktree_manage.current.root=%%A"
if not defined app.git_worktree_manage.current.root goto :_Main_remove_status
for %%A in ("%app.git_worktree_manage.current.root%") do set "app.git_worktree_manage.current.root.full=%%~fA"
if /I not "%app.git_worktree_manage.folder.full%"=="%app.git_worktree_manage.current.root.full%" goto :_Main_remove_status
echo ERROR: The currently active worktree cannot remove itself:
echo   %app.git_worktree_manage.folder.full%
echo.
echo Run this helper from another worktree.
set "_gwmm_rc=1" & goto :Main
:_Main_remove_status
set "app.git_worktree_manage.dirty="
if not exist "%app.git_worktree_manage.folder.full%\" goto :_Main_remove_plan
git -C "%app.git_worktree_manage.folder.full%" status --porcelain >nul 2>nul
if not errorlevel 1 goto :_Main_remove_detect_dirty
if /I "%app.git_worktree_manage.force%"=="yes" goto :_Main_remove_status_warning
echo ERROR: The target worktree status could not be inspected:
echo   %app.git_worktree_manage.folder.full%
echo.
echo Use force yes only after independently confirming the path.
set "_gwmm_rc=1" & goto :Main
:_Main_remove_status_warning
echo WARNING: The target worktree status could not be inspected.
echo force yes will ask Git to remove it anyway.
echo.
goto :_Main_remove_plan
:_Main_remove_detect_dirty
for /f "delims=" %%A in ('git -C "%app.git_worktree_manage.folder.full%" status --porcelain 2^>nul') do set "app.git_worktree_manage.dirty=1"
if not defined app.git_worktree_manage.dirty goto :_Main_remove_plan
if /I "%app.git_worktree_manage.force%"=="yes" goto :_Main_remove_plan
echo ERROR: Worktree has local changes:
echo   %app.git_worktree_manage.folder.full%
echo.
git -C "%app.git_worktree_manage.folder.full%" status --short
echo.
echo Commit or stash those changes first.
echo To remove anyway, use force yes.
set "_gwmm_rc=1" & goto :Main
:_Main_remove_plan
echo Action:
echo   remove
echo.
echo Folder:
echo   %app.git_worktree_manage.folder.full%
echo.
echo Force:
echo   %app.git_worktree_manage.force%
echo.
if not defined app.git_worktree_manage.dirty goto :_Main_remove_confirm
echo WARNING: Local changes in this worktree may be discarded.
echo.
:_Main_remove_confirm
set /p "app.git_worktree_manage.confirm=Type REMOVE to continue: "
if "%app.git_worktree_manage.confirm%"=="REMOVE" goto :_Main_remove_apply
echo.
echo Cancelled. Nothing was removed.
set "_gwmm_rc=0" & goto :Main
:_Main_remove_apply
if /I "%app.git_worktree_manage.force%"=="yes" goto :_Main_remove_force
git worktree remove "%app.git_worktree_manage.folder.full%"
set "_gwmm_rc=%errorlevel%"
goto :_Main_remove_result
:_Main_remove_force
git worktree remove --force "%app.git_worktree_manage.folder.full%"
set "_gwmm_rc=%errorlevel%"
:_Main_remove_result
if "%_gwmm_rc%"=="0" goto :_Main_remove_success
echo ERROR: Worktree removal failed.
set "_gwmm_rc=1" & goto :Main
:_Main_remove_success
echo.
echo Worktree removed successfully.
git worktree list
set "_gwmm_list_rc=%errorlevel%"
if not "%_gwmm_list_rc%"=="0" echo WARNING: The worktree was removed, but the updated list could not be displayed.
set "_gwmm_rc=0" & goto :Main
:_Main_prune
echo Stale worktree records that could be pruned:
echo.
git worktree prune --dry-run --verbose
set "_gwmm_rc=%errorlevel%"
if "%_gwmm_rc%"=="0" goto :_Main_prune_choice
echo ERROR: Worktree prune preview failed.
set "_gwmm_rc=1" & goto :Main
:_Main_prune_choice
echo.
if /I "%app.git_worktree_manage.apply%"=="yes" goto :_Main_prune_confirm
echo Preview only. Nothing was pruned.
echo To apply:
echo   git_worktree_manage.bat prune apply yes
set "_gwmm_rc=0" & goto :Main
:_Main_prune_confirm
set /p "app.git_worktree_manage.confirm=Type PRUNE to continue: "
if "%app.git_worktree_manage.confirm%"=="PRUNE" goto :_Main_prune_apply
echo.
echo Cancelled. Nothing was pruned.
set "_gwmm_rc=0" & goto :Main
:_Main_prune_apply
git worktree prune --verbose
set "_gwmm_rc=%errorlevel%"
if "%_gwmm_rc%"=="0" goto :_Main_prune_success
echo ERROR: Worktree prune failed.
set "_gwmm_rc=1" & goto :Main
:_Main_prune_success
echo.
echo Stale worktree records pruned successfully.
set "_gwmm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_gwmm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :FindRegisteredWorktree
:: Compares the selected absolute path with every porcelain worktree
:: path after normalizing each path through cmd.exe.
::
:: Usage: call :FindRegisteredWorktree
::
:: Returns: 0 when the selected path is registered
::          1 when it is not registered
::          2 when the worktree list cannot be read
:: Requires: :CompareWorktreePath, git
:: ============================================================
:FindRegisteredWorktree
for /f "tokens=1 delims==" %%v in ('set gwmf_ 2^>nul') do set "%%v="
if defined _gwmf_rc (set "_gwmf_rc=" & exit /b %_gwmf_rc%)
set "app.git_worktree_manage.registered="
set "app.git_worktree_manage.candidate="
git worktree list --porcelain >nul 2>nul
if errorlevel 1 (set "_gwmf_rc=2" & goto :FindRegisteredWorktree)
for /f "tokens=1,*" %%A in ('git worktree list --porcelain 2^>nul') do if /I "%%A"=="worktree" (
set "app.git_worktree_manage.candidate=%%B"
call :CompareWorktreePath
)
if defined app.git_worktree_manage.registered (set "_gwmf_rc=0" & goto :FindRegisteredWorktree)
set "_gwmf_rc=1" & goto :FindRegisteredWorktree
:: ============================================================
:: :CompareWorktreePath
:: Normalizes the current porcelain candidate and compares it with
:: app.git_worktree_manage.folder.full.
::
:: Usage: call :CompareWorktreePath
::
:: Returns: 0
:: Requires: app.git_worktree_manage.candidate
:: ============================================================
:CompareWorktreePath
for /f "tokens=1 delims==" %%v in ('set gwmc_ 2^>nul') do set "%%v="
if defined _gwmc_rc (set "_gwmc_rc=" & exit /b %_gwmc_rc%)
set "gwmc_full="
for %%A in ("%app.git_worktree_manage.candidate%") do set "gwmc_full=%%~fA"
if /I "%gwmc_full%"=="%app.git_worktree_manage.folder.full%" set "app.git_worktree_manage.registered=1"
set "_gwmc_rc=0" & goto :CompareWorktreePath
:: ============================================================
:: :NormalizeAction
:: Normalizes and validates list, add, remove, or prune.
::
:: Usage: call :NormalizeAction
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:NormalizeAction
if /I "%app.git_worktree_manage.action%"=="list" set "app.git_worktree_manage.action=list"
if /I "%app.git_worktree_manage.action%"=="add" set "app.git_worktree_manage.action=add"
if /I "%app.git_worktree_manage.action%"=="remove" set "app.git_worktree_manage.action=remove"
if /I "%app.git_worktree_manage.action%"=="prune" set "app.git_worktree_manage.action=prune"
if "%app.git_worktree_manage.action%"=="list" exit /b 0
if "%app.git_worktree_manage.action%"=="add" exit /b 0
if "%app.git_worktree_manage.action%"=="remove" exit /b 0
if "%app.git_worktree_manage.action%"=="prune" exit /b 0
echo ERROR: action must be list, add, remove, or prune.
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
for /f "tokens=1 delims==" %%v in ('set gwmy_ 2^>nul') do set "%%v="
if defined _gwmy_rc (set "_gwmy_rc=" & exit /b %_gwmy_rc%)
set "gwmy_name=%~1"
call set "gwmy_value=%%%gwmy_name%%%"
if /I "%gwmy_value%"=="y" set "%gwmy_name%=yes"
if /I "%gwmy_value%"=="yes" set "%gwmy_name%=yes"
if /I "%gwmy_value%"=="true" set "%gwmy_name%=yes"
if /I "%gwmy_value%"=="1" set "%gwmy_name%=yes"
if /I "%gwmy_value%"=="n" set "%gwmy_name%=no"
if /I "%gwmy_value%"=="no" set "%gwmy_name%=no"
if /I "%gwmy_value%"=="false" set "%gwmy_name%=no"
if /I "%gwmy_value%"=="0" set "%gwmy_name%=no"
call set "gwmy_value=%%%gwmy_name%%%"
if /I "%gwmy_value%"=="yes" (set "_gwmy_rc=0" & goto :NormalizeYesNo)
if /I "%gwmy_value%"=="no" (set "_gwmy_rc=0" & goto :NormalizeYesNo)
set "_gwmy_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ParseArgs
:: Parses worktree action and action-specific options.
::
:: Usage: call :ParseArgs list|add|remove|prune [arguments]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="list" goto :_ParseArgs_action_first
if /I "%~1"=="add" goto :_ParseArgs_action_first
if /I "%~1"=="remove" goto :_ParseArgs_action_first
if /I "%~1"=="prune" goto :_ParseArgs_action_first
if /I "%~1"=="action" goto :_ParseArgs_action
if /I "%~1"=="folder" goto :_ParseArgs_folder
if /I "%~1"=="branch" goto :_ParseArgs_branch
if /I "%~1"=="start" goto :_ParseArgs_start
if /I "%~1"=="create" goto :_ParseArgs_create
if /I "%~1"=="detach" goto :_ParseArgs_detach
if /I "%~1"=="force" goto :_ParseArgs_force
if /I "%~1"=="apply" goto :_ParseArgs_apply
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_action_first
set "app.git_worktree_manage.action=%~1"
shift
goto :ParseArgs
:_ParseArgs_action
if "%~2"=="" (echo ERROR: action requires list, add, remove, or prune. & exit /b 2)
set "app.git_worktree_manage.action=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_folder
if "%~2"=="" (echo ERROR: folder requires a path. & exit /b 2)
set "app.git_worktree_manage.folder=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_branch
if "%~2"=="" (echo ERROR: branch requires a name. & exit /b 2)
set "app.git_worktree_manage.branch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_start
if "%~2"=="" (echo ERROR: start requires a revision. & exit /b 2)
set "app.git_worktree_manage.start=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_create
if "%~2"=="" (echo ERROR: create requires yes or no. & exit /b 2)
set "app.git_worktree_manage.create=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_detach
if "%~2"=="" (echo ERROR: detach requires yes or no. & exit /b 2)
set "app.git_worktree_manage.detach=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_force
if "%~2"=="" (echo ERROR: force requires yes or no. & exit /b 2)
set "app.git_worktree_manage.force=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_apply
if "%~2"=="" (echo ERROR: apply requires yes or no. & exit /b 2)
set "app.git_worktree_manage.apply=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_worktree_manage.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays worktree actions and mutation safeguards.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_worktree_manage.bat
echo.
echo Usage:
echo   git_worktree_manage.bat list
echo   git_worktree_manage.bat add folder ..\feature branch feature/test
echo   git_worktree_manage.bat add folder ..\new branch feature/new create yes
echo   git_worktree_manage.bat add folder ..\inspect start origin/main detach yes
echo   git_worktree_manage.bat remove folder ..\feature
echo   git_worktree_manage.bat remove folder ..\feature force yes
echo   git_worktree_manage.bat prune
echo   git_worktree_manage.bat prune apply yes
echo.
echo add, remove, and applied prune operations require typed confirmation.
echo force yes may discard changes in a removed worktree.
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
