@echo off
:: ============================================================
:: git_status_summary.bat
:: Read-only branch and working-tree summary for Git repositories.
::
:: This helper does not:
::   - stage files
::   - modify files
::   - commit
::   - fetch
::   - pull
::   - push
::   - change Git configuration
::
:: Ahead/behind information uses the locally known upstream tracking
:: reference. Run the normal publish/login workflow when network state
:: must be refreshed.
::
:: Active placement:
::   tools\git_status_summary.bat
::
:: Root launcher:
::   just_status.bat
::
:: Usage:
::   call git_status_summary.bat
::   call git_status_summary.bat help
::
:: Returns: 0 when repository status was shown
::          1 when Git or the repository is unavailable
::          2 on an unknown argument
:: Requires: git.exe, where.exe, find.exe
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_status.rc=0"
set "app.git_status.root="
set "app.git_status.git="
set "app.git_status.branch="
set "app.git_status.upstream="
set "app.git_status.ahead="
set "app.git_status.behind="
set "app.git_status.origin="
set "app.git_status.detached="
set "app.git_status.request=%~1"
if defined GIT_PROJECT_ROOT set "app.git_status.root=%GIT_PROJECT_ROOT%"
if not defined app.git_status.root for %%A in ("%~dp0..") do set "app.git_status.root=%%~fA"
for %%A in ("%app.git_status.root%\.") do set "app.git_status.root=%%~fA"
if not defined app.git_status.request goto :main
if /I "%app.git_status.request%"=="help" goto :help
if /I "%app.git_status.request%"=="--help" goto :help
if /I "%app.git_status.request%"=="/help" goto :help
if /I "%app.git_status.request%"=="/?" goto :help
echo.
echo ERROR: Unknown status argument:
echo   %app.git_status.request%
echo.
set "app.git_status.rc=2"
goto :end
:main
call :ResolveGit
set "app.git_status.rc=%errorlevel%"
if not "%app.git_status.rc%"=="0" goto :end
cd /d "%app.git_status.root%"
set "app.git_status.rc=%errorlevel%"
if "%app.git_status.rc%"=="0" goto :_main_repository
echo.
echo ERROR: Could not enter the project root:
echo   "%app.git_status.root%"
echo.
set "app.git_status.rc=1"
goto :end
:_main_repository
git.exe rev-parse --is-inside-work-tree >nul 2>nul
set "app.git_status.rc=%errorlevel%"
if "%app.git_status.rc%"=="0" goto :_main_collect
echo.
echo ERROR: Project root is not inside a Git worktree:
echo   "%app.git_status.root%"
echo.
set "app.git_status.rc=1"
goto :end
:_main_collect
call :CollectRepositoryInfo
set "app.git_status.rc=%errorlevel%"
if not "%app.git_status.rc%"=="0" goto :end
call :ShowSummary
set "app.git_status.rc=%errorlevel%"
goto :end
:help
echo.
echo git_status_summary.bat
echo.
echo Usage:
echo   just_status.bat
echo   tools\git_status_summary.bat
echo.
echo Shows:
echo   repository root and origin
echo   current branch and upstream
echo   locally known ahead/behind counts
echo   concise staged, unstaged, and untracked file status
echo   staged and unstaged diff summaries
echo   five recent commits
echo.
echo This helper is read-only and performs no network operations.
echo.
set "app.git_status.rc=0"
:end
call :PauseIfNeeded
exit /b %app.git_status.rc%
:: ============================================================
:: :ResolveGit
:: Resolves git.exe from PATH.
::
:: Usage: call :ResolveGit
::
:: Output:
::   app.git_status.git
::
:: Returns: 0 when found, 1 when missing
:: Requires: where.exe
:: ============================================================
:ResolveGit
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined app.git_status.git set "app.git_status.git=%%~fG"
if defined app.git_status.git exit /b 0
echo.
echo ERROR: git.exe was not found in PATH.
echo Run prepare.bat repository or install Git first.
echo.
exit /b 1
:: ============================================================
:: :CollectRepositoryInfo
:: Collects branch, upstream, ahead/behind, and origin information.
::
:: Usage: call :CollectRepositoryInfo
::
:: Returns: 0
:: Requires: git.exe
:: ============================================================
:CollectRepositoryInfo
set "app.git_status.branch="
set "app.git_status.upstream="
set "app.git_status.ahead="
set "app.git_status.behind="
set "app.git_status.origin="
set "app.git_status.detached="
for /f "usebackq delims=" %%B in (`git.exe branch --show-current 2^>nul`) do if not defined app.git_status.branch set "app.git_status.branch=%%B"
if defined app.git_status.branch goto :_CollectRepositoryInfo_upstream
for /f "usebackq delims=" %%H in (`git.exe rev-parse --short HEAD 2^>nul`) do if not defined app.git_status.detached set "app.git_status.detached=%%H"
:_CollectRepositoryInfo_upstream
for /f "usebackq delims=" %%U in (`git.exe rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2^>nul`) do if not defined app.git_status.upstream set "app.git_status.upstream=%%U"
if not defined app.git_status.upstream goto :_CollectRepositoryInfo_origin
for /f "usebackq tokens=1,2" %%A in (`git.exe rev-list --left-right --count HEAD..."@{upstream}" 2^>nul`) do if not defined app.git_status.ahead set "app.git_status.ahead=%%A" & set "app.git_status.behind=%%B"
:_CollectRepositoryInfo_origin
for /f "usebackq delims=" %%U in (`git.exe remote get-url origin 2^>nul`) do if not defined app.git_status.origin set "app.git_status.origin=%%U"
exit /b 0
:: ============================================================
:: :ShowSummary
:: Prints branch state, file status, diff summaries, and recent commits.
::
:: Usage: call :ShowSummary
::
:: Returns: 0
:: Requires: git.exe
:: ============================================================
:ShowSummary
echo.
echo ============================================================
echo  Git status summary
echo ============================================================
echo.
echo Repository:
echo   %app.git_status.root%
echo.
echo Git:
echo   %app.git_status.git%
echo.
echo Origin:
if defined app.git_status.origin echo   %app.git_status.origin%
if not defined app.git_status.origin echo   not configured
echo.
echo Branch:
if defined app.git_status.branch echo   %app.git_status.branch%
if not defined app.git_status.branch if defined app.git_status.detached echo   detached at %app.git_status.detached%
if not defined app.git_status.branch if not defined app.git_status.detached echo   unavailable
echo.
echo Upstream:
if defined app.git_status.upstream echo   %app.git_status.upstream%
if not defined app.git_status.upstream echo   not configured
if defined app.git_status.upstream echo.
if defined app.git_status.upstream echo Locally known synchronization:
if defined app.git_status.upstream if defined app.git_status.ahead echo   ahead:  %app.git_status.ahead%
if defined app.git_status.upstream if defined app.git_status.behind echo   behind: %app.git_status.behind%
if defined app.git_status.upstream if not defined app.git_status.ahead echo   unavailable
echo.
echo Concise working-tree status:
git.exe --no-pager status --short --branch --untracked-files=all
set "ss_rc=%errorlevel%"
if not "%ss_rc%"=="0" exit /b %ss_rc%
echo.
echo Staged diff summary:
git.exe --no-pager diff --cached --stat
set "ss_rc=%errorlevel%"
if not "%ss_rc%"=="0" exit /b %ss_rc%
echo.
echo Unstaged diff summary:
git.exe --no-pager diff --stat
set "ss_rc=%errorlevel%"
if not "%ss_rc%"=="0" exit /b %ss_rc%
echo.
echo Recent commits:
git.exe --no-pager log -5 --oneline --decorate
set "ss_rc=%errorlevel%"
if not "%ss_rc%"=="0" exit /b %ss_rc%
echo.
exit /b 0
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when the outermost launch target is cmd.exe /c.
::
:: Usage: call :PauseIfNeeded
::
:: Returns: 0
:: Requires: :IsConsole
:: ============================================================
:PauseIfNeeded
call :IsConsole
if not errorlevel 1 exit /b 0
echo.
pause
exit /b 0
:: ============================================================
:: :IsConsole
:: Detects whether execution is already inside an interactive console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 for an existing console
::          1 when app.launch.name is the outer cmd.exe /c target
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
