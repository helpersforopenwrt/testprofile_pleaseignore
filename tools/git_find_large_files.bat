@echo off
:: ============================================================
:: git_find_large_files.bat
:: Reports the largest files tracked at HEAD and largest blobs in
:: Git history using temporary local Git output files.
::
:: Usage:
::   call tools\git_find_large_files.bat
::   call tools\git_find_large_files.bat mode tracked
::   call tools\git_find_large_files.bat mode history limit 30
::   call tools\git_find_large_files.bat mode both minimumbytes 1048576
::
:: Returns: 0 on successful analysis
::          1 on dependency, repository, Git, or formatting failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, PowerShell, :Main,
::           :ParseArgs, :NormalizeMode, :ValidateNumber,
::           :RunTrackedAnalysis, :RunHistoryAnalysis,
::           :CleanupTemp, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_large.mode=both"
set "app.git_large.limit=20"
set "app.git_large.minimumbytes=0"
set "app.git_large.temp.tracked="
set "app.git_large.temp.objects="
set "app.git_large.temp.blobs="
set "app.git_large.help="
set "app.git_large.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_large.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_large.rc=%errorlevel%"
:end
call :CleanupTemp
call :PauseIfNeeded
exit /b %app.git_large.rc%
:: ============================================================
:: :Main
:: Parses and validates options, prepares dependencies, verifies a
:: committed worktree, and runs the selected analyses.
::
:: Usage: call :Main [mode tracked|history|both] [limit N] [minimumbytes N]
::
:: Returns: 0 on successful analysis
::          1 on dependency, repository, Git, or formatting failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeMode, :ValidateNumber,
::           :RunTrackedAnalysis, :RunHistoryAnalysis, :ShowHelp,
::           prepare.bat, git, PowerShell
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gflm_ 2^>nul') do set "%%v="
if defined _gflm_rc (set "_gflm_rc=" & exit /b %_gflm_rc%)
call :ParseArgs %*
set "_gflm_rc=%errorlevel%"
if not "%_gflm_rc%"=="0" goto :Main
if defined app.git_large.help goto :_Main_help
call :NormalizeMode
if errorlevel 1 (set "_gflm_rc=2" & goto :Main)
call :ValidateNumber "%app.git_large.limit%" limit
if errorlevel 1 (set "_gflm_rc=2" & goto :Main)
call :ValidateNumber "%app.git_large.minimumbytes%" minimumbytes
if errorlevel 1 (set "_gflm_rc=2" & goto :Main)
if "%app.git_large.limit%"=="0" (echo ERROR: limit must be 1 or greater. & set "_gflm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Find large Git files
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
echo Mode:
echo   %app.git_large.mode%
echo.
echo Rows per section:
echo   %app.git_large.limit%
echo.
echo Minimum bytes:
echo   %app.git_large.minimumbytes%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gflm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gflm_rc=1" & goto :Main)
where powershell.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Windows PowerShell was not found. & set "_gflm_rc=1" & goto :Main)
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: The repository has no commits. & set "_gflm_rc=1" & goto :Main)
if "%app.git_large.mode%"=="history" goto :_Main_history
call :RunTrackedAnalysis
if errorlevel 1 (set "_gflm_rc=%errorlevel%" & goto :Main)
if "%app.git_large.mode%"=="tracked" goto :_Main_notes
:_Main_history
call :RunHistoryAnalysis
if errorlevel 1 (set "_gflm_rc=%errorlevel%" & goto :Main)
:_Main_notes
echo Notes:
echo   Historical blobs remain in repository history even after a file
echo   is deleted from the current branch.
echo.
echo   Rewriting history to remove large blobs is destructive and is
echo   intentionally outside this helper.
echo.
set "_gflm_rc=0" & goto :Main
:_Main_help
call :ShowHelp
set "_gflm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :RunTrackedAnalysis
:: Captures git ls-tree output, checks Git's result, and uses
:: PowerShell to filter, sort, and format tracked files.
::
:: Usage: call :RunTrackedAnalysis
::
:: Returns: 0 on success
::          1 on Git or PowerShell failure
:: Requires: git, PowerShell
:: ============================================================
:RunTrackedAnalysis
for /f "tokens=1 delims==" %%v in ('set gflt_ 2^>nul') do set "%%v="
if defined _gflt_rc (set "_gflt_rc=" & exit /b %_gflt_rc%)
set "app.git_large.temp.tracked=%TEMP%\git-large-tracked-%RANDOM%-%RANDOM%.txt"
git ls-tree -r -l HEAD >"%app.git_large.temp.tracked%" 2>nul
if errorlevel 1 (echo ERROR: Could not read files tracked at HEAD. & set "_gflt_rc=1" & goto :RunTrackedAnalysis)
echo ============================================================
echo  Largest files tracked at HEAD
echo ============================================================
echo.
set "GFL_INPUT=%app.git_large.temp.tracked%"
set "GFL_MINIMUM=%app.git_large.minimumbytes%"
set "GFL_LIMIT=%app.git_large.limit%"
powershell.exe -NoProfile -Command "$minimum=[int64]$env:GFL_MINIMUM; $limit=[int]$env:GFL_LIMIT; Get-Content -LiteralPath $env:GFL_INPUT | ForEach-Object { if ($_ -match '^\d+\s+\w+\s+[0-9a-f]+\s+(\d+)\t(.+)$') { [pscustomobject]@{MB=[math]::Round(([int64]$matches[1])/1MB,2); Bytes=[int64]$matches[1]; Path=$matches[2]} } } | Where-Object { $_.Bytes -ge $minimum } | Sort-Object Bytes -Descending | Select-Object -First $limit | Format-Table MB,Bytes,Path -AutoSize"
set "gflt_format_rc=%errorlevel%"
set "GFL_INPUT="
set "GFL_MINIMUM="
set "GFL_LIMIT="
if not "%gflt_format_rc%"=="0" (echo ERROR: Could not format files tracked at HEAD. & set "_gflt_rc=1" & goto :RunTrackedAnalysis)
echo.
set "_gflt_rc=0" & goto :RunTrackedAnalysis
:: ============================================================
:: :RunHistoryAnalysis
:: Captures object names and batch object metadata in separate files,
:: checks each Git command, and formats historical blobs.
::
:: Usage: call :RunHistoryAnalysis
::
:: Returns: 0 on success
::          1 on Git or PowerShell failure
:: Requires: git, PowerShell
:: ============================================================
:RunHistoryAnalysis
for /f "tokens=1 delims==" %%v in ('set gflh_ 2^>nul') do set "%%v="
if defined _gflh_rc (set "_gflh_rc=" & exit /b %_gflh_rc%)
set "app.git_large.temp.objects=%TEMP%\git-large-objects-%RANDOM%-%RANDOM%.txt"
set "app.git_large.temp.blobs=%TEMP%\git-large-blobs-%RANDOM%-%RANDOM%.txt"
git rev-list --objects --all >"%app.git_large.temp.objects%" 2>nul
if errorlevel 1 (echo ERROR: Could not enumerate Git history objects. & set "_gflh_rc=1" & goto :RunHistoryAnalysis)
git cat-file --batch-check="%%(objecttype) %%(objectsize) %%(rest)" <"%app.git_large.temp.objects%" >"%app.git_large.temp.blobs%" 2>nul
if errorlevel 1 (echo ERROR: Could not read Git object metadata. & set "_gflh_rc=1" & goto :RunHistoryAnalysis)
echo ============================================================
echo  Largest blobs anywhere in Git history
echo ============================================================
echo.
echo This may take longer in repositories with substantial history.
echo.
set "GFL_INPUT=%app.git_large.temp.blobs%"
set "GFL_MINIMUM=%app.git_large.minimumbytes%"
set "GFL_LIMIT=%app.git_large.limit%"
powershell.exe -NoProfile -Command "$minimum=[int64]$env:GFL_MINIMUM; $limit=[int]$env:GFL_LIMIT; Get-Content -LiteralPath $env:GFL_INPUT | ForEach-Object { if ($_ -match '^blob\s+(\d+)\s+(.*)$') { [pscustomobject]@{MB=[math]::Round(([int64]$matches[1])/1MB,2); Bytes=[int64]$matches[1]; Path=$matches[2]} } } | Where-Object { $_.Bytes -ge $minimum } | Sort-Object Bytes -Descending | Select-Object -First $limit | Format-Table MB,Bytes,Path -AutoSize"
set "gflh_format_rc=%errorlevel%"
set "GFL_INPUT="
set "GFL_MINIMUM="
set "GFL_LIMIT="
if not "%gflh_format_rc%"=="0" (echo ERROR: Could not format Git history objects. & set "_gflh_rc=1" & goto :RunHistoryAnalysis)
echo.
set "_gflh_rc=0" & goto :RunHistoryAnalysis
:: ============================================================
:: :CleanupTemp
:: Deletes temporary analysis files and clears formatting variables.
::
:: Usage: call :CleanupTemp
::
:: Returns: 0
:: Requires: del
:: ============================================================
:CleanupTemp
if defined app.git_large.temp.tracked del /q "%app.git_large.temp.tracked%" >nul 2>nul
if defined app.git_large.temp.objects del /q "%app.git_large.temp.objects%" >nul 2>nul
if defined app.git_large.temp.blobs del /q "%app.git_large.temp.blobs%" >nul 2>nul
set "app.git_large.temp.tracked="
set "app.git_large.temp.objects="
set "app.git_large.temp.blobs="
set "GFL_INPUT="
set "GFL_MINIMUM="
set "GFL_LIMIT="
exit /b 0
:: ============================================================
:: :NormalizeMode
:: Normalizes and validates tracked, history, or both.
::
:: Usage: call :NormalizeMode
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:NormalizeMode
if /I "%app.git_large.mode%"=="tracked" set "app.git_large.mode=tracked"
if /I "%app.git_large.mode%"=="history" set "app.git_large.mode=history"
if /I "%app.git_large.mode%"=="both" set "app.git_large.mode=both"
if "%app.git_large.mode%"=="tracked" exit /b 0
if "%app.git_large.mode%"=="history" exit /b 0
if "%app.git_large.mode%"=="both" exit /b 0
echo ERROR: mode must be tracked, history, or both.
exit /b 1
:: ============================================================
:: :ValidateNumber
:: Validates a non-negative decimal whole number.
::
:: Usage: call :ValidateNumber "value" argumentName
::
:: Returns: 0 when valid
::          1 when invalid
:: Requires: none
:: ============================================================
:ValidateNumber
for /f "tokens=1 delims==" %%v in ('set gfln_ 2^>nul') do set "%%v="
if defined _gfln_rc (set "_gfln_rc=" & exit /b %_gfln_rc%)
set "gfln_value=%~1"
set "gfln_name=%~2"
set "gfln_invalid="
if not defined gfln_value (echo ERROR: %gfln_name% requires a whole number. & set "_gfln_rc=1" & goto :ValidateNumber)
for /f "delims=0123456789" %%A in ("%gfln_value%") do set "gfln_invalid=%%A"
if defined gfln_invalid (echo ERROR: %gfln_name% must be a non-negative whole number. & set "_gfln_rc=1" & goto :ValidateNumber)
set "_gfln_rc=0" & goto :ValidateNumber
:: ============================================================
:: :ParseArgs
:: Parses mode, limit, minimumbytes, and help arguments.
::
:: Usage: call :ParseArgs [mode tracked|history|both] [limit N] [minimumbytes N]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="mode" goto :_ParseArgs_mode
if /I "%~1"=="limit" goto :_ParseArgs_limit
if /I "%~1"=="minimumbytes" goto :_ParseArgs_minimum
if /I "%~1"=="minbytes" goto :_ParseArgs_minimum
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_mode
if "%~2"=="" (echo ERROR: mode requires tracked, history, or both. & exit /b 2)
set "app.git_large.mode=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_limit
if "%~2"=="" (echo ERROR: limit requires a number. & exit /b 2)
set "app.git_large.limit=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_minimum
if "%~2"=="" (echo ERROR: minimumbytes requires a number. & exit /b 2)
set "app.git_large.minimumbytes=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_large.help=1"
shift
goto :ParseArgs
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
echo git_find_large_files.bat
echo.
echo Usage:
echo   git_find_large_files.bat
echo   git_find_large_files.bat mode tracked
echo   git_find_large_files.bat mode history limit 30
echo   git_find_large_files.bat mode both minimumbytes 1048576
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
