@echo off
:setup
:: ============================================================
:: build.bat
:: Plain Android / Java builder for FoodSnap-style projects.
::
:: Batch style:
::   - no delayed expansion
::   - no setlocal
::   - one empty line between documented functions
::   - no empty lines inside functions
::   - parenthesized conditionals when using multiple commands
::   - :setup, :main, and :end are structural labels, not functions
::
:: Build layout:
::   build_YYYY-MM-DD.HHhmm.ss\
::   source_YYYY-MM-DD.HHhmm.ss\
::   oldbuilds\
::
:: Source snapshot excludes:
::   build_*
::   source_*
::   oldbuilds
::   tools\ except tools\*.bat
:: ============================================================
cd /d "%~dp0"
set "app.rc=0"
set "app.config.file=build_config.bat"
set "app.config.file.requested="
set "app.mode="
set "app.help="
set "app.clean.first="
set "app.install.after.build="
set "app.run.after.install="
set "app.timestamp="
set "app.root="
set "app.log="
set "app.javac.log="
set "app.d8.log="
set "app.dx.log="
set "app.sign.log="
set "app.prepare.log="
set "app.build.dir="
set "app.source.snapshot.dir="
set "app.esc="
:main
call :InitializeConsoleColors
call :DetectBuildConfigFileRequest %*
if defined app.config.file.requested set "app.config.file=%app.config.file.requested%"
call :LoadBuildConfig
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
call :SetDefaults
call :ParseArgs %*
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
if defined app.help ( call :ShowHelp & set "app.rc=0" & goto :end )
if /I "%app.mode%"=="clean" ( call :Clean & set "app.rc=0" & goto :end )
if /I "%app.mode%"=="rebuild" set "app.clean.first=1"
if /I "%app.mode%"=="install" set "app.install.after.build=1"
if /I "%app.mode%"=="run" set "app.install.after.build=1"
if /I "%app.mode%"=="run" set "app.run.after.install=1"
if /I "%app.mode%"=="check" call :CheckOnly
if /I "%app.mode%"=="check" set "app.rc=%errorlevel%"
if /I "%app.mode%"=="check" goto :end
call :StartDatedBuild
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
call :Build
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
if defined app.install.after.build call :InstallApk
if defined app.install.after.build set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
if defined app.run.after.install call :RunApp
if defined app.run.after.install set "app.rc=%errorlevel%"
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
:: Function: LoadBuildConfig
:: Usage: call :LoadBuildConfig
:: Purpose: loads the selected build_config.bat.
:: Returns:
::   0 loaded
::   2 missing or failed config
:: ============================================================
:LoadBuildConfig
if not exist "%app.config.file%" ( call :Red FAIL: Missing config file: %app.config.file% & exit /b 2 )
call "%app.config.file%"
set "lbc_rc=%errorlevel%"
if not "%lbc_rc%"=="0" ( call :Red FAIL: Config failed: %app.config.file% & exit /b 2 )
set "lbc_rc="
exit /b 0

:: ============================================================
:: Function: DetectBuildConfigFileRequest
:: Usage: call :DetectBuildConfigFileRequest %*
:: Purpose: detects "config file" or "target file" before normal argument parsing.
:: Returns:
::   0 always
:: ============================================================
:DetectBuildConfigFileRequest
if "%~1"=="" exit /b 0
if /I "%~1"=="config" if not "%~2"=="" set "app.config.file.requested=%~2"
if /I "%~1"=="config" exit /b 0
if /I "%~1"=="target" if not "%~2"=="" set "app.config.file.requested=%~2"
if /I "%~1"=="target" exit /b 0
shift
goto :DetectBuildConfigFileRequest

:: ============================================================
:: Function: SetDefaults
:: Usage: call :SetDefaults
:: Purpose: sets generic Android project defaults after build_config.bat.
:: Returns:
::   0 always
:: ============================================================
:SetDefaults
for %%A in ("%CD%") do set "app.root=%%~fA"
if not defined app.display.name if defined app.display_name set "app.display.name=%app.display_name%"
if not defined app.display.name set "app.display.name=AndroidApp"
if not defined app.name set "app.name=%app.display.name%"
if not defined app.package.name if defined app.package_name set "app.package.name=%app.package_name%"
if not defined app.package.name set "app.package.name="
if not defined app.default.mode if defined app.default_mode set "app.default.mode=%app.default_mode%"
if not defined app.default.mode set "app.default.mode=build"
if not defined app.mode set "app.mode=%app.default.mode%"
if not defined app.compile.api if defined app.compile_api set "app.compile.api=%app.compile_api%"
if not defined app.compile.api set "app.compile.api=22"
if not defined app.min.sdk if defined app.min_sdk set "app.min.sdk=%app.min_sdk%"
if not defined app.min.sdk set "app.min.sdk=14"
if not defined app.target.sdk if defined app.target_sdk set "app.target.sdk=%app.target_sdk%"
if not defined app.target.sdk set "app.target.sdk=%app.compile.api%"
if not defined app.java.source if defined app.java_source set "app.java.source=%app.java_source%"
if not defined app.java.source set "app.java.source=8"
if not defined app.java.target if defined app.java_target set "app.java.target=%app.java_target%"
if not defined app.java.target set "app.java.target=8"
if not defined app.javac.extra.args if defined app.javac_extra_args set "app.javac.extra.args=%app.javac_extra_args%"
if not defined app.javac.extra.args set "app.javac.extra.args=-Xlint:deprecation"
if not defined app.manifest set "app.manifest=AndroidManifest.xml"
if not defined app.source.dir if defined app.source_dir set "app.source.dir=%app.source_dir%"
if not defined app.source.dir set "app.source.dir=src"
if not defined app.resources.dir if defined app.resources_dir set "app.resources.dir=%app.resources_dir%"
if not defined app.resources.dir set "app.resources.dir=resources"
if not defined app.tools.dir if defined app.tools_dir set "app.tools.dir=%app.tools_dir%"
if not defined app.tools.dir set "app.tools.dir=tools"
if not defined app.jdk.dir if defined app.jdk_dir set "app.jdk.dir=%app.jdk_dir%"
if not defined app.jdk.dir set "app.jdk.dir=%app.tools.dir%\jdk"
if not defined app.android.sdk.dir if defined app.android_sdk_dir set "app.android.sdk.dir=%app.android_sdk_dir%"
if not defined app.android.sdk.dir set "app.android.sdk.dir=%app.tools.dir%\android-sdk"
if not defined app.android.sdk.fallback.dir if defined app.android_sdk_fallback_dir set "app.android.sdk.fallback.dir=%app.android_sdk_fallback_dir%"
if not defined app.android.sdk.fallback.dir set "app.android.sdk.fallback.dir=android-sdk"
if not defined app.build.tools.version if defined app.build_tools_version set "app.build.tools.version=%app.build_tools_version%"
if not defined app.build.tools.version set "app.build.tools.version=28.0.3"
if not defined app.keystore if defined app.keystore_file set "app.keystore=%app.keystore_file%"
if not defined app.keystore set "app.keystore=%app.tools.dir%\debug.keystore"
if not defined app.keystore.alias if defined app.keystore_alias set "app.keystore.alias=%app.keystore_alias%"
if not defined app.keystore.alias set "app.keystore.alias=androiddebugkey"
if not defined app.keystore.pass if defined app.keystore_pass set "app.keystore.pass=%app.keystore_pass%"
if not defined app.keystore.pass set "app.keystore.pass=android"
if not defined app.icon.source if defined app.icon_source set "app.icon.source=%app.icon_source%"
if not defined app.icon.resource if defined app.icon_resource set "app.icon.resource=%app.icon_resource%"
if not defined app.icon.resource set "app.icon.resource=app_icon"
if not defined app.auto.strings if defined app.auto_strings set "app.auto.strings=%app.auto_strings%"
if not defined app.auto.strings set "app.auto.strings=1"
if not defined app.prepare.file set "app.prepare.file=prepare.bat"
if not defined app.oldbuilds.dir set "app.oldbuilds.dir=oldbuilds"
exit /b 0

