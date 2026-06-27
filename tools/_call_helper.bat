@echo off
setlocal EnableExtensions

set "HELPER_NAME=%~1"
if not defined HELPER_NAME (
    echo ERROR: No helper script name was supplied.
    exit /b 2
)

set "HELPER_PATH="

rem Required lookup order: project root first, then tools folder.
if exist "%CD%\%HELPER_NAME%" set "HELPER_PATH=%CD%\%HELPER_NAME%"
if not defined HELPER_PATH if defined app.tools_dir if exist "%CD%\%app.tools_dir%\%HELPER_NAME%" set "HELPER_PATH=%CD%\%app.tools_dir%\%HELPER_NAME%"
if not defined HELPER_PATH if exist "%CD%\tools\%HELPER_NAME%" set "HELPER_PATH=%CD%\tools\%HELPER_NAME%"

if not defined HELPER_PATH (
    echo.
    echo ERROR: Helper script was not found:
    echo   %HELPER_NAME%
    echo.
    echo Looked in:
    echo   %CD%
    echo   %CD%\%app.tools_dir%
    echo   %CD%\tools
    echo.
    exit /b 1
)

call "%HELPER_PATH%"
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
