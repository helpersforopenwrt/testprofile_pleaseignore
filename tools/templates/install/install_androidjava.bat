@echo off
:setup
:: ============================================================
:: install.bat
:: Installs a dated FoodSnap APK produced by build.bat.
::
:: Batch style:
::   - no delayed expansion
::   - no setlocal
::   - documented functions
::   - one empty line between documented functions
::   - no empty lines inside functions
::
:: Default behavior:
::   install.bat
::     Finds newest build_*\FoodSnap-debug.apk and installs it.
::     If no APK exists, runs build.bat, then installs the new APK.
::
:: Logs:
::   Install logs are written into the build folder being installed from:
::     build_YYYY-MM-DD.HHhmm.ss\install.YYYY-MM-DD.HHhmm.ss.log
::
:: Optional:
::   install.bat run
::   install.bat apk path\to\app.apk
::   install.bat build build_YYYY-MM-DD.HHhmm.ss
::   install.bat help
:: ============================================================
cd /d "%~dp0"
set "app.rc=0"
set "app.root=%CD%"
set "app.timestamp="
set "app.log="
set "app.config.file=build_config.bat"
set "app.apk.name=FoodSnap-debug.apk"
set "app.apk="
set "app.request.apk="
set "app.request.build="
set "app.build.folder="
set "app.mode=install"
set "app.help="
set "app.adb="
set "app.prepare.ran="
set "app.build.ran="
set "app.package.name="
set "app.launch.activity="
set "app.esc="
set "app.color.reset=0m"
set "app.color.red=31m"
set "app.color.green=32m"
set "app.color.yellow=33m"
set "app.color.cyan=36m"
:main
call :InitializeConsole || (call :SetAppRcFromErrorLevel & goto :end)
call :MakeTimestamp || (call :SetAppRcFromErrorLevel & goto :end)
call :ParseArgs %* || (call :SetAppRcFromErrorLevel & goto :end)
if defined app.help (call :ShowHelp & set "app.rc=0" & goto :end)
call :LoadBuildConfig || (call :SetAppRcFromErrorLevel & goto :end)
call :ApplyEnvFile
call :FindInstallApk
if errorlevel 1 call :BuildMissingApk
if errorlevel 1 (call :SetAppRcFromErrorLevel & goto :end)
call :InitializeInstallLog || (call :SetAppRcFromErrorLevel & goto :end)
call :ResolveAdb
if errorlevel 1 call :PrepareMissingAdb
if errorlevel 1 (call :SetAppRcFromErrorLevel & goto :end)
call :CheckAdbDevice || (call :SetAppRcFromErrorLevel & goto :end)
call :InstallApk || (call :SetAppRcFromErrorLevel & goto :end)
if /I "%app.mode%"=="run" (call :RunApp || (call :SetAppRcFromErrorLevel & goto :end))
set "app.rc=0"
:end
exit /b %app.rc%

:: ============================================================
:: Function: InitializeConsole
:: Usage: call :InitializeConsole
:: Purpose: initializes ANSI escape support for status colors.
:: Returns:
::   0 always
:: ============================================================
:InitializeConsole
call :SetESC app.esc
if errorlevel 1 set "app.esc="
if /I "%app.esc%"=="rem" set "app.esc="
exit /b 0

:: ============================================================
:: Function: SetAppRcFromErrorLevel
:: Usage: call :SetAppRcFromErrorLevel
:: Purpose: preserves the current ERRORLEVEL into app.rc.
:: Returns:
::   0 always
:: ============================================================
:SetAppRcFromErrorLevel
set "sarfel_rc=%errorlevel%"
if "%sarfel_rc%"=="0" set "sarfel_rc=1"
set "app.rc=%sarfel_rc%"
set "sarfel_rc="
exit /b 0

:: ============================================================
:: Function: MakeTimestamp
:: Usage: call :MakeTimestamp
:: Purpose: creates app.timestamp in YYYY-MM-DD.HHhmm.ss format.
:: Returns:
::   0 timestamp created
::   1 timestamp failed
:: ============================================================
:MakeTimestamp
set "app.timestamp="
for /f %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=Get-Date; '{0:yyyy-MM-dd}.{0:HH}h{0:mm}.{0:ss}' -f $d"') do set "app.timestamp=%%A"
if defined app.timestamp exit /b 0
echo FAIL: could not create timestamp.
exit /b 1

