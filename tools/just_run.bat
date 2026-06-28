@echo off
:: ============================================================
:: just_run.bat
:: Runs the configured project command, file, executable, or APK.
::
:: Usage: call tools\just_run.bat
::
:: Returns: 0 on success or when no run target is configured
::          1 on configuration, launch, adb, install, or app failure
:: Requires: _common.bat, :Main, :RunCommand, :RunFile, :RunExe,
::           :RunApk, :ResolveAdb, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.just_run.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :main
set "app.just_run.rc=%errorlevel%"
goto :end
:main
call :Main
set "app.just_run.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.just_run.rc%
:: ============================================================
:: :Main
:: Selects and runs the first configured project run target.
::
:: Usage: call :Main
::
:: Returns: selected run function exit code
::          0 when no run target is configured
:: Requires: :RunCommand, :RunFile, :RunExe, :RunApk
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set jrn_ 2^>nul') do set "%%v="
if defined _jrn_rc (set "_jrn_rc=" & exit /b %_jrn_rc%)
echo.
echo ============================================================
echo  Run project
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
if defined app.run_command goto :_Main_command
if defined app.run_file goto :_Main_file
if defined app.output_exe goto :_Main_exe
if defined app.output_apk goto :_Main_apk
echo This code-less demonstrator has no run target configured.
echo Configure app.run_command, app.run_file, app.output_exe,
echo or app.output_apk in build_config.bat for a runnable project.
echo.
set "_jrn_rc=0" & goto :Main
:_Main_command
call :RunCommand
set "_jrn_rc=%errorlevel%" & goto :Main
:_Main_file
call :RunFile
set "_jrn_rc=%errorlevel%" & goto :Main
:_Main_exe
call :RunExe
set "_jrn_rc=%errorlevel%" & goto :Main
:_Main_apk
call :RunApk
set "_jrn_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :RunCommand
:: Runs app.run_command through CALL.
::
:: Usage: call :RunCommand
::
:: Input:
::   app.run_command  command line to execute
::
:: Returns: configured command exit code
:: Requires: none
:: ============================================================
:RunCommand
for /f "tokens=1 delims==" %%v in ('set rcmd_ 2^>nul') do set "%%v="
if defined _rcmd_rc (set "_rcmd_rc=" & exit /b %_rcmd_rc%)
if not defined app.run_command (echo ERROR: app.run_command is not configured. & set "_rcmd_rc=1" & goto :RunCommand)
call %app.run_command%
set "_rcmd_rc=%errorlevel%" & goto :RunCommand
:: ============================================================
:: :RunFile
:: Opens the file configured by app.run_file.
::
:: Usage: call :RunFile
::
:: Input:
::   app.run_file  relative or absolute file path
::
:: Returns: START exit code, or 1 when the file is missing
:: Requires: start
:: ============================================================
:RunFile
for /f "tokens=1 delims==" %%v in ('set rfil_ 2^>nul') do set "%%v="
if defined _rfil_rc (set "_rfil_rc=" & exit /b %_rfil_rc%)
if not defined app.run_file (echo ERROR: app.run_file is not configured. & set "_rfil_rc=1" & goto :RunFile)
for %%A in ("%app.run_file%") do set "rfil_path=%%~fA"
if exist "%rfil_path%" goto :_RunFile_start
echo ERROR: app.run_file was not found:
echo   %rfil_path%
set "_rfil_rc=1" & goto :RunFile
:_RunFile_start
start "" "%rfil_path%"
set "_rfil_rc=%errorlevel%" & goto :RunFile
:: ============================================================
:: :RunExe
:: Starts the executable configured by app.output_exe.
::
:: Usage: call :RunExe
::
:: Input:
::   app.output_exe  relative or absolute executable path
::
:: Returns: START exit code, or 1 when the executable is missing
:: Requires: start
:: ============================================================
:RunExe
for /f "tokens=1 delims==" %%v in ('set rexe_ 2^>nul') do set "%%v="
if defined _rexe_rc (set "_rexe_rc=" & exit /b %_rexe_rc%)
if not defined app.output_exe (echo ERROR: app.output_exe is not configured. & set "_rexe_rc=1" & goto :RunExe)
for %%A in ("%app.output_exe%") do set "rexe_path=%%~fA"
if exist "%rexe_path%" goto :_RunExe_start
echo ERROR: app.output_exe was not found:
echo   %rexe_path%
set "_rexe_rc=1" & goto :RunExe
:_RunExe_start
start "" "%rexe_path%"
set "_rexe_rc=%errorlevel%" & goto :RunExe
:: ============================================================
:: :RunApk
:: Installs app.output_apk and optionally starts its activity.
::
:: Usage: call :RunApk
::
:: Input:
::   app.output_apk       relative or absolute APK path
::   app.launch_activity  optional Android component name
::
:: Returns: 0 on success
::          1 on missing APK, adb, install, or launch failure
:: Requires: :ResolveAdb
:: ============================================================
:RunApk
for /f "tokens=1 delims==" %%v in ('set rapk_ 2^>nul') do set "%%v="
if defined _rapk_rc (set "_rapk_rc=" & exit /b %_rapk_rc%)
if not defined app.output_apk (echo ERROR: app.output_apk is not configured. & set "_rapk_rc=1" & goto :RunApk)
for %%A in ("%app.output_apk%") do set "rapk_path=%%~fA"
if exist "%rapk_path%" goto :_RunApk_adb
echo ERROR: APK was not found:
echo   %rapk_path%
set "_rapk_rc=1" & goto :RunApk
:_RunApk_adb
call :ResolveAdb
if errorlevel 1 (set "_rapk_rc=%errorlevel%" & goto :RunApk)
call "%app.just_run.adb%" install -r "%rapk_path%"
if errorlevel 1 (echo ERROR: APK installation failed. & set "_rapk_rc=1" & goto :RunApk)
if not defined app.launch_activity (set "_rapk_rc=0" & goto :RunApk)
call "%app.just_run.adb%" shell am start -n "%app.launch_activity%"
if errorlevel 1 (echo ERROR: App launch failed. & set "_rapk_rc=1" & goto :RunApk)
set "_rapk_rc=0" & goto :RunApk
:: ============================================================
:: :ResolveAdb
:: Resolves adb.exe from configured SDK folders or PATH.
::
:: Usage: call :ResolveAdb
::
:: Input:
::   app.android_sdk_dir           optional preferred SDK folder
::   app.android_sdk_fallback_dir  optional fallback SDK folder
::
:: Output:
::   app.just_run.adb  resolved adb.exe path or command name
::
:: Returns: 0 when adb.exe is available
::          1 when adb.exe is unavailable
:: Requires: where
:: ============================================================
:ResolveAdb
for /f "tokens=1 delims==" %%v in ('set radb_ 2^>nul') do set "%%v="
if defined _radb_rc (set "_radb_rc=" & exit /b %_radb_rc%)
set "app.just_run.adb="
if defined app.android_sdk_dir if exist "%app.android_sdk_dir%\platform-tools\adb.exe" set "app.just_run.adb=%app.android_sdk_dir%\platform-tools\adb.exe"
if defined app.just_run.adb (set "_radb_rc=0" & goto :ResolveAdb)
if defined app.android_sdk_fallback_dir if exist "%app.android_sdk_fallback_dir%\platform-tools\adb.exe" set "app.just_run.adb=%app.android_sdk_fallback_dir%\platform-tools\adb.exe"
if defined app.just_run.adb (set "_radb_rc=0" & goto :ResolveAdb)
where adb.exe >nul 2>nul
if errorlevel 1 (echo ERROR: adb was not found. & set "_radb_rc=1" & goto :ResolveAdb)
set "app.just_run.adb=adb.exe"
set "_radb_rc=0" & goto :ResolveAdb
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when the outermost launcher is the cmd.exe /c target.
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
:: Detects whether the outermost launcher is running in an existing
:: interactive console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 when running in an existing console
::          1 when the outermost launcher is the cmd.exe /c target
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
