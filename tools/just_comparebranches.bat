@echo off
:: ============================================================
:: just_comparebranches.bat
:: Launches git_compare_branches.bat.
::
:: Usage: call tools\just_comparebranches.bat [arguments]
::
:: Returns: git_compare_branches.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
set "app.just_comparebranches.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_comparebranches.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_compare_branches.bat" %*
set "app.just_comparebranches.rc=%errorlevel%"
:end
exit /b %app.just_comparebranches.rc%
