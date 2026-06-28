@echo off
:: ============================================================
:: just_undo.bat
:: Launches git_undo_last_commit.bat.
::
:: Usage: call tools\just_undo.bat [arguments]
::
:: Returns: git_undo_last_commit.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_undo.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_undo.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "git_undo_last_commit.bat" %*
set "app.just_undo.rc=%errorlevel%"
:end
exit /b %app.just_undo.rc%
