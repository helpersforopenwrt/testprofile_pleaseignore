@echo off

:_ENTRY_FLOW_CONTROL

:: ============================================================
:: :setup
:: Initializes roots, package versions, base URLs, hashes, flags,
:: and starts the TCC bootstrap flow.
::
:: Root is based on the current working directory:
::   %CD%\tcc
::
:: Usage:
::   GetTCC.bat
::   GetTCC.bat alwaysdownload
::   GetTCC.bat nohashcheck
::   GetTCC.bat quiet
::   GetTCC.bat --help
::
:: Returns: exits through :end
:: Requires: :SetESC, :ConfigureTCCPackage, :ConfigureXZPackage, :ParseArgs, :ShowHelp, :CheckTCCReadyQuiet, :CheckExistingTCC, :GetTCC
:: ============================================================
:setup
for %%A in ("%CD%\tcc") do set "app.root=%%~fA"
for %%A in ("%CD%") do set "app.extract.root=%%~fA" & set "app.tcc=%app.root%" & set "app.downloads=%app.root%\downloads" & set "app.xz=%app.root%\xz"
set "app.tcc.version=0.9.27-win64"
set "app.tcc.baseurl=https://github.com/phoenixthrush/Tiny-C-Compiler/releases/download"
set "app.w32api.version=5.0.2"
set "app.xz.version=5.8.3"
set "app.xz.baseurl=https://github.com/tukaani-project/xz/releases/download"
set "app.w32api.sha256=b80b0c9d0158f9125e482b50fe00b70dde11d7a015ee687ca455fe2ea2ec8733"
set "app.xz.sha256=8d0048ee51177b11ef1613959c2a268c951f4e7f6fb3706e681e00e34bb6d5e3"
set "app.rc=0" & set "app.bootstrap.rc=0" & set "app.alwaysdownload=" & set "app.nohashcheck=" & set "app.help=" & set "app.quiet=" & set "app.existing.tcc.kind=" & set "app.current.tcc.exe="
call :SetESC app.esc
call :ConfigureTCCPackage || ( call set "app.rc=%%errorlevel%%" & goto :end )
call :ConfigureXZPackage || ( call set "app.rc=%%errorlevel%%" & goto :end )
for %%A in ("%app.tcc%") do set "app.tcc.abs=%%~fA"
for %%A in ("%app.tcc%\tcc.exe") do set "app.tcc.exe=%%~fA"
for %%A in ("%CD%\tcc.exe") do set "app.tcc.link=%%~fA"
call :ParseArgs %*
if errorlevel 1 ( set "app.rc=%errorlevel%" & goto :end )
if defined app.help ( set "app.quiet=" & call :ShowHelp & set "app.rc=0" & goto :end )
if defined app.alwaysdownload call :EchoYellow WARNING: alwaysdownload flag set. Forcing download and extraction.
if defined app.nohashcheck call :EchoYellow WARNING: nohashcheck flag set. Hash/signature downloads and verification will be skipped.
if not defined app.alwaysdownload ( call :CheckTCCReadyQuiet && ( set "app.rc=0" & goto :end ) )
if not defined app.alwaysdownload ( call :CheckExistingTCC && goto :main )
call :GetTCC
if errorlevel 1 set "app.bootstrap.rc=%errorlevel%"

:: ============================================================
:: :main
:: Finalizes or accepts the selected TCC executable.
::
:: Returns: exits through :end
:: Requires: :AcceptExistingTCC, :FinalizeTCC
:: ============================================================
:main
if defined app.existing.tcc.kind call :AcceptExistingTCC
if defined app.existing.tcc.kind set "app.rc=%errorlevel%" & goto :end
call :FinalizeTCC
set "app.rc=%errorlevel%" & goto :end

:: ============================================================
:: :end
:: Script exit point.
::
:: Returns: app.rc
:: Requires: none
:: ============================================================
:end
exit /b %app.rc%

:: ============================================================
:: :ParseArgs
:: Parses command line flags and rejects unknown arguments.
::
:: Flags:
::   alwaysdownload
::   /alwaysdownload
::   --alwaysdownload
::   nohashcheck
::   /nohashcheck
::   --nohashcheck
::   quiet
::   /quiet
::   --quiet
::   help
::   /help
::   --help
::   -h
::   /?
::   -?
::
:: Output:
::   app.alwaysdownload  set when force-download is requested
::   app.nohashcheck     set when hash/signature verification is skipped
::   app.quiet           set when good/warning output should be suppressed
::   app.help            set when help was requested
::
:: Returns: 0 on success
::          2 unrecognized argument
:: Requires: :EchoRed, :ShowHelp
:: ============================================================
:ParseArgs
for /f "tokens=1 delims==" %%v in ('set parg_ 2^>nul') do set "%%v="
if defined _parg_rc (set "_parg_rc=" & exit /b %_parg_rc%)
if "%~1"=="" ( set "_parg_rc=0" & goto :ParseArgs )
set "parg_seen="
if /i "%~1"=="alwaysdownload" set "app.alwaysdownload=1" & set "parg_seen=1"
if /i "%~1"=="/alwaysdownload" set "app.alwaysdownload=1" & set "parg_seen=1"
if /i "%~1"=="--alwaysdownload" set "app.alwaysdownload=1" & set "parg_seen=1"
if /i "%~1"=="nohashcheck" set "app.nohashcheck=1" & set "parg_seen=1"
if /i "%~1"=="/nohashcheck" set "app.nohashcheck=1" & set "parg_seen=1"
if /i "%~1"=="--nohashcheck" set "app.nohashcheck=1" & set "parg_seen=1"
if /i "%~1"=="quiet" set "app.quiet=1" & set "parg_seen=1"
if /i "%~1"=="/quiet" set "app.quiet=1" & set "parg_seen=1"
if /i "%~1"=="--quiet" set "app.quiet=1" & set "parg_seen=1"
if /i "%~1"=="help" set "app.help=1" & set "parg_seen=1"
if /i "%~1"=="/help" set "app.help=1" & set "parg_seen=1"
if /i "%~1"=="--help" set "app.help=1" & set "parg_seen=1"
if /i "%~1"=="-h" set "app.help=1" & set "parg_seen=1"
if /i "%~1"=="/?" set "app.help=1" & set "parg_seen=1"
if /i "%~1"=="-?" set "app.help=1" & set "parg_seen=1"
if not defined parg_seen ( set "app.quiet=" & call :EchoRed FAIL: unrecognized argument: %~1 & call :ShowHelp & set "_parg_rc=2" & goto :ParseArgs )
shift
goto :ParseArgs

:: ============================================================
:: :ShowHelp
:: Prints command line usage.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: :EchoGreen, :EchoYellow
:: ============================================================
:ShowHelp
for /f "tokens=1 delims==" %%v in ('set shlp_ 2^>nul') do set "%%v="
if defined _shlp_rc (set "_shlp_rc=" & exit /b %_shlp_rc%)
call :EchoGreen GetTCC.bat
call :EchoGreen Usage:
call :EchoGreen   GetTCC.bat [flags]
call :EchoGreen Flags:
call :EchoGreen   alwaysdownload     Force download and extraction even when cached files or tcc.exe exist.
call :EchoGreen   nohashcheck        Skip hash/signature downloads and verification.
call :EchoGreen   quiet              Suppress GOOD/WARNING output; FAIL output still prints.
call :EchoGreen   --help             Show this help and exit.
call :EchoYellow Root:
call :EchoYellow   TCC root is based on the current working directory:
call :EchoYellow   %app.root%
set "_shlp_rc=0" & goto :ShowHelp

:_...ENTRY_FLOW_CONTROL

:_TCC_BOOTSTRAP_ACTIVATION

:: ============================================================
:: :CheckTCCReadyQuiet
:: Fast-path check for the already-good state.
::
:: Already-good means:
::   local tcc\tcc.exe exists
::   current-folder tcc.exe exists
::   current tcc.exe resolves to current-folder tcc.exe or local tcc\tcc.exe
::
:: Output:
::   app.current.tcc.exe  resolved current executable path
::
:: Returns: 0 if already ready
::          1 if work still needs to be done
:: Requires: :GetCurrentTCC, :EchoGreen
:: ============================================================
:CheckTCCReadyQuiet
for /f "tokens=1 delims==" %%v in ('set ctccrq_ 2^>nul') do set "%%v="
if defined _ctccrq_rc (set "_ctccrq_rc=" & exit /b %_ctccrq_rc%)
if not exist "%app.tcc.exe%" ( set "_ctccrq_rc=1" & goto :CheckTCCReadyQuiet )
if not exist "%app.tcc.link%" ( set "_ctccrq_rc=1" & goto :CheckTCCReadyQuiet )
call :GetCurrentTCC
if errorlevel 1 ( set "_ctccrq_rc=1" & goto :CheckTCCReadyQuiet )
if /i "%app.current.tcc.exe%"=="%app.tcc.link%" goto :_CheckTCCReadyQuiet_yes
if /i "%app.current.tcc.exe%"=="%app.tcc.exe%" goto :_CheckTCCReadyQuiet_yes
set "_ctccrq_rc=1" & goto :CheckTCCReadyQuiet
:_CheckTCCReadyQuiet_yes
call :EchoGreen YES: TCC is already ready: %app.current.tcc.exe%
set "_ctccrq_rc=0" & goto :CheckTCCReadyQuiet

