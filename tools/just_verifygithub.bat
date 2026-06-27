@echo off
setlocal EnableExtensions
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)
call "%~dp0_call_helper.bat" "github_verify_clone.bat"
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
