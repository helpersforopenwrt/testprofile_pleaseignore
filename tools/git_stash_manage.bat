@echo off
:: ============================================================
:: git_stash_manage.bat
:: Lists, inspects, applies, pops, or permanently drops Git stashes.
:: Every worktree-changing or destructive action requires confirmation.
::
:: Usage:
::   call tools\git_stash_manage.bat list
::   call tools\git_stash_manage.bat show stash@{0}
::   call tools\git_stash_manage.bat apply stash@{0}
::   call tools\git_stash_manage.bat pop stash@{0}
::   call tools\git_stash_manage.bat drop stash@{0}
::
:: Returns: 0 on successful action, cancellation, or help
::          1 on preparation, repository, stash, tree, preview, or action failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeAction, :NormalizeYesNo, :ValidateStashRef,
::           :ValidateNonNegativeNumber, :PreviewStash, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_stash_manage.action=list"
set "app.git_stash_manage.ref="
set "app.git_stash_manage.index="
set "app.git_stash_manage.allowdirty=no"
set "app.git_stash_manage.dirty="
set "app.git_stash_manage.confirm="
set "app.git_stash_manage.help="
set "app.git_stash_manage.rc=0"
call "%~dp0_common.bat" init
set "app.git_stash_manage.rc=%errorlevel%"
if "%app.git_stash_manage.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_stash_manage.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_stash_manage.rc%
:: ============================================================
:: :Main
:: Validates the requested stash action and reference, protects dirty
:: worktrees by default, previews mutations, confirms, and applies them.
::
:: Usage: call :Main list|show|apply|pop|drop [stash@{N}]
::        [allowdirty yes|no]
::
:: Returns: 0 on successful action, cancellation, or help
::          1 on preparation, repository, stash, tree, preview, or action failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeAction, :NormalizeYesNo,
::           :ValidateStashRef, :PreviewStash, :ShowHelp,
::           prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gsmm_ 2^>nul') do set "%%v="
if defined _gsmm_rc (set "_gsmm_rc=" & exit /b %_gsmm_rc%)
call :ParseArgs %*
set "_gsmm_rc=%errorlevel%"
if not "%_gsmm_rc%"=="0" goto :Main
if defined app.git_stash_manage.help goto :_Main_help
call :NormalizeAction
if errorlevel 1 (set "_gsmm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_stash_manage.allowdirty
if errorlevel 1 (echo ERROR: allowdirty must be yes or no. & set "_gsmm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Manage Git stashes
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gsmm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gsmm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gsmm_rc=1" & goto :Main)
if "%app.git_stash_manage.action%"=="list" goto :_Main_list
if not defined app.git_stash_manage.ref set "app.git_stash_manage.ref=stash@{0}"
call :ValidateStashRef
if errorlevel 1 (set "_gsmm_rc=1" & goto :Main)
if "%app.git_stash_manage.action%"=="show" goto :_Main_show
if "%app.git_stash_manage.action%"=="drop" goto :_Main_drop
git status --porcelain >nul 2>nul
if errorlevel 1 (echo ERROR: Git status failed. & set "_gsmm_rc=1" & goto :Main)
set "app.git_stash_manage.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_stash_manage.dirty=1"
if not defined app.git_stash_manage.dirty goto :_Main_apply_plan
if /I "%app.git_stash_manage.allowdirty%"=="yes" goto :_Main_dirty_allowed
echo ERROR: The working tree has local changes.
echo Applying another stash could combine with or conflict with them.
echo.
git status --short
echo.
echo Commit or stash the current changes first.
echo To deliberately continue, add:
echo   allowdirty yes
set "_gsmm_rc=1" & goto :Main
:_Main_dirty_allowed
echo.
echo WARNING: Existing local changes may combine with the stash.
git status --short
echo.
:_Main_apply_plan
call :PreviewStash
if errorlevel 1 (set "_gsmm_rc=1" & goto :Main)
if "%app.git_stash_manage.action%"=="apply" goto :_Main_confirm_apply
goto :_Main_confirm_pop
:_Main_confirm_apply
echo Applying keeps the selected stash in the stash list.
echo The working tree may receive conflicts.
echo.
set /p "app.git_stash_manage.confirm=Type APPLY to continue: "
if "%app.git_stash_manage.confirm%"=="APPLY" goto :_Main_apply
echo.
echo Cancelled. Nothing was changed.
set "_gsmm_rc=0" & goto :Main
:_Main_apply
git stash apply "%app.git_stash_manage.ref%"
set "_gsmm_rc=%errorlevel%"
if "%_gsmm_rc%"=="0" goto :_Main_apply_success
echo.
echo ERROR: Stash apply did not complete cleanly.
echo The stash remains available, but the working tree may contain
echo partially applied files or conflicts. Inspect:
echo   git status
echo   git stash list
set "_gsmm_rc=1" & goto :Main
:_Main_apply_success
echo.
echo Stash applied successfully and retained:
echo   %app.git_stash_manage.ref%
goto :_Main_operation_success
:_Main_confirm_pop
echo Popping removes the stash only after a clean application.
echo The working tree may receive conflicts.
echo.
set /p "app.git_stash_manage.confirm=Type POP to continue: "
if "%app.git_stash_manage.confirm%"=="POP" goto :_Main_pop
echo.
echo Cancelled. Nothing was changed.
set "_gsmm_rc=0" & goto :Main
:_Main_pop
git stash pop "%app.git_stash_manage.ref%"
set "_gsmm_rc=%errorlevel%"
if "%_gsmm_rc%"=="0" goto :_Main_pop_success
echo.
echo ERROR: Stash pop did not complete cleanly.
echo The working tree may contain partially applied files or conflicts.
echo Git normally retains the stash after a failed pop, but verify:
echo   git status
echo   git stash list
set "_gsmm_rc=1" & goto :Main
:_Main_pop_success
echo.
echo Stash popped successfully:
echo   %app.git_stash_manage.ref%
goto :_Main_operation_success
:_Main_drop
call :PreviewStash
if errorlevel 1 (set "_gsmm_rc=1" & goto :Main)
echo WARNING: Dropping a stash permanently removes its normal reference.
echo Recovery is difficult and is not guaranteed.
echo.
set /p "app.git_stash_manage.confirm=Type DROP to continue: "
if "%app.git_stash_manage.confirm%"=="DROP" goto :_Main_drop_apply
echo.
echo Cancelled. Nothing was deleted.
set "_gsmm_rc=0" & goto :Main
:_Main_drop_apply
git stash drop "%app.git_stash_manage.ref%"
set "_gsmm_rc=%errorlevel%"
if "%_gsmm_rc%"=="0" goto :_Main_drop_success
echo ERROR: Git could not drop the stash.
set "_gsmm_rc=1" & goto :Main
:_Main_drop_success
echo.
echo Stash dropped successfully.
set "_gsmm_rc=0" & goto :Main
:_Main_show
call :PreviewStash
if errorlevel 1 (set "_gsmm_rc=1" & goto :Main)
echo Full patch:
echo.
git stash show --patch "%app.git_stash_manage.ref%"
set "_gsmm_rc=%errorlevel%"
echo.
if "%_gsmm_rc%"=="0" goto :Main
echo ERROR: Git could not display the stash patch.
set "_gsmm_rc=1" & goto :Main
:_Main_list
git stash list --date=local
set "_gsmm_rc=%errorlevel%"
if not "%_gsmm_rc%"=="0" (echo ERROR: Git could not list stashes. & set "_gsmm_rc=1" & goto :Main)
echo.
echo Use:
echo   git_stash_manage.bat show stash@{0}
echo   git_stash_manage.bat apply stash@{0}
echo   git_stash_manage.bat pop stash@{0}
echo   git_stash_manage.bat drop stash@{0}
set "_gsmm_rc=0" & goto :Main
:_Main_operation_success
echo.
git status --short --branch
set "_gsmm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_gsmm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses stash action, stash reference, dirty-tree override, and help.
::
:: Usage: call :ParseArgs list|show|apply|pop|drop [stash@{N}]
::        [allowdirty yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="list" goto :_ParseArgs_action_first
if /I "%~1"=="show" goto :_ParseArgs_action_first
if /I "%~1"=="apply" goto :_ParseArgs_action_first
if /I "%~1"=="pop" goto :_ParseArgs_action_first
if /I "%~1"=="drop" goto :_ParseArgs_action_first
if /I "%~1"=="action" goto :_ParseArgs_action
if /I "%~1"=="ref" goto :_ParseArgs_ref
if /I "%~1"=="stash" goto :_ParseArgs_ref
if /I "%~1"=="allowdirty" goto :_ParseArgs_dirty
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_stash_manage.ref (set "app.git_stash_manage.ref=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_action_first
set "app.git_stash_manage.action=%~1"
shift
goto :ParseArgs
:_ParseArgs_action
if "%~2"=="" (echo ERROR: action requires list, show, apply, pop, or drop. & exit /b 2)
set "app.git_stash_manage.action=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_ref
if "%~2"=="" (echo ERROR: ref requires stash@{N}. & exit /b 2)
set "app.git_stash_manage.ref=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_dirty
if "%~2"=="" (echo ERROR: allowdirty requires yes or no. & exit /b 2)
set "app.git_stash_manage.allowdirty=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_stash_manage.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeAction
:: Normalizes and validates the selected stash action.
::
:: Usage: call :NormalizeAction
::
:: Returns: 0 for list, show, apply, pop, or drop
::          1 otherwise
:: Requires: none
:: ============================================================
:NormalizeAction
if /I "%app.git_stash_manage.action%"=="list" set "app.git_stash_manage.action=list"
if /I "%app.git_stash_manage.action%"=="show" set "app.git_stash_manage.action=show"
if /I "%app.git_stash_manage.action%"=="apply" set "app.git_stash_manage.action=apply"
if /I "%app.git_stash_manage.action%"=="pop" set "app.git_stash_manage.action=pop"
if /I "%app.git_stash_manage.action%"=="drop" set "app.git_stash_manage.action=drop"
if "%app.git_stash_manage.action%"=="list" exit /b 0
if "%app.git_stash_manage.action%"=="show" exit /b 0
if "%app.git_stash_manage.action%"=="apply" exit /b 0
if "%app.git_stash_manage.action%"=="pop" exit /b 0
if "%app.git_stash_manage.action%"=="drop" exit /b 0
echo ERROR: action must be list, show, apply, pop, or drop.
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
for /f "tokens=1 delims==" %%v in ('set gsmy_ 2^>nul') do set "%%v="
if defined _gsmy_rc (set "_gsmy_rc=" & exit /b %_gsmy_rc%)
set "gsmy_name=%~1"
call set "gsmy_value=%%%gsmy_name%%%"
if /I "%gsmy_value%"=="y" set "%gsmy_name%=yes"
if /I "%gsmy_value%"=="yes" set "%gsmy_name%=yes"
if /I "%gsmy_value%"=="true" set "%gsmy_name%=yes"
if /I "%gsmy_value%"=="1" set "%gsmy_name%=yes"
if /I "%gsmy_value%"=="n" set "%gsmy_name%=no"
if /I "%gsmy_value%"=="no" set "%gsmy_name%=no"
if /I "%gsmy_value%"=="false" set "%gsmy_name%=no"
if /I "%gsmy_value%"=="0" set "%gsmy_name%=no"
call set "gsmy_value=%%%gsmy_name%%%"
if /I "%gsmy_value%"=="yes" (set "_gsmy_rc=0" & goto :NormalizeYesNo)
if /I "%gsmy_value%"=="no" (set "_gsmy_rc=0" & goto :NormalizeYesNo)
set "_gsmy_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ValidateStashRef
:: Restricts the selected reference to an existing stash@{N} entry.
::
:: Usage: call :ValidateStashRef
::
:: Returns: 0 when the stash reference exists
::          1 when its form or target is invalid
:: Requires: :ValidateNonNegativeNumber, git
:: ============================================================
:ValidateStashRef
for /f "tokens=1 delims==" %%v in ('set gsmv_ 2^>nul') do set "%%v="
if defined _gsmv_rc (set "_gsmv_rc=" & exit /b %_gsmv_rc%)
set "app.git_stash_manage.index=%app.git_stash_manage.ref:stash@{=%"
set "app.git_stash_manage.index=%app.git_stash_manage.index:}=%"
if not "%app.git_stash_manage.ref%"=="stash@{%app.git_stash_manage.index%}" goto :_ValidateStashRef_bad
call :ValidateNonNegativeNumber "%app.git_stash_manage.index%" stash-index
if errorlevel 1 (set "_gsmv_rc=1" & goto :ValidateStashRef)
git rev-parse --verify "%app.git_stash_manage.ref%^^{commit}" >nul 2>nul
if errorlevel 1 goto :_ValidateStashRef_missing
set "_gsmv_rc=0" & goto :ValidateStashRef
:_ValidateStashRef_bad
echo ERROR: Stash reference must use the exact form stash@{N}.
echo   supplied: %app.git_stash_manage.ref%
set "_gsmv_rc=1" & goto :ValidateStashRef
:_ValidateStashRef_missing
echo ERROR: Stash reference was not found:
echo   %app.git_stash_manage.ref%
set "_gsmv_rc=1" & goto :ValidateStashRef
:: ============================================================
:: :ValidateNonNegativeNumber
:: Validates a non-negative whole number.
::
:: Usage: call :ValidateNonNegativeNumber "value" name
::
:: Returns: 0 when valid
::          1 when empty or nonnumeric
:: Requires: none
:: ============================================================
:ValidateNonNegativeNumber
for /f "tokens=1 delims==" %%v in ('set gsmn_ 2^>nul') do set "%%v="
if defined _gsmn_rc (set "_gsmn_rc=" & exit /b %_gsmn_rc%)
set "gsmn_value=%~1"
set "gsmn_name=%~2"
if not defined gsmn_value (echo ERROR: %gsmn_name% requires a whole number. & set "_gsmn_rc=1" & goto :ValidateNonNegativeNumber)
set "gsmn_invalid="
for /f "delims=0123456789" %%A in ("%gsmn_value%") do set "gsmn_invalid=%%A"
if defined gsmn_invalid (echo ERROR: %gsmn_name% must be a non-negative whole number. & set "_gsmn_rc=1" & goto :ValidateNonNegativeNumber)
set "_gsmn_rc=0" & goto :ValidateNonNegativeNumber
:: ============================================================
:: :PreviewStash
:: Displays the selected stash identity and file summary.
::
:: Usage: call :PreviewStash
::
:: Returns: 0 when the preview succeeds
::          1 when Git cannot display it
:: Requires: git
:: ============================================================
:PreviewStash
for /f "tokens=1 delims==" %%v in ('set gsmp_ 2^>nul') do set "%%v="
if defined _gsmp_rc (set "_gsmp_rc=" & exit /b %_gsmp_rc%)
echo.
echo Stash:
echo   %app.git_stash_manage.ref%
echo.
git stash show --stat "%app.git_stash_manage.ref%"
set "_gsmp_rc=%errorlevel%"
echo.
if "%_gsmp_rc%"=="0" goto :PreviewStash
echo ERROR: Git could not preview the selected stash.
set "_gsmp_rc=1" & goto :PreviewStash
:: ============================================================
:: :ShowHelp
:: Displays stash actions, confirmation, and dirty-tree protection.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_stash_manage.bat
echo.
echo Usage:
echo   git_stash_manage.bat list
echo   git_stash_manage.bat show stash@{0}
echo   git_stash_manage.bat apply stash@{0}
echo   git_stash_manage.bat pop stash@{0}
echo   git_stash_manage.bat drop stash@{0}
echo.
echo apply, pop, and drop require typed confirmation.
echo apply and pop reject dirty working trees unless allowdirty yes is used.
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