:: ============================================================
:: Function: ParseArgs
:: Usage: call :ParseArgs %*
:: Purpose: parses install.bat command-line arguments.
:: Accepted:
::   run
::   apk file.apk
::   build build_folder
::   help, /help, --help, /?
:: Returns:
::   0 success
::   2 invalid argument
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="run" (set "app.mode=run" & shift & goto :ParseArgs)
if /I "%~1"=="apk" goto :ParseArgsApk
if /I "%~1"=="build" goto :ParseArgsBuild
if /I "%~1"=="help" (set "app.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="/help" (set "app.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="--help" (set "app.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="/?" (set "app.help=1" & shift & goto :ParseArgs)
call :Red FAIL: unknown argument: %~1
exit /b 2
:ParseArgsApk
if "%~2"=="" (call :Red FAIL: apk requires a file path. & exit /b 2)
set "app.request.apk=%~2"
shift
shift
goto :ParseArgs
:ParseArgsBuild
if "%~2"=="" (call :Red FAIL: build requires a build folder. & exit /b 2)
set "app.request.build=%~2"
shift
shift
goto :ParseArgs

:: ============================================================
:: Function: ShowHelp
:: Usage: call :ShowHelp
:: Purpose: prints install.bat usage and settings.
:: Returns:
::   0 always
:: ============================================================
:ShowHelp
call :Green FoodSnap install.bat
echo.
call :Yellow Usage:
echo   install.bat
echo   install.bat run
echo   install.bat apk path\to\FoodSnap-debug.apk
echo   install.bat build build_YYYY-MM-DD.HHhmm.ss
echo   install.bat help
echo.
call :Yellow Behavior:
echo   Finds newest build_*\%app.apk.name%
echo   Runs build.bat if no APK exists
echo   Runs prepare.bat if adb is missing
echo   Installs with adb install -r
echo   Logs into the build folder being installed from
echo.
call :Yellow Active settings:
echo   APK name: %app.apk.name%
echo   Config:   %app.config.file%
exit /b 0

:: ============================================================
:: Function: LoadBuildConfig
:: Usage: call :LoadBuildConfig
:: Purpose: loads build_config.bat when present and resolves APK/launch defaults.
:: Returns:
::   0 success
::   2 config failed
:: ============================================================
:LoadBuildConfig
if not exist "%app.config.file%" goto :LoadBuildConfigDefaults
call "%app.config.file%"
if errorlevel 1 (call :Red FAIL: Config failed: %app.config.file% & exit /b 2)
:LoadBuildConfigDefaults
if defined app.name set "app.apk.name=%app.name%-debug.apk"
if defined app.package_name set "app.package.name=%app.package_name%"
if not defined app.package.name set "app.package.name=org.foodsnap"
if defined app.launch_activity set "app.launch.activity=%app.launch_activity%"
if not defined app.launch.activity set "app.launch.activity=%app.package.name%/.MainActivity"
exit /b 0

:: ============================================================
:: Function: ApplyEnvFile
:: Usage: call :ApplyEnvFile
:: Purpose: applies env.bat when present.
:: Returns:
::   0 always
:: ============================================================
:ApplyEnvFile
if exist env.bat call env.bat >nul 2>nul
exit /b 0

:: ============================================================
:: Function: FindInstallApk
:: Usage: call :FindInstallApk
:: Purpose: finds the requested or newest installable APK.
:: Returns:
::   0 APK found
::   1 APK missing
:: ============================================================
:FindInstallApk
set "app.apk="
set "app.build.folder="
if defined app.request.apk goto :FindInstallApkRequestedFile
if defined app.request.build goto :FindInstallApkRequestedBuild
for /f "delims=" %%D in ('dir /b /ad /o-n "build_*" 2^>nul') do call :TryBuildFolderForApk "%%D"
if defined app.apk (call :Green OK: Found APK: %app.apk% & exit /b 0)
call :Yellow MISS: APK not found: build_*\%app.apk.name%
exit /b 1
:FindInstallApkRequestedFile
if exist "%app.request.apk%" for %%A in ("%app.request.apk%") do set "app.apk=%%~fA"
if defined app.apk for %%A in ("%app.apk%") do set "app.build.folder=%%~dpA"
if defined app.build.folder if "%app.build.folder:~-1%"=="\" set "app.build.folder=%app.build.folder:~0,-1%"
if defined app.apk (call :Green OK: Found APK: %app.apk% & exit /b 0)
call :Red FAIL: requested APK does not exist: %app.request.apk%
exit /b 1
:FindInstallApkRequestedBuild
if exist "%app.request.build%\%app.apk.name%" for %%A in ("%app.request.build%\%app.apk.name%") do set "app.apk=%%~fA"
if defined app.apk for %%A in ("%app.request.build%") do set "app.build.folder=%%~fA"
if defined app.apk (call :Green OK: Found APK: %app.apk% & exit /b 0)
call :Red FAIL: requested build folder does not contain %app.apk.name%: %app.request.build%
exit /b 1

:: ============================================================
:: Function: TryBuildFolderForApk
:: Usage: call :TryBuildFolderForApk "folder"
:: Purpose: sets app.apk from the first matching dated build folder.
:: Input:
::   %~1 build folder
:: Returns:
::   0 always
:: ============================================================
:TryBuildFolderForApk
if defined app.apk exit /b 0
if not exist "%~1\%app.apk.name%" exit /b 0
for %%A in ("%~1\%app.apk.name%") do set "app.apk=%%~fA"
for %%A in ("%~1") do set "app.build.folder=%%~fA"
exit /b 0

:: ============================================================
:: Function: BuildMissingApk
:: Usage: call :BuildMissingApk
:: Purpose: runs build.bat when no installable APK is available.
:: Returns:
::   0 APK created/found
::   4 build failed or APK still missing
:: ============================================================
:BuildMissingApk
if defined app.request.apk exit /b 1
if defined app.request.build exit /b 1
if not exist build.bat (call :Red FAIL: build.bat not found. & exit /b 4)
call :Yellow DO: Running build.bat because no installable APK was found.
call build.bat
if errorlevel 1 (call :Red FAIL: build.bat failed. & exit /b 4)
set "app.build.ran=1"
call :FindInstallApk
if errorlevel 1 (call :Red FAIL: build finished, but no APK was found. & exit /b 4)
exit /b 0

:: ============================================================
:: Function: InitializeInstallLog
:: Usage: call :InitializeInstallLog
:: Purpose: creates the install log inside the build folder being installed from.
:: Returns:
::   0 log ready
::   1 log failed
:: ============================================================
:InitializeInstallLog
if not defined app.build.folder for %%A in ("%app.apk%") do set "app.build.folder=%%~dpA"
if defined app.build.folder if "%app.build.folder:~-1%"=="\" set "app.build.folder=%app.build.folder:~0,-1%"
if not defined app.build.folder (call :Red FAIL: could not resolve install log folder. & exit /b 1)
if not exist "%app.build.folder%\" (call :Red FAIL: install log folder does not exist: %app.build.folder% & exit /b 1)
set "app.log=%app.build.folder%\install.%app.timestamp%.log"
break > "%app.log%"
call :WriteLogHeader
call :Cyan LOG: %app.log%
exit /b 0

:: ============================================================
:: Function: WriteLogHeader
:: Usage: call :WriteLogHeader
:: Purpose: writes the install log header.
:: Returns:
::   0 always
:: ============================================================
:WriteLogHeader
>>"%app.log%" echo FoodSnap install log
>>"%app.log%" echo Timestamp: %app.timestamp%
>>"%app.log%" echo Root: %app.root%
>>"%app.log%" echo Build folder: %app.build.folder%
>>"%app.log%" echo Log: %app.log%
>>"%app.log%" echo APK name: %app.apk.name%
>>"%app.log%" echo APK: %app.apk%
exit /b 0

:: ============================================================
:: Function: ResolveAdb
:: Usage: call :ResolveAdb
:: Purpose: locates adb.exe, preferring tools\adb over the SDK copy.
:: Returns:
::   0 adb found
::   1 adb missing
:: ============================================================
:ResolveAdb
set "app.adb="
if exist "tools\adb\platform-tools\adb.exe" for %%A in ("tools\adb\platform-tools\adb.exe") do set "app.adb=%%~fA"
if not defined app.adb if exist "tools\android-sdk\platform-tools\adb.exe" for %%A in ("tools\android-sdk\platform-tools\adb.exe") do set "app.adb=%%~fA"
if not defined app.adb if defined ADB_HOME if exist "%ADB_HOME%\platform-tools\adb.exe" for %%A in ("%ADB_HOME%\platform-tools\adb.exe") do set "app.adb=%%~fA"
if not defined app.adb if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" for %%A in ("%ANDROID_HOME%\platform-tools\adb.exe") do set "app.adb=%%~fA"
if not defined app.adb if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" for %%A in ("%ANDROID_SDK_ROOT%\platform-tools\adb.exe") do set "app.adb=%%~fA"
if not defined app.adb for %%P in (adb.exe) do set "app.adb=%%~$PATH:P"
if defined app.adb (call :Green OK: Found adb: %app.adb% & exit /b 0)
call :Yellow MISS: adb.exe not found.
exit /b 1

:: ============================================================
:: Function: PrepareMissingAdb
:: Usage: call :PrepareMissingAdb
:: Purpose: runs prepare.bat when adb is missing, then retries adb resolution.
:: Returns:
::   0 adb found
::   5 adb still missing or prepare failed
:: ============================================================
:PrepareMissingAdb
if not exist prepare.bat (call :Red FAIL: prepare.bat not found; cannot install adb. & exit /b 5)
call :Yellow DO: Running prepare.bat because adb is missing.
call :Yellow LOG: %app.log%
call prepare.bat >> "%app.log%" 2>&1
if errorlevel 1 (call :Red FAIL: prepare.bat failed. & call :Yellow LOG: %app.log% & exit /b 5)
set "app.prepare.ran=1"
call :ApplyEnvFile
call :ResolveAdb
if errorlevel 1 (call :Red FAIL: adb is still missing after prepare.bat. & call :Yellow LOG: %app.log% & exit /b 5)
exit /b 0

:: ============================================================
:: Function: CheckAdbDevice
:: Usage: call :CheckAdbDevice
:: Purpose: verifies that adb can see a device.
:: Returns:
::   0 device available
::   6 no usable device
:: ============================================================
:CheckAdbDevice
call :Cyan DO: Checking adb device.
"%app.adb%" get-state >> "%app.log%" 2>&1
if errorlevel 1 (call :Red FAIL: no Android device is ready for adb. & call :Yellow TRY: adb devices & call :Yellow LOG: %app.log% & exit /b 6)
call :Green OK: Device ready.
exit /b 0

:: ============================================================
:: Function: InstallApk
:: Usage: call :InstallApk
:: Purpose: installs app.apk with adb install -r.
:: Returns:
::   0 installed
::   6 install failed
:: ============================================================
:InstallApk
call :Cyan DO: Installing %app.apk.name%.
>>"%app.log%" echo APK: %app.apk%
"%app.adb%" install -r "%app.apk%" >> "%app.log%" 2>&1
if errorlevel 1 (call :Red FAIL: adb install failed. & call :Yellow APK: %app.apk% & call :Yellow LOG: %app.log% & exit /b 6)
call :Green OK: Installed %app.apk.name%.
exit /b 0

:: ============================================================
:: Function: RunApp
:: Usage: call :RunApp
:: Purpose: launches the configured Android activity.
:: Returns:
::   0 launched or skipped
::   6 launch failed
:: ============================================================
:RunApp
if not defined app.launch.activity (call :Yellow WARN: app.launch.activity is not set; launch skipped. & exit /b 0)
call :Cyan DO: Launching %app.launch.activity%.
"%app.adb%" shell am start -n "%app.launch.activity%" >> "%app.log%" 2>&1
if errorlevel 1 (call :Red FAIL: app launch failed: %app.launch.activity% & call :Yellow LOG: %app.log% & exit /b 6)
call :Green OK: Launched.
exit /b 0

:: ============================================================
:: Function: SetESC
:: Usage: call :SetESC outputVariable
:: Purpose: captures the ANSI escape character into a variable.
:: Input:
::   %~1 output variable name
:: Returns:
::   0 success
::   2 missing output variable
:: ============================================================
:SetESC
set "se_out=%~1"
if not defined se_out exit /b 2
for /f %%a in ('echo prompt $E^| cmd') do set "%se_out%=%%a"
set "se_out="
exit /b 0

:: ============================================================
:: Function: WriteLogLine
:: Usage: call :WriteLogLine message
:: Purpose: writes a line to app.log when app.log is defined.
:: Returns:
::   0 always
:: ============================================================
:WriteLogLine
if defined app.log if exist "%app.log%" >>"%app.log%" echo %*
exit /b 0

:: ============================================================
:: Function: Green
:: Usage: call :Green message
:: Purpose: prints a green status line.
:: Returns:
::   0 always
:: ============================================================
:Green
if defined app.esc (echo %app.esc%[%app.color.green%%*%app.esc%[%app.color.reset%) else (echo %*)
call :WriteLogLine %*
exit /b 0

:: ============================================================
:: Function: Yellow
:: Usage: call :Yellow message
:: Purpose: prints a yellow status line.
:: Returns:
::   0 always
:: ============================================================
:Yellow
if defined app.esc (echo %app.esc%[%app.color.yellow%%*%app.esc%[%app.color.reset%) else (echo %*)
call :WriteLogLine %*
exit /b 0

:: ============================================================
:: Function: Red
:: Usage: call :Red message
:: Purpose: prints a red status line.
:: Returns:
::   0 always
:: ============================================================
:Red
if defined app.esc (echo %app.esc%[%app.color.red%%*%app.esc%[%app.color.reset%) else (echo %*)
call :WriteLogLine %*
exit /b 0

:: ============================================================
:: Function: Cyan
:: Usage: call :Cyan message
:: Purpose: prints a cyan status line.
:: Returns:
::   0 always
:: ============================================================
:Cyan
if defined app.esc (echo %app.esc%[%app.color.cyan%%*%app.esc%[%app.color.reset%) else (echo %*)
call :WriteLogLine %*
exit /b 0