:: ============================================================
:: :ConfigureTCCPackage
:: Derives all TCC and w32api filenames, paths, and URLs from:
::   app.tcc.version
::   app.tcc.baseurl
::   app.w32api.version
::
:: Input:
::   app.tcc.version       release/version, e.g. 0.9.27-win64
::   app.tcc.baseurl       release base URL without version
::   app.w32api.version    w32api source version
::   app.downloads         downloads directory
::   app.tcc               TCC root directory
::
:: Output:
::   app.tcc.bin.name
::   app.tcc.zip.name
::   app.tcc.sha256.name
::   app.tcc.zip
::   app.tcc.sha256
::   app.tcc.zip.url
::   app.tcc.sha256.url
::   app.w32api.name
::   app.w32api.txz.name
::   app.w32api.sig.name
::   app.w32api.txz
::   app.w32api.sig
::   app.w32api.txz.url
::   app.w32api.sig.url
::   app.w32api.src
::   app.w32api.tar
::
:: Returns: 0 on success
::          2 missing required setup value
:: Requires: none
:: ============================================================
:ConfigureTCCPackage
for /f "tokens=1 delims==" %%v in ('set ctcc_ 2^>nul') do set "%%v="
if defined _ctcc_rc (set "_ctcc_rc=" & exit /b %_ctcc_rc%)
if not defined app.tcc.version ( call :EchoRed FAIL: app.tcc.version is not defined. & set "_ctcc_rc=2" & goto :ConfigureTCCPackage )
if not defined app.tcc.baseurl ( call :EchoRed FAIL: app.tcc.baseurl is not defined. & set "_ctcc_rc=2" & goto :ConfigureTCCPackage )
if not defined app.w32api.version ( call :EchoRed FAIL: app.w32api.version is not defined. & set "_ctcc_rc=2" & goto :ConfigureTCCPackage )
if not defined app.downloads ( call :EchoRed FAIL: app.downloads is not defined. & set "_ctcc_rc=2" & goto :ConfigureTCCPackage )
if not defined app.tcc ( call :EchoRed FAIL: app.tcc is not defined. & set "_ctcc_rc=2" & goto :ConfigureTCCPackage )
set "app.tcc.bin.name=tcc-%app.tcc.version%-bin"
set "app.tcc.zip.name=%app.tcc.bin.name%.zip"
set "app.tcc.sha256.name=%app.tcc.bin.name%.sha256"
set "app.tcc.zip=%app.downloads%\%app.tcc.zip.name%"
set "app.tcc.sha256=%app.downloads%\%app.tcc.sha256.name%"
set "app.tcc.zip.url=%app.tcc.baseurl%/%app.tcc.version%/%app.tcc.zip.name%"
set "app.tcc.sha256.url=%app.tcc.baseurl%/%app.tcc.version%/%app.tcc.sha256.name%"
set "app.w32api.name=w32api-%app.w32api.version%-mingw32-src"
set "app.w32api.txz.name=%app.w32api.name%.tar.xz"
set "app.w32api.sig.name=%app.w32api.txz.name%.sig"
set "app.w32api.txz=%app.downloads%\%app.w32api.txz.name%"
set "app.w32api.sig=%app.downloads%\%app.w32api.sig.name%"
set "app.w32api.txz.url=%app.tcc.baseurl%/%app.tcc.version%/%app.w32api.txz.name%"
set "app.w32api.sig.url=%app.tcc.baseurl%/%app.tcc.version%/%app.w32api.sig.name%"
set "app.w32api.src=%app.tcc%\w32api-src"
set "app.w32api.tar=%app.w32api.src%\%app.w32api.name%.tar"
set "_ctcc_rc=0" & goto :ConfigureTCCPackage

:: ============================================================
:: :CheckExistingTCC
:: Checks for an existing tcc.exe before downloading.
::
:: Search order:
::   current folder tcc.exe
::   tcc\tcc.exe
::   PATH tcc.exe
::
:: Output:
::   app.existing.tcc.kind  current, local, or path
::   app.current.tcc.exe    resolved executable path
::
:: Returns: 0 if found
::          1 if not found
:: Requires: where
:: ============================================================
:CheckExistingTCC
for /f "tokens=1 delims==" %%v in ('set cxtcc_ 2^>nul') do set "%%v="
if defined _cxtcc_rc (set "_cxtcc_rc=" & exit /b %_cxtcc_rc%)
set "app.existing.tcc.kind="
set "app.current.tcc.exe="
if exist "%CD%\tcc.exe" for %%P in ("%CD%\tcc.exe") do set "app.existing.tcc.kind=current" & set "app.current.tcc.exe=%%~fP"
if defined app.existing.tcc.kind ( call :EchoGreen GOOD: existing current-folder tcc.exe found: %app.current.tcc.exe% & set "_cxtcc_rc=0" & goto :CheckExistingTCC )
if exist "%app.tcc.exe%" set "app.existing.tcc.kind=local" & set "app.current.tcc.exe=%app.tcc.exe%"
if defined app.existing.tcc.kind ( call :EchoGreen GOOD: existing local tcc\tcc.exe found: %app.current.tcc.exe% & set "_cxtcc_rc=0" & goto :CheckExistingTCC )
for /f "delims=" %%P in ('where tcc.exe 2^>nul') do if not defined app.current.tcc.exe set "app.existing.tcc.kind=path" & set "app.current.tcc.exe=%%~fP"
if defined app.existing.tcc.kind ( call :EchoGreen GOOD: existing PATH tcc.exe found: %app.current.tcc.exe% & set "_cxtcc_rc=0" & goto :CheckExistingTCC )
call :EchoYellow WARNING: no existing tcc.exe found. Bootstrapping local TCC.
set "_cxtcc_rc=1" & goto :CheckExistingTCC

:: ============================================================
:: :AcceptExistingTCC
:: Ends successfully when an existing tcc.exe was found and
:: alwaysdownload was not requested.
::
:: Returns: 0 on accepted existing TCC
:: Requires: :FinalizeTCC for local tcc\tcc.exe
:: ============================================================
:AcceptExistingTCC
for /f "tokens=1 delims==" %%v in ('set aetcc_ 2^>nul') do set "%%v="
if defined _aetcc_rc (set "_aetcc_rc=" & exit /b %_aetcc_rc%)
if /i "%app.existing.tcc.kind%"=="local" goto :_AcceptExistingTCC_local
call :EchoGreen YES: tcc.exe already exists. No download needed.
call :EchoGreen GOOD: CURRENT TCC.EXE: %app.current.tcc.exe%
set "_aetcc_rc=0" & goto :AcceptExistingTCC
:_AcceptExistingTCC_local
call :EchoGreen GOOD: existing local TCC will be activated.
call :FinalizeTCC
set "_aetcc_rc=%errorlevel%" & goto :AcceptExistingTCC

:: ============================================================
:: :GetTCC
:: High-level TCC bootstrap.
::
:: Usage: call :GetTCC
::
:: Returns: 0 on success, nonzero on failure
:: Requires: :DownloadTCCFiles, :EnsureXZ, :UnpackTCC
:: ============================================================
:GetTCC
for /f "tokens=1 delims==" %%v in ('set gtcc_ 2^>nul') do set "%%v="
if defined _gtcc_rc (set "_gtcc_rc=" & exit /b %_gtcc_rc%)
call :DownloadTCCFiles
if errorlevel 1 ( set "_gtcc_rc=%errorlevel%" & goto :GetTCC )
call :EnsureXZ
if errorlevel 1 ( set "_gtcc_rc=%errorlevel%" & goto :GetTCC )
call :UnpackTCC
if errorlevel 1 ( set "_gtcc_rc=%errorlevel%" & goto :GetTCC )
set "_gtcc_rc=0" & goto :GetTCC

:: ============================================================
:: :DownloadTCCFiles
:: Ensures TCC compiler zip, SHA256 file, w32api tar.xz, and
:: w32api detached signature exist and verify.
::
:: Usage: call :DownloadTCCFiles
::
:: Returns: 0 on success, nonzero on failure
:: Requires: :DownloadAndCheck
:: ============================================================
:DownloadTCCFiles
for /f "tokens=1 delims==" %%v in ('set dtf_ 2^>nul') do set "%%v="
if defined _dtf_rc (set "_dtf_rc=" & exit /b %_dtf_rc%)
if not exist "%app.downloads%\" mkdir "%app.downloads%" >nul 2>&1
call :DownloadAndCheck "%app.tcc.zip.url%" "%app.tcc.zip%" "%app.tcc.sha256.url%" "%app.tcc.sha256%"
if errorlevel 1 ( set "_dtf_rc=%errorlevel%" & goto :DownloadTCCFiles )
call :DownloadAndCheck "%app.w32api.txz.url%" "%app.w32api.txz%" "%app.w32api.sig.url%" "%app.w32api.sig%" "%app.w32api.sha256%"
if errorlevel 1 ( set "_dtf_rc=%errorlevel%" & goto :DownloadTCCFiles )
set "_dtf_rc=0" & goto :DownloadTCCFiles

