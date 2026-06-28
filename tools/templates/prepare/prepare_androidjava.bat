@echo off
:setup
:: ============================================================
:: prepare.bat
:: Local Android / Java bootstrapper for FoodSnap-style projects.
::
:: Batch style:
::   - no delayed expansion
::   - no setlocal
::   - one empty line between documented functions
::   - no empty lines inside functions
::   - :setup, :main, and :end are structural labels, not functions
::
:: Variable style:
::   - global script variables use app.* pseudo-object names
::   - function-internal variables use an acronym prefix from the function name
::   - ANSI constants are created by :SetAppColors under app.color.*
::
:: User-modifiable settings:
::   JDK provider defaults to Temurin.
::   To use Oracle JDK instead, comment the Temurin line and uncomment Oracle.
::
::   Android SDK packages are installed by tools\GetAndroidSDK.bat.
::   ADB is installed by tools\GetADB.bat into tools\adb.
:: ============================================================
set "app.jdk.vendor=temurin"
:: set "app.jdk.vendor=oracle"
set "app.jdk.min.bytes=100000000"
set "app.jdk.url.temurin=https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
set "app.jdk.url.oracle=https://download.oracle.com/java/17/latest/jdk-17_windows-x64_bin.zip"
cd /d "%~dp0"
for %%A in ("%CD%") do set "app.root=%%~fA"
set "app.drive=%CD:~0,1%"
set "app.tools=%app.root%\tools"
set "app.downloads=%app.tools%\downloads"
set "app.env=%app.root%\env.bat"
set "app.log=%app.root%\prepare.log"
set "app.get.android.sdk=%app.tools%\GetAndroidSDK.bat"
set "app.get.adb=%app.tools%\GetADB.bat"
set "app.android.platform.tools.version=current"
set "app.android.platform.tools.revision="
set "app.android.platform.version=22"
set "app.android.platform.revision="
set "app.android.buildtools.version=28.0.3"
set "app.android.buildtools.revision="
set "app.android.cmdline.tools.version=latest"
set "app.android.cmdline.tools.revision="
set "app.adb.version=current"
set "app.adb.revision="
set "app.android.api=%app.android.platform.version%"
set "app.buildtools.version=%app.android.buildtools.version%"
set "app.jdk.root=%app.tools%\jdk"
set "app.jdk.extract=%app.downloads%\jdk"
set "app.sdk.store=%app.downloads%\android-sdk"
set "app.sdk=%app.tools%\android-sdk"
set "app.cmdtools=%app.sdk%\cmdline-tools\%app.android.cmdline.tools.version%"
set "app.sdkmanager=%app.cmdtools%\bin\sdkmanager.bat"
set "app.buildtools=%app.sdk%\build-tools\%app.android.buildtools.version%"
set "app.android.jar=%app.sdk%\platforms\android-%app.android.platform.version%\android.jar"
set "app.adb.root=%app.tools%\adb"
set "app.adb=%app.adb.root%\platform-tools\adb.exe"
set "app.force="
set "app.help="
set "app.rc=0"
set "app.java.home="
set "app.versioned.jdk="
set "app.found.jdk="
set "app.found.name="
set "app.jdk.url="
set "app.jdk.zip="
set "app.last.rc=0"
set "app.ready=1"
set "app.esc="
:main
call :InitializeConsoleColors
call :ParseArgs %*
set "app.rc=%errorlevel%"
if "%app.rc%"=="0" call :ResolveConfiguredJDKProvider
if "%app.rc%"=="0" set "app.rc=%errorlevel%"
if "%app.rc%"=="0" if defined app.help call :ShowHelp
if "%app.rc%"=="0" if defined app.help set "app.rc=%errorlevel%"
if "%app.rc%"=="0" if not defined app.help call :PrepareFoodSnapAndroidBuildTools
if "%app.rc%"=="0" if not defined app.help set "app.rc=%errorlevel%"
:end
exit /b %app.rc%

:: ============================================================
:: Function: InitializeConsoleColors
:: Usage: call :InitializeConsoleColors
:: Purpose: initializes ANSI escape support and app.color.* constants.
:: Returns:
::   0 always
:: ============================================================
:InitializeConsoleColors
call :SetESC app.esc
if errorlevel 1 set "app.esc="
if /I "%app.esc%"=="rem" set "app.esc="
call :SetAppColors
exit /b 0

:: ============================================================
:: Function: ResolveConfiguredJDKProvider
:: Usage: call :ResolveConfiguredJDKProvider
:: Purpose: resolves the configured FoodSnap JDK provider into URL and ZIP path.
:: Settings:
::   app.jdk.vendor=temurin
::   app.jdk.vendor=oracle
:: Returns:
::   0 provider resolved
::   2 unknown provider
:: ============================================================
:ResolveConfiguredJDKProvider
set "app.jdk.url="
set "app.jdk.zip="
if /I "%app.jdk.vendor%"=="temurin" set "app.jdk.url=%app.jdk.url.temurin%"
if /I "%app.jdk.vendor%"=="temurin" set "app.jdk.zip=%app.downloads%\temurin-jdk17-win64.zip"
if /I "%app.jdk.vendor%"=="oracle" set "app.jdk.url=%app.jdk.url.oracle%"
if /I "%app.jdk.vendor%"=="oracle" set "app.jdk.zip=%app.downloads%\oracle-jdk17-win64.zip"
if defined app.jdk.url exit /b 0
call :Red FAIL: unknown JDK provider: %app.jdk.vendor%
call :Yellow SETTING: app.jdk.vendor must be temurin or oracle
exit /b 2

