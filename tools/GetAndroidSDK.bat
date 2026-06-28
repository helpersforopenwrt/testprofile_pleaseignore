@echo off
:setup
set "app.rc=0"
set "app.name=AndroidSdkDirect"
set "app.self=%~f0"
set "app.script.dir=%~dp0"
for %%A in ("%app.script.dir%.") do set "app.root=%%~fA"
set "app.dest=%app.root%\android-sdk"
set "app.downloads=%app.root%\downloads"
set "app.work=%app.root%\android-sdk-direct-work"
set "app.log=%app.root%\android-sdk-direct.log"
set "app.file.list=%app.root%\android-sdk-installed-files.txt"
set "app.plan.file=%app.root%\android-sdk-package-plan.txt"
set "app.repository.url=https://dl.google.com/android/repository/repository2-1.xml"
set "app.repository.baseurl=https://dl.google.com/android/repository/"
set "app.cmdline.tools.fallback.url=https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
set "app.platform.api.version=22"
set "app.platform.api.revision="
set "app.build.tools.version=28.0.3"
set "app.build.tools.revision="
set "app.cmdline.tools.version=latest"
set "app.cmdline.tools.revision="
set "app.platform.tools.version=current"
set "app.platform.tools.revision="
set "app.help="
set "app.list="
set "app.list.detail="
call :InitializeConsoleColors
call :ParseArgs %*
if errorlevel 1 ( set "app.rc=%errorlevel%" & goto :end )
if defined app.help call :ShowHelp
if defined app.help set "app.rc=0" & goto :end
if defined app.list call :ListAllAndroidSDKComponentVersions
if defined app.list set "app.rc=%errorlevel%" & goto :end
:main
call :GetDefaultAndroidSDK
if errorlevel 1 ( set "app.rc=%errorlevel%" & goto :end )
call :VerifyAndroidSDK
if errorlevel 1 ( set "app.rc=%errorlevel%" & goto :end )
call :CleanAndroidSDKWork
call :OK OK: Android SDK is ready.
call :OK DEST: %app.dest%
set "app.rc=0" & goto :end
:end
exit /b %app.rc%

:: ============================================================
:: :ParseArgs
:: Parses top-level command-line arguments.
::
:: Usage:
::   call :ParseArgs %*
::
:: Accepts:
::   help
::   /?
::   list
::   list detail
::   version list
::   version list detail
::   "destination-path"
::   BuildTools versionnumber [Revision revisionnumber]
::   CmdlineTools versionnumber [Revision revisionnumber]
::   Platforms versionnumber [Revision revisionnumber]
::   PlatformTools versionnumber [Revision revisionnumber]
::
:: Returns: 0 on success
::          2 invalid arguments
:: ============================================================
:ParseArgs
for /f "tokens=1 delims==" %%v in ('set pa_ 2^>nul') do set "%%v="
if defined _pa_rc (set "_pa_rc=" & exit /b %_pa_rc%)
:ParseArgs_loop
if "%~1"=="" set "_pa_rc=0" & goto :ParseArgs
if /I "%~1"=="help" set "app.help=1" & shift & goto :ParseArgs_loop
if /I "%~1"=="--help" set "app.help=1" & shift & goto :ParseArgs_loop
if /I "%~1"=="/help" set "app.help=1" & shift & goto :ParseArgs_loop
if "%~1"=="/?" set "app.help=1" & shift & goto :ParseArgs_loop
if /I "%~1"=="list" set "app.list=1" & shift & goto :ParseArgs_loop
if /I "%~1"=="detail" goto :ParseArgs_detail
if /I "%~1"=="version" goto :ParseArgs_version
if /I "%~1"=="BuildTools" goto :ParseArgs_buildtools
if /I "%~1"=="CmdlineTools" goto :ParseArgs_cmdlinetools
if /I "%~1"=="Platforms" goto :ParseArgs_platforms
if /I "%~1"=="PlatformTools" goto :ParseArgs_platformtools
if /I "%~1"=="Revision" call :Fail ERROR: Revision must follow a component version.
if /I "%~1"=="Revision" set "_pa_rc=2" & goto :ParseArgs
if defined pa_dest_seen call :Fail ERROR: unexpected argument: %~1
if defined pa_dest_seen set "_pa_rc=2" & goto :ParseArgs
for %%D in ("%~1") do set "app.dest=%%~fD"
set "pa_dest_seen=1"
shift
goto :ParseArgs_loop
:ParseArgs_detail
if not defined app.list call :Fail ERROR: detail can only be used with list or version list.
if not defined app.list set "_pa_rc=2" & goto :ParseArgs
set "app.list.detail=1"
shift
goto :ParseArgs_loop
:ParseArgs_version
if /I "%~2"=="list" set "app.list=1" & shift & shift & goto :ParseArgs_loop
call :Fail ERROR: version must be followed by list at top level.
set "_pa_rc=2" & goto :ParseArgs
:ParseArgs_buildtools
if "%~2"=="" call :Fail ERROR: BuildTools requires a version number.
if "%~2"=="" set "_pa_rc=2" & goto :ParseArgs
set "app.build.tools.version=%~2"
shift
shift
if /I "%~1"=="Revision" goto :ParseArgs_buildtools_revision
goto :ParseArgs_loop
:ParseArgs_buildtools_revision
if "%~2"=="" call :Fail ERROR: BuildTools Revision requires a value.
if "%~2"=="" set "_pa_rc=2" & goto :ParseArgs
set "app.build.tools.revision=%~2"
shift
shift
goto :ParseArgs_loop
:ParseArgs_cmdlinetools
if "%~2"=="" call :Fail ERROR: CmdlineTools requires a version number.
if "%~2"=="" set "_pa_rc=2" & goto :ParseArgs
set "app.cmdline.tools.version=%~2"
shift
shift
if /I "%~1"=="Revision" goto :ParseArgs_cmdlinetools_revision
goto :ParseArgs_loop
:ParseArgs_cmdlinetools_revision
if "%~2"=="" call :Fail ERROR: CmdlineTools Revision requires a value.
if "%~2"=="" set "_pa_rc=2" & goto :ParseArgs
set "app.cmdline.tools.revision=%~2"
shift
shift
goto :ParseArgs_loop
:ParseArgs_platforms
if "%~2"=="" call :Fail ERROR: Platforms requires a version number.
if "%~2"=="" set "_pa_rc=2" & goto :ParseArgs
set "pa_platform_value=%~2"
if /I "%pa_platform_value:~0,8%"=="android-" set "pa_platform_value=%pa_platform_value:~8%"
set "app.platform.api.version=%pa_platform_value%"
shift
shift
if /I "%~1"=="Revision" goto :ParseArgs_platforms_revision
goto :ParseArgs_loop
:ParseArgs_platforms_revision
if "%~2"=="" call :Fail ERROR: Platforms Revision requires a value.
if "%~2"=="" set "_pa_rc=2" & goto :ParseArgs
set "app.platform.api.revision=%~2"
shift
shift
goto :ParseArgs_loop
:ParseArgs_platformtools
if "%~2"=="" call :Fail ERROR: PlatformTools requires a version number.
if "%~2"=="" set "_pa_rc=2" & goto :ParseArgs
set "app.platform.tools.version=%~2"
shift
shift
if /I "%~1"=="Revision" goto :ParseArgs_platformtools_revision
goto :ParseArgs_loop
:ParseArgs_platformtools_revision
if "%~2"=="" call :Fail ERROR: PlatformTools Revision requires a value.
if "%~2"=="" set "_pa_rc=2" & goto :ParseArgs
set "app.platform.tools.revision=%~2"
shift
shift
goto :ParseArgs_loop

