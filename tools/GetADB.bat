@echo off
:setup
:: ============================================================
:: GetADB.bat
:: Downloads and installs Android platform-tools / adb locally.
::
:: Batch style:
::   - no delayed expansion
::   - no setlocal
::   - one empty line between documented functions
::   - no empty lines inside functions
::   - :setup, :main, and :end are structural labels
::
:: Default install location:
::   If this file is in tools\: tools\adb\platform-tools\adb.exe
::   Otherwise:              tools\adb\platform-tools\adb.exe under the current folder
::
:: User-modifiable settings:
::   gad.platformtools.version=current
::   gad.platformtools.revision=
::     current downloads Google's latest platform-tools package.
::     revision downloads platform-tools_rREVISION-windows.zip.
:: ============================================================
cd /d "%~dp0"
for %%A in ("%CD%") do set "gad.script.folder=%%~fA"
for %%A in ("%CD%") do set "gad.script.folder.name=%%~nxA"
set "gad.platformtools.version=current"
set "gad.platformtools.revision="
set "gad.min.bytes=1000000"
set "gad.keep.download=0"
set "gad.force="
set "gad.help="
set "gad.rc=0"
set "gad.timestamp="
set "gad.install.root="
set "gad.downloads="
set "gad.logs="
set "gad.log="
set "gad.zip="
set "gad.url="
set "gad.extract="
set "gad.adb.exe="
set "gad.last.rc=0"
set "app.esc="
:main
call :InitializeConsoleColors
call :ParseArgs %*
set "gad.rc=%errorlevel%"
if "%gad.rc%"=="0" call :ResolveGetADBPaths
if "%gad.rc%"=="0" set "gad.rc=%errorlevel%"
if "%gad.rc%"=="0" if defined gad.help call :ShowHelp
if "%gad.rc%"=="0" if defined gad.help set "gad.rc=%errorlevel%"
if "%gad.rc%"=="0" if not defined gad.help call :InstallADB
if "%gad.rc%"=="0" if not defined gad.help set "gad.rc=%errorlevel%"
:end
exit /b %gad.rc%

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
:: Function: ParseArgs
:: Usage: call :ParseArgs %*
:: Purpose: parses command-line arguments.
:: Accepted:
::   help
::   force
::   root folder
::   target folder
::   into folder
::   version current
::   revision REVISION
:: Returns:
::   0 success
::   2 unrecognized or incomplete argument
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="help" ( set "gad.help=1" & shift & goto :ParseArgs )
if /I "%~1"=="/help" ( set "gad.help=1" & shift & goto :ParseArgs )
if /I "%~1"=="--help" ( set "gad.help=1" & shift & goto :ParseArgs )
if /I "%~1"=="/?" ( set "gad.help=1" & shift & goto :ParseArgs )
if /I "%~1"=="force" ( set "gad.force=1" & shift & goto :ParseArgs )
if /I "%~1"=="/force" ( set "gad.force=1" & shift & goto :ParseArgs )
if /I "%~1"=="--force" ( set "gad.force=1" & shift & goto :ParseArgs )
if /I "%~1"=="alwaysdownload" ( set "gad.force=1" & shift & goto :ParseArgs )
if /I "%~1"=="root" goto :ParseArgsInstallRoot
if /I "%~1"=="target" goto :ParseArgsInstallRoot
if /I "%~1"=="into" goto :ParseArgsInstallRoot
if /I "%~1"=="installroot" goto :ParseArgsInstallRoot
if /I "%~1"=="version" goto :ParseArgsVersion
if /I "%~1"=="revision" goto :ParseArgsRevision
if not defined gad.install.root ( set "gad.install.root=%~1" & shift & goto :ParseArgs )
call :Red FAIL: unrecognized argument: %~1
exit /b 2
:ParseArgsInstallRoot
if "%~2"=="" ( call :Red FAIL: %~1 requires a folder. & exit /b 2 )
set "gad.install.root=%~2"
shift
shift
goto :ParseArgs
:ParseArgsVersion
if "%~2"=="" ( call :Red FAIL: version requires a value. & exit /b 2 )
set "gad.platformtools.version=%~2"
shift
shift
goto :ParseArgs
:ParseArgsRevision
if "%~2"=="" ( call :Red FAIL: revision requires a value. & exit /b 2 )
set "gad.platformtools.revision=%~2"
shift
shift
goto :ParseArgs