:: ============================================================
:: Function: ParseArgs
:: Usage: call :ParseArgs %*
:: Purpose: parses command-line arguments.
:: Accepted:
::   force
::   alwaysdownload
::   /force
::   --force
::   help
::   /help
::   --help
::   /?
:: Returns:
::   0 success
::   2 unrecognized argument
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="force" ( set "app.force=1" & shift & goto :ParseArgs )
if /I "%~1"=="alwaysdownload" ( set "app.force=1" & shift & goto :ParseArgs )
if /I "%~1"=="/force" ( set "app.force=1" & shift & goto :ParseArgs )
if /I "%~1"=="--force" ( set "app.force=1" & shift & goto :ParseArgs )
if /I "%~1"=="help" ( set "app.help=1" & shift & goto :ParseArgs )
if /I "%~1"=="/help" ( set "app.help=1" & shift & goto :ParseArgs )
if /I "%~1"=="--help" ( set "app.help=1" & shift & goto :ParseArgs )
if /I "%~1"=="/?" ( set "app.help=1" & shift & goto :ParseArgs )
call :Red FAIL: unrecognized argument: %~1
exit /b 2

:: ============================================================
:: Function: ShowHelp
:: Usage: call :ShowHelp
:: Purpose: prints usage, command-line arguments, and setup settings.
:: Returns:
::   0 always
:: ============================================================
:ShowHelp
call :Green FoodSnap prepare.bat
echo.
call :Yellow Usage:
echo   prepare.bat
echo   prepare.bat force
echo   prepare.bat alwaysdownload
echo   prepare.bat help
echo.
call :Yellow Arguments:
echo   force            Re-run preparation checks and repair missing pieces.
echo   alwaysdownload   Alias for force, kept for compatibility.
echo   help             Show this help.
echo   /help            Show this help.
echo   --help           Show this help.
echo   /?               Show this help.
echo.
call :Yellow JDK settings in :setup:
echo   app.jdk.vendor=%app.jdk.vendor%
echo     Supported values: temurin, oracle
echo     Default: temurin
echo     To switch to Oracle, edit :setup:
echo       :: set "app.jdk.vendor=temurin"
echo       set "app.jdk.vendor=oracle"
echo   app.jdk.min.bytes=%app.jdk.min.bytes%
echo.
call :Yellow Android SDK helper:
echo   Helper:    %app.get.android.sdk%
echo   SDK root:  %app.sdk%
echo   SDK store: %app.sdk.store%
echo.
call :Yellow Android SDK package settings:
echo   PlatformTools version:  %app.android.platform.tools.version%
echo   PlatformTools revision: %app.android.platform.tools.revision%
echo   Platforms version:      %app.android.platform.version%
echo   Platforms revision:     %app.android.platform.revision%
echo   BuildTools version:     %app.android.buildtools.version%
echo   BuildTools revision:    %app.android.buildtools.revision%
echo   CmdlineTools version:   %app.android.cmdline.tools.version%
echo   CmdlineTools revision:  %app.android.cmdline.tools.revision%
echo.
call :Yellow ADB helper:
echo   Helper:       %app.get.adb%
echo   ADB root:     %app.adb.root%
echo   ADB exe:      %app.adb%
echo   ADB version:  %app.adb.version%
echo   ADB revision: %app.adb.revision%
echo.
call :Yellow Active paths:
echo   Root:      %app.root%
echo   Tools:     %app.tools%
echo   Downloads: %app.downloads%
echo   Log:       %app.log%
echo   Env file:  %app.env%
echo.
call :Yellow Active JDK:
echo   Provider:  %app.jdk.vendor%
echo   URL:       %app.jdk.url%
echo   ZIP:       %app.jdk.zip%
echo   Extract:   %app.jdk.extract%
echo   Link:      %app.jdk.root%
echo.
call :Yellow Required Android build files:
echo   %app.android.jar%
echo   %app.buildtools%\aapt.exe
echo   %app.buildtools%\zipalign.exe
echo   %app.buildtools%\lib\d8.jar
echo   %app.buildtools%\lib\apksigner.jar
echo.
call :Yellow Required ADB file:
echo   %app.adb%
exit /b 0

:: ============================================================
:: Function: PrepareFoodSnapAndroidBuildTools
:: Usage: call :PrepareFoodSnapAndroidBuildTools
:: Purpose: high-level FoodSnap Android build tools preparation workflow.
:: Returns:
::   0 tools ready
::   1 prepare failed
:: ============================================================
:PrepareFoodSnapAndroidBuildTools
set "app.ready=1"
call :CheckFoodSnapBuildToolsReady >nul 2>nul
if not errorlevel 1 set "app.ready=0"
if defined app.force set "app.ready=1"
if "%app.ready%"=="0" call :ApplyFoodSnapBuildEnvironment
if "%app.ready%"=="0" if not exist "%app.env%" call :WriteFoodSnapEnvFile
if "%app.ready%"=="0" call :Green OK: FoodSnap build tools already ready.
if "%app.ready%"=="0" exit /b 0
if not exist "%app.tools%\" mkdir "%app.tools%" >nul 2>&1
if not exist "%app.downloads%\" mkdir "%app.downloads%" >nul 2>&1
break > "%app.log%"
if defined app.force call :Yellow DO: forced refresh.
call :EnsureFoodSnapJDK
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :ReportPrepareFailed
if not "%app.last.rc%"=="0" exit /b %app.last.rc%
call :EnsureFoodSnapAndroidSDKPackages
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :ReportPrepareFailed
if not "%app.last.rc%"=="0" exit /b %app.last.rc%
call :EnsureFoodSnapADB
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :ReportPrepareFailed
if not "%app.last.rc%"=="0" exit /b %app.last.rc%
call :CheckFoodSnapBuildToolsReady >nul 2>nul
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :Red FAIL: prepare finished, but required files are still missing.
if not "%app.last.rc%"=="0" call :ExplainMissingFoodSnapBuildTools
if not "%app.last.rc%"=="0" exit /b 1
call :ApplyFoodSnapBuildEnvironment
call :WriteFoodSnapEnvFile
call :Green OK: FoodSnap build tools ready.
exit /b 0