:: ============================================================
:: :UnpackTCC
:: Extracts the compiler zip and w32api source.
::
:: Usage: call :UnpackTCC
::
:: Returns: 0 on success, nonzero on failure
:: Requires: :decompress
:: ============================================================
:UnpackTCC
for /f "tokens=1 delims==" %%v in ('set utcc_ 2^>nul') do set "%%v="
if defined _utcc_rc (set "_utcc_rc=" & exit /b %_utcc_rc%)
call :EchoGreen GOOD: extracting TCC compiler.
call :decompress "%app.tcc.zip%" "%app.extract.root%"
if errorlevel 1 ( set "_utcc_rc=%errorlevel%" & goto :UnpackTCC )
if not exist "%app.w32api.src%\" mkdir "%app.w32api.src%" >nul 2>&1
call :EchoGreen GOOD: extracting w32api .tar.xz to .tar.
call :decompress "%app.w32api.txz%" "%app.w32api.src%"
if errorlevel 1 ( set "_utcc_rc=%errorlevel%" & goto :UnpackTCC )
if not exist "%app.w32api.tar%" ( call :EchoRed FAIL: expected tar file was not produced: %app.w32api.tar% & set "_utcc_rc=1" & goto :UnpackTCC )
call :EchoGreen GOOD: extracting w32api .tar contents.
call :decompress "%app.w32api.tar%" "%app.w32api.src%"
if errorlevel 1 ( set "_utcc_rc=%errorlevel%" & goto :UnpackTCC )
set "_utcc_rc=0" & goto :UnpackTCC

:: ============================================================
:: :FinalizeTCC
:: Adds local TCC to the current temporary PATH, creates a
:: current-folder tcc.exe hardlink, resolves current tcc.exe, then
:: prints a decisive YES or NO.
::
:: Usage: call :FinalizeTCC
::
:: Output:
::   app.current.tcc.exe  resolved current tcc.exe path
::
:: Returns: 0 if local TCC is active and hardlink exists
::          1 otherwise
:: Requires: :AddTCCToPath, :LinkCurrentTCC, :GetCurrentTCC
:: ============================================================
:FinalizeTCC
for /f "tokens=1 delims==" %%v in ('set ftcc_ 2^>nul') do set "%%v="
if defined _ftcc_rc (set "_ftcc_rc=" & exit /b %_ftcc_rc%)
if defined app.bootstrap.rc if not "%app.bootstrap.rc%"=="0" ( call :EchoRed FAIL: bootstrap returned %app.bootstrap.rc% & set "ftcc_failed=1" )
if not exist "%app.tcc.exe%" goto :_FinalizeTCC_missing
call :EchoGreen GOOD: local TCC exists: %app.tcc.exe%
call :AddTCCToPath "%app.tcc.abs%"
if errorlevel 1 set "ftcc_failed=1"
call :LinkCurrentTCC "%app.tcc.exe%" "%app.tcc.link%"
if errorlevel 1 set "ftcc_failed=1"
call :GetCurrentTCC
if errorlevel 1 goto :_FinalizeTCC_notfound
set "ftcc_currentok="
if /i "%app.current.tcc.exe%"=="%app.tcc.link%" set "ftcc_currentok=1"
if /i "%app.current.tcc.exe%"=="%app.tcc.exe%" set "ftcc_currentok=1"
if defined ftcc_failed goto :_FinalizeTCC_failed
if not defined ftcc_currentok goto :_FinalizeTCC_wrong
call :EchoGreen YES: local TCC is ready and active.
call :EchoGreen GOOD: CURRENT TCC.EXE: %app.current.tcc.exe%
set "_ftcc_rc=0" & goto :FinalizeTCC
:_FinalizeTCC_missing
call :EchoRed NO: local TCC is missing.
call :GetCurrentTCC
if errorlevel 1 call :EchoRed FAIL: CURRENT TCC.EXE: not found
if not errorlevel 1 call :EchoRed FAIL: CURRENT TCC.EXE: %app.current.tcc.exe%
set "_ftcc_rc=1" & goto :FinalizeTCC
:_FinalizeTCC_notfound
call :EchoRed NO: tcc.exe is not available now.
call :EchoRed FAIL: CURRENT TCC.EXE: not found
set "_ftcc_rc=1" & goto :FinalizeTCC
:_FinalizeTCC_failed
call :EchoRed NO: local TCC setup is incomplete.
call :EchoRed FAIL: CURRENT TCC.EXE: %app.current.tcc.exe%
set "_ftcc_rc=1" & goto :FinalizeTCC
:_FinalizeTCC_wrong
call :EchoRed NO: current tcc.exe points outside this install.
call :EchoRed FAIL: CURRENT TCC.EXE: %app.current.tcc.exe%
set "_ftcc_rc=1" & goto :FinalizeTCC

:: ============================================================
:: :AddTCCToPath
:: Prepends the absolute local TCC folder to the current,
:: temporary PATH value.
::
:: Usage: call :AddTCCToPath absoluteTccFolder
::
:: Returns: 0 on success
::          2 missing folder
:: Requires: none
:: ============================================================
:AddTCCToPath
for /f "tokens=1 delims==" %%v in ('set atp_ 2^>nul') do set "%%v="
if defined _atp_rc (set "_atp_rc=" & exit /b %_atp_rc%)
set "atp_dir=%~1"
if not defined atp_dir ( call :EchoRed FAIL: missing TCC PATH folder. & set "_atp_rc=2" & goto :AddTCCToPath )
if not exist "%atp_dir%\" ( call :EchoRed FAIL: TCC PATH folder does not exist: %atp_dir% & set "_atp_rc=2" & goto :AddTCCToPath )
set "PATH=%atp_dir%;%PATH%"
call :EchoGreen GOOD: temporary PATH prepended: %atp_dir%
set "_atp_rc=0" & goto :AddTCCToPath

:: ============================================================
:: :LinkCurrentTCC
:: Creates current-folder tcc.exe as a hardlink to the real local
:: TCC executable.
::
:: Usage: call :LinkCurrentTCC realTccExe currentFolderLink
::
:: Returns: 0 on success
::          1 mklink failed
::          2 invalid args / source missing
:: Requires: mklink
:: ============================================================
:LinkCurrentTCC
for /f "tokens=1 delims==" %%v in ('set lctcc_ 2^>nul') do set "%%v="
if defined _lctcc_rc (set "_lctcc_rc=" & exit /b %_lctcc_rc%)
set "lctcc_src=%~1" & set "lctcc_dst=%~2"
if not defined lctcc_src ( call :EchoRed FAIL: missing real TCC executable path. & set "_lctcc_rc=2" & goto :LinkCurrentTCC )
if not defined lctcc_dst ( call :EchoRed FAIL: missing current-folder TCC hardlink path. & set "_lctcc_rc=2" & goto :LinkCurrentTCC )
if not exist "%lctcc_src%" ( call :EchoRed FAIL: real TCC executable missing: %lctcc_src% & set "_lctcc_rc=2" & goto :LinkCurrentTCC )
if /i "%lctcc_src%"=="%lctcc_dst%" ( call :EchoGreen GOOD: current folder is already the TCC folder; hardlink not needed. & set "_lctcc_rc=0" & goto :LinkCurrentTCC )
del /q "%lctcc_dst%" >nul 2>&1
if exist "%lctcc_dst%" ( call :EchoRed FAIL: could not replace existing current-folder tcc.exe: %lctcc_dst% & set "_lctcc_rc=1" & goto :LinkCurrentTCC )
mklink /H "%lctcc_dst%" "%lctcc_src%" >nul 2>&1
if errorlevel 1 ( call :EchoRed FAIL: could not create current-folder tcc.exe hardlink: %lctcc_dst% & set "_lctcc_rc=1" & goto :LinkCurrentTCC )
if not exist "%lctcc_dst%" ( call :EchoRed FAIL: current-folder tcc.exe hardlink was not created: %lctcc_dst% & set "_lctcc_rc=1" & goto :LinkCurrentTCC )
call :EchoGreen GOOD: current-folder tcc.exe hardlink: %lctcc_dst%
set "_lctcc_rc=0" & goto :LinkCurrentTCC

:: ============================================================
:: :GetCurrentTCC
:: Resolves the current tcc.exe path.
::
:: Usage: call :GetCurrentTCC
::
:: Output:
::   app.current.tcc.exe  resolved current tcc.exe path
::
:: Returns: 0 if found
::          1 if not found
:: Requires: where
:: ============================================================
:GetCurrentTCC
for /f "tokens=1 delims==" %%v in ('set gctcc_ 2^>nul') do set "%%v="
if defined _gctcc_rc (set "_gctcc_rc=" & exit /b %_gctcc_rc%)
set "app.current.tcc.exe="
if exist "%CD%\tcc.exe" for %%P in ("%CD%\tcc.exe") do if not defined app.current.tcc.exe set "app.current.tcc.exe=%%~fP"
for /f "delims=" %%P in ('where tcc.exe 2^>nul') do if not defined app.current.tcc.exe set "app.current.tcc.exe=%%~fP"
if not defined app.current.tcc.exe ( set "_gctcc_rc=1" & goto :GetCurrentTCC )
set "_gctcc_rc=0" & goto :GetCurrentTCC

:_...TCC_BOOTSTRAP_ACTIVATION

:_DOWNLOAD_VERIFICATION