:: ============================================================
:: :ShowHelp
:: Prints command-line usage and component function examples.
::
:: Usage:
::   call :ShowHelp
::
:: Returns: 0
:: ============================================================
:ShowHelp
echo Usage:
echo   android-sdk-direct.bat
echo   android-sdk-direct.bat "destination-path"
echo   android-sdk-direct.bat list
echo   android-sdk-direct.bat list detail
echo   android-sdk-direct.bat version list
echo   android-sdk-direct.bat version list detail
echo   android-sdk-direct.bat BuildTools 28.0.3 Platforms 22 CmdlineTools latest PlatformTools current
echo   android-sdk-direct.bat Platforms 34 Revision 3
echo.
echo Default destination:
echo   .\android-sdk
echo.
echo This script downloads public Android SDK package ZIPs directly,
echo unpacks them manually, and does not run sdkmanager or Android SDK Java code.
echo.
echo Top-level version keywords are case-insensitive:
echo   BuildTools versionnumber [Revision revisionnumber]
echo   CmdlineTools versionnumber [Revision revisionnumber]
echo   Platforms versionnumber [Revision revisionnumber]
echo   PlatformTools versionnumber [Revision revisionnumber]
echo.
echo Component function examples:
echo   call :GetAndroidBuildTools version 28.0.3
echo   call :GetAndroidBuildTools version 28.0.3 Revision 28.0.3
echo   call :GetAndroidBuildTools version list
echo   call :GetAndroidBuildTools version list detail
echo.
echo   call :GetAndroidCmdlineTools version latest
echo   call :GetAndroidCmdlineTools version list
echo.
echo   call :GetAndroidPlatforms version 22
echo   call :GetAndroidPlatforms version 34 Revision 3
echo   call :GetAndroidPlatforms version list detail
echo.
echo   call :GetAndroidPlatformTools version current
echo   call :GetAndroidPlatformTools version list
exit /b 0

:: ============================================================
:: :GetDefaultAndroidSDK
:: Downloads the default configured SDK component set.
::
:: Usage:
::   call :GetDefaultAndroidSDK
::
:: Components:
::   platform-tools
::   platforms;android-%app.platform.api.version%
::   build-tools;%app.build.tools.version%
::   cmdline-tools;%app.cmdline.tools.version%
::
:: Returns: 0 on success, non-zero on failure
:: ============================================================
:GetDefaultAndroidSDK
for /f "tokens=1 delims==" %%v in ('set gdas_ 2^>nul') do set "%%v="
if defined _gdas_rc (set "_gdas_rc=" & exit /b %_gdas_rc%)
call :CreateAndroidSDKFolders
if errorlevel 1 set "_gdas_rc=%errorlevel%" & goto :GetDefaultAndroidSDK
call :GetAndroidPlatformTools "%app.dest%"
if errorlevel 1 set "_gdas_rc=%errorlevel%" & goto :GetDefaultAndroidSDK
call :GetAndroidPlatforms "%app.dest%"
if errorlevel 1 set "_gdas_rc=%errorlevel%" & goto :GetDefaultAndroidSDK
call :GetAndroidBuildTools "%app.dest%"
if errorlevel 1 set "_gdas_rc=%errorlevel%" & goto :GetDefaultAndroidSDK
call :GetAndroidCmdlineTools "%app.dest%"
if errorlevel 1 set "_gdas_rc=%errorlevel%" & goto :GetDefaultAndroidSDK
set "_gdas_rc=0" & goto :GetDefaultAndroidSDK

:: ============================================================
:: :GetAndroidSDKComponent
:: Handles list/install behavior for one Android SDK component.
::
:: Usage:
::   call :GetAndroidSDKComponent component default-version default-revision args...
::
:: Components:
::   build-tools
::   cmdline-tools
::   platforms
::   platform-tools
::
:: Returns: 0 on success, non-zero on failure
:: Requires:
::   :ParseAndroidComponentArgs
::   :ListAndroidSDKComponentVersions
::   :InstallAndroidSDKComponent
:: ============================================================
:GetAndroidSDKComponent
for /f "tokens=1 delims==" %%v in ('set gasc_ 2^>nul') do set "%%v="
if defined _gasc_rc (set "_gasc_rc=" & exit /b %_gasc_rc%)
set "gasc_component=%~1"
set "gasc_default_version=%~2"
set "gasc_default_revision=%~3"
shift
shift
shift
call :ParseAndroidComponentArgs "%gasc_default_version%" "%gasc_default_revision%" %1 %2 %3 %4 %5 %6 %7 %8 %9
if errorlevel 1 set "_gasc_rc=%errorlevel%" & goto :GetAndroidSDKComponent
if /I "%app.component.mode%"=="list" call :ListAndroidSDKComponentVersions "%gasc_component%" "%app.component.detail%"
if /I "%app.component.mode%"=="list" set "_gasc_rc=%errorlevel%" & goto :GetAndroidSDKComponent
call :InstallAndroidSDKComponent "%gasc_component%" "%app.component.version%" "%app.component.destination%" "%app.component.revision%"
set "_gasc_rc=%errorlevel%" & goto :GetAndroidSDKComponent

:: ============================================================
:: :GetAndroidBuildTools
:: Downloads, installs, or lists Android SDK build-tools.
::
:: Usage:
::   call :GetAndroidBuildTools
::   call :GetAndroidBuildTools "destination-path"
::   call :GetAndroidBuildTools version 28.0.3
::   call :GetAndroidBuildTools version 28.0.3 Revision 28.0.3
::   call :GetAndroidBuildTools version list
::   call :GetAndroidBuildTools version list detail
::
:: Returns: 0 on success, non-zero on failure
:: ============================================================
:GetAndroidBuildTools
for /f "tokens=1 delims==" %%v in ('set gabt_ 2^>nul') do set "%%v="
if defined _gabt_rc (set "_gabt_rc=" & exit /b %_gabt_rc%)
call :GetAndroidSDKComponent build-tools "%app.build.tools.version%" "%app.build.tools.revision%" %*
set "_gabt_rc=%errorlevel%" & goto :GetAndroidBuildTools

:: ============================================================
:: :GetAndroidCmdlineTools
:: Downloads, installs, or lists Android SDK command-line tools.
::
:: Usage:
::   call :GetAndroidCmdlineTools
::   call :GetAndroidCmdlineTools "destination-path"
::   call :GetAndroidCmdlineTools version latest
::   call :GetAndroidCmdlineTools version latest Revision 20.0
::   call :GetAndroidCmdlineTools version list
::   call :GetAndroidCmdlineTools version list detail
::
:: Returns: 0 on success, non-zero on failure
:: ============================================================
:GetAndroidCmdlineTools
for /f "tokens=1 delims==" %%v in ('set gact_ 2^>nul') do set "%%v="
if defined _gact_rc (set "_gact_rc=" & exit /b %_gact_rc%)
call :GetAndroidSDKComponent cmdline-tools "%app.cmdline.tools.version%" "%app.cmdline.tools.revision%" %*
set "_gact_rc=%errorlevel%" & goto :GetAndroidCmdlineTools

:: ============================================================
:: :GetAndroidPlatforms
:: Downloads, installs, or lists Android SDK platforms.
::
:: Usage:
::   call :GetAndroidPlatforms
::   call :GetAndroidPlatforms "destination-path"
::   call :GetAndroidPlatforms version 22
::   call :GetAndroidPlatforms version android-22
::   call :GetAndroidPlatforms version 34 Revision 3
::   call :GetAndroidPlatforms version list
::   call :GetAndroidPlatforms version list detail
::
:: Returns: 0 on success, non-zero on failure
:: ============================================================
:GetAndroidPlatforms
for /f "tokens=1 delims==" %%v in ('set gap_ 2^>nul') do set "%%v="
if defined _gap_rc (set "_gap_rc=" & exit /b %_gap_rc%)
call :GetAndroidSDKComponent platforms "%app.platform.api.version%" "%app.platform.api.revision%" %*
set "_gap_rc=%errorlevel%" & goto :GetAndroidPlatforms