:: ============================================================
:: Function: ReportPrepareFailed
:: Usage: call :ReportPrepareFailed
:: Purpose: prints a standard prepare failure message using app.last.rc.
:: Returns:
::   0 always
:: ============================================================
:ReportPrepareFailed
if "%app.last.rc%"=="0" set "app.last.rc=1"
call :Red FAIL: prepare failed with exit code %app.last.rc%.
call :Yellow LOG: %app.log%
exit /b 0

:: ============================================================
:: Function: FindFoodSnapLocalJavaHome
:: Usage: call :FindFoodSnapLocalJavaHome
:: Purpose: checks whether the FoodSnap local project JDK is usable.
:: Output:
::   app.java.home set when usable
:: Returns:
::   0 local JDK found
::   1 local JDK missing or incomplete
:: ============================================================
:FindFoodSnapLocalJavaHome
set "app.java.home="
if exist "%app.jdk.root%\bin\javac.exe" set "app.java.home=%app.jdk.root%"
if not defined app.java.home exit /b 1
if not exist "%app.java.home%\bin\java.exe" exit /b 1
if not exist "%app.java.home%\bin\jar.exe" exit /b 1
if not exist "%app.java.home%\bin\keytool.exe" exit /b 1
exit /b 0

:: ============================================================
:: Function: CheckFoodSnapBuildToolsReady
:: Usage: call :CheckFoodSnapBuildToolsReady
:: Purpose: checks whether all required FoodSnap build tools are present.
:: Returns:
::   0 ready
::   1 one or more required tools missing
:: ============================================================
:CheckFoodSnapBuildToolsReady
call :FindFoodSnapLocalJavaHome || exit /b 1
call :CheckFoodSnapAndroidSDKPackagesOnly || exit /b 1
call :CheckFoodSnapADBOnly || exit /b 1
exit /b 0

:: ============================================================
:: Function: CheckFoodSnapAndroidSDKPackagesOnly
:: Usage: call :CheckFoodSnapAndroidSDKPackagesOnly
:: Purpose: checks FoodSnap Android SDK build packages only.
:: Returns:
::   0 Android SDK packages ready
::   1 one or more Android SDK packages missing
:: ============================================================
:CheckFoodSnapAndroidSDKPackagesOnly
if not exist "%app.sdk%\" exit /b 1
if not exist "%app.sdkmanager%" exit /b 1
if not exist "%app.android.jar%" exit /b 1
if not exist "%app.buildtools%\aapt.exe" exit /b 1
if not exist "%app.buildtools%\zipalign.exe" exit /b 1
if not exist "%app.buildtools%\lib\d8.jar" if not exist "%app.buildtools%\lib\dx.jar" exit /b 1
if not exist "%app.buildtools%\lib\apksigner.jar" if not exist "%app.buildtools%\apksigner.bat" exit /b 1
exit /b 0

:: ============================================================
:: Function: CheckFoodSnapADBOnly
:: Usage: call :CheckFoodSnapADBOnly
:: Purpose: checks whether standalone ADB exists under tools\adb.
:: Returns:
::   0 ADB ready
::   1 ADB missing
:: ============================================================
:CheckFoodSnapADBOnly
if exist "%app.adb%" exit /b 0
exit /b 1

:: ============================================================
:: Function: ExplainMissingFoodSnapBuildTools
:: Usage: call :ExplainMissingFoodSnapBuildTools
:: Purpose: prints required FoodSnap build files that are currently missing.
:: Returns:
::   0 always
:: ============================================================
:ExplainMissingFoodSnapBuildTools
call :FindFoodSnapLocalJavaHome >nul 2>nul
if not defined app.java.home call :Yellow MISS: %app.jdk.root%\bin\javac.exe
if defined app.java.home if not exist "%app.java.home%\bin\java.exe" call :Yellow MISS: %app.java.home%\bin\java.exe
if defined app.java.home if not exist "%app.java.home%\bin\jar.exe" call :Yellow MISS: %app.java.home%\bin\jar.exe
if defined app.java.home if not exist "%app.java.home%\bin\keytool.exe" call :Yellow MISS: %app.java.home%\bin\keytool.exe
if not exist "%app.sdkmanager%" call :Yellow MISS: %app.sdkmanager%
if not exist "%app.android.jar%" call :Yellow MISS: %app.android.jar%
if not exist "%app.buildtools%\aapt.exe" call :Yellow MISS: %app.buildtools%\aapt.exe
if not exist "%app.buildtools%\zipalign.exe" call :Yellow MISS: %app.buildtools%\zipalign.exe
if not exist "%app.buildtools%\lib\d8.jar" if not exist "%app.buildtools%\lib\dx.jar" call :Yellow MISS: %app.buildtools%\lib\d8.jar or dx.jar
if not exist "%app.buildtools%\lib\apksigner.jar" if not exist "%app.buildtools%\apksigner.bat" call :Yellow MISS: %app.buildtools%\lib\apksigner.jar or apksigner.bat
if not exist "%app.adb%" call :Yellow MISS: %app.adb%
call :Yellow LOG: %app.log%
exit /b 0

