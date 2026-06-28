@echo off
:: ============================================================
:: just_cleanpreview.bat
:: Launches git_clean_preview.bat.
::
:: Usage: call tools\just_cleanpreview.bat [arguments]
::
:: Returns: git_clean_preview.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
set "app.just_cleanpreview.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_cleanpreview.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_clean_preview.bat" %*
set "app.just_cleanpreview.rc=%errorlevel%"
:end
exit /b %app.just_cleanpreview.rc%
