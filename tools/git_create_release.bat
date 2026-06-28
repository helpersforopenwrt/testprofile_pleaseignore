@echo off
:: ============================================================
:: git_create_release.bat
:: Creates a GitHub release from an existing local tag.
::
:: Usage:
::   call tools\git_create_release.bat tag v1.0.0
::   call tools\git_create_release.bat tag v1.0.0 title "Version 1.0"
::   call tools\git_create_release.bat tag v1.0.0 notes "Release notes"
::   call tools\git_create_release.bat tag v1.0.0 draft yes prerelease no pushtag yes
::
:: Returns: 0 on success or cancellation
::          1 on repository, authentication, tag, push, or release failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, gh, :Main, :ParseArgs,
::           :NormalizeYesNo, :EnsureGitHubAuthentication,
::           :ResolveRepository, :ValidateRelease, :ShowPlan,
::           :CreateRelease, :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_create_release.tag="
set "app.git_create_release.title="
set "app.git_create_release.notes="
set "app.git_create_release.draft=no"
set "app.git_create_release.prerelease=no"
set "app.git_create_release.pushtag=yes"
set "app.git_create_release.repo.input="
set "app.git_create_release.repo.slug="
set "app.git_create_release.login="
set "app.git_create_release.remote.tag="
set "app.git_create_release.local.object="
set "app.git_create_release.remote.object="
set "app.git_create_release.confirm="
set "app.git_create_release.help="
set "app.git_create_release.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_create_release.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_create_release.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_create_release.rc%
:: ============================================================
:: :Main
:: Parses options, validates the worktree and local tag, authenticates,
:: resolves the target repository, confirms, pushes, and creates release.
::
:: Usage: call :Main [tag NAME] [title TEXT] [notes TEXT] [draft yes|no] [prerelease yes|no] [pushtag yes|no]
::
:: Returns: 0 on success or cancellation
::          1 on repository, authentication, tag, push, or release failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeYesNo,
::           :EnsureGitHubAuthentication, :ResolveRepository,
::           :ValidateRelease, :ShowPlan, :CreateRelease,
::           :ShowHelp, prepare.bat, git, gh
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcrm_ 2^>nul') do set "%%v="
if defined _gcrm_rc (set "_gcrm_rc=" & exit /b %_gcrm_rc%)
call :ParseArgs %*
set "_gcrm_rc=%errorlevel%"
if not "%_gcrm_rc%"=="0" goto :Main
if defined app.git_create_release.help goto :_Main_help
call :NormalizeYesNo app.git_create_release.draft
if errorlevel 1 (echo ERROR: draft must be yes or no. & set "_gcrm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_create_release.prerelease
if errorlevel 1 (echo ERROR: prerelease must be yes or no. & set "_gcrm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_create_release.pushtag
if errorlevel 1 (echo ERROR: pushtag must be yes or no. & set "_gcrm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Create GitHub release
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" repository
if errorlevel 1 (echo ERROR: Dependency preparation failed. & set "_gcrm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gcrm_rc=1" & goto :Main)
where gh.exe >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI was not found. & set "_gcrm_rc=1" & goto :Main)
if not defined app.git_create_release.tag set /p "app.git_create_release.tag=Existing tag for the release: "
if not defined app.git_create_release.tag (echo ERROR: A tag is required. & set "_gcrm_rc=1" & goto :Main)
git show-ref --verify --quiet "refs/tags/%app.git_create_release.tag%"
if errorlevel 1 (echo ERROR: Local tag does not exist: & echo   %app.git_create_release.tag% & echo. & echo Create it first with just_tag.bat. & set "_gcrm_rc=1" & goto :Main)
call :EnsureGitHubAuthentication
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
call :ResolveRepository
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
call :ValidateRelease
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
if not defined app.git_create_release.title set "app.git_create_release.title=%app.git_create_release.tag%"
call :ShowPlan
if errorlevel 1 (set "_gcrm_rc=%errorlevel%" & goto :Main)
set /p "app.git_create_release.confirm=Type RELEASE to continue: "
if "%app.git_create_release.confirm%"=="RELEASE" goto :_Main_create
echo.
echo Cancelled. Nothing was changed.
set "_gcrm_rc=0" & goto :Main
:_Main_create
call :CreateRelease
set "_gcrm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gcrm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :EnsureGitHubAuthentication
:: Logs in when necessary, resolves the account, and configures Git
:: HTTPS authentication.
::
:: Usage: call :EnsureGitHubAuthentication
::
:: Returns: 0 on success
::          1 on authentication or setup failure
:: Requires: gh
:: ============================================================
:EnsureGitHubAuthentication
for /f "tokens=1 delims==" %%v in ('set gcra_ 2^>nul') do set "%%v="
if defined _gcra_rc (set "_gcra_rc=" & exit /b %_gcra_rc%)
gh auth status --hostname github.com >nul 2>nul
if not errorlevel 1 goto :_EnsureGitHubAuthentication_account
echo GitHub login is required.
echo A browser window will open for secure login.
gh auth login --hostname github.com --git-protocol https --web
if errorlevel 1 (echo ERROR: GitHub login failed or was cancelled. & set "_gcra_rc=1" & goto :EnsureGitHubAuthentication)
:_EnsureGitHubAuthentication_account
set "app.git_create_release.login="
for /f "delims=" %%A in ('gh api user --jq ".login" 2^>nul') do set "app.git_create_release.login=%%A"
if not defined app.git_create_release.login (echo ERROR: Could not determine the logged-in GitHub account. & set "_gcra_rc=1" & goto :EnsureGitHubAuthentication)
gh auth setup-git --hostname github.com >nul 2>nul
if errorlevel 1 (echo ERROR: GitHub CLI could not configure Git authentication. & set "_gcra_rc=1" & goto :EnsureGitHubAuthentication)
set "_gcra_rc=0" & goto :EnsureGitHubAuthentication
:: ============================================================
:: :ResolveRepository
:: Resolves the release repository from project configuration or
:: origin and normalizes it to OWNER/REPO.
::
:: Usage: call :ResolveRepository
::
:: Returns: 0 on success
::          1 when no visible repository can be resolved
:: Requires: git, gh
:: ============================================================
:ResolveRepository
for /f "tokens=1 delims==" %%v in ('set gcrr_ 2^>nul') do set "%%v="
if defined _gcrr_rc (set "_gcrr_rc=" & exit /b %_gcrr_rc%)
if defined CFG_REPO_URL set "app.git_create_release.repo.input=%CFG_REPO_URL%"
if defined app.git_create_release.repo.input goto :_ResolveRepository_view
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_create_release.repo.input=%%A"
if not defined app.git_create_release.repo.input (echo ERROR: No GitHub repository is configured. & set "_gcrr_rc=1" & goto :ResolveRepository)
:_ResolveRepository_view
set "app.git_create_release.repo.slug="
for /f "delims=" %%A in ('gh repo view "%app.git_create_release.repo.input%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_create_release.repo.slug=%%A"
if not defined app.git_create_release.repo.slug (echo ERROR: Could not determine the GitHub repository. & set "_gcrr_rc=1" & goto :ResolveRepository)
set "_gcrr_rc=0" & goto :ResolveRepository
:: ============================================================
:: :ValidateRelease
:: Verifies the release does not exist, checks target reachability,
:: and determines whether the tag already exists remotely.
::
:: Usage: call :ValidateRelease
::
:: Output:
::   app.git_create_release.remote.tag  defined when tag is remote
::
:: Returns: 0 when creation may continue
::          1 on existing release, unreachable target, or missing remote tag
:: Requires: git, gh
:: ============================================================
:ValidateRelease
for /f "tokens=1 delims==" %%v in ('set gcrv_ 2^>nul') do set "%%v="
if defined _gcrv_rc (set "_gcrv_rc=" & exit /b %_gcrv_rc%)
gh release view "%app.git_create_release.tag%" --repo "%app.git_create_release.repo.slug%" >nul 2>nul
if not errorlevel 1 (echo ERROR: A GitHub release already exists for: & echo   %app.git_create_release.tag% & set "_gcrv_rc=1" & goto :ValidateRelease)
git ls-remote "%app.git_create_release.repo.input%" >nul 2>nul
if errorlevel 1 (echo ERROR: The target repository could not be reached. & set "_gcrv_rc=1" & goto :ValidateRelease)
set "app.git_create_release.remote.tag="
set "app.git_create_release.local.object="
set "app.git_create_release.remote.object="
for /f "delims=" %%A in ('git rev-parse "refs/tags/%app.git_create_release.tag%" 2^>nul') do set "app.git_create_release.local.object=%%A"
for /f "tokens=1" %%A in ('git ls-remote --tags "%app.git_create_release.repo.input%" "refs/tags/%app.git_create_release.tag%" 2^>nul') do set "app.git_create_release.remote.object=%%A"
if defined app.git_create_release.remote.object set "app.git_create_release.remote.tag=1"
if defined app.git_create_release.remote.tag if /I not "%app.git_create_release.local.object%"=="%app.git_create_release.remote.object%" (echo ERROR: The remote tag does not match the local tag object. & echo Refusing to create a release from mismatched tag data. & set "_gcrv_rc=1" & goto :ValidateRelease)
if /I "%app.git_create_release.pushtag%"=="no" if not defined app.git_create_release.remote.tag (echo ERROR: Tag is not in the target repository and pushtag is no. & set "_gcrv_rc=1" & goto :ValidateRelease)
set "_gcrv_rc=0" & goto :ValidateRelease
:: ============================================================
:: :ShowPlan
:: Displays the release repository, tag, title, note mode, and flags.
::
:: Usage: call :ShowPlan
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowPlan
echo.
echo Repository:
echo   %app.git_create_release.repo.slug%
echo.
echo Tag:
echo   %app.git_create_release.tag%
echo.
echo Title:
echo   %app.git_create_release.title%
echo.
if defined app.git_create_release.notes goto :_ShowPlan_notes
echo Notes:
echo   generated by GitHub
goto :_ShowPlan_flags
:_ShowPlan_notes
echo Notes:
echo   supplied on command line
:_ShowPlan_flags
echo.
echo Draft:
echo   %app.git_create_release.draft%
echo.
echo Prerelease:
echo   %app.git_create_release.prerelease%
echo.
echo Push local tag first:
echo   %app.git_create_release.pushtag%
echo.
exit /b 0
:: ============================================================
:: :CreateRelease
:: Pushes the local tag when needed and creates the GitHub release
:: with generated or supplied notes.
::
:: Usage: call :CreateRelease
::
:: Returns: 0 on success
::          1 on tag push or release creation failure
:: Requires: git, gh
:: ============================================================
:CreateRelease
for /f "tokens=1 delims==" %%v in ('set gcrc_ 2^>nul') do set "%%v="
if defined _gcrc_rc (set "_gcrc_rc=" & exit /b %_gcrc_rc%)
if defined app.git_create_release.remote.tag goto :_CreateRelease_gh
if /I "%app.git_create_release.pushtag%"=="no" goto :_CreateRelease_gh
git push "%app.git_create_release.repo.input%" "refs/tags/%app.git_create_release.tag%"
if errorlevel 1 (echo ERROR: Tag push failed. & set "_gcrc_rc=1" & goto :CreateRelease)
:_CreateRelease_gh
if defined app.git_create_release.notes goto :_CreateRelease_notes
if /I "%app.git_create_release.draft%"=="yes" goto :_CreateRelease_generated_draft
if /I "%app.git_create_release.prerelease%"=="yes" goto :_CreateRelease_generated_pre
gh release create "%app.git_create_release.tag%" --repo "%app.git_create_release.repo.slug%" --title "%app.git_create_release.title%" --generate-notes
goto :_CreateRelease_result
:_CreateRelease_generated_draft
if /I "%app.git_create_release.prerelease%"=="yes" goto :_CreateRelease_generated_draft_pre
gh release create "%app.git_create_release.tag%" --repo "%app.git_create_release.repo.slug%" --title "%app.git_create_release.title%" --generate-notes --draft
goto :_CreateRelease_result
:_CreateRelease_generated_draft_pre
gh release create "%app.git_create_release.tag%" --repo "%app.git_create_release.repo.slug%" --title "%app.git_create_release.title%" --generate-notes --draft --prerelease
goto :_CreateRelease_result
:_CreateRelease_generated_pre
gh release create "%app.git_create_release.tag%" --repo "%app.git_create_release.repo.slug%" --title "%app.git_create_release.title%" --generate-notes --prerelease
goto :_CreateRelease_result
:_CreateRelease_notes
if /I "%app.git_create_release.draft%"=="yes" goto :_CreateRelease_notes_draft
if /I "%app.git_create_release.prerelease%"=="yes" goto :_CreateRelease_notes_pre
gh release create "%app.git_create_release.tag%" --repo "%app.git_create_release.repo.slug%" --title "%app.git_create_release.title%" --notes "%app.git_create_release.notes%"
goto :_CreateRelease_result
:_CreateRelease_notes_draft
if /I "%app.git_create_release.prerelease%"=="yes" goto :_CreateRelease_notes_draft_pre
gh release create "%app.git_create_release.tag%" --repo "%app.git_create_release.repo.slug%" --title "%app.git_create_release.title%" --notes "%app.git_create_release.notes%" --draft
goto :_CreateRelease_result
:_CreateRelease_notes_draft_pre
gh release create "%app.git_create_release.tag%" --repo "%app.git_create_release.repo.slug%" --title "%app.git_create_release.title%" --notes "%app.git_create_release.notes%" --draft --prerelease
goto :_CreateRelease_result
:_CreateRelease_notes_pre
gh release create "%app.git_create_release.tag%" --repo "%app.git_create_release.repo.slug%" --title "%app.git_create_release.title%" --notes "%app.git_create_release.notes%" --prerelease
:_CreateRelease_result
if errorlevel 1 (echo ERROR: GitHub release creation failed. & set "_gcrc_rc=1" & goto :CreateRelease)
echo.
echo GitHub release created successfully.
set "_gcrc_rc=0" & goto :CreateRelease
:: ============================================================
:: :ParseArgs
:: Parses tag, title, notes, draft, prerelease, pushtag, and help.
::
:: Usage: call :ParseArgs [tag NAME] [title TEXT] [notes TEXT] [draft yes|no] [prerelease yes|no] [pushtag yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="tag" goto :_ParseArgs_tag
if /I "%~1"=="title" goto :_ParseArgs_title
if /I "%~1"=="notes" goto :_ParseArgs_notes
if /I "%~1"=="draft" goto :_ParseArgs_draft
if /I "%~1"=="prerelease" goto :_ParseArgs_prerelease
if /I "%~1"=="pushtag" goto :_ParseArgs_pushtag
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_create_release.tag (set "app.git_create_release.tag=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_tag
if "%~2"=="" (echo ERROR: tag requires a name. & exit /b 2)
set "app.git_create_release.tag=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_title
if "%~2"=="" (echo ERROR: title requires text. & exit /b 2)
set "app.git_create_release.title=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_notes
set "app.git_create_release.notes=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_draft
if "%~2"=="" (echo ERROR: draft requires yes or no. & exit /b 2)
set "app.git_create_release.draft=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_prerelease
if "%~2"=="" (echo ERROR: prerelease requires yes or no. & exit /b 2)
set "app.git_create_release.prerelease=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_pushtag
if "%~2"=="" (echo ERROR: pushtag requires yes or no. & exit /b 2)
set "app.git_create_release.pushtag=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_create_release.help=1"
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
for /f "tokens=1 delims==" %%v in ('set gcry_ 2^>nul') do set "%%v="
if defined _gcry_rc (set "_gcry_rc=" & exit /b %_gcry_rc%)
set "gcry_name=%~1"
call set "gcry_value=%%%gcry_name%%%"
if /I "%gcry_value%"=="y" set "%gcry_name%=yes"
if /I "%gcry_value%"=="yes" set "%gcry_name%=yes"
if /I "%gcry_value%"=="true" set "%gcry_name%=yes"
if /I "%gcry_value%"=="1" set "%gcry_name%=yes"
if /I "%gcry_value%"=="n" set "%gcry_name%=no"
if /I "%gcry_value%"=="no" set "%gcry_name%=no"
if /I "%gcry_value%"=="false" set "%gcry_name%=no"
if /I "%gcry_value%"=="0" set "%gcry_name%=no"
call set "gcry_value=%%%gcry_name%%%"
if /I "%gcry_value%"=="yes" (set "_gcry_rc=0" & goto :NormalizeYesNo)
if /I "%gcry_value%"=="no" (set "_gcry_rc=0" & goto :NormalizeYesNo)
set "_gcry_rc=1" & goto :NormalizeYesNo
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
echo git_create_release.bat
echo.
echo Usage:
echo   git_create_release.bat tag v1.0.0
echo   git_create_release.bat tag v1.0.0 title "Version 1.0"
echo   git_create_release.bat tag v1.0.0 draft yes prerelease yes
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