:: ============================================================
:: Function: EnsureFoodSnapJDK
:: Usage: call :EnsureFoodSnapJDK
:: Purpose: installs or normalizes the configured FoodSnap JDK.
:: Returns:
::   0 JDK ready
::   1 JDK install failed
:: ============================================================
:EnsureFoodSnapJDK
call :FindFoodSnapLocalJavaHome >nul 2>nul
if not errorlevel 1 exit /b 0
call :NormalizeNestedFoodSnapJDK
call :FindFoodSnapLocalJavaHome >nul 2>nul
if not errorlevel 1 call :Green OK: JDK ready.
if not errorlevel 1 exit /b 0
call :FindExtractedFoodSnapJDK
if defined app.versioned.jdk call :LinkOrMoveJDK
set "app.last.rc=%errorlevel%"
if defined app.versioned.jdk if not "%app.last.rc%"=="0" exit /b %app.last.rc%
if defined app.versioned.jdk if exist "%app.jdk.zip%" del /Q "%app.jdk.zip%" >> "%app.log%" 2>&1
if defined app.versioned.jdk call :Green OK: JDK ready.
if defined app.versioned.jdk exit /b 0
call :Download "%app.jdk.url%" "%app.jdk.zip%" "%app.jdk.vendor% JDK" %app.jdk.min.bytes% || exit /b 1
call :RequireFreeSpace 750000000 "JDK extraction" || exit /b 1
call :Yellow DO: extracting JDK.
if exist "%app.jdk.extract%\" rmdir /S /Q "%app.jdk.extract%" >> "%app.log%" 2>&1
mkdir "%app.jdk.extract%" >> "%app.log%" 2>&1
call :Unzip "%app.jdk.zip%" "%app.jdk.extract%"
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :Red FAIL: JDK unzip failed.
if not "%app.last.rc%"=="0" call :Yellow FILE: %app.jdk.zip%
if not "%app.last.rc%"=="0" call :Yellow LOG: %app.log%
if not "%app.last.rc%"=="0" exit /b 1
call :FindExtractedFoodSnapJDK
if not defined app.versioned.jdk call :Red FAIL: javac.exe was not found after extracting JDK.
if not defined app.versioned.jdk call :Yellow DIR: %app.jdk.extract%
if not defined app.versioned.jdk call :Yellow LOG: %app.log%
if not defined app.versioned.jdk exit /b 1
call :LinkOrMoveJDK || exit /b 1
if exist "%app.jdk.zip%" del /Q "%app.jdk.zip%" >> "%app.log%" 2>&1
call :Green OK: JDK ready.
exit /b 0

:: ============================================================
:: Function: NormalizeNestedFoodSnapJDK
:: Usage: call :NormalizeNestedFoodSnapJDK
:: Purpose: fixes a FoodSnap JDK accidentally placed under tools\jdk\jdk-*.
:: Returns:
::   0 normalized or already normal
::   1 no nested JDK found or normalization failed
:: ============================================================
:NormalizeNestedFoodSnapJDK
set "app.found.jdk="
set "app.found.name="
if exist "%app.jdk.root%\bin\javac.exe" exit /b 0
for /D %%D in ("%app.jdk.root%\jdk-*") do if exist "%%~fD\bin\javac.exe" set "app.found.jdk=%%~fD"
if not defined app.found.jdk exit /b 1
for %%D in ("%app.found.jdk%") do set "app.found.name=%%~nxD"
if not defined app.found.name exit /b 1
call :Yellow DO: normalizing JDK.
if not exist "%app.jdk.extract%\" mkdir "%app.jdk.extract%" >> "%app.log%" 2>&1
call :MoveNestedFoodSnapJDKToExtractFolder
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :Red FAIL: could not move JDK into downloads.
if not "%app.last.rc%"=="0" call :Yellow FROM: %app.found.jdk%
if not "%app.last.rc%"=="0" call :Yellow TO: %app.jdk.extract%
if not "%app.last.rc%"=="0" call :Yellow LOG: %app.log%
if not "%app.last.rc%"=="0" exit /b 1
set "app.versioned.jdk=%app.jdk.extract%\%app.found.name%"
call :LinkOrMoveJDK
exit /b %errorlevel%

:: ============================================================
:: Function: MoveNestedFoodSnapJDKToExtractFolder
:: Usage: call :MoveNestedFoodSnapJDKToExtractFolder
:: Purpose: moves tools\jdk\jdk-* into the configured FoodSnap JDK extract folder.
:: Input:
::   app.found.jdk
::   app.found.name
:: Returns:
::   0 moved or already present
::   1 move failed
:: ============================================================
:MoveNestedFoodSnapJDKToExtractFolder
if exist "%app.jdk.extract%\%app.found.name%\bin\javac.exe" exit /b 0
move /Y "%app.found.jdk%" "%app.jdk.extract%\" >> "%app.log%" 2>&1
exit /b %errorlevel%

:: ============================================================
:: Function: FindExtractedFoodSnapJDK
:: Usage: call :FindExtractedFoodSnapJDK
:: Purpose: finds an extracted FoodSnap JDK under tools\downloads\jdk.
:: Output:
::   app.versioned.jdk set when found
:: Returns:
::   0 extracted JDK found
::   1 extracted JDK missing
:: ============================================================
:FindExtractedFoodSnapJDK
set "app.versioned.jdk="
for /D %%D in ("%app.jdk.extract%\jdk-*") do if exist "%%~fD\bin\javac.exe" set "app.versioned.jdk=%%~fD"
if defined app.versioned.jdk exit /b 0
for /D %%D in ("%app.jdk.extract%\*") do if exist "%%~fD\bin\javac.exe" set "app.versioned.jdk=%%~fD"
if defined app.versioned.jdk exit /b 0
exit /b 1