:: ============================================================
:: :GetAndroidPlatformTools
:: Downloads, installs, or lists Android SDK platform-tools.
::
:: Usage:
::   call :GetAndroidPlatformTools
::   call :GetAndroidPlatformTools "destination-path"
::   call :GetAndroidPlatformTools version current
::   call :GetAndroidPlatformTools version current Revision 37.0.0
::   call :GetAndroidPlatformTools version list
::   call :GetAndroidPlatformTools version list detail
::
:: Returns: 0 on success, non-zero on failure
:: ============================================================
:GetAndroidPlatformTools
for /f "tokens=1 delims==" %%v in ('set gapt_ 2^>nul') do set "%%v="
if defined _gapt_rc (set "_gapt_rc=" & exit /b %_gapt_rc%)
call :GetAndroidSDKComponent platform-tools "%app.platform.tools.version%" "%app.platform.tools.revision%" %*
set "_gapt_rc=%errorlevel%" & goto :GetAndroidPlatformTools

:: ============================================================
:: :ParseAndroidComponentArgs
:: Parses optional destination, version, revision, and detail args.
::
:: Usage:
::   call :ParseAndroidComponentArgs default-version default-revision [destination] [version value] [Revision value] [detail]
::   call :ParseAndroidComponentArgs default-version default-revision [destination] version list [detail]
::
:: Output:
::   app.component.destination
::   app.component.version
::   app.component.revision
::   app.component.mode
::   app.component.detail
::
:: Returns: 0 on success
::          2 invalid arguments
:: ============================================================
:ParseAndroidComponentArgs
for /f "tokens=1 delims==" %%v in ('set paca_ 2^>nul') do set "%%v="
if defined _paca_rc (set "_paca_rc=" & exit /b %_paca_rc%)
set "app.component.destination=%app.dest%"
set "app.component.version=%~1"
set "app.component.revision=%~2"
set "app.component.mode=install"
set "app.component.detail="
shift
shift
:ParseAndroidComponentArgs_loop
if "%~1"=="" set "_paca_rc=0" & goto :ParseAndroidComponentArgs
if /I "%~1"=="version" goto :ParseAndroidComponentArgs_version
if /I "%~1"=="Revision" goto :ParseAndroidComponentArgs_revision
if /I "%~1"=="detail" set "app.component.detail=1" & shift & goto :ParseAndroidComponentArgs_loop
if defined paca_dest_seen call :Fail ERROR: unexpected argument: %~1
if defined paca_dest_seen set "_paca_rc=2" & goto :ParseAndroidComponentArgs
for %%D in ("%~1") do set "app.component.destination=%%~fD"
set "paca_dest_seen=1"
shift
goto :ParseAndroidComponentArgs_loop
:ParseAndroidComponentArgs_version
if "%~2"=="" call :Fail ERROR: version requires a value or list.
if "%~2"=="" set "_paca_rc=2" & goto :ParseAndroidComponentArgs
if /I "%~2"=="list" set "app.component.mode=list" & shift & shift & goto :ParseAndroidComponentArgs_loop
set "app.component.version=%~2"
shift
shift
goto :ParseAndroidComponentArgs_loop
:ParseAndroidComponentArgs_revision
if "%~2"=="" call :Fail ERROR: Revision requires a value.
if "%~2"=="" set "_paca_rc=2" & goto :ParseAndroidComponentArgs
set "app.component.revision=%~2"
shift
shift
goto :ParseAndroidComponentArgs_loop

:: ============================================================
:: :ListAllAndroidSDKComponentVersions
:: Lists available versions for all supported SDK components.
::
:: Usage:
::   call :ListAllAndroidSDKComponentVersions
::
:: Honors:
::   app.list.detail
::
:: Returns: 0 on success, non-zero on failure
:: ============================================================
:ListAllAndroidSDKComponentVersions
for /f "tokens=1 delims==" %%v in ('set lasdkcv_ 2^>nul') do set "%%v="
if defined _lasdkcv_rc (set "_lasdkcv_rc=" & exit /b %_lasdkcv_rc%)
call :ListAndroidSDKComponentVersions build-tools "%app.list.detail%"
if errorlevel 1 set "_lasdkcv_rc=%errorlevel%" & goto :ListAllAndroidSDKComponentVersions
call :ListAndroidSDKComponentVersions cmdline-tools "%app.list.detail%"
if errorlevel 1 set "_lasdkcv_rc=%errorlevel%" & goto :ListAllAndroidSDKComponentVersions
call :ListAndroidSDKComponentVersions platforms "%app.list.detail%"
if errorlevel 1 set "_lasdkcv_rc=%errorlevel%" & goto :ListAllAndroidSDKComponentVersions
call :ListAndroidSDKComponentVersions platform-tools "%app.list.detail%"
if errorlevel 1 set "_lasdkcv_rc=%errorlevel%" & goto :ListAllAndroidSDKComponentVersions
set "_lasdkcv_rc=0" & goto :ListAllAndroidSDKComponentVersions

:: ============================================================
:: :InstallAndroidSDKComponent
:: Resolves, downloads, verifies, unpacks, and installs one SDK component.
::
:: Usage:
::   call :InstallAndroidSDKComponent component version destination [revision]
::
:: Returns: 0 on success, non-zero on failure
:: ============================================================
:InstallAndroidSDKComponent
for /f "tokens=1 delims==" %%v in ('set iasc_ 2^>nul') do set "%%v="
if defined _iasc_rc (set "_iasc_rc=" & exit /b %_iasc_rc%)
set "iasc_component=%~1"
set "iasc_version=%~2"
set "iasc_destination=%~3"
set "iasc_revision=%~4"
if not defined iasc_destination set "iasc_destination=%app.dest%"
call :CreateAndroidSDKFolders
if errorlevel 1 set "_iasc_rc=%errorlevel%" & goto :InstallAndroidSDKComponent
call :DownloadRepositoryManifest
if errorlevel 1 set "_iasc_rc=%errorlevel%" & goto :InstallAndroidSDKComponent
call :ResolveAndroidSDKPackage "%iasc_component%" "%iasc_version%" "%iasc_revision%"
if errorlevel 1 set "_iasc_rc=%errorlevel%" & goto :InstallAndroidSDKComponent
call :Info COMPONENT: %iasc_component% version %iasc_version% revision %app.package.revision%
call :Info DEST: %iasc_destination%
call :VerifyAndroidPackageArchive "%app.package.zip%" "%app.package.size%" "%app.package.checksum.type%" "%app.package.checksum%" "%app.package.min.size%"
if not errorlevel 1 goto :InstallAndroidSDKComponent_unpack
if exist "%app.package.zip%" del /Q "%app.package.zip%" >nul 2>&1
call :DownloadFile "%app.package.url%" "%app.package.zip%"
if errorlevel 1 set "_iasc_rc=%errorlevel%" & goto :InstallAndroidSDKComponent
call :VerifyAndroidPackageArchive "%app.package.zip%" "%app.package.size%" "%app.package.checksum.type%" "%app.package.checksum%" "%app.package.min.size%"
if errorlevel 1 set "_iasc_rc=%errorlevel%" & goto :InstallAndroidSDKComponent
:InstallAndroidSDKComponent_unpack
call :OK OK: verified package ZIP: %app.package.file%
call :ExpandZipToFolder "%app.package.zip%" "%app.work%\%app.package.safe.name%"
if errorlevel 1 set "_iasc_rc=%errorlevel%" & goto :InstallAndroidSDKComponent
call :InstallExtractedAndroidPackage "%app.work%\%app.package.safe.name%" "%iasc_destination%" "%app.package.destination%" "%app.package.marker%" "%app.package.source.mode%"
if errorlevel 1 set "_iasc_rc=%errorlevel%" & goto :InstallAndroidSDKComponent
call :SaveAndroidPackagePlan "%iasc_destination%"
if errorlevel 1 set "_iasc_rc=%errorlevel%" & goto :InstallAndroidSDKComponent
call :OK OK: installed %app.package.path% revision %app.package.revision% to %iasc_destination%\%app.package.destination%
set "_iasc_rc=0" & goto :InstallAndroidSDKComponent