:: ============================================================
:: Function: ResolveGetADBPaths
:: Usage: call :ResolveGetADBPaths
:: Purpose: resolves install, download, URL, and log paths.
:: Returns:
::   0 paths resolved
::   2 invalid version setting
:: ============================================================
:ResolveGetADBPaths
if not defined gad.install.root if /I "%gad.script.folder.name%"=="tools" ( set "gad.install.root=%gad.script.folder%\adb" ) else ( set "gad.install.root=%gad.script.folder%\tools\adb" )
for %%A in ("%gad.install.root%") do set "gad.install.root=%%~fA"
if /I "%gad.script.folder.name%"=="tools" ( set "gad.downloads=%gad.script.folder%\downloads\adb" ) else ( set "gad.downloads=%gad.script.folder%\tools\downloads\adb" )
if /I "%gad.script.folder.name%"=="tools" ( set "gad.logs=%gad.script.folder%\logs" ) else ( set "gad.logs=%gad.script.folder%\tools\logs" )
set "gad.adb.exe=%gad.install.root%\platform-tools\adb.exe"
set "gad.zip=%gad.downloads%\platform-tools-windows.zip"
set "gad.extract=%gad.downloads%\extract"
if defined gad.platformtools.revision set "gad.url=https://dl.google.com/android/repository/platform-tools_r%gad.platformtools.revision%-windows.zip"
if not defined gad.platformtools.revision if /I "%gad.platformtools.version%"=="current" set "gad.url=https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
if defined gad.url exit /b 0
call :Red FAIL: unsupported platform-tools version: %gad.platformtools.version%
call :Yellow SETTING: use version current or revision REVISION
exit /b 2

:: ============================================================
:: Function: ShowHelp
:: Usage: call :ShowHelp
:: Purpose: prints usage and settings.
:: Returns:
::   0 always
:: ============================================================
:ShowHelp
call :Green GetADB.bat
echo.
call :Yellow Usage:
echo   GetADB.bat
echo   GetADB.bat force
echo   GetADB.bat root tools\adb
echo   GetADB.bat revision 35.0.2
echo   GetADB.bat help
echo.
call :Yellow Arguments:
echo   force              Re-download and reinstall ADB.
echo   alwaysdownload     Alias for force.
echo   root folder        Install root. adb.exe goes under folder\platform-tools\adb.exe.
echo   target folder      Alias for root.
echo   into folder        Alias for root.
echo   version current    Download latest platform-tools package.
echo   revision REVISION  Download platform-tools_rREVISION-windows.zip.
echo   help               Show this help.
echo.
call :Yellow Settings:
echo   gad.platformtools.version=%gad.platformtools.version%
echo   gad.platformtools.revision=%gad.platformtools.revision%
echo   gad.min.bytes=%gad.min.bytes%
echo   gad.keep.download=%gad.keep.download%
echo.
call :Yellow Active paths:
echo   Install root: %gad.install.root%
echo   ADB:          %gad.adb.exe%
echo   Downloads:    %gad.downloads%
echo   Logs:         %gad.logs%
echo   URL:          %gad.url%
exit /b 0

:: ============================================================
:: Function: InstallADB
:: Usage: call :InstallADB
:: Purpose: installs or verifies a local adb.exe.
:: Returns:
::   0 adb ready
::   1 install failed
:: ============================================================
:InstallADB
if exist "%gad.adb.exe%" if not defined gad.force ( call :Green OK: ADB already ready. & exit /b 0 )
call :GetTimestamp gad.timestamp
if not exist "%gad.logs%\" mkdir "%gad.logs%" >nul 2>&1
set "gad.log=%gad.logs%\GetADB.%gad.timestamp%.log"
break > "%gad.log%"
if defined gad.force call :Yellow DO: forced ADB refresh.
if not exist "%gad.downloads%\" mkdir "%gad.downloads%" >> "%gad.log%" 2>&1
if not exist "%gad.install.root%\" mkdir "%gad.install.root%" >> "%gad.log%" 2>&1
call :Download "%gad.url%" "%gad.zip%" "Android platform-tools" %gad.min.bytes%
if errorlevel 1 exit /b 1
call :ExtractADBPackage
if errorlevel 1 exit /b 1
if exist "%gad.adb.exe%" ( call :Green OK: ADB ready. & exit /b 0 )
call :Red FAIL: adb.exe was not found after install.
call :Yellow MISS: %gad.adb.exe%
call :Yellow LOG: %gad.log%
exit /b 1