:: ============================================================
:: Function: LinkOrMoveJDK
:: Usage: call :LinkOrMoveJDK
:: Purpose: links tools\jdk to the extracted JDK using a junction,
::          falling back to moving and renaming if junction creation fails.
:: Input:
::   app.versioned.jdk
::   app.jdk.root
:: Returns:
::   0 tools\jdk ready
::   1 link/move failed
:: ============================================================
:LinkOrMoveJDK
if not defined app.versioned.jdk exit /b 1
if exist "%app.jdk.root%\bin\javac.exe" exit /b 0
if exist "%app.jdk.root%\" rmdir /S /Q "%app.jdk.root%" >> "%app.log%" 2>&1
mklink /J "%app.jdk.root%" "%app.versioned.jdk%" >> "%app.log%" 2>&1
if exist "%app.jdk.root%\bin\javac.exe" exit /b 0
move /Y "%app.versioned.jdk%" "%app.jdk.root%" >> "%app.log%" 2>&1
if exist "%app.jdk.root%\bin\javac.exe" exit /b 0
call :Red FAIL: JDK link/move failed.
call :Yellow FROM: %app.versioned.jdk%
call :Yellow TO: %app.jdk.root%
call :Yellow LOG: %app.log%
exit /b 1

:: ============================================================
:: Function: EnsureFoodSnapAndroidSDKPackages
:: Usage: call :EnsureFoodSnapAndroidSDKPackages
:: Purpose: ensures required Android SDK packages exist locally.
::          Missing packages are installed by tools\GetAndroidSDK.bat.
:: Returns:
::   0 packages ready
::   1 package install failed or files missing
:: ============================================================
:EnsureFoodSnapAndroidSDKPackages
call :CheckFoodSnapAndroidSDKPackagesOnly >nul 2>nul
if not errorlevel 1 exit /b 0
if not exist "%app.get.android.sdk%" call :Red FAIL: Android SDK helper not found: %app.get.android.sdk%
if not exist "%app.get.android.sdk%" call :Yellow EXPECTED: place GetAndroidSDK.bat in tools\
if not exist "%app.get.android.sdk%" exit /b 1
call :RequireFreeSpace 1500000000 "Android SDK packages" || exit /b 1
set "efas_args=PlatformTools %app.android.platform.tools.version%"
if defined app.android.platform.tools.revision set "efas_args=%efas_args% Revision %app.android.platform.tools.revision%"
set "efas_args=%efas_args% Platforms %app.android.platform.version%"
if defined app.android.platform.revision set "efas_args=%efas_args% Revision %app.android.platform.revision%"
set "efas_args=%efas_args% BuildTools %app.android.buildtools.version%"
if defined app.android.buildtools.revision set "efas_args=%efas_args% Revision %app.android.buildtools.revision%"
set "efas_args=%efas_args% CmdlineTools %app.android.cmdline.tools.version%"
if defined app.android.cmdline.tools.revision set "efas_args=%efas_args% Revision %app.android.cmdline.tools.revision%"
call :Yellow DO: installing Android SDK packages using tools\GetAndroidSDK.bat.
call "%app.get.android.sdk%" %efas_args% >> "%app.log%" 2>&1
set "app.last.rc=%errorlevel%"
set "efas_args="
if not "%app.last.rc%"=="0" call :Red FAIL: Android SDK helper failed.
if not "%app.last.rc%"=="0" call :Yellow FILE: %app.get.android.sdk%
if not "%app.last.rc%"=="0" call :Yellow LOG: %app.log%
if not "%app.last.rc%"=="0" exit /b %app.last.rc%
call :CheckFoodSnapAndroidSDKPackagesOnly >nul 2>nul
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :Red FAIL: Android SDK packages are still missing after helper finished.
if not "%app.last.rc%"=="0" call :ExplainMissingFoodSnapBuildTools
if not "%app.last.rc%"=="0" exit /b 1
call :Green OK: Android SDK packages ready.
exit /b 0

:: ============================================================
:: Function: EnsureFoodSnapADB
:: Usage: call :EnsureFoodSnapADB
:: Purpose: ensures standalone ADB exists under tools\adb.
::          Missing ADB is installed by tools\GetADB.bat.
:: Returns:
::   0 ADB ready
::   1 ADB install failed or files missing
:: ============================================================
:EnsureFoodSnapADB
call :CheckFoodSnapADBOnly >nul 2>nul
if not errorlevel 1 exit /b 0
if not exist "%app.get.adb%" call :Red FAIL: ADB helper not found: %app.get.adb%
if not exist "%app.get.adb%" call :Yellow EXPECTED: place GetADB.bat in tools\
if not exist "%app.get.adb%" exit /b 1
call :RequireFreeSpace 300000000 "ADB platform-tools" || exit /b 1
call :Yellow DO: installing ADB using tools\GetADB.bat.
if defined app.force goto :EnsureFoodSnapADBForce
if defined app.adb.revision goto :EnsureFoodSnapADBRevision
call "%app.get.adb%" root "%app.adb.root%" version "%app.adb.version%" >> "%app.log%" 2>&1
goto :EnsureFoodSnapADBCheck
:EnsureFoodSnapADBForce
if defined app.adb.revision goto :EnsureFoodSnapADBForceRevision
call "%app.get.adb%" force root "%app.adb.root%" version "%app.adb.version%" >> "%app.log%" 2>&1
goto :EnsureFoodSnapADBCheck
:EnsureFoodSnapADBRevision
call "%app.get.adb%" root "%app.adb.root%" revision "%app.adb.revision%" >> "%app.log%" 2>&1
goto :EnsureFoodSnapADBCheck
:EnsureFoodSnapADBForceRevision
call "%app.get.adb%" force root "%app.adb.root%" revision "%app.adb.revision%" >> "%app.log%" 2>&1
goto :EnsureFoodSnapADBCheck
:EnsureFoodSnapADBCheck
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :Red FAIL: ADB helper failed.
if not "%app.last.rc%"=="0" call :Yellow FILE: %app.get.adb%
if not "%app.last.rc%"=="0" call :Yellow LOG: %app.log%
if not "%app.last.rc%"=="0" exit /b %app.last.rc%
call :CheckFoodSnapADBOnly >nul 2>nul
set "app.last.rc=%errorlevel%"
if not "%app.last.rc%"=="0" call :Red FAIL: ADB is still missing after helper finished.
if not "%app.last.rc%"=="0" call :Yellow MISS: %app.adb%
if not "%app.last.rc%"=="0" call :Yellow LOG: %app.log%
if not "%app.last.rc%"=="0" exit /b 1
call :Green OK: ADB ready.
exit /b 0

