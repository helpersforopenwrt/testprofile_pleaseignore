@echo off
:setup
set "app.start.dir=%CD%"
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
for %%A in ("%~dp0.") do set "app.script.dir=%%~fA"
cd /d "%app.script.dir%" >nul 2>&1
set "app.version=bootstrap-integrated-39.3"
set "app.rc=0"
set "app.timestamp="
set "app.log.dir=%TEMP%\bootstrap_logs"
set "app.log="
set "app.bootstrap.url=%bootstrap%"
set "app.repo.url="
set "app.repo.original.url="
set "app.repo.owner="
set "app.repo.name="
set "app.repo.branch=main"
set "app.repo.parent="
set "app.repo.ready="
set "app.repo.tools.prepared="
set "app.repo.sync.remote=origin"
set "app.provider="
set "app.provider.requested="
set "app.provider.display=Generic Git"
set "app.provider.can.login=0"
set "app.provider.can.fork=0"
set "app.raw.tools.url="
set "app.getgit.url="
set "app.getgh.url="
set "app.folder="
set "app.folder.origin="
set "app.folder.origin.normalized="
set "app.folder.upstream="
set "app.folder.upstream.normalized="
set "app.repo.url.normalized="
set "app.final.folder="
set "app.final.cd=%app.start.dir%"
set "app.tools=%app.script.dir%\tools"
if exist "%app.script.dir%\GetGit.bat" set "app.tools=%app.script.dir%"
set "app.git="
set "app.gh="
set "app.github.user="
set "app.git_name="
set "app.git_email="
set "app.mode=default"
set "app.dryrun="
set "app.unattended="
set "app.project.prepare=yes"
set "app.project.build=yes"
set "app.project.install=no"
set "app.update.mode=yes"
set "app.conflict.mode=quarantine"
set "app.login.mode=ask"
set "app.login.method=ask"
set "app.fork.mode=ask"
set "app.identity.mode=ask"
set "app.push.mode=yes"
set "app.move.mode=no"
set "app.move.parent="
set "app.explicit.repo="
set "app.explicit.branch="
set "app.explicit.provider="
set "app.explicit.toolsurl="
set "app.explicit.login="
set "app.explicit.fork="
set "app.explicit.identity="
set "app.explicit.push="
set "app.explicit.move="
set "app.explicit.prepare="
set "app.explicit.build="
set "app.explicit.install="
set "app.explicit.update="
set "app.explicit.conflict="
set "app.esc="
set "app.color.reset=0m"
set "app.color.red=31m"
set "app.color.green=32m"
set "app.color.yellow=33m"
set "app.color.cyan=36m"
goto :main

:main
call :ParseArguments %*
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
call :ApplyAutomationDefaults
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
if /I "%app.mode%"=="help" call :ShowHelp
if /I "%app.mode%"=="help" set "app.rc=%errorlevel%"
if /I "%app.mode%"=="help" goto :end
if /I "%app.mode%"=="version" call :ShowVersion
if /I "%app.mode%"=="version" set "app.rc=%errorlevel%"
if /I "%app.mode%"=="version" goto :end
call :InitializeRuntime
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
call :ResolveBootstrapContext
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
call :ResolveRepositoryFolder
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
call :ConfigureProvider
set "app.rc=%errorlevel%"
if not "%app.rc%"=="0" goto :end
call :DispatchMode
set "app.rc=%errorlevel%"
goto :end

:end
call :WarnIfTemporaryRepository
if defined app.final.cd cd /d "%app.final.cd%" >nul 2>&1
call :SetExitCode "%app.rc%"
goto :eof

:: ============================================================
:: HIGH LEVEL WORKFLOW FUNCTIONS
:: ============================================================

:DispatchMode
rem ============================================================
rem Function DispatchMode
rem Purpose
rem   Run exactly one selected top-level mode and return its result.
rem Inputs
rem   app.mode and app.dryrun
rem Return codes
rem   0 Selected mode completed
rem   nonzero Selected mode failed
rem Dependencies
rem   RunCheck RunDoctor RunDryRun RunAutoWorkflow RunBootstrapWorkflow RunMenu
rem ============================================================
set "dm_mode=%app.mode%"
set "dm_dryrun=%app.dryrun%"
set "dm_rc=0"
if defined dm_dryrun call :RunDryRun
if defined dm_dryrun set "dm_rc=%errorlevel%"
if defined dm_dryrun exit /b %dm_rc%
if /I "%dm_mode%"=="check" call :RunCheck
if /I "%dm_mode%"=="check" set "dm_rc=%errorlevel%"
if /I "%dm_mode%"=="check" exit /b %dm_rc%
if /I "%dm_mode%"=="doctor" call :RunDoctor
if /I "%dm_mode%"=="doctor" set "dm_rc=%errorlevel%"
if /I "%dm_mode%"=="doctor" exit /b %dm_rc%
if /I "%dm_mode%"=="auto" call :RunAutoWorkflow
if /I "%dm_mode%"=="auto" set "dm_rc=%errorlevel%"
if /I "%dm_mode%"=="auto" exit /b %dm_rc%
if /I "%dm_mode%"=="menu" call :RunMenu
if /I "%dm_mode%"=="menu" set "dm_rc=%errorlevel%"
if /I "%dm_mode%"=="menu" exit /b %dm_rc%
call :RunBootstrapWorkflow
set "dm_rc=%errorlevel%"
exit /b %dm_rc%

:RunAutoWorkflow
rem ============================================================
rem Function RunAutoWorkflow
rem Purpose
rem   Run repository setup and then run the project lifecycle.
rem Outputs
rem   app.final.cd
rem Return codes
rem   0 Auto workflow completed
rem   nonzero A workflow step failed
rem Dependencies
rem   RunRepositoryWorkflow RunProjectLifecycle PrintInfo PrintSuccess
rem ============================================================
call :PrintInfo "MODE: auto [%app.version%]"
call :PrintInfo "AUTO: Git, clone or update, repository tools, optional login and fork, optional move, prepare, build, and optional install."
call :RunRepositoryWorkflow
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
call :RunProjectLifecycle
set "raw_rc=%errorlevel%"
if not "%raw_rc%"=="0" exit /b %raw_rc%
if not defined app.final.cd set "app.final.cd=%app.folder%"
call :PrintSuccess "OK: Auto bootstrap complete."
call :PrintSuccess "DIR: %app.folder%"
set "raw_rc="
exit /b 0

:RunBootstrapWorkflow
rem ============================================================
rem Function RunBootstrapWorkflow
rem Purpose
rem   Run repository setup without automatically preparing or building the project.
rem Outputs
rem   app.final.cd
rem Return codes
rem   0 Bootstrap workflow completed
rem   nonzero A workflow step failed
rem Dependencies
rem   RunRepositoryWorkflow PrintInfo PrintSuccess
rem ============================================================
call :PrintInfo "MODE: default [%app.version%]"
call :RunRepositoryWorkflow
set "rbw_rc=%errorlevel%"
if not "%rbw_rc%"=="0" exit /b %rbw_rc%
if not defined app.final.cd set "app.final.cd=%app.folder%"
call :PrintSuccess "OK: Bootstrap complete."
call :PrintSuccess "DIR: %app.folder%"
set "rbw_rc="
exit /b 0

:RunRepositoryWorkflow
rem ============================================================
rem Function RunRepositoryWorkflow
rem Purpose
rem   Run the shared repository workflow used by default and auto modes.
rem   The sequence is repository readiness, optional provider login and fork, then optional move.
rem Outputs
rem   app.repo.ready app.final.cd
rem Return codes
rem   0 Repository workflow completed
rem   nonzero A workflow step failed
rem Dependencies
rem   EnsureRepositoryReady ResolveLoginDecision RunProviderLogin MaybeMoveRepository
rem ============================================================
call :EnsureRepositoryReady
set "rrw_rc=%errorlevel%"
if not "%rrw_rc%"=="0" exit /b %rrw_rc%
call :ResolveLoginDecision
set "rrw_rc=%errorlevel%"
if not "%rrw_rc%"=="0" exit /b %rrw_rc%
call :RunProviderLogin
set "rrw_rc=%errorlevel%"
if not "%rrw_rc%"=="0" exit /b %rrw_rc%
call :MaybeMoveRepository
set "rrw_rc=%errorlevel%"
if not "%rrw_rc%"=="0" exit /b %rrw_rc%
set "rrw_rc="
exit /b 0

:EnsureRepositoryReady
rem ============================================================
rem Function EnsureRepositoryReady
rem Purpose
rem   Ensure Git is available, clone or update the checkout, and prepare repository tools.
rem Outputs
rem   app.repo.ready app.repo.tools.prepared app.final.cd
rem Return codes
rem   0 Repository and repository tools are ready
rem   nonzero Git, synchronization, or repository preparation failed
rem Dependencies
rem   EnsureGit SynchronizeRepository PrepareRepositoryTools
rem ============================================================
if defined app.repo.ready goto :EnsureRepositoryReadyPrepare
call :EnsureGit
set "err_rc=%errorlevel%"
if not "%err_rc%"=="0" exit /b %err_rc%
call :SynchronizeRepository
set "err_rc=%errorlevel%"
if not "%err_rc%"=="0" exit /b %err_rc%
:EnsureRepositoryReadyPrepare
call :PrepareRepositoryTools
set "err_rc=%errorlevel%"
if not "%err_rc%"=="0" exit /b %err_rc%
set "err_rc="
exit /b 0

:RunProjectLifecycle
rem ============================================================
rem Function RunProjectLifecycle
rem Purpose
rem   Run project preparation, build, and installation according to independent command-line decisions.
rem Return codes
rem   0 Requested lifecycle steps completed
rem   8 A requested project lifecycle step failed
rem Dependencies
rem   RunProjectPrepare RunProjectBuild RunProjectInstall PrintWarning PrintInfo
rem ============================================================
set "rpl_rc=0"
if /I "%app.project.prepare%"=="yes" call :RunProjectPrepare
if /I "%app.project.prepare%"=="yes" set "rpl_rc=%errorlevel%"
if not "%rpl_rc%"=="0" exit /b %rpl_rc%
if /I not "%app.project.prepare%"=="yes" call :PrintWarning "SKIP: project preparation disabled."
if /I "%app.project.build%"=="yes" call :RunProjectBuild
if /I "%app.project.build%"=="yes" set "rpl_rc=%errorlevel%"
if not "%rpl_rc%"=="0" exit /b %rpl_rc%
if /I not "%app.project.build%"=="yes" call :PrintWarning "SKIP: project build disabled."
if /I "%app.project.install%"=="yes" call :RunProjectInstall
if /I "%app.project.install%"=="yes" set "rpl_rc=%errorlevel%"
if not "%rpl_rc%"=="0" exit /b %rpl_rc%
if /I not "%app.project.install%"=="yes" call :PrintInfo "SKIP: project installation not requested."
set "rpl_rc="
exit /b 0

:RunCheck
rem ============================================================
rem Function RunCheck
rem Purpose
rem   Validate inferred repository context without installing tools or changing repository files.
rem Return codes
rem   0 Required context is present
rem   3 Required context is missing
rem Dependencies
rem   FindGit PrintSuccess PrintInfo PrintError PrintWarning
rem ============================================================
call :PrintInfo "CHECK: essential bootstrap context"
call :PrintInfo "Version: %app.version%"
call :PrintInfo "Provider: %app.provider% [%app.provider.display%]"
call :PrintInfo "Repository: %app.repo.url%"
call :PrintInfo "Branch: %app.repo.branch%"
call :PrintInfo "Folder: %app.folder%"
call :PrintInfo "GetGit URL: %app.getgit.url%"
if not defined app.repo.url (call :PrintError "FAIL: repository URL is missing." & exit /b 3)
if not defined app.repo.name (call :PrintError "FAIL: repository name is missing." & exit /b 3)
if not defined app.getgit.url call :FindGit
if not defined app.getgit.url if not defined app.git (call :PrintError "FAIL: Git is unavailable and no GetGit.bat URL could be inferred." & call :PrintWarning "Use getgit URL on the command line." & exit /b 3)
if not defined app.getgit.url if defined app.git call :PrintInfo "INFO: GetGit.bat URL is unnecessary because Git is already available."
call :PrintSuccess "OK: essential check passed."
exit /b 0

:RunDoctor
rem ============================================================
rem Function RunDoctor
rem Purpose
rem   Report context, tool, checkout, provider, and lifecycle diagnostics without making changes.
rem Return codes
rem   0 Diagnostics completed
rem   3 Essential context check failed
rem   5 Existing checkout references an unexpected repository
rem Dependencies
rem   RunCheck FindGit FindGitHubCli VerifyRepositoryRemote PrintInfo PrintSuccess PrintWarning PrintError
rem ============================================================
call :RunCheck
set "rd_rc=%errorlevel%"
if not "%rd_rc%"=="0" exit /b %rd_rc%
call :PrintInfo "Provider login capability: %app.provider.can.login%"
call :PrintInfo "Provider fork capability: %app.provider.can.fork%"
call :FindGit
if defined app.git call :PrintSuccess "OK: Git found at %app.git%"
if not defined app.git call :PrintWarning "MISS: git.exe was not found; bootstrap would install it."
call :FindGitHubCli
if defined app.gh call :PrintSuccess "OK: GitHub CLI found at %app.gh%"
if not defined app.gh if /I "%app.provider%"=="github" call :PrintWarning "MISS: gh.exe was not found; repository preparation or login would install it."
if not exist "%app.folder%\.git" call :PrintInfo "INFO: checkout does not exist yet."
if exist "%app.folder%\.git" call :PrintSuccess "OK: existing checkout found."
set "rd_remote_rc=0"
if exist "%app.folder%\.git" if defined app.git call :VerifyRepositoryRemote
if exist "%app.folder%\.git" if defined app.git set "rd_remote_rc=%errorlevel%"
if exist "%app.folder%\prepare.bat" call :PrintSuccess "OK: prepare.bat found."
if not exist "%app.folder%\prepare.bat" call :PrintInfo "INFO: prepare.bat is not present."
if exist "%app.folder%\build.bat" call :PrintSuccess "OK: build.bat found."
if not exist "%app.folder%\build.bat" call :PrintInfo "INFO: build.bat is not present."
if exist "%app.folder%\install.bat" call :PrintSuccess "OK: install.bat found."
if not exist "%app.folder%\install.bat" call :PrintInfo "INFO: install.bat is not present."
call :PrintInfo "Login mode: %app.login.mode%"
call :PrintInfo "Login method: %app.login.method%"
call :PrintInfo "Fork mode: %app.fork.mode%"
call :PrintInfo "Move mode: %app.move.mode%"
call :PrintInfo "Project prepare: %app.project.prepare%"
call :PrintInfo "Project build: %app.project.build%"
call :PrintInfo "Project install: %app.project.install%"
call :PrintInfo "Update existing checkout: %app.update.mode%"
call :PrintInfo "Non-Git target conflict: %app.conflict.mode%"
call :PrintInfo "Identity mode: %app.identity.mode%"
call :PrintInfo "Push mode: %app.push.mode%"
call :PrintInfo "Unattended: %app.unattended%"
if not "%rd_remote_rc%"=="0" (call :PrintError "FAIL: doctor found an unexpected repository remote." & set "rd_rc=" & set "rd_remote_rc=" & exit /b 5)
call :PrintSuccess "OK: doctor completed."
set "rd_rc="
set "rd_remote_rc="
exit /b 0

