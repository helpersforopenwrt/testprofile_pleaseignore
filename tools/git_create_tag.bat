@echo off
:: ============================================================
:: git_create_tag.bat
:: Creates an annotated Git tag and optionally pushes it to origin.
::
:: Usage:
::   call tools\git_create_tag.bat v1.0.0
::   call tools\git_create_tag.bat name v1.0.0 message "First release"
::   call tools\git_create_tag.bat name v1.0.0 target HEAD push yes
::
:: Returns: 0 on success or cancellation
::          1 on repository, validation, creation, or push failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ResolvePushChoice, :ValidateTagPlan,
::           :ShowPlan, :CreateTag, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_create_tag.name="
set "app.git_create_tag.message="
set "app.git_create_tag.target=HEAD"
set "app.git_create_tag.push="
set "app.git_create_tag.origin="
set "app.git_create_tag.dirty="
set "app.git_create_tag.remote.exists="
set "app.git_create_tag.input="
set "app.git_create_tag.confirm="
set "app.git_create_tag.help="
set "app.git_create_tag.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_create_tag.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_create_tag.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_create_tag.rc%
:: ============================================================
:: :Main
:: Parses options, prepares Git, resolves push choice, validates the
:: tag plan, confirms, creates, and optionally pushes the tag.
::
:: Usage: call :Main [name TAG] [message TEXT] [target REV] [push yes|no]
::
:: Returns: 0 on success or cancellation
::          1 on repository, validation, creation, or push failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ResolvePushChoice,
::           :ValidateTagPlan, :ShowPlan, :CreateTag,
::           :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gctm_ 2^>nul') do set "%%v="
if defined _gctm_rc (set "_gctm_rc=" & exit /b %_gctm_rc%)
call :ParseArgs %*
set "_gctm_rc=%errorlevel%"
if not "%_gctm_rc%"=="0" goto :Main
if defined app.git_create_tag.help goto :_Main_help
if defined app.git_create_tag.push goto :_Main_normalize
goto :_Main_prepare
:_Main_normalize
call :NormalizeYesNo app.git_create_tag.push
if errorlevel 1 (echo ERROR: push must be yes or no. & set "_gctm_rc=2" & goto :Main)
:_Main_prepare
echo.
echo ============================================================
echo  Create annotated Git tag
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gctm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gctm_rc=1" & goto :Main)
if not defined app.git_create_tag.name set /p "app.git_create_tag.name=Tag name: "
call :ResolvePushChoice
if errorlevel 1 (set "_gctm_rc=%errorlevel%" & goto :Main)
call :ValidateTagPlan
if errorlevel 1 (set "_gctm_rc=%errorlevel%" & goto :Main)
call :ShowPlan
if errorlevel 1 (set "_gctm_rc=%errorlevel%" & goto :Main)
set /p "app.git_create_tag.confirm=Type TAG to continue: "
if "%app.git_create_tag.confirm%"=="TAG" goto :_Main_create
echo.
echo Cancelled. Nothing was changed.
set "_gctm_rc=0" & goto :Main
:_Main_create
call :CreateTag
set "_gctm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gctm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ResolvePushChoice
:: Prompts for the push choice when it was not supplied.
::
:: Usage: call :ResolvePushChoice
::
:: Returns: 0 when valid
::          2 when invalid
:: Requires: :NormalizeYesNo
:: ============================================================
:ResolvePushChoice
for /f "tokens=1 delims==" %%v in ('set gctp_ 2^>nul') do set "%%v="
if defined _gctp_rc (set "_gctp_rc=" & exit /b %_gctp_rc%)
if defined app.git_create_tag.push (set "_gctp_rc=0" & goto :ResolvePushChoice)
set /p "app.git_create_tag.input=Push the tag to origin after creation? [y/N]: "
if /I "%app.git_create_tag.input%"=="y" set "app.git_create_tag.push=yes"
if /I "%app.git_create_tag.input%"=="yes" set "app.git_create_tag.push=yes"
if not defined app.git_create_tag.push set "app.git_create_tag.push=no"
call :NormalizeYesNo app.git_create_tag.push
if errorlevel 1 (echo ERROR: push must be yes or no. & set "_gctp_rc=2" & goto :ResolvePushChoice)
set "_gctp_rc=0" & goto :ResolvePushChoice
:: ============================================================
:: :ValidateTagPlan
:: Validates target, tag name, local and remote collisions, origin
:: reachability, and annotation defaults.
::
:: Usage: call :ValidateTagPlan
::
:: Returns: 0 when the plan is safe
::          1 when validation fails
:: Requires: git
:: ============================================================
:ValidateTagPlan
for /f "tokens=1 delims==" %%v in ('set gctv_ 2^>nul') do set "%%v="
if defined _gctv_rc (set "_gctv_rc=" & exit /b %_gctv_rc%)
git rev-parse --verify "%app.git_create_tag.target%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Tag target was not found or is not a commit: & echo   %app.git_create_tag.target% & set "_gctv_rc=1" & goto :ValidateTagPlan)
if not defined app.git_create_tag.name (echo ERROR: A tag name is required. & set "_gctv_rc=1" & goto :ValidateTagPlan)
git check-ref-format "refs/tags/%app.git_create_tag.name%" >nul 2>nul
if errorlevel 1 (echo ERROR: Invalid tag name: & echo   %app.git_create_tag.name% & set "_gctv_rc=1" & goto :ValidateTagPlan)
git show-ref --verify --quiet "refs/tags/%app.git_create_tag.name%"
if not errorlevel 1 (echo ERROR: A local tag already exists: & echo   %app.git_create_tag.name% & set "_gctv_rc=1" & goto :ValidateTagPlan)
if not defined app.git_create_tag.message set "app.git_create_tag.message=%app.git_create_tag.name%"
set "app.git_create_tag.origin="
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_create_tag.origin=%%A"
if not defined app.git_create_tag.origin goto :_ValidateTagPlan_no_origin
git ls-remote origin >nul 2>nul
if not errorlevel 1 goto :_ValidateTagPlan_remote_tag
if /I "%app.git_create_tag.push%"=="yes" (echo ERROR: origin could not be reached. & set "_gctv_rc=1" & goto :ValidateTagPlan)
echo WARNING: origin could not be reached.
echo Remote tag collision checking was skipped for this local-only tag.
goto :_ValidateTagPlan_dirty
:_ValidateTagPlan_remote_tag
set "app.git_create_tag.remote.exists="
for /f "delims=" %%A in ('git ls-remote --tags origin "refs/tags/%app.git_create_tag.name%" 2^>nul') do set "app.git_create_tag.remote.exists=1"
if defined app.git_create_tag.remote.exists (echo ERROR: A tag already exists on origin: & echo   %app.git_create_tag.name% & set "_gctv_rc=1" & goto :ValidateTagPlan)
goto :_ValidateTagPlan_dirty
:_ValidateTagPlan_no_origin
if /I "%app.git_create_tag.push%"=="yes" (echo ERROR: push was requested, but origin is not configured. & set "_gctv_rc=1" & goto :ValidateTagPlan)
:_ValidateTagPlan_dirty
set "app.git_create_tag.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_create_tag.dirty=1"
set "_gctv_rc=0" & goto :ValidateTagPlan
:: ============================================================
:: :ShowPlan
:: Displays the tag, target, annotation, push choice, and dirty-tree
:: warning.
::
:: Usage: call :ShowPlan
::
:: Returns: 0
:: Requires: git
:: ============================================================
:ShowPlan
echo.
echo Tag:
echo   %app.git_create_tag.name%
echo.
echo Target:
echo   %app.git_create_tag.target%
echo.
echo Message:
echo   %app.git_create_tag.message%
echo.
echo Push:
echo   %app.git_create_tag.push%
echo.
if not defined app.git_create_tag.dirty goto :_ShowPlan_done
echo WARNING: The working tree has local changes.
echo The tag still points only to committed content.
echo.
git status --short
echo.
:_ShowPlan_done
exit /b 0
:: ============================================================
:: :CreateTag
:: Creates the annotated tag and optionally pushes it to origin.
::
:: Usage: call :CreateTag
::
:: Returns: 0 on success
::          1 on creation or push failure
:: Requires: git
:: ============================================================
:CreateTag
for /f "tokens=1 delims==" %%v in ('set gctc_ 2^>nul') do set "%%v="
if defined _gctc_rc (set "_gctc_rc=" & exit /b %_gctc_rc%)
git tag -a "%app.git_create_tag.name%" "%app.git_create_tag.target%" -m "%app.git_create_tag.message%"
if errorlevel 1 (echo ERROR: Git could not create the tag. & set "_gctc_rc=1" & goto :CreateTag)
if /I "%app.git_create_tag.push%"=="yes" goto :_CreateTag_push
echo.
echo Tag created locally:
echo   %app.git_create_tag.name%
echo.
echo It has not been pushed.
set "_gctc_rc=0" & goto :CreateTag
:_CreateTag_push
git push origin "refs/tags/%app.git_create_tag.name%"
if errorlevel 1 goto :_CreateTag_push_failed
echo.
echo Tag created and pushed:
echo   %app.git_create_tag.name%
set "_gctc_rc=0" & goto :CreateTag
:_CreateTag_push_failed
echo.
echo ERROR: The tag was created locally, but the push failed.
echo Retry later with:
echo   git push origin "refs/tags/%app.git_create_tag.name%"
set "_gctc_rc=1" & goto :CreateTag
:: ============================================================
:: :ParseArgs
:: Parses tag name, message, target, push, and help arguments.
::
:: Usage: call :ParseArgs [name TAG] [message TEXT] [target REV] [push yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="name" goto :_ParseArgs_name
if /I "%~1"=="message" goto :_ParseArgs_message
if /I "%~1"=="target" goto :_ParseArgs_target
if /I "%~1"=="push" goto :_ParseArgs_push
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_create_tag.name (set "app.git_create_tag.name=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_name
if "%~2"=="" (echo ERROR: name requires a tag name. & exit /b 2)
set "app.git_create_tag.name=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_message
if "%~2"=="" (echo ERROR: message requires text. & exit /b 2)
set "app.git_create_tag.message=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_target
if "%~2"=="" (echo ERROR: target requires a commit, branch, or tag. & exit /b 2)
set "app.git_create_tag.target=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_push
if "%~2"=="" (echo ERROR: push requires yes or no. & exit /b 2)
set "app.git_create_tag.push=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_create_tag.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gcty_ 2^>nul') do set "%%v="
if defined _gcty_rc (set "_gcty_rc=" & exit /b %_gcty_rc%)
set "gcty_name=%~1"
call set "gcty_value=%%%gcty_name%%%"
if /I "%gcty_value%"=="y" set "%gcty_name%=yes"
if /I "%gcty_value%"=="yes" set "%gcty_name%=yes"
if /I "%gcty_value%"=="true" set "%gcty_name%=yes"
if /I "%gcty_value%"=="1" set "%gcty_name%=yes"
if /I "%gcty_value%"=="n" set "%gcty_name%=no"
if /I "%gcty_value%"=="no" set "%gcty_name%=no"
if /I "%gcty_value%"=="false" set "%gcty_name%=no"
if /I "%gcty_value%"=="0" set "%gcty_name%=no"
call set "gcty_value=%%%gcty_name%%%"
if /I "%gcty_value%"=="yes" (set "_gcty_rc=0" & goto :NormalizeYesNo)
if /I "%gcty_value%"=="no" (set "_gcty_rc=0" & goto :NormalizeYesNo)
set "_gcty_rc=1" & goto :NormalizeYesNo
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
echo git_create_tag.bat
echo.
echo Usage:
echo   git_create_tag.bat v1.0.0
echo   git_create_tag.bat name v1.0.0 message "First release"
echo   git_create_tag.bat name v1.0.0 target HEAD push yes
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
