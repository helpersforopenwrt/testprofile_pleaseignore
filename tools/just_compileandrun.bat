@echo off
setlocal EnableExtensions
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)
if not exist "%CD%\build.bat" (
    echo ERROR: build.bat was not found in the project root:
    echo   %CD%
    pause
    exit /b 1
)

call "%CD%\build.bat" nosync
if errorlevel 1 (
    echo Build failed. The project was not run.
    pause
    exit /b 1
)

call "%~dp0_call_helper.bat" "just_run.bat"
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
