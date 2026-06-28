@echo off
:: ============================================================
:: just_short_help.bat
:: Launches git_help_short.bat.
::
:: Usage: call tools\just_short_help.bat [arguments]
::
:: Returns: git_help_short.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_short_help.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_short_help.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_help_short.bat" %*
set "app.just_short_help.rc=%errorlevel%"
:end
exit /b %app.just_short_help.rc%
