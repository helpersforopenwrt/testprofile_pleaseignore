@echo off
:: ============================================================
:: bootstrap.bat
:: Portable Windows bootstrapper for a Git repository.
::
:: Intended use:
::   1. Download this file into an empty temporary folder.
::   2. Set bootstrap to the raw URL used to download it.
::   3. Run bootstrap.bat.
::
:: Example:
::   cd /d "%TEMP%"
::   set "bootstrap=https://raw.githubusercontent.com/OWNER/REPO/main/tools/bootstrap.bat"
::   curl.exe -sSLO "%bootstrap%"
::   call bootstrap.bat auto
::
:: Modern repository integration:
::   - uses prepare.bat repository after cloning
::   - uses just_login.bat instead of maintaining a second login flow
::   - auto login selects browser option 3, private browser
::   - runs prepare.bat and build.bat in the same cmd.exe environment
::   - relies on repository launchers for GitHub login and project setup
::
:: Auto login selection:
::   bootstrap.bat auto
::     asks: GitHub login? [y/N]
::
::   bootstrap.bat auto login
::     logs in without asking and selects browser option 3
::
::   bootstrap.bat auto nologin
::     skips GitHub login without asking
::
:: Auto mode:
::   - resolves or installs Git
::   - clones or fast-forward updates the repository
::   - uses Documents\REPOSITORY unless dir PATH or move no is supplied
::   - prepares repository dependencies
::   - optionally runs the repository's just_login.bat
::   - runs prepare.bat
::   - runs build.bat
::
:: Safety:
::   - refuses to update a folder whose origin is a different repository
::   - refuses non-fast-forward pulls
::   - refuses to clone inside the source repository's tools directory
::   - does not change global Git credential-helper configuration
::   - does not duplicate GitHub authentication or fork logic
::
:: Usage:
::   call bootstrap.bat
::   call bootstrap.bat auto
::   call bootstrap.bat auto login
::   call bootstrap.bat auto nologin
::   call bootstrap.bat menu
::   call bootstrap.bat repo URL
::   call bootstrap.bat branch NAME
::   call bootstrap.bat dir PATH
::   call bootstrap.bat move documents
::   call bootstrap.bat move no
::   call bootstrap.bat help
::
:: Returns: 0 on success
::          2 on invalid arguments
::          3 on URL or folder resolution failure
::          4 when Git cannot be prepared
::          5 on clone or update failure
::          6 on repository login failure
::          7 on repository prepare failure
::          8 on build or install failure
:: Requires: cmd.exe, PowerShell, curl or Invoke-WebRequest when Git is absent
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
for %%A in ("%~dp0.") do set "app.bootstrap.root=%%~fA"
set "app.bootstrap.version=bootstrap-modern-1"
set "app.bootstrap.url=%bootstrap%"
set "app.bootstrap.mode=default"
set "app.bootstrap.login.mode=ask"
set "app.bootstrap.move.mode=ask"
set "app.bootstrap.repo.url="
set "app.bootstrap.repo.url.normalized="
set "app.bootstrap.repo.owner="
set "app.bootstrap.repo.name="
set "app.bootstrap.repo.branch=main"
set "app.bootstrap.provider=git"
set "app.bootstrap.raw.tools.url="
set "app.bootstrap.getgit.url="
set "app.bootstrap.folder="
set "app.bootstrap.folder.explicit="
set "app.bootstrap.git="
set "app.bootstrap.log.dir=%TEMP%\bootstrap_logs"
set "app.bootstrap.log="
set "app.bootstrap.timestamp="
set "app.bootstrap.input="
set "app.bootstrap.rc=0"
call :Main %*
set "app.bootstrap.rc=%errorlevel%"
exit /b %app.bootstrap.rc%
:: ============================================================
:: :Main
:: Parses arguments, resolves repository context, and runs the selected mode.
::
:: Usage: call :Main [arguments]
::
:: Returns: selected workflow result
:: Requires: :Initialize, :ParseArgs, :ResolveContext, :ResolveFolder,
::           :RunDefault, :RunAuto, :ShowMenu, :ShowHelp
:: ============================================================
:Main
call :Initialize
if errorlevel 1 exit /b %errorlevel%
call :ParseArgs %*
if errorlevel 1 exit /b %errorlevel%
if /I "%app.bootstrap.mode%"=="help" goto :_Main_help
call :ResolveContext
if errorlevel 1 exit /b %errorlevel%
call :ResolveFolder
if errorlevel 1 exit /b %errorlevel%
call :RejectUnsafeInPlaceRun
if errorlevel 1 exit /b %errorlevel%
if /I "%app.bootstrap.mode%"=="auto" goto :_Main_auto
if /I "%app.bootstrap.mode%"=="menu" goto :_Main_menu
call :RunDefault
exit /b %errorlevel%
:_Main_auto
call :RunAuto
exit /b %errorlevel%
:_Main_menu
call :ShowMenu
exit /b %errorlevel%
:_Main_help
call :ShowHelp
exit /b %errorlevel%
:: ============================================================
:: :Initialize
:: Creates the timestamp and bootstrap log.
::
:: Usage: call :Initialize
::
:: Returns: 0 on success, 3 on failure
:: Requires: PowerShell
:: ============================================================
:Initialize
for /f "delims=" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format yyyy-MM-dd.HHmmss" 2^>nul') do if not defined app.bootstrap.timestamp set "app.bootstrap.timestamp=%%A"
if not defined app.bootstrap.timestamp set "app.bootstrap.timestamp=unknown"
if not exist "%app.bootstrap.log.dir%\" mkdir "%app.bootstrap.log.dir%" >nul 2>nul
if not exist "%app.bootstrap.log.dir%\" (echo ERROR: Could not create bootstrap log folder. & exit /b 3)
set "app.bootstrap.log=%app.bootstrap.log.dir%\bootstrap.%app.bootstrap.timestamp%.log"
break >"%app.bootstrap.log%"
echo Bootstrap:
echo   %app.bootstrap.version%
echo.
echo Log:
echo   %app.bootstrap.log%
echo.
exit /b 0
:: ============================================================
:: :ParseArgs
:: Parses mode, repository, branch, destination, login, and move options.
::
:: Usage: call :ParseArgs [arguments]
::
:: Returns: 0 on success, 2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="auto" (set "app.bootstrap.mode=auto" & shift & goto :ParseArgs)
if /I "%~1"=="menu" (set "app.bootstrap.mode=menu" & shift & goto :ParseArgs)
if /I "%~1"=="login" (set "app.bootstrap.login.mode=yes" & shift & goto :ParseArgs)
if /I "%~1"=="nologin" (set "app.bootstrap.login.mode=no" & shift & goto :ParseArgs)
if /I "%~1"=="repo" goto :_ParseArgs_repo
if /I "%~1"=="branch" goto :_ParseArgs_branch
if /I "%~1"=="dir" goto :_ParseArgs_dir
if /I "%~1"=="move" goto :_ParseArgs_move
if /I "%~1"=="help" (set "app.bootstrap.mode=help" & shift & goto :ParseArgs)
if /I "%~1"=="--help" (set "app.bootstrap.mode=help" & shift & goto :ParseArgs)
if /I "%~1"=="/help" (set "app.bootstrap.mode=help" & shift & goto :ParseArgs)
if /I "%~1"=="/?" (set "app.bootstrap.mode=help" & shift & goto :ParseArgs)
echo %~1| "%SystemRoot%\System32\findstr.exe" /B /I "http:// https://" >nul 2>nul
if not errorlevel 1 (set "app.bootstrap.repo.url=%~1" & shift & goto :ParseArgs)
echo ERROR: Unknown bootstrap argument:
echo   %~1
echo.
exit /b 2
:_ParseArgs_repo
if "%~2"=="" (echo ERROR: repo requires a URL. & exit /b 2)
set "app.bootstrap.repo.url=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_branch
if "%~2"=="" (echo ERROR: branch requires a name. & exit /b 2)
set "app.bootstrap.repo.branch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_dir
if "%~2"=="" (echo ERROR: dir requires a path. & exit /b 2)
set "app.bootstrap.folder=%~2"
set "app.bootstrap.folder.explicit=1"
shift
shift
goto :ParseArgs
:_ParseArgs_move
if "%~2"=="" (echo ERROR: move requires documents, ask, or no. & exit /b 2)
if /I "%~2"=="documents" (set "app.bootstrap.move.mode=documents" & shift & shift & goto :ParseArgs)
if /I "%~2"=="ask" (set "app.bootstrap.move.mode=ask" & shift & shift & goto :ParseArgs)
if /I "%~2"=="no" (set "app.bootstrap.move.mode=no" & shift & shift & goto :ParseArgs)
echo ERROR: move requires documents, ask, or no.
exit /b 2
:: ============================================================
:: :ResolveContext
:: Resolves provider, repository URL, owner, name, branch, and raw tools URL.
::
:: Usage: call :ResolveContext
::
:: Returns: 0 on success, 3 on failure
:: Requires: PowerShell, :SetResolvedValue
:: ============================================================
:ResolveContext
if defined app.bootstrap.repo.url goto :_ResolveContext_repo
if not defined app.bootstrap.url goto :_ResolveContext_missing
set "BOOTSTRAP_RESOLVE_URL=%app.bootstrap.url%"
set "BOOTSTRAP_RESOLVE_BRANCH=%app.bootstrap.repo.branch%"
for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $u=[uri]$env:BOOTSTRAP_RESOLVE_URL; $p=$u.AbsolutePath.Trim('/') -split '/'; $host=$u.Host.ToLowerInvariant(); $branch=$env:BOOTSTRAP_RESOLVE_BRANCH; if(-not $branch){$branch='main'}; if($host -eq 'raw.githubusercontent.com' -and $p.Length -ge 4){$owner=$p[0];$repo=$p[1];$branch=$p[2];'provider=github';'owner='+$owner;'name='+$repo;'branch='+$branch;'repo=https://github.com/'+$owner+'/'+$repo+'.git';'raw=https://raw.githubusercontent.com/'+$owner+'/'+$repo+'/'+$branch+'/tools';exit 0}; if($host -eq 'github.com' -and $p.Length -ge 4 -and $p[2] -eq 'blob'){$owner=$p[0];$repo=$p[1];$branch=$p[3];'provider=github';'owner='+$owner;'name='+$repo;'branch='+$branch;'repo=https://github.com/'+$owner+'/'+$repo+'.git';'raw=https://raw.githubusercontent.com/'+$owner+'/'+$repo+'/'+$branch+'/tools';exit 0}; throw 'Unsupported bootstrap URL. Supply repo URL explicitly.'" 2^>nul') do call :SetResolvedValue "%%A" "%%B"
set "BOOTSTRAP_RESOLVE_URL="
set "BOOTSTRAP_RESOLVE_BRANCH="
if defined app.bootstrap.repo.url goto :_ResolveContext_done
echo ERROR: Could not infer the repository from:
echo   %app.bootstrap.url%
echo.
echo Supply it explicitly:
echo   bootstrap.bat repo https://host/owner/repository.git
echo.
exit /b 3
:_ResolveContext_repo
set "BOOTSTRAP_RESOLVE_URL=%app.bootstrap.repo.url%"
set "BOOTSTRAP_RESOLVE_BRANCH=%app.bootstrap.repo.branch%"
for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $original=$env:BOOTSTRAP_RESOLVE_URL; $parse=$original -replace '^git@([^:]+):','https://$1/' -replace '^ssh://git@','https://'; $u=[uri]$parse; $path=$u.AbsolutePath.Trim('/') -replace '\.git$',''; $parts=$path -split '/'; if($parts.Length -lt 2){throw 'Repository path is incomplete.'}; $name=$parts[$parts.Length-1]; $owner=($parts[0..($parts.Length-2)] -join '/'); $host=$u.Host.ToLowerInvariant(); $provider='git'; $raw=''; if($host -eq 'github.com'){$provider='github';$raw='https://raw.githubusercontent.com/'+$path+'/'+$env:BOOTSTRAP_RESOLVE_BRANCH+'/tools'}elseif($host -like '*gitlab*'){$provider='gitlab';$raw=$u.Scheme+'://'+$u.Authority+'/'+$path+'/-/raw/'+$env:BOOTSTRAP_RESOLVE_BRANCH+'/tools'}elseif($host -eq 'bitbucket.org'){$provider='bitbucket';$raw='https://bitbucket.org/'+$path+'/raw/'+$env:BOOTSTRAP_RESOLVE_BRANCH+'/tools'}elseif($host -like '*gitea*' -or $host -like '*forgejo*' -or $host -eq 'codeberg.org'){$provider='gitea';$raw=$u.Scheme+'://'+$u.Authority+'/'+$path+'/raw/branch/'+$env:BOOTSTRAP_RESOLVE_BRANCH+'/tools'};'provider='+$provider;'owner='+$owner;'name='+$name;if($raw){'raw='+$raw}" 2^>nul') do call :SetResolvedValue "%%A" "%%B"
set "BOOTSTRAP_RESOLVE_URL="
set "BOOTSTRAP_RESOLVE_BRANCH="
:_ResolveContext_done
if not defined app.bootstrap.repo.url goto :_ResolveContext_missing
if not defined app.bootstrap.repo.name goto :_ResolveContext_missing
if defined app.bootstrap.raw.tools.url set "app.bootstrap.getgit.url=%app.bootstrap.raw.tools.url%/GetGit.bat"
call :NormalizeRepoUrl "%app.bootstrap.repo.url%"
set "app.bootstrap.repo.url.normalized=%app.bootstrap.normalized.url%"
set "app.bootstrap.normalized.url="
echo Repository:
echo   %app.bootstrap.repo.url%
echo.
echo Provider:
echo   %app.bootstrap.provider%
echo.
echo Branch:
echo   %app.bootstrap.repo.branch%
echo.
exit /b 0
:_ResolveContext_missing
echo ERROR: Repository URL and repository name could not be resolved.
echo.
exit /b 3
:: ============================================================
:: :SetResolvedValue
:: Stores one key/value pair produced by :ResolveContext.
::
:: Usage: call :SetResolvedValue "key" "value"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:SetResolvedValue
if /I "%~1"=="provider" set "app.bootstrap.provider=%~2"
if /I "%~1"=="owner" set "app.bootstrap.repo.owner=%~2"
if /I "%~1"=="name" set "app.bootstrap.repo.name=%~2"
if /I "%~1"=="branch" set "app.bootstrap.repo.branch=%~2"
if /I "%~1"=="repo" set "app.bootstrap.repo.url=%~2"
if /I "%~1"=="raw" set "app.bootstrap.raw.tools.url=%~2"
exit /b 0
:: ============================================================
:: :ResolveFolder
:: Resolves the checkout folder.
::
:: Usage: call :ResolveFolder
::
:: Returns: 0 on success, 3 on failure
:: Requires: PowerShell
:: ============================================================
:ResolveFolder
if defined app.bootstrap.folder goto :_ResolveFolder_finalize
if /I "%app.bootstrap.mode%"=="auto" if /I not "%app.bootstrap.move.mode%"=="no" set "app.bootstrap.move.mode=documents"
if /I "%app.bootstrap.move.mode%"=="documents" goto :_ResolveFolder_documents
if /I "%app.bootstrap.move.mode%"=="ask" if /I "%app.bootstrap.mode%"=="default" goto :_ResolveFolder_ask
set "app.bootstrap.folder=%app.bootstrap.root%\%app.bootstrap.repo.name%"
goto :_ResolveFolder_finalize
:_ResolveFolder_documents
for /f "delims=" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "[Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)" 2^>nul') do if not defined app.bootstrap.documents set "app.bootstrap.documents=%%A"
if not defined app.bootstrap.documents (echo ERROR: Could not resolve the Windows Documents folder. & exit /b 3)
set "app.bootstrap.folder=%app.bootstrap.documents%\%app.bootstrap.repo.name%"
goto :_ResolveFolder_finalize
:_ResolveFolder_ask
set "app.bootstrap.input="
set /p "app.bootstrap.input=Checkout folder [%app.bootstrap.root%\%app.bootstrap.repo.name%]: "
if defined app.bootstrap.input (set "app.bootstrap.folder=%app.bootstrap.input%") else set "app.bootstrap.folder=%app.bootstrap.root%\%app.bootstrap.repo.name%"
:_ResolveFolder_finalize
for %%A in ("%app.bootstrap.folder%") do set "app.bootstrap.folder=%%~fA"
if not defined app.bootstrap.folder (echo ERROR: Checkout folder could not be resolved. & exit /b 3)
echo Checkout folder:
echo   %app.bootstrap.folder%
echo.
exit /b 0
:: ============================================================
:: :RejectUnsafeInPlaceRun
:: Prevents an accidental nested clone when this checked-in tools copy is run.
::
:: Usage: call :RejectUnsafeInPlaceRun
::
:: Returns: 0 when safe, 3 when the target is inside the source repository
:: Requires: PowerShell
:: ============================================================
:RejectUnsafeInPlaceRun
for %%A in ("%app.bootstrap.root%\..") do set "app.bootstrap.parent=%%~fA"
if not exist "%app.bootstrap.parent%\.git\" exit /b 0
set "BOOTSTRAP_PARENT=%app.bootstrap.parent%"
set "BOOTSTRAP_TARGET=%app.bootstrap.folder%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=[IO.Path]::GetFullPath($env:BOOTSTRAP_PARENT).TrimEnd('\')+'\'; $t=[IO.Path]::GetFullPath($env:BOOTSTRAP_TARGET); if($t.StartsWith($p,[StringComparison]::OrdinalIgnoreCase)){exit 3}; exit 0"
set "app.bootstrap.safety.rc=%errorlevel%"
set "BOOTSTRAP_PARENT="
set "BOOTSTRAP_TARGET="
if "%app.bootstrap.safety.rc%"=="0" exit /b 0
echo ERROR: Refusing to bootstrap a repository inside the current source repository.
echo.
echo Copy bootstrap.bat to an empty temporary folder first, or use:
echo   bootstrap.bat dir C:\Path\Outside\The\Current\Repository
echo.
exit /b 3
:: ============================================================
:: :RunDefault
:: Clones or updates the repository without prepare/build automation.
::
:: Usage: call :RunDefault
::
:: Returns: workflow result
:: Requires: :EnsureGit, :CloneOrUpdate
:: ============================================================
:RunDefault
echo ============================================================
echo  Bootstrap default mode
echo ============================================================
echo.
call :EnsureGit
if errorlevel 1 exit /b %errorlevel%
call :CloneOrUpdate
if errorlevel 1 exit /b %errorlevel%
echo Bootstrap complete.
echo.
echo Repository:
echo   %app.bootstrap.folder%
echo.
exit /b 0
:: ============================================================
:: :RunAuto
:: Runs clone/update, repository preparation, optional login, prepare, and build.
::
:: Usage: call :RunAuto
::
:: Returns: workflow result
:: Requires: :EnsureGit, :CloneOrUpdate, :PrepareRepository,
::           :ResolveAutoLoginChoice, :RunJustLoginPrivate,
::           :RunProjectPrepare, :RunProjectBuild
:: ============================================================
:RunAuto
echo ============================================================
echo  Bootstrap auto mode
echo ============================================================
echo.
call :EnsureGit
if errorlevel 1 exit /b %errorlevel%
call :CloneOrUpdate
if errorlevel 1 exit /b %errorlevel%
call :PrepareRepository
if errorlevel 1 exit /b %errorlevel%
call :ResolveAutoLoginChoice
if errorlevel 1 exit /b %errorlevel%
if /I "%app.bootstrap.login.mode%"=="yes" call :RunJustLoginPrivate
if errorlevel 1 exit /b %errorlevel%
call :RunProjectPrepare
if errorlevel 1 exit /b %errorlevel%
call :RunProjectBuild
if errorlevel 1 exit /b %errorlevel%
echo ============================================================
echo  Auto bootstrap complete
echo ============================================================
echo.
echo Repository:
echo   %app.bootstrap.folder%
echo.
exit /b 0
:: ============================================================
:: :EnsureGit
:: Resolves Git or downloads and runs the repository's GetGit.bat helper.
::
:: Usage: call :EnsureGit
::
:: Returns: 0 when Git is ready, 4 otherwise
:: Requires: :FindGit, :DownloadFile
:: ============================================================
:EnsureGit
call :FindGit
if defined app.bootstrap.git goto :_EnsureGit_ready
if not defined app.bootstrap.getgit.url goto :_EnsureGit_missing_url
echo Git was not found.
echo Downloading:
echo   %app.bootstrap.getgit.url%
echo.
if not exist "%app.bootstrap.root%\tools\" mkdir "%app.bootstrap.root%\tools" >nul 2>nul
call :DownloadFile "%app.bootstrap.getgit.url%" "%app.bootstrap.root%\tools\GetGit.bat"
if errorlevel 1 exit /b 4
call "%app.bootstrap.root%\tools\GetGit.bat" >>"%app.bootstrap.log%" 2>&1
set "app.bootstrap.getgit.rc=%errorlevel%"
if not "%app.bootstrap.getgit.rc%"=="0" (echo ERROR: GetGit.bat failed. See: & echo   %app.bootstrap.log% & exit /b 4)
call :FindGit
if not defined app.bootstrap.git (echo ERROR: Git is still unavailable after GetGit.bat. & exit /b 4)
:_EnsureGit_ready
for %%A in ("%app.bootstrap.git%") do set "app.bootstrap.git.dir=%%~dpA"
echo ;%PATH%;| "%SystemRoot%\System32\find.exe" /I ";%app.bootstrap.git.dir%;" >nul
if errorlevel 1 set "PATH=%app.bootstrap.git.dir%;%PATH%"
echo Git:
echo   %app.bootstrap.git%
echo.
exit /b 0
:_EnsureGit_missing_url
echo ERROR: Git was not found and GetGit.bat URL could not be inferred.
echo.
echo Supply a supported bootstrap URL or install Git before continuing.
echo.
exit /b 4
:: ============================================================
:: :FindGit
:: Resolves git.exe from local bootstrap tools or PATH.
::
:: Usage: call :FindGit
::
:: Returns: 0
:: Requires: none
:: ============================================================
:FindGit
set "app.bootstrap.git="
if exist "%app.bootstrap.root%\tools\git\cmd\git.exe" for %%A in ("%app.bootstrap.root%\tools\git\cmd\git.exe") do set "app.bootstrap.git=%%~fA"
if not defined app.bootstrap.git for %%A in (git.exe) do if not "%%~$PATH:A"=="" set "app.bootstrap.git=%%~$PATH:A"
exit /b 0
:: ============================================================
:: :DownloadFile
:: Downloads one file with curl or PowerShell fallback.
::
:: Usage: call :DownloadFile "URL" "destination"
::
:: Returns: 0 on success, 4 on failure
:: Requires: curl.exe or PowerShell
:: ============================================================
:DownloadFile
set "BOOTSTRAP_DOWNLOAD_URL=%~1"
set "BOOTSTRAP_DOWNLOAD_FILE=%~2"
if exist "%BOOTSTRAP_DOWNLOAD_FILE%" del /q "%BOOTSTRAP_DOWNLOAD_FILE%" >nul 2>nul
where curl.exe >nul 2>nul
if errorlevel 1 goto :_DownloadFile_powershell
curl.exe -L --fail --retry 3 -o "%BOOTSTRAP_DOWNLOAD_FILE%" "%BOOTSTRAP_DOWNLOAD_URL%" >>"%app.bootstrap.log%" 2>&1
if exist "%BOOTSTRAP_DOWNLOAD_FILE%" goto :_DownloadFile_ok
:_DownloadFile_powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri $env:BOOTSTRAP_DOWNLOAD_URL -OutFile $env:BOOTSTRAP_DOWNLOAD_FILE" >>"%app.bootstrap.log%" 2>&1
if exist "%BOOTSTRAP_DOWNLOAD_FILE%" goto :_DownloadFile_ok
echo ERROR: Download failed:
echo   %BOOTSTRAP_DOWNLOAD_URL%
echo.
set "BOOTSTRAP_DOWNLOAD_URL="
set "BOOTSTRAP_DOWNLOAD_FILE="
exit /b 4
:_DownloadFile_ok
set "BOOTSTRAP_DOWNLOAD_URL="
set "BOOTSTRAP_DOWNLOAD_FILE="
exit /b 0
:: ============================================================
:: :CloneOrUpdate
:: Clones the requested repository or fast-forward updates a verified checkout.
::
:: Usage: call :CloneOrUpdate
::
:: Returns: 0 on success, 5 on failure
:: Requires: Git, :VerifyExistingOrigin
:: ============================================================
:CloneOrUpdate
if exist "%app.bootstrap.folder%\.git\" goto :_CloneOrUpdate_existing
if exist "%app.bootstrap.folder%\" goto :_CloneOrUpdate_non_git
for %%A in ("%app.bootstrap.folder%\..") do if not exist "%%~fA\" mkdir "%%~fA" >nul 2>nul
echo Cloning:
echo   %app.bootstrap.repo.url%
echo.
"%app.bootstrap.git%" clone --branch "%app.bootstrap.repo.branch%" --single-branch "%app.bootstrap.repo.url%" "%app.bootstrap.folder%" >>"%app.bootstrap.log%" 2>&1
if errorlevel 1 (echo ERROR: Git clone failed. See: & echo   %app.bootstrap.log% & exit /b 5)
echo Clone complete.
echo.
exit /b 0
:_CloneOrUpdate_non_git
echo ERROR: Checkout folder exists but is not a Git repository:
echo   %app.bootstrap.folder%
echo.
echo Move or remove that folder, or choose another dir PATH.
echo.
exit /b 5
:_CloneOrUpdate_existing
call :VerifyExistingOrigin
if errorlevel 1 exit /b 5
echo Updating existing checkout...
"%app.bootstrap.git%" -C "%app.bootstrap.folder%" fetch origin --prune >>"%app.bootstrap.log%" 2>&1
if errorlevel 1 (echo ERROR: git fetch failed. See: & echo   %app.bootstrap.log% & exit /b 5)
"%app.bootstrap.git%" -C "%app.bootstrap.folder%" switch "%app.bootstrap.repo.branch%" >>"%app.bootstrap.log%" 2>&1
if errorlevel 1 "%app.bootstrap.git%" -C "%app.bootstrap.folder%" switch -c "%app.bootstrap.repo.branch%" --track "origin/%app.bootstrap.repo.branch%" >>"%app.bootstrap.log%" 2>&1
if errorlevel 1 (echo ERROR: Could not select branch %app.bootstrap.repo.branch%. & exit /b 5)
"%app.bootstrap.git%" -C "%app.bootstrap.folder%" pull --ff-only origin "%app.bootstrap.repo.branch%" >>"%app.bootstrap.log%" 2>&1
if errorlevel 1 (echo ERROR: Fast-forward update failed. Local work was not overwritten. & echo See: & echo   %app.bootstrap.log% & exit /b 5)
echo Checkout is current.
echo.
exit /b 0
:: ============================================================
:: :VerifyExistingOrigin
:: Verifies that an existing checkout belongs to the requested repository.
::
:: Usage: call :VerifyExistingOrigin
::
:: Returns: 0 when matching, 5 otherwise
:: Requires: Git, :NormalizeRepoUrl
:: ============================================================
:VerifyExistingOrigin
set "app.bootstrap.existing.origin="
for /f "delims=" %%A in ('"%app.bootstrap.git%" -C "%app.bootstrap.folder%" remote get-url origin 2^>nul') do if not defined app.bootstrap.existing.origin set "app.bootstrap.existing.origin=%%A"
if not defined app.bootstrap.existing.origin (echo ERROR: Existing checkout has no origin remote. & exit /b 5)
call :NormalizeRepoUrl "%app.bootstrap.existing.origin%"
set "app.bootstrap.existing.origin.normalized=%app.bootstrap.normalized.url%"
set "app.bootstrap.normalized.url="
if /I "%app.bootstrap.existing.origin.normalized%"=="%app.bootstrap.repo.url.normalized%" exit /b 0
echo ERROR: Existing checkout points to a different origin.
echo.
echo Expected:
echo   %app.bootstrap.repo.url%
echo.
echo Existing:
echo   %app.bootstrap.existing.origin%
echo.
exit /b 5
:: ============================================================
:: :NormalizeRepoUrl
:: Normalizes HTTPS and SSH-style Git URLs for comparison.
::
:: Usage: call :NormalizeRepoUrl "URL"
::
:: Output:
::   app.bootstrap.normalized.url
::
:: Returns: 0
:: Requires: PowerShell
:: ============================================================
:NormalizeRepoUrl
set "BOOTSTRAP_NORMALIZE_URL=%~1"
set "app.bootstrap.normalized.url="
for /f "delims=" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$u=$env:BOOTSTRAP_NORMALIZE_URL.Trim(); $u=$u -replace '^git@([^:]+):','https://$1/' -replace '^ssh://git@','https://'; $u=$u.TrimEnd('/'); $u=$u -replace '\.git$',''; $u.ToLowerInvariant()" 2^>nul') do if not defined app.bootstrap.normalized.url set "app.bootstrap.normalized.url=%%A"
set "BOOTSTRAP_NORMALIZE_URL="
exit /b 0
:: ============================================================
:: :PrepareRepository
:: Calls the cloned repository's prepare.bat repository mode.
::
:: Usage: call :PrepareRepository
::
:: Returns: 0 on success, 7 on failure
:: Requires: repository prepare.bat
:: ============================================================
:PrepareRepository
if not exist "%app.bootstrap.folder%\prepare.bat" (echo ERROR: prepare.bat was not found in the cloned repository. & exit /b 7)
pushd "%app.bootstrap.folder%" >nul
call prepare.bat repository
set "app.bootstrap.prepare.repo.rc=%errorlevel%"
popd >nul
if "%app.bootstrap.prepare.repo.rc%"=="0" exit /b 0
echo ERROR: prepare.bat repository failed.
exit /b 7
:: ============================================================
:: :ResolveAutoLoginChoice
:: Resolves whether auto mode should run repository GitHub login.
::
:: Usage: call :ResolveAutoLoginChoice
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ResolveAutoLoginChoice
if /I not "%app.bootstrap.provider%"=="github" (set "app.bootstrap.login.mode=no" & echo GitHub login skipped for provider %app.bootstrap.provider%. & echo. & exit /b 0)
if /I "%app.bootstrap.login.mode%"=="yes" exit /b 0
if /I "%app.bootstrap.login.mode%"=="no" (echo GitHub login skipped. & echo. & exit /b 0)
set "app.bootstrap.input="
set /p "app.bootstrap.input=GitHub login? [y/N]: "
if /I "%app.bootstrap.input%"=="y" set "app.bootstrap.login.mode=yes"
if /I "%app.bootstrap.input%"=="yes" set "app.bootstrap.login.mode=yes"
if /I not "%app.bootstrap.login.mode%"=="yes" set "app.bootstrap.login.mode=no"
echo.
exit /b 0
:: ============================================================
:: :EnsureGitHubCLI
:: Resolves GitHub CLI or runs the cloned repository's installer helper.
::
:: Usage: call :EnsureGitHubCLI
::
:: Returns: 0 when gh.exe is ready, 6 otherwise
:: Requires: repository tools\GetGithubCLI.bat when gh.exe is absent
:: ============================================================
:EnsureGitHubCLI
where gh.exe >nul 2>nul
if not errorlevel 1 exit /b 0
if exist "%app.bootstrap.folder%\tools\gh\bin\gh.exe" goto :_EnsureGitHubCLI_local
if not exist "%app.bootstrap.folder%\tools\GetGithubCLI.bat" goto :_EnsureGitHubCLI_missing
echo GitHub CLI was not found.
echo Running repository helper:
echo   tools\GetGithubCLI.bat
echo.
pushd "%app.bootstrap.folder%" >nul
call tools\GetGithubCLI.bat
set "app.bootstrap.getgh.rc=%errorlevel%"
popd >nul
if not "%app.bootstrap.getgh.rc%"=="0" (echo ERROR: GetGithubCLI.bat failed. & exit /b 6)
call :PrepareRepository
if errorlevel 1 exit /b 6
where gh.exe >nul 2>nul
if not errorlevel 1 exit /b 0
if not exist "%app.bootstrap.folder%\tools\gh\bin\gh.exe" goto :_EnsureGitHubCLI_missing
:_EnsureGitHubCLI_local
set "PATH=%app.bootstrap.folder%\tools\gh\bin;%PATH%"
where gh.exe >nul 2>nul
if not errorlevel 1 exit /b 0
:_EnsureGitHubCLI_missing
echo ERROR: GitHub CLI is unavailable.
echo.
echo Expected either gh.exe in PATH or:
echo   %app.bootstrap.folder%\tools\GetGithubCLI.bat
echo.
exit /b 6
:: ============================================================
:: :RunJustLoginPrivate
:: Runs the repository's tested just_login.bat workflow.
::
:: When login is required, this function supplies browser choice 3 and
:: blank responses for existing Git identity defaults. The repository's
:: just_login.bat remains responsible for browser launch, clipboard,
:: authentication, permissions, remotes, and Git identity storage.
::
:: Usage: call :RunJustLoginPrivate
::
:: Returns: 0 on success, 6 on failure
:: Requires: repository just_login.bat, gh.exe
:: ============================================================
:RunJustLoginPrivate
if not exist "%app.bootstrap.folder%\just_login.bat" (echo ERROR: just_login.bat was not found in the cloned repository. & exit /b 6)
call :EnsureGitHubCLI
if errorlevel 1 exit /b 6
gh.exe auth status --hostname github.com >nul 2>nul
if not errorlevel 1 goto :_RunJustLoginPrivate_existing
set "app.bootstrap.login.input=%TEMP%\bootstrap-login-%RANDOM%-%RANDOM%.txt"
> "%app.bootstrap.login.input%" echo 3
>>"%app.bootstrap.login.input%" echo.
>>"%app.bootstrap.login.input%" echo.
pushd "%app.bootstrap.folder%" >nul
call just_login.bat <"%app.bootstrap.login.input%"
set "app.bootstrap.login.rc=%errorlevel%"
popd >nul
del /q "%app.bootstrap.login.input%" >nul 2>nul
set "app.bootstrap.login.input="
if "%app.bootstrap.login.rc%"=="0" exit /b 0
echo ERROR: just_login.bat failed.
exit /b 6
:_RunJustLoginPrivate_existing
echo GitHub CLI is already authenticated.
echo Running repository login/setup without browser automation...
echo.
pushd "%app.bootstrap.folder%" >nul
call just_login.bat
set "app.bootstrap.login.rc=%errorlevel%"
popd >nul
if "%app.bootstrap.login.rc%"=="0" exit /b 0
echo ERROR: just_login.bat failed.
exit /b 6
:: ============================================================
:: :RunProjectPrepare
:: Calls prepare.bat in the current bootstrap cmd.exe environment.
::
:: Usage: call :RunProjectPrepare
::
:: Returns: 0 on success, 7 on failure
:: Requires: repository prepare.bat
:: ============================================================
:RunProjectPrepare
pushd "%app.bootstrap.folder%" >nul
call prepare.bat
set "app.bootstrap.prepare.rc=%errorlevel%"
popd >nul
if "%app.bootstrap.prepare.rc%"=="0" exit /b 0
echo ERROR: prepare.bat failed.
exit /b 7
:: ============================================================
:: :RunProjectBuild
:: Calls build.bat in the same bootstrap cmd.exe environment used by prepare.
::
:: Usage: call :RunProjectBuild
::
:: Returns: 0 on success or when absent, 8 on failure
:: Requires: repository build.bat
:: ============================================================
:RunProjectBuild
if not exist "%app.bootstrap.folder%\build.bat" (echo build.bat was not found; build skipped. & echo. & exit /b 0)
pushd "%app.bootstrap.folder%" >nul
call build.bat
set "app.bootstrap.build.rc=%errorlevel%"
popd >nul
if "%app.bootstrap.build.rc%"=="0" exit /b 0
echo ERROR: build.bat failed.
exit /b 8
:: ============================================================
:: :RunProjectInstall
:: Calls install.bat from the repository.
::
:: Usage: call :RunProjectInstall
::
:: Returns: 0 on success or when absent, 8 on failure
:: Requires: repository install.bat
:: ============================================================
:RunProjectInstall
if not exist "%app.bootstrap.folder%\install.bat" (echo install.bat was not found; install skipped. & echo. & exit /b 0)
pushd "%app.bootstrap.folder%" >nul
call install.bat
set "app.bootstrap.install.rc=%errorlevel%"
popd >nul
if "%app.bootstrap.install.rc%"=="0" exit /b 0
echo ERROR: install.bat failed.
exit /b 8
:: ============================================================
:: :ShowMenu
:: Displays an interactive menu that delegates to repository launchers.
::
:: Usage: call :ShowMenu
::
:: Returns: 0 when the user exits
:: Requires: workflow functions
:: ============================================================
:ShowMenu
:_ShowMenu_loop
echo ============================================================
echo  Bootstrap menu
echo ============================================================
echo.
echo   1  Clone or fast-forward update
echo   2  Prepare repository dependencies
echo   3  GitHub login using private-browser option 3
echo   4  Run prepare.bat
echo   5  Run build.bat
echo   6  Run install.bat
echo   7  Run auto workflow
echo   0  Exit
echo.
set "app.bootstrap.input="
set /p "app.bootstrap.input=Choose [0-7]: "
if "%app.bootstrap.input%"=="0" exit /b 0
if "%app.bootstrap.input%"=="1" (call :EnsureGit & if not errorlevel 1 call :CloneOrUpdate & goto :_ShowMenu_pause)
if "%app.bootstrap.input%"=="2" (call :PrepareRepository & goto :_ShowMenu_pause)
if "%app.bootstrap.input%"=="3" (set "app.bootstrap.login.mode=yes" & call :RunJustLoginPrivate & goto :_ShowMenu_pause)
if "%app.bootstrap.input%"=="4" (call :RunProjectPrepare & goto :_ShowMenu_pause)
if "%app.bootstrap.input%"=="5" (call :RunProjectBuild & goto :_ShowMenu_pause)
if "%app.bootstrap.input%"=="6" (call :RunProjectInstall & goto :_ShowMenu_pause)
if "%app.bootstrap.input%"=="7" (call :RunAuto & goto :_ShowMenu_pause)
echo Invalid menu choice.
:_ShowMenu_pause
echo.
pause
echo.
goto :_ShowMenu_loop
:: ============================================================
:: :ShowHelp
:: Displays command help.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo bootstrap.bat
echo.
echo Usage:
echo   bootstrap.bat
echo   bootstrap.bat auto
echo   bootstrap.bat auto login
echo   bootstrap.bat auto nologin
echo   bootstrap.bat menu
echo   bootstrap.bat repo URL
echo   bootstrap.bat branch NAME
echo   bootstrap.bat dir PATH
echo   bootstrap.bat move documents
echo   bootstrap.bat move no
echo.
echo Auto login:
echo   auto          asks GitHub login? [y/N]
echo   auto login    runs just_login.bat with private-browser option 3
echo   auto nologin  skips GitHub login
echo.
echo Recommended loader:
echo   cd /d %%TEMP%%
echo   set "bootstrap=https://raw.githubusercontent.com/OWNER/REPO/main/tools/bootstrap.bat"
echo   curl.exe -sSLO "%%bootstrap%%"
echo   call bootstrap.bat auto
echo.
exit /b 0