:: ============================================================
:: Function: ApplyFoodSnapBuildEnvironment
:: Usage: call :ApplyFoodSnapBuildEnvironment
:: Purpose: applies FoodSnap JAVA_HOME, Android SDK variables, ADB, and PATH.
:: Returns:
::   0 always
:: ============================================================
:ApplyFoodSnapBuildEnvironment
call :SetEnvironmentVariable "JAVA_HOME" "%app.jdk.root%"
call :SetEnvironmentVariable "ANDROID_HOME" "%app.sdk%"
call :SetEnvironmentVariable "ANDROID_SDK_ROOT" "%app.sdk%"
call :SetEnvironmentVariable "ADB_HOME" "%app.adb.root%"
call :PrependPathIfMissing "%JAVA_HOME%\bin"
call :PrependPathIfMissing "%ADB_HOME%\platform-tools"
call :PrependPathIfMissing "%ANDROID_HOME%\platform-tools"
call :PrependPathIfMissing "%app.buildtools%"
exit /b 0

:: ============================================================
:: Function: WriteFoodSnapEnvFile
:: Usage: call :WriteFoodSnapEnvFile
:: Purpose: writes FoodSnap env.bat so future shells can load the toolchain.
:: Returns:
::   0 always
:: ============================================================
:WriteFoodSnapEnvFile
call :CreateBatchFile "%app.env%"
call :AppendSetCommandToBatchFile "%app.env%" "JAVA_HOME" "%app.jdk.root%"
call :AppendSetCommandToBatchFile "%app.env%" "ANDROID_HOME" "%app.sdk%"
call :AppendSetCommandToBatchFile "%app.env%" "ANDROID_SDK_ROOT" "%app.sdk%"
call :AppendSetCommandToBatchFile "%app.env%" "ADB_HOME" "%app.adb.root%"
>> "%app.env%" echo set "PATH=%%JAVA_HOME%%\bin;%%ADB_HOME%%\platform-tools;%%ANDROID_HOME%%\platform-tools;%%ANDROID_HOME%%\build-tools\%app.android.buildtools.version%;%%PATH%%"
exit /b 0

:: ============================================================
:: Function: SetEnvironmentVariable
:: Usage: call :SetEnvironmentVariable "name" "value"
:: Purpose: sets an environment variable by name.
:: Input:
::   %~1 variable name
::   %~2 variable value
:: Returns:
::   0 always
:: ============================================================
:SetEnvironmentVariable
set "%~1=%~2"
exit /b 0

:: ============================================================
:: Function: PrependPathIfMissing
:: Usage: call :PrependPathIfMissing "folder"
:: Purpose: prepends a folder to PATH only when PATH does not already contain it.
:: Input:
::   %~1 folder to add
:: Returns:
::   0 always
:: ============================================================
:PrependPathIfMissing
path | find /I "%~1" >nul 2>nul
if errorlevel 1 set "PATH=%~1;%PATH%"
exit /b 0

:: ============================================================
:: Function: CreateBatchFile
:: Usage: call :CreateBatchFile "file"
:: Purpose: creates or replaces a batch file and writes @echo off.
:: Input:
::   %~1 batch file path
:: Returns:
::   0 always
:: ============================================================
:CreateBatchFile
> "%~1" echo @echo off
exit /b 0

:: ============================================================
:: Function: AppendSetCommandToBatchFile
:: Usage: call :AppendSetCommandToBatchFile "file" "name" "value"
:: Purpose: appends a quoted set command to a batch file.
:: Input:
::   %~1 batch file path
::   %~2 variable name
::   %~3 variable value
:: Returns:
::   0 always
:: ============================================================
:AppendSetCommandToBatchFile
>> "%~1" echo set "%~2=%~3"
exit /b 0

:: ============================================================
:: Function: Download
:: Usage: call :Download "url" "outputFile" "displayName" minBytes
:: Purpose: downloads a file using curl first, then PowerShell.
:: Input:
::   %~1 URL
::   %~2 destination file
::   %~3 display name
::   %~4 minimum acceptable byte size
:: Returns:
::   0 download exists and passes size check
::   1 download failed or file too small
:: ============================================================
:Download
set "dwn_url=%~1"
set "dwn_file=%~2"
set "dwn_name=%~3"
set "dwn_min=%~4"
if not defined dwn_min set "dwn_min=1024"
call :DownloadValidateExisting
set "dwn_rc=%errorlevel%"
if not "%dwn_rc%"=="0" call :DownloadClearVars
if not "%dwn_rc%"=="0" exit /b %dwn_rc%
if exist "%dwn_file%" goto :DownloadExistingOK
call :Yellow GET: %dwn_name%.
call :DownloadWithCurl
set "dwn_rc=%errorlevel%"
if not "%dwn_rc%"=="0" call :DownloadWithPowerShell
if not "%dwn_rc%"=="0" set "dwn_rc=%errorlevel%"
if not "%dwn_rc%"=="0" call :Red FAIL: download failed: %dwn_name%.
if not "%dwn_rc%"=="0" call :Yellow URL: %dwn_url%
if not "%dwn_rc%"=="0" call :Yellow LOG: %app.log%
if not "%dwn_rc%"=="0" call :DownloadClearVars
if not "%dwn_rc%"=="0" exit /b 1
call :DownloadValidateNew
set "dwn_rc=%errorlevel%"
call :DownloadClearVars
exit /b %dwn_rc%
:DownloadExistingOK
call :DownloadClearVars
exit /b 0