:: ============================================================
:: :CreateAndroidSDKFolders
:: Creates download, work, and log folders.
::
:: Usage:
::   call :CreateAndroidSDKFolders
::
:: Returns: 0 on success, 1 on failure
:: ============================================================
:CreateAndroidSDKFolders
for /f "tokens=1 delims==" %%v in ('set casf_ 2^>nul') do set "%%v="
if defined _casf_rc (set "_casf_rc=" & exit /b %_casf_rc%)
if not exist "%app.downloads%\" mkdir "%app.downloads%" >nul 2>&1
if not exist "%app.work%\" mkdir "%app.work%" >nul 2>&1
if not exist "%app.downloads%\" call :Fail FAIL: could not create %app.downloads%
if not exist "%app.downloads%\" set "_casf_rc=1" & goto :CreateAndroidSDKFolders
if not exist "%app.work%\" call :Fail FAIL: could not create %app.work%
if not exist "%app.work%\" set "_casf_rc=1" & goto :CreateAndroidSDKFolders
if not defined app.log.started echo %app.name% log> "%app.log%"
if not defined app.log.started set "app.log.started=1"
set "_casf_rc=0" & goto :CreateAndroidSDKFolders

:: ============================================================
:: :DownloadRepositoryManifest
:: Downloads Google's public Android SDK repository manifest.
::
:: Usage:
::   call :DownloadRepositoryManifest
::
:: Returns: 0 on success, non-zero on failure
:: ============================================================
:DownloadRepositoryManifest
for /f "tokens=1 delims==" %%v in ('set drm_ 2^>nul') do set "%%v="
if defined _drm_rc (set "_drm_rc=" & exit /b %_drm_rc%)
if defined app.repository.manifest.ready set "_drm_rc=0" & goto :DownloadRepositoryManifest
set "drm_file=%app.downloads%\repository2-1.xml"
set "drm_size="
if not exist "%drm_file%" goto :DownloadRepositoryManifestDownload
for %%F in ("%drm_file%") do set "drm_size=%%~zF"
if not defined drm_size goto :DownloadRepositoryManifestDownload
if %drm_size% GTR 100000 goto :DownloadRepositoryManifestExisting
goto :DownloadRepositoryManifestDownload
:DownloadRepositoryManifestExisting
call :OK OK: using existing repository manifest.
set "app.repository.manifest.ready=1"
set "_drm_rc=0" & goto :DownloadRepositoryManifest
:DownloadRepositoryManifestDownload
call :DownloadFile "%app.repository.url%" "%drm_file%"
if errorlevel 1 set "_drm_rc=%errorlevel%" & goto :DownloadRepositoryManifest
set "app.repository.manifest.ready=1"
set "_drm_rc=0" & goto :DownloadRepositoryManifest

:: ============================================================
:: :ResolveAndroidSDKPackage
:: Resolves one Android SDK package from repository2-1.xml.
::
:: Usage:
::   call :ResolveAndroidSDKPackage component version [revision]
::
:: Component path mapping:
::   build-tools     version maps to build-tools;version
::   cmdline-tools   version maps to cmdline-tools;version
::   platforms       version maps to platforms;android-version
::   platform-tools  version is friendly only; path is platform-tools
::
:: Notes:
::   If revision is omitted, the highest matching revision is used.
::   PowerShell writes app.package.*=value lines, which CMD imports
::   using for /f "tokens=1,* delims==".
::
:: Output:
::   app.package.*
::
:: Returns: 0 on success, 1 on failure
:: ============================================================
:ResolveAndroidSDKPackage
for /f "tokens=1 delims==" %%v in ('set rasp_ 2^>nul') do set "%%v="
if defined _rasp_rc (set "_rasp_rc=" & exit /b %_rasp_rc%)
for /f "tokens=1 delims==" %%v in ('set app.package. 2^>nul') do set "%%v="
set "rasp_component=%~1"
set "rasp_version=%~2"
set "rasp_revision=%~3"
set "rasp_manifest=%app.downloads%\repository2-1.xml"
set "rasp_script=$ErrorActionPreference='Stop';[xml]$xml=Get-Content -LiteralPath $env:rasp_manifest;$component=$env:rasp_component;$version=$env:rasp_version;$requestedRevision=$env:rasp_revision;$base=[Environment]::GetEnvironmentVariable('app.repository.baseurl');$fallback=[Environment]::GetEnvironmentVariable('app.cmdline.tools.fallback.url');$packagePath='';$hostOs='';$marker='';$destination='';$sourceMode='MarkerDirectory';$minSize='1000000';"
set "rasp_script=%rasp_script%if($component -eq 'build-tools'){$packagePath='build-tools;'+$version;$hostOs='windows';$marker='aapt.exe';$destination='build-tools\'+$version;$minSize='10000000'}elseif($component -eq 'platforms'){$platformVersion=$version;if($platformVersion.StartsWith('android-',[StringComparison]::OrdinalIgnoreCase)){$platformVersion=$platformVersion.Substring(8)};$packagePath='platforms;android-'+$platformVersion;$hostOs='';$marker='android.jar';$destination='platforms\android-'+$platformVersion}elseif($component -eq 'cmdline-tools'){$packagePath='cmdline-tools;'+$version;$hostOs='windows';$marker='sdkmanager.bat';$destination='cmdline-tools\'+$version;$sourceMode='ParentOfMarkerDirectory';$minSize='10000000'}elseif($component -eq 'platform-tools'){$packagePath='platform-tools';$hostOs='windows';$marker='adb.exe';$destination='platform-tools'}else{throw ('unknown component: '+$component)};"
set "rasp_script=%rasp_script%function Get-NodeText($node,$xpath){$found=$node.SelectSingleNode($xpath);if($null -eq $found){return ''};return $found.InnerText.Trim()};"
set "rasp_script=%rasp_script%function Get-PackageRevision($package){$revisionNode=$package.SelectSingleNode('*[local-name()=''revision'']');if($null -eq $revisionNode){return ''};$parts=@();foreach($name in 'major','minor','micro'){$value=Get-NodeText $revisionNode ('*[local-name()='''+$name+''']');if($value){$parts+=$value}};return ($parts -join '.')};"
set "rasp_script=%rasp_script%function Get-PackageRevisionKey($package){$revision=Get-PackageRevision $package;$out=@();foreach($part in $revision.Split('.')){$number=0;[void][int]::TryParse($part,[ref]$number);$out+=$number.ToString('000000')};while($out.Count -lt 3){$out+='000000'};return ($out -join '.')};"
set "rasp_script=%rasp_script%$allPackages=@($xml.SelectNodes('//*[local-name()=''remotePackage'']'));$matches=@();foreach($package in $allPackages){if($package.GetAttribute('path') -eq $packagePath){$matches+=$package}};"
set "rasp_script=%rasp_script%if($matches.Count -eq 0 -and $packagePath -eq 'cmdline-tools;latest'){$url=$fallback;$fileName=[IO.Path]::GetFileName(([Uri]$url).AbsolutePath);Write-Output ('app.package.path='+$packagePath);Write-Output 'app.package.revision=';Write-Output ('app.package.url='+$url);Write-Output ('app.package.file='+$fileName);Write-Output 'app.package.checksum.type=';Write-Output 'app.package.checksum=';Write-Output 'app.package.size=';Write-Output ('app.package.destination='+$destination);Write-Output ('app.package.marker='+$marker);Write-Output ('app.package.source.mode='+$sourceMode);Write-Output ('app.package.min.size='+$minSize);exit 0};"
set "rasp_script=%rasp_script%if($matches.Count -eq 0){throw ('package path not found: '+$packagePath)};"
set "rasp_script=%rasp_script%if(-not [string]::IsNullOrWhiteSpace($requestedRevision)){$filtered=@();foreach($package in $matches){if((Get-PackageRevision $package) -eq $requestedRevision){$filtered+=$package}};$matches=$filtered;if($matches.Count -eq 0){throw ('requested revision not found: '+$packagePath+' revision '+$requestedRevision)}};"
set "rasp_script=%rasp_script%$chosenPackage=@($matches|Sort-Object{Get-PackageRevisionKey $_} -Descending|Select-Object -First 1)[0];$revision=Get-PackageRevision $chosenPackage;$archives=@($chosenPackage.SelectNodes('*[local-name()=''archives'']/*[local-name()=''archive'']'));if($archives.Count -eq 0){throw ('package has no archives: '+$packagePath)};"
set "rasp_script=%rasp_script%$chosenArchive=$null;foreach($archive in $archives){$archiveHost=Get-NodeText $archive '*[local-name()=''host-os'']';if([string]::IsNullOrWhiteSpace($hostOs)){if([string]::IsNullOrWhiteSpace($archiveHost)){$chosenArchive=$archive;break}}else{if($archiveHost -eq $hostOs){$chosenArchive=$archive;break}}};if($null -eq $chosenArchive){$chosenArchive=@($archives|Select-Object -First 1)[0]};if($null -eq $chosenArchive){throw ('no usable archive found: '+$packagePath)};"
set "rasp_script=%rasp_script%$url=Get-NodeText $chosenArchive '*[local-name()=''complete'']/*[local-name()=''url'']';if([string]::IsNullOrWhiteSpace($url)){throw ('archive URL missing: '+$packagePath)};if($url -notmatch '^https?://'){$url=$base+$url};$checksum=Get-NodeText $chosenArchive '*[local-name()=''complete'']/*[local-name()=''checksum'']';$size=Get-NodeText $chosenArchive '*[local-name()=''complete'']/*[local-name()=''size'']';"
set "rasp_script=%rasp_script%$checksumNode=$chosenArchive.SelectSingleNode('*[local-name()=''complete'']/*[local-name()=''checksum'']');$checksumType='sha1';if($null -ne $checksumNode -and $checksumNode.HasAttribute('type')){$checksumType=$checksumNode.GetAttribute('type')};$fileName=[IO.Path]::GetFileName(([Uri]$url).AbsolutePath);"
set "rasp_script=%rasp_script%Write-Output ('app.package.path='+$packagePath);Write-Output ('app.package.revision='+$revision);Write-Output ('app.package.url='+$url);Write-Output ('app.package.file='+$fileName);Write-Output ('app.package.checksum.type='+$checksumType);Write-Output ('app.package.checksum='+$checksum);Write-Output ('app.package.size='+$size);Write-Output ('app.package.destination='+$destination);Write-Output ('app.package.marker='+$marker);Write-Output ('app.package.source.mode='+$sourceMode);Write-Output ('app.package.min.size='+$minSize);"
for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create($env:rasp_script))" 2^>^> "%app.log%"') do set "%%A=%%B"
if not defined app.package.url call :Fail FAIL: could not resolve SDK package %rasp_component% version %rasp_version% revision %rasp_revision%.
if not defined app.package.url set "_rasp_rc=1" & goto :ResolveAndroidSDKPackage
set "app.package.zip=%app.downloads%\%app.package.file%"
set "app.package.safe.name=%app.package.path:;=_%"
set "app.package.safe.name=%app.package.safe.name:/=_%"
set "_rasp_rc=0" & goto :ResolveAndroidSDKPackage

