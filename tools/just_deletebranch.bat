@echo off
:: ============================================================
:: just_deletebranch.bat
:: Launches git_delete_branch.bat.
::
:: Usage: call tools\just_deletebranch.bat [arguments]
::
:: Returns: git_delete_branch.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_deletebranch.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_deletebranch.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_delete_branch.bat" %*
set "app.just_deletebranch.rc=%errorlevel%"
:end
exit /b %app.just_deletebranch.rc%