:: ============================================================
:: Function: ParseArgs
:: Usage: call :ParseArgs %*
:: Purpose: parses build command arguments.
:: Accepted:
::   build, check, clean, rebuild, install, run, help
::   config file, target file
:: Returns:
::   0 success
::   2 unknown argument
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="config" goto :ParseArgsSkipValue
if /I "%~1"=="target" goto :ParseArgsSkipValue
if /I "%~1"=="help" ( set "app.help=1" & exit /b 0 )
if /I "%~1"=="--help" ( set "app.help=1" & exit /b 0 )
if /I "%~1"=="/help" ( set "app.help=1" & exit /b 0 )
if /I "%~1"=="-h" ( set "app.help=1" & exit /b 0 )
if /I "%~1"=="/?" ( set "app.help=1" & exit /b 0 )
if /I "%~1"=="build" ( set "app.mode=build" & shift & goto :ParseArgs )
if /I "%~1"=="check" ( set "app.mode=check" & shift & goto :ParseArgs )
if /I "%~1"=="clean" ( set "app.mode=clean" & shift & goto :ParseArgs )
if /I "%~1"=="rebuild" ( set "app.mode=rebuild" & shift & goto :ParseArgs )
if /I "%~1"=="install" ( set "app.mode=install" & shift & goto :ParseArgs )
if /I "%~1"=="run" ( set "app.mode=run" & shift & goto :ParseArgs )
call :Red FAIL: Unknown argument: %~1
exit /b 2
:ParseArgsSkipValue
if "%~2"=="" ( call :Red FAIL: %~1 requires a config file path. & exit /b 2 )
shift
shift
goto :ParseArgs

:: ============================================================
:: Function: ShowHelp:: ============================================================
:: Function: ShowHelp
:: Usage: call :ShowHelp
:: Purpose: prints usage and important settings.
:: Returns:
::   0 always
:: ============================================================
:ShowHelp
call :Green %app.display.name% build.bat
echo.
call :Yellow Usage:
echo   build
echo   build check
echo   build clean
echo   build rebuild
echo   build install
echo   build run
echo   build config other_config.bat
echo.
call :Yellow Settings:
echo   app.source.dir=%app.source.dir%
echo   app.resources.dir=%app.resources.dir%
echo   app.tools.dir=%app.tools.dir%
echo   app.android.sdk.dir=%app.android.sdk.dir%
echo   app.compile.api=%app.compile.api%
echo   app.min.sdk=%app.min.sdk%
echo   app.build.tools.version=%app.build.tools.version%
echo   app.javac.extra.args=%app.javac.extra.args%
echo.
call :Yellow Output:
echo   build_YYYY-MM-DD.HHhmm.ss\
echo   source_YYYY-MM-DD.HHhmm.ss\
echo   oldbuilds\
exit /b 0

:: ============================================================
:: Function: CheckOnly
:: Usage: call :CheckOnly
:: Purpose: verifies project layout and local build tools without creating dated output.
:: Returns:
::   0 ready
::   3 tool missing
::   4 project layout missing
:: ============================================================
:CheckOnly
call :ResolvePaths
set "co_rc=%errorlevel%"
if "%co_rc%"=="0" call :CheckProjectLayout
if "%co_rc%"=="0" set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" ( call :ExplainMissingBuildRequirements & exit /b %co_rc% )
call :Green OK: %app.display.name% build environment is ready.
set "co_rc="
exit /b 0