:: ============================================================
:: Function: ExtractADBPackage
:: Usage: call :ExtractADBPackage
:: Purpose: extracts platform-tools ZIP and installs it under gad.install.root.
:: Returns:
::   0 installed
::   1 extraction or install failed
:: ============================================================
:ExtractADBPackage
call :Yellow DO: extracting Android platform-tools.
if exist "%gad.extract%\" rmdir /S /Q "%gad.extract%" >> "%gad.log%" 2>&1
mkdir "%gad.extract%" >> "%gad.log%" 2>&1
call :Unzip "%gad.zip%" "%gad.extract%"
if errorlevel 1 ( call :Red FAIL: platform-tools unzip failed. & call :Yellow FILE: %gad.zip% & call :Yellow LOG: %gad.log% & exit /b 1 )
if not exist "%gad.extract%\platform-tools\adb.exe" ( call :Red FAIL: adb.exe not found inside platform-tools ZIP. & call :Yellow LOG: %gad.log% & exit /b 1 )
if exist "%gad.install.root%\platform-tools\" rmdir /S /Q "%gad.install.root%\platform-tools" >> "%gad.log%" 2>&1
move /Y "%gad.extract%\platform-tools" "%gad.install.root%\" >> "%gad.log%" 2>&1
if errorlevel 1 ( call :Red FAIL: could not install platform-tools. & call :Yellow TO: %gad.install.root% & call :Yellow LOG: %gad.log% & exit /b 1 )
if exist "%gad.extract%\" rmdir /S /Q "%gad.extract%" >> "%gad.log%" 2>&1
if "%gad.keep.download%"=="0" if exist "%gad.zip%" del /Q "%gad.zip%" >> "%gad.log%" 2>&1
exit /b 0

:: ============================================================
:: Function: Download
:: Usage: call :Download "url" "file" "name" minBytes
:: Purpose: downloads a file with curl first, then PowerShell.
:: Input:
::   %~1 URL
::   %~2 destination file
::   %~3 display name
::   %~4 minimum acceptable byte size
:: Returns:
::   0 file exists and is large enough
::   1 download failed
:: ============================================================
:Download
set "dwn.url=%~1"
set "dwn.file=%~2"
set "dwn.name=%~3"
set "dwn.min=%~4"
if not defined dwn.min set "dwn.min=1024"
call :DownloadValidateExisting
if errorlevel 1 ( call :DownloadClearVars & exit /b 1 )
if exist "%dwn.file%" ( call :DownloadClearVars & exit /b 0 )
call :Yellow GET: %dwn.name%.
call :DownloadWithCurl
set "dwn.rc=%errorlevel%"
if not "%dwn.rc%"=="0" call :DownloadWithPowerShell
if not "%dwn.rc%"=="0" set "dwn.rc=%errorlevel%"
if not "%dwn.rc%"=="0" ( call :Red FAIL: download failed: %dwn.name%. & call :Yellow URL: %dwn.url% & call :Yellow LOG: %gad.log% & call :DownloadClearVars & exit /b 1 )
call :DownloadValidateNew
set "dwn.rc=%errorlevel%"
call :DownloadClearVars
exit /b %dwn.rc%

:: ============================================================
:: Function: DownloadValidateExisting
:: Usage: call :DownloadValidateExisting
:: Purpose: deletes an existing download when it is too small.
:: Input:
::   dwn.file
::   dwn.min
:: Returns:
::   0 OK
::   1 bad existing file could not be deleted
:: ============================================================
:DownloadValidateExisting
set "dve.bad="
if not exist "%dwn.file%" exit /b 0
for %%Z in ("%dwn.file%") do if %%~zZ LSS %dwn.min% set "dve.bad=1"
if not defined dve.bad exit /b 0
del /Q "%dwn.file%" >nul 2>&1
if exist "%dwn.file%" ( call :Red FAIL: existing download is too small and could not be deleted: %dwn.file% & exit /b 1 )
exit /b 0

:: ============================================================
:: Function: DownloadWithCurl
:: Usage: call :DownloadWithCurl
:: Purpose: attempts a download with curl.exe.
:: Returns:
::   0 curl succeeded
::   1 curl missing or failed
:: ============================================================
:DownloadWithCurl
where curl.exe >nul 2>nul
if errorlevel 1 exit /b 1
curl.exe -L --fail --retry 3 --output "%dwn.file%" "%dwn.url%" >> "%gad.log%" 2>&1
exit /b %errorlevel%

:: ============================================================
:: Function: DownloadWithPowerShell
:: Usage: call :DownloadWithPowerShell
:: Purpose: attempts a download with PowerShell Invoke-WebRequest.
:: Returns:
::   0 PowerShell succeeded
::   1 PowerShell failed
:: ============================================================
:DownloadWithPowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%dwn.url%' -OutFile '%dwn.file%'" >> "%gad.log%" 2>&1
exit /b %errorlevel%

