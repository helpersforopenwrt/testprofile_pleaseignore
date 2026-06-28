@echo off
:: ============================================================
:: git_generate_changelog.bat
:: Generates a Markdown changelog between two commit revisions and
:: displays it or writes it through a temporary file.
::
:: Usage:
::   call tools\git_generate_changelog.bat from v1.0.0 to v1.1.0
::   call tools\git_generate_changelog.bat from v1.0.0 to HEAD output CHANGELOG.md
::   call tools\git_generate_changelog.bat from v1.0.0 to v1.1.0 merges yes
::
:: Returns: 0 on successful display, file creation, cancellation, or help
::          1 on dependency, repository, revision, path, or Git failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ValidatePlan,
::           :WriteConsole, :WriteFile, :CleanupTemp, :ParseArgs,
::           :NormalizeYesNo, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_changelog.from="
set "app.git_changelog.to=HEAD"
set "app.git_changelog.output="
set "app.git_changelog.output.full="
set "app.git_changelog.output.dir="
set "app.git_changelog.temp="
set "app.git_changelog.merges=no"
set "app.git_changelog.overwrite=no"
set "app.git_changelog.log.option=--no-merges"
set "app.git_changelog.confirm="
set "app.git_changelog.help="
set "app.git_changelog.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_changelog.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_changelog.rc=%errorlevel%"
:end
call :CleanupTemp
call :PauseIfNeeded
exit /b %app.git_changelog.rc%
:: ============================================================
:: :Main
:: Parses options, prepares Git, validates the revision range and
:: output plan, and displays or writes the changelog.
::
:: Usage: call :Main from REV [to REV] [output FILE] [merges yes|no] [overwrite yes|no]
::
:: Returns: 0 on successful display, file creation, cancellation, or help
::          1 on dependency, repository, revision, path, or Git failure
::          2 on invalid arguments
:: Requires: :ValidatePlan, :WriteConsole, :WriteFile, :ParseArgs,
::           :NormalizeYesNo, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set ggcm_ 2^>nul') do set "%%v="
if defined _ggcm_rc (set "_ggcm_rc=" & exit /b %_ggcm_rc%)
call :ParseArgs %*
set "_ggcm_rc=%errorlevel%"
if not "%_ggcm_rc%"=="0" goto :Main
if defined app.git_changelog.help goto :_Main_help
call :NormalizeYesNo app.git_changelog.merges
if errorlevel 1 (echo ERROR: merges must be yes or no. & set "_ggcm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_changelog.overwrite
if errorlevel 1 (echo ERROR: overwrite must be yes or no. & set "_ggcm_rc=2" & goto :Main)
if /I "%app.git_changelog.merges%"=="yes" set "app.git_changelog.log.option="
echo.
echo ============================================================
echo  Generate changelog
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_ggcm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_ggcm_rc=1" & goto :Main)
if not defined app.git_changelog.from set /p "app.git_changelog.from=Older revision or tag: "
call :ValidatePlan
if errorlevel 1 (set "_ggcm_rc=%errorlevel%" & goto :Main)
echo From:
echo   %app.git_changelog.from%
echo.
echo To:
echo   %app.git_changelog.to%
echo.
echo Include merge commits:
echo   %app.git_changelog.merges%
echo.
if defined app.git_changelog.output goto :_Main_file
call :WriteConsole
set "_ggcm_rc=%errorlevel%" & goto :Main
:_Main_file
call :WriteFile
set "_ggcm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_ggcm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ValidatePlan
:: Validates both commit revisions, reports non-ancestor ranges, and
:: resolves and checks an optional output path.
::
:: Usage: call :ValidatePlan
::
:: Returns: 0 when the plan is valid
::          1 when a revision or output path is invalid
:: Requires: git
:: ============================================================
:ValidatePlan
for /f "tokens=1 delims==" %%v in ('set ggcv_ 2^>nul') do set "%%v="
if defined _ggcv_rc (set "_ggcv_rc=" & exit /b %_ggcv_rc%)
if not defined app.git_changelog.from (echo ERROR: The older revision is required. & set "_ggcv_rc=1" & goto :ValidatePlan)
git rev-parse --verify "%app.git_changelog.from%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Older revision was not found: & echo   %app.git_changelog.from% & set "_ggcv_rc=1" & goto :ValidatePlan)
git rev-parse --verify "%app.git_changelog.to%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Newer revision was not found: & echo   %app.git_changelog.to% & set "_ggcv_rc=1" & goto :ValidatePlan)
git merge-base --is-ancestor "%app.git_changelog.from%" "%app.git_changelog.to%" >nul 2>nul
if not errorlevel 1 goto :_ValidatePlan_output
echo WARNING: The older revision is not an ancestor of the newer one.
echo The changelog will still use:
echo   %app.git_changelog.from%..%app.git_changelog.to%
echo.
:_ValidatePlan_output
if not defined app.git_changelog.output (set "_ggcv_rc=0" & goto :ValidatePlan)
for %%A in ("%app.git_changelog.output%") do (
set "app.git_changelog.output.full=%%~fA"
set "app.git_changelog.output.dir=%%~dpA"
)
if exist "%app.git_changelog.output.full%\" (echo ERROR: Output path is a directory: & echo   %app.git_changelog.output.full% & set "_ggcv_rc=1" & goto :ValidatePlan)
if exist "%app.git_changelog.output.full%" if /I not "%app.git_changelog.overwrite%"=="yes" goto :_ValidatePlan_exists
set "_ggcv_rc=0" & goto :ValidatePlan
:_ValidatePlan_exists
echo ERROR: Output file already exists:
echo   %app.git_changelog.output.full%
echo.
echo Use overwrite yes to replace it.
set "_ggcv_rc=1" & goto :ValidatePlan
:: ============================================================
:: :WriteConsole
:: Writes the selected commit range to the console.
::
:: Usage: call :WriteConsole
::
:: Returns: 0 on success
::          1 when git log fails
:: Requires: git
:: ============================================================
:WriteConsole
for /f "tokens=1 delims==" %%v in ('set ggcc_ 2^>nul') do set "%%v="
if defined _ggcc_rc (set "_ggcc_rc=" & exit /b %_ggcc_rc%)
echo ============================================================
echo  Changelog
echo ============================================================
echo.
git log "%app.git_changelog.from%..%app.git_changelog.to%" %app.git_changelog.log.option% --date=short --pretty=format:"- %%s (%%h, %%ad, %%an)"
set "ggcc_git_rc=%errorlevel%"
echo.
if not "%ggcc_git_rc%"=="0" (echo ERROR: Changelog generation failed. & set "_ggcc_rc=1" & goto :WriteConsole)
set "_ggcc_rc=0" & goto :WriteConsole
:: ============================================================
:: :WriteFile
:: Builds the changelog in a temporary sibling file and moves it to
:: the final path only after git log succeeds.
::
:: Usage: call :WriteFile
::
:: Returns: 0 on success or replacement cancellation
::          1 on directory, Git, write, or move failure
:: Requires: git, move
:: ============================================================
:WriteFile
for /f "tokens=1 delims==" %%v in ('set ggcf_ 2^>nul') do set "%%v="
if defined _ggcf_rc (set "_ggcf_rc=" & exit /b %_ggcf_rc%)
echo Output:
echo   %app.git_changelog.output.full%
echo.
if not exist "%app.git_changelog.output.full%" goto :_WriteFile_directory
set /p "app.git_changelog.confirm=Type CHANGELOG to replace the existing file: "
if "%app.git_changelog.confirm%"=="CHANGELOG" goto :_WriteFile_directory
echo.
echo Cancelled. Nothing was changed.
set "_ggcf_rc=0" & goto :WriteFile
:_WriteFile_directory
if exist "%app.git_changelog.output.dir%\" goto :_WriteFile_temp
mkdir "%app.git_changelog.output.dir%" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not create the output folder. & set "_ggcf_rc=1" & goto :WriteFile)
:_WriteFile_temp
set "app.git_changelog.temp=%app.git_changelog.output.full%.tmp-%RANDOM%-%RANDOM%"
> "%app.git_changelog.temp%" echo # Changelog
if errorlevel 1 (echo ERROR: Could not create the temporary changelog. & set "_ggcf_rc=1" & goto :WriteFile)
>>"%app.git_changelog.temp%" echo.
>>"%app.git_changelog.temp%" echo From `%app.git_changelog.from%` to `%app.git_changelog.to%`
>>"%app.git_changelog.temp%" echo.
git log "%app.git_changelog.from%..%app.git_changelog.to%" %app.git_changelog.log.option% --date=short --pretty=format:"- %%s (`%%h`, %%ad, %%an)" >>"%app.git_changelog.temp%"
set "ggcf_git_rc=%errorlevel%"
>>"%app.git_changelog.temp%" echo.
if not "%ggcf_git_rc%"=="0" (echo ERROR: Changelog generation failed. & set "_ggcf_rc=1" & goto :WriteFile)
move /y "%app.git_changelog.temp%" "%app.git_changelog.output.full%" >nul
if errorlevel 1 (echo ERROR: Could not move the completed changelog into place. & set "_ggcf_rc=1" & goto :WriteFile)
set "app.git_changelog.temp="
echo Changelog created:
echo   %app.git_changelog.output.full%
set "_ggcf_rc=0" & goto :WriteFile
:: ============================================================
:: :CleanupTemp
:: Deletes an incomplete temporary changelog, when present.
::
:: Usage: call :CleanupTemp
::
:: Returns: 0
:: Requires: del
:: ============================================================
:CleanupTemp
if defined app.git_changelog.temp del /q "%app.git_changelog.temp%" >nul 2>nul
set "app.git_changelog.temp="
exit /b 0
:: ============================================================
:: :ParseArgs
:: Parses revision, output, merge, overwrite, and help arguments.
::
:: Usage: call :ParseArgs from REV [to REV] [output FILE] [merges yes|no] [overwrite yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="from" goto :_ParseArgs_from
if /I "%~1"=="to" goto :_ParseArgs_to
if /I "%~1"=="output" goto :_ParseArgs_output
if /I "%~1"=="merges" goto :_ParseArgs_merges
if /I "%~1"=="overwrite" goto :_ParseArgs_overwrite
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_from
if "%~2"=="" (echo ERROR: from requires a revision. & exit /b 2)
set "app.git_changelog.from=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_to
if "%~2"=="" (echo ERROR: to requires a revision. & exit /b 2)
set "app.git_changelog.to=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_output
if "%~2"=="" (echo ERROR: output requires a file path. & exit /b 2)
set "app.git_changelog.output=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_merges
if "%~2"=="" (echo ERROR: merges requires yes or no. & exit /b 2)
set "app.git_changelog.merges=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_overwrite
if "%~2"=="" (echo ERROR: overwrite requires yes or no. & exit /b 2)
set "app.git_changelog.overwrite=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_changelog.help=1"
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
for /f "tokens=1 delims==" %%v in ('set ggcy_ 2^>nul') do set "%%v="
if defined _ggcy_rc (set "_ggcy_rc=" & exit /b %_ggcy_rc%)
set "ggcy_name=%~1"
call set "ggcy_value=%%%ggcy_name%%%"
if /I "%ggcy_value%"=="y" set "%ggcy_name%=yes"
if /I "%ggcy_value%"=="yes" set "%ggcy_name%=yes"
if /I "%ggcy_value%"=="true" set "%ggcy_name%=yes"
if /I "%ggcy_value%"=="1" set "%ggcy_name%=yes"
if /I "%ggcy_value%"=="n" set "%ggcy_name%=no"
if /I "%ggcy_value%"=="no" set "%ggcy_name%=no"
if /I "%ggcy_value%"=="false" set "%ggcy_name%=no"
if /I "%ggcy_value%"=="0" set "%ggcy_name%=no"
call set "ggcy_value=%%%ggcy_name%%%"
if /I "%ggcy_value%"=="yes" (set "_ggcy_rc=0" & goto :NormalizeYesNo)
if /I "%ggcy_value%"=="no" (set "_ggcy_rc=0" & goto :NormalizeYesNo)
set "_ggcy_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays changelog usage and output behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_generate_changelog.bat
echo.
echo Usage:
echo   git_generate_changelog.bat from v1.0.0 to v1.1.0
echo   git_generate_changelog.bat from v1.0.0 to HEAD output CHANGELOG.md
echo   git_generate_changelog.bat from v1.0.0 to v1.1.0 merges yes
echo.
echo Existing output files require overwrite yes and CHANGELOG confirmation.
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
