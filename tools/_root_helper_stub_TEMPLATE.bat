@echo off
setlocal EnableExtensions

cd /d "%~dp0"
set "TARGET=%CD%\tools\%~nx0"

if not exist "%TARGET%" (
    echo.
    echo ERROR: Matching helper was not found:
    echo   %TARGET%
    echo.
    pause
    exit /b 1
)

call "%TARGET%" %*
set "RC=%ERRORLEVEL%"

endlocal & exit /b %RC%
