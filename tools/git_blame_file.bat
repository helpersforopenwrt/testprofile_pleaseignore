@echo off
:: ============================================================
:: git_blame_file.bat
:: Shows which commit and author last changed selected file lines.
::
:: Usage:
::   call tools\git_blame_file.bat path README.md
::   call tools\git_blame_file.bat path README.md start 10 end 30
::   call tools\git_blame_file.bat path README.md revision origin/main
::   call tools\git_blame_file.bat path README.md ignorewhitespace yes
::
:: Returns: 0 on success
::          1 on repository, revision, file, or blame failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ValidatePositiveNumber, :RunBlame,
::           :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_blame.path="
set "app.git_blame.gitpath="
set "app.git_blame.revision=HEAD"
set "app.git_blame.start="
set "app.git_blame.end="
set "app.git_blame.ignorewhitespace=no"
set "app.git_blame.help="
set "app.git_blame.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_blame.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_blame.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_blame.rc%
:: ============================================================
:: :Main
:: Parses arguments, validates the repository, revision, file, and
:: optional line range, then runs git blame.
::
:: Usage: call :Main path FILE [revision REV] [start N] [end N] [ignorewhitespace yes|no]
::
:: Returns: 0 on success
::          1 on repository, revision, file, or blame failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ValidatePositiveNumber,
::           :RunBlame, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gbfm_ 2^>nul') do set "%%v="
if defined _gbfm_rc (set "_gbfm_rc=" & exit /b %_gbfm_rc%)
call :ParseArgs %*
if errorlevel 1 (set "_gbfm_rc=%errorlevel%" & goto :Main)
if defined app.git_blame.help goto :_Main_help
call :NormalizeYesNo app.git_blame.ignorewhitespace
if errorlevel 1 (echo ERROR: ignorewhitespace must be yes or no. & set "_gbfm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Git blame
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gbfm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gbfm_rc=1" & goto :Main)
if not defined app.git_blame.path set /p "app.git_blame.path=Repository-relative file path: "
if not defined app.git_blame.path (echo ERROR: A file path is required. & set "_gbfm_rc=1" & goto :Main)
set "app.git_blame.gitpath=%app.git_blame.path:\=/%"
git rev-parse --verify "%app.git_blame.revision%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Revision was not found: & echo   %app.git_blame.revision% & set "_gbfm_rc=1" & goto :Main)
git cat-file -e "%app.git_blame.revision%:%app.git_blame.gitpath%" >nul 2>nul
if errorlevel 1 (echo ERROR: File does not exist at the selected revision: & echo   %app.git_blame.gitpath% & echo. & echo Revision: & echo   %app.git_blame.revision% & set "_gbfm_rc=1" & goto :Main)
if defined app.git_blame.start call :ValidatePositiveNumber "%app.git_blame.start%" start
if errorlevel 1 (set "_gbfm_rc=2" & goto :Main)
if defined app.git_blame.end call :ValidatePositiveNumber "%app.git_blame.end%" end
if errorlevel 1 (set "_gbfm_rc=2" & goto :Main)
if defined app.git_blame.start if not defined app.git_blame.end set "app.git_blame.end=%app.git_blame.start%"
if defined app.git_blame.end if not defined app.git_blame.start (echo ERROR: end requires start. & set "_gbfm_rc=2" & goto :Main)
if not defined app.git_blame.start goto :_Main_show
if %app.git_blame.end% LSS %app.git_blame.start% (echo ERROR: end must be greater than or equal to start. & set "_gbfm_rc=2" & goto :Main)
:_Main_show
echo File:
echo   %app.git_blame.gitpath%
echo.
echo Revision:
echo   %app.git_blame.revision%
echo.
if defined app.git_blame.start echo Line range: %app.git_blame.start% through %app.git_blame.end%
echo Ignore whitespace-only changes:
echo   %app.git_blame.ignorewhitespace%
echo.
call :RunBlame
set "_gbfm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gbfm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :RunBlame
:: Runs git blame with the selected revision, optional line range,
:: and optional whitespace ignoring.
::
:: Usage: call :RunBlame
::
:: Returns: git blame exit code
:: Requires: git
:: ============================================================
:RunBlame
for /f "tokens=1 delims==" %%v in ('set gbfr_ 2^>nul') do set "%%v="
if defined _gbfr_rc (set "_gbfr_rc=" & exit /b %_gbfr_rc%)
if defined app.git_blame.start goto :_RunBlame_range
if /I "%app.git_blame.ignorewhitespace%"=="yes" goto :_RunBlame_whole_ignore
git blame --date=short "%app.git_blame.revision%" -- "%app.git_blame.gitpath%"
goto :_RunBlame_result
:_RunBlame_whole_ignore
git blame -w --date=short "%app.git_blame.revision%" -- "%app.git_blame.gitpath%"
goto :_RunBlame_result
:_RunBlame_range
if /I "%app.git_blame.ignorewhitespace%"=="yes" goto :_RunBlame_range_ignore
git blame -L %app.git_blame.start%,%app.git_blame.end% --date=short "%app.git_blame.revision%" -- "%app.git_blame.gitpath%"
goto :_RunBlame_result
:_RunBlame_range_ignore
git blame -w -L %app.git_blame.start%,%app.git_blame.end% --date=short "%app.git_blame.revision%" -- "%app.git_blame.gitpath%"
:_RunBlame_result
set "_gbfr_rc=%errorlevel%"
if not "%_gbfr_rc%"=="0" echo ERROR: git blame failed.
goto :RunBlame
:: ============================================================
:: :ValidatePositiveNumber
:: Validates a positive integer argument.
::
:: Usage: call :ValidatePositiveNumber "value" argumentName
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:ValidatePositiveNumber
for /f "tokens=1 delims==" %%v in ('set gbfn_ 2^>nul') do set "%%v="
if defined _gbfn_rc (set "_gbfn_rc=" & exit /b %_gbfn_rc%)
set "gbfn_value=%~1"
set "gbfn_name=%~2"
set "gbfn_invalid="
if not defined gbfn_value (echo ERROR: %gbfn_name% requires a positive number. & set "_gbfn_rc=1" & goto :ValidatePositiveNumber)
for /f "delims=0123456789" %%A in ("%gbfn_value%") do set "gbfn_invalid=%%A"
if defined gbfn_invalid (echo ERROR: %gbfn_name% must be a positive number. & set "_gbfn_rc=1" & goto :ValidatePositiveNumber)
if "%gbfn_value%"=="0" (echo ERROR: %gbfn_name% must be 1 or greater. & set "_gbfn_rc=1" & goto :ValidatePositiveNumber)
set "_gbfn_rc=0" & goto :ValidatePositiveNumber
:: ============================================================
:: :ParseArgs
:: Parses path, revision, line range, whitespace, and help options.
::
:: Usage: call :ParseArgs path FILE [revision REV] [start N] [end N] [ignorewhitespace yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="path" goto :_ParseArgs_path
if /I "%~1"=="file" goto :_ParseArgs_path
if /I "%~1"=="revision" goto :_ParseArgs_revision
if /I "%~1"=="rev" goto :_ParseArgs_revision
if /I "%~1"=="start" goto :_ParseArgs_start
if /I "%~1"=="end" goto :_ParseArgs_end
if /I "%~1"=="ignorewhitespace" goto :_ParseArgs_whitespace
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_blame.path (set "app.git_blame.path=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_path
if "%~2"=="" (echo ERROR: path requires a file. & exit /b 2)
set "app.git_blame.path=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_revision
if "%~2"=="" (echo ERROR: revision requires a commit, tag, or branch. & exit /b 2)
set "app.git_blame.revision=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_start
if "%~2"=="" (echo ERROR: start requires a line number. & exit /b 2)
set "app.git_blame.start=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_end
if "%~2"=="" (echo ERROR: end requires a line number. & exit /b 2)
set "app.git_blame.end=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_whitespace
if "%~2"=="" (echo ERROR: ignorewhitespace requires yes or no. & exit /b 2)
set "app.git_blame.ignorewhitespace=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_blame.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gbfy_ 2^>nul') do set "%%v="
if defined _gbfy_rc (set "_gbfy_rc=" & exit /b %_gbfy_rc%)
set "gbfy_name=%~1"
call set "gbfy_value=%%%gbfy_name%%%"
if /I "%gbfy_value%"=="y" set "%gbfy_name%=yes"
if /I "%gbfy_value%"=="yes" set "%gbfy_name%=yes"
if /I "%gbfy_value%"=="true" set "%gbfy_name%=yes"
if /I "%gbfy_value%"=="1" set "%gbfy_name%=yes"
if /I "%gbfy_value%"=="n" set "%gbfy_name%=no"
if /I "%gbfy_value%"=="no" set "%gbfy_name%=no"
if /I "%gbfy_value%"=="false" set "%gbfy_name%=no"
if /I "%gbfy_value%"=="0" set "%gbfy_name%=no"
call set "gbfy_value=%%%gbfy_name%%%"
if /I "%gbfy_value%"=="yes" (set "_gbfy_rc=0" & goto :NormalizeYesNo)
if /I "%gbfy_value%"=="no" (set "_gbfy_rc=0" & goto :NormalizeYesNo)
set "_gbfy_rc=1" & goto :NormalizeYesNo
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
echo git_blame_file.bat
echo.
echo Usage:
echo   git_blame_file.bat path README.md
echo   git_blame_file.bat path README.md start 10 end 30
echo   git_blame_file.bat path README.md revision origin/main
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