:: ============================================================
:: :ListAndroidSDKComponentVersions
:: Lists available versions for a component from repository2-1.xml.
::
:: Usage:
::   call :ListAndroidSDKComponentVersions component
::   call :ListAndroidSDKComponentVersions component detail
::
:: Components:
::   build-tools
::   cmdline-tools
::   platforms
::   platform-tools
::
:: Returns: 0 on success, non-zero on failure
:: ============================================================
:ListAndroidSDKComponentVersions
for /f "tokens=1 delims==" %%v in ('set lascv_ 2^>nul') do set "%%v="
if defined _lascv_rc (set "_lascv_rc=" & exit /b %_lascv_rc%)
set "lascv_component=%~1"
set "lascv_detail=%~2"
set "lascv_manifest=%app.downloads%\repository2-1.xml"
call :CreateAndroidSDKFolders
if errorlevel 1 set "_lascv_rc=%errorlevel%" & goto :ListAndroidSDKComponentVersions
call :DownloadRepositoryManifest
if errorlevel 1 set "_lascv_rc=%errorlevel%" & goto :ListAndroidSDKComponentVersions
set "lascv_script=$ErrorActionPreference='Stop';[xml]$x=Get-Content -LiteralPath $env:lascv_manifest;$c=$env:lascv_component;$detail=$env:lascv_detail;$base=[Environment]::GetEnvironmentVariable('app.repository.baseurl');$esc=[char]27;function Get-NodeText($n,$p){$r=$n.SelectSingleNode($p);if($null -eq $r){return ''};return $r.InnerText.Trim()};function Get-RevisionText($p){$r=$p.SelectSingleNode('*[local-name()=''revision'']');if($null -eq $r){return ''};$a=@();foreach($n in 'major','minor','micro'){$q=Get-NodeText $r ('*[local-name()='''+$n+''']');if($q){$a+=$q}};return ($a -join '.')};function Get-RevisionKey($p){$t=Get-RevisionText $p;$a=@();foreach($part in $t.Split('.')){$n=0;[void][int]::TryParse($part,[ref]$n);$a+=$n.ToString('000000')};return ($a -join '.')};function Get-Value($path,$prefix){if($path.StartsWith($prefix)){return $path.Substring($prefix.Length)};return $path};function Get-ArchiveFile($pkg,$hostOs){$archives=@($pkg.SelectNodes('*[local-name()=''archives'']/*[local-name()=''archive'']'));$chosen=$null;foreach($a in $archives){$ah=Get-NodeText $a '*[local-name()=''host-os'']';if([string]::IsNullOrWhiteSpace($hostOs)){if([string]::IsNullOrWhiteSpace($ah)){$chosen=$a;break}}else{if($ah -eq $hostOs){$chosen=$a;break}}};if($null -eq $chosen){$chosen=$archives|Select-Object -First 1};if($null -eq $chosen){return ''};$u=Get-NodeText $chosen '*[local-name()=''complete'']/*[local-name()=''url'']';if([string]::IsNullOrWhiteSpace($u)){return ''};if($u -notmatch '^https?://'){$u=$base+$u};return [IO.Path]::GetFileName(([Uri]$u).AbsolutePath)};function Write-Title($s){Write-Host ($esc+'[36m'+$s+$esc+'[0m')};function Write-Header{if($detail){Write-Host ('  '+('Version'.PadRight(18))+('Revision'.PadRight(12))+('Path'.PadRight(36))+'Archive')}else{Write-Host ('  '+('Version'.PadRight(18))+'Revision')}};function Write-Row($v,$r,$p,$a){if($detail){Write-Host ('  '+$esc+'[32m'+($v.PadRight(18))+($r.PadRight(12))+($p.PadRight(36))+$a+$esc+'[0m')}else{Write-Host ('  '+$esc+'[32m'+($v.PadRight(18))+$r+$esc+'[0m')}};$pkgs=$x.SelectNodes('//*[local-name()=''remotePackage'']');if($c -eq 'build-tools'){$title='BUILD-TOOLS';$prefix='build-tools;';$hostOs='windows';$rows=$pkgs|Where-Object{$_.GetAttribute('path') -like 'build-tools;*'}|Group-Object{$_.GetAttribute('path')}|ForEach-Object{$_.Group|Sort-Object{Get-RevisionKey $_} -Descending|Select-Object -First 1}|Sort-Object{try{[version]((Get-Value $_.GetAttribute('path') $prefix) -replace '-.*$','')}catch{[version]'0.0'}}}elseif($c -eq 'cmdline-tools'){$title='CMDLINE-TOOLS';$prefix='cmdline-tools;';$hostOs='windows';$rows=$pkgs|Where-Object{$_.GetAttribute('path') -like 'cmdline-tools;*'}|Group-Object{$_.GetAttribute('path')}|ForEach-Object{$_.Group|Sort-Object{Get-RevisionKey $_} -Descending|Select-Object -First 1}|Sort-Object{if((Get-Value $_.GetAttribute('path') $prefix) -eq 'latest'){[version]'999.0'}else{try{[version]((Get-Value $_.GetAttribute('path') $prefix) -replace '-.*$','')}catch{[version]'0.0'}}}}elseif($c -eq 'platforms'){$title='PLATFORMS';$prefix='platforms;android-';$hostOs='';$rows=$pkgs|Where-Object{$_.GetAttribute('path') -like 'platforms;android-*'}|Group-Object{$_.GetAttribute('path')}|ForEach-Object{$_.Group|Sort-Object{Get-RevisionKey $_} -Descending|Select-Object -First 1}|Sort-Object @{Expression={try{[int](Get-Value $_.GetAttribute('path') $prefix)}catch{9999}}},@{Expression={Get-Value $_.GetAttribute('path') $prefix}}}elseif($c -eq 'platform-tools'){$title='PLATFORM-TOOLS';$prefix='platform-tools';$hostOs='windows';$rows=@($pkgs|Where-Object{$_.GetAttribute('path') -eq 'platform-tools'}|Select-Object -First 1)}else{exit 2};Write-Title $title;Write-Header;foreach($r in $rows){if($null -eq $r){continue};$p=$r.GetAttribute('path');if($c -eq 'platform-tools'){$v='current'}else{$v=Get-Value $p $prefix};$rev=Get-RevisionText $r;$archive=Get-ArchiveFile $r $hostOs;Write-Row $v $rev $p $archive};Write-Host '';exit 0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create($env:lascv_script))"
set "_lascv_rc=%errorlevel%" & goto :ListAndroidSDKComponentVersions