:: ============================================================
:: :DownloadAndCheck
:: Ensures a file and its hash/signature file exist and verify.
:: If app.alwaysdownload is defined, downloads again even when
:: cached files already verify.
:: If app.nohashcheck is defined, downloads only the main file
:: and skips hash/signature download and verification.
::
:: Usage: call :DownloadAndCheck url filepath hashurl hashfilepath [optional hashfallback]
::
:: Returns: 0 on success, nonzero on failure
:: Requires: :download, :CheckFileIntegrity
:: ============================================================
:DownloadAndCheck
for /f "tokens=1 delims==" %%v in ('set dac_ 2^>nul') do set "%%v="
if defined _dac_rc (set "_dac_rc=" & exit /b %_dac_rc%)
set "dac_url=%~1" & set "dac_file=%~2" & set "dac_hashurl=%~3" & set "dac_hashfile=%~4" & set "dac_fallback=%~5"
if not defined dac_url ( call :EchoRed FAIL: DownloadAndCheck requires url. & set "_dac_rc=2" & goto :DownloadAndCheck )
if not defined dac_file ( call :EchoRed FAIL: DownloadAndCheck requires filepath. & set "_dac_rc=2" & goto :DownloadAndCheck )
if defined app.nohashcheck goto :_DownloadAndCheck_nohash
if not defined dac_hashurl ( call :EchoRed FAIL: DownloadAndCheck requires hashurl. & set "_dac_rc=2" & goto :DownloadAndCheck )
if not defined dac_hashfile ( call :EchoRed FAIL: DownloadAndCheck requires hashfilepath. & set "_dac_rc=2" & goto :DownloadAndCheck )
if defined app.alwaysdownload goto :_DownloadAndCheck_download
if exist "%dac_file%" if exist "%dac_hashfile%" call :CheckFileIntegrity "%dac_file%" "%dac_hashfile%" "%dac_fallback%"
if exist "%dac_file%" if exist "%dac_hashfile%" if not errorlevel 1 ( call :EchoGreen GOOD: verified cached: %~nx2 & set "_dac_rc=0" & goto :DownloadAndCheck )
:_DownloadAndCheck_download
call :download "%dac_hashurl%" "%dac_hashfile%"
if errorlevel 1 ( set "_dac_rc=%errorlevel%" & goto :DownloadAndCheck )
call :download "%dac_url%" "%dac_file%"
if errorlevel 1 ( set "_dac_rc=%errorlevel%" & goto :DownloadAndCheck )
call :CheckFileIntegrity "%dac_file%" "%dac_hashfile%" "%dac_fallback%"
if errorlevel 1 ( call :EchoRed FAIL: verification failed after download: %dac_file% & set "_dac_rc=1" & goto :DownloadAndCheck )
set "_dac_rc=0" & goto :DownloadAndCheck
:_DownloadAndCheck_nohash
if not defined app.alwaysdownload if exist "%dac_file%" ( call :EchoYellow WARNING: nohashcheck using cached unverified file: %~nx2 & set "_dac_rc=0" & goto :DownloadAndCheck )
call :EchoYellow WARNING: nohashcheck downloading without verification: %~nx2
call :download "%dac_url%" "%dac_file%"
if errorlevel 1 ( set "_dac_rc=%errorlevel%" & goto :DownloadAndCheck )
call :EchoYellow WARNING: nohashcheck skipped verification: %~nx2
set "_dac_rc=0" & goto :DownloadAndCheck

:: ============================================================
:: :download
:: Downloads a URL using curl.
::
:: Usage: call :download URL [optional filepath]
::
:: Output:
::   dl_curloutput[N]       captured curl output
::   dl_curloutput.lbound   lower bound, always 0
::   dl_curloutput.ubound   last captured output index, or -1
::
:: Returns: curl exit code on transfer, or:
::          2 invalid arguments / output path
:: Requires: curl
:: ============================================================
:download
for /f "tokens=1 delims==" %%v in ('set dl_ 2^>nul') do set "%%v="
if defined _dl_rc (set "_dl_rc=" & exit /b %_dl_rc%)
set "dl_url=%~1" & set "dl_out=%~2"
if not defined dl_url ( call :EchoRed FAIL: download requires a URL. & set "_dl_rc=2" & goto :download )
if not defined dl_out for %%A in ("%dl_url:/=\%") do set "dl_out=%%~nxA"
if not defined dl_out ( call :EchoRed FAIL: could not infer download filename. & set "_dl_rc=2" & goto :download )
for %%A in ("%dl_out%") do set "dl_outdir=%%~dpA" & set "dl_name=%%~nxA"
if defined dl_outdir if not exist "%dl_outdir%" mkdir "%dl_outdir%" >nul 2>&1
set /a dl_curloutput_ubound=-1
set "dl_curloutput.lbound=0"
set "dl_curloutput.ubound=-1"
for /f "delims=" %%L in ('curl -L --fail --show-error --retry 3 --retry-delay 2 -o "%dl_out%" "%dl_url%" 2^>^&1') do ( call set /a dl_curloutput_ubound+=1 & call set "dl_curloutput[%%dl_curloutput_ubound%%]=%%L" )
set "dl_curloutput.ubound=%dl_curloutput_ubound%"
set "_dl_rc=%errorlevel%"
if "%_dl_rc%"=="0" ( call :EchoGreen GOOD: download OK: %dl_name% & goto :download )
call :EchoRed FAIL: download FAILED: %dl_name%
call :EchoRed FAIL: URL: %dl_url%
call :EchoRed FAIL: To: %dl_out%
call :PrintArray dl_curloutput
goto :download

:: ============================================================
:: :CheckFileIntegrity
:: Verifies a file using a .sha256 file, a .sig file, or a
:: literal SHA256 fallback when .sig is present but gpg.exe is
:: unavailable.
::
:: Usage: call :CheckFileIntegrity filetocheck hashfile [optional hashfallback]
::
:: Returns: 0 on success, nonzero on failure
:: Requires: :hashcheck, :hashcheckliteral, :IsAppAvailable
:: ============================================================
:CheckFileIntegrity
for /f "tokens=1 delims==" %%v in ('set cfi_ 2^>nul') do set "%%v="
if defined _cfi_rc (set "_cfi_rc=" & exit /b %_cfi_rc%)
set "cfi_file=%~1" & set "cfi_hashfile=%~2" & set "cfi_fallback=%~3" & set "cfi_ext=%~x2"
if not defined cfi_file ( set "_cfi_rc=2" & goto :CheckFileIntegrity )
if not defined cfi_hashfile ( set "_cfi_rc=2" & goto :CheckFileIntegrity )
if /i not "%cfi_ext%"==".sig" goto :_CheckFileIntegrity_normal
call :IsAppAvailable gpg.exe
if not errorlevel 1 goto :_CheckFileIntegrity_normal
if not defined cfi_fallback ( call :EchoRed FAIL: integrity failed: %~nx1 ; gpg.exe missing and no fallback hash & set "_cfi_rc=3" & goto :CheckFileIntegrity )
call :EchoYellow WARNING: gpg.exe was not found. Falling back to embedded SHA256.
call :hashcheckliteral "%cfi_file%" "%cfi_fallback%"
set "_cfi_rc=%errorlevel%" & goto :CheckFileIntegrity
:_CheckFileIntegrity_normal
call :hashcheck "%cfi_file%" "%cfi_hashfile%"
set "_cfi_rc=%errorlevel%" & goto :CheckFileIntegrity

:: ============================================================
:: :hashcheck
:: Checks a file against either:
::   .sha256  using certutil SHA256 comparison
::   .sig     using gpg detached-signature verification
::
:: Usage: call :hashcheck filetocheck signaturefile
::
:: Returns: 0 if hash/signature matches
::          1 mismatch / invalid signature
::          2 invalid arguments / unsupported type
::          3 required app unavailable
:: Requires: certutil for .sha256, gpg for .sig
:: ============================================================
:hashcheck
for /f "tokens=1 delims==" %%v in ('set hc_ 2^>nul') do set "%%v="
if defined _hc_rc (set "_hc_rc=" & exit /b %_hc_rc%)
set "hc_file=%~1" & set "hc_sig=%~2" & set "hc_sigext=%~x2"
if not exist "%hc_file%" ( call :EchoRed FAIL: file to check does not exist: %hc_file% & set "_hc_rc=2" & goto :hashcheck )
if not exist "%hc_sig%" ( call :EchoRed FAIL: signature/hash file does not exist: %hc_sig% & set "_hc_rc=2" & goto :hashcheck )
if /i "%hc_sigext%"==".sha256" goto :_hashcheck_sha256
if /i "%hc_sigext%"==".sig" goto :_hashcheck_sig
call :EchoRed FAIL: unsupported signature/hash file type: %hc_sigext%
set "_hc_rc=2" & goto :hashcheck
:_hashcheck_sha256
set "hc_expected=" & set "hc_actual="
for /f "usebackq tokens=1" %%H in ("%hc_sig%") do if not defined hc_expected set "hc_expected=%%H"
for /f "tokens=1" %%H in ('certutil -hashfile "%hc_file%" SHA256 2^>nul ^| findstr /R /I "^[0-9A-F][0-9A-F]*$"') do if not defined hc_actual set "hc_actual=%%H"
if not defined hc_expected ( call :EchoRed FAIL: SHA256 could not read expected hash: %~nx1 & set "_hc_rc=1" & goto :hashcheck )
if not defined hc_actual ( call :EchoRed FAIL: SHA256 could not compute hash: %~nx1 & set "_hc_rc=1" & goto :hashcheck )
if /i "%hc_expected%"=="%hc_actual%" ( call :EchoGreen GOOD: SHA256 OK: %~nx1 & set "_hc_rc=0" & goto :hashcheck )
call :EchoRed FAIL: SHA256 mismatch: %~nx1
call :EchoRed FAIL: Expected: %hc_expected%
call :EchoRed FAIL: Actual: %hc_actual%
set "_hc_rc=1" & goto :hashcheck
:_hashcheck_sig
call :IsAppAvailable gpg.exe
if errorlevel 1 ( call :EchoRed FAIL: signature check unavailable: gpg.exe missing & set "_hc_rc=3" & goto :hashcheck )
call set "hc_gpg=%%iaa.found%%"
set /a hc_gpgoutput_ubound=-1
set "hc_gpgoutput.lbound=0"
set "hc_gpgoutput.ubound=-1"
for /f "delims=" %%L in ('call "%hc_gpg%" --batch --verify "%hc_sig%" "%hc_file%" 2^>^&1') do ( call set /a hc_gpgoutput_ubound+=1 & call set "hc_gpgoutput[%%hc_gpgoutput_ubound%%]=%%L" )
set "hc_gpgoutput.ubound=%hc_gpgoutput_ubound%"
set "_hc_rc=%errorlevel%"
if "%_hc_rc%"=="0" ( call :EchoGreen GOOD: signature OK: %~nx1 & goto :hashcheck )
call :EchoRed FAIL: signature FAILED: %~nx1
call :PrintArray hc_gpgoutput
goto :hashcheck