:: ============================================================
:: Function: DownloadValidateNew
:: Usage: call :DownloadValidateNew
:: Purpose: validates a newly downloaded file.
:: Returns:
::   0 file OK
::   1 file missing or too small
:: ============================================================
:DownloadValidateNew
set "dvn.bad="
if not exist "%dwn.file%" ( call :Red FAIL: download did not create file: %dwn.file% & call :Yellow LOG: %gad.log% & exit /b 1 )
for %%Z in ("%dwn.file%") do if %%~zZ LSS %dwn.min% set "dvn.bad=1"
if not defined dvn.bad exit /b 0
call :Red FAIL: downloaded file is too small: %dwn.file%
call :Yellow NEED: at least %dwn.min% bytes
call :Yellow LOG: %gad.log%
del /Q "%dwn.file%" >nul 2>&1
exit /b 1

:: ============================================================
:: Function: DownloadClearVars
:: Usage: call :DownloadClearVars
:: Purpose: clears download helper variables.
:: Returns:
::   0 always
:: ============================================================
:DownloadClearVars
set "dwn.url="
set "dwn.file="
set "dwn.name="
set "dwn.min="
set "dwn.rc="
set "dve.bad="
set "dvn.bad="
exit /b 0

:: ============================================================
:: Function: Unzip
:: Usage: call :Unzip "zipFile" "destinationFolder"
:: Purpose: extracts an archive using 7z, then tar, then PowerShell.
:: Returns:
::   0 extracted
::   1 failed
:: ============================================================
:Unzip
set "uz.file=%~1"
set "uz.dest=%~2"
set "uz.rc=1"
where 7z.exe >nul 2>nul
if not errorlevel 1 7z.exe x -y "-o%uz.dest%" "%uz.file%" >> "%gad.log%" 2>&1
if not errorlevel 1 set "uz.rc=0"
if "%uz.rc%"=="0" ( set "uz.file=" & set "uz.dest=" & set "uz.rc=" & exit /b 0 )
where tar.exe >nul 2>nul
if not errorlevel 1 tar.exe -xf "%uz.file%" -C "%uz.dest%" >> "%gad.log%" 2>&1
if not errorlevel 1 set "uz.rc=0"
if "%uz.rc%"=="0" ( set "uz.file=" & set "uz.dest=" & set "uz.rc=" & exit /b 0 )
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%uz.file%' -DestinationPath '%uz.dest%' -Force" >> "%gad.log%" 2>&1
set "uz.rc=%errorlevel%"
set "uz.file="
set "uz.dest="
exit /b %uz.rc%

:: ============================================================
:: Function: GetTimestamp
:: Usage: call :GetTimestamp outputVariable
:: Purpose: creates a filesystem-safe timestamp.
:: Format:
::   YYYY-MM-DD.HHhmm.ss
:: Returns:
::   0 always
:: ============================================================
:GetTimestamp
for /f %%T in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Date).ToString('yyyy-MM-dd.HH''h''mm.ss')"') do set "%~1=%%T"
exit /b 0

:: ============================================================
:: Function: Green
:: Usage: call :Green message
:: Purpose: prints a green message when ANSI color is available.
:: Returns:
::   0 always
:: ============================================================
:Green
if defined app.esc ( echo %app.esc%[%app.color.green%%*%app.esc%[%app.color.reset% ) else ( echo %* )
exit /b 0

:: ============================================================
:: Function: Yellow
:: Usage: call :Yellow message
:: Purpose: prints a yellow message when ANSI color is available.
:: Returns:
::   0 always
:: ============================================================
:Yellow
if defined app.esc ( echo %app.esc%[%app.color.yellow%%*%app.esc%[%app.color.reset% ) else ( echo %* )
exit /b 0

:: ============================================================
:: Function: Red
:: Usage: call :Red message
:: Purpose: prints a red message when ANSI color is available.
:: Returns:
::   0 always
:: ============================================================
:Red
if defined app.esc ( echo %app.esc%[%app.color.red%%*%app.esc%[%app.color.reset% ) else ( echo %* )
exit /b 0

:: ============================================================
:: Function: SetESC
:: Usage: call :SetESC outputVariable
:: Purpose: captures the ANSI escape character into a variable.
:: Returns:
::   0 success
::   2 missing output variable
:: ============================================================
:SetESC
set "se.out=%~1"
if not defined se.out exit /b 2
for /f %%a in ('echo prompt $E^| cmd') do set "%se.out%=%%a"
set "se.out="
exit /b 0

:: ============================================================
:: Function: SetAppColors
:: Usage: call :SetAppColors
:: Purpose: creates ANSI SGR constants under app.color.*.
:: Returns:
::   0 always
:: ============================================================
:SetAppColors
set "app.color.reset=0m"
set "app.color.red=31m"
set "app.color.green=32m"
set "app.color.yellow=33m"
exit /b 0
