@echo off
:: ============================================================
:: just_newbranch.bat
:: Launches git_create_branch.bat.
::
:: Usage: call tools\just_newbranch.bat [arguments]
::
:: Returns: git_create_branch.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_newbranch.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_newbranch.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_create_branch.bat" %*
set "app.just_newbranch.rc=%errorlevel%"
:end
exit /b %app.just_newbranch.rc%