:RunDryRun
rem ============================================================
rem Function RunDryRun
rem Purpose
rem   Describe the selected workflow without installing, cloning, moving, authenticating, or building.
rem Return codes
rem   0 Plan displayed
rem   5 Existing checkout references an unexpected repository
rem Dependencies
rem   FindGit VerifyRepositoryRemote PrintInfo PrintSuccess PrintError
rem ============================================================
call :PrintInfo "MODE: dryrun [%app.version%]"
call :FindGit
set "rdr_remote_rc=0"
if exist "%app.folder%\.git" if defined app.git call :VerifyRepositoryRemote
if exist "%app.folder%\.git" if defined app.git set "rdr_remote_rc=%errorlevel%"
if not "%rdr_remote_rc%"=="0" (call :PrintError "FAIL: dryrun found an unexpected repository remote." & set "rdr_remote_rc=" & exit /b 5)
set "rdr_remote_rc="
call :PrintInfo "Provider: %app.provider% [%app.provider.display%]"
call :PrintInfo "Repository: %app.repo.url%"
call :PrintInfo "Branch: %app.repo.branch%"
call :PrintInfo "Folder: %app.folder%"
if defined app.git call :PrintInfo "Would use Git at %app.git%."
if not defined app.git call :PrintInfo "Would install Git using %app.getgit.url%."
if exist "%app.folder%\.git" if /I "%app.update.mode%"=="yes" call :PrintInfo "Would update the existing checkout."
if exist "%app.folder%\.git" if /I "%app.update.mode%"=="no" call :PrintInfo "Would verify and reuse the existing checkout without fetching or pulling."
if not exist "%app.folder%\.git" if not exist "%app.folder%\" call :PrintInfo "Would clone the repository."
if not exist "%app.folder%\.git" if exist "%app.folder%\" if /I "%app.conflict.mode%"=="quarantine" call :PrintInfo "Would move the non-Git target aside, then clone."
if not exist "%app.folder%\.git" if exist "%app.folder%\" if /I "%app.conflict.mode%"=="fail" call :PrintInfo "Would stop because the target is not a Git checkout."
if /I "%app.login.mode%"=="none" call :PrintInfo "Would skip provider login and fork handling."
if /I not "%app.login.mode%"=="none" call :PrintInfo "Provider login is optional or explicitly requested."
if /I "%app.move.mode%"=="no" call :PrintInfo "Would not move the repository."
if /I "%app.move.mode%"=="ask" call :PrintInfo "Would ask whether to move the repository."
if /I "%app.move.mode%"=="documents" call :PrintInfo "Would move the repository to Documents."
if /I "%app.move.mode%"=="path" call :PrintInfo "Would move the repository beneath %app.move.parent%."
if /I "%app.mode%"=="auto" if /I "%app.project.prepare%"=="yes" call :PrintInfo "Would run project preparation."
if /I "%app.mode%"=="auto" if /I not "%app.project.prepare%"=="yes" call :PrintInfo "Would skip project preparation."
if /I "%app.mode%"=="auto" if /I "%app.project.build%"=="yes" call :PrintInfo "Would run project build."
if /I "%app.mode%"=="auto" if /I not "%app.project.build%"=="yes" call :PrintInfo "Would skip project build."
if /I "%app.mode%"=="auto" if /I "%app.project.install%"=="yes" call :PrintInfo "Would run project installation."
if /I "%app.mode%"=="auto" if /I not "%app.project.install%"=="yes" call :PrintInfo "Would skip project installation."
call :PrintSuccess "OK: dryrun complete; no repository changes were made."
exit /b 0

:RunMenu
rem ============================================================
rem Function RunMenu
rem Purpose
rem   Provide an interactive menu for repository and project operations.
rem Return codes
rem   0 User exited the menu
rem Dependencies
rem   DrawMenu PrintWarning RunAutoWorkflow EnsureGit SynchronizeRepository
rem   EnsureRepositoryReady ResolveLoginDecision RunProviderLogin RunProjectPrepare RunProjectBuild
rem   RunProjectInstall MaybeMoveRepository RunBootstrapWorkflow
rem ============================================================
:RunMenuLoop
cls
call :DrawMenu
set "rm_choice="
set /p "rm_choice=Choose [1-7, A=auto, 0=exit]: "
if /I "%rm_choice%"=="a" goto :RunMenuAuto
if /I "%rm_choice%"=="auto" goto :RunMenuAuto
if "%rm_choice%"=="1" goto :RunMenuSync
if "%rm_choice%"=="2" goto :RunMenuLogin
if "%rm_choice%"=="3" goto :RunMenuPrepare
if "%rm_choice%"=="4" goto :RunMenuBuild
if "%rm_choice%"=="5" goto :RunMenuInstall
if "%rm_choice%"=="6" goto :RunMenuMove
if "%rm_choice%"=="7" goto :RunMenuBootstrap
if "%rm_choice%"=="0" exit /b 0
call :PrintWarning "Choose 1-7, A, or 0."
pause
goto :RunMenuLoop
:RunMenuAuto
call :RunAutoWorkflow
pause
goto :RunMenuLoop
:RunMenuSync
call :EnsureGit
if not errorlevel 1 call :SynchronizeRepository
pause
goto :RunMenuLoop
:RunMenuLogin
set "app.login.mode=ask"
if not defined app.explicit.fork set "app.fork.mode=ask"
if not defined app.explicit.identity set "app.identity.mode=ask"
call :EnsureRepositoryReady
if not errorlevel 1 call :ResolveLoginDecision
if not errorlevel 1 call :RunProviderLogin
pause
goto :RunMenuLoop
:RunMenuPrepare
call :EnsureRepositoryReady
if not errorlevel 1 call :RunProjectPrepare
pause
goto :RunMenuLoop
:RunMenuBuild
call :EnsureRepositoryReady
if not errorlevel 1 call :RunProjectBuild
pause
goto :RunMenuLoop
:RunMenuInstall
call :EnsureRepositoryReady
if not errorlevel 1 call :RunProjectInstall
pause
goto :RunMenuLoop
:RunMenuMove
set "app.move.mode=ask"
call :MaybeMoveRepository
pause
goto :RunMenuLoop
:RunMenuBootstrap
call :RunBootstrapWorkflow
pause
goto :RunMenuLoop

