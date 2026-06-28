@echo off
:: ============================================================
:: git_merge_branch.bat
:: Safely merges an existing branch or revision into the current
:: named branch after a clean-tree check and typed confirmation.
::
:: Usage:
::   call tools\git_merge_branch.bat
::   call tools\git_merge_branch.bat branch feature/test
::   call tools\git_merge_branch.bat branch feature/test mode ff-only
::   call tools\git_merge_branch.bat branch feature/test mode merge fetch no
::
:: Returns: 0 on success, cancellation, no-op, or help
::          1 on preparation, repository, fetch, revision, or merge failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeMode, :NormalizeYesNo, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_merge_branch.branch="
set "app.git_merge_branch.ref="
set "app.git_merge_branch.mode=ff-only"
set "app.git_merge_branch.fetch=yes"
set "app.git_merge_branch.current="
set "app.git_merge_branch.dirty="
set "app.git_merge_branch.currentonly=0"
set "app.git_merge_branch.sourceonly=0"
set "app.git_merge_branch.confirm="
set "app.git_merge_branch.help="
set "app.git_merge_branch.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_merge_branch.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_merge_branch.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_merge_branch.rc%
:: ============================================================
:: :Main
:: Validates the repository and merge source, previews the change,
:: enforces fast-forward policy when selected, and performs the merge.
::
:: Usage: call :Main [branch REV] [mode ff-only|merge] [fetch yes|no]
::
:: Returns: 0 on success, cancellation, no-op, or help
::          1 on preparation, repository, fetch, revision, or merge failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeMode, :NormalizeYesNo, :ShowHelp,
::           prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gmbm_ 2^>nul') do set "%%v="
if defined _gmbm_rc (set "_gmbm_rc=" & exit /b %_gmbm_rc%)
call :ParseArgs %*
set "_gmbm_rc=%errorlevel%"
if not "%_gmbm_rc%"=="0" goto :Main
if defined app.git_merge_branch.help goto :_Main_help
call :NormalizeMode
if errorlevel 1 (set "_gmbm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_merge_branch.fetch
if errorlevel 1 (echo ERROR: fetch must be yes or no. & set "_gmbm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Merge branch
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gmbm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gmbm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gmbm_rc=1" & goto :Main)
set "app.git_merge_branch.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_merge_branch.dirty=1"
if defined app.git_merge_branch.dirty goto :_Main_dirty
set "app.git_merge_branch.current="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_merge_branch.current=%%A"
if not defined app.git_merge_branch.current (echo ERROR: A named branch is not checked out. & set "_gmbm_rc=1" & goto :Main)
if not defined app.git_merge_branch.branch set /p "app.git_merge_branch.branch=Branch or revision to merge into %app.git_merge_branch.current%: "
if not defined app.git_merge_branch.branch (echo ERROR: A source branch or revision is required. & set "_gmbm_rc=1" & goto :Main)
if /I "%app.git_merge_branch.fetch%"=="yes" goto :_Main_fetch
goto :_Main_resolve
:_Main_fetch
echo Fetching remote branch information...
git fetch --all --prune --quiet
if errorlevel 1 (echo ERROR: One or more remotes could not be fetched. & set "_gmbm_rc=1" & goto :Main)
:_Main_resolve
set "app.git_merge_branch.ref="
git show-ref --verify --quiet "refs/heads/%app.git_merge_branch.branch%"
if not errorlevel 1 set "app.git_merge_branch.ref=%app.git_merge_branch.branch%"
if defined app.git_merge_branch.ref goto :_Main_source_ready
git show-ref --verify --quiet "refs/remotes/origin/%app.git_merge_branch.branch%"
if not errorlevel 1 set "app.git_merge_branch.ref=origin/%app.git_merge_branch.branch%"
if defined app.git_merge_branch.ref goto :_Main_source_ready
git rev-parse --verify "%app.git_merge_branch.branch%^^{commit}" >nul 2>nul
if not errorlevel 1 set "app.git_merge_branch.ref=%app.git_merge_branch.branch%"
if not defined app.git_merge_branch.ref (echo ERROR: Source branch or revision was not found: & echo   %app.git_merge_branch.branch% & set "_gmbm_rc=1" & goto :Main)
:_Main_source_ready
set "app.git_merge_branch.currentonly="
set "app.git_merge_branch.sourceonly="
for /f "tokens=1,2" %%A in ('git rev-list --left-right --count "HEAD...%app.git_merge_branch.ref%" 2^>nul') do (
set "app.git_merge_branch.currentonly=%%A"
set "app.git_merge_branch.sourceonly=%%B"
)
if not defined app.git_merge_branch.currentonly (echo ERROR: Could not compare the selected revisions. & set "_gmbm_rc=1" & goto :Main)
if not defined app.git_merge_branch.sourceonly (echo ERROR: Could not compare the selected revisions. & set "_gmbm_rc=1" & goto :Main)
echo.
echo Current branch:
echo   %app.git_merge_branch.current%
echo.
echo Merge from:
echo   %app.git_merge_branch.ref%
echo.
echo Mode:
echo   %app.git_merge_branch.mode%
echo.
echo Commits only on current branch:
echo   %app.git_merge_branch.currentonly%
echo.
echo Commits only on source:
echo   %app.git_merge_branch.sourceonly%
echo.
if "%app.git_merge_branch.sourceonly%"=="0" goto :_Main_noop
echo Source commits:
echo.
git log --oneline --decorate "HEAD..%app.git_merge_branch.ref%"
if errorlevel 1 (echo ERROR: Could not display source commits. & set "_gmbm_rc=1" & goto :Main)
echo.
echo Changed files from the merge base:
echo.
git diff --stat "HEAD...%app.git_merge_branch.ref%"
if errorlevel 1 (echo ERROR: Could not display the merge diff. & set "_gmbm_rc=1" & goto :Main)
echo.
if "%app.git_merge_branch.mode%"=="ff-only" if not "%app.git_merge_branch.currentonly%"=="0" goto :_Main_not_ff
set /p "app.git_merge_branch.confirm=Type MERGE to continue: "
if "%app.git_merge_branch.confirm%"=="MERGE" goto :_Main_merge
echo.
echo Cancelled. Nothing was changed.
set "_gmbm_rc=0" & goto :Main
:_Main_merge
if "%app.git_merge_branch.mode%"=="merge" goto :_Main_merge_normal
git merge --ff-only "%app.git_merge_branch.ref%"
set "_gmbm_rc=%errorlevel%"
goto :_Main_merge_result
:_Main_merge_normal
git merge --no-edit "%app.git_merge_branch.ref%"
set "_gmbm_rc=%errorlevel%"
:_Main_merge_result
if "%_gmbm_rc%"=="0" goto :_Main_success
echo.
echo ERROR: Merge did not complete.
echo.
echo Resolve conflicted files, stage them, and run:
echo   tools\git_continue_operation.bat
echo.
echo To cancel the merge, run:
echo   tools\git_abort_operation.bat
set "_gmbm_rc=1" & goto :Main
:_Main_success
echo.
echo Merge completed successfully.
git status --short --branch
echo.
set "_gmbm_rc=0" & goto :Main
:_Main_dirty
echo ERROR: The working tree has local changes.
echo Commit or stash them before merging.
echo.
git status --short
set "_gmbm_rc=1" & goto :Main
:_Main_noop
echo The current branch already contains the selected source.
set "_gmbm_rc=0" & goto :Main
:_Main_not_ff
echo ERROR: A fast-forward merge is not possible because both sides
echo contain unique commits.
echo.
echo Review the comparison and use mode merge only when a merge
echo commit is intentional.
set "_gmbm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gmbm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses merge source, mode, fetch, and help arguments.
::
:: Usage: call :ParseArgs [branch REV] [mode ff-only|merge] [fetch yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="branch" goto :_ParseArgs_branch
if /I "%~1"=="source" goto :_ParseArgs_branch
if /I "%~1"=="mode" goto :_ParseArgs_mode
if /I "%~1"=="fetch" goto :_ParseArgs_fetch
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_merge_branch.branch (set "app.git_merge_branch.branch=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_branch
if "%~2"=="" (echo ERROR: branch requires a name or revision. & exit /b 2)
set "app.git_merge_branch.branch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_mode
if "%~2"=="" (echo ERROR: mode requires ff-only or merge. & exit /b 2)
set "app.git_merge_branch.mode=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_fetch
if "%~2"=="" (echo ERROR: fetch requires yes or no. & exit /b 2)
set "app.git_merge_branch.fetch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_merge_branch.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeMode
:: Normalizes and validates the selected merge mode.
::
:: Usage: call :NormalizeMode
::
:: Returns: 0 for ff-only or merge
::          1 otherwise
:: Requires: none
:: ============================================================
:NormalizeMode
if /I "%app.git_merge_branch.mode%"=="ff-only" set "app.git_merge_branch.mode=ff-only"
if /I "%app.git_merge_branch.mode%"=="merge" set "app.git_merge_branch.mode=merge"
if "%app.git_merge_branch.mode%"=="ff-only" exit /b 0
if "%app.git_merge_branch.mode%"=="merge" exit /b 0
echo ERROR: mode must be ff-only or merge.
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
for /f "tokens=1 delims==" %%v in ('set gmby_ 2^>nul') do set "%%v="
if defined _gmby_rc (set "_gmby_rc=" & exit /b %_gmby_rc%)
set "gmby_name=%~1"
call set "gmby_value=%%%gmby_name%%%"
if /I "%gmby_value%"=="y" set "%gmby_name%=yes"
if /I "%gmby_value%"=="yes" set "%gmby_name%=yes"
if /I "%gmby_value%"=="true" set "%gmby_name%=yes"
if /I "%gmby_value%"=="1" set "%gmby_name%=yes"
if /I "%gmby_value%"=="n" set "%gmby_name%=no"
if /I "%gmby_value%"=="no" set "%gmby_name%=no"
if /I "%gmby_value%"=="false" set "%gmby_name%=no"
if /I "%gmby_value%"=="0" set "%gmby_name%=no"
call set "gmby_value=%%%gmby_name%%%"
if /I "%gmby_value%"=="yes" (set "_gmby_rc=0" & goto :NormalizeYesNo)
if /I "%gmby_value%"=="no" (set "_gmby_rc=0" & goto :NormalizeYesNo)
set "_gmby_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays merge modes, source resolution, and fetch behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_merge_branch.bat
echo.
echo Usage:
echo   git_merge_branch.bat branch feature/test
echo   git_merge_branch.bat branch feature/test mode ff-only
echo   git_merge_branch.bat branch feature/test mode merge fetch no
echo.
echo ff-only refuses divergent history. merge permits a merge commit.
echo A clean working tree and MERGE confirmation are required.
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
