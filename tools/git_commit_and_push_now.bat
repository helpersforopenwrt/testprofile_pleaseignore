@echo off
:: ============================================================
:: git_commit_and_push_now.bat
:: Reviews all local changes, stages everything, validates the staged
:: result, creates one commit, pushes it, and displays final status.
::
:: Usage:
::   call tools\git_commit_and_push_now.bat
::   call tools\git_commit_and_push_now.bat message "Refactor helpers"
::   call tools\git_commit_and_push_now.bat message "Refactor helpers" fulldiff yes
::
:: Arguments:
::   message   Commit message.
::   fulldiff  yes or no. Default: no.
::
:: Workflow:
::   - show short status
::   - check unstaged and already-staged whitespace
::   - show unstaged and staged summaries
::   - require PUBLISH confirmation
::   - stage all changes
::   - show staged stat, name-status, and whitespace check
::   - show the full staged patch only when fulldiff yes is requested
::   - require COMMIT confirmation
::   - commit and push
::   - show final short branch status
::
:: Returns: 0 on successful commit and push, successful push-only,
::             cancellation before committing, or help
::          1 on Git, repository, validation, staging, commit, or push failure
::          2 on invalid arguments
:: Requires: _common.bat, git, :Main, :ParseArgs, :GetCommitMessage,
::           :PushCurrent, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_commit_push.message="
set "app.git_commit_push.fulldiff=no"
set "app.git_commit_push.dirty="
set "app.git_commit_push.staged="
set "app.git_commit_push.branch="
set "app.git_commit_push.confirm="
set "app.git_commit_push.help="
set "app.git_commit_push.rc=0"
call "%~dp0_common.bat" init
set "app.git_commit_push.rc=%errorlevel%"
if "%app.git_commit_push.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_commit_push.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_commit_push.rc%
:: ============================================================
:: :Main
:: Performs the complete guarded review, stage, commit, and push
:: workflow, or pushes pending commits when no files changed.
::
:: Usage: call :Main [message TEXT] [fulldiff yes|no]
::
:: Returns: 0 on success, cancellation, push-only success, or help
::          1 on Git, repository, validation, staging, commit, or push failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :GetCommitMessage, :PushCurrent, :ShowHelp, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcam_ 2^>nul') do set "%%v="
if defined _gcam_rc (set "_gcam_rc=" & exit /b %_gcam_rc%)
call :ParseArgs %*
set "_gcam_rc=%errorlevel%"
if not "%_gcam_rc%"=="0" goto :Main
if defined app.git_commit_push.help goto :_Main_help
call :NormalizeYesNo app.git_commit_push.fulldiff
if errorlevel 1 (echo ERROR: fulldiff must be yes or no. & set "_gcam_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Review, commit, and push
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gcam_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gcam_rc=1" & goto :Main)
echo Current status:
echo.
git status --short
set "_gcam_status_rc=%errorlevel%"
if not "%_gcam_status_rc%"=="0" (echo ERROR: Git status failed. & set "_gcam_rc=1" & goto :Main)
set "app.git_commit_push.dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "app.git_commit_push.dirty=1"
if defined app.git_commit_push.dirty goto :_Main_checks
echo No local file changes need to be committed.
echo Trying push in case local commits are pending...
echo.
call :PushCurrent
set "_gcam_rc=%errorlevel%" & goto :Main
:_Main_checks
echo.
echo Checking unstaged whitespace...
git diff --check
set "_gcam_check_rc=%errorlevel%"
if "%_gcam_check_rc%"=="0" goto :_Main_cached_check
echo.
echo ERROR: Unstaged changes contain whitespace errors.
echo Correct the reported lines before publishing.
set "_gcam_rc=1" & goto :Main
:_Main_cached_check
echo Checking already-staged whitespace...
git diff --cached --check
set "_gcam_check_rc=%errorlevel%"
if "%_gcam_check_rc%"=="0" goto :_Main_summary
echo.
echo ERROR: Already-staged changes contain whitespace errors.
echo Correct the reported lines before publishing.
set "_gcam_rc=1" & goto :Main
:_Main_summary
echo.
echo ============================================================
echo  Before staging
echo ============================================================
echo.
echo Unstaged diff summary:
git --no-pager diff --stat
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Unstaged diff summary failed. & set "_gcam_rc=1" & goto :Main)
echo.
echo Unstaged file status:
git --no-pager diff --name-status
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Unstaged name-status failed. & set "_gcam_rc=1" & goto :Main)
echo.
echo Already-staged diff summary:
git --no-pager diff --cached --stat
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Staged diff summary failed. & set "_gcam_rc=1" & goto :Main)
echo.
echo Already-staged file status:
git --no-pager diff --cached --name-status
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Staged name-status failed. & set "_gcam_rc=1" & goto :Main)
echo.
echo Untracked files are listed in the short status above.
echo.
set "app.git_commit_push.confirm="
set /p "app.git_commit_push.confirm=Type PUBLISH to stage all changes: "
if "%app.git_commit_push.confirm%"=="PUBLISH" goto :_Main_stage
echo.
echo Cancelled. Nothing new was staged, committed, or pushed.
set "_gcam_rc=0" & goto :Main
:_Main_stage
git add --all
set "_gcam_stage_rc=%errorlevel%"
if "%_gcam_stage_rc%"=="0" goto :_Main_staged_exists
echo ERROR: git add --all failed.
set "_gcam_rc=1" & goto :Main
:_Main_staged_exists
git diff --cached --quiet
if errorlevel 1 goto :_Main_staged_check
echo.
echo No staged changes remain after staging.
echo Nothing was committed.
set "_gcam_rc=0" & goto :Main
:_Main_staged_check
echo.
echo Checking final staged whitespace...
git diff --cached --check
set "_gcam_check_rc=%errorlevel%"
if "%_gcam_check_rc%"=="0" goto :_Main_staged_review
echo.
echo ERROR: Final staged changes contain whitespace errors.
echo.
echo The changes remain staged so you can correct or inspect them.
set "_gcam_rc=1" & goto :Main
:_Main_staged_review
echo.
echo ============================================================
echo  Final staged review
echo ============================================================
echo.
echo Staged diff summary:
git --no-pager diff --cached --stat
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Final staged diff summary failed. & set "_gcam_rc=1" & goto :Main)
echo.
echo Staged file status:
git --no-pager diff --cached --name-status
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Final staged name-status failed. & set "_gcam_rc=1" & goto :Main)
echo.
if /I "%app.git_commit_push.fulldiff%"=="yes" goto :_Main_full_diff
echo Full staged diff was skipped.
echo Use fulldiff yes when the complete patch is specifically needed.
goto :_Main_after_full_diff
:_Main_full_diff
echo Full staged diff:
echo.
git --no-pager diff --cached
set "_gcam_diff_rc=%errorlevel%"
if not "%_gcam_diff_rc%"=="0" (echo ERROR: Full staged diff failed. & set "_gcam_rc=1" & goto :Main)
:_Main_after_full_diff
echo.
call :GetCommitMessage
set "_gcam_message_rc=%errorlevel%"
if not "%_gcam_message_rc%"=="0" (set "_gcam_rc=%_gcam_message_rc%" & goto :Main)
set "app.git_commit_push.confirm="
set /p "app.git_commit_push.confirm=Type COMMIT to commit and push these staged changes: "
if "%app.git_commit_push.confirm%"=="COMMIT" goto :_Main_commit
echo.
echo Cancelled before commit.
echo The reviewed changes remain staged.
set "_gcam_rc=0" & goto :Main
:_Main_commit
git commit -m "%app.git_commit_push.message%"
set "_gcam_commit_rc=%errorlevel%"
if "%_gcam_commit_rc%"=="0" goto :_Main_push
echo ERROR: git commit failed.
set "_gcam_rc=1" & goto :Main
:_Main_push
call :PushCurrent
set "_gcam_push_rc=%errorlevel%"
if "%_gcam_push_rc%"=="0" goto :_Main_success
echo.
echo ERROR: The commit was saved locally, but push failed.
echo Retry later with:
echo   just_push.bat
echo.
echo Current status:
git status --short --branch
set "_gcam_rc=1" & goto :Main
:_Main_success
echo.
echo ============================================================
echo  Publish complete
echo ============================================================
echo.
git status --short --branch
set "_gcam_status_rc=%errorlevel%"
if "%_gcam_status_rc%"=="0" (set "_gcam_rc=0" & goto :Main)
echo WARNING: Commit and push succeeded, but final status failed.
set "_gcam_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_gcam_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :GetCommitMessage
:: Prompts for a commit message when none was supplied and creates
:: a timestamped default when Enter is pressed.
::
:: Usage: call :GetCommitMessage
::
:: Output:
::   app.git_commit_push.message  final commit message
::
:: Returns: 0
:: Requires: none
:: ============================================================
:GetCommitMessage
for /f "tokens=1 delims==" %%v in ('set gcag_ 2^>nul') do set "%%v="
if defined _gcag_rc (set "_gcag_rc=" & exit /b %_gcag_rc%)
if defined app.git_commit_push.message (set "_gcag_rc=0" & goto :GetCommitMessage)
set /p "app.git_commit_push.message=Commit message, or press Enter for default: "
if defined app.git_commit_push.message (set "_gcag_rc=0" & goto :GetCommitMessage)
set "app.git_commit_push.message=Manual save %APP_DISPLAY_NAME% %DATE% %TIME%"
set "_gcag_rc=0" & goto :GetCommitMessage
:: ============================================================
:: :PushCurrent
:: Pushes the current named branch. It uses the configured upstream
:: or creates origin tracking when no upstream exists.
::
:: Usage: call :PushCurrent
::
:: Returns: 0 on success
::          1 when branch, origin, or push validation fails
:: Requires: git
:: ============================================================
:PushCurrent
for /f "tokens=1 delims==" %%v in ('set gcap_ 2^>nul') do set "%%v="
if defined _gcap_rc (set "_gcap_rc=" & exit /b %_gcap_rc%)
set "app.git_commit_push.branch="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_commit_push.branch=%%A"
if defined app.git_commit_push.branch goto :_PushCurrent_tracking
echo ERROR: A named branch is not checked out.
set "_gcap_rc=1" & goto :PushCurrent
:_PushCurrent_tracking
git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>nul
if errorlevel 1 goto :_PushCurrent_new_tracking
git push
set "_gcap_push_rc=%errorlevel%"
if "%_gcap_push_rc%"=="0" goto :_PushCurrent_success
echo ERROR: Push failed.
set "_gcap_rc=1" & goto :PushCurrent
:_PushCurrent_new_tracking
git remote get-url origin >nul 2>nul
if not errorlevel 1 goto :_PushCurrent_push_origin
echo ERROR: No upstream branch or origin remote is configured.
set "_gcap_rc=1" & goto :PushCurrent
:_PushCurrent_push_origin
git push -u origin "%app.git_commit_push.branch%"
set "_gcap_push_rc=%errorlevel%"
if "%_gcap_push_rc%"=="0" goto :_PushCurrent_success
echo ERROR: Push failed.
set "_gcap_rc=1" & goto :PushCurrent
:_PushCurrent_success
echo Push complete.
set "_gcap_rc=0" & goto :PushCurrent
:: ============================================================
:: :ParseArgs
:: Parses an optional commit message, full-diff option, and help.
::
:: Usage: call :ParseArgs [message TEXT] [fulldiff yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="message" goto :_ParseArgs_message
if /I "%~1"=="fulldiff" goto :_ParseArgs_fulldiff
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_commit_push.message (set "app.git_commit_push.message=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_message
if "%~2"=="" (echo ERROR: message requires text. & exit /b 2)
set "app.git_commit_push.message=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_fulldiff
if "%~2"=="" (echo ERROR: fulldiff requires yes or no. & exit /b 2)
set "app.git_commit_push.fulldiff=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_commit_push.help=1"
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
:: Displays the complete guarded publish workflow.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_commit_and_push_now.bat
echo.
echo Usage:
echo   git_commit_and_push_now.bat
echo   git_commit_and_push_now.bat message "Refactor helpers"
echo   git_commit_and_push_now.bat message "Refactor helpers" fulldiff yes
echo.
echo The helper reviews changes, stages everything, validates the
echo final staged result, commits after confirmation, pushes, and
echo displays final branch status.
echo.
echo The complete patch is skipped by default to avoid paging or
echo flooding the console. fulldiff yes prints it without a pager.
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