:: ============================================================
:: :hashcheckliteral
:: Checks a file against a literal SHA256 hash string.
::
:: Usage: call :hashcheckliteral filetocheck expectedsha256
::
:: Returns: 0 if SHA256 matches
::          1 mismatch / hash computation failure
::          2 invalid arguments
:: Requires: certutil
:: ============================================================
:hashcheckliteral
for /f "tokens=1 delims==" %%v in ('set hcl_ 2^>nul') do set "%%v="
if defined _hcl_rc (set "_hcl_rc=" & exit /b %_hcl_rc%)
set "hcl_file=%~1" & set "hcl_expected=%~2" & set "hcl_actual="
if not exist "%hcl_file%" ( call :EchoRed FAIL: SHA256 file missing: %~nx1 & set "_hcl_rc=2" & goto :hashcheckliteral )
if not defined hcl_expected ( call :EchoRed FAIL: SHA256 expected hash missing: %~nx1 & set "_hcl_rc=2" & goto :hashcheckliteral )
for /f "tokens=1" %%H in ('certutil -hashfile "%hcl_file%" SHA256 2^>nul ^| findstr /R /I "^[0-9A-F][0-9A-F]*$"') do if not defined hcl_actual set "hcl_actual=%%H"
if not defined hcl_actual ( call :EchoRed FAIL: SHA256 could not compute hash: %~nx1 & set "_hcl_rc=1" & goto :hashcheckliteral )
if /i "%hcl_expected%"=="%hcl_actual%" ( call :EchoGreen GOOD: SHA256 OK: %~nx1 & set "_hcl_rc=0" & goto :hashcheckliteral )
call :EchoRed FAIL: SHA256 mismatch: %~nx1
call :EchoRed FAIL: Expected: %hcl_expected%
call :EchoRed FAIL: Actual: %hcl_actual%
set "_hcl_rc=1" & goto :hashcheckliteral

:_...DOWNLOAD_VERIFICATION

:_ARCHIVE_EXTRACTION

:: ============================================================
:: :decompress
:: General-purpose archive dispatcher.
::
:: Usage: call :decompress sourcefile [optional destination path]
::
:: Supports:
::   .zip using :unzip
::   .xz  using :unxz
::   .tar using :untar
::
:: Returns: child function exit code, or:
::          2 invalid args / unsupported archive type
:: Requires: :unzip, :unxz, :untar
:: ============================================================
:decompress
for /f "tokens=1 delims==" %%v in ('set dec_ 2^>nul') do set "%%v="
if defined _dec_rc (set "_dec_rc=" & exit /b %_dec_rc%)
set "dec_src=%~1" & set "dec_dest=%~2" & set "dec_ext=%~x1"
if not exist "%dec_src%" ( call :EchoRed FAIL: decompress source file missing: %~nx1 & set "_dec_rc=2" & goto :decompress )
if not defined dec_dest for %%A in ("%dec_src%") do set "dec_dest=%%~dpA"
for %%A in ("%dec_dest%.") do set "dec_dest=%%~fA"
if /i "%dec_ext%"==".zip" goto :_decompress_zip
if /i "%dec_ext%"==".xz" goto :_decompress_xz
if /i "%dec_ext%"==".tar" goto :_decompress_tar
call :EchoRed FAIL: unsupported archive type: %~nx1
set "_dec_rc=2" & goto :decompress
:_decompress_zip
call :unzip "%dec_src%" "%dec_dest%" dec_output
set "_dec_rc=%errorlevel%" & goto :decompress
:_decompress_xz
call :unxz "%dec_src%" "%dec_dest%" dec_output
set "_dec_rc=%errorlevel%" & goto :decompress
:_decompress_tar
call :untar "%dec_src%" "%dec_dest%" dec_output
set "_dec_rc=%errorlevel%" & goto :decompress

:: ============================================================
:: :unzip
:: Extracts a .zip archive using PowerShell Expand-Archive.
::
:: Usage: call :unzip sourcefile destination [outputArrayPrefix]
::
:: Output:
::   outputArrayPrefix[N]       captured PowerShell output
::   outputArrayPrefix.lbound   lower bound, always 0
::   outputArrayPrefix.ubound   last captured output index, or -1
::
:: Returns: 0 on success
::          2 invalid args
::          3 powershell unavailable
:: Requires: :IsAppAvailable, :PrintArray
:: ============================================================
:unzip
for /f "tokens=1 delims==" %%v in ('set uz_ 2^>nul') do set "%%v="
if defined _uz_rc (set "_uz_rc=" & exit /b %_uz_rc%)
set "uz_src=%~1" & set "uz_dest=%~2" & set "uz_outpfx=%~3"
if not defined uz_outpfx set "uz_outpfx=uz_output"
if not exist "%uz_src%" ( call :EchoRed FAIL: unzip source file missing: %~nx1 & set "_uz_rc=2" & goto :unzip )
if not defined uz_dest for %%A in ("%uz_src%") do set "uz_dest=%%~dpA"
for %%A in ("%uz_dest%.") do set "uz_dest=%%~fA"
if not exist "%uz_dest%\" mkdir "%uz_dest%" >nul 2>&1
call :IsAppAvailable powershell.exe
if errorlevel 1 ( call :EchoRed FAIL: unzip unavailable: powershell.exe not found & set "_uz_rc=3" & goto :unzip )
set "uz_ps_src=%uz_src%"
set "uz_ps_dest=%uz_dest%"
set "uz_ps_unzip_script=$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:uz_ps_src -DestinationPath $env:uz_ps_dest -Force"
set /a uz_ubound=-1
set "%uz_outpfx%.lbound=0"
set "%uz_outpfx%.ubound=-1"
for /f "delims=" %%L in ('powershell -NoProfile -Sta -ExecutionPolicy Bypass -Command "iex $env:uz_ps_unzip_script" 2^>^&1') do ( call set /a uz_ubound+=1 & call set "%uz_outpfx%[%%uz_ubound%%]=%%L" )
set "%uz_outpfx%.ubound=%uz_ubound%"
set "_uz_rc=%errorlevel%"
set "uz_ps_src="
set "uz_ps_dest="
set "uz_ps_unzip_script="
if "%_uz_rc%"=="0" ( call :EchoGreen GOOD: unzip OK: %~nx1 to %uz_dest% & goto :unzip )
call :EchoRed FAIL: unzip FAILED: %~nx1 to %uz_dest%
call :PrintArray "%uz_outpfx%"
goto :unzip

:: ============================================================
:: :unxz
:: Decompresses an .xz file using xz.exe.
::
:: Usage: call :unxz sourcefile destination [outputArrayPrefix]
::
:: Output:
::   outputArrayPrefix[N]       captured xz output
::   outputArrayPrefix.lbound   lower bound, always 0
::   outputArrayPrefix.ubound   last captured output index, or -1
::
:: Returns: 0 on success
::          2 invalid args
::          3 xz unavailable
:: Requires: :IsAppAvailable, :PrintArray
:: ============================================================
:unxz
for /f "tokens=1 delims==" %%v in ('set uxz_ 2^>nul') do set "%%v="
if defined _uxz_rc (set "_uxz_rc=" & exit /b %_uxz_rc%)
set "uxz_src=%~1" & set "uxz_dest=%~2" & set "uxz_outpfx=%~3"
if not defined uxz_outpfx set "uxz_outpfx=uxz_output"
if not exist "%uxz_src%" ( call :EchoRed FAIL: unxz source file missing: %~nx1 & set "_uxz_rc=2" & goto :unxz )
if not defined uxz_dest for %%A in ("%uxz_src%") do set "uxz_dest=%%~dpA"
for %%A in ("%uxz_dest%.") do set "uxz_dest=%%~fA"
if not exist "%uxz_dest%\" mkdir "%uxz_dest%" >nul 2>&1
call :IsAppAvailable xz.exe
if errorlevel 1 ( call :EchoRed FAIL: unxz unavailable: xz.exe not found & set "_uxz_rc=3" & goto :unxz )
call set "uxz_xz=%%iaa.found%%"
for %%A in ("%uxz_src%") do set "uxz_outfile=%uxz_dest%\%%~nA"
set /a uxz_ubound=-1
set "%uxz_outpfx%.lbound=0"
set "%uxz_outpfx%.ubound=-1"
for /f "delims=" %%L in ('call "%uxz_xz%" -dc "%uxz_src%" 2^>^&1 ^> "%uxz_outfile%"') do ( call set /a uxz_ubound+=1 & call set "%uxz_outpfx%[%%uxz_ubound%%]=%%L" )
set "%uxz_outpfx%.ubound=%uxz_ubound%"
set "_uxz_rc=%errorlevel%"
if "%_uxz_rc%"=="0" ( call :EchoGreen GOOD: unxz OK: %~nx1 to %uxz_outfile% & goto :unxz )
del /q "%uxz_outfile%" >nul 2>&1
call :EchoRed FAIL: unxz FAILED: %~nx1 to %uxz_outfile%
call :PrintArray "%uxz_outpfx%"
goto :unxz

