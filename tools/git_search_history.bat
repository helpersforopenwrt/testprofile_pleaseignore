@echo off
:: ============================================================
:: git_search_history.bat
:: Searches Git history by message, file, changed text, regular
:: expression, author, or exact commit.
::
:: Usage:
::   call tools\git_search_history.bat mode message query "login"
::   call tools\git_search_history.bat mode file query tools\git_login.bat
::   call tools\git_search_history.bat mode text query "old function"
::   call tools\git_search_history.bat mode regex query "function.*name"
::   call tools\git_search_history.bat mode author query "Alice"
::   call tools\git_search_history.bat mode commit query abc123
::
:: Returns: 0 on successful search, no matches, or help
::          1 on preparation, repository, fetch, revision, or Git failure
::          2 on invalid arguments
:: Requires: _common.bat, prepare.bat, git, :Main, :ParseArgs,
::           :NormalizeMode, :NormalizeYesNo, :RunSearch, :ShowHelp,
::           :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_search_history.mode="
set "app.git_search_history.query="
set "app.git_search_history.all=yes"
set "app.git_search_history.fetch=no"
set "app.git_search_history.scope=--all"
set "app.git_search_history.help="
set "app.git_search_history.rc=0"
call "%~dp0_common.bat" init
set "app.git_search_history.rc=%errorlevel%"
if "%app.git_search_history.rc%"=="0" goto :run
goto :end
:run
call :Main %*
set "app.git_search_history.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_search_history.rc%
:: ============================================================
:: :Main
:: Validates search options, optionally refreshes remote references,
:: resolves scope, and dispatches the selected read-only search.
::
:: Usage: call :Main [mode MODE] [query VALUE] [all yes|no] [fetch yes|no]
::
:: Returns: 0 on successful search, no matches, or help
::          1 on preparation, repository, fetch, revision, or Git failure
::          2 on invalid arguments
:: Requires: :ParseArgs, :NormalizeMode, :NormalizeYesNo, :RunSearch,
::           :ShowHelp, prepare.bat, git
:: ============================================================
:Main
for /f "tokens=1 delims==" %%v in ('set gshm_ 2^>nul') do set "%%v="
if defined _gshm_rc (set "_gshm_rc=" & exit /b %_gshm_rc%)
call :ParseArgs %*
set "_gshm_rc=%errorlevel%"
if not "%_gshm_rc%"=="0" goto :Main
if defined app.git_search_history.help goto :_Main_help
call :NormalizeYesNo app.git_search_history.all
if errorlevel 1 (echo ERROR: all must be yes or no. & set "_gshm_rc=2" & goto :Main)
call :NormalizeYesNo app.git_search_history.fetch
if errorlevel 1 (echo ERROR: fetch must be yes or no. & set "_gshm_rc=2" & goto :Main)
echo.
echo ============================================================
echo  Search Git history
echo ============================================================
echo.
echo Project:
echo   %APP_DISPLAY_NAME%
echo.
echo Folder:
echo   %CD%
echo.
call "%CD%\prepare.bat" git
if errorlevel 1 (echo ERROR: Git preparation failed. & set "_gshm_rc=1" & goto :Main)
where git.exe >nul 2>nul
if errorlevel 1 (echo ERROR: Git was not found in PATH. & set "_gshm_rc=1" & goto :Main)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (echo ERROR: This folder is not inside a Git working tree. & set "_gshm_rc=1" & goto :Main)
if /I "%app.git_search_history.fetch%"=="yes" goto :_Main_fetch
goto :_Main_inputs
:_Main_fetch
echo Fetching remote references...
git fetch --all --prune --quiet
if errorlevel 1 (echo ERROR: One or more remotes could not be fetched. & set "_gshm_rc=1" & goto :Main)
echo.
:_Main_inputs
if not defined app.git_search_history.mode set /p "app.git_search_history.mode=Search mode [message/file/text/regex/author/commit]: "
call :NormalizeMode
if errorlevel 1 (set "_gshm_rc=2" & goto :Main)
if not defined app.git_search_history.query set /p "app.git_search_history.query=Search query: "
if not defined app.git_search_history.query (echo ERROR: A search query is required. & set "_gshm_rc=1" & goto :Main)
set "app.git_search_history.scope=--all"
if /I "%app.git_search_history.all%"=="no" set "app.git_search_history.scope=HEAD"
echo Mode:
echo   %app.git_search_history.mode%
echo.
echo Query:
echo   %app.git_search_history.query%
echo.
echo Search scope:
if /I "%app.git_search_history.all%"=="yes" goto :_Main_scope_all
echo   current HEAD history only
goto :_Main_scope_done
:_Main_scope_all
echo   all local and remote refs
:_Main_scope_done
echo.
if not "%app.git_search_history.mode%"=="file" goto :_Main_follow_note_done
if /I not "%app.git_search_history.all%"=="yes" goto :_Main_follow_note_done
echo Note: file searches across all refs do not use --follow because Git cannot combine those modes reliably.
echo.
:_Main_follow_note_done
call :RunSearch
set "_gshm_rc=%errorlevel%" & goto :Main
:_Main_help
call :ShowHelp
set "_gshm_rc=%errorlevel%" & goto :Main
:: ============================================================
:: :RunSearch
:: Runs the selected Git history query with the resolved scope.
:: Current-history file searches use --follow; all-ref file searches do not.
::
:: Usage: call :RunSearch
::
:: Returns: 0 on successful search or no matches
::          1 on revision or Git failure
:: Requires: git
:: ============================================================
:RunSearch
for /f "tokens=1 delims==" %%v in ('set gshr_ 2^>nul') do set "%%v="
if defined _gshr_rc (set "_gshr_rc=" & exit /b %_gshr_rc%)
if "%app.git_search_history.mode%"=="message" goto :_RunSearch_message
if "%app.git_search_history.mode%"=="file" goto :_RunSearch_file
if "%app.git_search_history.mode%"=="text" goto :_RunSearch_text
if "%app.git_search_history.mode%"=="regex" goto :_RunSearch_regex
if "%app.git_search_history.mode%"=="author" goto :_RunSearch_author
if "%app.git_search_history.mode%"=="commit" goto :_RunSearch_commit
echo ERROR: Unsupported search mode.
set "_gshr_rc=1" & goto :RunSearch
:_RunSearch_message
git log %app.git_search_history.scope% --regexp-ignore-case --decorate --date=short --pretty=format:"%%h  %%ad  %%an  %%d%%n    %%s" --grep="%app.git_search_history.query%"
set "_gshr_rc=%errorlevel%"
goto :_RunSearch_result
:_RunSearch_file
if /I "%app.git_search_history.all%"=="yes" goto :_RunSearch_file_all
git log HEAD --follow --date=short --decorate --pretty=format:"%%h  %%ad  %%an  %%d%%n    %%s" -- "%app.git_search_history.query%"
set "_gshr_rc=%errorlevel%"
goto :_RunSearch_result
:_RunSearch_file_all
git log --all --date=short --decorate --pretty=format:"%%h  %%ad  %%an  %%d%%n    %%s" -- "%app.git_search_history.query%"
set "_gshr_rc=%errorlevel%"
goto :_RunSearch_result
:_RunSearch_text
git log %app.git_search_history.scope% -S"%app.git_search_history.query%" --pickaxe-all --date=short --decorate --pretty=format:"%%h  %%ad  %%an  %%d%%n    %%s" --stat
set "_gshr_rc=%errorlevel%"
goto :_RunSearch_result
:_RunSearch_regex
git log %app.git_search_history.scope% -G"%app.git_search_history.query%" --pickaxe-all --date=short --decorate --pretty=format:"%%h  %%ad  %%an  %%d%%n    %%s" --stat
set "_gshr_rc=%errorlevel%"
goto :_RunSearch_result
:_RunSearch_author
git log %app.git_search_history.scope% --regexp-ignore-case --author="%app.git_search_history.query%" --date=short --decorate --pretty=format:"%%h  %%ad  %%an  %%d%%n    %%s"
set "_gshr_rc=%errorlevel%"
goto :_RunSearch_result
:_RunSearch_commit
git rev-parse --verify "%app.git_search_history.query%^^{commit}" >nul 2>nul
if errorlevel 1 (echo ERROR: Commit was not found: & echo   %app.git_search_history.query% & set "_gshr_rc=1" & goto :RunSearch)
git show --decorate --stat --summary "%app.git_search_history.query%"
set "_gshr_rc=%errorlevel%"
:_RunSearch_result
echo.
if "%_gshr_rc%"=="0" goto :RunSearch
echo ERROR: Git history search failed.
set "_gshr_rc=1" & goto :RunSearch
:: ============================================================
:: :ParseArgs
:: Parses mode, query, all-ref scope, fetch, and help arguments.
::
:: Usage: call :ParseArgs [mode MODE] [query VALUE] [all yes|no] [fetch yes|no]
::
:: Returns: 0 on success
::          2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="mode" goto :_ParseArgs_mode
if /I "%~1"=="query" goto :_ParseArgs_query
if /I "%~1"=="all" goto :_ParseArgs_all
if /I "%~1"=="fetch" goto :_ParseArgs_fetch
if /I "%~1"=="help" goto :_ParseArgs_help
if /I "%~1"=="/help" goto :_ParseArgs_help
if /I "%~1"=="--help" goto :_ParseArgs_help
if /I "%~1"=="/?" goto :_ParseArgs_help
if not defined app.git_search_history.mode (set "app.git_search_history.mode=%~1" & shift & goto :ParseArgs)
if not defined app.git_search_history.query (set "app.git_search_history.query=%~1" & shift & goto :ParseArgs)
echo ERROR: Unrecognized argument: %~1
exit /b 2
:_ParseArgs_mode
if "%~2"=="" (echo ERROR: mode requires a value. & exit /b 2)
set "app.git_search_history.mode=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_query
if "%~2"=="" (echo ERROR: query requires a value. & exit /b 2)
set "app.git_search_history.query=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_all
if "%~2"=="" (echo ERROR: all requires yes or no. & exit /b 2)
set "app.git_search_history.all=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_fetch
if "%~2"=="" (echo ERROR: fetch requires yes or no. & exit /b 2)
set "app.git_search_history.fetch=%~2"
shift
shift
goto :ParseArgs
:_ParseArgs_help
set "app.git_search_history.help=1"
shift
goto :ParseArgs
:: ============================================================
:: :NormalizeMode
:: Normalizes and validates the selected history-search mode.
::
:: Usage: call :NormalizeMode
::
:: Returns: 0 for message, file, text, regex, author, or commit
::          1 when empty or invalid
:: Requires: none
:: ============================================================
:NormalizeMode
if /I "%app.git_search_history.mode%"=="message" set "app.git_search_history.mode=message"
if /I "%app.git_search_history.mode%"=="file" set "app.git_search_history.mode=file"
if /I "%app.git_search_history.mode%"=="text" set "app.git_search_history.mode=text"
if /I "%app.git_search_history.mode%"=="regex" set "app.git_search_history.mode=regex"
if /I "%app.git_search_history.mode%"=="author" set "app.git_search_history.mode=author"
if /I "%app.git_search_history.mode%"=="commit" set "app.git_search_history.mode=commit"
if "%app.git_search_history.mode%"=="message" exit /b 0
if "%app.git_search_history.mode%"=="file" exit /b 0
if "%app.git_search_history.mode%"=="text" exit /b 0
if "%app.git_search_history.mode%"=="regex" exit /b 0
if "%app.git_search_history.mode%"=="author" exit /b 0
if "%app.git_search_history.mode%"=="commit" exit /b 0
echo ERROR: mode must be message, file, text, regex, author, or commit.
exit /b 1
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
for /f "tokens=1 delims==" %%v in ('set gshy_ 2^>nul') do set "%%v="
if defined _gshy_rc (set "_gshy_rc=" & exit /b %_gshy_rc%)
set "gshy_name=%~1"
call set "gshy_value=%%%gshy_name%%%"
if /I "%gshy_value%"=="y" set "%gshy_name%=yes"
if /I "%gshy_value%"=="yes" set "%gshy_name%=yes"
if /I "%gshy_value%"=="true" set "%gshy_name%=yes"
if /I "%gshy_value%"=="1" set "%gshy_name%=yes"
if /I "%gshy_value%"=="n" set "%gshy_name%=no"
if /I "%gshy_value%"=="no" set "%gshy_name%=no"
if /I "%gshy_value%"=="false" set "%gshy_name%=no"
if /I "%gshy_value%"=="0" set "%gshy_name%=no"
call set "gshy_value=%%%gshy_name%%%"
if /I "%gshy_value%"=="yes" (set "_gshy_rc=0" & goto :NormalizeYesNo)
if /I "%gshy_value%"=="no" (set "_gshy_rc=0" & goto :NormalizeYesNo)
set "_gshy_rc=1" & goto :NormalizeYesNo
:: ============================================================
:: :ShowHelp
:: Displays history-search modes, scope, and file-follow behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo git_search_history.bat
echo.
echo Usage:
echo   git_search_history.bat mode message query "login"
echo   git_search_history.bat mode file query tools\git_login.bat
echo   git_search_history.bat mode text query "old function"
echo   git_search_history.bat mode regex query "function.*name"
echo   git_search_history.bat mode author query "Alice"
echo   git_search_history.bat mode commit query abc123
echo.
echo all yes searches every ref. For file mode, --follow is used only
echo with all no because Git does not reliably combine --follow and --all.
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
