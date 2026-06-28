@echo off
:: ============================================================
:: git_remote_manage.bat
:: Lists, adds, changes, renames, or removes Git remotes. Mutating
:: actions validate their inputs and require REMOTE confirmation.
::
:: Usage:
::   call tools\git_remote_manage.bat list
::   call tools\git_remote_manage.bat add name upstream url OWNER/REPO
::   call tools\git_remote_manage.bat seturl name origin url OWNER/REPO
::   call tools\git_remote_manage.bat rename old backup new archive
::   call tools\git_remote_manage.bat remove name archive
::
:: Returns: 0 on successful list, mutation, cancellation, or help
::          1 on preparation, repository, verification, or Git failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ListRemotes,
::           :ShowRemote, :VerifyURL, :ValidateRemoteName, :NormalizeURL,
::           :NormalizeAction, :NormalizeYesNo, :ParseArgs, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_remote_manage.action=list"
set "app.git_remote_manage.name="
set "app.git_remote_manage.url="
set "app.git_remote_manage.url.normalized="
set "app.git_remote_manage.old="
set "app.git_remote_manage.new="
set "app.git_remote_manage.verify=yes"
set "app.git_remote_manage.old.url="
set "app.git_remote_manage.confirm="
set "app.git_remote_manage.help="
set "app.git_remote_manage.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_remote_manage.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_remote_manage.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_remote_manage.rc%
:: ============================================================
:: :Main
:: Parses and validates a remote-management action, previews any
:: mutation, obtains confirmation, and applies the selected Git command.
::
:: Usage: call :Main list|add|seturl|rename|remove [arguments]
::
:: Returns: 0 on successful list, mutation, cancellation, or help
::          1 on preparation, repository, verification, or Git failure
::          2 on invalid arguments
:: Requires: :ListRemotes, :VerifyURL, :ValidateRemoteName, :NormalizeURL,
::           :NormalizeAction, :NormalizeYesNo, :ParseArgs, :ShowHelp,
::           prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set grmm_ 2^>nul') do set "%%v="
if defined _grmm_rc (set "_grmm_rc=" & exit /b %_grmm_rc%)
call :ParseArgs %*
set "_grmm_rc=%errorlevel%"
if not "%_grmm_rc%"=="0" goto :Main
if defined app.git_remote_manage.help goto :_Main_help
call :NormalizeAction
if errorlevel 1 (set "_grmm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_remote_manage.verify
if errorlevel 1 (echo ERROR: verify must be yes or no. & set "_grmm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Manage Git remotes
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_grmm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_grmm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_grmm_rc=1" & goto :Main)
if "%app.git_remote_manage.action%"=="list" goto :_Main_list
if "%app.git_remote_manage.action%"=="add" goto :_Main_add
if "%app.git_remote_manage.action%"=="seturl" goto :_Main_seturl
if "%app.git_remote_manage.action%"=="rename" goto :_Main_rename
if "%app.git_remote_manage.action%"=="remove" goto :_Main_remove
echo ERROR: Unsupported action.
set "_grmm_rc=2" & goto :Main
:_Main_list
call :ListRemotes
set "_grmm_rc=%errorlevel%" & goto :Main
:_Main_add
if not defined app.git_remote_manage.name set /p "app.git_remote_manage.name=New remote name: "
if not defined app.git_remote_manage.url set /p "app.git_remote_manage.url=Remote URL or OWNER/REPO: "
if not defined app.git_remote_manage.name (echo ERROR: A remote name is required. & set "_grmm_rc=1" & goto :Main)
if not defined app.git_remote_manage.url (echo ERROR: A remote URL is required. & set "_grmm_rc=1" & goto :Main)
call :ValidateRemoteName "%app.git_remote_manage.name%"
if errorlevel 1 (set "_grmm_rc=2" & goto :Main)
git remote get-url "%app.git_remote_manage.name%" >nul 2>nul
if not errorlevel 1 (echo ERROR: Remote already exists: & echo   %app.git_remote_manage.name% & set "_grmm_rc=1" & goto :Main)
call :NormalizeURL "%app.git_remote_manage.url%" app.git_remote_manage.url.normalized
if errorlevel 1 (set "_grmm_rc=2" & goto :Main)
call :VerifyURL
if errorlevel 1 (set "_grmm_rc=1" & goto :Main)
echo Action:
echo   add
echo.
echo Name:
echo   %app.git_remote_manage.name%
echo.
echo URL:
echo   %app.git_remote_manage.url.normalized%
echo.
goto :_Main_confirm
:_Main_seturl
if not defined app.git_remote_manage.name set /p "app.git_remote_manage.name=Existing remote name: "
if not defined app.git_remote_manage.url set /p "app.git_remote_manage.url=New URL or OWNER/REPO: "
if not defined app.git_remote_manage.name (echo ERROR: A remote name is required. & set "_grmm_rc=1" & goto :Main)
if not defined app.git_remote_manage.url (echo ERROR: A new URL is required. & set "_grmm_rc=1" & goto :Main)
set "app.git_remote_manage.old.url="
for /f "delims=" %%A in ('git remote get-url "%app.git_remote_manage.name%" 2^>nul') do set "app.git_remote_manage.old.url=%%A"
if not defined app.git_remote_manage.old.url (echo ERROR: Remote does not exist: & echo   %app.git_remote_manage.name% & set "_grmm_rc=1" & goto :Main)
call :NormalizeURL "%app.git_remote_manage.url%" app.git_remote_manage.url.normalized
if errorlevel 1 (set "_grmm_rc=2" & goto :Main)
if "%app.git_remote_manage.old.url%"=="%app.git_remote_manage.url.normalized%" goto :_Main_same_url
call :VerifyURL
if errorlevel 1 (set "_grmm_rc=1" & goto :Main)
echo Action:
echo   seturl
echo.
echo Remote:
echo   %app.git_remote_manage.name%
echo.
echo Old URL:
echo   %app.git_remote_manage.old.url%
echo.
echo New URL:
echo   %app.git_remote_manage.url.normalized%
echo.
goto :_Main_confirm
:_Main_rename
if not defined app.git_remote_manage.old set /p "app.git_remote_manage.old=Existing remote name: "
if not defined app.git_remote_manage.new set /p "app.git_remote_manage.new=New remote name: "
if not defined app.git_remote_manage.old (echo ERROR: old remote name is required. & set "_grmm_rc=1" & goto :Main)
if not defined app.git_remote_manage.new (echo ERROR: new remote name is required. & set "_grmm_rc=1" & goto :Main)
call :ValidateRemoteName "%app.git_remote_manage.old%"
if errorlevel 1 (set "_grmm_rc=2" & goto :Main)
call :ValidateRemoteName "%app.git_remote_manage.new%"
if errorlevel 1 (set "_grmm_rc=2" & goto :Main)
if /I "%app.git_remote_manage.old%"=="%app.git_remote_manage.new%" goto :_Main_same_name
git remote get-url "%app.git_remote_manage.old%" >nul 2>nul
if errorlevel 1 (echo ERROR: Existing remote was not found: & echo   %app.git_remote_manage.old% & set "_grmm_rc=1" & goto :Main)
git remote get-url "%app.git_remote_manage.new%" >nul 2>nul
if not errorlevel 1 (echo ERROR: New remote name is already in use: & echo   %app.git_remote_manage.new% & set "_grmm_rc=1" & goto :Main)
echo Action:
echo   rename
echo.
echo Old name:
echo   %app.git_remote_manage.old%
echo.
echo New name:
echo   %app.git_remote_manage.new%
echo.
goto :_Main_confirm
:_Main_remove
if not defined app.git_remote_manage.name set /p "app.git_remote_manage.name=Remote name to remove: "
if not defined app.git_remote_manage.name (echo ERROR: A remote name is required. & set "_grmm_rc=1" & goto :Main)
call :ValidateRemoteName "%app.git_remote_manage.name%"
if errorlevel 1 (set "_grmm_rc=2" & goto :Main)
set "app.git_remote_manage.old.url="
for /f "delims=" %%A in ('git remote get-url "%app.git_remote_manage.name%" 2^>nul') do set "app.git_remote_manage.old.url=%%A"
if not defined app.git_remote_manage.old.url (echo ERROR: Remote does not exist: & echo   %app.git_remote_manage.name% & set "_grmm_rc=1" & goto :Main)
echo Action:
echo   remove
echo.
echo Remote:
echo   %app.git_remote_manage.name%
echo.
echo URL:
echo   %app.git_remote_manage.old.url%
echo.
if /I "%app.git_remote_manage.name%"=="origin" echo WARNING: Removing origin breaks normal push and pull helpers.
if /I "%app.git_remote_manage.name%"=="upstream" echo WARNING: Removing upstream breaks fork synchronization helpers.
echo.
goto :_Main_confirm
:_Main_confirm
set /p "app.git_remote_manage.confirm=Type REMOTE to continue: "
if "%app.git_remote_manage.confirm%"=="REMOTE" goto :_Main_apply
echo.
echo Cancelled. Nothing was changed.
set "_grmm_rc=0" & goto :Main
:_Main_apply
if "%app.git_remote_manage.action%"=="add" goto :_Main_apply_add
if "%app.git_remote_manage.action%"=="seturl" goto :_Main_apply_seturl
if "%app.git_remote_manage.action%"=="rename" goto :_Main_apply_rename
if "%app.git_remote_manage.action%"=="remove" goto :_Main_apply_remove
echo ERROR: Unsupported action.
set "_grmm_rc=2" & goto :Main
:_Main_apply_add
git remote add "%app.git_remote_manage.name%" "%app.git_remote_manage.url.normalized%"
set "_grmm_rc=%errorlevel%"
goto :_Main_apply_result
:_Main_apply_seturl
git remote set-url "%app.git_remote_manage.name%" "%app.git_remote_manage.url.normalized%"
set "_grmm_rc=%errorlevel%"
goto :_Main_apply_result
:_Main_apply_rename
git remote rename "%app.git_remote_manage.old%" "%app.git_remote_manage.new%"
set "_grmm_rc=%errorlevel%"
goto :_Main_apply_result
:_Main_apply_remove
git remote remove "%app.git_remote_manage.name%"
set "_grmm_rc=%errorlevel%"
:_Main_apply_result
if "%_grmm_rc%"=="0" goto :_Main_apply_success
echo ERROR: Remote operation failed.
set "_grmm_rc=1" & goto :Main
:_Main_apply_success
echo.
echo Remote operation completed successfully.
echo.
git remote -v
set "_grmm_rc=0" & goto :Main
:_Main_same_url
echo The remote already uses the requested URL.
set "_grmm_rc=0" & goto :Main
:_Main_same_name
echo The old and new remote names are the same.
set "_grmm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_grmm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ListRemotes
:: Displays fetch and push URLs for every configured remote.
::
:: Usage: call :ListRemotes
::
:: Returns: 0 on successful listing
::          1 when Git cannot list remotes
:: Requires: :ShowRemote, git
:: ============================================================
:ListRemotes
for /f "tokens=1 delims==" %%v in ('set grml_ 2^>nul') do set "%%v="
if defined _grml_rc (set "_grml_rc=" & exit /b %_grml_rc%)
echo Remotes:
echo.
git remote -v
if errorlevel 1 (echo ERROR: Git could not list remotes. & set "_grml_rc=1" & goto :ListRemotes)
echo.
echo Detailed configuration:
echo.
for /f "delims=" %%A in ('git remote 2^>nul') do call :ShowRemote "%%A"
set "_grml_rc=0" & goto :ListRemotes
:: ============================================================
:: :ShowRemote
:: Displays all fetch and push URLs for one named remote.
::
:: Usage: call :ShowRemote "name"
::
:: Returns: 0
:: Requires: git
:: ============================================================
:ShowRemote
echo [%~1]
echo Fetch URLs:
git remote get-url --all "%~1"
echo Push URLs:
git remote get-url --push --all "%~1"
echo.
exit /b 0
:: ============================================================
:: :VerifyURL
:: Tests the normalized URL with git ls-remote when verification is
:: enabled. Empty repositories are accepted because no ref is required.
::
:: Usage: call :VerifyURL
::
:: Returns: 0 when skipped or reachable
::          1 when verification fails
:: Requires: git
:: ============================================================
:VerifyURL
if /I not "%app.git_remote_manage.verify%"=="yes" exit /b 0
git ls-remote "%app.git_remote_manage.url.normalized%" >nul 2>nul
if not errorlevel 1 exit /b 0
echo ERROR: Remote URL could not be verified:
echo   %app.git_remote_manage.url.normalized%
echo.
echo Use verify no only when the URL is intentionally unreachable
echo from the current environment.
exit /b 1
:: ============================================================
:: :ValidateRemoteName
:: Validates a Git remote name through Git reference syntax.
::
:: Usage: call :ValidateRemoteName "name"
::
:: Returns: 0 when valid
::          1 when empty or invalid
:: Requires: git
:: ============================================================
:ValidateRemoteName
for /f "tokens=1 delims==" %%v in ('set grmv_ 2^>nul') do set "%%v="
if defined _grmv_rc (set "_grmv_rc=" & exit /b %_grmv_rc%)
set "grmv_name=%~1"
if not defined grmv_name (echo ERROR: Remote name is required. & set "_grmv_rc=1" & goto :ValidateRemoteName)
git check-ref-format "refs/remotes/%grmv_name%/test" >nul 2>nul
if not errorlevel 1 (set "_grmv_rc=0" & goto :ValidateRemoteName)
echo ERROR: Invalid remote name:
echo   %grmv_name%
set "_grmv_rc=1" & goto :ValidateRemoteName
:: ============================================================
:: :NormalizeURL
:: Converts an OWNER/REPO slug to a GitHub HTTPS URL and otherwise
:: preserves the supplied Git URL or local path.
::
:: Usage: call :NormalizeURL "value" outputVariable
::
:: Returns: 0 when a nonempty value is produced
::          1 when the input or output variable is missing
:: Requires: none
:: ============================================================
:NormalizeURL
for /f "tokens=1 delims==" %%v in ('set grmn_ 2^>nul') do set "%%v="
if defined _grmn_rc (set "_grmn_rc=" & exit /b %_grmn_rc%)
set "grmn_value=%~1"
set "grmn_output=%~2"
if not defined grmn_value (echo ERROR: A remote URL is required. & set "_grmn_rc=1" & goto :NormalizeURL)
if not defined grmn_output (echo ERROR: An output variable is required. & set "_grmn_rc=1" & goto :NormalizeURL)
set "grmn_part1="
set "grmn_part2="
set "grmn_part3="
for /f "tokens=1-3 delims=/" %%A in ("%grmn_value%") do (
set "grmn_part1=%%A"
set "grmn_part2=%%B"
set "grmn_part3=%%C"
)
if "%grmn_value:~0,1%"=="." goto :_NormalizeURL_done
if not defined grmn_part1 goto :_NormalizeURL_done
if not defined grmn_part2 goto :_NormalizeURL_done
if defined grmn_part3 goto :_NormalizeURL_done
if not "%grmn_value::=%"=="%grmn_value%" goto :_NormalizeURL_done
if not "%grmn_value:\=%"=="%grmn_value%" goto :_NormalizeURL_done
if not "%grmn_value:@=%"=="%grmn_value%" goto :_NormalizeURL_done
set "grmn_value=https://github.com/%grmn_value%.git"
:_NormalizeURL_done
set "%grmn_output%=%grmn_value%"
set "_grmn_rc=0" & goto :NormalizeURL
:: ============================================================
:: :NormalizeAction
:: Normalizes and validates the selected remote action.
::
:: Usage: call :NormalizeAction
::
:: Returns: 0 for list, add, seturl, rename, or remove
::          1 otherwise
:: Requires: none
:: ============================================================
:NormalizeAction
if /I "%app.git_remote_manage.action%"=="list" set "app.git_remote_manage.action=list"
if /I "%app.git_remote_manage.action%"=="add" set "app.git_remote_manage.action=add"
if /I "%app.git_remote_manage.action%"=="seturl" set "app.git_remote_manage.action=seturl"
if /I "%app.git_remote_manage.action%"=="rename" set "app.git_remote_manage.action=rename"
if /I "%app.git_remote_manage.action%"=="remove" set "app.git_remote_manage.action=remove"
if "%app.git_remote_manage.action%"=="list" exit /b 0
if "%app.git_remote_manage.action%"=="add" exit /b 0
if "%app.git_remote_manage.action%"=="seturl" exit /b 0
if "%app.git_remote_manage.action%"=="rename" exit /b 0
if "%app.git_remote_manage.action%"=="remove" exit /b 0
echo ERROR: action must be list, add, seturl, rename, or remove.
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
for /f "tokens=1 delims==" %%v in ('set grmy_ 2^>nul') do set "%%v="
if defined _grmy_rc (set "_grmy_rc=" & exit /b %_grmy_rc%)
set "grmy_name=%~1"
call set "grmy_value=%%%grmy_name%%%"
if /I "%grmy_value%"=="y" set "%grmy_name%=yes"
if /I "%grmy_value%"=="yes" set "%grmy_name%=yes"
if /I "%grmy_value%"=="true" set "%grmy_name%=yes"
if /I "%grmy_value%"=="1" set "%grmy_name%=yes"
if /I "%grmy_value%"=="n" set "%grmy_name%=no"
if /I "%grmy_value%"=="no" set "%grmy_name%=no"
if /I "%grmy_value%"=="false" set "%grmy_name%=no"
if /I "%grmy_value%"=="0" set "%grmy_name%=no"
call set "grmy_value=%%%grmy_name%%%"
if /I "%grmy_value%"=="yes" (set "_grmy_rc=0" & goto :NormalizeYesNo)
if /I "%grmy_value%"=="no" (set "_grmy_rc=0" & goto :NormalizeYesNo)
set "_grmy_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ParseArgs
:: Parses action, remote name, URL, rename names, verification,
:: and help arguments.
::
:: Usage: call :ParseArgs list|add|seturl|rename|remove [arguments]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="list" goto :_ParseArgs_action_first
if /I "%~1"=="add" goto :_ParseArgs_action_first
if /I "%~1"=="seturl" goto :_ParseArgs_action_first
if /I "%~1"=="rename" goto :_ParseArgs_action_first
if /I "%~1"=="remove" goto :_ParseArgs_action_first
if /I "%~1"=="action" goto :_ParseArgs_action
if /I "%~1"=="name" goto :_ParseArgs_name
if /I "%~1"=="url" goto :_ParseArgs_url
if /I "%~1"=="old" goto :_ParseArgs_old
if /I "%~1"=="new" goto :_ParseArgs_new
if /I "%~1"=="verify" goto :_ParseArgs_verify
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_action_first
set "app.git_remote_manage.action=%~1"
shift
goto :ParseArgs
:_ParseArgs_action
if "%~2"=="" (echo ERROR: action requires list, add, seturl, rename, or remove. & exit /b 2)
set "app.git_remote_manage.action=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_name
if "%~2"=="" (echo ERROR: name requires a remote name. & exit /b 2)
set "app.git_remote_manage.name=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_url
if "%~2"=="" (echo ERROR: url requires a URL or OWNER/REPO. & exit /b 2)
set "app.git_remote_manage.url=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_old
if "%~2"=="" (echo ERROR: old requires a remote name. & exit /b 2)
set "app.git_remote_manage.old=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_new
if "%~2"=="" (echo ERROR: new requires a remote name. & exit /b 2)
set "app.git_remote_manage.new=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_verify
if "%~2"=="" (echo ERROR: verify requires yes or no. & exit /b 2)
set "app.git_remote_manage.verify=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_remote_manage.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :ShowHelp
:: Displays remote actions, argument forms, verification, and
:: confirmation behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_remote_manage.bat
echo.
echo Usage:
echo   git_remote_manage.bat list
echo   git_remote_manage.bat add name upstream url OWNER/REPO
echo   git_remote_manage.bat seturl name origin url OWNER/REPO
echo   git_remote_manage.bat rename old backup new archive
echo   git_remote_manage.bat remove name archive
echo.
echo OWNER/REPO values are converted to GitHub HTTPS URLs.
echo Mutating actions require REMOTE confirmation.
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