:: ============================================================
:: Function: DownloadValidateExisting
:: Usage: call :DownloadValidateExisting
:: Purpose: deletes an existing download if it is smaller than dwn_min.
:: Input:
::   dwn_file
::   dwn_min
:: Returns:
::   0 existing file acceptable, missing, or deleted
::   1 existing bad file could not be deleted
:: ============================================================
:DownloadValidateExisting
set "dve_bad="
if not exist "%dwn_file%" exit /b 0
for %%Z in ("%dwn_file%") do if %%~zZ LSS %dwn_min% set "dve_bad=1"
if not defined dve_bad exit /b 0
del /Q "%dwn_file%" >nul 2>&1
if exist "%dwn_file%" call :Red FAIL: existing download is too small and could not be deleted: %dwn_file%
if exist "%dwn_file%" exit /b 1
exit /b 0

:: ============================================================
:: Function: DownloadWithCurl
:: Usage: call :DownloadWithCurl
:: Purpose: attempts a download using curl.exe.
:: Input:
::   dwn_url
::   dwn_file
:: Returns:
::   0 curl download succeeded
::   1 curl missing or failed
:: ============================================================
:DownloadWithCurl
where curl.exe >nul 2>nul
if errorlevel 1 exit /b 1
curl.exe -L --fail --retry 3 --output "%dwn_file%" "%dwn_url%" >> "%app.log%" 2>&1
exit /b %errorlevel%

:: ============================================================
:: Function: DownloadWithPowerShell
:: Usage: call :DownloadWithPowerShell
:: Purpose: attempts a download using PowerShell Invoke-WebRequest.
:: Input:
::   dwn_url
::   dwn_file
:: Returns:
::   0 PowerShell download succeeded
::   1 PowerShell download failed
:: ============================================================
:DownloadWithPowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%dwn_url%' -OutFile '%dwn_file%'" >> "%app.log%" 2>&1
exit /b %errorlevel%

:: ============================================================
:: Function: DownloadValidateNew
:: Usage: call :DownloadValidateNew
:: Purpose: validates that a newly downloaded file exists and is large enough.
:: Input:
::   dwn_file
::   dwn_min
:: Returns:
::   0 file exists and passes size check
::   1 file missing or too small
:: ============================================================
:DownloadValidateNew
set "dvn_bad="
if not exist "%dwn_file%" call :Red FAIL: download did not create file: %dwn_file%
if not exist "%dwn_file%" call :Yellow LOG: %app.log%
if not exist "%dwn_file%" exit /b 1
for %%Z in ("%dwn_file%") do if %%~zZ LSS %dwn_min% set "dvn_bad=1"
if not defined dvn_bad exit /b 0
call :Red FAIL: downloaded file is too small: %dwn_file%
call :Yellow NEED: at least %dwn_min% bytes
call :Yellow LOG: %app.log%
del /Q "%dwn_file%" >nul 2>&1
exit /b 1

:: ============================================================
:: Function: DownloadClearVars
:: Usage: call :DownloadClearVars
:: Purpose: clears temporary download variables.
:: Returns:
::   0 always
:: ============================================================
:DownloadClearVars
set "dwn_url="
set "dwn_file="
set "dwn_name="
set "dwn_min="
set "dwn_rc="
set "dve_bad="
set "dvn_bad="
exit /b 0

:: ============================================================
:: Function: Unzip
:: Usage: call :Unzip "zipFile" "destinationFolder"
:: Purpose: extracts an archive using 7z, then tar, then PowerShell.
:: Input:
::   %~1 archive file
::   %~2 destination folder
:: Returns:
::   0 extraction succeeded
::   1 extraction failed
:: ============================================================
:Unzip
set "uz_file=%~1"
set "uz_dest=%~2"
set "uz_rc=1"
where 7z.exe >nul 2>nul
if not errorlevel 1 7z.exe x -y "-o%uz_dest%" "%uz_file%" >> "%app.log%" 2>&1
if not errorlevel 1 set "uz_rc=0"
if "%uz_rc%"=="0" set "uz_file="
if "%uz_rc%"=="0" set "uz_dest="
if "%uz_rc%"=="0" exit /b 0
where tar.exe >nul 2>nul
if not errorlevel 1 tar.exe -xf "%uz_file%" -C "%uz_dest%" >> "%app.log%" 2>&1
if not errorlevel 1 set "uz_rc=0"
if "%uz_rc%"=="0" set "uz_file="
if "%uz_rc%"=="0" set "uz_dest="
if "%uz_rc%"=="0" exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%uz_file%' -DestinationPath '%uz_dest%' -Force" >> "%app.log%" 2>&1
set "uz_rc=%errorlevel%"
set "uz_file="
set "uz_dest="
exit /b %uz_rc%

