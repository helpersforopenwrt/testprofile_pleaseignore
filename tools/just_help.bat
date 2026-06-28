@echo off
:: ============================================================
:: just_help.bat
:: Launches the complete Git and GitHub helper reference.
::
:: Usage: call tools\just_help.bat [arguments]
::
:: Returns: git_help.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_help.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_help.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_help.bat" %*
set "app.just_help.rc=%errorlevel%"
:end
exit /b %app.just_help.rc%