:: ============================================================
:: :untar
:: Extracts a .tar archive using tar.exe.
::
:: Usage: call :untar sourcefile destination [outputArrayPrefix]
::
:: Output:
::   outputArrayPrefix[N]       captured tar output
::   outputArrayPrefix.lbound   lower bound, always 0
::   outputArrayPrefix.ubound   last captured output index, or -1
::
:: Returns: 0 on success
::          2 invalid args
::          3 tar unavailable
:: Requires: :IsAppAvailable, :PrintArray
:: ============================================================
:untar
for /f "tokens=1 delims==" %%v in ('set utar_ 2^>nul') do set "%%v="
if defined _utar_rc (set "_utar_rc=" & exit /b %_utar_rc%)
set "utar_src=%~1" & set "utar_dest=%~2" & set "utar_outpfx=%~3"
if not defined utar_outpfx set "utar_outpfx=utar_output"
if not exist "%utar_src%" ( call :EchoRed FAIL: untar source file missing: %~nx1 & set "_utar_rc=2" & goto :untar )
if not defined utar_dest for %%A in ("%utar_src%") do set "utar_dest=%%~dpA"
for %%A in ("%utar_dest%.") do set "utar_dest=%%~fA"
if not exist "%utar_dest%\" mkdir "%utar_dest%" >nul 2>&1
call :IsAppAvailable tar.exe
if errorlevel 1 ( call :EchoRed FAIL: untar unavailable: tar.exe not found & set "_utar_rc=3" & goto :untar )
call set "utar_tar=%%iaa.found%%"
set /a utar_ubound=-1
set "%utar_outpfx%.lbound=0"
set "%utar_outpfx%.ubound=-1"
for /f "delims=" %%L in ('call "%utar_tar%" -xf "%utar_src%" -C "%utar_dest%" 2^>^&1') do ( call set /a utar_ubound+=1 & call set "%utar_outpfx%[%%utar_ubound%%]=%%L" )
set "%utar_outpfx%.ubound=%utar_ubound%"
set "_utar_rc=%errorlevel%"
if "%_utar_rc%"=="0" ( call :EchoGreen GOOD: untar OK: %~nx1 to %utar_dest% & goto :untar )
call :EchoRed FAIL: untar FAILED: %~nx1 to %utar_dest%
call :PrintArray "%utar_outpfx%"
goto :untar

:_...ARCHIVE_EXTRACTION

:_XZ_BOOTSTRAP

:: ============================================================
:: :ConfigureXZPackage
:: Derives all xz filenames, paths, and URLs from:
::   app.xz.version
::   app.xz.baseurl
::
:: Input:
::   app.xz.version   version, e.g. 5.8.3
::   app.xz.baseurl   release base URL without version tag
::   app.downloads    downloads directory
::   app.xz           xz root directory
::
:: Output:
::   app.xz.release
::   app.xz.package.name
::   app.xz.zip.name
::   app.xz.sig.name
::   app.xz.zip
::   app.xz.sig
::   app.xz.zip.url
::   app.xz.sig.url
::
:: Returns: 0 on success
::          2 missing required setup value
:: Requires: none
:: ============================================================
:ConfigureXZPackage
for /f "tokens=1 delims==" %%v in ('set cxz_ 2^>nul') do set "%%v="
if defined _cxz_rc (set "_cxz_rc=" & exit /b %_cxz_rc%)
if not defined app.xz.version ( call :EchoRed FAIL: app.xz.version is not defined. & set "_cxz_rc=2" & goto :ConfigureXZPackage )
if not defined app.xz.baseurl ( call :EchoRed FAIL: app.xz.baseurl is not defined. & set "_cxz_rc=2" & goto :ConfigureXZPackage )
if not defined app.downloads ( call :EchoRed FAIL: app.downloads is not defined. & set "_cxz_rc=2" & goto :ConfigureXZPackage )
if not defined app.xz ( call :EchoRed FAIL: app.xz is not defined. & set "_cxz_rc=2" & goto :ConfigureXZPackage )
set "app.xz.release=v%app.xz.version%"
set "app.xz.package.name=xz-%app.xz.version%-windows"
set "app.xz.zip.name=%app.xz.package.name%.zip"
set "app.xz.sig.name=%app.xz.zip.name%.sig"
set "app.xz.zip=%app.downloads%\%app.xz.zip.name%"
set "app.xz.sig=%app.downloads%\%app.xz.sig.name%"
set "app.xz.zip.url=%app.xz.baseurl%/%app.xz.release%/%app.xz.zip.name%"
set "app.xz.sig.url=%app.xz.baseurl%/%app.xz.release%/%app.xz.sig.name%"
set "_cxz_rc=0" & goto :ConfigureXZPackage

:: ============================================================
:: :EnsureXZ
:: Ensures xz.exe is available.
::
:: Usage: call :EnsureXZ
::
:: Output:
::   app.xz.exe  resolved xz.exe path
::
:: Returns: 0 if xz.exe is available, nonzero otherwise
:: Requires: :IsAppAvailable, :GetXZ
:: ============================================================
:EnsureXZ
for /f "tokens=1 delims==" %%v in ('set exz_ 2^>nul') do set "%%v="
if defined _exz_rc (set "_exz_rc=" & exit /b %_exz_rc%)
call :IsAppAvailable xz.exe
if not errorlevel 1 goto :_EnsureXZ_found
call :EchoYellow WARNING: xz.exe was not found. Downloading xz.
call :GetXZ
if errorlevel 1 ( set "_exz_rc=%errorlevel%" & goto :EnsureXZ )
call :IsAppAvailable xz.exe
if errorlevel 1 ( call :EchoRed FAIL: xz.exe is still unavailable after GetXZ. & set "_exz_rc=1" & goto :EnsureXZ )
:_EnsureXZ_found
call set "app.xz.exe=%%iaa.found%%"
call :EchoGreen GOOD: xz.exe: %app.xz.exe%
set "_exz_rc=0" & goto :EnsureXZ

:: ============================================================
:: :GetXZ
:: Downloads and extracts the Windows xz package to app.xz,
:: then links/copies the selected architecture binaries into
:: app.xz directly.
::
:: Usage: call :GetXZ
::
:: Output:
::   app.xz.bin  selected source binary folder
::
:: Returns: 0 on success, nonzero on failure
:: Requires: :DownloadAndCheck, :decompress, :IsX64Windows, :hardlink
:: ============================================================
:GetXZ
for /f "tokens=1 delims==" %%v in ('set gxz_ 2^>nul') do set "%%v="
if defined _gxz_rc (set "_gxz_rc=" & exit /b %_gxz_rc%)
if not exist "%app.downloads%\" mkdir "%app.downloads%" >nul 2>&1
call :DownloadAndCheck "%app.xz.zip.url%" "%app.xz.zip%" "%app.xz.sig.url%" "%app.xz.sig%" "%app.xz.sha256%"
if errorlevel 1 ( set "_gxz_rc=%errorlevel%" & goto :GetXZ )
call :decompress "%app.xz.zip%" "%app.xz%"
if errorlevel 1 ( set "_gxz_rc=%errorlevel%" & goto :GetXZ )
call :IsX64Windows
if errorlevel 1 ( set "app.xz.bin=%app.xz%\bin_i686-sse2" ) else ( set "app.xz.bin=%app.xz%\bin_x86-64" )
if not exist "%app.xz.bin%\" ( call :EchoRed FAIL: xz install selected bin folder missing: %app.xz.bin% & set "_gxz_rc=2" & goto :GetXZ )
for %%F in ("%app.xz.bin%\*") do set "hardlink.fallback.copy=true" & call :hardlink "%%~fF" "%app.xz%\%%~nxF"
if not exist "%app.xz%\xz.exe" ( call :EchoRed FAIL: xz install failed: xz.exe was not linked or copied & set "_gxz_rc=1" & goto :GetXZ )
call :EchoGreen GOOD: xz bin OK: %app.xz.bin% to %app.xz%
set "_gxz_rc=0" & goto :GetXZ

:_...XZ_BOOTSTRAP

:_FILE_SYSTEM_HELPERS

