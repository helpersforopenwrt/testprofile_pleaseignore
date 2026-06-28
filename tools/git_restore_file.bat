@echo off
:: ============================================================
:: git_restore_file.bat
:: Restores one currently tracked repository-relative file from a
:: selected commit, tag, or branch after a focused preview.
::
:: Usage:
::   call tools\git_restore_file.bat
::   call tools\git_restore_file.bat path README.md
::   call tools\git_restore_file.bat path src\main.c source HEAD
::   call tools\git_restore_file.bat path src\main.c source origin/main staged yes
::
:: Returns: 0 on successful restore, cancellation, or help
::          1 on preparation, repository, revision, path, preview, or restore failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_restore_file.path="
set "app.git_restore_file.gitpath="
set "app.git_restore_file.source=HEAD"
set "app.git_restore_file.staged=no"
set "app.git_restore_file.confirm="
set "app.git_restore_file.help="
set "app.git_restore_file.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_restore_file.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_restore_file.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_restore_file.rc%
:: ============================================================
:: :Main
:: Validates the source and tracked path, previews staged and unstaged
:: changes for that file, confirms, and restores worktree or index plus worktree.
::
:: Usage: call :Main [path FILE] [source REV] [staged yes|no]
::
:: Returns: 0 on successful restore, cancellation, or help
::          1 on preparation, repository, revision, path, preview, or restore failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set grfm_ 2^>nul') do set "%%v="
if defined _grfm_rc (set "_grfm_rc=" & exit /b %_grfm_rc%)
call :ParseArgs %*
set "_grfm_rc=%errorlevel%"
if not "%_grfm_rc%"=="0" goto :Main
if defined app.git_restore_file.help goto :_Main_help
call :NormalizeYesNo app.git_restore_file.staged
if errorlevel 1 (echo ERROR: staged must be yes or no. & set "_grfm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Restore one file
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_grfm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_grfm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_grfm_rc=1" & goto :Main)
if not defined app.git_restore_file.path set /p "app.git_restore_file.path=Repository-relative tracked file path: "
if not defined app.git_restore_file.path (echo ERROR: A file path is required. & set "_grfm_rc=1" & goto :Main)
set "app.git_restore_file.gitpath=%app.git_restore_file.path:\=/%"
git rev-parse --verify "%app.git_restore_file.source%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Source revision was not found: & echo   %app.git_restore_file.source% & set "_grfm_rc=1" & goto :Main)
git ls-files --error-unmatch -- "%app.git_restore_file.gitpath%" >nul 2>nul
if errorlevel 1 goto :_Main_not_tracked
git cat-file -e "%app.git_restore_file.source%:%app.git_restore_file.gitpath%" >nul 2>nul
if errorlevel 1 goto :_Main_missing_source
echo.
echo File:
echo   %app.git_restore_file.gitpath%
echo.
echo Restore from:
echo   %app.git_restore_file.source%
echo.
echo Restore staged/index copy too:
echo   %app.git_restore_file.staged%
echo.
echo Current unstaged changes for this file:
echo.
git diff -- "%app.git_restore_file.gitpath%"
if errorlevel 1 (echo ERROR: Could not preview unstaged changes. & set "_grfm_rc=1" & goto :Main)
echo.
echo Current staged changes for this file:
echo.
git diff --cached -- "%app.git_restore_file.gitpath%"
if errorlevel 1 (echo ERROR: Could not preview staged changes. & set "_grfm_rc=1" & goto :Main)
echo.
echo WARNING: Current changes in this file may be overwritten.
echo Other files will not be changed.
echo.
set /p "app.git_restore_file.confirm=Type RESTORE to continue: "
if "%app.git_restore_file.confirm%"=="RESTORE" goto :_Main_restore
echo.
echo Cancelled. Nothing was changed.
set "_grfm_rc=0" & goto :Main
:_Main_restore
if /I "%app.git_restore_file.staged%"=="yes" goto :_Main_restore_staged
git restore --source="%app.git_restore_file.source%" --worktree -- "%app.git_restore_file.gitpath%"
set "_grfm_rc=%errorlevel%"
goto :_Main_result
:_Main_restore_staged
git restore --source="%app.git_restore_file.source%" --staged --worktree -- "%app.git_restore_file.gitpath%"
set "_grfm_rc=%errorlevel%"
:_Main_result
if "%_grfm_rc%"=="0" goto :_Main_success
echo.
echo ERROR: Git could not restore the file.
set "_grfm_rc=1" & goto :Main
:_Main_success
echo.
echo File restored successfully:
echo   %app.git_restore_file.gitpath%
echo.
git status --short -- "%app.git_restore_file.gitpath%"
set "_grfm_rc=0" & goto :Main
:_Main_not_tracked
echo ERROR: The selected path is not currently tracked by Git:
echo   %app.git_restore_file.gitpath%
set "_grfm_rc=1" & goto :Main
:_Main_missing_source
echo ERROR: The selected file does not exist in:
echo   %app.git_restore_file.source%
echo.
echo File:
echo   %app.git_restore_file.gitpath%
set "_grfm_rc=1" & goto :Main
:_Main_help
call :ShowHelp
set "_grfm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ParseArgs
:: Parses path, source revision, staged behavior, and help arguments.
::
:: Usage: call :ParseArgs [path FILE] [source REV] [staged yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="path" goto :_ParseArgs_path
if /I "%~1"=="file" goto :_ParseArgs_path
if /I "%~1"=="source" goto :_ParseArgs_source
if /I "%~1"=="from" goto :_ParseArgs_source
if /I "%~1"=="staged" goto :_ParseArgs_staged
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_restore_file.path (set "app.git_restore_file.path=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_path
if "%~2"=="" (echo ERROR: path requires a file name. & exit /b 2)
set "app.git_restore_file.path=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_source
if "%~2"=="" (echo ERROR: source requires a commit, tag, or branch. & exit /b 2)
set "app.git_restore_file.source=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_staged
if "%~2"=="" (echo ERROR: staged requires yes or no. & exit /b 2)
set "app.git_restore_file.staged=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_restore_file.help=1"
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
for /f "tokens=1 delims==" %%v in ('set grfy_ 2^>nul') do set "%%v="
if defined _grfy_rc (set "_grfy_rc=" & exit /b %_grfy_rc%)
set "grfy_name=%~1"
call set "grfy_value=%%%grfy_name%%%"
if /I "%grfy_value%"=="y" set "%grfy_name%=yes"
if /I "%grfy_value%"=="yes" set "%grfy_name%=yes"
if /I "%grfy_value%"=="true" set "%grfy_name%=yes"
if /I "%grfy_value%"=="1" set "%grfy_name%=yes"
if /I "%grfy_value%"=="n" set "%grfy_name%=no"
if /I "%grfy_value%"=="no" set "%grfy_name%=no"
if /I "%grfy_value%"=="false" set "%grfy_name%=no"
if /I "%grfy_value%"=="0" set "%grfy_name%=no"
call set "grfy_value=%%%grfy_name%%%"
if /I "%grfy_value%"=="yes" (set "_grfy_rc=0" & goto :NormalizeYesNo)
if /I "%grfy_value%"=="no" (set "_grfy_rc=0" & goto :NormalizeYesNo)
set "_grfy_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays focused restore behavior for worktree-only and staged modes.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_restore_file.bat
echo.
echo Usage:
echo   git_restore_file.bat path README.md
echo   git_restore_file.bat path src\main.c source origin/main
echo   git_restore_file.bat path src\main.c staged yes
echo.
echo staged no restores only the worktree copy.
echo staged yes restores both the index and worktree copy.
echo Only currently tracked paths are accepted.
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
