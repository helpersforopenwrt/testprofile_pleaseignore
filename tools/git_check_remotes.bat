@echo off
:: ============================================================
:: git_check_remotes.bat
:: Checks origin and upstream URLs, reachability, configuration,
:: visibility, and push permission without changing remotes.
::
:: Usage:
::   call tools\git_check_remotes.bat
::   call tools\git_check_remotes.bat help
::
:: Returns: 0 when no required check fails
::          1 when one or more required checks fail
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, optional gh, :Main,
::           :ParseArgs, :LoadRemoteValues, :CheckOrigin,
::           :CheckGitHubOrigin, :CheckUpstream, :ShowResult,
::           :NormalizeURL, :Section, :OK, :Warning, :Error,
::           :ShowHelp, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_check_remotes.error.count=0"
set "app.git_check_remotes.warning.count=0"
set "app.git_check_remotes.origin.fetch="
set "app.git_check_remotes.origin.push="
set "app.git_check_remotes.upstream.fetch="
set "app.git_check_remotes.upstream.push="
set "app.git_check_remotes.config.origin="
set "app.git_check_remotes.config.upstream="
set "app.git_check_remotes.norm.a="
set "app.git_check_remotes.norm.b="
set "app.git_check_remotes.repo.slug="
set "app.git_check_remotes.can.push="
set "app.git_check_remotes.help="
set "app.git_check_remotes.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_check_remotes.rc=%errorlevel%"
goto :end
:run
call :Main %*
set "app.git_check_remotes.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_check_remotes.rc%
:: ============================================================
:: :Main
:: Parses arguments, prepares dependencies, loads remote values,
:: runs origin and upstream checks, and prints the result.
::
:: Usage: call :Main [help]
::
:: Returns: 0 when no required check fails
::          1 when one or more required checks fail
::          2 on invalid arguments
:: Requires: :ParseArgs, :LoadRemoteValues, :CheckOrigin,
::           :CheckUpstream, :ShowResult, :ShowHelp, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gcrmm_ 2^>nul') do set "%%v="
if defined _gcrmm_rc (set "_gcrmm_rc=" & exit /b %_gcrmm_rc%)
call :ParseArgs %*
set "_gcrmm_rc=%errorlevel%"
if not "%_gcrmm_rc%"=="0" goto :Main
if defined app.git_check_remotes.help goto :_Main_help
echo.
echo ============================================================
echo  Check Git remotes
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" repository
if errorlevel 1 (call :Error "Dependency preparation failed" & goto :_Main_result)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (call :Error "Current folder is not inside a Git working tree" & goto :_Main_result)
echo Configured remotes:
echo.
git remote -v
if errorlevel 1 call :Error "git remote -v failed"
echo.
call :LoadRemoteValues
call :CheckOrigin
call :CheckUpstream
:_Main_result
call :ShowResult
set "_gcrmm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gcrmm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :LoadRemoteValues
:: Loads fetch and push URLs plus configured project URLs.
::
:: Usage: call :LoadRemoteValues
::
:: Output:
::   app.git_check_remotes.origin.fetch
::   app.git_check_remotes.origin.push
::   app.git_check_remotes.upstream.fetch
::   app.git_check_remotes.upstream.push
::   app.git_check_remotes.config.origin
::   app.git_check_remotes.config.upstream
::
:: Returns: 0
:: Requires: git
:: ============================================================
:LoadRemoteValues
for /f "tokens=1 delims==" %%v in ('set gcrml_ 2^>nul') do set "%%v="
if defined _gcrml_rc (set "_gcrml_rc=" & exit /b %_gcrml_rc%)
for /f "delims=" %%A in ('git remote get-url origin 2^>nul') do set "app.git_check_remotes.origin.fetch=%%A"
for /f "delims=" %%A in ('git remote get-url --push origin 2^>nul') do set "app.git_check_remotes.origin.push=%%A"
for /f "delims=" %%A in ('git remote get-url upstream 2^>nul') do set "app.git_check_remotes.upstream.fetch=%%A"
for /f "delims=" %%A in ('git remote get-url --push upstream 2^>nul') do set "app.git_check_remotes.upstream.push=%%A"
if defined CFG_REPO_URL set "app.git_check_remotes.config.origin=%CFG_REPO_URL%"
if defined app.upstream_url set "app.git_check_remotes.config.upstream=%app.upstream_url%"
if not defined app.git_check_remotes.config.upstream if defined app.fork_source_url set "app.git_check_remotes.config.upstream=%app.fork_source_url%"
set "_gcrml_rc=0" & goto :LoadRemoteValues
:: ============================================================
:: :CheckOrigin
:: Checks origin URLs, reachability, project configuration, and
:: optional GitHub visibility and permissions.
::
:: Usage: call :CheckOrigin
::
:: Returns: 0
:: Requires: :Section, :OK, :Warning, :Error, :NormalizeURL,
::           :CheckGitHubOrigin, git
:: ============================================================
:CheckOrigin
for /f "tokens=1 delims==" %%v in ('set gcro_ 2^>nul') do set "%%v="
if defined _gcro_rc (set "_gcro_rc=" & exit /b %_gcro_rc%)
call :Section "origin"
if not defined app.git_check_remotes.origin.fetch (call :Error "origin is not configured" & set "_gcro_rc=0" & goto :CheckOrigin)
call :OK "origin fetch URL exists"
echo       %app.git_check_remotes.origin.fetch%
if defined app.git_check_remotes.origin.push goto :_CheckOrigin_push
call :Warning "origin push URL is unavailable"
goto :_CheckOrigin_reachability
:_CheckOrigin_push
call :OK "origin push URL exists"
echo       %app.git_check_remotes.origin.push%
:_CheckOrigin_reachability
git ls-remote --heads "%app.git_check_remotes.origin.fetch%" >nul 2>nul
if errorlevel 1 (call :Error "origin could not be reached") else (call :OK "origin is reachable")
if not defined app.git_check_remotes.config.origin goto :_CheckOrigin_github
call :NormalizeURL "%app.git_check_remotes.origin.fetch%" app.git_check_remotes.norm.a
call :NormalizeURL "%app.git_check_remotes.config.origin%" app.git_check_remotes.norm.b
if /I "%app.git_check_remotes.norm.a%"=="%app.git_check_remotes.norm.b%" goto :_CheckOrigin_match
call :Error "origin does not match app.repo_url"
echo       origin:       %app.git_check_remotes.origin.fetch%
echo       build_config: %app.git_check_remotes.config.origin%
goto :_CheckOrigin_github
:_CheckOrigin_match
call :OK "origin matches app.repo_url"
:_CheckOrigin_github
call :CheckGitHubOrigin
set "_gcro_rc=0" & goto :CheckOrigin
:: ============================================================
:: :CheckGitHubOrigin
:: Uses GitHub CLI when available and authenticated to check
:: repository visibility and direct push permission.
::
:: Usage: call :CheckGitHubOrigin
::
:: Returns: 0
:: Requires: :OK, :Warning, gh
:: ============================================================
:CheckGitHubOrigin
for /f "tokens=1 delims==" %%v in ('set gcrg_ 2^>nul') do set "%%v="
if defined _gcrg_rc (set "_gcrg_rc=" & exit /b %_gcrg_rc%)
where gh.exe >nul 2>nul
if errorlevel 1 (call :Warning "GitHub CLI is unavailable; permission check skipped" & set "_gcrg_rc=0" & goto :CheckGitHubOrigin)
gh auth status --hostname github.com >nul 2>nul
if errorlevel 1 (call :Warning "GitHub CLI is not logged in; permission check skipped" & set "_gcrg_rc=0" & goto :CheckGitHubOrigin)
set "app.git_check_remotes.repo.slug="
for /f "delims=" %%A in ('gh repo view "%app.git_check_remotes.origin.fetch%" --json nameWithOwner --jq ".nameWithOwner" 2^>nul') do set "app.git_check_remotes.repo.slug=%%A"
if not defined app.git_check_remotes.repo.slug (call :Warning "origin is not visible through GitHub CLI" & set "_gcrg_rc=0" & goto :CheckGitHubOrigin)
call :OK "origin is visible through GitHub CLI"
echo       %app.git_check_remotes.repo.slug%
set "app.git_check_remotes.can.push="
for /f "delims=" %%A in ('gh api "repos/%app.git_check_remotes.repo.slug%" --jq ".permissions.push" 2^>nul') do set "app.git_check_remotes.can.push=%%A"
if /I "%app.git_check_remotes.can.push%"=="true" goto :_CheckGitHubOrigin_push
call :Warning "logged-in account lacks direct push permission on origin"
set "_gcrg_rc=0" & goto :CheckGitHubOrigin
:_CheckGitHubOrigin_push
call :OK "logged-in account has push permission on origin"
set "_gcrg_rc=0" & goto :CheckGitHubOrigin
:: ============================================================
:: :CheckUpstream
:: Checks whether upstream is required, configured, matching, and
:: reachable.
::
:: Usage: call :CheckUpstream
::
:: Returns: 0
:: Requires: :Section, :OK, :Warning, :Error, :NormalizeURL, git
:: ============================================================
:CheckUpstream
for /f "tokens=1 delims==" %%v in ('set gcru_ 2^>nul') do set "%%v="
if defined _gcru_rc (set "_gcru_rc=" & exit /b %_gcru_rc%)
call :Section "upstream"
if defined app.git_check_remotes.config.upstream goto :_CheckUpstream_required
if defined app.git_check_remotes.upstream.fetch goto :_CheckUpstream_unexpected
call :OK "No upstream remote is required by build_config.bat"
set "_gcru_rc=0" & goto :CheckUpstream
:_CheckUpstream_unexpected
call :Warning "upstream exists but build_config.bat has no upstream setting"
echo       %app.git_check_remotes.upstream.fetch%
goto :_CheckUpstream_reachability
:_CheckUpstream_required
if defined app.git_check_remotes.upstream.fetch goto :_CheckUpstream_compare
call :Error "build_config.bat defines upstream, but remote is missing"
echo       configured: %app.git_check_remotes.config.upstream%
set "_gcru_rc=0" & goto :CheckUpstream
:_CheckUpstream_compare
call :NormalizeURL "%app.git_check_remotes.upstream.fetch%" app.git_check_remotes.norm.a
call :NormalizeURL "%app.git_check_remotes.config.upstream%" app.git_check_remotes.norm.b
if /I "%app.git_check_remotes.norm.a%"=="%app.git_check_remotes.norm.b%" goto :_CheckUpstream_match
call :Error "upstream does not match build_config.bat"
echo       upstream:   %app.git_check_remotes.upstream.fetch%
echo       configured: %app.git_check_remotes.config.upstream%
goto :_CheckUpstream_reachability
:_CheckUpstream_match
call :OK "upstream matches build_config.bat"
:_CheckUpstream_reachability
git ls-remote --heads "%app.git_check_remotes.upstream.fetch%" >nul 2>nul
if errorlevel 1 (call :Error "upstream could not be reached") else (call :OK "upstream is reachable")
set "_gcru_rc=0" & goto :CheckUpstream
:: ============================================================
:: :ShowResult
:: Displays error and warning totals and returns the final status.
::
:: Usage: call :ShowResult
::
:: Returns: 0 when no required error exists
::          1 when one or more required checks failed
:: Requires: :Section
:: ============================================================
:ShowResult
for /f "tokens=1 delims==" %%v in ('set gcrr_ 2^>nul') do set "%%v="
if defined _gcrr_rc (set "_gcrr_rc=" & exit /b %_gcrr_rc%)
call :Section "Result"
echo Errors:
echo   %app.git_check_remotes.error.count%
echo.
echo Warnings:
echo   %app.git_check_remotes.warning.count%
echo.
if "%app.git_check_remotes.error.count%"=="0" goto :_ShowResult_ok
echo One or more remote checks failed.
set "_gcrr_rc=1" & goto :ShowResult
:_ShowResult_ok
echo Remote configuration has no required error.
set "_gcrr_rc=0" & goto :ShowResult
:: ============================================================
:: :NormalizeURL
:: Normalizes common GitHub HTTPS and SSH URL forms for comparison.
::
:: Usage: call :NormalizeURL "URL" outputVariable
::
:: Output:
::   outputVariable  normalized URL without trailing slash or .git
::
:: Returns: 0
:: Requires: none
:: ============================================================
:NormalizeURL
for /f "tokens=1 delims==" %%v in ('set gcrn_ 2^>nul') do set "%%v="
if defined _gcrn_rc (set "_gcrn_rc=" & exit /b %_gcrn_rc%)
set "gcrn_value=%~1"
set "gcrn_output=%~2"
set "gcrn_value=%gcrn_value:git@github.com:=https://github.com/%"
set "gcrn_value=%gcrn_value:ssh://git@github.com/=https://github.com/%"
if /I "%gcrn_value:~-4%"==".git" set "gcrn_value=%gcrn_value:~0,-4%"
if "%gcrn_value:~-1%"=="/" set "gcrn_value=%gcrn_value:~0,-1%"
if defined gcrn_output set "%gcrn_output%=%gcrn_value%"
set "_gcrn_rc=0" & goto :NormalizeURL
:: ============================================================
:: :Section
:: Prints a section heading.
::
:: Usage: call :Section "title"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:Section
echo.
echo ============================================================
echo  %~1
echo ============================================================
echo.
exit /b 0
:: ============================================================
:: :OK
:: Prints a successful check.
::
:: Usage: call :OK "message"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:OK
echo [OK]      %~1
exit /b 0
:: ============================================================
:: :Warning
:: Prints a warning and increments the warning counter.
::
:: Usage: call :Warning "message"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:Warning
echo [WARNING] %~1
set /a app.git_check_remotes.warning.count+=1
exit /b 0
:: ============================================================
:: :Error
:: Prints an error and increments the error counter.
::
:: Usage: call :Error "message"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:Error
echo [ERROR]   %~1
set /a app.git_check_remotes.error.count+=1
exit /b 0
:: ============================================================
:: :ParseArgs
:: Parses the optional help argument.
::
:: Usage: call :ParseArgs [help]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_help
set "app.git_check_remotes.help=1"
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
echo git_check_remotes.bat
echo.
echo Usage:
echo   git_check_remotes.bat
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
