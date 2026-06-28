@echo off
:setup

:: ============================================================
:: bootstrap.bat
:: Generic local bootstrapper for Git repositories.
::
:: Batch style:
::   - no delayed expansion
::   - no setlocal
::   - documented functions
::   - one empty line between documented functions
::   - no empty lines inside functions
::
:: Typical loader:
::   cd /d %TEMP% & set "bootstrap=https://raw.githubusercontent.com/FoodSnap2/FoodSnap/main/tools/bootstrap.bat" & call curl.exe -sSLO "%bootstrap%" & bootstrap
::
:: Purpose:
::   - infer repo URL from the bootstrap URL
::   - get local Git before cloning
::   - clone/update repo
::   - optionally login/fork/move/build/install
::   - auto mode bypasses menu and runs end-to-end

:: ============================================================
cd /d "%~dp0"
set "app.rc=0"
set "app.version=bootstrap25"
set "app.root=%CD%"
set "app.timestamp="
set "app.log.dir=%app.root%\bootstrap_logs"
set "app.log="
set "app.bootstrap.url=%bootstrap%"
set "app.repo.url="
set "app.repo.owner="
set "app.repo.name="
set "app.repo.branch=main"
set "app.repo.host="
set "app.repo.path="
set "app.provider="
set "app.provider.requested="
set "app.repo.github="
set "app.raw.tools.url="
set "app.getgit.url="
set "app.getgh.url="
set "app.folder="
set "app.final.folder="
set "app.final.cd="
set "app.tools=%app.root%\tools"
set "app.git="
set "app.gh="
set "app.github.user="
set "app.mode=default"
set "app.help="
set "app.auto="
set "app.login.mode=ask"
set "app.fork.mode=ask"
set "app.move.mode=ask"
set "app.choice="
set "app.esc="
set "app.color.reset=0m"
set "app.color.red=31m"
set "app.color.green=32m"
set "app.color.yellow=33m"
set "app.color.cyan=36m"
set "app.color.white=37m"
:main
call :InitializeBootstrap
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
call :ParseArgs %*
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
if defined app.auto set "app.mode=auto"
if defined app.help call :ShowHelp
if defined app.help set "app.rc=0"
if defined app.help goto :end
call :ResolveBootstrapContext
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
call :ResolveRepoFolder
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
if /I "%app.mode%"=="auto" goto :main_auto
if /I "%app.mode%"=="menu" goto :main_menu
call :Cyan MODE: default [%app.version%]
call :RunBootstrapWorkflow
set "app.rc=%errorlevel%"
goto :end
:main_auto
call :Cyan MODE: auto [%app.version%]
call :RunAutoWorkflow
set "app.rc=%errorlevel%"
goto :end
:main_menu
call :Cyan MODE: menu [%app.version%]
call :ShowMenu
set "app.rc=%errorlevel%"
goto :end
:end
if defined app.final.cd cd /d "%app.final.cd%" >nul 2>&1
exit /b %app.rc%

:: ============================================================
:: Function: InitializeBootstrap
:: Usage: call :InitializeBootstrap
:: Purpose: initializes timestamp, log file, and colors.
:: Returns:
::   0 success
::   1 initialization failed

:: ============================================================
:InitializeBootstrap
call :SetESC app.esc
if errorlevel 1 set "app.esc="
if /I "%app.esc%"=="rem" set "app.esc="
call :MakeTimestamp
if errorlevel 1 exit /b 1
if not exist "%app.log.dir%\" mkdir "%app.log.dir%" >nul 2>&1
set "app.log=%app.log.dir%\bootstrap.%app.timestamp%.log"
break > "%app.log%"
call :Cyan LOG: %app.log%
exit /b 0

:: ============================================================
:: Function: MakeTimestamp
:: Usage: call :MakeTimestamp
:: Purpose: creates app.timestamp in YYYY-MM-DD.HHhmm.ss format.
:: Returns:
::   0 timestamp created
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
:: Purpose: parses bootstrap command-line arguments.
:: Accepted:
::   auto
::   menu
::   nologin
::   repo URL
::   branch NAME
::   dir PATH
::   fork ask|yes|no
::   move ask|no
::   help
:: Returns:
::   0 success
::   2 invalid argument

:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
echo %~1| findstr /B /I "http:// https://" >nul 2>nul
if not errorlevel 1 (set "app.repo.url=%~1" & shift & goto :ParseArgs)
if /I "%~1"=="auto" (set "app.auto=1" & set "app.mode=auto" & set "app.move.mode=documents" & shift & goto :ParseArgs)
if /I "%~1"=="menu" (set "app.mode=menu" & shift & goto :ParseArgs)
if /I "%~1"=="nologin" (set "app.login.mode=none" & shift & goto :ParseArgs)
if /I "%~1"=="repo" goto :ParseArgsRepo
if /I "%~1"=="provider" goto :ParseArgsProvider
if /I "%~1"=="toolsurl" goto :ParseArgsToolsUrl
if /I "%~1"=="getgit" goto :ParseArgsGetGit
if /I "%~1"=="getgithubcli" goto :ParseArgsGetGithubCLI
if /I "%~1"=="branch" goto :ParseArgsBranch
if /I "%~1"=="dir" goto :ParseArgsDir
if /I "%~1"=="fork" goto :ParseArgsFork
if /I "%~1"=="move" goto :ParseArgsMove
if /I "%~1"=="help" (set "app.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="/help" (set "app.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="--help" (set "app.help=1" & shift & goto :ParseArgs)
if /I "%~1"=="/?" (set "app.help=1" & shift & goto :ParseArgs)
call :Red FAIL: unknown argument: %~1
exit /b 2
:ParseArgsRepo
if "%~2"=="" (call :Red FAIL: repo requires a URL. & exit /b 2)
set "app.repo.url=%~2"
shift
shift
goto :ParseArgs
:ParseArgsProvider
if "%~2"=="" (call :Red FAIL: provider requires a name. & exit /b 2)
set "app.provider.requested=%~2"
shift
shift
goto :ParseArgs

:ParseArgsToolsUrl
if "%~2"=="" (call :Red FAIL: toolsurl requires a URL. & exit /b 2)
set "app.raw.tools.url=%~2"
shift
shift
goto :ParseArgs

:ParseArgsGetGit
if "%~2"=="" (call :Red FAIL: getgit requires a URL. & exit /b 2)
set "app.getgit.url=%~2"
shift
shift
goto :ParseArgs

:ParseArgsGetGithubCLI
if "%~2"=="" (call :Red FAIL: getgithubcli requires a URL. & exit /b 2)
set "app.getgh.url=%~2"
shift
shift
goto :ParseArgs

:ParseArgsBranch
if "%~2"=="" (call :Red FAIL: branch requires a name. & exit /b 2)
set "app.repo.branch=%~2"
shift
shift
goto :ParseArgs
:ParseArgsDir
if "%~2"=="" (call :Red FAIL: dir requires a path. & exit /b 2)
set "app.folder=%~2"
shift
shift
goto :ParseArgs
:ParseArgsFork
if "%~2"=="" (call :Red FAIL: fork requires ask, yes, or no. & exit /b 2)
set "app.fork.mode=%~2"
shift
shift
goto :ParseArgs
:ParseArgsMove
if "%~2"=="" (call :Red FAIL: move requires ask or no. & exit /b 2)
set "app.move.mode=%~2"
shift
shift
goto :ParseArgs

:: ============================================================
:: Function: ShowHelp
:: Usage: call :ShowHelp
:: Purpose: prints usage.
:: Returns:
::   0 always

:: ============================================================
:ShowHelp
call :Green Generic bootstrap.bat
echo.
call :Yellow Usage:
echo   bootstrap
echo   bootstrap auto
echo   bootstrap menu
echo   bootstrap nologin
echo   bootstrap repo https://host/user/repo.git
echo   bootstrap provider github^|gitlab^|bitbucket^|gitea^|git
echo   bootstrap toolsurl https://host/user/repo/raw/main/tools
echo   bootstrap getgit https://host/user/repo/raw/main/tools/GetGit.bat
echo   bootstrap branch main
echo   bootstrap dir C:\Path\Repo
echo   bootstrap fork ask
echo   bootstrap fork yes
echo   bootstrap fork no
echo.
call :Yellow Providers:
echo   github     clone/update, optional login, write check, fork
echo   gitlab     clone/update, raw helper URL inference, no login/fork yet
echo   bitbucket  clone/update, raw helper URL inference, no login/fork yet
echo   gitea      clone/update, raw helper URL inference, no login/fork yet
echo   git        clone/update only; use toolsurl/getgit if needed
echo.
call :Yellow Loader:
echo   cd /d %%TEMP%% ^& set "bootstrap=https://raw.githubusercontent.com/USER/REPO/main/tools/bootstrap.bat" ^& call curl.exe -sSLO "%%bootstrap%%" ^& bootstrap
echo.
call :Yellow Current:
echo   bootstrap: %app.bootstrap.url%
echo   provider:  %app.provider%
echo   repo:      %app.repo.url%
echo   tools:     %app.raw.tools.url%
echo   log:       %app.log%
exit /b 0

:ResolveBootstrapContext
if not defined app.repo.url if not defined app.bootstrap.url (call :Red FAIL: no repo URL and no bootstrap variable was provided. & call :Yellow TRY: bootstrap repo https://github.com/user/repo.git & exit /b 3)
if defined app.bootstrap.url call :InferFromBootstrapUrl
if defined app.repo.url call :InferFromRepoUrl
if defined app.provider.requested set "app.provider=%app.provider.requested%"
if not defined app.provider set "app.provider=git"
if not defined app.repo.url (call :Red FAIL: could not infer repo URL from bootstrap URL. & call :Yellow URL: %app.bootstrap.url% & exit /b 3)
if not defined app.getgit.url if defined app.raw.tools.url set "app.getgit.url=%app.raw.tools.url%/GetGit.bat"
if not defined app.getgh.url if defined app.raw.tools.url set "app.getgh.url=%app.raw.tools.url%/GetGithubCLI.bat"
if not defined app.getgit.url (call :Red FAIL: could not infer tools/GetGit.bat URL. & call :Yellow Use: bootstrap repo URL getgit URL & exit /b 3)
call :Green OK: Provider: %app.provider%
call :Green OK: Repo: %app.repo.url%
exit /b 0

:InferFromBootstrapUrl
for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$u=${env:app.bootstrap.url}; if(!$u){$u=$env:bootstrap}; if(!$u){exit 0}; $b=${env:app.repo.branch}; if(!$b){$b='main'}; $uri=[uri]$u; $s=$uri.Scheme; $h=$uri.Host.ToLowerInvariant(); $a=$uri.Authority; $p=$uri.AbsolutePath.Trim('/') -split '/'; $provider='git'; $owner=''; $repo=''; $branch=$b; $repoUrl=''; $raw=''; $repoPath=''; $gh='0'; if($h -eq 'raw.githubusercontent.com' -and $p.Length -ge 4){$provider='github';$owner=$p[0];$repo=$p[1];$branch=$p[2];$repoPath=$owner+'/'+$repo;$repoUrl='https://github.com/'+$repoPath+'.git';$raw='https://raw.githubusercontent.com/'+$repoPath+'/'+$branch+'/tools';$gh='1'} elseif($h -eq 'github.com' -and $p.Length -ge 4 -and $p[2] -eq 'blob'){$provider='github';$owner=$p[0];$repo=$p[1];$branch=$p[3];$repoPath=$owner+'/'+$repo;$repoUrl='https://github.com/'+$repoPath+'.git';$raw='https://raw.githubusercontent.com/'+$repoPath+'/'+$branch+'/tools';$gh='1'} elseif($h -like '*gitlab*' -and ($p -contains '-')){$provider='gitlab';$i=[array]::IndexOf($p,'-'); if($i -gt 0){$repo=$p[$i-1];$owner=($p[0..($i-2)] -join '/');$repoPath=($p[0..($i-1)] -join '/');$repoUrl=$s+'://'+$a+'/'+$repoPath+'.git';$j=$i+1; if($p.Length -gt ($j+1) -and ($p[$j] -eq 'raw' -or $p[$j] -eq 'blob')){$branch=$p[$j+1]};$raw=$s+'://'+$a+'/'+$repoPath+'/-/raw/'+$branch+'/tools'}} elseif($h -eq 'bitbucket.org' -and $p.Length -ge 4 -and ($p[2] -eq 'raw' -or $p[2] -eq 'src')){$provider='bitbucket';$owner=$p[0];$repo=$p[1];$branch=$p[3];$repoPath=$owner+'/'+$repo;$repoUrl='https://bitbucket.org/'+$repoPath+'.git';$raw='https://bitbucket.org/'+$repoPath+'/raw/'+$branch+'/tools'} elseif($p.Length -ge 4 -and ($p[2] -eq 'raw' -or $p[2] -eq 'src')){$provider='gitea';$owner=$p[0];$repo=$p[1];$branch=$p[3];$repoPath=$owner+'/'+$repo;$repoUrl=$s+'://'+$a+'/'+$repoPath+'.git';$raw=$s+'://'+$a+'/'+$repoPath+'/raw/'+$branch+'/tools'} else {if($p.Length -ge 1){$owner=$p[0]}; if($p.Length -ge 2){$repo=$p[1] -replace '\.git$','';$repoPath=$owner+'/'+$repo;$repoUrl=$s+'://'+$a+'/'+$repoPath+'.git'}; $left=$uri.GetLeftPart([System.UriPartial]::Path); if($left.LastIndexOf('/') -gt 0){$raw=$left.Substring(0,$left.LastIndexOf('/'))}}; if($provider){'provider='+$provider}; if($h){'repo.host='+$h}; if($repoPath){'repo.path='+$repoPath}; if($repoUrl){'repo.url='+$repoUrl}; if($owner){'repo.owner='+$owner}; if($repo){'repo.name='+$repo}; if($branch){'repo.branch='+$branch}; if($raw){'raw.tools.url='+$raw}; 'repo.github='+$gh"') do call :SetAppValue "%%A" "%%B"
exit /b 0

:InferFromRepoUrl
for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$orig=${env:app.repo.url}; if(!$orig){exit 0}; $b=${env:app.repo.branch}; if(!$b){$b='main'}; $parse=$orig -replace '^git@([^:]+):','https://$1/'; $parse=$parse -replace '^ssh://git@','https://'; $uri=[uri]$parse; $s=$uri.Scheme; $h=$uri.Host.ToLowerInvariant(); $a=$uri.Authority; $path=$uri.AbsolutePath.Trim('/') -replace '\.git$',''; $p=$path -split '/'; $provider='git';$owner='';$repo='';$repoPath=$path;$raw='';$gh='0'; if($p.Length -ge 1){$repo=$p[$p.Length-1]}; if($p.Length -ge 2){$owner=($p[0..($p.Length-2)] -join '/')}; if($h -eq 'github.com'){$provider='github';$gh='1'; if($p.Length -ge 2){$raw='https://raw.githubusercontent.com/'+$path+'/'+$b+'/tools'}} elseif($h -like '*gitlab*'){$provider='gitlab'; if($p.Length -ge 2){$raw=$s+'://'+$a+'/'+$path+'/-/raw/'+$b+'/tools'}} elseif($h -eq 'bitbucket.org'){$provider='bitbucket'; if($p.Length -ge 2){$raw='https://bitbucket.org/'+$path+'/raw/'+$b+'/tools'}} elseif($h -like '*codeberg.org' -or $h -like '*gitea*' -or $h -like '*forgejo*'){$provider='gitea'; if($p.Length -ge 2){$raw=$s+'://'+$a+'/'+$path+'/raw/'+$b+'/tools'}}; if($provider){'provider='+$provider}; if($h){'repo.host='+$h}; if($repoPath){'repo.path='+$repoPath}; if($owner){'repo.owner='+$owner}; if($repo){'repo.name='+$repo}; if($raw){'raw.tools.url='+$raw}; 'repo.github='+$gh"') do call :SetAppValue "%%A" "%%B"
if defined app.raw.tools.url if not defined app.getgit.url set "app.getgit.url=%app.raw.tools.url%/GetGit.bat"
if defined app.raw.tools.url if not defined app.getgh.url set "app.getgh.url=%app.raw.tools.url%/GetGithubCLI.bat"
exit /b 0

:SetAppValue
if "%~1"=="" exit /b 0
set "app.%~1=%~2"
exit /b 0

:: ============================================================
:: Function: ResolveRepoFolder
:: Usage: call :ResolveRepoFolder
:: Purpose: resolves the project folder path.
:: Returns:
::   0 success
::   3 repo name missing

:: ============================================================
:ResolveRepoFolder
if not defined app.repo.name (call :Red FAIL: could not determine repo name. & exit /b 3)
if not defined app.folder set "app.folder=%app.root%\%app.repo.name%"
for %%A in ("%app.folder%") do set "app.folder=%%~fA"
call :Green OK: Folder: %app.folder%
exit /b 0

:: ============================================================
:: Function: RunAutoWorkflow
:: Usage: call :RunAutoWorkflow
:: Purpose: runs the fully automatic workflow.
:: Returns:
::   0 success
::   nonzero failure

:: ============================================================
:RunAutoWorkflow
set "app.auto=1"
set "app.mode=auto"
set "app.move.mode=documents"
set "app.login.mode=none"
set "app.fork.mode=no"
echo AUTO: Git, clone/update, optional provider login, optional fork, move to Documents, prepare, build.
if defined app.log >>"%app.log%" echo AUTO: Git, clone/update, optional provider login, optional fork, move to Documents, prepare, build.
call :EnsureGit
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
call :CloneOrUpdateRepo
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
call :PromptAutoProviderLogin
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
if /I "%app.login.mode%"=="login" goto :RunAutoWorkflowGitHub
echo SKIP: provider login and fork steps skipped.
if defined app.log >>"%app.log%" echo SKIP: provider login and fork steps skipped.
goto :RunAutoWorkflowAfterGitHub

:RunAutoWorkflowGitHub
set "app.fork.mode=yes"
call :EnsureGitHubCLI
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
call :EnsureGitHubLogin
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
call :MaybeForkRepo
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
:RunAutoWorkflowAfterGitHub
call :MoveProjectToDocuments
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
call :RunPrepareStep
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
call :RunBuildStep
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
set "raw_rc="
call :Green OK: Auto bootstrap complete.
call :Green DIR: %app.folder%
exit /b 0

:: ============================================================
:: Function: RunBootstrapWorkflow
:: Usage: call :RunBootstrapWorkflow
:: Purpose: runs the normal or auto bootstrap workflow.
:: Returns:
::   0 success
::   nonzero failure

:: ============================================================
:RunBootstrapWorkflow
call :EnsureGit
set "rbw_rc=%errorlevel%"
if not "%rbw_rc%"=="0" exit /b %rbw_rc%
call :CloneOrUpdateRepo
set "rbw_rc=%errorlevel%"
if not "%rbw_rc%"=="0" exit /b %rbw_rc%
call :MaybeLoginAndFork
set "rbw_rc=%errorlevel%"
if not "%rbw_rc%"=="0" exit /b %rbw_rc%
call :MaybeMoveProject
set "rbw_rc=%errorlevel%"
if not "%rbw_rc%"=="0" exit /b %rbw_rc%
set "rbw_rc="
call :Green OK: Bootstrap complete.
call :Green DIR: %app.folder%
exit /b 0

:: ============================================================
:: Function: EnsureGit
:: Usage: call :EnsureGit
:: Purpose: finds Git or downloads/runs tools\GetGit.bat before cloning.
:: Returns:
::   0 Git ready
::   4 Git install failed

:: ============================================================
:EnsureGit
call :FindGitExe
if defined app.git (call :AddGitToPath & call :Green OK: Found Git: %app.git% & exit /b 0)
call :Yellow MISS: git.exe not found.
call :EnsureGetGitHelper
if errorlevel 1 exit /b 4
call :Yellow DO: Installing Git using tools\GetGit.bat.
cmd.exe /D /C call "%app.tools%\GetGit.bat" >> "%app.log%" 2>&1
set "eg_rc=%errorlevel%"
cd /d "%app.root%" >nul 2>&1
if not "%eg_rc%"=="0" (call :Red FAIL: GetGit.bat failed. & call :Yellow LOG: %app.log% & set "eg_rc=" & exit /b 4)
set "eg_rc="
call :FindGitExe
if not defined app.git (call :Red FAIL: Git is still missing after GetGit.bat. & call :Yellow LOG: %app.log% & exit /b 4)
call :AddGitToPath
call :Green OK: Git ready: %app.git%
exit /b 0

:: ============================================================
:: Function: ResolveGit
:: Usage: call :ResolveGit
:: Purpose: resolves local or PATH git.exe.
:: Returns:
::   0 always

:: ============================================================
:ResolveGit
call :FindGitExe
exit /b 0

:: ============================================================
:: Function: FindGitExe
:: Usage: call :FindGitExe
:: Purpose: resolves local or PATH git.exe into app.git.
:: Returns:
::   0 always

:: ============================================================
:FindGitExe
set "app.git="
if exist "%app.tools%\git\cmd\git.exe" for %%A in ("%app.tools%\git\cmd\git.exe") do set "app.git=%%~fA"
if not defined app.git if exist "%app.folder%\tools\git\cmd\git.exe" for %%A in ("%app.folder%\tools\git\cmd\git.exe") do set "app.git=%%~fA"
if not defined app.git for %%P in (git.exe) do set "app.git=%%~$PATH:P"
exit /b 0

:: ============================================================
:: Function: AddGitToPath
:: Usage: call :AddGitToPath
:: Purpose: prepends resolved git.exe folder to PATH so gh can find Git.
:: Returns:
::   0 always

:: ============================================================
:AddGitToPath
if not defined app.git exit /b 0
for %%A in ("%app.git%") do set "agtp_dir=%%~dpA"
if not defined agtp_dir exit /b 0
echo ;%PATH%;| find /I ";%agtp_dir%;" >nul 2>nul
if errorlevel 1 set "PATH=%agtp_dir%;%PATH%"
set "agtp_dir="
exit /b 0

:: ============================================================
:: Function: EnsureGetGitHelper
:: Usage: call :EnsureGetGitHelper
:: Purpose: downloads tools\GetGit.bat from the inferred tools URL.
:: Returns:
::   0 helper ready
::   4 helper missing/download failed

:: ============================================================
:EnsureGetGitHelper
if exist "%app.tools%\GetGit.bat" exit /b 0
if not exist "%app.tools%\" mkdir "%app.tools%" >nul 2>&1
if not defined app.getgit.url (call :Red FAIL: GetGit.bat URL is unknown. & exit /b 4)
call :Yellow GET: %app.getgit.url%
if exist "%app.tools%\GetGit.bat" del /Q "%app.tools%\GetGit.bat" >nul 2>&1
where curl.exe >nul 2>nul
if not errorlevel 1 curl.exe -L --fail --retry 3 -o "%app.tools%\GetGit.bat" "%app.getgit.url%" >> "%app.log%" 2>&1
if exist "%app.tools%\GetGit.bat" exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%app.getgit.url%' -OutFile '%app.tools%\GetGit.bat'" >> "%app.log%" 2>&1
if exist "%app.tools%\GetGit.bat" exit /b 0
call :Red FAIL: GetGit.bat was not downloaded.
exit /b 4

:: ============================================================
:: Function: CloneOrUpdateRepo
:: Usage: call :CloneOrUpdateRepo
:: Purpose: clones the repo or updates an existing checkout.
:: Returns:
::   0 cloned/updated
::   5 git operation failed

:: ============================================================
:CloneOrUpdateRepo
if not defined app.git call :EnsureGit
if not defined app.git (call :Red FAIL: git.exe is not ready. & exit /b 5)
if exist "%app.folder%\.git\" goto :CloneOrUpdateRepoUpdate
if not exist "%app.folder%\" goto :CloneOrUpdateRepoClone
call :QuarantineNonGitFolder
if errorlevel 1 exit /b 5
:CloneOrUpdateRepoClone
call :Yellow DO: Cloning %app.repo.url%.
"%app.git%" clone --branch "%app.repo.branch%" "%app.repo.url%" "%app.folder%" >> "%app.log%" 2>&1
if errorlevel 1 (call :Red FAIL: git clone failed. & call :Yellow LOG: %app.log% & exit /b 5)
call :Green OK: Repo cloned.
exit /b 0
:CloneOrUpdateRepoUpdate
call :Yellow DO: Updating existing repo.
pushd "%app.folder%" >nul
"%app.git%" fetch --all --prune >> "%app.log%" 2>&1
if errorlevel 1 (popd & call :Red FAIL: git fetch failed. & call :Yellow LOG: %app.log% & exit /b 5)
"%app.git%" checkout "%app.repo.branch%" >> "%app.log%" 2>&1
if errorlevel 1 (popd & call :Red FAIL: git checkout failed. & call :Yellow LOG: %app.log% & exit /b 5)
"%app.git%" pull --ff-only >> "%app.log%" 2>&1
if errorlevel 1 (popd & call :Yellow WARN: git pull --ff-only failed; continuing with checked out copy. & call :Yellow LOG: %app.log%)
popd >nul
call :Green OK: Repo ready.
exit /b 0

:: ============================================================
:: Function: QuarantineNonGitFolder
:: Usage: call :QuarantineNonGitFolder
:: Purpose: moves an existing non-Git target folder aside before cloning.
:: Returns:
::   0 folder moved/clear
::   5 folder could not be moved

:: ============================================================
:QuarantineNonGitFolder
set "qngf_old=%app.folder%.notgit.%app.timestamp%"
call :Yellow WARN: target folder exists but is not a Git checkout: %app.folder%
call :Yellow DO: Moving stale folder to %qngf_old%.
move "%app.folder%" "%qngf_old%" >> "%app.log%" 2>&1
if errorlevel 1 if not exist "%app.folder%\" (set "qngf_old=" & exit /b 0)
if errorlevel 1 (call :Red FAIL: could not move stale folder. & call :Yellow LOG: %app.log% & set "qngf_old=" & exit /b 5)
set "qngf_old="
exit /b 0

:: ============================================================
:: Function: PromptAutoGitHubLogin
:: Usage: call :PromptAutoProviderLogin
:: Purpose: asks whether auto mode should login to GitHub; Enter skips login and fork.
:: Returns:
::   0 always

:: ============================================================
:PromptAutoProviderLogin
if /I not "%app.provider%"=="github" (call :Yellow SKIP: %app.provider% provider has no login/fork plugin. & set "app.login.mode=none" & set "app.fork.mode=no" & exit /b 0)
set "paghl_choice="
echo GitHub login is optional.
if defined app.log >>"%app.log%" echo GitHub login is optional.
echo Press Enter to skip GitHub login and fork, or type y to login.
if defined app.log >>"%app.log%" echo Press Enter to skip GitHub login and fork, or type y to login.
set /p "paghl_choice=GitHub login? [y/N]: "
if /I "%paghl_choice%"=="y" goto :PromptAutoGitHubLoginYes
if /I "%paghl_choice%"=="yes" goto :PromptAutoGitHubLoginYes
if defined paghl_choice echo NOTE: input ignored; skipping GitHub login and fork.
if defined paghl_choice if defined app.log >>"%app.log%" echo NOTE: input ignored; skipping GitHub login and fork.
set "app.login.mode=none"
set "app.fork.mode=no"
set "paghl_choice="
exit /b 0

:PromptAutoGitHubLoginYes
set "app.login.mode=login"
set "app.fork.mode=yes"
set "paghl_choice="
exit /b 0

:: ============================================================
:: Function: MaybeLoginAndFork
:: Usage: call :MaybeLoginAndFork
:: Purpose: for GitHub repos, logs in and forks only when user lacks write access.
:: Returns:
::   0 success/skipped
::   6 GitHub CLI operation failed

:: ============================================================
:MaybeLoginAndFork
if /I "%app.provider%"=="github" goto :MaybeLoginAndForkGitHub
if /I "%app.login.mode%"=="none" exit /b 0
call :Yellow SKIP: %app.provider% provider has no login/fork plugin.
exit /b 0
:MaybeLoginAndForkGitHub
if /I "%app.login.mode%"=="none" (call :Yellow SKIP: GitHub login and fork steps skipped. & exit /b 0)
call :MaybePromptLoginSkip
set "mlaf_rc=%errorlevel%"
if not "%mlaf_rc%"=="0" exit /b %mlaf_rc%
if /I "%app.login.mode%"=="none" (call :Yellow SKIP: GitHub login and fork steps skipped. & exit /b 0)
call :EnsureGit
set "mlaf_rc=%errorlevel%"
if not "%mlaf_rc%"=="0" exit /b %mlaf_rc%
call :EnsureGitHubCLI
set "mlaf_rc=%errorlevel%"
if not "%mlaf_rc%"=="0" exit /b %mlaf_rc%
call :EnsureGitHubLogin
set "mlaf_rc=%errorlevel%"
if not "%mlaf_rc%"=="0" exit /b %mlaf_rc%
call :MaybeForkRepo
set "mlaf_rc=%errorlevel%"
if not "%mlaf_rc%"=="0" exit /b %mlaf_rc%
set "mlaf_rc="
exit /b 0

:MaybePromptLoginSkip
call :Yellow GitHub login is optional.
call :Yellow Press Enter to skip GitHub login and fork, or type y to login.
set "mpls_choice="
set /p "mpls_choice=GitHub login? [y/N]: "
if not defined mpls_choice goto :MaybePromptLoginSkipNo
if /I "%mpls_choice%"=="n" goto :MaybePromptLoginSkipNo
if /I "%mpls_choice%"=="no" goto :MaybePromptLoginSkipNo
if /I "%mpls_choice%"=="nologin" goto :MaybePromptLoginSkipNo
if /I "%mpls_choice%"=="y" goto :MaybePromptLoginSkipYes
if /I "%mpls_choice%"=="yes" goto :MaybePromptLoginSkipYes
call :Yellow NOTE: input ignored; skipping GitHub login and fork.
goto :MaybePromptLoginSkipNo
:MaybePromptLoginSkipYes
set "app.login.mode=ask"
set "mpls_choice="
exit /b 0
:MaybePromptLoginSkipNo
set "app.login.mode=none"
set "mpls_choice="
exit /b 0

:: ============================================================
:: Function: EnsureGitHubCLI
:: Usage: call :EnsureGitHubCLI
:: Purpose: finds or installs gh.exe using tools\GetGithubCLI.bat from the repo.
:: Returns:
::   0 gh ready
::   6 gh install failed

:: ============================================================
:EnsureGitHubCLI
call :AddGitToPath
call :FindGitHubCliExe
if defined app.gh if exist "%app.gh%" (call :Green OK: Found GitHub CLI: %app.gh% & exit /b 0)
set "app.gh="
if not exist "%app.folder%\tools\GetGithubCLI.bat" call :DownloadRepoGetGithubCLI
if not exist "%app.folder%\tools\GetGithubCLI.bat" (call :Red FAIL: tools\GetGithubCLI.bat was not found. & exit /b 6)
call :Yellow DO: Installing GitHub CLI using tools\GetGithubCLI.bat.
pushd "%app.folder%" >nul
cmd.exe /D /C call "tools\GetGithubCLI.bat" >> "%app.log%" 2>&1
set "egc_rc=%errorlevel%"
popd >nul 2>&1
cd /d "%app.root%" >nul 2>&1
if not "%egc_rc%"=="0" (call :Red FAIL: GetGithubCLI.bat failed. & call :Yellow LOG: %app.log% & set "egc_rc=" & exit /b 6)
set "egc_rc="
call :FindGitHubCliExe
if not defined app.gh (call :Red FAIL: gh.exe is still missing after GetGithubCLI.bat. & call :Yellow LOG: %app.log% & exit /b 6)
if not exist "%app.gh%" (call :Red FAIL: gh.exe path is invalid: %app.gh% & set "app.gh=" & call :Yellow LOG: %app.log% & exit /b 6)
call :Green OK: GitHub CLI ready: %app.gh%
exit /b 0

:: ============================================================
:: Function: ResolveGitHubCLI
:: Usage: call :ResolveGitHubCLI
:: Purpose: resolves local or PATH gh.exe.
:: Returns:
::   0 always

:: ============================================================
:ResolveGitHubCLI
call :FindGitHubCliExe
exit /b 0

:: ============================================================
:: Function: FindGitHubCliExe
:: Usage: call :FindGitHubCliExe
:: Purpose: resolves local or PATH gh.exe into app.gh.
:: Returns:
::   0 always

:: ============================================================
:FindGitHubCliExe
set "app.gh="
if exist "%app.folder%\tools\gh\bin\gh.exe" for %%A in ("%app.folder%\tools\gh\bin\gh.exe") do set "app.gh=%%~fA"
if not defined app.gh if exist "%app.tools%\gh\bin\gh.exe" for %%A in ("%app.tools%\gh\bin\gh.exe") do set "app.gh=%%~fA"
if not defined app.gh for %%P in (gh.exe) do set "app.gh=%%~$PATH:P"
if defined app.gh if not exist "%app.gh%" set "app.gh="
exit /b 0

:: ============================================================
:: Function: AddGitHubCliToPath
:: Usage: call :AddGitHubCliToPath
:: Purpose: prepends gh.exe's folder to PATH for child commands.
:: Returns:
::   0 always

:: ============================================================
:AddGitHubCliToPath
if not defined app.gh exit /b 0
for %%A in ("%app.gh%") do set "agctp_dir=%%~dpA"
if not defined agctp_dir exit /b 0
echo ;%PATH%;| find /I ";%agctp_dir%;" >nul 2>nul
if errorlevel 1 set "PATH=%agctp_dir%;%PATH%"
set "agctp_dir="
exit /b 0

:: ============================================================
:: Function: DownloadRepoGetGithubCLI
:: Usage: call :DownloadRepoGetGithubCLI
:: Purpose: downloads GetGithubCLI.bat into the cloned repo if missing.
:: Returns:
::   0 always

:: ============================================================
:DownloadRepoGetGithubCLI
if not defined app.getgh.url exit /b 0
if not exist "%app.folder%\tools\" mkdir "%app.folder%\tools" >nul 2>&1
call :Yellow GET: %app.getgh.url%
if exist "%app.folder%\tools\GetGithubCLI.bat" del /Q "%app.folder%\tools\GetGithubCLI.bat" >nul 2>&1
where curl.exe >nul 2>nul
if not errorlevel 1 curl.exe -L --fail --retry 3 -o "%app.folder%\tools\GetGithubCLI.bat" "%app.getgh.url%" >> "%app.log%" 2>&1
if exist "%app.folder%\tools\GetGithubCLI.bat" exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%app.getgh.url%' -OutFile '%app.folder%\tools\GetGithubCLI.bat'" >> "%app.log%" 2>&1
exit /b 0

:: ============================================================
:: Function: EnsureGitHubLogin
:: Usage: call :EnsureGitHubLogin
:: Purpose: runs gh auth login if needed and verifies the GitHub username.
:: Returns:
::   0 logged in and user verified
::   6 login failed

:: ============================================================
:EnsureGitHubLogin
call :FindGitHubCliExe
if not defined app.gh call :EnsureGitHubCLI
if not defined app.gh (call :Red FAIL: gh.exe is not ready. & exit /b 6)
if not exist "%app.gh%" (call :Red FAIL: gh.exe path is invalid: %app.gh% & set "app.gh=" & exit /b 6)
call :AddGitToPath
call :AddGitHubCliToPath
call :ConfigureGitCredentialHelper
call :IsGitHubLoggedIn
if not errorlevel 1 (call :Green OK: GitHub login ready: %app.github.user% & exit /b 0)
call :Yellow DO: GitHub login.
call :Yellow NOTE: A one-time code will be shown. Use any browser/device to enter it.
set "eghl_old_gh_browser=%GH_BROWSER%"
set "eghl_old_browser=%BROWSER%"
set "GH_BROWSER=echo"
set "BROWSER=echo"
echo. | "%app.gh%" auth login --web --git-protocol https
set "eghl_rc=%errorlevel%"
if defined eghl_old_gh_browser (set "GH_BROWSER=%eghl_old_gh_browser%") else (set "GH_BROWSER=")
if defined eghl_old_browser (set "BROWSER=%eghl_old_browser%") else (set "BROWSER=")
if not "%eghl_rc%"=="0" (call :Red FAIL: GitHub login failed. & set "eghl_rc=" & exit /b 6)
set "eghl_rc="
call :ConfigureGitCredentialHelper
"%app.gh%" auth setup-git >> "%app.log%" 2>&1
if errorlevel 1 call :Yellow WARN: gh auth setup-git failed; continuing because login may still be valid.
call :IsGitHubLoggedIn
if errorlevel 1 (call :Red FAIL: GitHub login was not confirmed. & call :Yellow LOG: %app.log% & exit /b 6)
call :Green OK: GitHub login ready: %app.github.user%
exit /b 0

:: ============================================================
:: Function: GetGitHubUser
:: Usage: call :GetGitHubUser
:: Purpose: captures the logged-in GitHub username in app.github.user.
:: Returns:
::   0 user captured
::   6 user could not be captured

:: ============================================================
:GetGitHubUser
set "app.github.user="
if not defined app.gh exit /b 6
for /f "usebackq delims=" %%A in (`"%app.gh%" api user --jq ".login" 2^>nul`) do if not defined app.github.user set "app.github.user=%%A"
if defined app.github.user exit /b 0
call :GetGitHubUserFromStatus
if defined app.github.user exit /b 0
exit /b 6

:: ============================================================
:: Function: IsGitHubLoggedIn
:: Usage: call :IsGitHubLoggedIn
:: Purpose: checks whether gh has an authenticated GitHub account and captures the user.
:: Returns:
::   0 logged in
::   6 not logged in or user unknown
:: ============================================================
:IsGitHubLoggedIn
if not defined app.gh exit /b 6
call :AddGitToPath
"%app.gh%" auth status -h github.com >> "%app.log%" 2>&1
if errorlevel 1 exit /b 6
call :GetGitHubUser
if errorlevel 1 exit /b 6
exit /b 0

:: ============================================================
:: Function: GetGitHubUserFromStatus
:: Usage: call :GetGitHubUserFromStatus
:: Purpose: parses gh auth status output as a fallback username source.
:: Returns:
::   0 user captured
::   6 user could not be captured
:: ============================================================
:GetGitHubUserFromStatus
set "ggufs_file=%app.log.dir%\gh.auth.%app.timestamp%.txt"
"%app.gh%" auth status -h github.com > "%ggufs_file%" 2>&1
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:ggufs_file; if(Test-Path -LiteralPath $p){$s=Get-Content -LiteralPath $p -Raw; if($s -match 'account\s+([A-Za-z0-9._-]+)'){ $matches[1] }}"`) do if not defined app.github.user set "app.github.user=%%A"
del "%ggufs_file%" >nul 2>&1
set "ggufs_file="
if defined app.github.user exit /b 0
exit /b 6

:: ============================================================
:: Function: ConfigureGitCredentialHelper
:: Usage: call :ConfigureGitCredentialHelper
:: Purpose: preselects Git Credential Manager to avoid Git's credential helper selector dialog.
:: Returns:
::   0 always
:: ============================================================
:ConfigureGitCredentialHelper
if not defined app.git exit /b 0
"%app.git%" config --global credential.helper manager >> "%app.log%" 2>&1
"%app.git%" config --global credential.helperselector.selected manager >> "%app.log%" 2>&1
exit /b 0

:: ============================================================
:: Function: MaybeForkRepo
:: Usage: call :MaybeForkRepo
:: Purpose: checks push permission and creates/configures fork when needed.
:: Returns:
::   0 success/skipped
::   6 fork failed

:: ============================================================
:MaybeForkRepo
if /I not "%app.provider%"=="github" exit /b 0
if not defined app.gh (call :Red FAIL: gh.exe is not ready; fork step cannot continue. & exit /b 6)
if not exist "%app.gh%" (call :Red FAIL: gh.exe path is invalid: %app.gh% & exit /b 6)
if not defined app.repo.owner (call :Red FAIL: repo owner is unknown; fork step cannot continue. & exit /b 6)
if not defined app.repo.name (call :Red FAIL: repo name is unknown; fork step cannot continue. & exit /b 6)
if not defined app.github.user call :GetGitHubUser
if errorlevel 1 (call :Red FAIL: could not determine GitHub user; fork step cannot continue. & exit /b 6)
for /f "tokens=* delims= " %%A in ("%app.github.user%") do set "app.github.user=%%A"
if /I "%app.github.user%"=="%app.repo.owner%" (call :Green OK: Logged in as repo owner; original repo is writable. & exit /b 0)
set "mfr_perm="
for /f "usebackq delims=" %%A in (`"%app.gh%" repo view "%app.repo.owner%/%app.repo.name%" --json viewerPermission --jq ".viewerPermission" 2^>nul`) do set "mfr_perm=%%A"
if /I "%mfr_perm%"=="ADMIN" (call :Green OK: You can push to original repo. & set "mfr_perm=" & exit /b 0)
if /I "%mfr_perm%"=="MAINTAIN" (call :Green OK: You can push to original repo. & set "mfr_perm=" & exit /b 0)
if /I "%mfr_perm%"=="WRITE" (call :Green OK: You can push to original repo. & set "mfr_perm=" & exit /b 0)
if not defined mfr_perm call :Yellow WARN: could not confirm write access to %app.repo.owner%/%app.repo.name%.
if defined mfr_perm call :Yellow MISS: You do not appear to have write access to %app.repo.owner%/%app.repo.name%.
if /I "%app.fork.mode%"=="no" (call :Yellow SKIP: fork not created. & set "mfr_perm=" & exit /b 0)
if not defined app.auto if /I "%app.fork.mode%"=="ask" call :AskForkChoice
if /I "%app.fork.mode%"=="no" (set "mfr_perm=" & exit /b 0)
if defined app.auto call :Yellow AUTO: creating/configuring fork because original repo is not writable.
call :CreateAndConfigureFork
set "mfr_rc=%errorlevel%"
set "mfr_perm="
exit /b %mfr_rc%

:: ============================================================
:: Function: CanPushToOrigin
:: Usage: call :CanPushToOrigin
:: Purpose: tests whether the current user can push to origin using git dry-run.
:: Returns:
::   0 push likely allowed
::   1 push not confirmed
:: ============================================================
:CanPushToOrigin
if not exist "%app.folder%\.git\" exit /b 1
pushd "%app.folder%" >nul
"%app.git%" remote get-url origin >nul 2>&1
if errorlevel 1 (popd >nul & exit /b 1)
"%app.git%" push --dry-run origin "HEAD:%app.repo.branch%" >> "%app.log%" 2>&1
set "cpto_rc=%errorlevel%"
popd >nul
if "%cpto_rc%"=="0" (set "cpto_rc=" & exit /b 0)
set "cpto_rc="
exit /b 1

:: ============================================================
:: Function: AskForkChoice
:: Usage: call :AskForkChoice
:: Purpose: asks whether to create/use a GitHub fork.
:: Returns:
::   0 always

:: ============================================================
:AskForkChoice
set "afc_choice="
set /p "afc_choice=Create/use a fork? [y/N]: "
if /I "%afc_choice%"=="y" set "app.fork.mode=yes"
if /I "%afc_choice%"=="yes" set "app.fork.mode=yes"
if /I not "%app.fork.mode%"=="yes" set "app.fork.mode=no"
set "afc_choice="
exit /b 0

:: ============================================================
:: Function: CreateAndConfigureFork
:: Usage: call :CreateAndConfigureFork
:: Purpose: creates GitHub fork and sets origin/upstream remotes.
:: Returns:
::   0 fork configured
::   6 fork failed

:: ============================================================
:CreateAndConfigureFork
if not defined app.gh (call :Red FAIL: gh.exe is not ready; fork cannot continue. & exit /b 6)
if not exist "%app.gh%" (call :Red FAIL: gh.exe path is invalid: %app.gh% & exit /b 6)
if not defined app.repo.owner (call :Red FAIL: repo owner is unknown; fork cannot continue. & exit /b 6)
if not defined app.repo.name (call :Red FAIL: repo name is unknown; fork cannot continue. & exit /b 6)
if not defined app.github.user call :GetGitHubUser
if errorlevel 1 (call :Red FAIL: could not determine GitHub user. & exit /b 6)
if /I "%app.github.user%"=="%app.repo.owner%" (call :Green OK: Logged in user owns original repo; fork is not needed. & exit /b 0)
call :Yellow DO: Creating or using fork %app.github.user%/%app.repo.name%.
"%app.gh%" repo fork "%app.repo.owner%/%app.repo.name%" --clone=false >> "%app.log%" 2>&1
if errorlevel 1 call :Yellow WARN: gh repo fork returned an error; it may already exist.
pushd "%app.folder%" >nul
"%app.git%" remote get-url upstream >nul 2>&1
if errorlevel 1 call :MoveOriginToUpstream
"%app.git%" remote get-url origin >nul 2>&1
if errorlevel 1 goto :CreateAndConfigureForkAddOrigin
"%app.git%" remote set-url origin "https://github.com/%app.github.user%/%app.repo.name%.git" >> "%app.log%" 2>&1
goto :CreateAndConfigureForkFetchOrigin
:CreateAndConfigureForkAddOrigin
"%app.git%" remote add origin "https://github.com/%app.github.user%/%app.repo.name%.git" >> "%app.log%" 2>&1
:CreateAndConfigureForkFetchOrigin
if errorlevel 1 (popd & cd /d "%app.root%" >nul 2>&1 & call :Red FAIL: could not configure fork remote. & exit /b 6)
"%app.git%" fetch origin >> "%app.log%" 2>&1
popd >nul 2>&1
cd /d "%app.root%" >nul 2>&1
call :Green OK: Fork remote configured.
exit /b 0

:: ============================================================
:: Function: MoveOriginToUpstream
:: Usage: call :MoveOriginToUpstream
:: Purpose: renames origin to upstream only when origin exists.
:: Returns:
::   0 always
:: ============================================================
:MoveOriginToUpstream
"%app.git%" remote get-url origin >nul 2>&1
if errorlevel 1 exit /b 0
"%app.git%" remote rename origin upstream >> "%app.log%" 2>&1
exit /b 0

:: ============================================================
:: Function: MaybeMoveProject
:: Usage: call :MaybeMoveProject
:: Purpose: optionally moves the project folder.
:: Returns:
::   0 moved/skipped
::   7 move failed

:: ============================================================
:MaybeMoveProject
if /I "%app.move.mode%"=="no" exit /b 0
if /I "%app.move.mode%"=="documents" goto :MoveProjectToDocuments
if /I "%app.move.mode%"=="ask" goto :AskMoveProject
exit /b 0
:AskMoveProject
set "app.choice="
call :Yellow Move project folder? Type n, y, or a destination path.
set /p "app.choice=Move to: "
if "%app.choice%"=="" exit /b 0
if /I "%app.choice%"=="n" exit /b 0
if /I "%app.choice%"=="no" exit /b 0
if /I "%app.choice%"=="y" goto :MoveProjectWithFolderPicker
if /I "%app.choice%"=="yes" goto :MoveProjectWithFolderPicker
call :MoveProjectToChosenFolder "%app.choice%"
exit /b %errorlevel%

:: ============================================================
:: Function: MoveProjectToDocuments
:: Usage: call :MoveProjectToDocuments
:: Purpose: moves project into the Windows Documents special folder.
:: Returns:
::   0 moved/skipped
::   7 move failed

:: ============================================================
:MoveProjectToDocuments
set "mptd_base="
for /f "delims=" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "[Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)"') do set "mptd_base=%%A"
if not defined mptd_base (call :Red FAIL: could not find Documents folder. & exit /b 7)
if /I "%mptd_base%"=="." (call :Red FAIL: Documents folder resolved to an invalid path. & exit /b 7)
call :MoveProjectToChosenFolder "%mptd_base%"
set "mptd_rc=%errorlevel%"
set "mptd_base="
exit /b %mptd_rc%

:: ============================================================
:: Function: MoveProjectWithFolderPicker
:: Usage: call :MoveProjectWithFolderPicker
:: Purpose: opens a Windows folder picker and moves project into chosen folder.
:: Returns:
::   0 moved/skipped
::   7 move failed

:: ============================================================
:MoveProjectWithFolderPicker
set "mpwfp_base="
for /f "delims=" %%A in ('powershell -NoProfile -STA -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description='Choose destination folder for project'; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$d.SelectedPath}"') do set "mpwfp_base=%%A"
if not defined mpwfp_base (call :Yellow MOVE: canceled; project kept at %app.folder% & exit /b 0)
call :MoveProjectToChosenFolder "%mpwfp_base%"
set "mpwfp_rc=%errorlevel%"
set "mpwfp_base="
exit /b %mpwfp_rc%

:: ============================================================
:: Function: MoveProjectToChosenFolder
:: Usage: call :MoveProjectToChosenFolder "destinationParent"
:: Purpose: moves app.folder into destinationParent\repoName.
:: Returns:
::   0 moved/skipped
::   7 move failed

:: ============================================================
:MoveProjectToChosenFolder
set "mptcf_parent=%~1"
if not defined mptcf_parent exit /b 0
if not defined app.repo.name (call :Red FAIL: repo name is unknown; cannot move project. & set "mptcf_parent=" & exit /b 7)
if not exist "%app.folder%\" (call :Red FAIL: project folder does not exist: %app.folder% & set "mptcf_parent=" & exit /b 7)
for %%A in ("%mptcf_parent%\%app.repo.name%") do set "app.final.folder=%%~fA"
if not defined app.final.folder (call :Red FAIL: destination could not be resolved. & set "mptcf_parent=" & exit /b 7)
if /I "%app.final.folder%"=="%app.folder%" (call :Green OK: Project already in destination. & set "app.final.cd=%app.folder%" & set "mptcf_parent=" & exit /b 0)
if exist "%app.final.folder%\" (call :Yellow WARN: destination already exists: %app.final.folder% & set "app.folder=%app.final.folder%" & set "app.final.cd=%app.folder%" & set "mptcf_parent=" & exit /b 0)
call :Yellow DO: Moving project to %app.final.folder%.
robocopy "%app.folder%" "%app.final.folder%" /E /MOVE >> "%app.log%" 2>&1
if errorlevel 8 (call :Red FAIL: project move failed. & call :Yellow LOG: %app.log% & set "mptcf_parent=" & exit /b 7)
set "app.folder=%app.final.folder%"
set "app.final.cd=%app.folder%"
call :Green OK: Project moved to %app.folder%.
set "mptcf_parent="
exit /b 0

:: ============================================================
:: Function: RunBuildStep
:: Usage: call :RunBuildStep
:: Purpose: runs prepare.bat then build.bat from the project folder when present.
:: Returns:
::   0 build succeeded or skipped
::   8 build failed

:: ============================================================
:RunBuildStep
if not exist "%app.folder%\build.bat" (call :Yellow SKIP: build.bat not found. & exit /b 0)
call :Yellow DO: Running build.bat.
pushd "%app.folder%" >nul
cmd.exe /D /C call build.bat >> "%app.log%" 2>&1
set "rbs_rc=%errorlevel%"
popd >nul
if not "%rbs_rc%"=="0" (call :Red FAIL: build.bat failed. & call :Yellow LOG: %app.log% & set "rbs_rc=" & exit /b 8)
set "rbs_rc="
call :Green OK: Build complete.
exit /b 0

:: ============================================================
:: Function: RunPrepareStep
:: Usage: call :RunPrepareStep
:: Purpose: runs prepare.bat from the project folder.
:: Returns:
::   0 success
::   8 prepare failed/missing

:: ============================================================
:RunPrepareStep
if not exist "%app.folder%\prepare.bat" (call :Red FAIL: prepare.bat not found in %app.folder% & exit /b 8)
pushd "%app.folder%" >nul
cmd.exe /D /C call prepare.bat
set "rps_rc=%errorlevel%"
popd >nul
exit /b %rps_rc%

:: ============================================================
:: Function: RunInstallStep
:: Usage: call :RunInstallStep
:: Purpose: runs install.bat from the project folder.
:: Returns:
::   0 success
::   8 install failed/missing

:: ============================================================
:RunInstallStep
if not exist "%app.folder%\install.bat" (call :Red FAIL: install.bat not found in %app.folder% & exit /b 8)
pushd "%app.folder%" >nul
cmd.exe /D /C call install.bat
set "ris_rc=%errorlevel%"
popd >nul
exit /b %ris_rc%

:: ============================================================
:: Function: ShowMenu
:: Usage: call :ShowMenu
:: Purpose: shows a DOS-style interactive text menu.
:: Returns:
::   0 user exited

:: ============================================================
:ShowMenu
call :MenuLoop
exit /b 0

:: ============================================================
:: Function: MenuLoop
:: Usage: call :MenuLoop
:: Purpose: interactive menu loop.
:: Returns:
::   0 user exited

:: ============================================================
:MenuLoop
cls
call :DrawMenu
set "ml_choice="
set /p "ml_choice=Choose [1-8, A=auto, 0=exit]: "
if /I "%ml_choice%"=="a" goto :MenuAuto
if /I "%ml_choice%"=="auto" goto :MenuAuto
if "%ml_choice%"=="1" goto :MenuClone
if "%ml_choice%"=="2" goto :MenuLogin
if "%ml_choice%"=="3" goto :MenuFork
if "%ml_choice%"=="4" goto :MenuPrepare
if "%ml_choice%"=="5" goto :MenuBuild
if "%ml_choice%"=="6" goto :MenuInstall
if "%ml_choice%"=="7" goto :MenuMove
if "%ml_choice%"=="8" goto :MenuFull
if "%ml_choice%"=="0" exit /b 0
call :Yellow Choose 1-8, A, or 0.
pause
goto :MenuLoop
:MenuAuto
call :RunAutoWorkflow
pause
goto :MenuLoop
:MenuClone
call :EnsureGit
if not errorlevel 1 call :CloneOrUpdateRepo
pause
goto :MenuLoop
:MenuLogin
call :EnsureGit
if not errorlevel 1 call :EnsureGitHubCLI
if not errorlevel 1 call :EnsureGitHubLogin
pause
goto :MenuLoop
:MenuFork
call :EnsureGit
if not errorlevel 1 call :EnsureGitHubCLI
if not errorlevel 1 call :EnsureGitHubLogin
if not errorlevel 1 call :MaybeForkRepo
pause
goto :MenuLoop
:MenuPrepare
call :RunPrepareStep
pause
goto :MenuLoop
:MenuBuild
call :RunBuildStep
pause
goto :MenuLoop
:MenuInstall
call :RunInstallStep
pause
goto :MenuLoop
:MenuMove
set "app.move.mode=ask"
call :MaybeMoveProject
pause
goto :MenuLoop
:MenuFull
call :RunBootstrapWorkflow
pause
goto :MenuLoop

:: ============================================================
:: Function: DrawMenu
:: Usage: call :DrawMenu
:: Purpose: draws the DOS-style menu without passing pipe characters through CALL.
:: Returns:
::   0 always

:: ============================================================
:DrawMenu
if defined app.esc goto :DrawMenuColor
echo +------------------------------------------------------------+
echo ^|                   Generic Bootstrap Menu                 ^|
echo +------------------------------------------------------------+
echo ^|  1  Clone or update repo                                  ^|
echo ^|  2  Provider login                                      ^|
echo ^|  3  Fork/configure remotes if supported                 ^|
echo ^|  4  Run prepare.bat                                       ^|
echo ^|  5  Run build.bat                                         ^|
echo ^|  6  Run install.bat                                       ^|
echo ^|  7  Move project folder                                   ^|
echo ^|  8  Run full bootstrap                                    ^|
echo ^|  A  Auto: clone, optional login, Documents, build       ^|
echo ^|  0  Exit                                                  ^|
echo +------------------------------------------------------------+
exit /b 0
:DrawMenuColor
echo %app.esc%[%app.color.cyan%+------------------------------------------------------------+%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|                   Generic Bootstrap Menu                 ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%+------------------------------------------------------------+%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|  1  Clone or update repo                                  ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|  2  Provider login                                      ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|  3  Fork/configure remotes if supported                 ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|  4  Run prepare.bat                                       ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|  5  Run build.bat                                         ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|  6  Run install.bat                                       ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|  7  Move project folder                                   ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|  8  Run full bootstrap                                    ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|  A  Auto: clone, optional login, Documents, build       ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%^|  0  Exit                                                  ^|%app.esc%[%app.color.reset%
echo %app.esc%[%app.color.cyan%+------------------------------------------------------------+%app.esc%[%app.color.reset%
exit /b 0

:: ============================================================
:: Function: DownloadFile
:: Usage: call :DownloadFile "url" "file"
:: Purpose: downloads a file using curl, then PowerShell fallback.
:: Returns:
::   0 downloaded
::   4 download failed

:: ============================================================
:DownloadFile
set "df_url=%~1"
set "df_file=%~2"
if exist "%df_file%" del /Q "%df_file%" >nul 2>&1
where curl.exe >nul 2>nul
if not errorlevel 1 curl.exe -L --fail --retry 3 -o "%df_file%" "%df_url%" >> "%app.log%" 2>&1
if exist "%df_file%" goto :DownloadFileOK
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%df_url%' -OutFile '%df_file%'" >> "%app.log%" 2>&1
if exist "%df_file%" goto :DownloadFileOK
call :Red FAIL: download failed.
call :Yellow URL: %df_url%
set "df_url="
set "df_file="
exit /b 4
:DownloadFileOK
set "df_url="
set "df_file="
exit /b 0

:: ============================================================
:: Function: SetESC
:: Usage: call :SetESC outputVariable
:: Purpose: captures ANSI escape character.
:: Returns:
::   0 success
::   2 missing output variable

:: ============================================================
:SetESC
set "se_out=%~1"
if not defined se_out exit /b 2
for /f %%a in ('echo prompt $E^| cmd') do set "%se_out%=%%a"
set "se_out="
exit /b 0

:: ============================================================
:: Function: Green
:: Usage: call :Green message
:: Purpose: prints/logs green status.
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
:: Purpose: prints/logs yellow status.
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
:: Purpose: prints/logs red status.
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
:: Purpose: prints/logs cyan status.
:: Returns:
::   0 always

:: ============================================================
:Cyan
if defined app.esc (echo %app.esc%[%app.color.cyan%%*%app.esc%[%app.color.reset%) else (echo %*)
if defined app.log >>"%app.log%" echo %*
exit /b 0
