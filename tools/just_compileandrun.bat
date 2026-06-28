@echo off
:: ============================================================
:: just_compileandrun.bat
:: Builds the project and runs it only when the build succeeds.
::
:: Usage: call tools\just_compileandrun.bat [run arguments]
::
:: Returns: build.bat or just_run.bat exit code
:: Requires: _common.bat, _call_helper.bat, project-root build.bat,
::           :Main, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
set "app.launch.path=%~f0"
set "app.launch.name=%~nx0"
set "app.just_compileandrun.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_compileandrun.rc=%errorlevel%"
goto :end
:main
call :Main %*
set "app.just_compileandrun.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.just_compileandrun.rc%
:: ============================================================
:: :Main
:: Runs build.bat nosync and then launches just_run.bat.
::
:: Usage: call :Main [run arguments]
::
:: Returns: build.bat or just_run.bat exit code
:: Requires: _call_helper.bat, project-root build.bat
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set jcr_ 2^>nul') do set "%%v="
if defined _jcr_rc (set "_jcr_rc=" & exit /b %_jcr_rc%)
if exist "%CD%\build.bat" goto :_Main_build
echo ERROR: build.bat was not found in the project root:
echo   %CD%
set "_jcr_rc=1" & goto :Main
:_Main_build
call "%CD%\build.bat" nosync
if not errorlevel 1 goto :_Main_run
echo Build failed. The project was not run.
set "_jcr_rc=%errorlevel%" & goto :Main
:_Main_run
call "%~dp0_call_helper.bat" "just_run.bat" %*
set "_jcr_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when this script is the cmd.exe /c launch target.
::
:: Usage: call :PauseIfNeeded
::
:: Returns: 0
:: Requires: :IsConsole
:: ============================================================
:PauseIfNeeded
for /f "tokens=1 delims==" %%v in ('set pif_ 2^>nul') do set "%%v="
if defined _pif_rc (set "_pif_rc=" & exit /b %_pif_rc%)
call :IsConsole
if not errorlevel 1 (set "_pif_rc=0" & goto :PauseIfNeeded)
echo.
pause
set "_pif_rc=0" & goto :PauseIfNeeded
:: ============================================================
:: :IsConsole
:: Detects whether this script is running in an existing console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 when running in an existing console
::          1 when this script is the cmd.exe /c launch target
:: Requires: find.exe
:: ============================================================
:IsConsole
setlocal EnableDelayedExpansion
set "ic_cmdline=!CMDCMDLINE!"
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I " /c " >nul
if errorlevel 1 (endlocal & exit /b 0)
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I "!app.launch.name!" >nul
if errorlevel 1 (endlocal & exit /b 0)
endlocal & exit /b 1
