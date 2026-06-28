@echo off
:: ============================================================
:: git_cherry_pick.bat
:: Applies one existing commit onto the current branch.
::
:: Usage:
::   call tools\git_cherry_pick.bat commit abc123
::   call tools\git_cherry_pick.bat commit abc123 mainline 1
::   call tools\git_cherry_pick.bat commit abc123 nocommit yes
::
:: Returns: 0 on success or cancellation
::          1 on repository, safety, selection, or cherry-pick failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ValidatePositiveNumber,
::           :ValidateSelection, :ShowPlan, :ApplyCherryPick,
::           :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_cherry_pick.commit="
set "app.git_cherry_pick.mainline="
set "app.git_cherry_pick.nocommit=no"
set "app.git_cherry_pick.dirty="
set "app.git_cherry_pick.parent2="
set "app.git_cherry_pick.confirm="
set "app.git_cherry_pick.help="
set "app.git_cherry_pick.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_cherry_pick.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_cherry_pick.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_cherry_pick.rc%
:: ============================================================
:: :Main
:: Parses arguments, validates a clean repository and commit
:: selection, previews the operation, confirms it, and applies it.
::
:: Usage: call :Main commit REV [mainline N] [nocommit yes|no]
::
:: Returns: 0 on success or cancellation
::          1 on repository, safety, selection, or cherry-pick failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ValidateSelection,
::           :ShowPlan, :ApplyCherryPick, :ShowHelp, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcpm_ 2^>nul') do set "%%v="
if defined _gcpm_rc (set "_gcpm_rc=" & exit /b %_gcpm_rc%)
call :ParseArgs %*
set "_gcpm_rc=%errorlevel%"
if not "%_gcpm_rc%"=="0" goto :Main
if defined app.git_cherry_pick.help goto :_Main_help
call :NormalizeYesNo app.git_cherry_pick.nocommit
if errorlevel 1 (echo ERROR: nocommit must be yes or no. & set "_gcpm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Cherry-pick commit
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gcpm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gcpm_rc=1" & goto :Main)
set "app.git_cherry_pick.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_cherry_pick.dirty=1"
if defined app.git_cherry_pick.dirty goto :_Main_dirty
if not defined app.git_cherry_pick.commit set /p "app.git_cherry_pick.commit=Commit to cherry-pick: "
call :ValidateSelection
if errorlevel 1 (set "_gcpm_rc=%errorlevel%" & goto :Main)
call :ShowPlan
if errorlevel 1 (set "_gcpm_rc=%errorlevel%" & goto :Main)
set /p "app.git_cherry_pick.confirm=Type CHERRYPICK to continue: "
if "%app.git_cherry_pick.confirm%"=="CHERRYPICK" goto :_Main_apply
echo.
echo Cancelled. Nothing was changed.
set "_gcpm_rc=0" & goto :Main
:_Main_apply
call :ApplyCherryPick
set "_gcpm_rc=%errorlevel%" & goto :Main
:_Main_dirty
echo ERROR: The working tree has local changes.
echo Commit or stash them before cherry-picking.
echo.
git status --short
set "_gcpm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_gcpm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ValidateSelection
:: Validates the selected commit and merge-mainline combination.
::
:: Usage: call :ValidateSelection
::
:: Output:
::   app.git_cherry_pick.parent2  defined when the commit is a merge
::
:: Returns: 0 when valid
::          1 on missing or incompatible selection
::          2 on invalid mainline syntax
:: Requires: :ValidatePositiveNumber, git
:: ============================================================
:ValidateSelection
for /f "tokens=1 delims==" %%v in ('set gcpv_ 2^>nul') do set "%%v="
if defined _gcpv_rc (set "_gcpv_rc=" & exit /b %_gcpv_rc%)
if not defined app.git_cherry_pick.commit (echo ERROR: A commit is required. & set "_gcpv_rc=1" & goto :ValidateSelection)
git rev-parse --verify "%app.git_cherry_pick.commit%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Commit was not found: & echo   %app.git_cherry_pick.commit% & set "_gcpv_rc=1" & goto :ValidateSelection)
set "app.git_cherry_pick.parent2="
for /f "tokens=3" %%A in ('git rev-list --parents -n 1 "%app.git_cherry_pick.commit%" 2^>nul') do set "app.git_cherry_pick.parent2=%%A"
if defined app.git_cherry_pick.mainline call :ValidatePositiveNumber "%app.git_cherry_pick.mainline%" mainline
if errorlevel 1 (set "_gcpv_rc=2" & goto :ValidateSelection)
if defined app.git_cherry_pick.parent2 goto :_ValidateSelection_merge
if defined app.git_cherry_pick.mainline (echo ERROR: mainline is valid only for a merge commit. & set "_gcpv_rc=1" & goto :ValidateSelection)
set "_gcpv_rc=0" & goto :ValidateSelection
:_ValidateSelection_merge
if defined app.git_cherry_pick.mainline (set "_gcpv_rc=0" & goto :ValidateSelection)
echo ERROR: The selected commit is a merge commit.
echo Supply its mainline parent, usually:
echo.
echo   git_cherry_pick.bat commit "%app.git_cherry_pick.commit%" mainline 1
echo.
git show --no-patch --pretty=raw "%app.git_cherry_pick.commit%"
set "_gcpv_rc=1" & goto :ValidateSelection
:: ============================================================
:: :ShowPlan
:: Displays the current branch, selected commit, merge mainline,
:: and automatic-commit mode.
::
:: Usage: call :ShowPlan
::
:: Returns: 0 on success
::          1 when Git cannot display the commit
:: Requires: git
:: ============================================================
:ShowPlan
for /f "tokens=1 delims==" %%v in ('set gcps_ 2^>nul') do set "%%v="
if defined _gcps_rc (set "_gcps_rc=" & exit /b %_gcps_rc%)
echo.
echo Current branch:
git branch --show-current
echo.
echo Commit to apply:
echo.
git show --no-patch --decorate --oneline "%app.git_cherry_pick.commit%"
if errorlevel 1 (echo ERROR: Commit details could not be displayed. & set "_gcps_rc=1" & goto :ShowPlan)
git show --stat --summary "%app.git_cherry_pick.commit%"
if errorlevel 1 (echo ERROR: Commit summary could not be displayed. & set "_gcps_rc=1" & goto :ShowPlan)
echo.
if defined app.git_cherry_pick.mainline echo Merge mainline parent: %app.git_cherry_pick.mainline%
echo Create a commit automatically:
if /I "%app.git_cherry_pick.nocommit%"=="yes" goto :_ShowPlan_no
echo   yes
goto :_ShowPlan_done
:_ShowPlan_no
echo   no
:_ShowPlan_done
echo.
set "_gcps_rc=0" & goto :ShowPlan
:: ============================================================
:: :ApplyCherryPick
:: Runs git cherry-pick with the selected mainline and no-commit
:: options and prints recovery guidance on failure.
::
:: Usage: call :ApplyCherryPick
::
:: Returns: 0 on success
::          1 on cherry-pick failure
:: Requires: git
:: ============================================================
:ApplyCherryPick
for /f "tokens=1 delims==" %%v in ('set gcpa_ 2^>nul') do set "%%v="
if defined _gcpa_rc (set "_gcpa_rc=" & exit /b %_gcpa_rc%)
if defined app.git_cherry_pick.mainline goto :_ApplyCherryPick_merge
if /I "%app.git_cherry_pick.nocommit%"=="yes" goto :_ApplyCherryPick_no_commit
git cherry-pick "%app.git_cherry_pick.commit%"
goto :_ApplyCherryPick_result
:_ApplyCherryPick_no_commit
git cherry-pick --no-commit "%app.git_cherry_pick.commit%"
goto :_ApplyCherryPick_result
:_ApplyCherryPick_merge
if /I "%app.git_cherry_pick.nocommit%"=="yes" goto :_ApplyCherryPick_merge_no_commit
git cherry-pick -m %app.git_cherry_pick.mainline% "%app.git_cherry_pick.commit%"
goto :_ApplyCherryPick_result
:_ApplyCherryPick_merge_no_commit
git cherry-pick --no-commit -m %app.git_cherry_pick.mainline% "%app.git_cherry_pick.commit%"
:_ApplyCherryPick_result
if errorlevel 1 goto :_ApplyCherryPick_failed
echo.
if /I "%app.git_cherry_pick.nocommit%"=="yes" goto :_ApplyCherryPick_applied
echo Cherry-pick completed successfully:
git log -1 --oneline
echo.
set "_gcpa_rc=0" & goto :ApplyCherryPick
:_ApplyCherryPick_applied
echo Changes were applied without creating a commit.
git status --short
echo.
set "_gcpa_rc=0" & goto :ApplyCherryPick
:_ApplyCherryPick_failed
echo.
echo ERROR: Cherry-pick did not complete.
echo.
echo Resolve conflicted files, stage them, and run:
echo   tools\git_continue_operation.bat
echo.
echo To cancel the cherry-pick, run:
echo   tools\git_abort_operation.bat
echo.
set "_gcpa_rc=1" & goto :ApplyCherryPick
:: ============================================================
:: :ValidatePositiveNumber
:: Validates a positive integer argument.
::
:: Usage: call :ValidatePositiveNumber "value" argumentName
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:ValidatePositiveNumber
for /f "tokens=1 delims==" %%v in ('set gcpn_ 2^>nul') do set "%%v="
if defined _gcpn_rc (set "_gcpn_rc=" & exit /b %_gcpn_rc%)
set "gcpn_value=%~1"
set "gcpn_name=%~2"
set "gcpn_invalid="
if not defined gcpn_value (echo ERROR: %gcpn_name% requires a positive number. & set "_gcpn_rc=1" & goto :ValidatePositiveNumber)
for /f "delims=0123456789" %%A in ("%gcpn_value%") do set "gcpn_invalid=%%A"
if defined gcpn_invalid (echo ERROR: %gcpn_name% must be a positive number. & set "_gcpn_rc=1" & goto :ValidatePositiveNumber)
if "%gcpn_value%"=="0" (echo ERROR: %gcpn_name% must be 1 or greater. & set "_gcpn_rc=1" & goto :ValidatePositiveNumber)
set "_gcpn_rc=0" & goto :ValidatePositiveNumber
:: ============================================================
:: :ParseArgs
:: Parses commit, mainline, no-commit, and help arguments.
::
:: Usage: call :ParseArgs [commit REV] [mainline N] [nocommit yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="commit" goto :_ParseArgs_commit
if /I "%~1"=="mainline" goto :_ParseArgs_mainline
if /I "%~1"=="nocommit" goto :_ParseArgs_nocommit
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_cherry_pick.commit (set "app.git_cherry_pick.commit=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_commit
if "%~2"=="" (echo ERROR: commit requires a revision. & exit /b 2)
set "app.git_cherry_pick.commit=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_mainline
if "%~2"=="" (echo ERROR: mainline requires a parent number. & exit /b 2)
set "app.git_cherry_pick.mainline=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_nocommit
if "%~2"=="" (echo ERROR: nocommit requires yes or no. & exit /b 2)
set "app.git_cherry_pick.nocommit=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_cherry_pick.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gcpy_ 2^>nul') do set "%%v="
if defined _gcpy_rc (set "_gcpy_rc=" & exit /b %_gcpy_rc%)
set "gcpy_name=%~1"
call set "gcpy_value=%%%gcpy_name%%%"
if /I "%gcpy_value%"=="y" set "%gcpy_name%=yes"
if /I "%gcpy_value%"=="yes" set "%gcpy_name%=yes"
if /I "%gcpy_value%"=="true" set "%gcpy_name%=yes"
if /I "%gcpy_value%"=="1" set "%gcpy_name%=yes"
if /I "%gcpy_value%"=="n" set "%gcpy_name%=no"
if /I "%gcpy_value%"=="no" set "%gcpy_name%=no"
if /I "%gcpy_value%"=="false" set "%gcpy_name%=no"
if /I "%gcpy_value%"=="0" set "%gcpy_name%=no"
call set "gcpy_value=%%%gcpy_name%%%"
if /I "%gcpy_value%"=="yes" (set "_gcpy_rc=0" & goto :NormalizeYesNo)
if /I "%gcpy_value%"=="no" (set "_gcpy_rc=0" & goto :NormalizeYesNo)
set "_gcpy_rc=1" & goto :NormalizeYesNo
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
echo git_cherry_pick.bat
echo.
echo Usage:
echo   git_cherry_pick.bat commit abc123
echo   git_cherry_pick.bat commit abc123 mainline 1
echo   git_cherry_pick.bat commit abc123 nocommit yes
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
