@echo off
:: ============================================================
:: just_publish.bat
:: Dispatches directly to git_commit_and_push_now.bat while
:: preserving every command-line argument and the exit code.
::
:: Usage: call tools\just_publish.bat [message TEXT]
::
:: Returns: git_commit_and_push_now.bat exit code
:: Requires: git_commit_and_push_now.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_publish.target=%~dp0git_commit_and_push_now.bat"
set "app.just_publish.rc=0"
if exist "%app.just_publish.target%" goto :run
echo ERROR: Publish implementation not found:
echo   "%app.just_publish.target%"
set "app.just_publish.rc=1"
goto :end
:run
call "%app.just_publish.target%" %*
set "app.just_publish.rc=%errorlevel%"
:end
exit /b %app.just_publish.rc%
