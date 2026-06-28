@echo off
:: ============================================================
:: just_branches.bat
:: Launches git_list_branches.bat.
::
:: Usage: call tools\just_branches.bat [arguments]
::
:: Returns: git_list_branches.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
set "app.just_branches.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_branches.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_list_branches.bat" %*
set "app.just_branches.rc=%errorlevel%"
:end
exit /b %app.just_branches.rc%