:: ============================================================
:: Function: StartDatedBuild
:: Usage: call :StartDatedBuild
:: Purpose: creates timestamped build/source folders and moves old dated folders first.
:: Returns:
::   0 success
::   1 failure
:: ============================================================
:StartDatedBuild
call :CreateTimestamp
if errorlevel 1 exit /b 1
call :ArchiveOldDatedFolders
if errorlevel 1 exit /b 1
set "app.build.dir=build_%app.timestamp%"
set "app.source.snapshot.dir=source_%app.timestamp%"
set "app.temp.dir=%app.build.dir%\temp"
set "app.staged.res=%app.temp.dir%\res"
set "app.gen.dir=%app.build.dir%\gen"
set "app.classes.dir=%app.build.dir%\classes"
set "app.dex.dir=%app.build.dir%\dex"
set "app.log=%app.build.dir%\build.%app.timestamp%.log"
set "app.javac.log=%app.build.dir%\javac.%app.timestamp%.log"
set "app.d8.log=%app.build.dir%\d8.%app.timestamp%.log"
set "app.dx.log=%app.build.dir%\dx.%app.timestamp%.log"
set "app.sign.log=%app.build.dir%\sign.%app.timestamp%.log"
set "app.prepare.log=%app.build.dir%\prepare.%app.timestamp%.log"
set "app.sources.file=%app.build.dir%\sources.txt"
set "app.classes.file=%app.build.dir%\classes.txt"
set "app.classes.jar=%app.build.dir%\classes.%app.timestamp%.jar"
set "app.unsigned.apk=%app.build.dir%\%app.name%-unsigned.apk"
set "app.aligned.apk=%app.build.dir%\%app.name%-aligned.apk"
set "app.output.apk=%app.build.dir%\%app.name%-debug.apk"
mkdir "%app.build.dir%" >nul 2>nul
if not exist "%app.build.dir%\" ( call :Red FAIL: could not create build folder: %app.build.dir% & exit /b 1 )
call :CreateBuildLogHeader
call :Yellow LOG: %app.log%
call :CreateSourceSnapshot
exit /b %errorlevel%

:: ============================================================
:: Function: CreateTimestamp
:: Usage: call :CreateTimestamp
:: Purpose: creates app.timestamp in YYYY-MM-DD.HHhmm.ss format.
:: Returns:
::   0 timestamp created
::   1 timestamp failed
:: ============================================================
:CreateTimestamp
set "app.timestamp="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Date).ToString('yyyy-MM-dd.HH''h''mm.ss')"`) do set "app.timestamp=%%A"
if defined app.timestamp exit /b 0
call :Red FAIL: could not create timestamp.
exit /b 1

:: ============================================================
:: Function: ArchiveOldDatedFolders
:: Usage: call :ArchiveOldDatedFolders
:: Purpose: moves previous build_* and source_* folders into oldbuilds before new build.
:: Returns:
::   0 always
:: ============================================================
:ArchiveOldDatedFolders
if not exist "%app.oldbuilds.dir%\" mkdir "%app.oldbuilds.dir%" >nul 2>nul
for /D %%D in ("build_*") do call :ArchiveOneDatedFolder "%%~fD"
for /D %%D in ("source_*") do call :ArchiveOneDatedFolder "%%~fD"
exit /b 0

:: ============================================================
:: Function: ArchiveOneDatedFolder
:: Usage: call :ArchiveOneDatedFolder "folder"
:: Purpose: moves one dated folder into oldbuilds, avoiding name collisions.
:: Input:
::   %~1 folder
:: Returns:
::   0 always
:: ============================================================
:ArchiveOneDatedFolder
set "aodf_source=%~1"
for %%A in ("%aodf_source%") do set "aodf_name=%%~nxA"
set "aodf_target=%app.root%\%app.oldbuilds.dir%\%aodf_name%"
if /I "%aodf_source%"=="%app.root%\%app.oldbuilds.dir%" goto :ArchiveOneDatedFolderDone
if exist "%aodf_target%\" set "aodf_target=%app.root%\%app.oldbuilds.dir%\%aodf_name%.moved_%app.timestamp%"
move "%aodf_source%" "%aodf_target%" >nul 2>nul
:ArchiveOneDatedFolderDone
set "aodf_source="
set "aodf_name="
set "aodf_target="
exit /b 0

:: ============================================================
:: Function: CreateBuildLogHeader
:: Usage: call :CreateBuildLogHeader
:: Purpose: creates the dated build log header.
:: Returns:
::   0 always
:: ============================================================
:CreateBuildLogHeader
> "%app.log%" echo %app.display.name% build log
>> "%app.log%" echo Timestamp: %app.timestamp%
>> "%app.log%" echo Root: %app.root%
>> "%app.log%" echo Build: %app.build.dir%
>> "%app.log%" echo Source snapshot: %app.source.snapshot.dir%
>> "%app.log%" echo LOG: %app.log%
exit /b 0

:: ============================================================
:: Function: CreateSourceSnapshot
:: Usage: call :CreateSourceSnapshot
:: Purpose: copies source project files into source_YYYY-MM-DD.HHhmm.ss.
:: Returns:
::   0 success
::   1 failure
:: ============================================================
:CreateSourceSnapshot
call :Yellow DO: Creating source snapshot.
if exist "%app.source.snapshot.dir%\" rmdir /S /Q "%app.source.snapshot.dir%" >> "%app.log%" 2>&1
mkdir "%app.source.snapshot.dir%" >> "%app.log%" 2>&1
if not exist "%app.source.snapshot.dir%\" ( call :Red FAIL: could not create source snapshot folder. & exit /b 1 )
for %%F in (*) do copy /Y "%%~fF" "%app.source.snapshot.dir%\" >> "%app.log%" 2>&1
for /D %%D in (*) do call :SnapshotRootDirectory "%%~fD" "%%~nxD"
call :Green OK: Source snapshot ready: %app.source.snapshot.dir%
exit /b 0

:: ============================================================
:: Function: SnapshotRootDirectory
:: Usage: call :SnapshotRootDirectory "fullPath" "name"
:: Purpose: copies an allowed root directory into the source snapshot.
:: Input:
::   %~1 full source path
::   %~2 folder name
:: Returns:
::   0 always
:: ============================================================
:SnapshotRootDirectory
set "srd_path=%~1"
set "srd_name=%~2"
if /I "%srd_name%"=="%app.oldbuilds.dir%" goto :SnapshotRootDirectoryDone
if /I "%srd_name:~0,6%"=="build_" goto :SnapshotRootDirectoryDone
if /I "%srd_name:~0,7%"=="source_" goto :SnapshotRootDirectoryDone
if /I "%srd_name%"=="%app.tools.dir%" goto :SnapshotToolsDirectory
xcopy "%srd_path%\*" "%app.source.snapshot.dir%\%srd_name%\" /E /I /Y /Q >> "%app.log%" 2>&1
goto :SnapshotRootDirectoryDone
:SnapshotToolsDirectory
mkdir "%app.source.snapshot.dir%\%app.tools.dir%" >nul 2>nul
copy /Y "%srd_path%\*.bat" "%app.source.snapshot.dir%\%app.tools.dir%\" >> "%app.log%" 2>&1
:SnapshotRootDirectoryDone
set "srd_path="
set "srd_name="
exit /b 0

