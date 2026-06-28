@echo off
:: ============================================================
:: just_clone.bat
:: Launches git_clone_repository.bat.
::
:: Usage: call tools\just_clone.bat [arguments]
::
:: Returns: git_clone_repository.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
set "app.just_clone.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_clone.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_clone_repository.bat" %*
set "app.just_clone.rc=%errorlevel%"
:end
exit /b %app.just_clone.rc%
