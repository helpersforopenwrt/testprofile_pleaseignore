@echo off
:: ============================================================
:: just_restore.bat
:: Launches git_restore_file.bat.
::
:: Usage: call tools\just_restore.bat [arguments]
::
:: Returns: git_restore_file.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_restore.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_restore.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_restore_file.bat" %*
set "app.just_restore.rc=%errorlevel%"
:end
exit /b %app.just_restore.rc%
