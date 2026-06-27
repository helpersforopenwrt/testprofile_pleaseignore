@echo off
setlocal EnableExtensions

rem This is a no-op demonstrator build script.
rem A real project can replace it while keeping the helper interface.

set "MODE=%~1"
if not defined MODE set "MODE=build"

echo.
echo ============================================================
echo  testprofile_pleaseignore demonstrator build
echo ============================================================
echo.
echo Folder:
echo   %CD%
echo.
echo Mode:
echo   %MODE%
echo.

if /I "%MODE%"=="check" (
    echo Configuration check complete.
    echo This demonstrator has no source code to compile.
    echo.
    exit /b 0
)

if /I "%MODE%"=="nosync" (
    echo No-op build complete.
    echo No commit or push was performed.
    echo.
    exit /b 0
)

echo No-op build complete.
echo This demonstrator has no source code to compile.
echo.
exit /b 0
