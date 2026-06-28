@echo off
:: ============================================================
:: git_stash_changes.bat
:: Saves eligible uncommitted changes in a new Git stash after
:: classifying staged, unstaged, and untracked content.
::
:: Usage:
::   call tools\git_stash_changes.bat
::   call tools\git_stash_changes.bat message "Work in progress"
::   call tools\git_stash_changes.bat includeuntracked no
::   call tools\git_stash_changes.bat keepindex yes
::
:: Returns: 0 on successful stash, no eligible changes, cancellation, or help
::          1 on preparation, repository, conflict, inspection, or stash failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :DetectChanges,
::           :ParseArgs, :NormalizeYesNo, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_stash_changes.message="
set "app.git_stash_changes.includeuntracked=yes"
set "app.git_stash_changes.keepindex=no"
set "app.git_stash_changes.has.staged="
set "app.git_stash_changes.has.unstaged="
set "app.git_stash_changes.has.untracked="
set "app.git_stash_changes.has.conflicts="
set "app.git_stash_changes.eligible="
set "app.git_stash_changes.confirm="
set "app.git_stash_changes.help="
set "app.git_stash_changes.rc=0"
call "%~dp0_common.bat" init
set "app.git_stash_changes.rc=%errorlevel%"
if "%app.git_stash_changes.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_stash_changes.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_stash_changes.rc%
:: ============================================================
:: :Main
:: Validates options and repository state, determines which changes
:: the selected stash flags can save, confirms, and creates the stash.
::
:: Usage: call :Main [message TEXT] [includeuntracked yes|no]
::        [keepindex yes|no]
::
:: Returns: 0 on successful stash, no eligible changes, cancellation, or help
::          1 on preparation, repository, conflict, inspection, or stash failure
::          2 on invalid arguments
:: Requires: :DetectChanges, :ParseArgs, :NormalizeYesNo, :ShowHelp,
::           prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gscm_ 2^>nul') do set "%%v="
if defined _gscm_rc (set "_gscm_rc=" & exit /b %_gscm_rc%)
call :ParseArgs %*
set "_gscm_rc=%errorlevel%"
if not "%_gscm_rc%"=="0" goto :Main
if defined app.git_stash_changes.help goto :_Main_help
call :NormalizeYesNo app.git_stash_changes.includeuntracked
if errorlevel 1 (echo ERROR: includeuntracked must be yes or no. & set "_gscm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_stash_changes.keepindex
if errorlevel 1 (echo ERROR: keepindex must be yes or no. & set "_gscm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Stash local changes
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gscm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gscm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gscm_rc=1" & goto :Main)
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: The repository has no commits yet, so Git cannot create a stash. & set "_gscm_rc=1" & goto :Main)
call :DetectChanges
if errorlevel 1 (set "_gscm_rc=1" & goto :Main)
if defined app.git_stash_changes.has.conflicts goto :_Main_conflicts
set "app.git_stash_changes.eligible="
if /I "%app.git_stash_changes.keepindex%"=="no" if defined app.git_stash_changes.has.staged set "app.git_stash_changes.eligible=1"
if defined app.git_stash_changes.has.unstaged set "app.git_stash_changes.eligible=1"
if /I "%app.git_stash_changes.includeuntracked%"=="yes" if defined app.git_stash_changes.has.untracked set "app.git_stash_changes.eligible=1"
if not defined app.git_stash_changes.eligible goto :_Main_no_eligible
if not defined app.git_stash_changes.message set "app.git_stash_changes.message=Work in progress"
echo Local changes:
echo.
git status --short
if errorlevel 1 (echo ERROR: Git status failed. & set "_gscm_rc=1" & goto :Main)
echo.
echo Stash message:
echo   %app.git_stash_changes.message%
echo.
echo Include untracked files:
echo   %app.git_stash_changes.includeuntracked%
echo.
echo Keep staged changes in the working tree:
echo   %app.git_stash_changes.keepindex%
echo.
set /p "app.git_stash_changes.confirm=Type STASH to continue: "
if "%app.git_stash_changes.confirm%"=="STASH" goto :_Main_stash
echo.
echo Cancelled. Nothing was changed.
set "_gscm_rc=0" & goto :Main
:_Main_stash
if /I "%app.git_stash_changes.includeuntracked%"=="yes" goto :_Main_stash_untracked
if /I "%app.git_stash_changes.keepindex%"=="yes" goto :_Main_stash_keep
git stash push -m "%app.git_stash_changes.message%"
set "_gscm_rc=%errorlevel%"
goto :_Main_result
:_Main_stash_untracked
if /I "%app.git_stash_changes.keepindex%"=="yes" goto :_Main_stash_both
git stash push --include-untracked -m "%app.git_stash_changes.message%"
set "_gscm_rc=%errorlevel%"
goto :_Main_result
:_Main_stash_keep
git stash push --keep-index -m "%app.git_stash_changes.message%"
set "_gscm_rc=%errorlevel%"
goto :_Main_result
:_Main_stash_both
git stash push --include-untracked --keep-index -m "%app.git_stash_changes.message%"
set "_gscm_rc=%errorlevel%"
:_Main_result
if "%_gscm_rc%"=="0" goto :_Main_success
echo.
echo ERROR: Git could not create the stash.
set "_gscm_rc=1" & goto :Main
:_Main_success
echo.
echo ============================================================
echo  Changes stashed
echo ============================================================
echo.
git stash list -1
set "_gscm_list_rc=%errorlevel%"
if not "%_gscm_list_rc%"=="0" echo WARNING: The stash was created, but Git could not display the stash list.
echo.
echo Restore or inspect it with:
echo   tools\git_stash_manage.bat show stash@{0}
echo   tools\git_stash_manage.bat apply stash@{0}
echo   tools\git_stash_manage.bat pop stash@{0}
echo.
set "_gscm_rc=0" & goto :Main
:_Main_conflicts
echo ERROR: Unresolved conflicts are present.
echo Resolve or abort the active Git operation before creating a stash.
echo.
git diff --name-only --diff-filter=U
set "_gscm_rc=1" & goto :Main
:_Main_no_eligible
echo No changes are eligible for the selected stash options.
echo.
if defined app.git_stash_changes.has.staged if /I "%app.git_stash_changes.keepindex%"=="yes" echo Staged changes are being kept because keepindex is yes.
if defined app.git_stash_changes.has.untracked if /I "%app.git_stash_changes.includeuntracked%"=="no" echo Untracked files are excluded because includeuntracked is no.
if not defined app.git_stash_changes.has.staged if not defined app.git_stash_changes.has.unstaged if not defined app.git_stash_changes.has.untracked echo The working tree has no stashable changes.
set "_gscm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_gscm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :DetectChanges
:: Classifies staged, unstaged, untracked, and unresolved content.
::
:: Usage: call :DetectChanges
::
:: Returns: 0 when inspection succeeds
::          1 when a Git inspection command fails
:: Requires: git
:: ============================================================
:DetectChanges
for /f "tokens=1 delims==" %%v in ('set gscd_ 2^>nul') do set "%%v="
if defined _gscd_rc (set "_gscd_rc=" & exit /b %_gscd_rc%)
set "app.git_stash_changes.has.staged="
set "app.git_stash_changes.has.unstaged="
set "app.git_stash_changes.has.untracked="
set "app.git_stash_changes.has.conflicts="
git diff --cached --quiet --no-ext-diff
set "gscd_cached_rc=%errorlevel%"
if "%gscd_cached_rc%"=="1" set "app.git_stash_changes.has.staged=1"
if not "%gscd_cached_rc%"=="0" if not "%gscd_cached_rc%"=="1" (echo ERROR: Could not inspect staged changes. & set "_gscd_rc=1" & goto :DetectChanges)
git diff --quiet --no-ext-diff
set "gscd_worktree_rc=%errorlevel%"
if "%gscd_worktree_rc%"=="1" set "app.git_stash_changes.has.unstaged=1"
if not "%gscd_worktree_rc%"=="0" if not "%gscd_worktree_rc%"=="1" (echo ERROR: Could not inspect unstaged changes. & set "_gscd_rc=1" & goto :DetectChanges)
git ls-files --others --exclude-standard >nul 2>nul
if errorlevel 1 (echo ERROR: Could not inspect untracked files. & set "_gscd_rc=1" & goto :DetectChanges)
for /f "delims=" %%A in ('git ls-files --others --exclude-standard 2^>nul') do set "app.git_stash_changes.has.untracked=1"
for /f "delims=" %%A in ('git diff --name-only --diff-filter^=U 2^>nul') do set "app.git_stash_changes.has.conflicts=1"
set "_gscd_rc=0" & goto :DetectChanges
:: ============================================================
:: :ParseArgs
:: Parses stash message, untracked inclusion, keep-index, and help.
::
:: Usage: call :ParseArgs [message TEXT] [includeuntracked yes|no]
::        [keepindex yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="message" goto :_ParseArgs_message
if /I "%~1"=="includeuntracked" goto :_ParseArgs_include
if /I "%~1"=="keepindex" goto :_ParseArgs_keep
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_message
if "%~2"=="" (echo ERROR: message requires text. & exit /b 2)
set "app.git_stash_changes.message=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_include
if "%~2"=="" (echo ERROR: includeuntracked requires yes or no. & exit /b 2)
set "app.git_stash_changes.includeuntracked=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_keep
if "%~2"=="" (echo ERROR: keepindex requires yes or no. & exit /b 2)
set "app.git_stash_changes.keepindex=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_stash_changes.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gscy_ 2^>nul') do set "%%v="
if defined _gscy_rc (set "_gscy_rc=" & exit /b %_gscy_rc%)
set "gscy_name=%~1"
call set "gscy_value=%%%gscy_name%%%"
if /I "%gscy_value%"=="y" set "%gscy_name%=yes"
if /I "%gscy_value%"=="yes" set "%gscy_name%=yes"
if /I "%gscy_value%"=="true" set "%gscy_name%=yes"
if /I "%gscy_value%"=="1" set "%gscy_name%=yes"
if /I "%gscy_value%"=="n" set "%gscy_name%=no"
if /I "%gscy_value%"=="no" set "%gscy_name%=no"
if /I "%gscy_value%"=="false" set "%gscy_name%=no"
if /I "%gscy_value%"=="0" set "%gscy_name%=no"
call set "gscy_value=%%%gscy_name%%%"
if /I "%gscy_value%"=="yes" (set "_gscy_rc=0" & goto :NormalizeYesNo)
if /I "%gscy_value%"=="no" (set "_gscy_rc=0" & goto :NormalizeYesNo)
set "_gscy_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays stash eligibility, untracked, and keep-index behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_stash_changes.bat
echo.
echo Usage:
echo   git_stash_changes.bat
echo   git_stash_changes.bat message "Work in progress"
echo   git_stash_changes.bat includeuntracked no keepindex yes
echo.
echo keepindex yes keeps staged changes and stashes eligible unstaged
echo content. includeuntracked yes also saves untracked, nonignored files.
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