:: ============================================================
:: :VerifyAndroidPackageArchive
:: Verifies package ZIP size and checksum when metadata is available.
::
:: Usage:
::   call :VerifyAndroidPackageArchive "zip" "size" "checksum-type" "checksum" "minimum-size"
::
:: Returns: 0 if valid, 1 if invalid
:: Requires: :ComputeFileHash
:: ============================================================
:VerifyAndroidPackageArchive
for /f "tokens=1 delims==" %%v in ('set vapa_ 2^>nul') do set "%%v="
if defined _vapa_rc (set "_vapa_rc=" & exit /b %_vapa_rc%)
set "vapa_file=%~1"
set "vapa_expected_size=%~2"
set "vapa_checksum_type=%~3"
set "vapa_checksum=%~4"
set "vapa_min_size=%~5"
set "vapa_actual_size="
if not exist "%vapa_file%" set "_vapa_rc=1" & goto :VerifyAndroidPackageArchive
for %%F in ("%vapa_file%") do set "vapa_actual_size=%%~zF"
if not defined vapa_actual_size set "_vapa_rc=1" & goto :VerifyAndroidPackageArchive
if defined vapa_expected_size goto :VerifyAndroidPackageArchiveCheckExactSize
if defined vapa_min_size goto :VerifyAndroidPackageArchiveCheckMinSize
goto :VerifyAndroidPackageArchiveCheckHash
:VerifyAndroidPackageArchiveCheckExactSize
if not "%vapa_actual_size%"=="%vapa_expected_size%" set "_vapa_rc=1" & goto :VerifyAndroidPackageArchive
goto :VerifyAndroidPackageArchiveCheckHash
:VerifyAndroidPackageArchiveCheckMinSize
if %vapa_actual_size% LSS %vapa_min_size% set "_vapa_rc=1" & goto :VerifyAndroidPackageArchive
goto :VerifyAndroidPackageArchiveCheckHash
:VerifyAndroidPackageArchiveCheckHash
if not defined vapa_checksum set "_vapa_rc=0" & goto :VerifyAndroidPackageArchive
call :ComputeFileHash "%vapa_file%" "%vapa_checksum_type%"
if errorlevel 1 set "_vapa_rc=1" & goto :VerifyAndroidPackageArchive
if /I not "%app.file.hash%"=="%vapa_checksum%" set "_vapa_rc=1" & goto :VerifyAndroidPackageArchive
set "_vapa_rc=0" & goto :VerifyAndroidPackageArchive

:: ============================================================
:: :ComputeFileHash
:: Computes a file hash using PowerShell Get-FileHash.
::
:: Usage:
::   call :ComputeFileHash "file" "algorithm"
::
:: Output:
::   app.file.hash
::
:: Returns: 0 on success, 1 on failure
:: ============================================================
:ComputeFileHash
for /f "tokens=1 delims==" %%v in ('set cfh_ 2^>nul') do set "%%v="
if defined _cfh_rc (set "_cfh_rc=" & exit /b %_cfh_rc%)
set "cfh_file=%~1"
set "cfh_algorithm=%~2"
set "app.file.hash="
if not defined cfh_algorithm set "cfh_algorithm=SHA1"
set "cfh_script=$ErrorActionPreference='Stop';$a=$env:cfh_algorithm;if($a -eq 'SHA-1'){$a='SHA1'};(Get-FileHash -Algorithm $a -LiteralPath $env:cfh_file).Hash.ToLowerInvariant()"
for /f "delims=" %%H in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "%cfh_script%" 2^>^> "%app.log%"') do set "app.file.hash=%%H"
if not defined app.file.hash call :Fail FAIL: could not compute hash for %cfh_file%
if not defined app.file.hash set "_cfh_rc=1" & goto :ComputeFileHash
set "_cfh_rc=0" & goto :ComputeFileHash

