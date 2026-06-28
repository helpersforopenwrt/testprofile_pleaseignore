@echo off
:: ============================================================
:: just_stash.bat
:: Launches git_stash_changes.bat.
::
:: Usage: call tools\just_stash.bat [arguments]
::
:: Returns: git_stash_changes.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_stash.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_stash.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_stash_changes.bat" %*
set "app.just_stash.rc=%errorlevel%"
:end
exit /b %app.just_stash.rc%
