@echo off
:: ============================================================
:: just_backup.bat
:: Launches git_backup_bundle.bat.
::
:: Usage: call tools\just_backup.bat [arguments]
::
:: Returns: git_backup_bundle.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
set "app.just_backup.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_backup.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_backup_bundle.bat" %*
set "app.just_backup.rc=%errorlevel%"
:end
exit /b %app.just_backup.rc%
