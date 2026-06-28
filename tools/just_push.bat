@echo off
:: ============================================================
:: just_push.bat
:: Launches git_push_local.bat.
::
:: Usage: call tools\just_push.bat [arguments]
::
:: Returns: git_push_local.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_push.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_push.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_push_local.bat" %*
set "app.just_push.rc=%errorlevel%"
:end
exit /b %app.just_push.rc%
