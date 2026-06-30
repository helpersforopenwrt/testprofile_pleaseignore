@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if not exist "build.bat" (
    echo ERROR: build.bat was not found in:
    echo %CD%
    echo.
    pause
    exit /b 1
)

call build.bat nopush

endlocal
exit /b %ERRORLEVEL%