:: ============================================================
:: Function: Build
:: Usage: call :Build
:: Purpose: performs the complete Android Java build.
:: Returns:
::   0 APK built
::   nonzero on failure
:: ============================================================
:Build
if defined app.clean.first call :Clean
call :EnsureBuildToolsReady
if errorlevel 1 exit /b %errorlevel%
call :PrepareBuildFolders
if errorlevel 1 exit /b %errorlevel%
call :StageResources
if errorlevel 1 exit /b %errorlevel%
call :GenerateR
if errorlevel 1 exit /b %errorlevel%
call :CompileJava
if errorlevel 1 exit /b %errorlevel%
call :MakeDex
if errorlevel 1 exit /b %errorlevel%
call :PackageApk
if errorlevel 1 exit /b %errorlevel%
call :EnsureDebugKeystore
if errorlevel 1 exit /b %errorlevel%
call :AlignAndSign
if errorlevel 1 exit /b %errorlevel%
call :Green OK: Built %app.output.apk%
exit /b 0

:: ============================================================
:: Function: EnsureBuildToolsReady
:: Usage: call :EnsureBuildToolsReady
:: Purpose: checks tools/project layout and runs prepare.bat if tools are missing.
:: Returns:
::   0 ready
::   nonzero prepare or check failed
:: ============================================================
:EnsureBuildToolsReady
call :ResolvePaths >nul 2>nul
set "ebtr_rc=%errorlevel%"
if "%ebtr_rc%"=="0" call :CheckProjectLayout >nul 2>nul
if "%ebtr_rc%"=="0" set "ebtr_rc=%errorlevel%"
if "%ebtr_rc%"=="0" call :Green OK: %app.display.name% build environment is ready.
if "%ebtr_rc%"=="0" ( set "ebtr_rc=" & exit /b 0 )
call :ExplainMissingBuildRequirements
if not exist "%app.prepare.file%" ( call :Red FAIL: Missing %app.prepare.file%; cannot repair build tools. & exit /b 3 )
call :Yellow DO: Running %app.prepare.file% because required build tools are missing.
call :Yellow LOG: %app.prepare.log%
call "%app.prepare.file%" > "%app.prepare.log%" 2>&1
set "ebtr_rc=%errorlevel%"
type "%app.prepare.log%"
if not "%ebtr_rc%"=="0" ( call :Red FAIL: %app.prepare.file% failed with exit code %ebtr_rc%. & exit /b %ebtr_rc% )
call :ResolvePaths
if errorlevel 1 exit /b %errorlevel%
call :CheckProjectLayout
if errorlevel 1 exit /b %errorlevel%
call :Green OK: %app.display.name% build environment is ready.
set "ebtr_rc="
exit /b 0

:: ============================================================
:: Function: ResolvePaths
:: Usage: call :ResolvePaths
:: Purpose: resolves JDK, Android SDK, build tools, and adb.
:: Returns:
::   0 resolved
::   3 missing tool
:: ============================================================
:ResolvePaths
call :ResolveJdk
if errorlevel 1 exit /b %errorlevel%
call :ResolveAndroidSdk
if errorlevel 1 exit /b %errorlevel%
call :ResolveBuildTools
if errorlevel 1 exit /b %errorlevel%
call :ResolveAdb
exit /b 0

:: ============================================================
:: Function: ResolveJdk
:: Usage: call :ResolveJdk
:: Purpose: resolves local JDK command paths.
:: Returns:
::   0 resolved
::   3 missing JDK
:: ============================================================
:ResolveJdk
set "app.javac="
set "app.java.exe="
set "app.jar.exe="
set "app.keytool="
if exist "%app.jdk.dir%\bin\javac.exe" for %%A in ("%app.jdk.dir%") do set "JAVA_HOME=%%~fA"
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\javac.exe" set "app.javac=%JAVA_HOME%\bin\javac.exe"
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" set "app.java.exe=%JAVA_HOME%\bin\java.exe"
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\jar.exe" set "app.jar.exe=%JAVA_HOME%\bin\jar.exe"
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\keytool.exe" set "app.keytool=%JAVA_HOME%\bin\keytool.exe"
if defined app.javac if defined app.java.exe if defined app.jar.exe if defined app.keytool exit /b 0
for %%P in (javac.exe) do set "app.javac=%%~$PATH:P"
for %%P in (java.exe) do set "app.java.exe=%%~$PATH:P"
for %%P in (jar.exe) do set "app.jar.exe=%%~$PATH:P"
for %%P in (keytool.exe) do set "app.keytool=%%~$PATH:P"
if not defined app.javac exit /b 3
if not defined app.java.exe exit /b 3
if not defined app.jar.exe exit /b 3
if not defined app.keytool exit /b 3
exit /b 0

:: ============================================================
:: Function: ResolveAndroidSdk
:: Usage: call :ResolveAndroidSdk
:: Purpose: resolves Android SDK and android.jar.
:: Returns:
::   0 resolved
::   3 missing SDK/platform
:: ============================================================
:ResolveAndroidSdk
set "app.android.sdk="
if exist "%app.android.sdk.dir%\platforms" for %%A in ("%app.android.sdk.dir%") do set "app.android.sdk=%%~fA"
if not defined app.android.sdk if exist "%app.android.sdk.fallback.dir%\platforms" for %%A in ("%app.android.sdk.fallback.dir%") do set "app.android.sdk=%%~fA"
if not defined app.android.sdk if defined ANDROID_HOME if exist "%ANDROID_HOME%\platforms" for %%A in ("%ANDROID_HOME%") do set "app.android.sdk=%%~fA"
if not defined app.android.sdk if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platforms" for %%A in ("%ANDROID_SDK_ROOT%") do set "app.android.sdk=%%~fA"
if not defined app.android.sdk exit /b 3
set "ANDROID_HOME=%app.android.sdk%"
set "ANDROID_SDK_ROOT=%app.android.sdk%"
set "app.android.jar=%app.android.sdk%\platforms\android-%app.compile.api%\android.jar"
if not exist "%app.android.jar%" exit /b 3
exit /b 0