:: ============================================================
:: :DownloadFile
:: Downloads a file with curl.exe when available, otherwise PowerShell.
::
:: Usage:
::   call :DownloadFile "url" "destination-file"
::
:: Returns: 0 on success, 1 on failure
:: ============================================================
:DownloadFile
for /f "tokens=1 delims==" %%v in ('set df_ 2^>nul') do set "%%v="
if defined _df_rc (set "_df_rc=" & exit /b %_df_rc%)
set "df_url=%~1"
set "df_file=%~2"
set "df_part=%~2.part"
if not defined df_url call :Fail FAIL: missing download URL.
if not defined df_url set "_df_rc=1" & goto :DownloadFile
if not defined df_file call :Fail FAIL: missing download destination.
if not defined df_file set "_df_rc=1" & goto :DownloadFile
if exist "%df_part%" del /Q "%df_part%" >nul 2>&1
call :Info DOWNLOAD: %~nx2
where curl.exe >nul 2>nul
if errorlevel 1 goto :DownloadFile_powershell
curl.exe --silent --show-error --location --fail --retry 3 --output "%df_part%" "%df_url%" >> "%app.log%" 2>&1
set "df_rc=%errorlevel%"
if not "%df_rc%"=="0" call :Fail FAIL: download failed: %df_url%
if not "%df_rc%"=="0" set "_df_rc=%df_rc%" & goto :DownloadFile
goto :DownloadFile_finish
:DownloadFile_powershell
set "df_script=$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Invoke-WebRequest -Uri $env:df_url -OutFile $env:df_part -UseBasicParsing"
powershell -NoProfile -ExecutionPolicy Bypass -Command "%df_script%" >> "%app.log%" 2>&1
set "df_rc=%errorlevel%"
if not "%df_rc%"=="0" call :Fail FAIL: download failed: %df_url%
if not "%df_rc%"=="0" set "_df_rc=%df_rc%" & goto :DownloadFile
:DownloadFile_finish
move /Y "%df_part%" "%df_file%" >> "%app.log%" 2>&1
set "df_rc=%errorlevel%"
if not "%df_rc%"=="0" call :Fail FAIL: could not move downloaded file into place.
if not "%df_rc%"=="0" set "_df_rc=%df_rc%" & goto :DownloadFile
call :OK OK: downloaded %~nx2
set "_df_rc=0" & goto :DownloadFile

:: ============================================================
:: :ExpandZipToFolder
:: Extracts a ZIP archive to a folder using .NET ZipFile.
::
:: Usage:
::   call :ExpandZipToFolder "zip" "destination-folder"
::
:: Returns: 0 on success, 1 on failure
:: ============================================================
:ExpandZipToFolder
for /f "tokens=1 delims==" %%v in ('set eztf_ 2^>nul') do set "%%v="
if defined _eztf_rc (set "_eztf_rc=" & exit /b %_eztf_rc%)
set "eztf_zip=%~1"
set "eztf_dest=%~2"
set "eztf_parent="
for %%D in ("%eztf_dest%\..") do set "eztf_parent=%%~fD"
if not exist "%eztf_zip%" call :Fail FAIL: ZIP file not found: %eztf_zip%
if not exist "%eztf_zip%" set "_eztf_rc=1" & goto :ExpandZipToFolder
if not exist "%eztf_parent%\" mkdir "%eztf_parent%" >nul 2>nul
if not exist "%eztf_parent%\" call :Fail FAIL: could not create extract parent: %eztf_parent%
if not exist "%eztf_parent%\" set "_eztf_rc=1" & goto :ExpandZipToFolder
call :Info UNPACK: %~nx1
set "eztf_script=$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';$zip=$env:eztf_zip;$dest=$env:eztf_dest;$parent=Split-Path -Parent $dest;if(-not (Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Force -Path $parent|Out-Null};if(Test-Path -LiteralPath $dest){Remove-Item -LiteralPath $dest -Recurse -Force};New-Item -ItemType Directory -Force -Path $dest|Out-Null;Add-Type -AssemblyName System.IO.Compression.FileSystem;[System.IO.Compression.ZipFile]::ExtractToDirectory($zip,$dest)"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create($env:eztf_script))" >> "%app.log%" 2>&1
if errorlevel 1 call :Fail FAIL: could not unpack %eztf_zip%
if errorlevel 1 set "_eztf_rc=1" & goto :ExpandZipToFolder
set "_eztf_rc=0" & goto :ExpandZipToFolder

:: ============================================================
:: :InstallExtractedAndroidPackage
:: Copies an extracted SDK package into its final SDK destination.
::
:: Usage:
::   call :InstallExtractedAndroidPackage "extract-root" "sdk-root" "destination-subfolder" "marker-file" "source-mode"
::
:: Source modes:
::   MarkerDirectory
::   ParentOfMarkerDirectory
::
:: Returns: 0 on success, 1 on failure
:: ============================================================
:InstallExtractedAndroidPackage
for /f "tokens=1 delims==" %%v in ('set ieap_ 2^>nul') do set "%%v="
if defined _ieap_rc (set "_ieap_rc=" & exit /b %_ieap_rc%)
set "ieap_extract=%~1"
set "ieap_sdk=%~2"
set "ieap_destsub=%~3"
set "ieap_marker=%~4"
set "ieap_mode=%~5"
set "ieap_script=$ErrorActionPreference='Stop';$extract=$env:ieap_extract;$sdk=$env:ieap_sdk;$destSub=$env:ieap_destsub;$markerName=$env:ieap_marker;$mode=$env:ieap_mode;if(-not (Test-Path -LiteralPath $extract)){throw ('extract folder not found: '+$extract)};if(-not (Test-Path -LiteralPath $sdk)){New-Item -ItemType Directory -Force -Path $sdk|Out-Null};$marker=Get-ChildItem -LiteralPath $extract -Recurse -File -Filter $markerName|Select-Object -First 1;if($null -eq $marker){throw ('marker file not found: '+$markerName)};if($mode -eq 'ParentOfMarkerDirectory'){$source=Split-Path -Parent $marker.Directory.FullName}else{$source=$marker.Directory.FullName};if(-not (Test-Path -LiteralPath $source)){throw ('source folder not found: '+$source)};$final=Join-Path $sdk $destSub;$parent=Split-Path -Parent $final;if(-not (Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Force -Path $parent|Out-Null};if(Test-Path -LiteralPath $final){Remove-Item -LiteralPath $final -Recurse -Force};New-Item -ItemType Directory -Force -Path $final|Out-Null;Get-ChildItem -LiteralPath $source -Force|ForEach-Object{Copy-Item -LiteralPath $_.FullName -Destination $final -Recurse -Force};exit 0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create($env:ieap_script))" 1>nul 2>>"%app.log%"
if errorlevel 1 call :Fail FAIL: could not install extracted Android SDK package.
if errorlevel 1 set "_ieap_rc=1" & goto :InstallExtractedAndroidPackage
set "_ieap_rc=0" & goto :InstallExtractedAndroidPackage

:: ============================================================
:: :SaveAndroidPackagePlan
:: Appends one resolved package record to the package plan file.
::
:: Usage:
::   call :SaveAndroidPackagePlan "sdk-destination"
::
:: Record format:
::   path|revision|url|archive|checksum-type|checksum|size|sdk-subfolder|sdk-root
::
:: Returns: 0 on success, 1 on failure
:: ============================================================
:SaveAndroidPackagePlan
for /f "tokens=1 delims==" %%v in ('set sapp_ 2^>nul') do set "%%v="
if defined _sapp_rc (set "_sapp_rc=" & exit /b %_sapp_rc%)
set "sapp_destination=%~1"
set "sapp_script=$ErrorActionPreference='Stop';$file=[Environment]::GetEnvironmentVariable('app.plan.file');if([string]::IsNullOrWhiteSpace($file)){throw 'app.plan.file is not defined'};$parent=Split-Path -Parent $file;if(-not (Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Force -Path $parent|Out-Null};$path=[Environment]::GetEnvironmentVariable('app.package.path');$revision=[Environment]::GetEnvironmentVariable('app.package.revision');$url=[Environment]::GetEnvironmentVariable('app.package.url');$archive=[Environment]::GetEnvironmentVariable('app.package.file');$checksumType=[Environment]::GetEnvironmentVariable('app.package.checksum.type');$checksum=[Environment]::GetEnvironmentVariable('app.package.checksum');$size=[Environment]::GetEnvironmentVariable('app.package.size');$subfolder=[Environment]::GetEnvironmentVariable('app.package.destination');$sdkRoot=[Environment]::GetEnvironmentVariable('sapp_destination');$line=($path+'|'+$revision+'|'+$url+'|'+$archive+'|'+$checksumType+'|'+$checksum+'|'+$size+'|'+$subfolder+'|'+$sdkRoot);Add-Content -LiteralPath $file -Value $line -Encoding ASCII"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create($env:sapp_script))" 1>nul 2>>"%app.log%"
if errorlevel 1 call :Fail FAIL: could not save Android SDK package plan.
if errorlevel 1 set "_sapp_rc=1" & goto :SaveAndroidPackagePlan
set "_sapp_rc=0" & goto :SaveAndroidPackagePlan