:: ============================================================
:: :IsX64Windows
:: Detects whether the current Windows environment is x64.
::
:: Usage: call :IsX64Windows
::
:: Returns: 0 if x64/AMD64
::          1 otherwise
:: Requires: none
:: ============================================================
:IsX64Windows
for /f "tokens=1 delims==" %%v in ('set ix64_ 2^>nul') do set "%%v="
if defined _ix64_rc (set "_ix64_rc=" & exit /b %_ix64_rc%)
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" ( set "_ix64_rc=0" & goto :IsX64Windows )
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" ( set "_ix64_rc=0" & goto :IsX64Windows )
set "_ix64_rc=1" & goto :IsX64Windows

:: ============================================================
:: :hardlink
:: Creates a hardlink from targetfile to sourcefile.
::
:: Usage:
::   call :hardlink sourcefile targetfile
::   set "hardlink.fallback.copy=true" & call :hardlink sourcefile targetfile
::   set "_hardlink.fallback.copy=true"
::
:: Feature flags:
::   hardlink.fallback.copy   one-call copy fallback flag. Cleared each call.
::   _hardlink.fallback.copy  persistent copy fallback flag. Not cleared.
::
:: Returns: 0 if linked or copied
::          1 failed
::          2 invalid args / source missing
:: Requires: mklink, optional copy
:: ============================================================
:hardlink
for /f "tokens=1 delims==" %%v in ('set hl_ 2^>nul') do set "%%v="
if defined _hl_rc (set "_hl_rc=" & exit /b %_hl_rc%)
set "hl_src=%~1" & set "hl_dst=%~2" & set "hl_copyfallback="
if defined hardlink.fallback.copy set "hl_copyfallback=1"
if defined _hardlink.fallback.copy set "hl_copyfallback=1"
set "hardlink.fallback.copy="
if not defined hl_src ( call :EchoRed FAIL: hardlink missing sourcefile & set "_hl_rc=2" & goto :hardlink )
if not defined hl_dst ( call :EchoRed FAIL: hardlink missing targetfile & set "_hl_rc=2" & goto :hardlink )
if not exist "%hl_src%" ( call :EchoRed FAIL: hardlink source file missing: %hl_src% & set "_hl_rc=2" & goto :hardlink )
for %%A in ("%hl_dst%") do set "hl_dstdir=%%~dpA" & set "hl_dstname=%%~nxA"
if defined hl_dstdir if not exist "%hl_dstdir%" mkdir "%hl_dstdir%" >nul 2>&1
if exist "%hl_dst%" del /q "%hl_dst%" >nul 2>&1
mklink /H "%hl_dst%" "%hl_src%" >nul 2>&1
if not errorlevel 1 ( set "_hl_rc=0" & goto :hardlink )
if defined hl_copyfallback copy /y "%hl_src%" "%hl_dst%" >nul 2>&1
if defined hl_copyfallback if not errorlevel 1 ( set "_hl_rc=0" & goto :hardlink )
call :EchoRed FAIL: hardlink failed: %hl_dstname%
call :EchoRed FAIL: source: %hl_src%
call :EchoRed FAIL: target: %hl_dst%
if defined hl_copyfallback call :EchoRed FAIL: copy fallback also failed.
set "_hl_rc=1" & goto :hardlink

:: ============================================================
:: :IsAppAvailable
:: Checks whether an executable is available.
::
:: Usage: call :IsAppAvailable executablename
::
:: Output:
::   iaa.found  resolved path when found
::
:: Returns: 0 if found
::          1 if not found
::          2 invalid arguments
:: Requires: where
:: ============================================================
:IsAppAvailable
for /f "tokens=1 delims==" %%v in ('set iaa_ 2^>nul') do set "%%v="
if defined _iaa_rc (set "_iaa_rc=" & exit /b %_iaa_rc%)
set "iaa.name=%~1" & set "iaa.found="
if not defined iaa.name ( set "_iaa_rc=2" & goto :IsAppAvailable )
call :_IsAppAvailable_consider "%iaa.name%"
if not errorlevel 1 ( set "_iaa_rc=0" & goto :IsAppAvailable )
if /i "%~x1"=="" ( call :_IsAppAvailable_consider "%iaa.name%.exe" & if not errorlevel 1 ( set "_iaa_rc=0" & goto :IsAppAvailable ) )
set "_iaa_rc=1" & goto :IsAppAvailable

:: ============================================================
:: :_IsAppAvailable_consider
:: Helper for :IsAppAvailable. Tests one candidate name.
::
:: Usage: call :_IsAppAvailable_consider executablename
::
:: Returns: 0 if found
::          1 if not found
:: Requires: where
:: ============================================================
:_IsAppAvailable_consider
set "iaa_candidate=%~1"
if not defined iaa_candidate exit /b 1
if exist "%iaa_candidate%" ( for %%P in ("%iaa_candidate%") do set "iaa.found=%%~fP" & exit /b 0 )
for /f "delims=" %%P in ('where "%iaa_candidate%" 2^>nul') do ( set "iaa.found=%%~fP" & exit /b 0 )
if exist "%CD%\%iaa_candidate%" ( set "iaa.found=%CD%\%iaa_candidate%" & exit /b 0 )
if exist "%~dp0%iaa_candidate%" ( set "iaa.found=%~dp0%iaa_candidate%" & exit /b 0 )
for /r "%CD%" %%P in (%iaa_candidate%) do if exist "%%~fP" ( set "iaa.found=%%~fP" & exit /b 0 )
if /i not "%CD%\"=="%~dp0" for /r "%~dp0" %%P in (%iaa_candidate%) do if exist "%%~fP" ( set "iaa.found=%%~fP" & exit /b 0 )
exit /b 1

:_...FILE_SYSTEM_HELPERS

:_ARRAY_OUTPUT_HELPERS

:: ============================================================
:: :PrintArray
:: Prints indexed pseudoarray entries in red.
::
:: Usage: call :PrintArray arrayPrefix
::
:: Input:
::   arrayPrefix[N]       array entry
::   arrayPrefix.lbound   optional lower bound, defaults to 0
::   arrayPrefix.ubound   upper bound
::
:: Returns: 0 on success
::          2 missing prefix / missing ubound
:: Requires: :EchoRed
:: ============================================================
:PrintArray
for /f "tokens=1 delims==" %%v in ('set pa_ 2^>nul') do set "%%v="
if defined _pa_rc (set "_pa_rc=" & exit /b %_pa_rc%)
set "pa_pfx=%~1"
if not defined pa_pfx ( set "_pa_rc=2" & goto :PrintArray )
call set "pa_lbound=%%%pa_pfx%.lbound%%"
call set "pa_ubound=%%%pa_pfx%.ubound%%"
if not defined pa_lbound set "pa_lbound=0"
if not defined pa_ubound ( set "_pa_rc=2" & goto :PrintArray )
if %pa_ubound% LSS %pa_lbound% ( set "_pa_rc=0" & goto :PrintArray )
set /a pa_i=pa_lbound
:_PrintArray_loop
call set "pa_line=%%%pa_pfx%[%pa_i%]%%"
call :EchoRed FAIL: %%pa_line%%
set /a pa_i+=1
if %pa_i% LEQ %pa_ubound% goto :_PrintArray_loop
set "_pa_rc=0" & goto :PrintArray

:: ============================================================
:: :SetESC
:: Captures the ANSI escape character into the requested output
:: variable.
::
:: Usage: call :SetESC outputVariable
::
:: Output:
::   outputVariable  ANSI escape character if capture succeeds
::
:: Returns: 0 on success
::          2 missing output variable
:: Requires: prompt, cmd
:: ============================================================
:SetESC
for /f "tokens=1 delims==" %%v in ('set sesc_ 2^>nul') do set "%%v="
if defined _sesc_rc (set "_sesc_rc=" & exit /b %_sesc_rc%)
set "sesc_out=%~1"
if not defined sesc_out ( set "_sesc_rc=2" & goto :SetESC )
for /f %%a in ('echo prompt $E^| cmd') do set "%sesc_out%=%%a"
set "_sesc_rc=0" & goto :SetESC

:_...ARRAY_OUTPUT_HELPERS

:_GENERIC_CONSOLE_OUTPUT

:: ============================================================
:: :Write
:: Prints %* without appending a newline.
::
:: One-call config,                  persistent config
::   write.color                     _write.color
::   write.backcolor                 _write.backcolor
::
:: Usage:
::   call :Write message
::   set "write.color=92" & call :Write green message
::
:: Returns: 0
:: Requires: optional :SetESC
:: ============================================================
:Write
for /f "tokens=1 delims==" %%v in ('set wr_ 2^>nul') do set "%%v="
if defined _wr_rc (set "_wr_rc=" & exit /b %_wr_rc%)
>nul 2>&1 set _write. && (
    if defined _write.color set "wr_colorfore=%_write.color%"
    if defined _write.backcolor set "wr_colorback=;%_write.backcolor%"
)
>nul 2>&1 set write. && (
    if defined write.color set "wr_colorfore=%write.color%"
    if defined write.backcolor set "wr_colorback=;%write.backcolor%"
    set "write.color=" & set "write.backcolor="
)
>nul 2>&1 set wr_color && (
    if not defined app.esc call :SetESC app.esc
    set "wr_startcolor=%app.esc%[%wr_colorfore%%wr_colorback%m"
    set "wr_endcolor=%app.esc%[0m"
)
<nul set /p "=%wr_startcolor%%*%wr_endcolor%"
set "_wr_rc=0" & goto :Write

