@echo off
:: ============================================================
:: just_build.bat
:: Runs the project build without synchronizing first.
::
:: Usage: call tools\just_build.bat
::
:: Returns: build.bat exit code
:: Requires: _common.bat, project-root build.bat
:: ============================================================
:setup
set "app.just_build.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :check
set "app.just_build.rc=%errorlevel%"
goto :end
:check
if exist "%CD%\build.bat" goto :main
echo ERROR: build.bat was not found in the project root:
echo   %CD%
set "app.just_build.rc=1"
goto :end
:main
call "%CD%\build.bat" nosync
set "app.just_build.rc=%errorlevel%"
:end
exit /b %app.just_build.rc%