:: ============================================================
:: Function: RequireFreeSpace
:: Usage: call :RequireFreeSpace bytes "purpose"
:: Purpose: verifies that the current drive has enough free space.
:: Input:
::   %~1 required bytes
::   %~2 purpose shown in error message
:: Returns:
::   0 enough free space
::   1 not enough free space
:: ============================================================
:RequireFreeSpace
set "rfs_need_bytes=%~1"
set "rfs_need_mb=?"
set "rfs_free_mb=?"
set "rfs_rc=1"
for /f "tokens=1,2,3" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$d='%app.drive%'; $n=[int64]'%rfs_need_bytes%'; $f=(Get-PSDrive -Name $d).Free; $need=[math]::Ceiling($n/1MB); $free=[math]::Floor($f/1MB); if ($f -lt $n) { Write-Output ($need.ToString() + ' ' + $free.ToString() + ' 1') } else { Write-Output ($need.ToString() + ' ' + $free.ToString() + ' 0') }" 2^>^> "%app.log%"') do set "rfs_need_mb=%%A" & set "rfs_free_mb=%%B" & set "rfs_rc=%%C"
if "%rfs_rc%"=="0" goto :RequireFreeSpaceOK
call :Red FAIL: not enough free disk space for %~2.
call :Yellow DRIVE: %app.drive%:
call :Yellow NEED: at least %rfs_need_mb% MB free
call :Yellow FREE: %rfs_free_mb% MB free
call :Yellow LOG: %app.log%
set "rfs_need_bytes="
set "rfs_need_mb="
set "rfs_free_mb="
set "rfs_rc="
exit /b 1
:RequireFreeSpaceOK
set "rfs_need_bytes="
set "rfs_need_mb="
set "rfs_free_mb="
set "rfs_rc="
exit /b 0

:: ============================================================
:: Function: Green
:: Usage: call :Green message
:: Purpose: prints a green message when ANSI color is available.
:: Returns:
::   0 always
:: ============================================================
:Green
if defined app.esc echo %app.esc%[%app.color.green%%*%app.esc%[%app.color.reset%
if not defined app.esc echo %*
exit /b 0

:: ============================================================
:: Function: Yellow
:: Usage: call :Yellow message
:: Purpose: prints a yellow message when ANSI color is available.
:: Returns:
::   0 always
:: ============================================================
:Yellow
if defined app.esc echo %app.esc%[%app.color.yellow%%*%app.esc%[%app.color.reset%
if not defined app.esc echo %*
exit /b 0

:: ============================================================
:: Function: Red
:: Usage: call :Red message
:: Purpose: prints a red message when ANSI color is available.
:: Returns:
::   0 always
:: ============================================================
:Red
if defined app.esc echo %app.esc%[%app.color.red%%*%app.esc%[%app.color.reset%
if not defined app.esc echo %*
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
:: Function: SetAppColors
:: Usage: call :SetAppColors
:: Purpose: creates ANSI SGR color/style constants under app.color.*.
:: Notes:
::   Constants contain the SGR payload plus final "m".
::   They do not include ESC[.
:: Example:
::   echo %%app.esc%%[%%app.color.red%%Red text%%app.esc%%[%%app.color.reset%%
:: Returns:
::   0 always
:: ============================================================
:SetAppColors
for /f "tokens=1 delims==" %%v in ('set sac_ 2^>nul') do set "%%v="
if defined _sac_rc (set "_sac_rc=" & exit /b %_sac_rc%)
rem ------------------------------------------------------------
rem Reset / defaults
rem ------------------------------------------------------------
set "app.color.reset=0m"
set "app.color.normal=0m"
set "app.color.default=39;49m"
set "app.color.foredefault=39m"
set "app.color.backdefault=49m"
rem ------------------------------------------------------------
rem Styles
rem ------------------------------------------------------------
set "app.color.bold=1m"
set "app.color.bright=1m"
set "app.color.faint=2m"
set "app.color.italic=3m"
set "app.color.underline=4m"
set "app.color.blink=5m"
set "app.color.inverse=7m"
set "app.color.hidden=8m"
set "app.color.strike=9m"
rem ------------------------------------------------------------
rem Style off switches
rem ------------------------------------------------------------
set "app.color.nobold=22m"
set "app.color.nobright=22m"
set "app.color.nofaint=22m"
set "app.color.noitalic=23m"
set "app.color.nounderline=24m"
set "app.color.noblink=25m"
set "app.color.noinverse=27m"
set "app.color.nohidden=28m"
set "app.color.nostrike=29m"
rem ------------------------------------------------------------
rem Normal foreground colors
rem ------------------------------------------------------------
set "app.color.black=30m"
set "app.color.red=31m"
set "app.color.green=32m"
set "app.color.yellow=33m"
set "app.color.blue=34m"
set "app.color.magenta=35m"
set "app.color.cyan=36m"
set "app.color.white=37m"
rem ------------------------------------------------------------
rem Bright foreground colors
rem ------------------------------------------------------------
set "app.color.gray=90m"
set "app.color.grey=90m"
set "app.color.brightblack=90m"
set "app.color.brightred=91m"
set "app.color.brightgreen=92m"
set "app.color.brightyellow=93m"
set "app.color.brightblue=94m"
set "app.color.brightmagenta=95m"
set "app.color.brightcyan=96m"
set "app.color.brightwhite=97m"
rem ------------------------------------------------------------
rem Normal background colors
rem ------------------------------------------------------------
set "app.color.backblack=40m"
set "app.color.backred=41m"
set "app.color.backgreen=42m"
set "app.color.backyellow=43m"
set "app.color.backblue=44m"
set "app.color.backmagenta=45m"
set "app.color.backcyan=46m"
set "app.color.backwhite=47m"
rem ------------------------------------------------------------
rem Bright background colors
rem ------------------------------------------------------------
set "app.color.backgray=100m"
set "app.color.backgrey=100m"
set "app.color.backbrightblack=100m"
set "app.color.backbrightred=101m"
set "app.color.backbrightgreen=102m"
set "app.color.backbrightyellow=103m"
set "app.color.backbrightblue=104m"
set "app.color.backbrightmagenta=105m"
set "app.color.backbrightcyan=106m"
set "app.color.backbrightwhite=107m"
set "_sac_rc=0" & goto :SetAppColors