:: ============================================================
:: Function: ResolveBuildTools
:: Usage: call :ResolveBuildTools
:: Purpose: resolves Android build-tools paths.
:: Returns:
::   0 resolved
::   3 missing build-tools
:: ============================================================
:ResolveBuildTools
set "app.build.tools="
if exist "%app.android.sdk%\build-tools\%app.build.tools.version%\aapt.exe" set "app.build.tools=%app.android.sdk%\build-tools\%app.build.tools.version%"
if defined app.build.tools goto :ResolveBuildToolsFound
for /f "delims=" %%B in ('dir /b /ad /o-n "%app.android.sdk%\build-tools" 2^>nul') do call :ResolveBuildToolsCandidate "%%B"
if not defined app.build.tools exit /b 3
:ResolveBuildToolsFound
set "app.aapt=%app.build.tools%\aapt.exe"
set "app.d8.jar=%app.build.tools%\lib\d8.jar"
set "app.dx.jar=%app.build.tools%\lib\dx.jar"
set "app.zipalign=%app.build.tools%\zipalign.exe"
set "app.apksigner.jar=%app.build.tools%\lib\apksigner.jar"
set "app.apksigner.bat=%app.build.tools%\apksigner.bat"
if not exist "%app.aapt%" exit /b 3
if not exist "%app.d8.jar%" if not exist "%app.dx.jar%" exit /b 3
if not exist "%app.zipalign%" exit /b 3
if not exist "%app.apksigner.jar%" if not exist "%app.apksigner.bat%" exit /b 3
exit /b 0

:: ============================================================
:: Function: ResolveBuildToolsCandidate
:: Usage: call :ResolveBuildToolsCandidate "version"
:: Purpose: records the first usable build-tools version when the preferred one is missing.
:: Input:
::   %~1 version folder name
:: Returns:
::   0 always
:: ============================================================
:ResolveBuildToolsCandidate
if defined app.build.tools exit /b 0
if exist "%app.android.sdk%\build-tools\%~1\aapt.exe" set "app.build.tools=%app.android.sdk%\build-tools\%~1"
exit /b 0

:: ============================================================
:: Function: ResolveAdb
:: Usage: call :ResolveAdb
:: Purpose: resolves adb if available.
:: Returns:
::   0 always
:: ============================================================
:ResolveAdb
set "app.adb="
if defined app.android.sdk if exist "%app.android.sdk%\platform-tools\adb.exe" set "app.adb=%app.android.sdk%\platform-tools\adb.exe"
if not defined app.adb for %%P in (adb.exe) do set "app.adb=%%~$PATH:P"
exit /b 0

:: ============================================================
:: Function: CheckProjectLayout
:: Usage: call :CheckProjectLayout
:: Purpose: checks required FoodSnap project files/folders.
:: Returns:
::   0 ready
::   4 missing project file/folder
:: ============================================================
:CheckProjectLayout
if not exist "%app.manifest%" exit /b 4
if not exist "%app.source.dir%\" exit /b 4
if not exist "%app.resources.dir%\" exit /b 4
if defined app.icon.source if not exist "%app.icon.source%" exit /b 4
exit /b 0

:: ============================================================
:: Function: ExplainMissingBuildRequirements
:: Usage: call :ExplainMissingBuildRequirements
:: Purpose: prints missing build tools and project files.
:: Returns:
::   0 always
:: ============================================================
:ExplainMissingBuildRequirements
if not exist "%app.jdk.dir%\bin\javac.exe" call :Yellow MISS: JDK javac: %app.jdk.dir%\bin\javac.exe
if not exist "%app.jdk.dir%\bin\java.exe" call :Yellow MISS: JDK java: %app.jdk.dir%\bin\java.exe
if not exist "%app.jdk.dir%\bin\jar.exe" call :Yellow MISS: JDK jar: %app.jdk.dir%\bin\jar.exe
if not exist "%app.jdk.dir%\bin\keytool.exe" call :Yellow MISS: JDK keytool: %app.jdk.dir%\bin\keytool.exe
if not exist "%app.android.sdk.dir%\platforms\" call :Yellow MISS: Android SDK platforms folder: %app.android.sdk.dir%\platforms\
if not exist "%app.android.sdk.dir%\platforms\android-%app.compile.api%\android.jar" call :Yellow MISS: Android platform jar: %app.android.sdk.dir%\platforms\android-%app.compile.api%\android.jar
if not exist "%app.android.sdk.dir%\build-tools\%app.build.tools.version%\" call :Yellow MISS: Android build-tools %app.build.tools.version%: %app.android.sdk.dir%\build-tools\%app.build.tools.version%\
if not exist "%app.android.sdk.dir%\build-tools\%app.build.tools.version%\aapt.exe" call :Yellow MISS: aapt.exe: %app.android.sdk.dir%\build-tools\%app.build.tools.version%\aapt.exe
if not exist "%app.android.sdk.dir%\build-tools\%app.build.tools.version%\lib\d8.jar" if not exist "%app.android.sdk.dir%\build-tools\%app.build.tools.version%\lib\dx.jar" call :Yellow MISS: d8.jar or dx.jar under build-tools lib\
if not exist "%app.android.sdk.dir%\build-tools\%app.build.tools.version%\zipalign.exe" call :Yellow MISS: zipalign.exe: %app.android.sdk.dir%\build-tools\%app.build.tools.version%\zipalign.exe
if not exist "%app.android.sdk.dir%\build-tools\%app.build.tools.version%\lib\apksigner.jar" if not exist "%app.android.sdk.dir%\build-tools\%app.build.tools.version%\apksigner.bat" call :Yellow MISS: apksigner.jar or apksigner.bat under build-tools
if not exist "%app.manifest%" call :Yellow MISS: Manifest: %app.manifest%
if not exist "%app.source.dir%\" call :Yellow MISS: Source folder: %app.source.dir%\
if not exist "%app.resources.dir%\" call :Yellow MISS: Resources folder: %app.resources.dir%\
if defined app.icon.source if not exist "%app.icon.source%" call :Yellow MISS: Icon: %app.icon.source%
exit /b 0

