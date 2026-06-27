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
call "%CD%\build.bat" check
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
