@echo off
:: ============================================================
:: git_compare_branches.bat
:: Compares two branches, tags, or commits without changing them.
:: Optional fetch updates remote references first.
::
:: Usage:
::   call tools\git_compare_branches.bat
::   call tools\git_compare_branches.bat main feature/test
::   call tools\git_compare_branches.bat left origin/main right HEAD fetch no
::
:: Returns: 0 on successful comparison
::          1 on repository, revision, or comparison failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeYesNo, :ResolveRevisions, :RunComparison,
::           :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_compare.left="
set "app.git_compare.right="
set "app.git_compare.fetch=yes"
set "app.git_compare.current="
set "app.git_compare.leftonly="
set "app.git_compare.rightonly="
set "app.git_compare.help="
set "app.git_compare.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_compare.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_compare.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_compare.rc%
:: ============================================================
:: :Main
:: Parses options, prepares Git, optionally fetches remotes,
:: resolves both revisions, validates them, and displays comparison.
::
:: Usage: call :Main [left REV] [right REV] [fetch yes|no]
::
:: Returns: 0 on successful comparison
::          1 on repository, revision, or comparison failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo, :ResolveRevisions,
::           :RunComparison, :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcbm_ 2^>nul') do set "%%v="
if defined _gcbm_rc (set "_gcbm_rc=" & exit /b %_gcbm_rc%)
call :ParseArgs %*
set "_gcbm_rc=%errorlevel%"
if not "%_gcbm_rc%"=="0" goto :Main
if defined app.git_compare.help goto :_Main_help
call :NormalizeYesNo app.git_compare.fetch
if errorlevel 1 (echo ERROR: fetch must be yes or no. & set "_gcbm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Compare Git branches or revisions
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gcbm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gcbm_rc=1" & goto :Main)
if /I "%app.git_compare.fetch%"=="yes" goto :_Main_fetch
goto :_Main_resolve
:_Main_fetch
echo Fetching remote references...
git fetch --all --prune --quiet
if errorlevel 1 echo WARNING: One or more remotes could not be fetched.
echo.
:_Main_resolve
call :ResolveRevisions
if errorlevel 1 (set "_gcbm_rc=%errorlevel%" & goto :Main)
call :RunComparison
set "_gcbm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gcbm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ResolveRevisions
:: Selects defaults and validates both comparison revisions.
::
:: Usage: call :ResolveRevisions
::
:: Output:
::   app.git_compare.left   validated left revision
::   app.git_compare.right  validated right revision
::
:: Returns: 0 on success
::          1 when revisions are identical or unavailable
:: Requires: git
:: ============================================================
:ResolveRevisions
for /f "tokens=1 delims==" %%v in ('set gcbr_ 2^>nul') do set "%%v="
if defined _gcbr_rc (set "_gcbr_rc=" & exit /b %_gcbr_rc%)
set "app.git_compare.current="
for /f "delims=" %%A in ('git branch --show-current 2^>nul') do set "app.git_compare.current=%%A"
if defined app.git_compare.left goto :_ResolveRevisions_right
if defined CFG_BRANCH set "app.git_compare.left=%CFG_BRANCH%"
if not defined app.git_compare.left set "app.git_compare.left=main"
:_ResolveRevisions_right
if defined app.git_compare.right goto :_ResolveRevisions_compare
if defined app.git_compare.current set "app.git_compare.right=%app.git_compare.current%"
if not defined app.git_compare.right set "app.git_compare.right=HEAD"
:_ResolveRevisions_compare
if /I "%app.git_compare.left%"=="%app.git_compare.right%" (echo ERROR: left and right are the same revision: & echo   %app.git_compare.left% & set "_gcbr_rc=1" & goto :ResolveRevisions)
git rev-parse --verify "%app.git_compare.left%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Left revision was not found: & echo   %app.git_compare.left% & set "_gcbr_rc=1" & goto :ResolveRevisions)
git rev-parse --verify "%app.git_compare.right%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Right revision was not found: & echo   %app.git_compare.right% & set "_gcbr_rc=1" & goto :ResolveRevisions)
set "_gcbr_rc=0" & goto :ResolveRevisions
:: ============================================================
:: :RunComparison
:: Displays unique commit counts, unique commits, merge-base-to-right
:: changes, and the direct tree difference.
::
:: Usage: call :RunComparison
::
:: Returns: 0 on success
::          1 when Git comparison commands fail
:: Requires: git
:: ============================================================
:RunComparison
for /f "tokens=1 delims==" %%v in ('set gcbc_ 2^>nul') do set "%%v="
if defined _gcbc_rc (set "_gcbc_rc=" & exit /b %_gcbc_rc%)
set "app.git_compare.leftonly="
set "app.git_compare.rightonly="
for /f "tokens=1,2" %%A in ('git rev-list --left-right --count "%app.git_compare.left%...%app.git_compare.right%" 2^>nul') do (
set "app.git_compare.leftonly=%%A"
set "app.git_compare.rightonly=%%B"
)
if not defined app.git_compare.leftonly (echo ERROR: Commit counts could not be calculated. & set "_gcbc_rc=1" & goto :RunComparison)
echo Left:
echo   %app.git_compare.left%
echo.
echo Right:
echo   %app.git_compare.right%
echo.
echo Commits only on left:
echo   %app.git_compare.leftonly%
echo.
echo Commits only on right:
echo   %app.git_compare.rightonly%
echo.
echo ============================================================
echo  Unique commits
echo ============================================================
echo.
git log --left-right --graph --decorate --oneline "%app.git_compare.left%...%app.git_compare.right%"
if errorlevel 1 (echo ERROR: Unique commit comparison failed. & set "_gcbc_rc=1" & goto :RunComparison)
echo.
echo ============================================================
echo  Files changed from merge base to right
echo ============================================================
echo.
git diff --stat "%app.git_compare.left%...%app.git_compare.right%"
if errorlevel 1 (echo ERROR: Merge-base diff summary failed. & set "_gcbc_rc=1" & goto :RunComparison)
echo.
git diff --name-status "%app.git_compare.left%...%app.git_compare.right%"
if errorlevel 1 (echo ERROR: Merge-base file comparison failed. & set "_gcbc_rc=1" & goto :RunComparison)
echo.
echo ============================================================
echo  Direct tree difference: left to right
echo ============================================================
echo.
git diff --stat "%app.git_compare.left%..%app.git_compare.right%"
if errorlevel 1 (echo ERROR: Direct tree comparison failed. & set "_gcbc_rc=1" & goto :RunComparison)
echo.
set "_gcbc_rc=0" & goto :RunComparison
:: ============================================================
:: :ParseArgs
:: Parses left, right, fetch, and help arguments.
::
:: Usage: call :ParseArgs [left REV] [right REV] [fetch yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="left" goto :_ParseArgs_left
if /I "%~1"=="right" goto :_ParseArgs_right
if /I "%~1"=="fetch" goto :_ParseArgs_fetch
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_compare.left (set "app.git_compare.left=%~1" & shift & goto :ParseArgs)
if not defined app.git_compare.right (set "app.git_compare.right=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_left
if "%~2"=="" (echo ERROR: left requires a revision. & exit /b 2)
set "app.git_compare.left=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_right
if "%~2"=="" (echo ERROR: right requires a revision. & exit /b 2)
set "app.git_compare.right=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_fetch
if "%~2"=="" (echo ERROR: fetch requires yes or no. & exit /b 2)
set "app.git_compare.fetch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_compare.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gcby_ 2^>nul') do set "%%v="
if defined _gcby_rc (set "_gcby_rc=" & exit /b %_gcby_rc%)
set "gcby_name=%~1"
call set "gcby_value=%%%gcby_name%%%"
if /I "%gcby_value%"=="y" set "%gcby_name%=yes"
if /I "%gcby_value%"=="yes" set "%gcby_name%=yes"
if /I "%gcby_value%"=="true" set "%gcby_name%=yes"
if /I "%gcby_value%"=="1" set "%gcby_name%=yes"
if /I "%gcby_value%"=="n" set "%gcby_name%=no"
if /I "%gcby_value%"=="no" set "%gcby_name%=no"
if /I "%gcby_value%"=="false" set "%gcby_name%=no"
if /I "%gcby_value%"=="0" set "%gcby_name%=no"
call set "gcby_value=%%%gcby_name%%%"
if /I "%gcby_value%"=="yes" (set "_gcby_rc=0" & goto :NormalizeYesNo)
if /I "%gcby_value%"=="no" (set "_gcby_rc=0" & goto :NormalizeYesNo)
set "_gcby_rc=1" & goto :NormalizeYesNo
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
echo git_compare_branches.bat
echo.
echo Usage:
echo   git_compare_branches.bat
echo   git_compare_branches.bat main feature/test
echo   git_compare_branches.bat left origin/main right HEAD fetch no
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
