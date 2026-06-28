@echo off
:: ============================================================
:: just_verifygithub.bat
:: Launches github_verify_clone.bat.
::
:: Usage: call tools\just_verifygithub.bat [arguments]
::
:: Returns: github_verify_clone.bat exit code
:: Requires: _common.bat, _call_helper.bat
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_verifygithub.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_verifygithub.rc=%errorlevel%"
goto :end
:main
call "%~dp0_call_helper.bat" "github_verify_clone.bat" %*
set "app.just_verifygithub.rc=%errorlevel%"
:end
exit /b %app.just_verifygithub.rc%
