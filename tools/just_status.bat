@echo off
:: ============================================================
:: just_status.bat
:: Launches git_status_check.bat.
::
:: Usage: call tools\just_status.bat [arguments]
::
:: Returns: git_status_check.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_status.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_status.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_status_check.bat" %*
set "app.just_status.rc=%errorlevel%"
:end
exit /b %app.just_status.rc%
