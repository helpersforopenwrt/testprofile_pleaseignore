@echo off
:: ============================================================
:: git_amend_last_commit.bat
:: Amends the most recent local commit without force-pushing.
::
:: Usage:
::   call tools\git_amend_last_commit.bat
::   call tools\git_amend_last_commit.bat message "Corrected message"
::   call tools\git_amend_last_commit.bat stage yes
::   call tools\git_amend_last_commit.bat allowpushed yes
::
:: Returns: 0 on success or cancellation
::          1 on repository, safety, staging, or commit failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :CheckPushedState, :AnalyzeChanges,
::           :ShowPlan, :AmendCommit, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_amend.message="
set "app.git_amend.stage=no"
set "app.git_amend.allowpushed=no"
set "app.git_amend.hasstaged="
set "app.git_amend.haschanges="
set "app.git_amend.tracking="
set "app.git_amend.pushed="
set "app.git_amend.confirm="
set "app.git_amend.help="
set "app.git_amend.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_amend.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_amend.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_amend.rc%
:: ============================================================
:: :Main
:: Parses options, validates repository safety, previews the amend,
:: requests confirmation, and performs the amend.
::
:: Usage: call :Main [message TEXT] [stage yes|no] [allowpushed yes|no]
::
:: Returns: 0 on success or cancellation
::          1 on repository, safety, staging, or commit failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :CheckPushedState,
::           :AnalyzeChanges, :ShowPlan, :AmendCommit, :ShowHelp
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set galm_ 2^>nul') do set "%%v="
if defined _galm_rc (set "_galm_rc=" & exit /b %_galm_rc%)
call :ParseArgs %*
if errorlevel 1 (set "_galm_rc=%errorlevel%" & goto :Main)
if defined app.git_amend.help goto :_Main_help
call :NormalizeYesNo app.git_amend.stage
if errorlevel 1 (echo ERROR: stage must be yes or no. & set "_galm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_amend.allowpushed
if errorlevel 1 (echo ERROR: allowpushed must be yes or no. & set "_galm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Amend last commit
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_galm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_galm_rc=1" & goto :Main)
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: The repository has no commit to amend. & set "_galm_rc=1" & goto :Main)
call :CheckPushedState
if errorlevel 1 (set "_galm_rc=%errorlevel%" & goto :Main)
call :AnalyzeChanges
if errorlevel 1 (set "_galm_rc=%errorlevel%" & goto :Main)
call :ShowPlan
if errorlevel 1 (set "_galm_rc=%errorlevel%" & goto :Main)
set /p "app.git_amend.confirm=Type AMEND to continue: "
if "%app.git_amend.confirm%"=="AMEND" goto :_Main_amend
echo.
echo Cancelled. Nothing was changed.
set "_galm_rc=0" & goto :Main
:_Main_amend
call :AmendCommit
set "_galm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_galm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :CheckPushedState
:: Determines whether HEAD appears on the upstream branch and
:: enforces the allowpushed safety option.
::
:: Usage: call :CheckPushedState
::
:: Output:
::   app.git_amend.tracking  upstream branch name when configured
::   app.git_amend.pushed    defined when HEAD appears upstream
::
:: Returns: 0 when amending may continue
::          1 when pushed-history protection blocks the amend
:: Requires: git
:: ============================================================
:CheckPushedState
for /f "tokens=1 delims==" %%v in ('set galp_ 2^>nul') do set "%%v="
if defined _galp_rc (set "_galp_rc=" & exit /b %_galp_rc%)
set "app.git_amend.tracking="
set "app.git_amend.pushed="
for /f "delims=" %%A in ('git rev-parse --abbrev-ref --symbolic-full-name @{u} 2^>nul') do set "app.git_amend.tracking=%%A"
if not defined app.git_amend.tracking (set "_galp_rc=0" & goto :CheckPushedState)
git merge-base --is-ancestor HEAD @{u} >nul 2>nul
if not errorlevel 1 set "app.git_amend.pushed=1"
if not defined app.git_amend.pushed (set "_galp_rc=0" & goto :CheckPushedState)
if /I "%app.git_amend.allowpushed%"=="yes" goto :_CheckPushedState_allowed
echo.
echo ERROR: The current commit appears to exist on:
echo   %app.git_amend.tracking%
echo.
echo Amending it rewrites history. This helper refuses by default.
echo To proceed locally anyway, use:
echo   git_amend_last_commit.bat allowpushed yes
echo.
echo The helper will never force-push.
set "_galp_rc=1" & goto :CheckPushedState
:_CheckPushedState_allowed
echo.
echo WARNING: The commit appears to have been pushed.
echo The helper will amend locally but will not force-push.
set "_galp_rc=0" & goto :CheckPushedState
:: ============================================================
:: :AnalyzeChanges
:: Determines whether working-tree or staged changes exist and
:: verifies that the requested amend has something to change.
::
:: Usage: call :AnalyzeChanges
::
:: Output:
::   app.git_amend.haschanges  defined when any local change exists
::   app.git_amend.hasstaged   staged or planned
::
:: Returns: 0 when an amend is meaningful
::          1 when there is nothing to amend
:: Requires: git
:: ============================================================
:AnalyzeChanges
for /f "tokens=1 delims==" %%v in ('set gala_ 2^>nul') do set "%%v="
if defined _gala_rc (set "_gala_rc=" & exit /b %_gala_rc%)
set "app.git_amend.haschanges="
set "app.git_amend.hasstaged="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_amend.haschanges=1"
if /I "%app.git_amend.stage%"=="yes" goto :_AnalyzeChanges_stage
git diff --cached --quiet
if errorlevel 1 set "app.git_amend.hasstaged=1"
goto :_AnalyzeChanges_validate
:_AnalyzeChanges_stage
if defined app.git_amend.haschanges set "app.git_amend.hasstaged=planned"
:_AnalyzeChanges_validate
if defined app.git_amend.hasstaged (set "_gala_rc=0" & goto :AnalyzeChanges)
if defined app.git_amend.message (set "_gala_rc=0" & goto :AnalyzeChanges)
echo.
echo ERROR: There are no staged changes and no new message.
echo Nothing needs to be amended.
echo.
echo Use stage yes to include current changes, or provide message text.
set "_gala_rc=1" & goto :AnalyzeChanges
:: ============================================================
:: :ShowPlan
:: Displays the current commit and the planned amend.
::
:: Usage: call :ShowPlan
::
:: Returns: 0
:: Requires: git
:: ============================================================
:ShowPlan
for /f "tokens=1 delims==" %%v in ('set gals_ 2^>nul') do set "%%v="
if defined _gals_rc (set "_gals_rc=" & exit /b %_gals_rc%)
echo.
echo Current last commit:
git log -1 --oneline
echo.
echo Stage all current changes:
echo   %app.git_amend.stage%
echo.
if defined app.git_amend.message goto :_ShowPlan_message
echo Commit message:
echo   keep existing message
goto :_ShowPlan_changes
:_ShowPlan_message
echo New message:
echo   %app.git_amend.message%
:_ShowPlan_changes
echo.
if /I "%app.git_amend.stage%"=="yes" goto :_ShowPlan_all_changes
echo Staged changes that will be included:
echo.
git diff --cached --stat
goto :_ShowPlan_notes
:_ShowPlan_all_changes
echo Changes that will be staged and included:
echo.
git status --short
:_ShowPlan_notes
echo.
if /I "%app.git_amend.stage%"=="no" if defined app.git_amend.haschanges echo Note: unstaged changes remain outside the amended commit.
if defined app.git_amend.pushed echo WARNING: Local history will differ from the remote afterward.
echo.
set "_gals_rc=0" & goto :ShowPlan
:: ============================================================
:: :AmendCommit
:: Optionally stages all changes and amends the latest commit.
::
:: Usage: call :AmendCommit
::
:: Returns: 0 on success
::          1 on staging or commit failure
:: Requires: git
:: ============================================================
:AmendCommit
for /f "tokens=1 delims==" %%v in ('set galc_ 2^>nul') do set "%%v="
if defined _galc_rc (set "_galc_rc=" & exit /b %_galc_rc%)
if /I not "%app.git_amend.stage%"=="yes" goto :_AmendCommit_commit
git add --all
if errorlevel 1 (echo ERROR: git add --all failed. & set "_galc_rc=1" & goto :AmendCommit)
:_AmendCommit_commit
if defined app.git_amend.message goto :_AmendCommit_message
git commit --amend --no-edit
goto :_AmendCommit_result
:_AmendCommit_message
git commit --amend -m "%app.git_amend.message%"
:_AmendCommit_result
if errorlevel 1 (echo. & echo ERROR: Git could not amend the commit. & set "_galc_rc=1" & goto :AmendCommit)
echo.
echo Commit amended successfully:
git log -1 --oneline
echo.
if defined app.git_amend.pushed echo WARNING: No force-push was attempted.
set "_galc_rc=0" & goto :AmendCommit
:: ============================================================
:: :ParseArgs
:: Parses message, stage, allowpushed, and help arguments.
::
:: Usage: call :ParseArgs [message TEXT] [stage yes|no] [allowpushed yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="message" goto :_ParseArgs_message
if /I "%~1"=="stage" goto :_ParseArgs_stage
if /I "%~1"=="allowpushed" goto :_ParseArgs_allowpushed
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_message
if "%~2"=="" (echo ERROR: message requires text. & exit /b 2)
set "app.git_amend.message=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_stage
if "%~2"=="" (echo ERROR: stage requires yes or no. & exit /b 2)
set "app.git_amend.stage=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_allowpushed
if "%~2"=="" (echo ERROR: allowpushed requires yes or no. & exit /b 2)
set "app.git_amend.allowpushed=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_amend.help=1"
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
for /f "tokens=1 delims==" %%v in ('set galn_ 2^>nul') do set "%%v="
if defined _galn_rc (set "_galn_rc=" & exit /b %_galn_rc%)
set "galn_name=%~1"
call set "galn_value=%%%galn_name%%%"
if /I "%galn_value%"=="y" set "%galn_name%=yes"
if /I "%galn_value%"=="yes" set "%galn_name%=yes"
if /I "%galn_value%"=="true" set "%galn_name%=yes"
if /I "%galn_value%"=="1" set "%galn_name%=yes"
if /I "%galn_value%"=="n" set "%galn_name%=no"
if /I "%galn_value%"=="no" set "%galn_name%=no"
if /I "%galn_value%"=="false" set "%galn_name%=no"
if /I "%galn_value%"=="0" set "%galn_name%=no"
call set "galn_value=%%%galn_name%%%"
if /I "%galn_value%"=="yes" (set "_galn_rc=0" & goto :NormalizeYesNo)
if /I "%galn_value%"=="no" (set "_galn_rc=0" & goto :NormalizeYesNo)
set "_galn_rc=1" & goto :NormalizeYesNo
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
echo git_amend_last_commit.bat
echo.
echo Usage:
echo   git_amend_last_commit.bat message "Corrected message"
echo   git_amend_last_commit.bat stage yes
echo   git_amend_last_commit.bat allowpushed yes
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
