@echo off
:: ============================================================
:: git_archive_source.bat
:: Creates a clean ZIP archive from committed Git content.
::
:: Usage:
::   call tools\git_archive_source.bat
::   call tools\git_archive_source.bat revision v1.0.0
::   call tools\git_archive_source.bat output releases\source.zip
::   call tools\git_archive_source.bat prefix project-1.0\ overwrite yes
::
:: Returns: 0 on success or cancellation
::          1 on repository, path, or archive failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :PrepareArchive, :CreateArchive,
::           :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_archive.revision=HEAD"
set "app.git_archive.output="
set "app.git_archive.output.full="
set "app.git_archive.output.dir="
set "app.git_archive.prefix="
set "app.git_archive.repo.name="
set "app.git_archive.short="
set "app.git_archive.overwrite=no"
set "app.git_archive.confirm="
set "app.git_archive.help="
set "app.git_archive.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_archive.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_archive.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_archive.rc%
:: ============================================================
:: :Main
:: Parses options, validates the repository and archive plan,
:: confirms replacement, and creates the ZIP archive.
::
:: Usage: call :Main [revision REV] [output FILE] [prefix FOLDER] [overwrite yes|no]
::
:: Returns: 0 on success or cancellation
::          1 on repository, path, or archive failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :PrepareArchive,
::           :CreateArchive, :ShowHelp
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gasm_ 2^>nul') do set "%%v="
if defined _gasm_rc (set "_gasm_rc=" & exit /b %_gasm_rc%)
call :ParseArgs %*
if errorlevel 1 (set "_gasm_rc=%errorlevel%" & goto :Main)
if defined app.git_archive.help goto :_Main_help
call :NormalizeYesNo app.git_archive.overwrite
if errorlevel 1 (echo ERROR: overwrite must be yes or no. & set "_gasm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Create source archive
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gasm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gasm_rc=1" & goto :Main)
call :PrepareArchive
if errorlevel 1 (set "_gasm_rc=%errorlevel%" & goto :Main)
if not exist "%app.git_archive.output.full%" goto :_Main_create
if /I not "%app.git_archive.overwrite%"=="yes" (echo ERROR: Output file already exists: & echo   %app.git_archive.output.full% & echo. & echo Use overwrite yes to replace it. & set "_gasm_rc=1" & goto :Main)
set /p "app.git_archive.confirm=Type ARCHIVE to replace the existing file: "
if "%app.git_archive.confirm%"=="ARCHIVE" goto :_Main_create
echo.
echo Cancelled. Nothing was changed.
set "_gasm_rc=0" & goto :Main
:_Main_create
call :CreateArchive
set "_gasm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gasm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :PrepareArchive
:: Validates the revision and resolves the output path and archive
:: prefix.
::
:: Usage: call :PrepareArchive
::
:: Output:
::   app.git_archive.output.full  absolute ZIP path
::   app.git_archive.output.dir   destination folder
::   app.git_archive.prefix       slash-normalized archive prefix
::
:: Returns: 0 on success
::          1 on invalid revision or unresolved metadata
:: Requires: git
:: ============================================================
:PrepareArchive
for /f "tokens=1 delims==" %%v in ('set gasp_ 2^>nul') do set "%%v="
if defined _gasp_rc (set "_gasp_rc=" & exit /b %_gasp_rc%)
git rev-parse --verify "%app.git_archive.revision%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Revision was not found: & echo   %app.git_archive.revision% & set "_gasp_rc=1" & goto :PrepareArchive)
for %%A in ("%CD%") do set "app.git_archive.repo.name=%%~nxA"
for /f "delims=" %%A in ('git rev-parse --short=12 "%app.git_archive.revision%" 2^>nul') do set "app.git_archive.short=%%A"
if not defined app.git_archive.repo.name (echo ERROR: Repository name could not be determined. & set "_gasp_rc=1" & goto :PrepareArchive)
if not defined app.git_archive.short (echo ERROR: Revision hash could not be determined. & set "_gasp_rc=1" & goto :PrepareArchive)
if not defined app.git_archive.output set "app.git_archive.output=archives\%app.git_archive.repo.name%-%app.git_archive.short%.zip"
for %%A in ("%app.git_archive.output%") do set "app.git_archive.output.full=%%~fA"
for %%A in ("%app.git_archive.output.full%") do set "app.git_archive.output.dir=%%~dpA"
if not defined app.git_archive.prefix set "app.git_archive.prefix=%app.git_archive.repo.name%\"
if not "%app.git_archive.prefix:~-1%"=="\" set "app.git_archive.prefix=%app.git_archive.prefix%\"
set "app.git_archive.prefix=%app.git_archive.prefix:\=/%"
echo Revision:
echo   %app.git_archive.revision%
echo.
echo Commit:
git log -1 --oneline "%app.git_archive.revision%"
echo.
echo Output:
echo   %app.git_archive.output.full%
echo.
echo Prefix inside archive:
echo   %app.git_archive.prefix%
echo.
echo Overwrite existing file:
echo   %app.git_archive.overwrite%
echo.
set "_gasp_rc=0" & goto :PrepareArchive
:: ============================================================
:: :CreateArchive
:: Creates the destination folder and writes the ZIP with
:: git archive.
::
:: Usage: call :CreateArchive
::
:: Returns: 0 on success
::          1 on folder or archive failure
:: Requires: git
:: ============================================================
:CreateArchive
for /f "tokens=1 delims==" %%v in ('set gasc_ 2^>nul') do set "%%v="
if defined _gasc_rc (set "_gasc_rc=" & exit /b %_gasc_rc%)
if exist "%app.git_archive.output.dir%\" goto :_CreateArchive_git
mkdir "%app.git_archive.output.dir%" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not create the output folder: & echo   %app.git_archive.output.dir% & set "_gasc_rc=1" & goto :CreateArchive)
:_CreateArchive_git
git archive --format=zip --output="%app.git_archive.output.full%" --prefix="%app.git_archive.prefix%" "%app.git_archive.revision%"
if errorlevel 1 (echo ERROR: Git archive creation failed. & set "_gasc_rc=1" & goto :CreateArchive)
echo.
echo Source archive created:
echo   %app.git_archive.output.full%
echo.
for %%A in ("%app.git_archive.output.full%") do echo Size: %%~zA bytes
set "_gasc_rc=0" & goto :CreateArchive
:: ============================================================
:: :ParseArgs
:: Parses revision, output, prefix, overwrite, and help arguments.
::
:: Usage: call :ParseArgs [revision REV] [output FILE] [prefix FOLDER] [overwrite yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="revision" goto :_ParseArgs_revision
if /I "%~1"=="rev" goto :_ParseArgs_revision
if /I "%~1"=="output" goto :_ParseArgs_output
if /I "%~1"=="prefix" goto :_ParseArgs_prefix
if /I "%~1"=="overwrite" goto :_ParseArgs_overwrite
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_revision
if "%~2"=="" (echo ERROR: revision requires a commit, tag, or branch. & exit /b 2)
set "app.git_archive.revision=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_output
if "%~2"=="" (echo ERROR: output requires a ZIP path. & exit /b 2)
set "app.git_archive.output=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_prefix
if "%~2"=="" (echo ERROR: prefix requires a folder name. & exit /b 2)
set "app.git_archive.prefix=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_overwrite
if "%~2"=="" (echo ERROR: overwrite requires yes or no. & exit /b 2)
set "app.git_archive.overwrite=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_archive.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeYesNo
:: Normalizes a named variable to yes or no.
::
:: Usage: call :NormalizeYesNo variableName
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:NormalizeYesNo
for /f "tokens=1 delims==" %%v in ('set gasn_ 2^>nul') do set "%%v="
if defined _gasn_rc (set "_gasn_rc=" & exit /b %_gasn_rc%)
set "gasn_name=%~1"
call set "gasn_value=%%%gasn_name%%%"
if /I "%gasn_value%"=="y" set "%gasn_name%=yes"
if /I "%gasn_value%"=="yes" set "%gasn_name%=yes"
if /I "%gasn_value%"=="true" set "%gasn_name%=yes"
if /I "%gasn_value%"=="1" set "%gasn_name%=yes"
if /I "%gasn_value%"=="n" set "%gasn_name%=no"
if /I "%gasn_value%"=="no" set "%gasn_name%=no"
if /I "%gasn_value%"=="false" set "%gasn_name%=no"
if /I "%gasn_value%"=="0" set "%gasn_name%=no"
call set "gasn_value=%%%gasn_name%%%"
if /I "%gasn_value%"=="yes" (set "_gasn_rc=0" & goto :NormalizeYesNo)
if /I "%gasn_value%"=="no" (set "_gasn_rc=0" & goto :NormalizeYesNo)
set "_gasn_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays command usage.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_archive_source.bat
echo.
echo Usage:
echo   git_archive_source.bat
echo   git_archive_source.bat revision v1.0.0
echo   git_archive_source.bat output releases\source.zip
echo   git_archive_source.bat prefix project-1.0\ overwrite yes
echo.
exit /b 0
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