:: ============================================================
:: :VerifyAndroidSDK
:: Verifies the default Android SDK files after installation.
::
:: Usage:
::   call :VerifyAndroidSDK
::
:: Returns: 0 on success, 1 on missing file
:: ============================================================
:VerifyAndroidSDK
for /f "tokens=1 delims==" %%v in ('set vas_ 2^>nul') do set "%%v="
if defined _vas_rc (set "_vas_rc=" & exit /b %_vas_rc%)
call :RequireFile "%app.dest%\platform-tools\adb.exe"
if errorlevel 1 set "_vas_rc=1" & goto :VerifyAndroidSDK
call :RequireFile "%app.dest%\platforms\android-%app.platform.api.version%\android.jar"
if errorlevel 1 set "_vas_rc=1" & goto :VerifyAndroidSDK
call :RequireFile "%app.dest%\build-tools\%app.build.tools.version%\aapt.exe"
if errorlevel 1 set "_vas_rc=1" & goto :VerifyAndroidSDK
call :RequireFile "%app.dest%\build-tools\%app.build.tools.version%\zipalign.exe"
if errorlevel 1 set "_vas_rc=1" & goto :VerifyAndroidSDK
call :RequireFile "%app.dest%\build-tools\%app.build.tools.version%\apksigner.bat"
if errorlevel 1 set "_vas_rc=1" & goto :VerifyAndroidSDK
if exist "%app.dest%\build-tools\%app.build.tools.version%\d8.bat" goto :VerifyAndroidSDK_check_cmdline
if exist "%app.dest%\build-tools\%app.build.tools.version%\dx.bat" goto :VerifyAndroidSDK_check_cmdline
call :Fail FAIL: missing required dexer: d8.bat or dx.bat
set "_vas_rc=1" & goto :VerifyAndroidSDK
:VerifyAndroidSDK_check_cmdline
call :RequireFile "%app.dest%\cmdline-tools\%app.cmdline.tools.version%\bin\sdkmanager.bat"
if errorlevel 1 set "_vas_rc=1" & goto :VerifyAndroidSDK
call :RequireFile "%app.dest%\cmdline-tools\%app.cmdline.tools.version%\source.properties"
if errorlevel 1 set "_vas_rc=1" & goto :VerifyAndroidSDK
dir /S /B "%app.dest%" > "%app.file.list%" 2>nul
call :OK OK: Android SDK files verified.
call :OK FILES: %app.file.list%
set "_vas_rc=0" & goto :VerifyAndroidSDK

:: ============================================================
:: :RequireFile
:: Requires one file to exist.
::
:: Usage:
::   call :RequireFile "path"
::
:: Returns: 0 if present, 1 if missing
:: ============================================================
:RequireFile
for /f "tokens=1 delims==" %%v in ('set rf_ 2^>nul') do set "%%v="
if defined _rf_rc (set "_rf_rc=" & exit /b %_rf_rc%)
if exist "%~1" set "_rf_rc=0" & goto :RequireFile
call :Fail FAIL: missing required file: %~1
set "_rf_rc=1" & goto :RequireFile

:: ============================================================
:: :CleanAndroidSDKWork
:: Removes temporary extraction folders.
::
:: Usage:
::   call :CleanAndroidSDKWork
::
:: Returns: 0
:: ============================================================
:CleanAndroidSDKWork
for /f "tokens=1 delims==" %%v in ('set casw_ 2^>nul') do set "%%v="
if defined _casw_rc (set "_casw_rc=" & exit /b %_casw_rc%)
if exist "%app.work%\" rmdir /S /Q "%app.work%" >nul 2>&1
set "_casw_rc=0" & goto :CleanAndroidSDKWork

:: ============================================================
:: :InitializeConsoleColors
:: Initializes ANSI escape and app.color.* constants.
::
:: Usage:
::   call :InitializeConsoleColors
::
:: Returns: 0
:: ============================================================
:InitializeConsoleColors
for /f "tokens=1 delims==" %%v in ('set icc_ 2^>nul') do set "%%v="
if defined _icc_rc (set "_icc_rc=" & exit /b %_icc_rc%)
call :SetESC app.esc
if errorlevel 1 set "app.esc="
call :SetAppColors
set "_icc_rc=0" & goto :InitializeConsoleColors

:: ============================================================
:: :Info
:: Prints an informational message.
::
:: Usage:
::   call :Info message
::
:: Returns: 0
:: ============================================================
:Info
if defined app.esc echo %app.esc%[%app.color.cyan%%*%app.esc%[%app.color.reset%
if not defined app.esc echo %*
if defined app.log >> "%app.log%" echo %*
exit /b 0

:: ============================================================
:: :OK
:: Prints a success message.
::
:: Usage:
::   call :OK message
::
:: Returns: 0
:: ============================================================
:OK
if defined app.esc echo %app.esc%[%app.color.green%%*%app.esc%[%app.color.reset%
if not defined app.esc echo %*
if defined app.log >> "%app.log%" echo %*
exit /b 0

:: ============================================================
:: :Warn
:: Prints a warning message.
::
:: Usage:
::   call :Warn message
::
:: Returns: 0
:: ============================================================
:Warn
if defined app.esc echo %app.esc%[%app.color.yellow%WARN: %*%app.esc%[%app.color.reset%
if not defined app.esc echo WARN: %*
if defined app.log >> "%app.log%" echo WARN: %*
exit /b 0

:: ============================================================
:: :Fail
:: Prints a failure message.
::
:: Usage:
::   call :Fail message
::
:: Returns: 1
:: ============================================================
:Fail
if defined app.esc echo %app.esc%[%app.color.red%%*%app.esc%[%app.color.reset%
if not defined app.esc echo %*
if defined app.log >> "%app.log%" echo %*
exit /b 1

:: ============================================================
:: :SetESC
:: Sets an output variable to the ANSI escape character.
::
:: Usage:
::   call :SetESC output.variable
::
:: Returns: 0 on success
::          2 missing output variable
:: ============================================================
:SetESC
for /f "tokens=1 delims==" %%v in ('set se_ 2^>nul') do set "%%v="
if defined _se_rc (set "_se_rc=" & exit /b %_se_rc%)
set "se_out=%~1"
if not defined se_out set "_se_rc=2" & goto :SetESC
for /f %%a in ('echo prompt $E^| cmd') do set "%se_out%=%%a"
set "_se_rc=0" & goto :SetESC

:: ============================================================
:: :SetAppColors
:: Creates ANSI SGR color/style constants under app.color.*.
::
:: Usage:
::   call :SetAppColors
::
:: Returns: 0
:: ============================================================
:SetAppColors
for /f "tokens=1 delims==" %%v in ('set sac_ 2^>nul') do set "%%v="
if defined _sac_rc (set "_sac_rc=" & exit /b %_sac_rc%)
set "app.color.reset=0m"
set "app.color.normal=0m"
set "app.color.bold=1m"
set "app.color.red=31m"
set "app.color.green=32m"
set "app.color.yellow=33m"
set "app.color.blue=34m"
set "app.color.magenta=35m"
set "app.color.cyan=36m"
set "app.color.white=37m"
set "app.color.gray=90m"
set "app.color.brightred=91m"
set "app.color.brightgreen=92m"
set "app.color.brightyellow=93m"
set "app.color.brightcyan=96m"
set "_sac_rc=0" & goto :SetAppColors