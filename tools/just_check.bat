@echo off
:: ============================================================
:: just_check.bat
:: Runs the project build checks.
::
:: Usage: call tools\just_check.bat
::
:: Returns: build.bat exit code
:: Requires: _common.bat, project-root build.bat
:: ============================================================
:setup
set "app.just_check.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :check
set "app.just_check.rc=%errorlevel%"
goto :end
:check
if exist "%CD%\build.bat" goto :main
echo ERROR: build.bat was not found in the project root:
echo   %CD%
set "app.just_check.rc=1"
goto :end
:main
call "%CD%\build.bat" check
set "app.just_check.rc=%errorlevel%"
:end
exit /b %app.just_check.rc%
