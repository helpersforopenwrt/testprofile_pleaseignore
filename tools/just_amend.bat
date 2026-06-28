@echo off
:: ============================================================
:: just_amend.bat
:: Launches git_amend_last_commit.bat.
::
:: Usage: call tools\just_amend.bat [arguments]
::
:: Returns: git_amend_last_commit.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
set "app.just_amend.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_amend.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_amend_last_commit.bat" %*
set "app.just_amend.rc=%errorlevel%"
:end
exit /b %app.just_amend.rc%
