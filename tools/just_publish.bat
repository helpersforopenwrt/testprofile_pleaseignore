@echo off
:: ============================================================
:: just_publish.bat
:: Reviews line endings, then starts the existing publish workflow.
::
:: This tools-level launcher is intended to live at:
::   tools\just_publish.bat
::
:: A generic root stub named just_publish.bat may call this file.
::
:: Before staging or committing, it calls:
::   tools\just_diff_check.bat
::
:: That helper:
::   - scans changed text files for line-ending mismatches
::   - offers Fix now, Skip once, or Ignore locally in future
::   - runs unstaged git diff --check
::   - runs staged git diff --cached --check
::
:: If the check succeeds, all original arguments are forwarded unchanged
:: to:
::   tools\git_commit_and_push_now.bat
::
:: Examples:
::   just_publish.bat
::   just_publish.bat message "Describe the update"
::   just_publish.bat fulldiff yes message "Describe the update"
::
:: Returns: line-ending/diff-check result when review fails
::          git_commit_and_push_now.bat result otherwise
:: Requires: tools\just_diff_check.bat
::           tools\git_commit_and_push_now.bat
:: ============================================================
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
if not defined GIT_PROJECT_ROOT for %%A in ("%~dp0..") do set "GIT_PROJECT_ROOT=%%~fA"
if exist "%~dp0just_diff_check.bat" goto :check
echo.
echo ERROR: Required pre-publish checker was not found:
echo   "%~dp0just_diff_check.bat"
echo.
exit /b 1
:check
call "%~dp0just_diff_check.bat"
set "just_publish_check_rc=%errorlevel%"
if "%just_publish_check_rc%"=="0" goto :publish
echo.
echo Publish stopped before staging or committing.
echo Fix or review the reported issue, then run just_publish.bat again.
echo.
exit /b %just_publish_check_rc%
:publish
if exist "%~dp0git_commit_and_push_now.bat" goto :publish_call
echo.
echo ERROR: Publish implementation was not found:
echo   "%~dp0git_commit_and_push_now.bat"
echo.
exit /b 1
:publish_call
call "%~dp0git_commit_and_push_now.bat" %*
set "just_publish_rc=%errorlevel%"
exit /b %just_publish_rc%