:ShowHelp
rem ============================================================
rem Function ShowHelp
rem Purpose
rem   Display current command syntax, modes, automation decisions, aliases, and examples.
rem Return codes
rem   0 Help displayed
rem Dependencies
rem   none
rem ============================================================
echo(
echo %app.launch.name% [%app.version%]
echo(
echo Usage:
echo   %app.launch.name% [MODE] [OPTIONS]
echo(
echo Modes:
echo   auto                 Set up the repository, then run requested project steps
echo   bootstrap            Set up the repository only; this is the default mode
echo   menu                 Open the interactive operation menu
echo   check                Validate inferred context without changing repository files
echo   doctor               Report context, tools, checkout, and decisions
echo   dryrun               Show the selected plan without making changes
echo   help                 Show this usage information
echo   version              Show the bootstrap version
echo   --version  /version  Version aliases
echo(
echo Repository options:
echo   repo URL             Override the inferred repository URL
echo   HTTP_OR_HTTPS_URL    Bare repository URL alias for repo URL
echo   branch NAME          Select the clone and update branch
echo   dir PATH             Set the checkout folder; relative paths use launch folder
echo   provider NAME        Override provider detection
echo   toolsurl URL         Override the raw tools directory URL
echo   getgit URL           Override the GetGit.bat URL
echo   getgithubcli URL     Override the GetGithubCLI.bat URL
echo   update yes^|no       Update an existing checkout; default yes
echo   conflict quarantine^|fail
echo                        Move a non-Git target aside or fail; default quarantine
echo(
echo Login and publication options:
echo   nologin              Skip provider login and fork handling
echo   login [ask^|1^|2^|3^|4^|no]
echo                        Request login and optionally preselect browser behavior
echo   fork ask^|yes^|no    Preselect personal-fork handling; default ask
echo   identity ask^|defaults
echo                        Ask or accept derived defaults; default ask
echo   gitname NAME         Override the repository-local Git author name
echo   gitemail EMAIL       Override the repository-local Git author email
echo                        Supplying both identity values skips identity prompts
echo   push yes^|no         Push the current branch after login setup; default yes
echo(
echo Login methods:
echo   1                    Let GitHub CLI open the default browser
echo   2                    Open the GitHub device page in the default browser first
echo   3                    Open the GitHub device page in a private browser first
echo   4                    Do not open a browser on this computer
echo(
echo Destination and project options:
echo   move no              Keep the checkout in its resolved folder; default
echo   move ask             Ask for a destination after repository setup
echo   move documents       Move beneath the Windows Documents folder
echo   move path PATH       Move beneath an explicit parent folder
echo   prepare yes^|no      Run project preparation in auto mode; default yes
echo   build yes^|no        Run the project build in auto mode; default yes
echo   install [yes^|no]    Run project installation in auto mode; default no; bare means yes
echo(
echo Automation:
echo   unattended           Fill unresolved bootstrap decisions without prompting
echo                        Login defaults to no; fork defaults to yes only when
echo                        login was explicitly requested; identity uses defaults;
echo                        move stays no; prepare and build stay yes; install stays no
echo(
echo Convenience aliases:
echo   default              Alias for bootstrap mode
echo   nobuild  noprepare  noinstall  noupdate  nomove  nologin
echo   --no-build  --no-prepare  --no-install  --no-update  --no-move
echo   --no-login
echo   noninteractive  --noninteractive  --unattended
echo                        Aliases for unattended or the matching no option
echo(
echo Automatic profiles:
echo   auto unattended
echo                        Fully automatic setup without provider login
echo   auto unattended login 4
echo                        Pre-fill fork, identity, push, move, and project
echo                        decisions; GitHub device authorization remains manual
echo(
echo Help aliases:
echo   help  /help  -help  --help  /h  -h  --h  /?  -?  --?  ?
echo(
echo Examples:
echo   %app.launch.name% auto
echo   %app.launch.name% auto unattended
echo   %app.launch.name% auto unattended nologin
echo   %app.launch.name% auto unattended login 4 fork yes identity defaults
echo   %app.launch.name% auto login 4 gitname "Example User" gitemail user@example.com
echo   %app.launch.name% auto repo https://github.com/Owner/Repo.git branch main
echo   %app.launch.name% auto dir projects\Repo move no prepare yes build yes install no
echo   %app.launch.name% doctor repo https://github.com/Owner/Repo.git
echo(
echo Notes:
echo   Options may be combined in any order; later repeated options win.
echo   Quote names, email addresses, or paths that contain spaces.
echo   Explicit ask values remain interactive even with unattended.
echo   GitHub device authorization still requires user action in a browser.
echo   Project prepare, build, and install launchers may have their own prompts.
echo(
echo Cache-safe loader:
echo   set "bootstrap=https://raw.githubusercontent.com/ExampleOwner/ExampleRepo/main/tools/bootstrap.bat" ^& call curl.exe -sSfL -H "Cache-Control: no-cache" "%%bootstrap%%?cache=%%RANDOM%%" -o "%%TEMP%%\bootstrap.bat" ^&^& call "%%TEMP%%\bootstrap.bat" auto
exit /b 0

:ShowVersion
rem ============================================================
rem Function ShowVersion
rem Purpose
rem   Print the internal bootstrap version.
rem Return codes
rem   0 Version displayed
rem Dependencies
rem   none
rem ============================================================
echo %app.version%
exit /b 0

:: ============================================================
:: LOWER LEVEL WORKFLOW FUNCTIONS
:: ============================================================

:InitializeRuntime
rem ============================================================
rem Function InitializeRuntime
rem Purpose
rem   Create the log file and initialize optional ANSI colours.
rem Outputs
rem   app.timestamp app.log app.esc
rem Return codes
rem   0 Runtime initialized
rem   1 Timestamp or log initialization failed
rem Dependencies
rem   MakeTimestamp SetEscapeCharacter PrintInfo
rem ============================================================
call :MakeTimestamp
if errorlevel 1 exit /b 1
if not exist "%app.log.dir%\" mkdir "%app.log.dir%" >nul 2>&1
if not exist "%app.log.dir%\" exit /b 1
set "app.log=%app.log.dir%\bootstrap.%app.timestamp%.log"
type nul >"%app.log%" 2>nul
if not exist "%app.log%" exit /b 1
call :SetEscapeCharacter app.esc
if errorlevel 1 set "app.esc="
call :PrintInfo "LOG: %app.log%"
exit /b 0

:ParseArguments
rem ============================================================
rem Function ParseArguments
rem Purpose
rem   Parse modes and command-line decisions in any order.
rem Inputs
rem   All command-line arguments
rem Outputs
rem   app.mode and related app option variables
rem Return codes
rem   0 Arguments accepted
rem   2 An argument is unknown incomplete or invalid
rem Dependencies
rem   ParseYesNoValue ResolvePathFromStart PrintError PrintWarning
rem ============================================================
if "%~1"=="" exit /b 0
set "pa_arg=%~1"
if /I "%pa_arg:~0,7%"=="http://" (set "app.repo.url=%~1" & set "app.explicit.repo=1" & shift & goto :ParseArguments)
if /I "%pa_arg:~0,8%"=="https://" (set "app.repo.url=%~1" & set "app.explicit.repo=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="auto" (set "app.mode=auto" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="bootstrap" (set "app.mode=default" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="default" (set "app.mode=default" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="menu" (set "app.mode=menu" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="check" (set "app.mode=check" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="doctor" (set "app.mode=doctor" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="dryrun" (set "app.dryrun=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="version" (set "app.mode=version" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="--version" (set "app.mode=version" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="/version" (set "app.mode=version" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="unattended" (set "app.unattended=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="--unattended" (set "app.unattended=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="noninteractive" (set "app.unattended=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="--noninteractive" (set "app.unattended=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="nobuild" (set "app.project.build=no" & set "app.explicit.build=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="--no-build" (set "app.project.build=no" & set "app.explicit.build=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="noprepare" (set "app.project.prepare=no" & set "app.explicit.prepare=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="--no-prepare" (set "app.project.prepare=no" & set "app.explicit.prepare=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="noinstall" (set "app.project.install=no" & set "app.explicit.install=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="--no-install" (set "app.project.install=no" & set "app.explicit.install=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="noupdate" (set "app.update.mode=no" & set "app.explicit.update=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="--no-update" (set "app.update.mode=no" & set "app.explicit.update=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="nomove" (set "app.move.mode=no" & set "app.move.parent=" & set "app.explicit.move=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="--no-move" (set "app.move.mode=no" & set "app.move.parent=" & set "app.explicit.move=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="nologin" (set "app.login.mode=none" & set "app.login.method=ask" & set "app.explicit.login=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="--no-login" (set "app.login.mode=none" & set "app.login.method=ask" & set "app.explicit.login=1" & shift & goto :ParseArguments)
if /I "%pa_arg%"=="login" goto :ParseArgumentsLogin
if /I "%pa_arg%"=="repo" goto :ParseArgumentsRepo
if /I "%pa_arg%"=="provider" goto :ParseArgumentsProvider
if /I "%pa_arg%"=="toolsurl" goto :ParseArgumentsToolsUrl
if /I "%pa_arg%"=="getgit" goto :ParseArgumentsGetGit
if /I "%pa_arg%"=="getgithubcli" goto :ParseArgumentsGetGitHubCli
if /I "%pa_arg%"=="branch" goto :ParseArgumentsBranch
if /I "%pa_arg%"=="dir" goto :ParseArgumentsDir
if /I "%pa_arg%"=="fork" goto :ParseArgumentsFork
if /I "%pa_arg%"=="identity" goto :ParseArgumentsIdentity
if /I "%pa_arg%"=="gitname" goto :ParseArgumentsGitName
if /I "%pa_arg%"=="gitemail" goto :ParseArgumentsGitEmail
if /I "%pa_arg%"=="push" goto :ParseArgumentsPush
if /I "%pa_arg%"=="move" goto :ParseArgumentsMove
if /I "%pa_arg%"=="prepare" goto :ParseArgumentsPrepare
if /I "%pa_arg%"=="build" goto :ParseArgumentsBuild
if /I "%pa_arg%"=="install" goto :ParseArgumentsInstall
if /I "%pa_arg%"=="update" goto :ParseArgumentsUpdate
if /I "%pa_arg%"=="conflict" goto :ParseArgumentsConflict
if /I "%pa_arg%"=="help" goto :ParseArgumentsHelp
if /I "%pa_arg%"=="/help" goto :ParseArgumentsHelp
if /I "%pa_arg%"=="-help" goto :ParseArgumentsHelp
if /I "%pa_arg%"=="--help" goto :ParseArgumentsHelp
if /I "%pa_arg%"=="/h" goto :ParseArgumentsHelp
if /I "%pa_arg%"=="-h" goto :ParseArgumentsHelp
if /I "%pa_arg%"=="--h" goto :ParseArgumentsHelp
if /I "%pa_arg%"=="/?" goto :ParseArgumentsHelp
if /I "%pa_arg%"=="-?" goto :ParseArgumentsHelp
if /I "%pa_arg%"=="--?" goto :ParseArgumentsHelp
if /I "%pa_arg%"=="?" goto :ParseArgumentsHelp
call :PrintError "FAIL: unknown argument %~1"
call :PrintWarning "Use %app.launch.name% --help for current command syntax."
set "pa_arg="
exit /b 2
:ParseArgumentsHelp
set "app.mode=help"
exit /b 0
:ParseArgumentsLogin
set "app.login.mode=login"
set "app.login.method=ask"
set "app.explicit.login=1"
if /I "%~2"=="no" (set "app.login.mode=none" & shift & shift & goto :ParseArguments)
if /I "%~2"=="ask" (set "app.login.method=ask" & shift & shift & goto :ParseArguments)
if "%~2"=="1" (set "app.login.method=1" & shift & shift & goto :ParseArguments)
if "%~2"=="2" (set "app.login.method=2" & shift & shift & goto :ParseArguments)
if "%~2"=="3" (set "app.login.method=3" & shift & shift & goto :ParseArguments)
if "%~2"=="4" (set "app.login.method=4" & shift & shift & goto :ParseArguments)
shift
goto :ParseArguments
:ParseArgumentsRepo
if "%~2"=="" (call :PrintError "FAIL: repo requires a URL." & exit /b 2)
set "app.repo.url=%~2"
set "app.explicit.repo=1"
shift
shift
goto :ParseArguments
:ParseArgumentsProvider
if "%~2"=="" (call :PrintError "FAIL: provider requires a name." & exit /b 2)
set "app.provider.requested=%~2"
set "app.explicit.provider=1"
shift
shift
goto :ParseArguments
:ParseArgumentsToolsUrl
if "%~2"=="" (call :PrintError "FAIL: toolsurl requires a URL." & exit /b 2)
set "app.raw.tools.url=%~2"
set "app.explicit.toolsurl=1"
shift
shift
goto :ParseArguments
:ParseArgumentsGetGit
if "%~2"=="" (call :PrintError "FAIL: getgit requires a URL." & exit /b 2)
set "app.getgit.url=%~2"
shift
shift
goto :ParseArguments
:ParseArgumentsGetGitHubCli
if "%~2"=="" (call :PrintError "FAIL: getgithubcli requires a URL." & exit /b 2)
set "app.getgh.url=%~2"
shift
shift
goto :ParseArguments
:ParseArgumentsBranch
if "%~2"=="" (call :PrintError "FAIL: branch requires a name." & exit /b 2)
set "app.repo.branch=%~2"
set "app.explicit.branch=1"
shift
shift
goto :ParseArguments
:ParseArgumentsDir
if "%~2"=="" (call :PrintError "FAIL: dir requires a path." & exit /b 2)
call :ResolvePathFromStart "%~2" app.folder
if errorlevel 1 (call :PrintError "FAIL: dir path could not be resolved." & exit /b 2)
shift
shift
goto :ParseArguments
:ParseArgumentsFork
if "%~2"=="" (call :PrintError "FAIL: fork requires ask, yes, or no." & exit /b 2)
if /I "%~2"=="ask" (set "app.fork.mode=ask" & set "app.explicit.fork=1" & shift & shift & goto :ParseArguments)
if /I "%~2"=="yes" (set "app.fork.mode=yes" & set "app.explicit.fork=1" & shift & shift & goto :ParseArguments)
if /I "%~2"=="no" (set "app.fork.mode=no" & set "app.explicit.fork=1" & shift & shift & goto :ParseArguments)
call :PrintError "FAIL: fork requires ask, yes, or no."
exit /b 2
:ParseArgumentsIdentity
if "%~2"=="" (call :PrintError "FAIL: identity requires ask or defaults." & exit /b 2)
if /I "%~2"=="ask" (set "app.identity.mode=ask" & set "app.explicit.identity=1" & shift & shift & goto :ParseArguments)
if /I "%~2"=="defaults" (set "app.identity.mode=defaults" & set "app.explicit.identity=1" & shift & shift & goto :ParseArguments)
call :PrintError "FAIL: identity requires ask or defaults."
exit /b 2
:ParseArgumentsGitName
if "%~2"=="" (call :PrintError "FAIL: gitname requires a value." & exit /b 2)
set "app.git_name=%~2"
shift
shift
goto :ParseArguments
:ParseArgumentsGitEmail
if "%~2"=="" (call :PrintError "FAIL: gitemail requires a value." & exit /b 2)
set "app.git_email=%~2"
shift
shift
goto :ParseArguments
:ParseArgumentsPush
if "%~2"=="" (call :PrintError "FAIL: push requires yes or no." & exit /b 2)
call :ParseYesNoValue "%~2" app.push.mode
if errorlevel 1 (call :PrintError "FAIL: push requires yes or no." & exit /b 2)
set "app.explicit.push=1"
shift
shift
goto :ParseArguments
:ParseArgumentsMove
if "%~2"=="" (call :PrintError "FAIL: move requires no, ask, documents, or path PATH." & exit /b 2)
if /I "%~2"=="no" (set "app.move.mode=no" & set "app.move.parent=" & set "app.explicit.move=1" & shift & shift & goto :ParseArguments)
if /I "%~2"=="ask" (set "app.move.mode=ask" & set "app.move.parent=" & set "app.explicit.move=1" & shift & shift & goto :ParseArguments)
if /I "%~2"=="documents" (set "app.move.mode=documents" & set "app.move.parent=" & set "app.explicit.move=1" & shift & shift & goto :ParseArguments)
if /I "%~2"=="path" goto :ParseArgumentsMovePath
call :PrintError "FAIL: move requires no, ask, documents, or path PATH."
exit /b 2
:ParseArgumentsMovePath
if "%~3"=="" (call :PrintError "FAIL: move path requires a parent path." & exit /b 2)
call :ResolvePathFromStart "%~3" app.move.parent
if errorlevel 1 (call :PrintError "FAIL: move parent path could not be resolved." & exit /b 2)
set "app.move.mode=path"
set "app.explicit.move=1"
shift
shift
shift
goto :ParseArguments
:ParseArgumentsPrepare
if "%~2"=="" (call :PrintError "FAIL: prepare requires yes or no." & exit /b 2)
call :ParseYesNoValue "%~2" app.project.prepare
if errorlevel 1 (call :PrintError "FAIL: prepare requires yes or no." & exit /b 2)
set "app.explicit.prepare=1"
shift
shift
goto :ParseArguments
:ParseArgumentsBuild
if "%~2"=="" (call :PrintError "FAIL: build requires yes or no." & exit /b 2)
call :ParseYesNoValue "%~2" app.project.build
if errorlevel 1 (call :PrintError "FAIL: build requires yes or no." & exit /b 2)
set "app.explicit.build=1"
shift
shift
goto :ParseArguments
:ParseArgumentsInstall
if "%~2"=="" (set "app.project.install=yes" & set "app.explicit.install=1" & shift & goto :ParseArguments)
call :ParseYesNoValue "%~2" app.project.install
if errorlevel 1 (set "app.project.install=yes" & set "app.explicit.install=1" & shift & goto :ParseArguments)
set "app.explicit.install=1"
shift
shift
goto :ParseArguments
:ParseArgumentsUpdate
if "%~2"=="" (call :PrintError "FAIL: update requires yes or no." & exit /b 2)
call :ParseYesNoValue "%~2" app.update.mode
if errorlevel 1 (call :PrintError "FAIL: update requires yes or no." & exit /b 2)
set "app.explicit.update=1"
shift
shift
goto :ParseArguments
:ParseArgumentsConflict
if "%~2"=="" (call :PrintError "FAIL: conflict requires quarantine or fail." & exit /b 2)
if /I "%~2"=="quarantine" (set "app.conflict.mode=quarantine" & set "app.explicit.conflict=1" & shift & shift & goto :ParseArguments)
if /I "%~2"=="fail" (set "app.conflict.mode=fail" & set "app.explicit.conflict=1" & shift & shift & goto :ParseArguments)
call :PrintError "FAIL: conflict requires quarantine or fail."
exit /b 2

:ApplyAutomationDefaults
rem ============================================================
rem Function ApplyAutomationDefaults
rem Purpose
rem   Fill unresolved decisions for unattended execution without overriding explicit options.
rem   Suppress identity prompts when both Git identity values were supplied.
rem Outputs
rem   Login fork identity push move project update and conflict decisions
rem Return codes
rem   0 Defaults applied
rem Dependencies
rem   none
rem ============================================================
if defined app.git_name if defined app.git_email if not defined app.explicit.identity set "app.identity.mode=defaults"
if not defined app.unattended exit /b 0
if not defined app.explicit.login set "app.login.mode=none"
if not defined app.explicit.login set "app.login.method=ask"
if not defined app.explicit.fork if /I "%app.login.mode%"=="login" set "app.fork.mode=yes"
if not defined app.explicit.fork if /I not "%app.login.mode%"=="login" set "app.fork.mode=no"
if not defined app.explicit.identity set "app.identity.mode=defaults"
if not defined app.explicit.push set "app.push.mode=yes"
if not defined app.explicit.move set "app.move.mode=no"
if not defined app.explicit.prepare set "app.project.prepare=yes"
if not defined app.explicit.build set "app.project.build=yes"
if not defined app.explicit.install set "app.project.install=no"
if not defined app.explicit.update set "app.update.mode=yes"
if not defined app.explicit.conflict set "app.conflict.mode=quarantine"
exit /b 0

:ResolveBootstrapContext
rem ============================================================
rem Function ResolveBootstrapContext
rem Purpose
rem   Infer repository metadata from the loader URL or explicit repository URL.
rem   Preserve explicit command-line overrides and derive helper download URLs.
rem Outputs
rem   Repository provider owner name branch and helper URLs
rem Return codes
rem   0 Context resolved
rem   3 Required repository context could not be resolved
rem Dependencies
rem   ParseBootstrapUrl ParseRepositoryUrl PrintSuccess PrintError PrintWarning
rem ============================================================
if not defined app.repo.url if not defined app.bootstrap.url (call :PrintError "FAIL: no repository URL or bootstrap loader URL was provided." & exit /b 3)
if not defined app.explicit.repo if defined app.bootstrap.url call :ParseBootstrapUrl
if defined app.repo.url call :ParseRepositoryUrl
if defined app.provider.requested set "app.provider=%app.provider.requested%"
if not defined app.provider set "app.provider=git"
if not defined app.repo.url (call :PrintError "FAIL: repository URL could not be inferred." & call :PrintWarning "Use repo URL on the command line." & exit /b 3)
if not defined app.repo.name (call :PrintError "FAIL: repository name could not be inferred." & exit /b 3)
if /I "%app.provider%"=="github" if not defined app.repo.owner (call :PrintError "FAIL: GitHub repository owner could not be inferred." & exit /b 3)
if not defined app.raw.tools.url if /I "%app.provider%"=="github" set "app.raw.tools.url=https://raw.githubusercontent.com/%app.repo.owner%/%app.repo.name%/%app.repo.branch%/tools"
if not defined app.getgit.url if defined app.raw.tools.url set "app.getgit.url=%app.raw.tools.url%/GetGit.bat"
if not defined app.getgh.url if defined app.raw.tools.url set "app.getgh.url=%app.raw.tools.url%/GetGithubCLI.bat"
set "app.repo.original.url=%app.repo.url%"
set "app.repo.url.normalized="
call :PrintSuccess "OK: Provider: %app.provider%"
call :PrintSuccess "OK: Repo: %app.repo.url%"
call :PrintSuccess "OK: Branch: %app.repo.branch%"
exit /b 0

:ResolveRepositoryFolder
rem ============================================================
rem Function ResolveRepositoryFolder
rem Purpose
rem   Choose the target checkout path using explicit path, matching current checkout, writable launch directory, then TEMP fallback.
rem Outputs
rem   app.folder and app.repo.parent
rem Return codes
rem   0 Target folder resolved
rem   3 No writable target parent was available
rem Dependencies
rem   UseCurrentRepository SelectRepositoryParent PrintSuccess
rem ============================================================
if defined app.folder goto :ResolveRepositoryFolderNormalize
call :UseCurrentRepository
if not errorlevel 1 goto :ResolveRepositoryFolderNormalize
call :SelectRepositoryParent
set "rrf_rc=%errorlevel%"
if not "%rrf_rc%"=="0" exit /b %rrf_rc%
set "app.folder=%app.repo.parent%\%app.repo.name%"
:ResolveRepositoryFolderNormalize
for %%A in ("%app.folder%") do set "app.folder=%%~fA"
set "rrf_rc="
call :PrintSuccess "OK: Folder: %app.folder%"
exit /b 0

:UseCurrentRepository
rem ============================================================
rem Function UseCurrentRepository
rem Purpose
rem   Reuse the launch directory when it is already the intended repository checkout.
rem Outputs
rem   app.folder when a matching checkout is found
rem Return codes
rem   0 Current directory selected
rem   1 Current directory is not the matching checkout
rem Dependencies
rem   PrintInfo
rem ============================================================
set "ucr_name="
if not exist "%app.start.dir%\.git" exit /b 1
for %%A in ("%app.start.dir%") do set "ucr_name=%%~nxA"
if /I not "%ucr_name%"=="%app.repo.name%" (set "ucr_name=" & exit /b 1)
for %%A in ("%app.start.dir%") do set "app.folder=%%~fA"
set "ucr_name="
call :PrintInfo "INFO: Reusing the current repository folder."
exit /b 0

:SelectRepositoryParent
rem ============================================================
rem Function SelectRepositoryParent
rem Purpose
rem   Use the writable launch directory as checkout parent and use TEMP only as a fallback.
rem Outputs
rem   app.repo.parent
rem Return codes
rem   0 Writable parent selected
rem   3 Neither launch directory nor TEMP is writable
rem Dependencies
rem   IsDirectoryWritable PrintWarning PrintError
rem ============================================================
set "app.repo.parent="
call :IsDirectoryWritable "%app.start.dir%"
if not errorlevel 1 goto :SelectRepositoryParentStart
call :IsDirectoryWritable "%TEMP%"
if errorlevel 1 (call :PrintError "FAIL: neither the launch directory nor TEMP is writable." & exit /b 3)
for %%A in ("%TEMP%") do set "app.repo.parent=%%~fA"
call :PrintWarning "WARN: launch directory is not writable; using TEMP for the repository."
call :PrintWarning "CURRENT: %app.start.dir%"
call :PrintWarning "TEMP: %app.repo.parent%"
exit /b 0
:SelectRepositoryParentStart
for %%A in ("%app.start.dir%") do set "app.repo.parent=%%~fA"
exit /b 0

:ConfigureProvider
rem ============================================================
rem Function ConfigureProvider
rem Purpose
rem   Set provider display name and supported login, fork, and raw-tools capabilities.
rem Outputs
rem   app.provider.display and provider capability flags
rem Return codes
rem   0 Provider configured
rem Dependencies
rem   none
rem ============================================================
set "app.provider.display=Generic Git"
set "app.provider.can.login=0"
set "app.provider.can.fork=0"
if /I "%app.provider%"=="github" set "app.provider.display=GitHub"
if /I "%app.provider%"=="github" set "app.provider.can.login=1"
if /I "%app.provider%"=="github" set "app.provider.can.fork=1"
if /I "%app.provider%"=="gitlab" set "app.provider.display=GitLab"
if /I "%app.provider%"=="bitbucket" set "app.provider.display=Bitbucket"
if /I "%app.provider%"=="gitea" set "app.provider.display=Gitea or Forgejo"
exit /b 0

:EnsureGit
rem ============================================================
rem Function EnsureGit
rem Purpose
rem   Find Git or install it through the inferred GetGit helper.
rem Outputs
rem   app.git and PATH
rem Return codes
rem   0 Git is ready
rem   4 Git could not be installed
rem Dependencies
rem   FindGit EnsureGetGitHelper PrependExecutableDirectoryToPath PrintWarning PrintError PrintSuccess
rem ============================================================
call :FindGit
if defined app.git goto :EnsureGitReady
call :PrintWarning "MISS: git.exe not found."
call :EnsureGetGitHelper
if errorlevel 1 exit /b 4
call :PrintWarning "DO: Installing Git using GetGit.bat."
cmd.exe /D /C call "%app.tools%\GetGit.bat" >>"%app.log%" 2>&1
set "eg_rc=%errorlevel%"
cd /d "%app.script.dir%" >nul 2>&1
if not "%eg_rc%"=="0" (call :PrintError "FAIL: GetGit.bat failed." & call :PrintWarning "LOG: %app.log%" & set "eg_rc=" & exit /b 4)
set "eg_rc="
call :FindGit
if not defined app.git (call :PrintError "FAIL: Git is still missing after GetGit.bat." & exit /b 4)
:EnsureGitReady
call :PrependExecutableDirectoryToPath "%app.git%"
call :PrintSuccess "OK: Git ready: %app.git%"
exit /b 0

:SynchronizeRepository
rem ============================================================
rem Function SynchronizeRepository
rem Purpose
rem   Clone the repository or safely fast-forward an existing matching checkout.
rem Outputs
rem   app.repo.ready app.final.cd
rem Return codes
rem   0 Checkout ready
rem   5 Clone or update failed
rem Dependencies
rem   EnsureGit VerifyRepositoryRemote CloneRepository UpdateRepository QuarantineNonGitFolder PrintError
rem   PrintInfo
rem ============================================================
if not defined app.git call :EnsureGit
if errorlevel 1 exit /b 5
if exist "%app.folder%\.git" goto :SynchronizeRepositoryExisting
if not exist "%app.folder%\" goto :SynchronizeRepositoryClone
if /I "%app.conflict.mode%"=="fail" (call :PrintError "FAIL: target exists and is not a Git checkout: %app.folder%" & exit /b 5)
call :QuarantineNonGitFolder
set "sr_rc=%errorlevel%"
if not "%sr_rc%"=="0" exit /b %sr_rc%
:SynchronizeRepositoryClone
call :CloneRepository
set "sr_rc=%errorlevel%"
if not "%sr_rc%"=="0" exit /b %sr_rc%
goto :SynchronizeRepositoryDone
:SynchronizeRepositoryExisting
if /I "%app.update.mode%"=="no" goto :SynchronizeRepositoryReuse
call :UpdateRepository
set "sr_rc=%errorlevel%"
if not "%sr_rc%"=="0" exit /b %sr_rc%
goto :SynchronizeRepositoryDone
:SynchronizeRepositoryReuse
call :VerifyRepositoryRemote
set "sr_rc=%errorlevel%"
if not "%sr_rc%"=="0" exit /b %sr_rc%
call :PrintInfo "INFO: Existing checkout verified; fetch and pull were skipped."
:SynchronizeRepositoryDone
set "app.repo.ready=1"
set "app.final.cd=%app.folder%"
set "sr_rc="
exit /b 0

:CloneRepository
rem ============================================================
rem Function CloneRepository
rem Purpose
rem   Clone the configured branch into the resolved checkout folder.
rem Return codes
rem   0 Repository cloned
rem   5 Git clone failed
rem Dependencies
rem   PrintInfo PrintSuccess PrintError PrintWarning
rem ============================================================
call :PrintInfo "DO: Cloning %app.repo.url%."
"%app.git%" clone --branch "%app.repo.branch%" "%app.repo.url%" "%app.folder%" >>"%app.log%" 2>&1
set "cr_rc=%errorlevel%"
if not "%cr_rc%"=="0" (call :PrintError "FAIL: git clone failed." & call :PrintWarning "LOG: %app.log%" & set "cr_rc=" & exit /b 5)
call :PrintSuccess "OK: Repo cloned."
set "cr_rc="
exit /b 0

:UpdateRepository
rem ============================================================
rem Function UpdateRepository
rem Purpose
rem   Verify the expected original remote and fast-forward the configured branch from that remote.
rem   A missing local branch may be created to track the selected remote branch.
rem Outputs
rem   app.repo.sync.remote
rem Return codes
rem   0 Repository updated
rem   5 Remote verification or Git update failed
rem Dependencies
rem   VerifyRepositoryRemote PrintInfo PrintSuccess PrintError PrintWarning
rem ============================================================
call :VerifyRepositoryRemote
set "ur_rc=%errorlevel%"
if not "%ur_rc%"=="0" (set "ur_rc=" & exit /b 5)
call :PrintInfo "DO: Updating existing repository from %app.repo.sync.remote%."
"%app.git%" -C "%app.folder%" fetch "%app.repo.sync.remote%" --prune >>"%app.log%" 2>&1
set "ur_rc=%errorlevel%"
if not "%ur_rc%"=="0" (call :PrintError "FAIL: git fetch failed." & call :PrintWarning "LOG: %app.log%" & set "ur_rc=" & exit /b 5)
"%app.git%" -C "%app.folder%" checkout "%app.repo.branch%" >>"%app.log%" 2>&1
set "ur_rc=%errorlevel%"
if "%ur_rc%"=="0" goto :UpdateRepositoryPull
"%app.git%" -C "%app.folder%" switch "%app.repo.branch%" >>"%app.log%" 2>&1
set "ur_rc=%errorlevel%"
if "%ur_rc%"=="0" goto :UpdateRepositoryPull
"%app.git%" -C "%app.folder%" switch --track -c "%app.repo.branch%" "%app.repo.sync.remote%/%app.repo.branch%" >>"%app.log%" 2>&1
set "ur_rc=%errorlevel%"
if not "%ur_rc%"=="0" (call :PrintError "FAIL: Git could not switch to branch %app.repo.branch%." & call :PrintWarning "LOG: %app.log%" & set "ur_rc=" & exit /b 5)
:UpdateRepositoryPull
"%app.git%" -C "%app.folder%" pull --ff-only "%app.repo.sync.remote%" "%app.repo.branch%" >>"%app.log%" 2>&1
set "ur_rc=%errorlevel%"
if not "%ur_rc%"=="0" (call :PrintError "FAIL: git pull --ff-only failed; local work was not overwritten." & call :PrintWarning "LOG: %app.log%" & set "ur_rc=" & exit /b 5)
call :PrintSuccess "OK: Repo ready."
set "ur_rc="
exit /b 0

:VerifyRepositoryRemote
rem ============================================================
rem Function VerifyRepositoryRemote
rem Purpose
rem   Confirm that origin or upstream points to the original repository and select that remote for updates.
rem Outputs
rem   app.repo.sync.remote and normalized remote values
rem Return codes
rem   0 Expected remote found
rem   5 Checkout is not the expected repository
rem Dependencies
rem   NormalizeGitUrl PrintError PrintWarning
rem ============================================================
"%app.git%" -C "%app.folder%" rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (call :PrintError "FAIL: target is not a Git worktree." & exit /b 5)
set "app.folder.origin="
set "app.folder.origin.normalized="
set "app.folder.upstream="
set "app.folder.upstream.normalized="
for /f "delims=" %%A in ('"%app.git%" -C "%app.folder%" remote get-url origin 2^>nul') do if not defined app.folder.origin set "app.folder.origin=%%A"
for /f "delims=" %%A in ('"%app.git%" -C "%app.folder%" remote get-url upstream 2^>nul') do if not defined app.folder.upstream set "app.folder.upstream=%%A"
if not defined app.repo.url.normalized call :NormalizeGitUrl "%app.repo.original.url%" app.repo.url.normalized
if not defined app.repo.url.normalized (call :PrintError "FAIL: expected repository URL could not be normalized." & exit /b 5)
if defined app.folder.origin call :NormalizeGitUrl "%app.folder.origin%" app.folder.origin.normalized
if defined app.folder.upstream call :NormalizeGitUrl "%app.folder.upstream%" app.folder.upstream.normalized
if defined app.folder.origin.normalized if /I "%app.folder.origin.normalized%"=="%app.repo.url.normalized%" (set "app.repo.sync.remote=origin" & exit /b 0)
if defined app.folder.upstream.normalized if /I "%app.folder.upstream.normalized%"=="%app.repo.url.normalized%" (set "app.repo.sync.remote=upstream" & exit /b 0)
call :PrintError "FAIL: existing checkout does not reference the expected repository."
call :PrintWarning "EXPECTED: %app.repo.original.url%"
if defined app.folder.origin call :PrintWarning "ORIGIN: %app.folder.origin%"
if defined app.folder.upstream call :PrintWarning "UPSTREAM: %app.folder.upstream%"
exit /b 5

:PrepareRepositoryTools
rem ============================================================
rem Function PrepareRepositoryTools
rem Purpose
rem   Let the cloned repository prepare Git and provider command-line tools without authenticating.
rem Outputs
rem   app.repo.tools.prepared and refreshed tool paths
rem Return codes
rem   0 Repository tools prepared or no launcher exists
rem   8 Repository preparation failed
rem Dependencies
rem   RunRepositoryLauncher FindGit FindGitHubCli PrependExecutableDirectoryToPath
rem ============================================================
if defined app.repo.tools.prepared exit /b 0
call :RunRepositoryLauncher "prepare.bat" "Repository preparation" "repository"
set "prt_rc=%errorlevel%"
if not "%prt_rc%"=="0" exit /b %prt_rc%
set "app.repo.tools.prepared=1"
set "prt_rc="
call :FindGit
if defined app.git call :PrependExecutableDirectoryToPath "%app.git%"
call :FindGitHubCli
if defined app.gh call :PrependExecutableDirectoryToPath "%app.gh%"
exit /b 0

:ResolveLoginDecision
rem ============================================================
rem Function ResolveLoginDecision
rem Purpose
rem   Respect explicit login settings or ask once whether provider login and fork handling should run.
rem Outputs
rem   app.login.mode app.fork.mode
rem Return codes
rem   0 Login decision resolved
rem Dependencies
rem   PrintInfo PrintWarning
rem ============================================================
if /I not "%app.provider.can.login%"=="1" (set "app.login.mode=none" & set "app.fork.mode=no" & call :PrintWarning "SKIP: provider login is not implemented for %app.provider%." & exit /b 0)
if /I "%app.login.mode%"=="none" (set "app.fork.mode=no" & exit /b 0)
if /I "%app.login.mode%"=="login" exit /b 0
set "rld_choice="
call :PrintInfo "%app.provider.display% login is optional."
call :PrintInfo "Press Enter to skip provider login and fork, or type y to login."
set /p "rld_choice=%app.provider.display% login? [y/N]: "
if /I "%rld_choice%"=="y" (set "app.login.mode=login" & set "rld_choice=" & exit /b 0)
if /I "%rld_choice%"=="yes" (set "app.login.mode=login" & set "rld_choice=" & exit /b 0)
if defined rld_choice if /I not "%rld_choice%"=="n" if /I not "%rld_choice%"=="no" call :PrintWarning "NOTE: unrecognized input; skipping provider login and fork."
set "app.login.mode=none"
set "app.fork.mode=no"
set "rld_choice="
exit /b 0

:RunProviderLogin
rem ============================================================
rem Function RunProviderLogin
rem Purpose
rem   Dispatch the requested provider login and fork workflow.
rem Return codes
rem   0 Login completed or skipped
rem   6 Provider login or fork setup failed
rem Dependencies
rem   RunGitHubLoginWorkflow PrintWarning
rem ============================================================
if /I "%app.login.mode%"=="none" (call :PrintWarning "SKIP: provider login and fork steps skipped." & exit /b 0)
if /I "%app.provider%"=="github" goto :RunProviderLoginGitHub
call :PrintWarning "SKIP: provider login is not implemented for %app.provider%."
exit /b 0
:RunProviderLoginGitHub
call :RunGitHubLoginWorkflow
set "rplg_rc=%errorlevel%"
exit /b %rplg_rc%

:RunGitHubLoginWorkflow
rem ============================================================
rem Function RunGitHubLoginWorkflow
rem Purpose
rem   Prefer the repository just_login launcher and use a standalone fallback only when that launcher is absent.
rem Return codes
rem   0 GitHub setup completed
rem   6 GitHub setup failed
rem Dependencies
rem   EnsureGit EnsureGitHubCli RunRepositoryLogin RunFallbackGitHubLogin ConfigureFallbackGitHubFork ConfigureFallbackGitIdentity RunFallbackGitPush
rem ============================================================
call :EnsureGit
if errorlevel 1 exit /b 6
call :EnsureGitHubCli
if errorlevel 1 exit /b 6
if exist "%app.folder%\just_login.bat" goto :RunGitHubLoginWorkflowRepository
call :RunFallbackGitHubLogin
set "rglw_rc=%errorlevel%"
if not "%rglw_rc%"=="0" exit /b %rglw_rc%
call :ConfigureFallbackGitHubFork
set "rglw_rc=%errorlevel%"
if not "%rglw_rc%"=="0" exit /b %rglw_rc%
call :ConfigureFallbackGitIdentity
set "rglw_rc=%errorlevel%"
if not "%rglw_rc%"=="0" exit /b %rglw_rc%
call :RunFallbackGitPush
set "rglw_rc=%errorlevel%"
exit /b %rglw_rc%
:RunGitHubLoginWorkflowRepository
call :RunRepositoryLogin
set "rglw_rc=%errorlevel%"
exit /b %rglw_rc%

:RunRepositoryLogin
rem ============================================================
rem Function RunRepositoryLogin
rem Purpose
rem   Call repository just_login with explicit repository branch browser fork identity and push decisions.
rem Return codes
rem   0 Repository login launcher completed
rem   6 Repository login launcher failed
rem Dependencies
rem   just_login.bat PrintError PrintSuccess
rem ============================================================
set "rrl_rc=0"
pushd "%app.folder%" >nul 2>&1
if errorlevel 1 (call :PrintError "FAIL: repository folder could not be entered for login." & exit /b 6)
call just_login.bat repo "%app.repo.original.url%" branch "%app.repo.branch%" browser %app.login.method% fork %app.fork.mode% identity %app.identity.mode% push %app.push.mode% prepared yes
set "rrl_rc=%errorlevel%"
popd >nul
if not "%rrl_rc%"=="0" (call :PrintError "FAIL: just_login.bat failed." & set "rrl_rc=" & exit /b 6)
set "rrl_rc="
call :PrintSuccess "OK: repository just_login.bat completed GitHub setup."
exit /b 0

:RunFallbackGitHubLogin
rem ============================================================
rem Function RunFallbackGitHubLogin
rem Purpose
rem   Authenticate GitHub CLI when the repository does not provide just_login.bat.
rem Outputs
rem   app.github.user
rem Return codes
rem   0 GitHub authentication confirmed
rem   6 GitHub authentication failed
rem Dependencies
rem   CheckGitHubAuthentication PromptLoginMethod OpenDeviceLoginPage GetGitHubUser PrintInfo PrintError
rem   PrintSuccess
rem ============================================================
call :CheckGitHubAuthentication
set "rfgl_rc=%errorlevel%"
if "%rfgl_rc%"=="0" (set "rfgl_rc=" & exit /b 0)
set "rfgl_rc="
if /I "%app.login.method%"=="ask" call :PromptLoginMethod
if /I "%app.login.method%"=="ask" set "rfgl_rc=%errorlevel%"
if defined rfgl_rc if not "%rfgl_rc%"=="0" (set "rfgl_rc=" & exit /b 6)
set "rfgl_rc="
call :OpenDeviceLoginPage "%app.login.method%"
set "rfgl_old_gh_browser=%GH_BROWSER%"
set "rfgl_old_browser=%BROWSER%"
if not "%app.login.method%"=="1" set "GH_BROWSER=echo"
if not "%app.login.method%"=="1" set "BROWSER=echo"
call :PrintInfo "DO: GitHub device login."
if "%app.login.method%"=="1" goto :RunFallbackGitHubLoginNormal
echo.| "%app.gh%" auth login --web --git-protocol https
set "rfgl_rc=%errorlevel%"
goto :RunFallbackGitHubLoginRestore
:RunFallbackGitHubLoginNormal
"%app.gh%" auth login --web --git-protocol https
set "rfgl_rc=%errorlevel%"
:RunFallbackGitHubLoginRestore
if defined rfgl_old_gh_browser (set "GH_BROWSER=%rfgl_old_gh_browser%") else (set "GH_BROWSER=")
if defined rfgl_old_browser (set "BROWSER=%rfgl_old_browser%") else (set "BROWSER=")
set "rfgl_old_gh_browser="
set "rfgl_old_browser="
if not "%rfgl_rc%"=="0" (call :PrintError "FAIL: GitHub login failed." & set "rfgl_rc=" & exit /b 6)
"%app.gh%" auth setup-git >>"%app.log%" 2>&1
set "rfgl_rc=%errorlevel%"
if not "%rfgl_rc%"=="0" (call :PrintError "FAIL: GitHub CLI could not configure Git authentication." & set "rfgl_rc=" & exit /b 6)
call :CheckGitHubAuthentication
if errorlevel 1 (call :PrintError "FAIL: GitHub login was not confirmed." & exit /b 6)
call :GetGitHubUser
if errorlevel 1 (call :PrintError "FAIL: authenticated GitHub username could not be resolved." & exit /b 6)
call :PrintSuccess "OK: GitHub login ready: %app.github.user%"
set "rfgl_rc="
exit /b 0

:ConfigureFallbackGitHubFork
rem ============================================================
rem Function ConfigureFallbackGitHubFork
rem Purpose
rem   Configure direct push, a verified personal fork, or read-only original-repository mode.
rem Return codes
rem   0 Direct push fork or read-only workflow configured
rem   6 Remote or fork workflow failed
rem Dependencies
rem   GetGitHubUser CheckGitHubWritePermission PromptForkChoice CreateGitHubFork ConfigureOriginalRemote
rem   ConfigureForkRemotes PrintSuccess PrintWarning
rem ============================================================
call :GetGitHubUser
set "cfghf_rc=%errorlevel%"
if not "%cfghf_rc%"=="0" (set "cfghf_rc=" & exit /b 6)
call :CheckGitHubWritePermission
set "cfghf_rc=%errorlevel%"
if "%cfghf_rc%"=="0" goto :ConfigureFallbackGitHubForkDirect
if /I "%app.fork.mode%"=="no" goto :ConfigureFallbackGitHubForkReadOnly
if /I "%app.fork.mode%"=="ask" call :PromptForkChoice
if /I "%app.fork.mode%"=="no" goto :ConfigureFallbackGitHubForkReadOnly
call :CreateGitHubFork
set "cfghf_rc=%errorlevel%"
if not "%cfghf_rc%"=="0" (set "cfghf_rc=" & exit /b 6)
call :ConfigureForkRemotes
set "cfghf_rc=%errorlevel%"
if not "%cfghf_rc%"=="0" (set "cfghf_rc=" & exit /b 6)
set "cfghf_rc="
exit /b 0
:ConfigureFallbackGitHubForkDirect
call :ConfigureOriginalRemote
set "cfghf_rc=%errorlevel%"
if not "%cfghf_rc%"=="0" (set "cfghf_rc=" & exit /b 6)
call :PrintSuccess "OK: authenticated account can write to the original repository."
set "cfghf_rc="
exit /b 0
:ConfigureFallbackGitHubForkReadOnly
set "app.push.mode=no"
call :ConfigureOriginalRemote
set "cfghf_rc=%errorlevel%"
if not "%cfghf_rc%"=="0" (set "cfghf_rc=" & exit /b 6)
call :PrintWarning "SKIP: fork was not requested; push was disabled because direct write access is unavailable."
set "cfghf_rc="
exit /b 0

:ConfigureFallbackGitIdentity
rem ============================================================
rem Function ConfigureFallbackGitIdentity
rem Purpose
rem   Resolve and write repository-local Git identity when just_login.bat is unavailable.
rem Outputs
rem   Local Git user name and email
rem Return codes
rem   0 Local identity configured
rem   6 Identity could not be resolved or written
rem Dependencies
rem   GetGitHubUser PrintError PrintSuccess
rem ============================================================
set "cfgi_name="
set "cfgi_email="
set "cfgi_input="
set "cfgi_id="
if defined app.git_name set "cfgi_name=%app.git_name%"
if defined app.git_email set "cfgi_email=%app.git_email%"
for /f "delims=" %%A in ('"%app.git%" -C "%app.folder%" config --local --get user.name 2^>nul') do if not defined cfgi_name set "cfgi_name=%%A"
for /f "delims=" %%A in ('"%app.git%" -C "%app.folder%" config --local --get user.email 2^>nul') do if not defined cfgi_email set "cfgi_email=%%A"
if not defined cfgi_name for /f "delims=" %%A in ('"%app.git%" config --global --get user.name 2^>nul') do if not defined cfgi_name set "cfgi_name=%%A"
if not defined cfgi_email for /f "delims=" %%A in ('"%app.git%" config --global --get user.email 2^>nul') do if not defined cfgi_email set "cfgi_email=%%A"
if not defined app.github.user call :GetGitHubUser
if not defined cfgi_name set "cfgi_name=%app.github.user%"
if not defined cfgi_email for /f "delims=" %%A in ('"%app.gh%" api user --jq ".email // empty" 2^>nul') do if not defined cfgi_email set "cfgi_email=%%A"
if not defined cfgi_email for /f "delims=" %%A in ('"%app.gh%" api user --jq ".id" 2^>nul') do if not defined cfgi_id set "cfgi_id=%%A"
if not defined cfgi_email if defined cfgi_id set "cfgi_email=%cfgi_id%+%app.github.user%@users.noreply.github.com"
if not defined cfgi_email if defined app.github.user set "cfgi_email=%app.github.user%@users.noreply.github.com"
if /I not "%app.identity.mode%"=="ask" goto :ConfigureFallbackGitIdentityValidate
set /p "cfgi_input=Git name [%cfgi_name%]: "
if defined cfgi_input set "cfgi_name=%cfgi_input%"
set "cfgi_input="
set /p "cfgi_input=Git email [%cfgi_email%]: "
if defined cfgi_input set "cfgi_email=%cfgi_input%"
:ConfigureFallbackGitIdentityValidate
if not defined cfgi_name (call :PrintError "FAIL: Git author name is required." & exit /b 6)
if not defined cfgi_email (call :PrintError "FAIL: Git author email is required." & exit /b 6)
"%app.git%" -C "%app.folder%" config --local user.name "%cfgi_name%" >>"%app.log%" 2>&1
if errorlevel 1 (call :PrintError "FAIL: local Git user.name could not be set." & exit /b 6)
"%app.git%" -C "%app.folder%" config --local user.email "%cfgi_email%" >>"%app.log%" 2>&1
if errorlevel 1 (call :PrintError "FAIL: local Git user.email could not be set." & exit /b 6)
call :PrintSuccess "OK: Local Git identity configured."
set "cfgi_name="
set "cfgi_email="
set "cfgi_input="
set "cfgi_id="
exit /b 0

:RunFallbackGitPush
rem ============================================================
rem Function RunFallbackGitPush
rem Purpose
rem   Push the current branch after standalone GitHub login setup when requested.
rem Return codes
rem   0 Push completed skipped or no commits exist
rem   6 Push failed
rem Dependencies
rem   PrintInfo PrintSuccess PrintWarning PrintError
rem ============================================================
if /I "%app.push.mode%"=="no" (call :PrintWarning "SKIP: Git push disabled." & exit /b 0)
"%app.git%" -C "%app.folder%" rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 (call :PrintInfo "INFO: No commits exist yet; nothing to push." & exit /b 0)
set "rfgp_branch="
for /f "delims=" %%A in ('"%app.git%" -C "%app.folder%" branch --show-current 2^>nul') do if not defined rfgp_branch set "rfgp_branch=%%A"
if not defined rfgp_branch set "rfgp_branch=%app.repo.branch%"
call :PrintInfo "DO: Pushing branch %rfgp_branch% to origin."
"%app.git%" -C "%app.folder%" push -u origin "%rfgp_branch%" >>"%app.log%" 2>&1
if errorlevel 1 (call :PrintError "FAIL: Git push failed." & call :PrintWarning "LOG: %app.log%" & set "rfgp_branch=" & exit /b 6)
call :PrintSuccess "OK: Git push complete."
set "rfgp_branch="
exit /b 0

:MaybeMoveRepository
rem ============================================================
rem Function MaybeMoveRepository
rem Purpose
rem   Move the repository only when explicitly requested.
rem Outputs
rem   app.folder app.final.cd
rem Return codes
rem   0 Repository moved or move skipped
rem   7 Move failed
rem Dependencies
rem   MoveRepositoryToDocuments MoveRepositoryWithPicker MoveRepositoryToParent PrintInfo ResolvePathFromStart
rem   PrintError
rem ============================================================
if /I "%app.move.mode%"=="no" exit /b 0
if /I "%app.move.mode%"=="documents" call :MoveRepositoryToDocuments
if /I "%app.move.mode%"=="documents" exit /b %errorlevel%
if /I "%app.move.mode%"=="path" call :MoveRepositoryToParent "%app.move.parent%"
if /I "%app.move.mode%"=="path" exit /b %errorlevel%
set "mmr_choice="
set "mmr_parent="
set "mmr_rc=0"
call :PrintInfo "Move repository folder? Type n, y, or a destination parent path."
set /p "mmr_choice=Move to: "
if not defined mmr_choice exit /b 0
if /I "%mmr_choice%"=="n" (set "mmr_choice=" & exit /b 0)
if /I "%mmr_choice%"=="no" (set "mmr_choice=" & exit /b 0)
if /I "%mmr_choice%"=="y" call :MoveRepositoryWithPicker
if /I "%mmr_choice%"=="y" set "mmr_rc=%errorlevel%"
if /I "%mmr_choice%"=="yes" call :MoveRepositoryWithPicker
if /I "%mmr_choice%"=="yes" set "mmr_rc=%errorlevel%"
if /I "%mmr_choice%"=="y" goto :MaybeMoveRepositoryDone
if /I "%mmr_choice%"=="yes" goto :MaybeMoveRepositoryDone
call :ResolvePathFromStart "%mmr_choice%" mmr_parent
if errorlevel 1 (call :PrintError "FAIL: destination parent path could not be resolved." & set "mmr_rc=7" & goto :MaybeMoveRepositoryDone)
call :MoveRepositoryToParent "%mmr_parent%"
set "mmr_rc=%errorlevel%"
:MaybeMoveRepositoryDone
set "mmr_choice="
set "mmr_parent="
exit /b %mmr_rc%

:MoveRepositoryToDocuments
rem ============================================================
rem Function MoveRepositoryToDocuments
rem Purpose
rem   Move the repository beneath the Windows Documents folder.
rem Return codes
rem   0 Repository moved or already present
rem   7 Documents path or move failed
rem Dependencies
rem   MoveRepositoryToParent PrintError
rem ============================================================
set "mrtd_parent="
for /f "delims=" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "[Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)"') do set "mrtd_parent=%%A"
if not defined mrtd_parent (call :PrintError "FAIL: Documents folder could not be resolved." & exit /b 7)
if /I "%mrtd_parent%"=="." (call :PrintError "FAIL: Documents folder resolved to an invalid path." & set "mrtd_parent=" & exit /b 7)
call :MoveRepositoryToParent "%mrtd_parent%"
set "mrtd_rc=%errorlevel%"
set "mrtd_parent="
exit /b %mrtd_rc%

:MoveRepositoryWithPicker
rem ============================================================
rem Function MoveRepositoryWithPicker
rem Purpose
rem   Open a Windows folder picker and move the repository beneath the selected parent.
rem Return codes
rem   0 Repository moved or picker cancelled
rem   7 Move failed
rem Dependencies
rem   MoveRepositoryToParent PrintWarning
rem ============================================================
set "mrwp_parent="
for /f "delims=" %%A in ('powershell -NoProfile -STA -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description='Choose destination parent folder'; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$d.SelectedPath}"') do set "mrwp_parent=%%A"
if not defined mrwp_parent (call :PrintWarning "MOVE: cancelled; repository kept at %app.folder%." & exit /b 0)
call :MoveRepositoryToParent "%mrwp_parent%"
set "mrwp_rc=%errorlevel%"
set "mrwp_parent="
exit /b %mrwp_rc%

:MoveRepositoryToParent
rem ============================================================
rem Function MoveRepositoryToParent
rem Purpose
rem   Validate a destination parent then move or reuse a verified matching checkout.
rem Outputs
rem   app.folder app.final.cd and refreshed repository tool state
rem Return codes
rem   0 Repository moved or matching destination reused
rem   7 Move failed or destination conflicts
rem Dependencies
rem   IsDirectoryWritable IsPathWithin FindGit VerifyRepositoryRemote PrepareRepositoryTools PrintError
rem   PrintInfo PrintWarning PrependExecutableDirectoryToPath PrintSuccess
rem ============================================================
set "mrtp_parent=%~1"
set "mrtp_previous="
if not defined mrtp_parent exit /b 0
call :IsPathWithin "%mrtp_parent%" "%app.folder%"
set "mrtp_path_rc=%errorlevel%"
if "%mrtp_path_rc%"=="0" (call :PrintError "FAIL: destination parent cannot be inside the current repository." & set "mrtp_parent=" & set "mrtp_path_rc=" & exit /b 7)
set "mrtp_path_rc="
if not exist "%mrtp_parent%\" mkdir "%mrtp_parent%" >nul 2>&1
if not exist "%mrtp_parent%\" (call :PrintError "FAIL: destination parent does not exist and could not be created: %mrtp_parent%" & set "mrtp_parent=" & exit /b 7)
call :IsDirectoryWritable "%mrtp_parent%"
if errorlevel 1 (call :PrintError "FAIL: destination parent is not writable: %mrtp_parent%" & set "mrtp_parent=" & exit /b 7)
for %%A in ("%mrtp_parent%\%app.repo.name%") do set "app.final.folder=%%~fA"
if /I "%app.final.folder%"=="%app.folder%" (set "app.final.cd=%app.folder%" & set "mrtp_parent=" & exit /b 0)
call :IsPathWithin "%app.final.folder%" "%app.folder%"
if not errorlevel 1 (call :PrintError "FAIL: destination cannot be inside the current repository." & set "mrtp_parent=" & exit /b 7)
if exist "%app.final.folder%\.git" goto :MoveRepositoryToParentExisting
if exist "%app.final.folder%\" (call :PrintError "FAIL: destination exists and is not a Git checkout: %app.final.folder%" & set "mrtp_parent=" & exit /b 7)
set "mrtp_previous=%app.folder%"
call :PrintInfo "DO: Moving repository to %app.final.folder%."
robocopy "%app.folder%" "%app.final.folder%" /E /MOVE /NFL /NDL /NJH /NJS /NP >>"%app.log%" 2>&1
if errorlevel 8 (call :PrintError "FAIL: repository move failed." & call :PrintWarning "LOG: %app.log%" & set "mrtp_previous=" & set "mrtp_parent=" & exit /b 7)
if not exist "%app.final.folder%\.git" (call :PrintError "FAIL: moved destination is not a Git checkout." & set "app.folder=%app.final.folder%" & set "app.final.cd=%app.final.folder%" & set "mrtp_previous=" & set "mrtp_parent=" & exit /b 7)
set "app.folder=%app.final.folder%"
call :FindGit
if not defined app.git (call :PrintError "FAIL: Git could not be resolved after moving the repository." & set "app.final.cd=%app.folder%" & set "mrtp_previous=" & set "mrtp_parent=" & exit /b 7)
call :PrependExecutableDirectoryToPath "%app.git%"
call :VerifyRepositoryRemote
if errorlevel 1 (call :PrintError "FAIL: moved destination does not reference the expected repository." & set "app.final.cd=%app.folder%" & set "mrtp_previous=" & set "mrtp_parent=" & exit /b 7)
set "mrtp_previous="
goto :MoveRepositoryToParentRefresh
:MoveRepositoryToParentExisting
set "mrtp_previous=%app.folder%"
set "app.folder=%app.final.folder%"
call :FindGit
if not defined app.git (set "app.folder=%mrtp_previous%" & set "mrtp_previous=" & set "mrtp_parent=" & exit /b 7)
call :PrependExecutableDirectoryToPath "%app.git%"
call :VerifyRepositoryRemote
if errorlevel 1 (set "app.folder=%mrtp_previous%" & set "mrtp_previous=" & set "mrtp_parent=" & exit /b 7)
call :PrintInfo "INFO: using the existing matching destination checkout."
call :PrintWarning "NOTE: the original checkout remains at %mrtp_previous%."
set "mrtp_previous="
:MoveRepositoryToParentRefresh
set "app.final.cd=%app.folder%"
set "app.repo.tools.prepared="
call :PrepareRepositoryTools
if errorlevel 1 (set "mrtp_parent=" & exit /b 7)
call :PrintSuccess "OK: Repository ready at %app.folder%."
set "mrtp_parent="
exit /b 0

:RunProjectPrepare
rem ============================================================
rem Function RunProjectPrepare
rem Purpose
rem   Run the repository prepare launcher in project-only mode when present.
rem Return codes
rem   0 Preparation completed or launcher absent
rem   8 Preparation failed
rem Dependencies
rem   RunRepositoryLauncher
rem ============================================================
call :RunRepositoryLauncher "prepare.bat" "Project preparation" "project"
set "rpp_rc=%errorlevel%"
exit /b %rpp_rc%

:RunProjectBuild
rem ============================================================
rem Function RunProjectBuild
rem Purpose
rem   Run the repository build launcher when present.
rem Return codes
rem   0 Build completed or launcher absent
rem   8 Build failed
rem Dependencies
rem   RunRepositoryLauncher
rem ============================================================
call :RunRepositoryLauncher "build.bat" "Build"
set "rpb_rc=%errorlevel%"
exit /b %rpb_rc%

:RunProjectInstall
rem ============================================================
rem Function RunProjectInstall
rem Purpose
rem   Run the repository install launcher when present.
rem Return codes
rem   0 Installation completed or launcher absent
rem   8 Installation failed
rem Dependencies
rem   RunRepositoryLauncher
rem ============================================================
call :RunRepositoryLauncher "install.bat" "Install"
set "rpi_rc=%errorlevel%"
exit /b %rpi_rc%

:: ============================================================
:: SPECIAL PURPOSE HELPERS
:: ============================================================

:ParseBootstrapUrl
rem ============================================================
rem Function ParseBootstrapUrl
rem Purpose
rem   Parse a supported raw bootstrap URL into inferred repository and tools metadata.
rem   Explicit provider branch and tools URL values remain unchanged.
rem Outputs
rem   app.provider app.repo owner name branch URL and app.raw.tools.url
rem Return codes
rem   0 Parsing attempted
rem Dependencies
rem   PowerShell
rem ============================================================
set "pbu.provider="
set "pbu.repo.url="
set "pbu.repo.owner="
set "pbu.repo.name="
set "pbu.repo.branch="
set "pbu.raw.tools.url="
for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$u=${env:app.bootstrap.url}; if(!$u){$u=$env:bootstrap}; if(!$u){exit 0}; $b=${env:app.repo.branch}; if(!$b){$b='main'}; $x=[uri]$u; $s=$x.Scheme; $h=$x.Host.ToLowerInvariant(); $a=$x.Authority; $p=$x.AbsolutePath.Trim('/') -split '/'; $provider='git'; $owner=''; $repo=''; $branch=$b; $repoUrl=''; $raw=''; $repoPath=''; if($h -eq 'raw.githubusercontent.com' -and $p.Length -ge 4){$provider='github';$owner=$p[0];$repo=$p[1];$branch=$p[2];$repoPath=$owner+'/'+$repo;$repoUrl='https://github.com/'+$repoPath+'.git';$raw='https://raw.githubusercontent.com/'+$repoPath+'/'+$branch+'/tools'} elseif($h -eq 'github.com' -and $p.Length -ge 4 -and $p[2] -eq 'blob'){$provider='github';$owner=$p[0];$repo=$p[1];$branch=$p[3];$repoPath=$owner+'/'+$repo;$repoUrl='https://github.com/'+$repoPath+'.git';$raw='https://raw.githubusercontent.com/'+$repoPath+'/'+$branch+'/tools'} elseif($h -like '*gitlab*' -and ($p -contains '-')){$provider='gitlab';$i=[array]::IndexOf($p,'-');if($i -gt 0){$repo=$p[$i-1];$owner=($p[0..($i-2)] -join '/');$repoPath=($p[0..($i-1)] -join '/');$repoUrl=$s+'://'+$a+'/'+$repoPath+'.git';$j=$i+1;if($p.Length -gt ($j+1) -and ($p[$j] -eq 'raw' -or $p[$j] -eq 'blob')){$branch=$p[$j+1]};$raw=$s+'://'+$a+'/'+$repoPath+'/-/raw/'+$branch+'/tools'}} elseif($h -eq 'bitbucket.org' -and $p.Length -ge 4 -and ($p[2] -eq 'raw' -or $p[2] -eq 'src')){$provider='bitbucket';$owner=$p[0];$repo=$p[1];$branch=$p[3];$repoPath=$owner+'/'+$repo;$repoUrl='https://bitbucket.org/'+$repoPath+'.git';$raw='https://bitbucket.org/'+$repoPath+'/raw/'+$branch+'/tools'} elseif($p.Length -ge 4 -and ($p[2] -eq 'raw' -or $p[2] -eq 'src')){$provider='gitea';$owner=$p[0];$repo=$p[1];$branch=$p[3];$repoPath=$owner+'/'+$repo;$repoUrl=$s+'://'+$a+'/'+$repoPath+'.git';$raw=$s+'://'+$a+'/'+$repoPath+'/raw/'+$branch+'/tools'}; if($provider){'provider='+$provider};if($repoUrl){'repo.url='+$repoUrl};if($owner){'repo.owner='+$owner};if($repo){'repo.name='+$repo};if($branch){'repo.branch='+$branch};if($raw){'raw.tools.url='+$raw}" 2^>nul') do set "pbu.%%A=%%B"
if not defined app.explicit.provider if defined pbu.provider set "app.provider=%pbu.provider%"
if defined pbu.repo.url set "app.repo.url=%pbu.repo.url%"
if defined pbu.repo.owner set "app.repo.owner=%pbu.repo.owner%"
if defined pbu.repo.name set "app.repo.name=%pbu.repo.name%"
if not defined app.explicit.branch if defined pbu.repo.branch set "app.repo.branch=%pbu.repo.branch%"
if not defined app.explicit.toolsurl if defined pbu.raw.tools.url set "app.raw.tools.url=%pbu.raw.tools.url%"
set "pbu.provider="
set "pbu.repo.url="
set "pbu.repo.owner="
set "pbu.repo.name="
set "pbu.repo.branch="
set "pbu.raw.tools.url="
exit /b 0

:ParseRepositoryUrl
rem ============================================================
rem Function ParseRepositoryUrl
rem Purpose
rem   Normalize common HTTPS and SSH repository URLs and infer provider-specific raw tools URLs.
rem   Explicit provider and tools URL values remain unchanged.
rem Outputs
rem   app.provider app.repo owner name and helper URLs
rem Return codes
rem   0 Parsing attempted
rem Dependencies
rem   PowerShell
rem ============================================================
set "pru.provider="
set "pru.repo.owner="
set "pru.repo.name="
set "pru.raw.tools.url="
for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$u=${env:app.repo.url}; if(!$u){exit 0}; $b=${env:app.repo.branch}; if(!$b){$b='main'}; $q=$u -replace '^git@([^:]+):','https://$1/' -replace '^ssh://git@','https://'; $x=[uri]$q; $h=$x.Host.ToLowerInvariant(); $a=$x.Authority; $path=$x.AbsolutePath.Trim('/') -replace '\.git$',''; $p=$path -split '/'; $provider='git';$owner='';$repo='';$raw='';if($p.Length -ge 1){$repo=$p[$p.Length-1]};if($p.Length -ge 2){$owner=($p[0..($p.Length-2)] -join '/')};if($h -eq 'github.com'){$provider='github';$raw='https://raw.githubusercontent.com/'+$path+'/'+$b+'/tools'} elseif($h -like '*gitlab*'){$provider='gitlab';$raw=$x.Scheme+'://'+$a+'/'+$path+'/-/raw/'+$b+'/tools'} elseif($h -eq 'bitbucket.org'){$provider='bitbucket';$raw='https://bitbucket.org/'+$path+'/raw/'+$b+'/tools'} elseif($h -like '*codeberg.org' -or $h -like '*gitea*' -or $h -like '*forgejo*'){$provider='gitea';$raw=$x.Scheme+'://'+$a+'/'+$path+'/raw/'+$b+'/tools'};'provider='+$provider;if($owner){'repo.owner='+$owner};if($repo){'repo.name='+$repo};if($raw){'raw.tools.url='+$raw}" 2^>nul') do set "pru.%%A=%%B"
if not defined app.explicit.provider if defined pru.provider set "app.provider=%pru.provider%"
if defined pru.repo.owner set "app.repo.owner=%pru.repo.owner%"
if defined pru.repo.name set "app.repo.name=%pru.repo.name%"
if not defined app.explicit.toolsurl if defined pru.raw.tools.url set "app.raw.tools.url=%pru.raw.tools.url%"
set "pru.provider="
set "pru.repo.owner="
set "pru.repo.name="
set "pru.raw.tools.url="
if defined app.raw.tools.url if not defined app.getgit.url set "app.getgit.url=%app.raw.tools.url%/GetGit.bat"
if defined app.raw.tools.url if not defined app.getgh.url set "app.getgh.url=%app.raw.tools.url%/GetGithubCLI.bat"
exit /b 0

:EnsureGetGitHelper
rem ============================================================
rem Function EnsureGetGitHelper
rem Purpose
rem   Reuse a nonempty GetGit.bat or download a validated replacement.
rem Return codes
rem   0 Helper ready
rem   4 Helper URL missing or download failed
rem Dependencies
rem   IsFileNonEmpty DownloadFile PrintInfo PrintError
rem ============================================================
call :IsFileNonEmpty "%app.tools%\GetGit.bat"
if not errorlevel 1 exit /b 0
if exist "%app.tools%\GetGit.bat" del /q "%app.tools%\GetGit.bat" >nul 2>&1
if not exist "%app.tools%\" mkdir "%app.tools%" >nul 2>&1
if not defined app.getgit.url (call :PrintError "FAIL: GetGit.bat URL is unknown." & exit /b 4)
call :PrintInfo "GET: %app.getgit.url%"
call :DownloadFile "%app.getgit.url%" "%app.tools%\GetGit.bat"
if errorlevel 1 (call :PrintError "FAIL: GetGit.bat was not downloaded." & exit /b 4)
exit /b 0

:FindGit
rem ============================================================
rem Function FindGit
rem Purpose
rem   Resolve a repository-local, bootstrap-local, or PATH git.exe.
rem Outputs
rem   app.git
rem Return codes
rem   0 Search completed
rem Dependencies
rem   none
rem ============================================================
set "app.git="
if exist "%app.folder%\tools\git\cmd\git.exe" for %%A in ("%app.folder%\tools\git\cmd\git.exe") do set "app.git=%%~fA"
if not defined app.git if exist "%app.tools%\git\cmd\git.exe" for %%A in ("%app.tools%\git\cmd\git.exe") do set "app.git=%%~fA"
if not defined app.git for /f "delims=" %%A in ('where git.exe 2^>nul') do if not defined app.git set "app.git=%%~fA"
if defined app.git if not exist "%app.git%" set "app.git="
exit /b 0

:EnsureGitHubCli
rem ============================================================
rem Function EnsureGitHubCli
rem Purpose
rem   Resolve or install GitHub CLI through repository preparation or GetGithubCLI.bat.
rem Outputs
rem   app.gh and PATH
rem Return codes
rem   0 GitHub CLI ready
rem   6 GitHub CLI could not be installed
rem Dependencies
rem   PrepareRepositoryTools FindGitHubCli DownloadFile PrependExecutableDirectoryToPath PrintError
rem   IsFileNonEmpty PrintInfo PrintWarning PrintSuccess
rem ============================================================
call :PrepareRepositoryTools
if errorlevel 1 exit /b 6
call :FindGitHubCli
if defined app.gh goto :EnsureGitHubCliReady
if not defined app.getgh.url (call :PrintError "FAIL: GetGithubCLI.bat URL is unknown." & exit /b 6)
if not exist "%app.folder%\tools\" mkdir "%app.folder%\tools" >nul 2>&1
call :IsFileNonEmpty "%app.folder%\tools\GetGithubCLI.bat"
if errorlevel 1 if exist "%app.folder%\tools\GetGithubCLI.bat" del /q "%app.folder%\tools\GetGithubCLI.bat" >nul 2>&1
call :IsFileNonEmpty "%app.folder%\tools\GetGithubCLI.bat"
if errorlevel 1 call :DownloadFile "%app.getgh.url%" "%app.folder%\tools\GetGithubCLI.bat"
call :IsFileNonEmpty "%app.folder%\tools\GetGithubCLI.bat"
if errorlevel 1 (call :PrintError "FAIL: GetGithubCLI.bat was not found or is empty." & exit /b 6)
call :PrintInfo "DO: Installing GitHub CLI using GetGithubCLI.bat."
pushd "%app.folder%" >nul 2>&1
if errorlevel 1 (call :PrintError "FAIL: repository folder could not be entered for GitHub CLI installation." & exit /b 6)
cmd.exe /D /C call "tools\GetGithubCLI.bat" >>"%app.log%" 2>&1
set "eghc_rc=%errorlevel%"
popd >nul
if not "%eghc_rc%"=="0" (call :PrintError "FAIL: GetGithubCLI.bat failed." & call :PrintWarning "LOG: %app.log%" & set "eghc_rc=" & exit /b 6)
set "eghc_rc="
call :FindGitHubCli
if not defined app.gh (call :PrintError "FAIL: gh.exe is missing after GetGithubCLI.bat." & exit /b 6)
:EnsureGitHubCliReady
call :PrependExecutableDirectoryToPath "%app.gh%"
call :PrintSuccess "OK: GitHub CLI ready: %app.gh%"
exit /b 0

:FindGitHubCli
rem ============================================================
rem Function FindGitHubCli
rem Purpose
rem   Resolve a repository-local, bootstrap-local, or PATH gh.exe.
rem Outputs
rem   app.gh
rem Return codes
rem   0 Search completed
rem Dependencies
rem   none
rem ============================================================
set "app.gh="
if exist "%app.folder%\tools\gh\bin\gh.exe" for %%A in ("%app.folder%\tools\gh\bin\gh.exe") do set "app.gh=%%~fA"
if not defined app.gh if exist "%app.tools%\gh\bin\gh.exe" for %%A in ("%app.tools%\gh\bin\gh.exe") do set "app.gh=%%~fA"
if not defined app.gh for /f "delims=" %%A in ('where gh.exe 2^>nul') do if not defined app.gh set "app.gh=%%~fA"
if defined app.gh if not exist "%app.gh%" set "app.gh="
exit /b 0

:PromptLoginMethod
rem ============================================================
rem Function PromptLoginMethod
rem Purpose
rem   Ask which browser behavior the standalone GitHub login fallback should use.
rem Outputs
rem   app.login.method
rem Return codes
rem   0 Valid method selected
rem   6 Invalid method selected
rem Dependencies
rem   PrintError
rem ============================================================
echo(
echo(  1. Let GitHub CLI open the default browser
echo(  2. Open the default browser now
echo(  3. Open a private browser now
echo(  4. Do not open a browser on this computer
set "plm_choice="
set /p "plm_choice=Choice [1]: "
if not defined plm_choice set "plm_choice=1"
if "%plm_choice%"=="1" set "app.login.method=1"
if "%plm_choice%"=="2" set "app.login.method=2"
if "%plm_choice%"=="3" set "app.login.method=3"
if "%plm_choice%"=="4" set "app.login.method=4"
if not "%plm_choice%"=="1" if not "%plm_choice%"=="2" if not "%plm_choice%"=="3" if not "%plm_choice%"=="4" (call :PrintError "FAIL: login method must be 1, 2, 3, or 4." & set "plm_choice=" & exit /b 6)
set "plm_choice="
exit /b 0

:OpenDeviceLoginPage
rem ============================================================
rem Function OpenDeviceLoginPage
rem Purpose
rem   Open the GitHub device page according to login method 2 or 3 and leave methods 1 and 4 untouched.
rem Inputs
rem   Login method
rem Return codes
rem   0 Page opened or deliberately not opened
rem Dependencies
rem   PrintWarning PrintInfo
rem ============================================================
if "%~1"=="2" start "" "https://github.com/login/device"
if "%~1"=="3" powershell -NoProfile -ExecutionPolicy Bypass -Command "$u='https://github.com/login/device'; $p=$env:ProgramFiles+'\Google\Chrome\Application\chrome.exe'; if(Test-Path -LiteralPath $p){Start-Process -FilePath $p -ArgumentList @('--incognito',$u); exit 0}; $p=${env:ProgramFiles(x86)}+'\Microsoft\Edge\Application\msedge.exe'; if(Test-Path -LiteralPath $p){Start-Process -FilePath $p -ArgumentList @('--inprivate',$u); exit 0}; $p=$env:ProgramFiles+'\Mozilla Firefox\firefox.exe'; if(Test-Path -LiteralPath $p){Start-Process -FilePath $p -ArgumentList @('-private-window',$u); exit 0}; exit 1" >nul 2>&1
if "%~1"=="3" if errorlevel 1 call :PrintWarning "WARN: a supported private browser was not found; open the device page manually."
if "%~1"=="4" call :PrintInfo "Open https://github.com/login/device on any computer when GitHub CLI shows the code."
exit /b 0

:CheckGitHubAuthentication
rem ============================================================
rem Function CheckGitHubAuthentication
rem Purpose
rem   Confirm GitHub CLI authentication and capture the authenticated username.
rem Outputs
rem   app.github.user
rem Return codes
rem   0 Authenticated user resolved
rem   6 Authentication unavailable
rem Dependencies
rem   GetGitHubUser
rem ============================================================
if not defined app.gh exit /b 6
"%app.gh%" auth status -h github.com >>"%app.log%" 2>&1
if errorlevel 1 exit /b 6
call :GetGitHubUser
if errorlevel 1 exit /b 6
exit /b 0

:GetGitHubUser
rem ============================================================
rem Function GetGitHubUser
rem Purpose
rem   Read the authenticated GitHub login through the API.
rem Outputs
rem   app.github.user
rem Return codes
rem   0 Username resolved
rem   6 Username unavailable
rem Dependencies
rem   none
rem ============================================================
set "app.github.user="
if not defined app.gh exit /b 6
for /f "usebackq delims=" %%A in (`"%app.gh%" api user --jq ".login" 2^>nul`) do if not defined app.github.user set "app.github.user=%%A"
if defined app.github.user exit /b 0
exit /b 6

:CheckGitHubWritePermission
rem ============================================================
rem Function CheckGitHubWritePermission
rem Purpose
rem   Check whether the authenticated account owns or can write to the original GitHub repository.
rem Return codes
rem   0 Direct write access confirmed
rem   1 Direct write access unavailable or unknown
rem Dependencies
rem   GetGitHubUser
rem ============================================================
if not defined app.github.user call :GetGitHubUser
if errorlevel 1 exit /b 1
if /I "%app.github.user%"=="%app.repo.owner%" exit /b 0
set "cgp_permission="
for /f "usebackq delims=" %%A in (`"%app.gh%" repo view "%app.repo.owner%/%app.repo.name%" --json viewerPermission --jq ".viewerPermission" 2^>nul`) do set "cgp_permission=%%A"
if /I "%cgp_permission%"=="ADMIN" (set "cgp_permission=" & exit /b 0)
if /I "%cgp_permission%"=="MAINTAIN" (set "cgp_permission=" & exit /b 0)
if /I "%cgp_permission%"=="WRITE" (set "cgp_permission=" & exit /b 0)
set "cgp_permission="
exit /b 1

:PromptForkChoice
rem ============================================================
rem Function PromptForkChoice
rem Purpose
rem   Ask whether to create or reuse a personal fork, defaulting to yes.
rem Outputs
rem   app.fork.mode
rem Return codes
rem   0 Fork decision resolved
rem Dependencies
rem   PrintWarning
rem ============================================================
set "pfc_choice="
set /p "pfc_choice=Create or use a personal fork? [Y/n]: "
if not defined pfc_choice (set "app.fork.mode=yes" & exit /b 0)
if /I "%pfc_choice%"=="y" (set "app.fork.mode=yes" & set "pfc_choice=" & exit /b 0)
if /I "%pfc_choice%"=="yes" (set "app.fork.mode=yes" & set "pfc_choice=" & exit /b 0)
if /I "%pfc_choice%"=="n" (set "app.fork.mode=no" & set "pfc_choice=" & exit /b 0)
if /I "%pfc_choice%"=="no" (set "app.fork.mode=no" & set "pfc_choice=" & exit /b 0)
call :PrintWarning "Choose y or n."
goto :PromptForkChoice

:CreateGitHubFork
rem ============================================================
rem Function CreateGitHubFork
rem Purpose
rem   Verify or create the personal fork through the GitHub API.
rem Return codes
rem   0 Fork exists and is visible
rem   6 Fork creation or visibility check failed
rem Dependencies
rem   VerifyGitHubFork WaitForGitHubFork PrintInfo PrintError
rem ============================================================
call :VerifyGitHubFork
set "cgf_rc=%errorlevel%"
if "%cgf_rc%"=="0" (set "cgf_rc=" & exit /b 0)
if "%cgf_rc%"=="6" (set "cgf_rc=" & exit /b 6)
set "cgf_rc="
call :PrintInfo "DO: Creating fork %app.github.user%/%app.repo.name%."
"%app.gh%" api --method POST "repos/%app.repo.owner%/%app.repo.name%/forks" >nul 2>>"%app.log%"
if errorlevel 1 (call :PrintError "FAIL: GitHub could not create the fork." & exit /b 6)
call :WaitForGitHubFork
if errorlevel 1 (call :PrintError "FAIL: the new fork did not become visible or did not match the original repository." & exit /b 6)
exit /b 0

:VerifyGitHubFork
rem ============================================================
rem Function VerifyGitHubFork
rem Purpose
rem   Confirm that the authenticated account repository is a fork of the configured original repository.
rem Return codes
rem   0 Matching fork exists
rem   1 Repository does not exist yet
rem   6 Existing repository is not the expected fork
rem Dependencies
rem   PrintError PrintWarning
rem ============================================================
set "vgf_is_fork="
set "vgf_parent="
set "vgf_source="
"%app.gh%" repo view "%app.github.user%/%app.repo.name%" >nul 2>&1
if errorlevel 1 exit /b 1
for /f "delims=" %%A in ('"%app.gh%" api "repos/%app.github.user%/%app.repo.name%" --jq ".fork" 2^>nul') do set "vgf_is_fork=%%A"
for /f "delims=" %%A in ('"%app.gh%" api "repos/%app.github.user%/%app.repo.name%" --jq ".parent.full_name // empty" 2^>nul') do set "vgf_parent=%%A"
for /f "delims=" %%A in ('"%app.gh%" api "repos/%app.github.user%/%app.repo.name%" --jq ".source.full_name // empty" 2^>nul') do set "vgf_source=%%A"
if /I "%vgf_is_fork%"=="true" if /I "%vgf_parent%"=="%app.repo.owner%/%app.repo.name%" (set "vgf_is_fork=" & set "vgf_parent=" & set "vgf_source=" & exit /b 0)
if /I "%vgf_is_fork%"=="true" if /I "%vgf_source%"=="%app.repo.owner%/%app.repo.name%" (set "vgf_is_fork=" & set "vgf_parent=" & set "vgf_source=" & exit /b 0)
call :PrintError "FAIL: %app.github.user%/%app.repo.name% exists but is not a fork of the expected repository."
call :PrintWarning "EXPECTED: %app.repo.owner%/%app.repo.name%"
set "vgf_is_fork="
set "vgf_parent="
set "vgf_source="
exit /b 6

:WaitForGitHubFork
rem ============================================================
rem Function WaitForGitHubFork
rem Purpose
rem   Poll GitHub until the personal fork becomes visible and matches the original repository.
rem Return codes
rem   0 Matching fork visible
rem   6 Fork mismatch or timeout
rem Dependencies
rem   VerifyGitHubFork
rem ============================================================
set "wfgf_count=0"
:WaitForGitHubForkPoll
call :VerifyGitHubFork
set "wfgf_rc=%errorlevel%"
if "%wfgf_rc%"=="0" (set "wfgf_count=" & set "wfgf_rc=" & exit /b 0)
if "%wfgf_rc%"=="6" (set "wfgf_count=" & set "wfgf_rc=" & exit /b 6)
set "wfgf_rc="
set /a wfgf_count+=1 >nul
if %wfgf_count% GEQ 30 (set "wfgf_count=" & exit /b 6)
timeout /t 2 /nobreak >nul
goto :WaitForGitHubForkPoll

:ConfigureOriginalRemote
rem ============================================================
rem Function ConfigureOriginalRemote
rem Purpose
rem   Configure origin to the original repository for direct-push or read-only fallback mode.
rem Return codes
rem   0 Origin configured
rem   6 Origin could not be configured
rem Dependencies
rem   SetGitRemote PrintError
rem ============================================================
call :SetGitRemote "origin" "%app.repo.original.url%"
set "cor_rc=%errorlevel%"
if not "%cor_rc%"=="0" (call :PrintError "FAIL: origin remote could not be configured." & set "cor_rc=" & exit /b 6)
set "cor_rc="
exit /b 0

:ConfigureForkRemotes
rem ============================================================
rem Function ConfigureForkRemotes
rem Purpose
rem   Set upstream to the original repository and origin to the authenticated personal fork.
rem Return codes
rem   0 Remotes configured and fetched
rem   6 Remote configuration or fetch failed
rem Dependencies
rem   SetGitRemote PrintError PrintWarning PrintSuccess
rem ============================================================
set "cfr_fork=https://github.com/%app.github.user%/%app.repo.name%.git"
call :SetGitRemote "upstream" "%app.repo.original.url%"
set "cfr_rc=%errorlevel%"
if not "%cfr_rc%"=="0" (call :PrintError "FAIL: upstream remote could not be configured." & set "cfr_fork=" & set "cfr_rc=" & exit /b 6)
call :SetGitRemote "origin" "%cfr_fork%"
set "cfr_rc=%errorlevel%"
if not "%cfr_rc%"=="0" (call :PrintError "FAIL: origin remote could not be configured." & set "cfr_fork=" & set "cfr_rc=" & exit /b 6)
"%app.git%" -C "%app.folder%" fetch upstream --prune >>"%app.log%" 2>&1
set "cfr_rc=%errorlevel%"
if not "%cfr_rc%"=="0" (call :PrintError "FAIL: upstream fetch failed." & call :PrintWarning "LOG: %app.log%" & set "cfr_fork=" & set "cfr_rc=" & exit /b 6)
"%app.git%" -C "%app.folder%" fetch origin --prune >>"%app.log%" 2>&1
set "cfr_rc=%errorlevel%"
if not "%cfr_rc%"=="0" (call :PrintError "FAIL: origin fetch failed." & call :PrintWarning "LOG: %app.log%" & set "cfr_fork=" & set "cfr_rc=" & exit /b 6)
set "app.repo.sync.remote=upstream"
set "cfr_fork="
set "cfr_rc="
call :PrintSuccess "OK: fork remotes configured."
exit /b 0

:QuarantineNonGitFolder
rem ============================================================
rem Function QuarantineNonGitFolder
rem Purpose
rem   Move an existing non-Git target folder aside before cloning.
rem Return codes
rem   0 Folder moved aside
rem   5 Folder could not be moved
rem Dependencies
rem   PrintWarning PrintInfo PrintError
rem ============================================================
set "qngf_target=%app.folder%.notgit.%app.timestamp%-%RANDOM%"
call :PrintWarning "WARN: target exists but is not a Git checkout."
call :PrintInfo "DO: Moving it to %qngf_target%."
move "%app.folder%" "%qngf_target%" >>"%app.log%" 2>&1
set "qngf_rc=%errorlevel%"
if not "%qngf_rc%"=="0" if not exist "%app.folder%\" (set "qngf_target=" & set "qngf_rc=" & exit /b 0)
if not "%qngf_rc%"=="0" (call :PrintError "FAIL: existing target could not be moved." & set "qngf_target=" & set "qngf_rc=" & exit /b 5)
set "qngf_target="
set "qngf_rc="
exit /b 0

:WarnIfTemporaryRepository
rem ============================================================
rem Function WarnIfTemporaryRepository
rem Purpose
rem   Warn only when the completed Git checkout is actually located beneath TEMP.
rem Return codes
rem   0 Warning evaluated
rem Dependencies
rem   IsPathWithin PrintWarning
rem ============================================================
if not defined app.repo.ready exit /b 0
if not exist "%app.folder%\.git" exit /b 0
call :IsPathWithin "%app.folder%" "%TEMP%"
if errorlevel 1 exit /b 0
echo(
call :PrintWarning "WARNING: The repository is inside the Windows temporary folder."
call :PrintWarning "  %app.folder%"
call :PrintWarning "Move this repository to a permanent folder before relying on it."
exit /b 0

:DrawMenu
rem ============================================================
rem Function DrawMenu
rem Purpose
rem   Draw the interactive bootstrap menu.
rem Return codes
rem   0 Menu displayed
rem Dependencies
rem   none
rem ============================================================
echo(+------------------------------------------------------------+
echo(^|                    Bootstrap Menu                         ^|
echo(+------------------------------------------------------------+
echo(^|  1  Clone or update repository                            ^|
echo(^|  2  Provider login and fork handling                      ^|
echo(^|  3  Run prepare.bat                                       ^|
echo(^|  4  Run build.bat                                         ^|
echo(^|  5  Run install.bat                                       ^|
echo(^|  6  Move repository                                       ^|
echo(^|  7  Run repository bootstrap                              ^|
echo(^|  A  Run auto workflow                                     ^|
echo(^|  0  Exit                                                  ^|
echo(+------------------------------------------------------------+
exit /b 0

:: ============================================================
:: REUSABLE GENERIC HELPERS
:: ============================================================

:SetGitRemote
rem ============================================================
rem Function SetGitRemote
rem Purpose
rem   Add or update one Git remote in the current repository folder.
rem Inputs
rem   Remote name and URL
rem Return codes
rem   0 Remote configured
rem   6 Name URL or Git command failed
rem Dependencies
rem   none
rem ============================================================
set "sgr_name=%~1"
set "sgr_url=%~2"
if not defined sgr_name (set "sgr_url=" & exit /b 6)
if not defined sgr_url (set "sgr_name=" & exit /b 6)
"%app.git%" -C "%app.folder%" remote get-url "%sgr_name%" >nul 2>&1
set "sgr_rc=%errorlevel%"
if "%sgr_rc%"=="0" goto :SetGitRemoteUpdate
"%app.git%" -C "%app.folder%" remote add "%sgr_name%" "%sgr_url%" >>"%app.log%" 2>&1
set "sgr_rc=%errorlevel%"
goto :SetGitRemoteDone
:SetGitRemoteUpdate
"%app.git%" -C "%app.folder%" remote set-url "%sgr_name%" "%sgr_url%" >>"%app.log%" 2>&1
set "sgr_rc=%errorlevel%"
:SetGitRemoteDone
set "sgr_name="
set "sgr_url="
if not "%sgr_rc%"=="0" (set "sgr_rc=" & exit /b 6)
set "sgr_rc="
exit /b 0

:RunRepositoryLauncher
rem ============================================================
rem Function RunRepositoryLauncher
rem Purpose
rem   Run one optional repository batch launcher with optional arguments and consistent error handling.
rem Inputs
rem   Launcher file name action name and optional argument string
rem Return codes
rem   0 Launcher completed or was absent
rem   8 Launcher failed
rem Dependencies
rem   PrintInfo PrintWarning PrintSuccess PrintError
rem ============================================================
set "rrl_script=%~1"
set "rrl_action=%~2"
set "rrl_arguments=%~3"
if not exist "%app.folder%\%rrl_script%" (call :PrintWarning "SKIP: %rrl_script% not found." & set "rrl_script=" & set "rrl_action=" & set "rrl_arguments=" & exit /b 0)
call :PrintInfo "DO: %rrl_action%."
pushd "%app.folder%" >nul 2>&1
if errorlevel 1 (call :PrintError "FAIL: repository folder could not be entered for %rrl_action%." & set "rrl_script=" & set "rrl_action=" & set "rrl_arguments=" & exit /b 8)
if defined rrl_arguments call "%rrl_script%" %rrl_arguments%
if defined rrl_arguments set "rrl_rc=%errorlevel%"
if not defined rrl_arguments call "%rrl_script%"
if not defined rrl_arguments set "rrl_rc=%errorlevel%"
popd >nul
if not "%rrl_rc%"=="0" (call :PrintError "FAIL: %rrl_action% failed." & set "rrl_script=" & set "rrl_action=" & set "rrl_arguments=" & set "rrl_rc=" & exit /b 8)
call :PrintSuccess "OK: %rrl_action% complete."
set "rrl_script="
set "rrl_action="
set "rrl_arguments="
set "rrl_rc="
exit /b 0

:MakeTimestamp
rem ============================================================
rem Function MakeTimestamp
rem Purpose
rem   Create a sortable local timestamp for log and quarantine names.
rem Outputs
rem   app.timestamp
rem Return codes
rem   0 Timestamp created
rem   1 Timestamp unavailable
rem Dependencies
rem   none
rem ============================================================
set "app.timestamp="
for /f "delims=" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date -Format yyyy-MM-dd.HHmmss" 2^>nul') do set "app.timestamp=%%A"
if not defined app.timestamp exit /b 1
exit /b 0

:IsDirectoryWritable
rem ============================================================
rem Function IsDirectoryWritable
rem Purpose
rem   Test directory write access by creating and deleting a unique probe file.
rem Inputs
rem   Directory path
rem Return codes
rem   0 Directory is writable
rem   1 Directory is missing or not writable
rem Dependencies
rem   none
rem ============================================================
set "idw_dir=%~1"
set "idw_file="
if not defined idw_dir exit /b 1
if not exist "%idw_dir%\" exit /b 1
set "idw_file=%idw_dir%\.bootstrap-write-test-%RANDOM%-%RANDOM%.tmp"
>"%idw_file%" echo bootstrap-write-test 2>nul
if not exist "%idw_file%" (set "idw_dir=" & set "idw_file=" & exit /b 1)
del /q "%idw_file%" >nul 2>&1
if exist "%idw_file%" (set "idw_dir=" & set "idw_file=" & exit /b 1)
set "idw_dir="
set "idw_file="
exit /b 0

:IsPathWithin
rem ============================================================
rem Function IsPathWithin
rem Purpose
rem   Test whether one absolute path is equal to or beneath another path.
rem Inputs
rem   Candidate path and parent path
rem Return codes
rem   0 Candidate is within parent
rem   1 Candidate is outside parent or comparison failed
rem Dependencies
rem   none
rem ============================================================
set "ipw_candidate=%~1"
set "ipw_parent=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=[IO.Path]::GetFullPath($env:ipw_candidate).TrimEnd([char]92); $p=[IO.Path]::GetFullPath($env:ipw_parent).TrimEnd([char]92); if($c.Equals($p,[StringComparison]::OrdinalIgnoreCase) -or $c.StartsWith($p+[char]92,[StringComparison]::OrdinalIgnoreCase)){exit 0}; exit 1" >nul 2>&1
set "ipw_rc=%errorlevel%"
set "ipw_candidate="
set "ipw_parent="
exit /b %ipw_rc%

:NormalizeGitUrl
rem ============================================================
rem Function NormalizeGitUrl
rem Purpose
rem   Normalize HTTPS and SSH Git URLs for case-insensitive repository comparison.
rem Inputs
rem   URL and output variable name
rem Outputs
rem   Named output variable
rem Return codes
rem   0 Normalized value produced
rem   1 Input output name or normalization result is unavailable
rem Dependencies
rem   none
rem ============================================================
set "ngu_url=%~1"
set "ngu_output=%~2"
if not defined ngu_output exit /b 1
set "%ngu_output%="
set "BOOTSTRAP_NORMALIZE_URL=%ngu_url%"
for /f "delims=" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$u=$env:BOOTSTRAP_NORMALIZE_URL; if(!$u){exit 0}; $u=$u.Trim() -replace '^git@([^:]+):','https://$1/' -replace '^ssh://git@','https://'; $u=$u.TrimEnd('/') -replace '\.git$',''; $u.ToLowerInvariant()" 2^>nul') do set "%ngu_output%=%%A"
set "BOOTSTRAP_NORMALIZE_URL="
if not defined %ngu_output% goto :NormalizeGitUrlFailed
set "ngu_url="
set "ngu_output="
exit /b 0
:NormalizeGitUrlFailed
set "ngu_url="
set "ngu_output="
exit /b 1

:ParseYesNoValue
rem ============================================================
rem Function ParseYesNoValue
rem Purpose
rem   Validate a yes or no value and assign it to a named variable.
rem Inputs
rem   Value and output variable name
rem Return codes
rem   0 Valid value assigned
rem   1 Value or output name is invalid
rem Dependencies
rem   none
rem ============================================================
if "%~2"=="" exit /b 1
if /I "%~1"=="yes" (set "%~2=yes" & exit /b 0)
if /I "%~1"=="no" (set "%~2=no" & exit /b 0)
exit /b 1

:ResolvePathFromStart
rem ============================================================
rem Function ResolvePathFromStart
rem Purpose
rem   Resolve an absolute path or resolve a relative path against the launch directory.
rem Inputs
rem   Input path and output variable name
rem Return codes
rem   0 Path resolved
rem   1 Input or output name is missing
rem Dependencies
rem   none
rem ============================================================
set "rpfs_input=%~1"
set "rpfs_output=%~2"
if not defined rpfs_input exit /b 1
if not defined rpfs_output (set "rpfs_input=" & exit /b 1)
if "%rpfs_input:~1,1%"==":" goto :ResolvePathFromStartAbsolute
if "%rpfs_input:~0,2%"=="\\" goto :ResolvePathFromStartAbsolute
if "%rpfs_input:~0,1%"=="\" goto :ResolvePathFromStartAbsolute
if "%rpfs_input:~0,1%"=="/" goto :ResolvePathFromStartAbsolute
for %%A in ("%app.start.dir%\%rpfs_input%") do set "%rpfs_output%=%%~fA"
goto :ResolvePathFromStartDone
:ResolvePathFromStartAbsolute
for %%A in ("%rpfs_input%") do set "%rpfs_output%=%%~fA"
:ResolvePathFromStartDone
set "rpfs_input="
set "rpfs_output="
exit /b 0

:IsFileNonEmpty
rem ============================================================
rem Function IsFileNonEmpty
rem Purpose
rem   Confirm that a regular file exists and has a nonzero size.
rem Inputs
rem   File path
rem Return codes
rem   0 File exists and is nonempty
rem   1 File is missing empty or not a regular file
rem Dependencies
rem   none
rem ============================================================
if "%~1"=="" exit /b 1
if not exist "%~1" exit /b 1
for %%A in ("%~1") do if %%~zA GTR 0 exit /b 0
exit /b 1

:DownloadFile
rem ============================================================
rem Function DownloadFile
rem Purpose
rem   Download through a temporary file with curl or PowerShell then atomically promote a nonempty result.
rem Inputs
rem   URL and destination file
rem Return codes
rem   0 Nonempty file downloaded
rem   4 Download failed or produced an empty file
rem Dependencies
rem   IsFileNonEmpty
rem ============================================================
set "df_url=%~1"
set "df_file=%~2"
set "df_temp=%~2.download.%RANDOM%-%RANDOM%.tmp"
set "df_rc=4"
if exist "%df_temp%" del /q "%df_temp%" >nul 2>&1
if exist "%df_file%" del /q "%df_file%" >nul 2>&1
where curl.exe >nul 2>nul
if errorlevel 1 goto :DownloadFilePowerShell
curl.exe -sSfL --retry 3 "%df_url%" -o "%df_temp%" >>"%app.log%" 2>&1
set "df_rc=%errorlevel%"
if not "%df_rc%"=="0" goto :DownloadFileCurlFailed
call :IsFileNonEmpty "%df_temp%"
set "df_rc=%errorlevel%"
if "%df_rc%"=="0" goto :DownloadFileCommit
:DownloadFileCurlFailed
if exist "%df_temp%" del /q "%df_temp%" >nul 2>&1
:DownloadFilePowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri $env:df_url -OutFile $env:df_temp" >>"%app.log%" 2>&1
set "df_rc=%errorlevel%"
if not "%df_rc%"=="0" goto :DownloadFileFailed
call :IsFileNonEmpty "%df_temp%"
set "df_rc=%errorlevel%"
if not "%df_rc%"=="0" goto :DownloadFileFailed
:DownloadFileCommit
move /y "%df_temp%" "%df_file%" >nul 2>&1
set "df_rc=%errorlevel%"
if not "%df_rc%"=="0" goto :DownloadFileFailed
call :IsFileNonEmpty "%df_file%"
set "df_rc=%errorlevel%"
if not "%df_rc%"=="0" goto :DownloadFileFailed
set "df_url="
set "df_file="
set "df_temp="
set "df_rc="
exit /b 0
:DownloadFileFailed
if exist "%df_temp%" del /q "%df_temp%" >nul 2>&1
if exist "%df_file%" del /q "%df_file%" >nul 2>&1
set "df_url="
set "df_file="
set "df_temp="
set "df_rc="
exit /b 4

:PrependExecutableDirectoryToPath
rem ============================================================
rem Function PrependExecutableDirectoryToPath
rem Purpose
rem   Prepend an executable directory to PATH only when it is not already present.
rem Inputs
rem   Executable path
rem Return codes
rem   0 PATH updated or no change required
rem Dependencies
rem   none
rem ============================================================
set "pedtp_dir="
if "%~1"=="" exit /b 0
for %%A in ("%~1") do set "pedtp_dir=%%~dpA"
if not defined pedtp_dir exit /b 0
echo(;%PATH%;| find /I ";%pedtp_dir%;" >nul 2>nul
if errorlevel 1 set "PATH=%pedtp_dir%;%PATH%"
set "pedtp_dir="
exit /b 0

:PrintSuccess
rem ============================================================
rem Function PrintSuccess
rem Purpose
rem   Print and log a success message.
rem Inputs
rem   Message
rem Return codes
rem   0 Message processed
rem Dependencies
rem   PrintColor
rem ============================================================
call :PrintColor "%app.color.green%" "%~1"
exit /b 0

:PrintInfo
rem ============================================================
rem Function PrintInfo
rem Purpose
rem   Print and log an informational message.
rem Inputs
rem   Message
rem Return codes
rem   0 Message processed
rem Dependencies
rem   PrintColor
rem ============================================================
call :PrintColor "%app.color.cyan%" "%~1"
exit /b 0

:PrintWarning
rem ============================================================
rem Function PrintWarning
rem Purpose
rem   Print and log a warning message.
rem Inputs
rem   Message
rem Return codes
rem   0 Message processed
rem Dependencies
rem   PrintColor
rem ============================================================
call :PrintColor "%app.color.yellow%" "%~1"
exit /b 0

:PrintError
rem ============================================================
rem Function PrintError
rem Purpose
rem   Print and log an error message.
rem Inputs
rem   Message
rem Return codes
rem   0 Message processed
rem Dependencies
rem   PrintColor
rem ============================================================
call :PrintColor "%app.color.red%" "%~1"
exit /b 0

:PrintColor
rem ============================================================
rem Function PrintColor
rem Purpose
rem   Print one message with optional ANSI colour and append the plain message to the log.
rem Inputs
rem   Colour sequence and message
rem Return codes
rem   0 Message processed
rem Dependencies
rem   none
rem ============================================================
set "pc_color=%~1"
set "pc_message=%~2"
if not defined app.esc goto :PrintColorPlain
<nul set /p "=%app.esc%[%pc_color%%pc_message%%app.esc%[%app.color.reset%"
echo(
goto :PrintColorLog
:PrintColorPlain
<nul set /p "=%pc_message%"
echo(
:PrintColorLog
if not defined app.log goto :PrintColorDone
>>"%app.log%" <nul set /p "=%pc_message%"
>>"%app.log%" echo(
:PrintColorDone
set "pc_color="
set "pc_message="
exit /b 0

:SetEscapeCharacter
rem ============================================================
rem Function SetEscapeCharacter
rem Purpose
rem   Capture the ANSI escape character into a named variable.
rem Inputs
rem   Output variable name
rem Return codes
rem   0 Escape character captured
rem   2 Output variable missing
rem Dependencies
rem   none
rem ============================================================
set "sec_output=%~1"
if not defined sec_output exit /b 2
for /f %%A in ('echo prompt $E^| cmd') do set "%sec_output%=%%A"
set "sec_output="
exit /b 0

:SetExitCode
rem ============================================================
rem Function SetExitCode
rem Purpose
rem   Set the final process error level before the top-level goto eof.
rem Inputs
rem   Numeric exit code
rem Return codes
rem   same Requested exit code
rem Dependencies
rem   none
rem ============================================================
exit /b %~1
