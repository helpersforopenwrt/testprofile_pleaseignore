@echo off
:: ============================================================
:: git_backup_bundle.bat
:: Creates a timestamped Git bundle containing committed history.
::
:: Usage: call tools\git_backup_bundle.bat
::
:: Returns: 0 on success or cancellation
::          1 on repository, folder, bundle, or verification failure
:: Requires: _common.bat, git, PowerShell, :Main,
::           :ConfirmDirtyRepository, :ResolveBackupPath,
::           :SanitizeFileName, :CreateBundle,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_backup.safe.name="
set "app.git_backup.dir="
set "app.git_backup.file="
set "app.git_backup.stamp="
set "app.git_backup.confirm="
set "app.git_backup.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_backup.rc=%errorlevel%"
goto :end
:run
call :Main
set "app.git_backup.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_backup.rc%
:: ============================================================
:: :Main
:: Validates the repository, warns about uncommitted content,
:: resolves a backup path, creates the bundle, and verifies it.
::
:: Usage: call :Main
::
:: Returns: 0 on success or cancellation
::          1 on repository, folder, bundle, or verification failure
:: Requires: :ConfirmDirtyRepository, :ResolveBackupPath,
::           :CreateBundle, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gbbm_ 2^>nul') do set "%%v="
if defined _gbbm_rc (set "_gbbm_rc=" & exit /b %_gbbm_rc%)
echo.
echo ============================================================
echo  Create Git backup bundle
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: git was not found in PATH. & set "_gbbm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gbbm_rc=1" & goto :Main)
git rev-parse --verify HEAD >nul 2>nul
if errorlevel 1 (echo ERROR: A Git bundle needs at least one commit. & set "_gbbm_rc=1" & goto :Main)
call :ConfirmDirtyRepository
if errorlevel 2 (set "_gbbm_rc=0" & goto :Main)
if errorlevel 1 (set "_gbbm_rc=%errorlevel%" & goto :Main)
call :ResolveBackupPath
if errorlevel 1 (set "_gbbm_rc=%errorlevel%" & goto :Main)
call :CreateBundle
set "_gbbm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :ConfirmDirtyRepository
:: Warns that a bundle excludes uncommitted, untracked, and ignored
:: files and asks whether to continue when local changes exist.
::
:: Usage: call :ConfirmDirtyRepository
::
:: Returns: 0 when clean or confirmed
::          2 when the user cancels
:: Requires: git
:: ============================================================
:ConfirmDirtyRepository
for /f "tokens=1 delims==" %%v in ('set gbbd_ 2^>nul') do set "%%v="
if defined _gbbd_rc (set "_gbbd_rc=" & exit /b %_gbbd_rc%)
set "gbbd_dirty="
for /f "delims=" %%A in ('git status --porcelain 2^>nul') do set "gbbd_dirty=1"
if not defined gbbd_dirty (set "_gbbd_rc=0" & goto :ConfirmDirtyRepository)
echo WARNING: A Git bundle contains committed Git history only.
echo It does not include uncommitted, untracked, or ignored files.
echo.
git status --short
echo.
set "app.git_backup.confirm="
set /p "app.git_backup.confirm=Create the committed-history bundle anyway? [y/N]: "
if /I "%app.git_backup.confirm%"=="y" (set "_gbbd_rc=0" & goto :ConfirmDirtyRepository)
if /I "%app.git_backup.confirm%"=="yes" (set "_gbbd_rc=0" & goto :ConfirmDirtyRepository)
echo Cancelled.
set "_gbbd_rc=2" & goto :ConfirmDirtyRepository
:: ============================================================
:: :ResolveBackupPath
:: Sanitizes the project name, resolves the backup folder, and
:: creates a timestamped bundle path.
::
:: Usage: call :ResolveBackupPath
::
:: Output:
::   app.git_backup.safe.name  filesystem-safe project name
::   app.git_backup.dir        absolute backup folder
::   app.git_backup.file       absolute bundle path
::
:: Returns: 0 on success
::          1 when the folder cannot be created
:: Requires: :SanitizeFileName, PowerShell
:: ============================================================
:ResolveBackupPath
for /f "tokens=1 delims==" %%v in ('set gbbr_ 2^>nul') do set "%%v="
if defined _gbbr_rc (set "_gbbr_rc=" & exit /b %_gbbr_rc%)
call :SanitizeFileName "%APP_NAME%"
if errorlevel 1 (set "_gbbr_rc=%errorlevel%" & goto :ResolveBackupPath)
set "app.git_backup.safe.name=%sfn.output%"
if defined app.git_backup_dir set "app.git_backup.dir=%app.git_backup_dir%"
if not defined app.git_backup.dir set "app.git_backup.dir=%USERPROFILE%\Desktop\%app.git_backup.safe.name%-git-backups"
for %%A in ("%app.git_backup.dir%") do set "app.git_backup.dir=%%~fA"
if exist "%app.git_backup.dir%\" goto :_ResolveBackupPath_stamp
mkdir "%app.git_backup.dir%" >nul 2>nul
if errorlevel 1 (echo ERROR: Could not create backup folder: & echo   %app.git_backup.dir% & set "_gbbr_rc=1" & goto :ResolveBackupPath)
:_ResolveBackupPath_stamp
for /f "delims=" %%A in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd.HHmmss" 2^>nul') do set "app.git_backup.stamp=%%A"
if not defined app.git_backup.stamp set "app.git_backup.stamp=%RANDOM%-%RANDOM%"
set "app.git_backup.file=%app.git_backup.dir%\%app.git_backup.safe.name%-%app.git_backup.stamp%.bundle"
set "_gbbr_rc=0" & goto :ResolveBackupPath
:: ============================================================
:: :SanitizeFileName
:: Replaces characters that are unsafe in Windows filenames.
::
:: Usage: call :SanitizeFileName "text"
::
:: Output:
::   sfn.output  sanitized filename component
::
:: Returns: 0
:: Requires: PowerShell
:: ============================================================
:SanitizeFileName
for /f "tokens=1 delims==" %%v in ('set sfn_ 2^>nul') do set "%%v="
if defined _sfn_rc (set "_sfn_rc=" & exit /b %_sfn_rc%)
set "sfn_input=%~1"
set "sfn.output="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$v=$env:sfn_input; if([string]::IsNullOrWhiteSpace($v)){$v='repository'}; foreach($c in [IO.Path]::GetInvalidFileNameChars()){$v=$v.Replace($c,'_')}; $v=$v.Replace(' ','_').Trim('.','_'); if([string]::IsNullOrWhiteSpace($v)){$v='repository'}; $v" 2^>nul`) do set "sfn.output=%%A"
if not defined sfn.output set "sfn.output=repository"
set "_sfn_rc=0" & goto :SanitizeFileName
:: ============================================================
:: :CreateBundle
:: Creates and verifies the Git bundle.
::
:: Usage: call :CreateBundle
::
:: Returns: 0 on success
::          1 on create or verification failure
:: Requires: git
:: ============================================================
:CreateBundle
for /f "tokens=1 delims==" %%v in ('set gbbc_ 2^>nul') do set "%%v="
if defined _gbbc_rc (set "_gbbc_rc=" & exit /b %_gbbc_rc%)
git bundle create "%app.git_backup.file%" --all
if errorlevel 1 (echo ERROR: Backup bundle failed. & set "_gbbc_rc=1" & goto :CreateBundle)
git bundle verify "%app.git_backup.file%" >nul 2>nul
if errorlevel 1 (echo ERROR: Backup bundle verification failed. & del /q "%app.git_backup.file%" >nul 2>nul & set "_gbbc_rc=1" & goto :CreateBundle)
echo.
echo Backup created:
echo   %app.git_backup.file%
echo.
set "_gbbc_rc=0" & goto :CreateBundle
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