:: ============================================================
:: Function: PrepareBuildFolders
:: Usage: call :PrepareBuildFolders
:: Purpose: creates per-build temporary folders.
:: Returns:
::   0 success
:: ============================================================
:PrepareBuildFolders
if exist "%app.temp.dir%" rmdir /S /Q "%app.temp.dir%" >> "%app.log%" 2>&1
mkdir "%app.temp.dir%" "%app.gen.dir%" "%app.classes.dir%" "%app.dex.dir%" >> "%app.log%" 2>&1
exit /b 0

:: ============================================================
:: Function: StageResources
:: Usage: call :StageResources
:: Purpose: stages Android resources from resources\ and optional icon source.
:: Returns:
::   0 success
::   4 missing icon
:: ============================================================
:StageResources
call :Blue DO: Staging resources.
mkdir "%app.staged.res%" >nul 2>nul
for /D %%D in ("%app.resources.dir%\*") do call :CopyResourceDirectory "%%~fD" "%%~nxD"
if defined app.icon.source call :StageIcon
if errorlevel 1 exit /b %errorlevel%
if "%app.auto.strings%"=="1" call :EnsureStringsXml
call :Green OK: Resources ready.
exit /b 0

:: ============================================================
:: Function: CopyResourceDirectory
:: Usage: call :CopyResourceDirectory "sourcePath" "directoryName"
:: Purpose: copies a resource subfolder to staged resources.
:: Input:
::   %~1 source path
::   %~2 resource folder name
:: Returns:
::   0 always
:: ============================================================
:CopyResourceDirectory
xcopy "%~1\*" "%app.staged.res%\%~2\" /E /I /Y /Q >> "%app.log%" 2>&1
exit /b 0

:: ============================================================
:: Function: StageIcon
:: Usage: call :StageIcon
:: Purpose: stages app.icon.source as drawable-nodpi app icon.
:: Returns:
::   0 icon copied
::   4 icon missing
:: ============================================================
:StageIcon
if not exist "%app.icon.source%" ( call :Red FAIL: Missing icon: %app.icon.source% & exit /b 4 )
mkdir "%app.staged.res%\drawable-nodpi" >nul 2>nul
copy /Y "%app.icon.source%" "%app.staged.res%\drawable-nodpi\%app.icon.resource%.png" >> "%app.log%" 2>&1
set "si_rc=%errorlevel%"
if not "%si_rc%"=="0" ( call :Red FAIL: Could not stage icon: %app.icon.source% & exit /b 4 )
set "si_rc="
exit /b 0

:: ============================================================
:: Function: EnsureStringsXml
:: Usage: call :EnsureStringsXml
:: Purpose: creates a default strings.xml if project resources do not supply one.
:: Returns:
::   0 always
:: ============================================================
:EnsureStringsXml
if not exist "%app.staged.res%\values" mkdir "%app.staged.res%\values" >nul 2>nul
if exist "%app.staged.res%\values\strings.xml" exit /b 0
>"%app.staged.res%\values\strings.xml" echo ^<resources^>
>>"%app.staged.res%\values\strings.xml" echo     ^<string name="app_name"^>%app.display.name%^</string^>
>>"%app.staged.res%\values\strings.xml" echo ^</resources^>
exit /b 0

:: ============================================================
:: Function: GenerateR
:: Usage: call :GenerateR
:: Purpose: runs aapt to generate R.java.
:: Returns:
::   0 success
::   5 failure
:: ============================================================
:GenerateR
call :Blue DO: Generating R.java.
"%app.aapt%" package -f -m -J "%app.gen.dir%" -M "%app.manifest%" -S "%app.staged.res%" -I "%app.android.jar%" >> "%app.log%" 2>&1
set "gr_rc=%errorlevel%"
if not "%gr_rc%"=="0" ( call :Red FAIL: aapt R.java generation failed. & exit /b 5 )
set "gr_rc="
exit /b 0

:: ============================================================
:: Function: CompileJava
:: Usage: call :CompileJava
:: Purpose: compiles Java sources and generated R.java.
:: Returns:
::   0 success
::   5 compile failure
:: ============================================================
:CompileJava
call :Blue DO: Compiling Java.
if exist "%app.sources.file%" del "%app.sources.file%" >nul 2>nul
for /R "%app.source.dir%" %%F in (*.java) do call :AppendQuotedForwardSlashPath "%app.sources.file%" "%%~fF"
for /R "%app.gen.dir%" %%F in (*.java) do call :AppendQuotedForwardSlashPath "%app.sources.file%" "%%~fF"
if not exist "%app.sources.file%" ( call :Red FAIL: No Java source files found in %app.source.dir%\ & exit /b 5 )
"%app.javac%" -encoding UTF-8 -source %app.java.source% -target %app.java.target% %app.javac.extra.args% -bootclasspath "%app.android.jar%" -classpath "%app.android.jar%" -d "%app.classes.dir%" @"%app.sources.file%" > "%app.javac.log%" 2>&1
set "cj_rc=%errorlevel%"
if not "%cj_rc%"=="0" ( type "%app.javac.log%" & call :Red FAIL: Java compilation failed. & exit /b 5 )
call :ReportJavacWarnings
set "cj_rc="
exit /b 0

:: ============================================================
:: Function: ReportJavacWarnings
:: Usage: call :ReportJavacWarnings
:: Purpose: prints a warning count while keeping details in the dated javac log.
:: Returns:
::   0 always
:: ============================================================
:ReportJavacWarnings
set "rjw_count=0"
for /f %%W in ('findstr /C:"warning:" "%app.javac.log%" 2^>nul ^| find /C /V ""') do set "rjw_count=%%W"
if not "%rjw_count%"=="0" call :Yellow WARN: javac warnings: %rjw_count% details in %app.javac.log%
set "rjw_count="
exit /b 0

