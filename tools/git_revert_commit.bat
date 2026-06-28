@echo off
:: ============================================================
:: git_revert_commit.bat
:: Creates a new commit that reverses an older commit without
:: rewriting existing history.
::
:: Usage:
::   call tools\git_revert_commit.bat
::   call tools\git_revert_commit.bat commit abc123
::   call tools\git_revert_commit.bat commit abc123 mainline 1
::   call tools\git_revert_commit.bat commit abc123 edit yes
::
:: Returns: 0 on successful revert, cancellation, or help
::          1 on preparation, repository, revision, tree, or revert failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ValidatePositiveNumber, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_revert_commit.commit="
set "app.git_revert_commit.mainline="
set "app.git_revert_commit.edit=no"
set "app.git_revert_commit.dirty="
set "app.git_revert_commit.parent.count=0"
set "app.git_revert_commit.confirm="
set "app.git_revert_commit.help="
set "app.git_revert_commit.rc=0"
call "%~dp0_common.bat" init
set "app.git_revert_commit.rc=%errorlevel%"
if "%app.git_revert_commit.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_revert_commit.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_revert_commit.rc%
:: ============================================================
:: :Main
:: Validates a clean working tree, commit and merge-parent selection,
:: previews the revert, confirms it, and runs git revert.
::
:: Usage: call :Main [commit REV] [mainline N] [edit yes|no]
::
:: Returns: 0 on successful revert, cancellation, or help
::          1 on preparation, repository, revision, tree, or revert failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ValidatePositiveNumber,
::           :ShowHelp, prepare.bat, git, findstr.exe
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set grcm_ 2^>nul') do set "%%v="
if defined _grcm_rc (set "_grcm_rc=" & exit /b %_grcm_rc%)
call :ParseArgs %*
set "_grcm_rc=%errorlevel%"
if not "%_grcm_rc%"=="0" goto :Main
if defined app.git_revert_commit.help goto :_Main_help
call :NormalizeYesNo app.git_revert_commit.edit
if errorlevel 1 (echo ERROR: edit must be yes or no. & set "_grcm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Revert a commit safely
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_grcm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_grcm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_grcm_rc=1" & goto :Main)
git status --porcelain >nul 2>nul
if errorlevel 1 (echo ERROR: Git status failed. & set "_grcm_rc=1" & goto :Main)
set "app.git_revert_commit.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_revert_commit.dirty=1"
if defined app.git_revert_commit.dirty goto :_Main_dirty
if not defined app.git_revert_commit.commit set /p "app.git_revert_commit.commit=Commit to revert: "
if not defined app.git_revert_commit.commit (echo ERROR: A commit is required. & set "_grcm_rc=1" & goto :Main)
git rev-parse --verify "%app.git_revert_commit.commit%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Commit was not found: & echo   %app.git_revert_commit.commit% & set "_grcm_rc=1" & goto :Main)
git cat-file -p "%app.git_revert_commit.commit%" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not inspect the selected commit. & set "_grcm_rc=1" & goto :Main)
set "app.git_revert_commit.parent.count=0"
for /f "tokens=1" %%A in ('git cat-file -p "%app.git_revert_commit.commit%" 2^>nul ^| "%SystemRoot%\System32\findstr.exe" /B /C:"parent "') do set /a app.git_revert_commit.parent.count+=1
if "%app.git_revert_commit.parent.count%"=="0" goto :_Main_nonmerge
if "%app.git_revert_commit.parent.count%"=="1" goto :_Main_nonmerge
if defined app.git_revert_commit.mainline goto :_Main_validate_mainline
echo.
echo ERROR: The selected commit is a merge commit with %app.git_revert_commit.parent.count% parents.
echo Supply the parent to treat as the mainline, usually 1:
echo.
echo   git_revert_commit.bat commit "%app.git_revert_commit.commit%" mainline 1
echo.
echo Review the merge parents before choosing:
git show --no-patch --pretty=raw "%app.git_revert_commit.commit%"
set "_grcm_rc=1" & goto :Main
:_Main_nonmerge
if not defined app.git_revert_commit.mainline goto :_Main_parent_ready
echo ERROR: mainline is valid only when reverting a merge commit.
set "_grcm_rc=2" & goto :Main
:_Main_validate_mainline
call :ValidatePositiveNumber "%app.git_revert_commit.mainline%" mainline
if errorlevel 1 (set "_grcm_rc=2" & goto :Main)
if %app.git_revert_commit.mainline% LEQ %app.git_revert_commit.parent.count% goto :_Main_parent_ready
echo ERROR: mainline exceeds the merge commit's parent count.
echo   requested: %app.git_revert_commit.mainline%
echo   parents:   %app.git_revert_commit.parent.count%
set "_grcm_rc=2" & goto :Main
:_Main_parent_ready
echo.
echo Commit to revert:
echo.
git show --no-patch --decorate --oneline "%app.git_revert_commit.commit%"
if errorlevel 1 (echo ERROR: Could not display the selected commit. & set "_grcm_rc=1" & goto :Main)
git show --stat --summary "%app.git_revert_commit.commit%"
if errorlevel 1 (echo ERROR: Could not display the selected commit summary. & set "_grcm_rc=1" & goto :Main)
echo.
if not defined app.git_revert_commit.mainline goto :_Main_mainline_done
echo Merge mainline parent:
echo   %app.git_revert_commit.mainline%
echo.
:_Main_mainline_done
echo Open editor for the revert message:
echo   %app.git_revert_commit.edit%
echo.
echo Result:
echo   a new commit will be created
echo   existing history will not be rewritten
echo.
set /p "app.git_revert_commit.confirm=Type REVERT to continue: "
if "%app.git_revert_commit.confirm%"=="REVERT" goto :_Main_revert
echo.
echo Cancelled. Nothing was changed.
set "_grcm_rc=0" & goto :Main
:_Main_revert
if defined app.git_revert_commit.mainline goto :_Main_revert_merge
if /I "%app.git_revert_commit.edit%"=="yes" goto :_Main_revert_edit
git revert --no-edit "%app.git_revert_commit.commit%"
set "_grcm_rc=%errorlevel%"
goto :_Main_result
:_Main_revert_edit
git revert --edit "%app.git_revert_commit.commit%"
set "_grcm_rc=%errorlevel%"
goto :_Main_result
:_Main_revert_merge
if /I "%app.git_revert_commit.edit%"=="yes" goto :_Main_revert_merge_edit
git revert --no-edit -m %app.git_revert_commit.mainline% "%app.git_revert_commit.commit%"
set "_grcm_rc=%errorlevel%"
goto :_Main_result
:_Main_revert_merge_edit
git revert --edit -m %app.git_revert_commit.mainline% "%app.git_revert_commit.commit%"
set "_grcm_rc=%errorlevel%"
:_Main_result
if "%_grcm_rc%"=="0" goto :_Main_success
echo.
echo ERROR: Revert did not complete.
echo.
echo Git may have left an in-progress revert with conflicts.
echo Resolve conflicted files, stage them, and run:
echo   tools\git_continue_operation.bat
echo.
echo To cancel the in-progress revert, run:
echo   tools\git_abort_operation.bat
echo.
set "_grcm_rc=1" & goto :Main
:_Main_success
echo.
echo Revert commit created successfully:
git log -1 --oneline
set "_grcm_log_rc=%errorlevel%"
if not "%_grcm_log_rc%"=="0" echo WARNING: The revert succeeded, but Git could not display the new commit.
echo.
set "_grcm_rc=0" & goto :Main
:_Main_dirty
echo ERROR: The working tree has local changes.
echo Commit or stash them before reverting a commit.
echo.
git status --short
set "_grcm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_grcm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses the commit, merge mainline, editor selection, and help.
::
:: Usage: call :ParseArgs [commit REV] [mainline N] [edit yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="commit" goto :_ParseArgs_commit
if /I "%~1"=="mainline" goto :_ParseArgs_mainline
if /I "%~1"=="edit" goto :_ParseArgs_edit
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_revert_commit.commit (set "app.git_revert_commit.commit=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_commit
if "%~2"=="" (echo ERROR: commit requires a revision. & exit /b 2)
set "app.git_revert_commit.commit=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_mainline
if "%~2"=="" (echo ERROR: mainline requires a parent number. & exit /b 2)
set "app.git_revert_commit.mainline=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_edit
if "%~2"=="" (echo ERROR: edit requires yes or no. & exit /b 2)
set "app.git_revert_commit.edit=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_revert_commit.help=1"
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
for /f "tokens=1 delims==" %%v in ('set grcy_ 2^>nul') do set "%%v="
if defined _grcy_rc (set "_grcy_rc=" & exit /b %_grcy_rc%)
set "grcy_name=%~1"
call set "grcy_value=%%%grcy_name%%%"
if /I "%grcy_value%"=="y" set "%grcy_name%=yes"
if /I "%grcy_value%"=="yes" set "%grcy_name%=yes"
if /I "%grcy_value%"=="true" set "%grcy_name%=yes"
if /I "%grcy_value%"=="1" set "%grcy_name%=yes"
if /I "%grcy_value%"=="n" set "%grcy_name%=no"
if /I "%grcy_value%"=="no" set "%grcy_name%=no"
if /I "%grcy_value%"=="false" set "%grcy_name%=no"
if /I "%grcy_value%"=="0" set "%grcy_name%=no"
call set "grcy_value=%%%grcy_name%%%"
if /I "%grcy_value%"=="yes" (set "_grcy_rc=0" & goto :NormalizeYesNo)
if /I "%grcy_value%"=="no" (set "_grcy_rc=0" & goto :NormalizeYesNo)
set "_grcy_rc=1" & goto :NormalizeYesNo
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
for /f "tokens=1 delims==" %%v in ('set grcn_ 2^>nul') do set "%%v="
if defined _grcn_rc (set "_grcn_rc=" & exit /b %_grcn_rc%)
set "grcn_value=%~1"
set "grcn_name=%~2"
if not defined grcn_value (echo ERROR: %grcn_name% requires a positive number. & set "_grcn_rc=1" & goto :ValidatePositiveNumber)
set "grcn_invalid="
for /f "delims=0123456789" %%A in ("%grcn_value%") do set "grcn_invalid=%%A"
if defined grcn_invalid (echo ERROR: %grcn_name% must be a positive whole number. & set "_grcn_rc=1" & goto :ValidatePositiveNumber)
if "%grcn_value%"=="0" (echo ERROR: %grcn_name% must be 1 or greater. & set "_grcn_rc=1" & goto :ValidatePositiveNumber)
set "_grcn_rc=0" & goto :ValidatePositiveNumber
:: ============================================================
:: :ShowHelp
:: Displays safe revert, merge-mainline, and editor behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_revert_commit.bat
echo.
echo Usage:
echo   git_revert_commit.bat commit abc123
echo   git_revert_commit.bat commit abc123 mainline 1
echo   git_revert_commit.bat commit abc123 edit yes
echo.
echo Merge commits require a mainline parent within the actual parent count.
echo A clean working tree and REVERT confirmation are required.
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