:: ============================================================
:: :Echo
:: Prints %* with a newline unless echo.nonewline or
:: _echo.nonewline is defined.
::
:: One-call config,                  persistent config
::   echo.color                      _echo.color
::   echo.backcolor                  _echo.backcolor
::   echo.nonewline                  _echo.nonewline
::
:: Usage:
::   call :Echo message
::   set "echo.color=91" & call :Echo red message
::   set "echo.nonewline=true" & call :Echo no newline
::
:: Returns: 0
:: Requires: optional :SetESC
:: ============================================================
:Echo
for /f "tokens=1 delims==" %%v in ('set ech_ 2^>nul') do set "%%v="
if defined _ech_rc (set "_ech_rc=" & exit /b %_ech_rc%)
>nul 2>&1 set _echo. && (
    if defined _echo.color set "ech_colorfore=%_echo.color%"
    if defined _echo.backcolor set "ech_colorback=;%_echo.backcolor%"
    if defined _echo.nonewline set "ech_nonewline=%_echo.nonewline%"
)
>nul 2>&1 set echo. && (
    if defined echo.color set "ech_colorfore=%echo.color%"
    if defined echo.backcolor set "ech_colorback=;%echo.backcolor%"
    if defined echo.nonewline set "ech_nonewline=%echo.nonewline%"
    set "echo.color=" & set "echo.backcolor=" & set "echo.nonewline="
)
>nul 2>&1 set ech_color && (
    if not defined app.esc call :SetESC app.esc
    set "ech_startcolor=%app.esc%[%ech_colorfore%%ech_colorback%m"
    set "ech_endcolor=%app.esc%[0m"
)
if defined ech_nonewline ( <nul set /p "=%ech_startcolor%%*%ech_endcolor%" & set "_ech_rc=0" & goto :Echo )
<nul set /p "=%ech_startcolor%%*%ech_endcolor%"
echo.
set "_ech_rc=0" & goto :Echo

:: ============================================================
:: :WriteFast
:: Prints %* without appending a newline.
::
:: Usage:
::   call :WriteFast message
::
:: Returns: 0
:: Requires: none
:: ============================================================
:WriteFast
<nul set /p "=%*"
exit /b 0

:: ============================================================
:: :EchoFast
:: Prints %* with a newline unless echo.nonewline or
:: _echo.nonewline is defined.
::
:: One-call config,                  persistent config
::   echo.nonewline                  _echo.nonewline
::
:: Usage:
::   call :EchoFast message
::   set "echo.nonewline=true" & call :EchoFast no newline
::
:: Returns: 0
:: Requires: none
:: ============================================================
:EchoFast
for /f "tokens=1 delims==" %%v in ('set echf_ 2^>nul') do set "%%v="
if defined _echf_rc (set "_echf_rc=" & exit /b %_echf_rc%)
>nul 2>&1 set _echo. && if defined _echo.nonewline set "echf_nonewline=%_echo.nonewline%"
>nul 2>&1 set echo. && ( if defined echo.nonewline set "echf_nonewline=%echo.nonewline%" & set "echo.nonewline=" )
if defined echf_nonewline ( <nul set /p "=%*" & set "_echf_rc=0" & goto :EchoFast )
<nul set /p "=%*"
echo.
set "_echf_rc=0" & goto :EchoFast

:: ============================================================
:: :EchoFastest
:: Prints %* with a newline.
::
:: Usage:
::   call :EchoFastest message
::
:: Returns: 0
:: Requires: none
:: ============================================================
:EchoFastest
<nul set /p "=%*"
echo.
exit /b 0

:: ============================================================
:: :WriteColor
:: Prints %* without appending a newline, using color config.
:: Assumes app.esc is already set.
::
:: One-call config,                  persistent config
::   write.color                     _write.color
::   write.backcolor                 _write.backcolor
::
:: Usage:
::   set "write.color=31" & call :WriteColor red text
::
:: Returns: 0
:: Requires: app.esc
:: ============================================================
:WriteColor
for /f "tokens=1 delims==" %%v in ('set wc_ 2^>nul') do set "%%v="
if defined _wc_rc (set "_wc_rc=" & exit /b %_wc_rc%)
>nul 2>&1 set _write. && (
    if defined _write.color set "wc_colorfore=%_write.color%"
    if defined _write.backcolor set "wc_colorback=;%_write.backcolor%"
)
>nul 2>&1 set write. && (
    if defined write.color set "wc_colorfore=%write.color%"
    if defined write.backcolor set "wc_colorback=;%write.backcolor%"
    set "write.color=" & set "write.backcolor="
)
<nul set /p "=%app.esc%[%wc_colorfore%%wc_colorback%m%*%app.esc%[0m"
set "_wc_rc=0" & goto :WriteColor

:: ============================================================
:: :EchoColor
:: Prints %* with a newline, using color config.
:: Assumes app.esc is already set.
::
:: One-call config,                  persistent config
::   echo.color                      _echo.color
::   echo.backcolor                  _echo.backcolor
::
:: Usage:
::   set "echo.color=31" & call :EchoColor red text
::
:: Returns: 0
:: Requires: app.esc
:: ============================================================
:EchoColor
for /f "tokens=1 delims==" %%v in ('set ec_ 2^>nul') do set "%%v="
if defined _ec_rc (set "_ec_rc=" & exit /b %_ec_rc%)
>nul 2>&1 set _echo. && (
    if defined _echo.color set "ec_colorfore=%_echo.color%"
    if defined _echo.backcolor set "ec_colorback=;%_echo.backcolor%"
)
>nul 2>&1 set echo. && (
    if defined echo.color set "ec_colorfore=%echo.color%"
    if defined echo.backcolor set "ec_colorback=;%echo.backcolor%"
    set "echo.color=" & set "echo.backcolor="
)
<nul set /p "=%app.esc%[%ec_colorfore%%ec_colorback%m%*%app.esc%[0m"
echo.
set "_ec_rc=0" & goto :EchoColor

:_...GENERIC_CONSOLE_OUTPUT

:_FIXED_COLOR_CONSOLE_OUTPUT

:: ============================================================
:: :WriteRed
:: Prints %* in red without appending a newline.
:: Assumes app.esc is already set.
::
:: Usage: call :WriteRed message
::
:: Returns: 0
:: Requires: app.esc
:: ============================================================
:WriteRed
<nul set /p "=%app.esc%[31m%*%app.esc%[0m"
exit /b 0

:: ============================================================
:: :EchoRed
:: Prints %* in red with a newline.
:: Assumes app.esc is already set.
::
:: Usage: call :EchoRed message
::
:: Returns: 0
:: Requires: app.esc
:: ============================================================
:EchoRed
<nul set /p "=%app.esc%[31m%*%app.esc%[0m"
echo.
exit /b 0

:: ============================================================
:: :WriteGreen
:: Prints %* in green without appending a newline.
:: Suppressed when app.quiet is defined.
:: Assumes app.esc is already set.
::
:: Usage: call :WriteGreen message
::
:: Returns: 0
:: Requires: app.esc
:: ============================================================
:WriteGreen
if defined app.quiet exit /b 0
<nul set /p "=%app.esc%[32m%*%app.esc%[0m"
exit /b 0

:: ============================================================
:: :EchoGreen
:: Prints %* in green with a newline.
:: Suppressed when app.quiet is defined.
:: Assumes app.esc is already set.
::
:: Usage: call :EchoGreen message
::
:: Returns: 0
:: Requires: app.esc
:: ============================================================
:EchoGreen
if defined app.quiet exit /b 0
<nul set /p "=%app.esc%[32m%*%app.esc%[0m"
echo.
exit /b 0

:: ============================================================
:: :WriteYellow
:: Prints %* in yellow without appending a newline.
:: Suppressed when app.quiet is defined.
:: Assumes app.esc is already set.
::
:: Usage: call :WriteYellow message
::
:: Returns: 0
:: Requires: app.esc
:: ============================================================
:WriteYellow
if defined app.quiet exit /b 0
<nul set /p "=%app.esc%[33m%*%app.esc%[0m"
exit /b 0

:: ============================================================
:: :EchoYellow
:: Prints %* in yellow with a newline.
:: Suppressed when app.quiet is defined.
:: Assumes app.esc is already set.
::
:: Usage: call :EchoYellow message
::
:: Returns: 0
:: Requires: app.esc
:: ============================================================
:EchoYellow
if defined app.quiet exit /b 0
<nul set /p "=%app.esc%[33m%*%app.esc%[0m"
echo.
exit /b 0

:: ============================================================
:: :WriteBlue
:: Prints %* in blue without appending a newline.
:: Assumes app.esc is already set.
::
:: Usage: call :WriteBlue message
::
:: Returns: 0
:: Requires: app.esc
:: ============================================================
:WriteBlue
<nul set /p "=%app.esc%[34m%*%app.esc%[0m"
exit /b 0

:: ============================================================
:: :EchoBlue
:: Prints %* in blue with a newline.
:: Assumes app.esc is already set.
::
:: Usage: call :EchoBlue message
::
:: Returns: 0
:: Requires: app.esc
:: ============================================================
:EchoBlue
<nul set /p "=%app.esc%[34m%*%app.esc%[0m"
echo.
exit /b 0

:_...FIXED_COLOR_CONSOLE_OUTPUT