:: ============================================================
:: Function: MakeDex
:: Usage: call :MakeDex
:: Purpose: converts .class files to classes.dex using direct d8.jar Java invocation.
:: Returns:
::   0 classes.dex produced
::   5 dex failure
:: ============================================================
:MakeDex
call :Blue DO: Creating classes.dex.
if exist "%app.classes.file%" del "%app.classes.file%" >nul 2>nul
for /R "%app.classes.dir%" %%F in (*.class) do call :AppendQuotedForwardSlashPath "%app.classes.file%" "%%~fF"
if not exist "%app.classes.file%" ( call :Red FAIL: No compiled .class files found. & exit /b 5 )
if exist "%app.classes.jar%" del "%app.classes.jar%" >nul 2>nul
"%app.jar.exe%" cf "%app.classes.jar%" -C "%app.classes.dir%" . >> "%app.log%" 2>&1
set "md_rc=%errorlevel%"
if not "%md_rc%"=="0" ( call :Red FAIL: could not create classes jar for dex. & exit /b 5 )
if exist "%app.d8.jar%" call :MakeDexWithD8
if exist "%app.dex.dir%\classes.dex" exit /b 0
if exist "%app.dx.jar%" call :MakeDexWithDx
if exist "%app.dex.dir%\classes.dex" exit /b 0
call :Red FAIL: classes.dex was not produced.
if exist "%app.d8.log%" call :Yellow LOG: %app.d8.log%
if exist "%app.dx.log%" call :Yellow LOG: %app.dx.log%
exit /b 5

:: ============================================================
:: Function: MakeDexWithD8
:: Usage: call :MakeDexWithD8
:: Purpose: runs d8 directly through java.exe and d8.jar.
:: Returns:
::   0 always; caller checks for classes.dex
:: ============================================================
:MakeDexWithD8
"%app.java.exe%" -cp "%app.d8.jar%" com.android.tools.r8.D8 --debug --min-api %app.min.sdk% --output "%app.dex.dir%" "%app.classes.jar%" > "%app.d8.log%" 2>&1
set "mdwd_rc=%errorlevel%"
if not "%mdwd_rc%"=="0" type "%app.d8.log%"
if not "%mdwd_rc%"=="0" call :Yellow WARN: d8 failed; will try dx if available.
set "mdwd_rc="
exit /b 0

:: ============================================================
:: Function: MakeDexWithDx
:: Usage: call :MakeDexWithDx
:: Purpose: runs dx directly through java.exe and dx.jar as a fallback.
:: Returns:
::   0 always; caller checks for classes.dex
:: ============================================================
:MakeDexWithDx
"%app.java.exe%" -jar "%app.dx.jar%" --dex --output="%app.dex.dir%\classes.dex" "%app.classes.jar%" > "%app.dx.log%" 2>&1
set "mdwx_rc=%errorlevel%"
if not "%mdwx_rc%"=="0" type "%app.dx.log%"
if not "%mdwx_rc%"=="0" call :Yellow WARN: dx failed.
set "mdwx_rc="
exit /b 0

:: ============================================================
:: Function: PackageApk
:: Usage: call :PackageApk
:: Purpose: packages resources and adds classes.dex to the unsigned APK.
:: Returns:
::   0 success
::   5 packaging failure
:: ============================================================
:PackageApk
call :Blue DO: Packaging APK.
if exist "%app.unsigned.apk%" del "%app.unsigned.apk%" >nul 2>nul
"%app.aapt%" package -f -M "%app.manifest%" -S "%app.staged.res%" -I "%app.android.jar%" -F "%app.unsigned.apk%" >> "%app.log%" 2>&1
set "pa_rc=%errorlevel%"
if not "%pa_rc%"=="0" ( call :Red FAIL: APK packaging failed. & exit /b 5 )
copy /Y "%app.dex.dir%\classes.dex" "%app.build.dir%\classes.dex" >> "%app.log%" 2>&1
set "pa_rc=%errorlevel%"
if not "%pa_rc%"=="0" ( call :Red FAIL: could not stage classes.dex for APK. & exit /b 5 )
"%app.jar.exe%" uf "%app.unsigned.apk%" -C "%app.build.dir%" classes.dex >> "%app.log%" 2>&1
set "pa_rc=%errorlevel%"
if not "%pa_rc%"=="0" ( call :Red FAIL: Adding classes.dex failed. & exit /b 5 )
"%app.jar.exe%" tf "%app.unsigned.apk%" | find "classes.dex" >nul 2>nul
set "pa_rc=%errorlevel%"
if not "%pa_rc%"=="0" ( call :Red FAIL: unsigned APK does not contain classes.dex. & exit /b 5 )
set "pa_rc="
exit /b 0

:: ============================================================
:: Function: EnsureDebugKeystore
:: Usage: call :EnsureDebugKeystore
:: Purpose: creates an Android debug keystore when missing.
:: Returns:
::   0 keystore exists
::   5 creation failed
:: ============================================================
:EnsureDebugKeystore
if exist "%app.keystore%" exit /b 0
call :Blue DO: Creating debug keystore.
for %%A in ("%app.keystore%") do if not exist "%%~dpA" mkdir "%%~dpA" >nul 2>nul
"%app.keytool%" -genkeypair -v -keystore "%app.keystore%" -storepass "%app.keystore.pass%" -alias "%app.keystore.alias%" -keypass "%app.keystore.pass%" -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" -noprompt >> "%app.log%" 2>&1
set "edk_rc=%errorlevel%"
if not "%edk_rc%"=="0" ( call :Red FAIL: Debug keystore creation failed. & exit /b 5 )
set "edk_rc="
exit /b 0

:: ============================================================
:: Function: AlignAndSign
:: Usage: call :AlignAndSign
:: Purpose: zipaligns and signs the APK.
:: Returns:
::   0 signed APK created
::   5 signing failure
:: ============================================================
:AlignAndSign
call :Blue DO: Signing APK.
if exist "%app.aligned.apk%" del "%app.aligned.apk%" >nul 2>nul
if exist "%app.output.apk%" del "%app.output.apk%" >nul 2>nul
"%app.zipalign%" -f 4 "%app.unsigned.apk%" "%app.aligned.apk%" >> "%app.sign.log%" 2>&1
set "aas_rc=%errorlevel%"
if not "%aas_rc%"=="0" ( type "%app.sign.log%" & call :Red FAIL: zipalign failed. & call :Yellow LOG: %app.sign.log% & exit /b 5 )
call :SignApk
set "aas_rc=%errorlevel%"
if not "%aas_rc%"=="0" exit /b %aas_rc%
if not exist "%app.output.apk%" ( type "%app.sign.log%" & call :Red FAIL: signed APK was not produced. & call :Yellow LOG: %app.sign.log% & exit /b 5 )
set "aas_rc="
exit /b 0

