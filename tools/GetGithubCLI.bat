@echo off
:setup
:: ============================================================
:: GetGithubCLI.bat
:: Downloads and installs GitHub CLI, gh.exe, locally.
::
:: Style:
::   - no setlocal
::   - no delayed expansion
::   - documented functions
::   - one empty line between functions
::
:: Default when placed in tools\:
::   tools\gh\bin\gh.exe
::   tools\downloads\gh\
::   tools\logs\
:: ============================================================
cd /d "%~dp0"
for %%A in ("%CD%") do set "app.root=%%~fA"
set "app.rc=0"
set "app.force="
set "app.help="
set "app.timestamp="
set "app.logs=%app.root%\logs"
set "app.log="
set "app.downloads=%app.root%\downloads\gh"
set "app.gh.install=%app.root%\gh"
set "app.gh.exe=%app.gh.install%\bin\gh.exe"
set "app.gh.url="
set "app.gh.api=https://api.github.com/repos/cli/cli/releases/latest"
set "app.gh.asset.regex=^gh_.*_windows_amd64\.zip$"
set "app.gh.file=%app.downloads%\gh-windows-amd64.zip"
set "app.gh.extract=%app.downloads%\extract"
set "app.gh.extracted.root="
set "app.gh.min.bytes=5000000"
set "app.esc="
set "app.color.reset=0m"
set "app.color.red=31m"
set "app.color.green=32m"
set "app.color.yellow=33m"
set "app.color.cyan=36m"
:main
call :InitConsole
call :ParseArgs %* || (set "app.rc=%errorlevel%" & goto :end)
if defined app.help (call :ShowHelp & set "app.rc=0" & goto :end)
call :CheckReady >nul 2>nul
if not defined app.force if not errorlevel 1 (call :Green OK: GitHub CLI already ready: %app.gh.exe% & set "app.rc=0" & goto :end)
call :InitLog || (set "app.rc=1" & goto :end)
call :EnsureFolders || (set "app.rc=1" & goto :end)
if defined app.force call :Yellow DO: forced refresh.
call :InstallGitCLI || (set "app.rc=%errorlevel%" & goto :end)
call :Green OK: GitHub CLI ready: %app.gh.exe%
set "app.rc=0"
:end
exit /b %app.rc%

:: ============================================================
:: Function: InitConsole
:: Usage: call :InitConsole
:: Purpose: initializes ANSI escape support.
:: Returns:
::   0 always
:: ============================================================
:InitConsole
call :SetESC app.esc
if errorlevel 1 set "app.esc="
if /I "%app.esc%"=="rem" set "app.esc="
exit /b 0

:: ============================================================
:: Function: InitLog
:: Usage: call :InitLog
:: Purpose: creates the dated log file.
:: Returns:
::   0 log ready
::   1 timestamp failed
:: ============================================================
:InitLog
call :MakeTimestamp || exit /b 1
if not exist "%app.logs%\" mkdir "%app.logs%" >nul 2>&1
set "app.log=%app.logs%\GetGithubCLI.%app.timestamp%.log"
break > "%app.log%"
call :Cyan LOG: %app.log%
>>"%app.log%" echo GetGithubCLI log
>>"%app.log%" echo Timestamp: %app.timestamp%
>>"%app.log%" echo Root: %app.root%
>>"%app.log%" echo Install: %app.gh.install%
exit /b 0

:: ============================================================
:: Function: MakeTimestamp
:: Usage: call :MakeTimestamp
:: Purpose: creates app.timestamp in YYYY-MM-DD.HHhmm.ss format.
:: Returns:
::   0 timestamp ready
::   1 timestamp failed
:: ============================================================
:MakeTimestamp
set "app.timestamp="
for /f %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format yyyy-MM-dd.HH\hmm.ss"') do set "app.timestamp=%%A"
if defined app.timestamp exit /b 0
exit /b 1

