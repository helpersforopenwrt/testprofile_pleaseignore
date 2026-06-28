@echo off
:: ============================================================
:: just_pr.bat
:: Launches git_create_pull_request.bat.
::
:: Usage: call tools\just_pr.bat [arguments]
::
:: Returns: git_create_pull_request.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_pr.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_pr.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_create_pull_request.bat" %*
set "app.just_pr.rc=%errorlevel%"
:end
exit /b %app.just_pr.rc%