:: ============================================================
:: Function: SignApk
:: Usage: call :SignApk
:: Purpose: signs app.aligned.apk into app.output.apk using direct apksigner.jar when possible.
:: Returns:
::   0 signed
::   5 signing failed
:: ============================================================
:SignApk
if exist "%app.apksigner.jar%" "%app.java.exe%" -jar "%app.apksigner.jar%" sign --ks "%app.keystore%" --ks-pass pass:%app.keystore.pass% --key-pass pass:%app.keystore.pass% --v1-signing-enabled true --v2-signing-enabled true --out "%app.output.apk%" "%app.aligned.apk%" >> "%app.sign.log%" 2>&1
if exist "%app.apksigner.jar%" set "sa_rc=%errorlevel%"
if exist "%app.apksigner.jar%" goto :SignApkCheck
call "%app.apksigner.bat%" sign --ks "%app.keystore%" --ks-pass pass:%app.keystore.pass% --key-pass pass:%app.keystore.pass% --v1-signing-enabled true --v2-signing-enabled true --out "%app.output.apk%" "%app.aligned.apk%" >> "%app.sign.log%" 2>&1
set "sa_rc=%errorlevel%"
:SignApkCheck
if not "%sa_rc%"=="0" ( type "%app.sign.log%" & call :Red FAIL: APK signing failed. & call :Yellow LOG: %app.sign.log% & exit /b 5 )
set "sa_rc="
exit /b 0

:: ============================================================
:: Function: InstallApk
:: Usage: call :InstallApk
:: Purpose: installs the built APK using adb.
:: Returns:
::   0 installed
::   6 adb/install failure
:: ============================================================
:InstallApk
if not defined app.adb ( call :Red FAIL: adb not found. Run prepare.bat or add platform-tools to PATH. & exit /b 6 )
call :Blue DO: Installing APK.
"%app.adb%" install -r "%app.output.apk%" >> "%app.log%" 2>&1
set "ia_rc=%errorlevel%"
if not "%ia_rc%"=="0" ( call :Red FAIL: adb install failed. & exit /b 6 )
call :Green OK: Installed.
set "ia_rc="
exit /b 0

:: ============================================================
:: Function: RunApp
:: Usage: call :RunApp
:: Purpose: launches the configured Android activity.
:: Returns:
::   0 launched or skipped
::   6 launch failure
:: ============================================================
:RunApp
if not defined app.launch.activity if defined app.launch_activity set "app.launch.activity=%app.launch_activity%"
if not defined app.launch.activity ( call :Yellow WARNING: app.launch.activity is not set; skipping launch. & exit /b 0 )
call :Blue DO: Launching app.
"%app.adb%" shell am start -n "%app.launch.activity%" >> "%app.log%" 2>&1
set "ra_rc=%errorlevel%"
if not "%ra_rc%"=="0" ( call :Red FAIL: App launch failed: %app.launch.activity% & exit /b 6 )
call :Green OK: Launched.
set "ra_rc="
exit /b 0

:: ============================================================
:: Function: Clean
:: Usage: call :Clean
:: Purpose: moves current dated build/source folders into oldbuilds.
:: Returns:
::   0 always
:: ============================================================
:Clean
call :CreateTimestamp
call :ArchiveOldDatedFolders
call :Green OK: Clean.
exit /b 0

:: ============================================================
:: Function: AppendQuotedForwardSlashPath
:: Usage: call :AppendQuotedForwardSlashPath "file" "path"
:: Purpose: appends a quoted path using forward slashes for javac/d8 response files.
:: Input:
::   %~1 response file
::   %~2 path
:: Returns:
::   0 always
:: ============================================================
:AppendQuotedForwardSlashPath
set "aqfsp_file=%~1"
set "aqfsp_path=%~2"
set "aqfsp_path=%aqfsp_path:\=/%"
>>"%aqfsp_file%" echo "%aqfsp_path%"
set "aqfsp_file="
set "aqfsp_path="
exit /b 0

:: ============================================================
:: Function: Green
:: Usage: call :Green message
:: Purpose: prints green message and writes plain text to build log when active.
:: Returns:
::   0 always
:: ============================================================
:Green
if defined app.esc echo %app.esc%[%app.color.green%%*%app.esc%[%app.color.reset%
if not defined app.esc echo %*
if defined app.log >> "%app.log%" echo %*
exit /b 0

:: ============================================================
:: Function: Yellow
:: Usage: call :Yellow message
:: Purpose: prints yellow message and writes plain text to build log when active.
:: Returns:
::   0 always
:: ============================================================
:Yellow
if defined app.esc echo %app.esc%[%app.color.yellow%%*%app.esc%[%app.color.reset%
if not defined app.esc echo %*
if defined app.log >> "%app.log%" echo %*
exit /b 0

:: ============================================================
:: Function: Red
:: Usage: call :Red message
:: Purpose: prints red message and writes plain text to build log when active.
:: Returns:
::   0 always
:: ============================================================
:Red
if defined app.esc echo %app.esc%[%app.color.red%%*%app.esc%[%app.color.reset%
if not defined app.esc echo %*
if defined app.log >> "%app.log%" echo %*
exit /b 0

:: ============================================================
:: Function: Blue
:: Usage: call :Blue message
:: Purpose: prints cyan message and writes plain text to build log when active.
:: Returns:
::   0 always
:: ============================================================
:Blue
if defined app.esc echo %app.esc%[%app.color.cyan%%*%app.esc%[%app.color.reset%
if not defined app.esc echo %*
if defined app.log >> "%app.log%" echo %*
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
:: Returns:
::   0 always
:: ============================================================
:SetAppColors
set "app.color.reset=0m"
set "app.color.red=31m"
set "app.color.green=32m"
set "app.color.yellow=33m"
set "app.color.cyan=36m"
exit /b 0