:: ============================================================
:: Function: ParseArgs
:: Usage: call :ParseArgs %*
:: Purpose: parses command-line arguments.
:: Accepted:
::   force
::   root folder
::   url downloadUrl
::   help, /help, --help, /?
:: Returns:
::   0 success
::   2 invalid argument
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="force" (set "app.force=1" & shift & goto :ParseArgs)
if /I "%~1"=="alwaysdownload" (set "app.force=1" & shift & goto :ParseArgs)
if /I "%~1"=="root" goto :ParseArgsRoot
if /I "%~1"=="url" goto :ParseArgsUrl
if /I "%~1"=="help" (set "app.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="/help" (set "app.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="--help" (set "app.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="/?" (set "app.help=1" & shift & goto :ParseArgs)
call :Red FAIL: unknown argument: %~1
exit /b 2
:ParseArgsRoot
if "%~2"=="" (call :Red FAIL: root requires a folder. & exit /b 2)
for %%A in ("%~2") do set "app.root=%%~fA"
set "app.logs=%app.root%\logs"
set "app.downloads=%app.root%\downloads\gh"
set "app.gh.install=%app.root%\gh"
set "app.gh.exe=%app.gh.install%\bin\gh.exe"
set "app.gh.file=%app.downloads%\gh-windows-amd64.zip"
set "app.gh.extract=%app.downloads%\extract"
shift
shift
goto :ParseArgs
:ParseArgsUrl
if "%~2"=="" (call :Red FAIL: url requires a download URL. & exit /b 2)
set "app.gh.url=%~2"
shift
shift
goto :ParseArgs

:: ============================================================
:: Function: ShowHelp
:: Usage: call :ShowHelp
:: Purpose: prints usage and settings.
:: Returns:
::   0 always
:: ============================================================
:ShowHelp
call :Green GetGithubCLI.bat
echo.
call :Yellow Usage:
echo   GetGithubCLI.bat
echo   GetGithubCLI.bat force
echo   GetGithubCLI.bat root tools
echo   GetGithubCLI.bat url https://example/gh_windows_amd64.zip
echo   GetGithubCLI.bat help
echo.
call :Yellow Behavior:
echo   Installs GitHub CLI ^(gh.exe^) into:
echo     %app.gh.install%
echo   Ready file:
echo     %app.gh.exe%
echo   Logs:
echo     %app.logs%\GetGithubCLI.YYYY-MM-DD.HHhmm.ss.log
echo.
call :Yellow Latest release lookup:
echo   API:   %app.gh.api%
echo   Asset: %app.gh.asset.regex%
exit /b 0

:: ============================================================
:: Function: CheckReady
:: Usage: call :CheckReady
:: Purpose: checks whether GitHub CLI is installed locally.
:: Returns:
::   0 ready
::   1 missing
:: ============================================================
:CheckReady
if exist "%app.gh.exe%" exit /b 0
exit /b 1

:: ============================================================
:: Function: EnsureFolders
:: Usage: call :EnsureFolders
:: Purpose: creates downloads and logs folders.
:: Returns:
::   0 folders ready
::   1 folder creation failed
:: ============================================================
:EnsureFolders
if not exist "%app.root%\" mkdir "%app.root%" >> "%app.log%" 2>&1
if not exist "%app.downloads%\" mkdir "%app.downloads%" >> "%app.log%" 2>&1
if not exist "%app.logs%\" mkdir "%app.logs%" >> "%app.log%" 2>&1
if not exist "%app.downloads%\" (call :Red FAIL: could not create downloads folder: %app.downloads% & call :Yellow LOG: %app.log% & exit /b 1)
exit /b 0

:: ============================================================
:: Function: InstallGitCLI
:: Usage: call :InstallGitCLI
:: Purpose: resolves, downloads, extracts, and installs gh.exe.
:: Returns:
::   0 installed
::   1 failed
:: ============================================================
:InstallGitCLI
call :ResolveUrl || exit /b 1
call :Download "%app.gh.url%" "%app.gh.file%" "GitHub CLI" %app.gh.min.bytes% || exit /b 1
call :RequireFreeSpace 150000000 "GitHub CLI extraction" || exit /b 1
call :Yellow DO: extracting GitHub CLI.
if exist "%app.gh.extract%\" rmdir /S /Q "%app.gh.extract%" >> "%app.log%" 2>&1
mkdir "%app.gh.extract%" >> "%app.log%" 2>&1
call :Unzip "%app.gh.file%" "%app.gh.extract%" || (call :Red FAIL: GitHub CLI unzip failed. & call :Yellow LOG: %app.log% & exit /b 1)
call :FindExtractedRoot || (call :Red FAIL: gh.exe was not found after extraction. & call :Yellow DIR: %app.gh.extract% & call :Yellow LOG: %app.log% & exit /b 1)
call :Yellow DO: installing GitHub CLI.
if exist "%app.gh.install%\" rmdir /S /Q "%app.gh.install%" >> "%app.log%" 2>&1
move /Y "%app.gh.extracted.root%" "%app.gh.install%" >> "%app.log%" 2>&1
call :CheckReady || (call :Red FAIL: GitHub CLI install finished, but gh.exe is missing. & call :Yellow LOG: %app.log% & exit /b 1)
exit /b 0

:: ============================================================
:: Function: ResolveUrl
:: Usage: call :ResolveUrl
:: Purpose: resolves latest GitHub CLI URL unless app.gh.url is set.
:: Returns:
::   0 URL ready
::   1 resolution failed
:: ============================================================
:ResolveUrl
if defined app.gh.url exit /b 0
call :Yellow DO: resolving latest GitHub CLI URL.
for /f "delims=" %%U in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; $h=@{'User-Agent'='FoodSnap-GetGithubCLI'}; $r=Invoke-RestMethod -Headers $h -Uri '%app.gh.api%'; $a=$r.assets | Where-Object { $_.name -match '%app.gh.asset.regex%' } | Select-Object -First 1; if($null -eq $a){exit 1}; Write-Output $a.browser_download_url" 2^>^> "%app.log%"') do set "app.gh.url=%%U"
if defined app.gh.url exit /b 0
call :Red FAIL: could not resolve latest GitHub CLI URL.
call :Yellow LOG: %app.log%
exit /b 1

:: ============================================================
:: Function: FindExtractedRoot
:: Usage: call :FindExtractedRoot
:: Purpose: finds the extracted folder that contains bin\gh.exe.
:: Output:
::   app.gh.extracted.root
:: Returns:
::   0 found
::   1 missing
:: ============================================================
:FindExtractedRoot
set "app.gh.extracted.root="
if exist "%app.gh.extract%\bin\gh.exe" set "app.gh.extracted.root=%app.gh.extract%"
if defined app.gh.extracted.root exit /b 0
for /D %%D in ("%app.gh.extract%\gh_*") do if exist "%%~fD\bin\gh.exe" set "app.gh.extracted.root=%%~fD"
if defined app.gh.extracted.root exit /b 0
for /D %%D in ("%app.gh.extract%\*") do if exist "%%~fD\bin\gh.exe" set "app.gh.extracted.root=%%~fD"
if defined app.gh.extracted.root exit /b 0
exit /b 1

:: ============================================================
:: Function: Unzip
:: Usage: call :Unzip "zipFile" "destinationFolder"
:: Purpose: extracts a zip with 7z, then tar, then PowerShell.
:: Returns:
::   0 extracted
::   1 failed
:: ============================================================
:Unzip
set "uz.file=%~1"
set "uz.dest=%~2"
set "uz.rc=1"
where 7z.exe >nul 2>nul
if not errorlevel 1 7z.exe x -y "-o%uz.dest%" "%uz.file%" >> "%app.log%" 2>&1
if not errorlevel 1 set "uz.rc=0"
if "%uz.rc%"=="0" goto :UnzipDone
where tar.exe >nul 2>nul
if not errorlevel 1 tar.exe -xf "%uz.file%" -C "%uz.dest%" >> "%app.log%" 2>&1
if not errorlevel 1 set "uz.rc=0"
if "%uz.rc%"=="0" goto :UnzipDone
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%uz.file%' -DestinationPath '%uz.dest%' -Force" >> "%app.log%" 2>&1
set "uz.rc=%errorlevel%"
:UnzipDone
set "uz.file="
set "uz.dest="
exit /b %uz.rc%

:: ============================================================
:: Function: Download
:: Usage: call :Download "url" "file" "name" minBytes
:: Purpose: downloads a file with curl or PowerShell.
:: Returns:
::   0 ready
::   1 failed
:: ============================================================
:Download
set "dwn.url=%~1"
set "dwn.file=%~2"
set "dwn.name=%~3"
set "dwn.min=%~4"
if not defined dwn.min set "dwn.min=1024"
if exist "%dwn.file%" call :ValidateFile "%dwn.file%" %dwn.min%
if exist "%dwn.file%" if not errorlevel 1 goto :DownloadDone
if exist "%dwn.file%" del /Q "%dwn.file%" >nul 2>&1
call :Yellow GET: %dwn.name%.
where curl.exe >nul 2>nul
if not errorlevel 1 curl.exe -L --fail --retry 3 --output "%dwn.file%" "%dwn.url%" >> "%app.log%" 2>&1
if not exist "%dwn.file%" powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%dwn.url%' -OutFile '%dwn.file%'" >> "%app.log%" 2>&1
call :ValidateFile "%dwn.file%" %dwn.min%
if errorlevel 1 (call :Red FAIL: download failed or file too small: %dwn.name% & call :Yellow LOG: %app.log% & call :DownloadClear & exit /b 1)
:DownloadDone
call :DownloadClear
exit /b 0

:: ============================================================
:: Function: ValidateFile
:: Usage: call :ValidateFile "file" minBytes
:: Purpose: checks that a file exists and has sufficient size.
:: Returns:
::   0 valid
::   1 invalid
:: ============================================================
:ValidateFile
set "vf.bad="
if not exist "%~1" exit /b 1
for %%Z in ("%~1") do if %%~zZ LSS %~2 set "vf.bad=1"
if defined vf.bad (set "vf.bad=" & exit /b 1)
exit /b 0

:: ============================================================
:: Function: DownloadClear
:: Usage: call :DownloadClear
:: Purpose: clears download-local variables.
:: Returns:
::   0 always
:: ============================================================
:DownloadClear
set "dwn.url="
set "dwn.file="
set "dwn.name="
set "dwn.min="
exit /b 0

:: ============================================================
:: Function: RequireFreeSpace
:: Usage: call :RequireFreeSpace bytes "purpose"
:: Purpose: checks free disk space on the install drive.
:: Returns:
::   0 enough free space
::   1 not enough free space
:: ============================================================
:RequireFreeSpace
for /f "tokens=1,2,3" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=(Get-PSDrive -Name '%app.root:~0,1%').Free; $n=[int64]'%~1'; $need=[math]::Ceiling($n/1MB); $free=[math]::Floor($f/1MB); if($f -lt $n){Write-Output ($need.ToString()+' '+$free.ToString()+' 1')}else{Write-Output ($need.ToString()+' '+$free.ToString()+' 0')}" 2^>^> "%app.log%"') do set "rfs.need=%%A" & set "rfs.free=%%B" & set "rfs.rc=%%C"
if "%rfs.rc%"=="0" (set "rfs.need=" & set "rfs.free=" & set "rfs.rc=" & exit /b 0)
call :Red FAIL: not enough free disk space for %~2.
call :Yellow NEED: %rfs.need% MB
call :Yellow FREE: %rfs.free% MB
call :Yellow LOG: %app.log%
set "rfs.need="
set "rfs.free="
set "rfs.rc="
exit /b 1

:: ============================================================
:: Function: SetESC
:: Usage: call :SetESC outputVariable
:: Purpose: captures ANSI escape character into a variable.
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
:: Function: Green
:: Usage: call :Green message
:: Purpose: prints/logs a green status line.
:: Returns:
::   0 always
:: ============================================================
:Green
if defined app.esc (echo %app.esc%[%app.color.green%%*%app.esc%[%app.color.reset%) else (echo %*)
if defined app.log >>"%app.log%" echo %*
exit /b 0

:: ============================================================
:: Function: Yellow
:: Usage: call :Yellow message
:: Purpose: prints/logs a yellow status line.
:: Returns:
::   0 always
:: ============================================================
:Yellow
if defined app.esc (echo %app.esc%[%app.color.yellow%%*%app.esc%[%app.color.reset%) else (echo %*)
if defined app.log >>"%app.log%" echo %*
exit /b 0

:: ============================================================
:: Function: Red
:: Usage: call :Red message
:: Purpose: prints/logs a red status line.
:: Returns:
::   0 always
:: ============================================================
:Red
if defined app.esc (echo %app.esc%[%app.color.red%%*%app.esc%[%app.color.reset%) else (echo %*)
if defined app.log >>"%app.log%" echo %*
exit /b 0

:: ============================================================
:: Function: Cyan
:: Usage: call :Cyan message
:: Purpose: prints/logs a cyan status line.
:: Returns:
::   0 always
:: ============================================================
:Cyan
if defined app.esc (echo %app.esc%[%app.color.cyan%%*%app.esc%[%app.color.reset%) else (echo %*)
if defined app.log >>"%app.log%" echo %*
exit /b 0
