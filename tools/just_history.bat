@echo off
:: ============================================================
:: just_history.bat
:: Launches git_show_history.bat.
::
:: Usage: call tools\just_history.bat [arguments]
::
:: Returns: git_show_history.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_history.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_history.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_show_history.bat" %*
set "app.just_history.rc=%errorlevel%"
:end
exit /b %app.just_history.rc%
