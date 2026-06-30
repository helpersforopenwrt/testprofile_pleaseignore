@echo off

:setup
setlocal EnableExtensions
cd /d "%~dp0"
set "app.rc=0"
set "app.pause=1"
set "app.config_file=build_config.bat"
set "app.use_default_build_config=0"
set "app.default_config_loaded=0"
set "app.file_config_loaded=0"
set "app.custom_config_requested=0"
set "app.help_requested=0"
set "app.cleanup_enabled=0"
call :SetAppColors >nul 2>nul
if errorlevel 1 call :SetNoColors
call :DetectHelpRequest %* || goto :end
call :DetectDefaultBuildConfigRequest %* || goto :end
call :DetectBuildConfigFileRequest %* || goto :end
if "%app.use_default_build_config%"=="1" ( call :LoadDefaultBuildConfig || goto :end )
call :LoadBuildConfig || goto :end
if "%app.help_requested%"=="1" (
    call :FinalizeHelpConfig || goto :end
    call :ParseArgs %* || goto :end
    goto :end
)
call :RequireBuildTargetConfig || goto :end
call :FinalizeBuildConfig || goto :end
call :InitializeBuildState || goto :end
call :ParseArgs %* || goto :end
if "%app.help_only%"=="1" goto :end
goto :main

:main
call :BuildDescribeRequest || goto :end
call :BuildCheckRequiredTools || goto :end
if "%app.check_only%"=="1" (
    call :BuildRunCheckOnly || goto :end
    goto :end
)
call :BuildPrepareRun || goto :end
call :ResourcesEnsureAll || goto :end
call :BuildCollectSources || goto :end
call :BuildPrepareTempFolders || goto :end
call :BuildCompile || goto :end
call :BuildCreateSnapshots || goto :end
call :BuildPromoteSuccessfulBuild || goto :end
call :BuildArchiveOldFolders || goto :end
call :BuildUpdateCurrentExe || goto :end
call :BuildReportSuccess || goto :end
if "%app.run_after_build%"=="1" call :BuildRunProgram
if "%app.git.commit%"=="1" (
    call :GitSync || ( call :Warn "Build succeeded, but Git/GitHub sync failed." & goto :end )
) else (
    call :Warn "Git commit/push skipped for this build mode."
)
goto :end

:end
call :CleanupTemp
if not defined app.rc set "app.rc=0"
echo.
if "%app.pause%"=="1" pause
endlocal & exit /b %app.rc%

:: ============================================================
:_COMMAND_LINE_HELP
:: ============================================================

:: ============================================================
:: :ParseArgs
:: Parses build.bat command-line arguments.
:: default/build-default/builddefault requests :SetDefaultBuildConfig.
:: target/config selects an alternate config file.
:: Command-line build modes override app.default_mode.
:: Returns 0 on success, 1 on unknown argument.
:: ============================================================
:ParseArgs
if "%~1"=="" exit /b 0
if /I "%~1"=="default" ( shift & goto ParseArgs )
if /I "%~1"=="build-default" ( shift & goto ParseArgs )
if /I "%~1"=="builddefault" ( shift & goto ParseArgs )
if /I "%~1"=="target" goto ParseArgsSkipValue
if /I "%~1"=="config" goto ParseArgsSkipValue
if /I "%~1"=="help" (
    if /I "%~2"=="howtouse" ( call :ShowBuildHowToUse & set "app.help_only=1" & exit /b 0 )
    call :ShowBuildArgsHelp
    set "app.help_only=1"
    exit /b 0
)
if /I "%~1"=="/help" ( call :ShowBuildArgsHelp & set "app.help_only=1" & exit /b 0 )
if /I "%~1"=="--help" ( call :ShowBuildArgsHelp & set "app.help_only=1" & exit /b 0 )
if /I "%~1"=="-h" ( call :ShowBuildArgsHelp & set "app.help_only=1" & exit /b 0 )
if /I "%~1"=="/?" ( call :ShowBuildArgsHelp & set "app.help_only=1" & exit /b 0 )
if /I "%~1"=="howtouse" ( call :ShowBuildHowToUse & set "app.help_only=1" & exit /b 0 )
call :ApplyBuildMode "%~1"
if errorlevel 1 exit /b 1
shift
goto ParseArgs
:ParseArgsSkipValue
if "%~2"=="" ( call :SetFailure "%~1 requires a config file path." & exit /b 1 )
shift
shift
goto ParseArgs

:: ============================================================
:: :ShowBuildTargetSummary
:: Prints information about the loaded build target, if any.
:: Shows partial/incomplete target info during help.
:: Returns 0.
:: ============================================================
:ShowBuildTargetSummary
call :Line
call :Say app.color.header "Loaded build target"
call :Line
if "%app.default_config_loaded%"=="0" if "%app.file_config_loaded%"=="0" (
    echo   No build target is loaded.
    echo(
    echo   To load one:
    echo     build.bat default
    echo     build.bat target custom_config.bat
    echo     create build_config.bat
    exit /b 0
)
if "%app.default_config_loaded%"=="1" echo   Built-in default target: loaded
if "%app.file_config_loaded%"=="1" echo   Config file: %app.config_file%
if defined app.display_name ( echo   Display name: %app.display_name% ) else ( echo   Display name: not configured )
if defined app.name ( echo   App name:     %app.name% ) else ( echo   App name:     not configured )
if defined app.exe ( echo   Exe:          %app.exe% ) else ( echo   Exe:          not configured )
if defined app.default_mode ( echo   Default mode: %app.default_mode% ) else ( echo   Default mode: not configured )
if defined app.resource.ubound ( echo   Resources:    app.resource[%app.resource.lbound%] through app.resource[%app.resource.ubound%] ) else ( echo   Resources:    not configured )
exit /b 0

:: ============================================================
:: :ShowBuildArgsHelp
:: Prints short command-line help for build.bat.
:: Usage: build.bat help
:: Returns 0.
:: ============================================================
:ShowBuildArgsHelp
call :ShowBuildTargetSummary
echo(
call :Line
call :Say app.color.header "build.bat command-line options"
call :Line
echo(
echo   build.bat
echo     Uses the configured build target and its app.default_mode.
echo(
echo   build.bat default
echo     Uses the built-in :SetDefaultBuildConfig target.
echo(
echo   build.bat target custom_config.bat
echo     Uses an alternate custom build target config file.
echo(
echo   build.bat config custom_config.bat
echo     Same as target.
echo(
echo   build.bat build
echo     Builds only. Does not commit or push.
echo(
echo   build.bat sync
echo     Builds, asks for a commit message, commits, and pushes to GitHub.
echo(
echo   build.bat nopush
echo     Builds, asks for a commit message, commits locally, but does not push.
echo(
echo   build.bat run
echo     Builds only, then runs the configured exe.
echo(
echo   build.bat check
echo     Checks prerequisites only. Does not compile, snapshot, commit, or push.
echo(
echo   build.bat test
echo     Same as check.
echo(
echo   build.bat help howtouse
echo     Explains how build.bat works.
echo(
call :Line
echo(
echo Common choices:
echo   build.bat help                         Show help without requiring a target
echo   build.bat                              Use build_config.bat default mode
echo   build.bat default                      Use built-in default target
echo   build.bat target debug_config.bat run  Use custom target, build, run
echo   build.bat sync                         Build, commit, push
echo(
exit /b 0

:: ============================================================
:: :ShowBuildHowToUse
:: Prints detailed usage help for build.bat.
:: Usage: build.bat help howtouse
:: Returns 0.
:: ============================================================
:ShowBuildHowToUse
call :Line
call :Say app.color.header "How build.bat works"
call :Line
echo(
call :ShowBuildTargetSummary
echo(
call :Line
call :Say app.color.header "Build target selection"
call :Line
echo(
echo   build.bat help
echo     Shows help without requiring a build target.
echo(
echo   build.bat
echo     Uses build_config.bat when it exists.
echo     Uses the loaded target's app.default_mode.
echo(
echo   build.bat default
echo     Uses the built-in :SetDefaultBuildConfig target.
echo(
echo   build.bat default sync
echo     Uses the built-in default target, then runs sync mode.
echo(
echo   build.bat target custom_config.bat
echo     Uses an alternate custom build target config file.
echo(
echo   build.bat target custom_config.bat sync
echo     Uses that custom target, then runs sync mode.
echo(
echo   build.bat config custom_config.bat
echo     Same as target.
echo(
echo If neither build_config.bat exists nor default/target/config is requested:
echo   build.bat exits cleanly with "No build target."
echo(
call :Line
call :Say app.color.header "Build modes"
call :Line
echo(
echo   build.bat build
echo     Builds only. Does not commit or push.
echo(
echo   build.bat sync
echo     Builds, asks for a commit message, commits, and pushes.
echo(
echo   build.bat nopush
echo     Builds, asks for a commit message, and commits locally.
echo(
echo   build.bat run
echo     Builds only, then runs the configured exe.
echo(
echo   build.bat check
echo     Checks prerequisites only. Does not compile, snapshot, commit, or push.
echo(
echo   build.bat test
echo     Same as check.
echo(
call :Line
call :Say app.color.header "Build folders"
call :Line
echo(
echo   Work happens first in %app.temp_root% folders.
echo   Final %app.build_dir_prefix%_... and %app.source_dir_prefix%_... folders are created only after success.
echo   Older folders move to %app.oldbuilds_dir%.
echo(
call :Line
call :Say app.color.header "Resource generation"
call :Line
echo(
echo   Resources are configured with app.resource[index] pseudoarray values.
echo   app.resource.lbound defaults to 0 when omitted.
echo   app.resource.ubound is inclusive.
echo(
echo   Example:
echo     app.resource[0].id=theme
echo     app.resource[0].root=themes
echo     app.resource[0].generator=generate_theme_resources.ps1
echo     app.resource[0].output=theme_resources_generated.c
echo(
call :Line
call :Say app.color.header "Compiler selection"
call :Line
echo(
echo   Prefers %app.tcc_bundled_exe%, then %app.tcc_exe_name% from PATH, then %app.gettcc_script%.
echo(
call :Line
echo(
exit /b 0

:: ============================================================
:: :ApplyBuildMode
:: Applies one build mode to the internal flags.
:: Used by app.default_mode and command-line arguments.
:: Valid modes: build, sync, nopush, run, check, test.
:: Returns 0 on success, 1 on invalid mode.
:: ============================================================
:ApplyBuildMode
if /I "%~1"=="build" ( set "app.git.commit=0" & set "app.git.push=0" & set "app.run_after_build=0" & set "app.check_only=0" & set "app.mode=build" & exit /b 0 )
if /I "%~1"=="nosync" ( set "app.git.commit=0" & set "app.git.push=0" & set "app.run_after_build=0" & set "app.check_only=0" & set "app.mode=build" & exit /b 0 )
if /I "%~1"=="sync" ( set "app.git.commit=1" & set "app.git.push=1" & set "app.run_after_build=0" & set "app.check_only=0" & set "app.mode=sync" & exit /b 0 )
if /I "%~1"=="push" ( set "app.git.commit=1" & set "app.git.push=1" & set "app.run_after_build=0" & set "app.check_only=0" & set "app.mode=sync" & exit /b 0 )
if /I "%~1"=="github" ( set "app.git.commit=1" & set "app.git.push=1" & set "app.run_after_build=0" & set "app.check_only=0" & set "app.mode=sync" & exit /b 0 )
if /I "%~1"=="commitpush" ( set "app.git.commit=1" & set "app.git.push=1" & set "app.run_after_build=0" & set "app.check_only=0" & set "app.mode=sync" & exit /b 0 )
if /I "%~1"=="nopush" ( set "app.git.commit=1" & set "app.git.push=0" & set "app.run_after_build=0" & set "app.check_only=0" & set "app.mode=nopush" & exit /b 0 )
if /I "%~1"=="commit" ( set "app.git.commit=1" & set "app.git.push=0" & set "app.run_after_build=0" & set "app.check_only=0" & set "app.mode=nopush" & exit /b 0 )
if /I "%~1"=="save" ( set "app.git.commit=1" & set "app.git.push=0" & set "app.run_after_build=0" & set "app.check_only=0" & set "app.mode=nopush" & exit /b 0 )
if /I "%~1"=="run" ( set "app.git.commit=0" & set "app.git.push=0" & set "app.run_after_build=1" & set "app.check_only=0" & set "app.mode=run" & exit /b 0 )
if /I "%~1"=="check" ( set "app.git.commit=0" & set "app.git.push=0" & set "app.run_after_build=0" & set "app.check_only=1" & set "app.mode=check" & exit /b 0 )
if /I "%~1"=="test" ( set "app.git.commit=0" & set "app.git.push=0" & set "app.run_after_build=0" & set "app.check_only=1" & set "app.mode=test" & exit /b 0 )
call :SetFailure "Invalid build mode: %~1"
exit /b 1

:: ============================================================
:_...COMMAND_LINE_HELP
:: ============================================================

:: ============================================================
:_CONFIGURATION
:: ============================================================

:: ============================================================
:: :DetectHelpRequest
:: Detects whether the command line requested help.
:: Allows help to work even when no build target exists.
:: Outputs app.help_requested.
:: Returns 0.
:: ============================================================
:DetectHelpRequest
if "%~1"=="" exit /b 0
if /I "%~1"=="help" set "app.help_requested=1"
if /I "%~1"=="/help" set "app.help_requested=1"
if /I "%~1"=="--help" set "app.help_requested=1"
if /I "%~1"=="-h" set "app.help_requested=1"
if /I "%~1"=="/?" set "app.help_requested=1"
if /I "%~1"=="howtouse" set "app.help_requested=1"
shift
goto DetectHelpRequest

:: ============================================================
:: :DetectBuildConfigFileRequest
:: Detects an alternate custom target config file.
:: Accepted syntax:
::   build.bat target custom_config.bat
::   build.bat config custom_config.bat
:: Outputs app.config_file and app.custom_config_requested.
:: Returns 0 on success, 1 when target/config has no file argument.
:: ============================================================
:DetectBuildConfigFileRequest
if "%~1"=="" exit /b 0
if /I "%~1"=="target" goto DetectBuildConfigFileRequestPair
if /I "%~1"=="config" goto DetectBuildConfigFileRequestPair
shift
goto DetectBuildConfigFileRequest
:DetectBuildConfigFileRequestPair
if "%~2"=="" ( call :SetFailure "%~1 requires a config file path." & exit /b 1 )
set "app.config_file=%~2"
set "app.custom_config_requested=1"
shift
shift
goto DetectBuildConfigFileRequest

:: ============================================================
:: :InitializeHelpOnlyState
:: Sets safe placeholder values so help can print without a build target.
:: Returns 0.
:: ============================================================
:InitializeHelpOnlyState
set "app.mode=help"
set "app.help_only=0"
set "app.default_mode="
set "app.name="
set "app.exe="
set "app.display_name=No build target loaded"
set "app.build_dir_prefix=build"
set "app.source_dir_prefix=source"
set "app.temp_root=temp"
set "app.oldbuilds_dir=oldbuilds"
set "app.tcc_bundled_exe=.\tcc\tcc.exe"
set "app.tcc_exe_name=tcc.exe"
set "app.gettcc_script=gettcc.bat"
exit /b 0

:: ============================================================
:: :FinalizeHelpConfig
:: Fills safe display defaults for help output.
:: Does not require a complete build target.
:: Does not apply app.default_mode.
:: Returns 0.
:: ============================================================
:FinalizeHelpConfig
if "%app.default_config_loaded%"=="0" if "%app.file_config_loaded%"=="0" (
    call :InitializeHelpOnlyState
    exit /b %ERRORLEVEL%
)
if not defined app.display_name set "app.display_name=%app.name%"
if not defined app.display_name set "app.display_name=Unnamed build target"
if not defined app.build_dir_prefix set "app.build_dir_prefix=build"
if not defined app.source_dir_prefix set "app.source_dir_prefix=source"
if not defined app.temp_root set "app.temp_root=temp"
if not defined app.oldbuilds_dir set "app.oldbuilds_dir=oldbuilds"
if not defined app.tcc_dir set "app.tcc_dir=tcc"
if not defined app.tcc_exe_name set "app.tcc_exe_name=tcc.exe"
if not defined app.gettcc_script set "app.gettcc_script=gettcc.bat"
set "app.tcc_bundled_exe=.\%app.tcc_dir%\%app.tcc_exe_name%"
if not defined app.resource.lbound set "app.resource.lbound=0"
set "app.mode=help"
set "app.help_only=0"
exit /b 0

:: ============================================================
:: :DetectDefaultBuildConfigRequest
:: Detects whether the command line requested the built-in default target.
:: Accepted tokens: default, build-default, builddefault.
:: Outputs app.use_default_build_config.
:: Returns 0.
:: ============================================================
:DetectDefaultBuildConfigRequest
if "%~1"=="" exit /b 0
if /I "%~1"=="default" set "app.use_default_build_config=1"
if /I "%~1"=="build-default" set "app.use_default_build_config=1"
if /I "%~1"=="builddefault" set "app.use_default_build_config=1"
shift
goto DetectDefaultBuildConfigRequest

:: ============================================================
:: :FunctionExists
:: Checks whether a batch label exists in this file.
:: Usage: call :FunctionExists LabelName
:: Returns 0 when found, 1 when missing.
:: ============================================================
:FunctionExists
findstr /R /C:"^:%~1$" "%~f0" >nul 2>nul
exit /b %ERRORLEVEL%

:: ============================================================
:: :LoadDefaultBuildConfig
:: Calls :SetDefaultBuildConfig only when explicitly requested.
:: Fails cleanly if the default target function is missing or fails.
:: Returns 0 on success, 1 on failure.
:: ============================================================
:LoadDefaultBuildConfig
call :FunctionExists SetDefaultBuildConfig
if errorlevel 1 ( call :SetFailure "No build target: default target was requested, but :SetDefaultBuildConfig does not exist." & exit /b 1 )
call :SetDefaultBuildConfig
if errorlevel 1 ( call :SetFailure "No build target: :SetDefaultBuildConfig did not complete successfully." & exit /b 1 )
set "app.default_config_loaded=1"
exit /b 0

:: ============================================================
:: :SetDefaultBuildConfig
:: Sets the built-in default build target.
:: This function is called only when requested with:
::   build.bat default
:: build_config.bat may still override these values when it exists.
:: Returns 0.
:: ============================================================
:SetDefaultBuildConfig
set "app.display_name=FindReplaceMark"
set "app.name=window"
set "app.exe=window.exe"
set "app.default_mode=build"
set "app.repo_url=https://github.com/npp-findreplace-prototype/npp-findreplace-prototype.git"
set "app.gettcc_script=gettcc.bat"
set "app.tcc_dir=tcc"
set "app.tcc_exe_name=tcc.exe"
set "app.time_format=yyyy-MM-dd.HH'h'mm's'ss"
set "app.libs=-luser32 -lgdi32 -lcomctl32 -lgdiplus -lole32"
set "app.tcc_flags=-mwindows"
set "app.build_dir_prefix=build"
set "app.source_dir_prefix=source"
set "app.temp_root=temp"
set "app.oldbuilds_dir=oldbuilds"
set "app.temp_file_dir=%TEMP%"
set "app.temp_file_prefix=%app.name%-build"
set "app.resource.lbound=0"
set "app.resource.ubound=1"
set "app.resource[0].id=theme"
set "app.resource[0].label=theme resources"
set "app.resource[0].enabled=1"
set "app.resource[0].kind=theme"
set "app.resource[0].root=themes"
set "app.resource[0].include=*"
set "app.resource[0].generator=generate_theme_resources.ps1"
set "app.resource[0].output=theme_resources_generated.c"
set "app.resource[0].hash=.theme_resources.hash"
set "app.resource[0].hash_new=.theme_resources.hash.new"
set "app.resource[0].group=theme"
set "app.resource[0].legacy_output="
set "app.resource[1].id=ini"
set "app.resource[1].label=INI resources"
set "app.resource[1].enabled=1"
set "app.resource[1].kind=embedded"
set "app.resource[1].root=."
set "app.resource[1].include=*.ini"
set "app.resource[1].generator=generate_embedded_resources.ps1"
set "app.resource[1].output=embedded_resources_generated.c"
set "app.resource[1].hash=.embedded_resources.hash"
set "app.resource[1].hash_new=.embedded_resources.hash.new"
set "app.resource[1].group=ini"
set "app.resource[1].legacy_output=ini_resources_generated.c"
exit /b 0

:: ============================================================
:: :LoadBuildConfig
:: Calls the selected config file when it exists.
:: Default file is build_config.bat.
:: Custom target files are requested with:
::   build.bat target custom_config.bat
::   build.bat config custom_config.bat
:: Returns 0 on success, 1 if a requested custom config is missing or fails.
:: ============================================================
:LoadBuildConfig
if not exist "%app.config_file%" (
    if "%app.custom_config_requested%"=="1" ( call :SetFailure "Custom build target config was not found: %app.config_file%" & exit /b 1 )
    exit /b 0
)
call :Info "Loading %app.config_file%..."
call "%app.config_file%"
if errorlevel 1 ( call :SetFailure "%app.config_file% failed." & exit /b 1 )
set "app.file_config_loaded=1"
exit /b 0

:: ============================================================
:: :RequireBuildTargetConfig
:: Verifies that some build target source was loaded.
:: A target source is build_config.bat, a custom config file, or explicit default config.
:: Also verifies required build values exist.
:: Returns 0 on success, 1 when no build target is configured.
:: ============================================================
:RequireBuildTargetConfig
if "%app.default_config_loaded%"=="0" if "%app.file_config_loaded%"=="0" ( call :SetFailure "No build target. Create build_config.bat, run build.bat default, or run build.bat target custom_config.bat" & exit /b 1 )
if not defined app.name ( call :SetFailure "No build target: app.name is not configured." & exit /b 1 )
if not defined app.exe ( call :SetFailure "No build target: app.exe is not configured." & exit /b 1 )
if not defined app.default_mode ( call :SetFailure "No build target: app.default_mode is not configured." & exit /b 1 )
if not defined app.gettcc_script ( call :SetFailure "No build target: app.gettcc_script is not configured." & exit /b 1 )
if not defined app.tcc_dir ( call :SetFailure "No build target: app.tcc_dir is not configured." & exit /b 1 )
if not defined app.tcc_exe_name ( call :SetFailure "No build target: app.tcc_exe_name is not configured." & exit /b 1 )
if not defined app.time_format ( call :SetFailure "No build target: app.time_format is not configured." & exit /b 1 )
if not defined app.build_dir_prefix ( call :SetFailure "No build target: app.build_dir_prefix is not configured." & exit /b 1 )
if not defined app.source_dir_prefix ( call :SetFailure "No build target: app.source_dir_prefix is not configured." & exit /b 1 )
if not defined app.temp_root ( call :SetFailure "No build target: app.temp_root is not configured." & exit /b 1 )
if not defined app.oldbuilds_dir ( call :SetFailure "No build target: app.oldbuilds_dir is not configured." & exit /b 1 )
exit /b 0

:: ============================================================
:: :FinalizeBuildConfig
:: Builds derived paths after the target config is loaded.
:: Also fills optional defaults.
:: Returns 0.
:: ============================================================
:FinalizeBuildConfig
if not defined app.display_name set "app.display_name=%app.name%"
if not defined app.libs set "app.libs="
if not defined app.tcc_flags set "app.tcc_flags="
if not defined app.temp_file_dir set "app.temp_file_dir=%TEMP%"
if not defined app.temp_file_prefix set "app.temp_file_prefix=%app.name%-build"
set "app.tcc_bundled_exe=.\%app.tcc_dir%\%app.tcc_exe_name%"
set "app.build_reason_file_prefix=%app.temp_file_dir%\%app.temp_file_prefix%-reason"
set "app.commit_msg_file_prefix=%app.temp_file_dir%\%app.temp_file_prefix%-commit"
if not defined app.resource.lbound set "app.resource.lbound=0"
exit /b 0

:: ============================================================
:: :InitializeBuildState
:: Sets internal per-run state, then applies app.default_mode.
:: app.default_mode comes from build.bat defaults or build_config.bat.
:: Returns 0 on success, 1 on invalid default mode.
:: ============================================================
:InitializeBuildState
set "app.mode="
set "app.check_only=0"
set "app.help_only=0"
set "app.git.commit=0"
set "app.git.push=0"
set "app.run_after_build=0"
set "app.build_complete=0"
set "app.created_final_build=0"
set "app.created_final_source=0"
call :ApplyBuildMode "%app.default_mode%"
exit /b %ERRORLEVEL%

:: ============================================================
:_...CONFIGURATION
:: ============================================================

:: ============================================================
:_BUILD_WORKFLOW
:: ============================================================

:: ============================================================
:: :BuildDescribeRequest
:: Prints the selected build mode and asks for a build purpose only
:: when the selected mode will create a Git commit.
:: Returns 0 on success, non-zero if the user cancels.
:: ============================================================
:BuildDescribeRequest
call :Step "Build requested"
if "%app.check_only%"=="1" ( call :Warn "Check mode: no compile, no build folders, no source snapshot, no commit, no push." & exit /b 0 )
if not "%app.git.commit%"=="1" ( call :Warn "Build-only mode: no Git commit, no GitHub push." & exit /b 0 )
call :AskBuildReason
if errorlevel 1 exit /b 1
call :Info "Purpose: %app.build_reason%"
if "%app.git.push%"=="0" call :Warn "nopush mode: will commit locally but will not push to GitHub."
if "%app.git.push%"=="1" call :Info "sync mode: successful build will commit and push to GitHub."
exit /b 0

:: ============================================================
:: :BuildCheckRequiredTools
:: Selects TCC and checks tools required by the build script.
:: Returns 0 when ready, 1 when something required is missing.
:: ============================================================
:BuildCheckRequiredTools
call :SelectTCC
if errorlevel 1 exit /b 1
call :RequireCommand powershell "PowerShell was not found in PATH."
if errorlevel 1 exit /b 1
call :RequireCommand robocopy "Robocopy was not found in PATH."
if errorlevel 1 exit /b 1
exit /b 0

:: ============================================================
:: :BuildRunCheckOnly
:: Runs prerequisite checks without compiling.
:: Returns 0 when checks pass, 1 when checks fail.
:: ============================================================
:BuildRunCheckOnly
call :RunCheckOnly
if errorlevel 1 exit /b 1
call :Line
call :Ok "Build check passed."
call :Info "Selected compiler: %app.tcc_exe%"
if exist ".git" ( echo. & git status -sb )
call :Line
exit /b 0

:: ============================================================
:: :BuildPrepareRun
:: Creates this build's timestamp and derived folder/file paths.
:: Enables cleanup because build-specific temp paths now exist.
:: Returns 0 on success, 1 on timestamp failure.
:: ============================================================
:BuildPrepareRun
for /f %%A in ('powershell -NoProfile -Command "Get-Date -Format \"%app.time_format%\""') do set "app.build_stamp=%%A"
if not defined app.build_stamp ( call :SetFailure "Could not create build timestamp." & exit /b 1 )
set "app.build_dir=%app.build_dir_prefix%_%app.build_stamp%"
set "app.source_dir=%app.source_dir_prefix%_%app.build_stamp%"
set "app.work_build_dir=%app.temp_root%\%app.build_dir_prefix%_work_%app.build_stamp%"
set "app.work_source_dir=%app.temp_root%\%app.source_dir_prefix%_work_%app.build_stamp%"
set "app.work_output_exe=%app.work_build_dir%\%app.exe%"
set "app.final_output_exe=%app.build_dir%\%app.exe%"
set "app.current_hardlink=%app.exe%"
set "app.cleanup_enabled=1"
exit /b 0

:: ============================================================
:: :BuildCollectSources
:: Collects top-level .c files into app.cfiles for the compiler.
:: Returns 0 when source files exist, 1 when none are found.
:: ============================================================
:BuildCollectSources
call :Step "Collecting C source files"
set "app.cfiles="
for %%F in (*.c) do call :BuildAddSourceFile "%%F"
if not defined app.cfiles ( call :SetFailure "No .c files were found." & exit /b 1 )
call :Ok "C source files found."
exit /b 0

:: ============================================================
:: :BuildAddSourceFile
:: Appends one source file to app.cfiles without global delayed expansion.
:: Usage: call :BuildAddSourceFile "file.c"
:: Returns 0.
:: ============================================================
:BuildAddSourceFile
set "app.next_cfile=%~1"
call set app.cfiles=%%app.cfiles%% "%app.next_cfile%"
set "app.next_cfile="
exit /b 0

:: ============================================================
:: :BuildPrepareTempFolders
:: Creates clean temporary folders for the build.
:: Returns 0 on success, 1 on folder creation failure.
:: ============================================================
:BuildPrepareTempFolders
call :Step "Preparing temporary build folders"
if not exist "%app.temp_root%" mkdir "%app.temp_root%" >nul 2>nul
if not exist "%app.temp_root%" ( call :SetFailure "Could not create temp folder." & exit /b 1 )
if exist "%app.work_build_dir%" rmdir /S /Q "%app.work_build_dir%" >nul 2>nul
if exist "%app.work_source_dir%" rmdir /S /Q "%app.work_source_dir%" >nul 2>nul
mkdir "%app.work_build_dir%" >nul 2>nul
if not exist "%app.work_build_dir%" ( call :SetFailure "Could not create temporary build folder." & exit /b 1 )
call :Ok "Temporary folders ready."
exit /b 0

:: ============================================================
:: :BuildCompile
:: Compiles the program into the temporary build folder.
:: Returns 0 on success, 1 on compile failure.
:: ============================================================
:BuildCompile
call :Step "Compiling"
call :Info "Compiler: %app.tcc_exe%"
call :Info "Output:   %app.work_output_exe%"
"%app.tcc_exe%" %app.tcc_flags% -o "%app.work_output_exe%" %app.cfiles% %app.libs%
call :CheckError "Build failed."
if errorlevel 1 exit /b 1
if not exist "%app.work_output_exe%" ( call :SetFailure "Build command completed, but output exe was not created." & exit /b 1 )
call :Ok "Compilation succeeded."
exit /b 0

:: ============================================================
:: :BuildCreateSnapshots
:: Creates source snapshots after a successful compile.
:: Returns 0 on success, 1 on Robocopy failure.
:: ============================================================
:BuildCreateSnapshots
call :Step "Creating source snapshot"
robocopy . "%app.work_source_dir%" /E /XD .git %app.build_dir_prefix%_* %app.source_dir_prefix%_* "%app.oldbuilds_dir%" "%app.temp_root%" "%app.tcc_dir%" /XF "%app.exe%" *.exe *.obj *.pdb *.ilk *.res *.log >nul
call :CheckRobocopy "Source copy failed."
if errorlevel 1 exit /b 1
call :Ok "Source snapshot prepared."
call :Step "Copying source snapshot into build folder"
robocopy "%app.work_source_dir%" "%app.work_build_dir%\%app.source_dir%" /E >nul
call :CheckRobocopy "Build source copy failed."
if errorlevel 1 exit /b 1
call :Ok "Build source snapshot prepared."
exit /b 0

:: ============================================================
:: :BuildPromoteSuccessfulBuild
:: Moves temporary build/source folders to final build_*/source_* folders.
:: Returns 0 on success, 1 on move failure.
:: ============================================================
:BuildPromoteSuccessfulBuild
call :Step "Promoting successful build"
if exist "%app.build_dir%" ( call :SetFailure "Final build folder already exists: %app.build_dir%" & exit /b 1 )
if exist "%app.source_dir%" ( call :SetFailure "Final source folder already exists: %app.source_dir%" & exit /b 1 )
move "%app.work_build_dir%" "%app.build_dir%" >nul
call :CheckError "Could not move temporary build folder to final build folder."
if errorlevel 1 exit /b 1
set "app.created_final_build=1"
move "%app.work_source_dir%" "%app.source_dir%" >nul
call :CheckError "Could not move temporary source folder to final source folder."
if errorlevel 1 exit /b 1
set "app.created_final_source=1"
set "app.build_complete=1"
call :Ok "Final build and source folders created."
exit /b 0

:: ============================================================
:: :BuildArchiveOldFolders
:: Moves older build and source folders into the configured archive folder.
:: Returns 0 even if the archive folder cannot be created.
:: ============================================================
:BuildArchiveOldFolders
call :Step "Archiving older build/source folders"
if not exist "%app.oldbuilds_dir%" mkdir "%app.oldbuilds_dir%" >nul 2>nul
if exist "%app.oldbuilds_dir%" (
    for /d %%D in (%app.build_dir_prefix%_*) do if /i not "%%~nxD"=="%app.build_dir%" move "%%D" "%app.oldbuilds_dir%\%%~nxD" >nul 2>nul
    for /d %%D in (%app.source_dir_prefix%_*) do if /i not "%%~nxD"=="%app.source_dir%" move "%%D" "%app.oldbuilds_dir%\%%~nxD" >nul 2>nul
    call :Ok "Older build/source folders archived."
) else (
    call :Warn "Could not create %app.oldbuilds_dir% folder. Build still succeeded."
)
exit /b 0

:: ============================================================
:: :BuildUpdateCurrentExe
:: Updates the configured current executable as a hardlink or copy.
:: Returns 0.
:: ============================================================
:BuildUpdateCurrentExe
call :Step "Updating current exe link"
if exist "%app.current_hardlink%" del "%app.current_hardlink%" >nul 2>nul
mklink /H "%app.current_hardlink%" "%app.final_output_exe%" >nul 2>nul
if errorlevel 1 copy /Y "%app.final_output_exe%" "%app.current_hardlink%" >nul 2>nul
if exist "%app.current_hardlink%" ( call :Ok "Updated %app.current_hardlink%." ) else ( call :Warn "Build succeeded, but could not update %app.current_hardlink%." )
exit /b 0

:: ============================================================
:: :BuildReportSuccess
:: Prints final build output paths.
:: Returns 0.
:: ============================================================
:BuildReportSuccess
call :Line
call :Ok "Build complete."
call :Info "Output: %app.final_output_exe%"
call :Info "Link:   %app.current_hardlink%"
call :Line
exit /b 0

:: ============================================================
:: :BuildRunProgram
:: Runs the current executable after a successful build.
:: Returns 0.
:: ============================================================
:BuildRunProgram
call :Step "Running program"
if exist "%app.current_hardlink%" ( start "" "%CD%\%app.current_hardlink%" & call :Ok "Started %app.current_hardlink%." ) else ( call :Warn "Could not run because %app.current_hardlink% was not found." )
exit /b 0

:: ============================================================
:_...BUILD_WORKFLOW
:: ============================================================

:: ============================================================
:_USER_INPUT
:: ============================================================

:: ============================================================
:: :AskBuildReason
:: Asks the user for the build purpose.
:: The answer becomes the Git commit message in sync/nopush modes.
:: The temporary input file path is derived from setup values.
:: Empty messages are rejected.
:: Outputs app.build_reason and BUILD_REASON.
:: Returns 0 when accepted, 130 when cancelled.
:: ============================================================
:AskBuildReason
call :Line
call :Say app.color.header "%app.display_name% build"
call :Say app.color.note "Type what this build is for. This becomes the Git commit message after a successful build."
call :Say app.color.skip "Press Ctrl+C to cancel before anything builds."
call :Say app.color.skip "Empty messages are not accepted."
call :Line
:AskBuildReasonLoop
set "app.build_reason="
set "BUILD_REASON="
set "app.build_reason_file=%app.build_reason_file_prefix%-%RANDOM%-%RANDOM%.txt"
set "BUILD_REASON_FILE=%app.build_reason_file%"
echo.
call :PrintWord app.color.cyan "Build purpose"
<nul set /p "= : "
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try { [Console]::TreatControlCAsInput=$false; $s=[Console]::ReadLine(); if($null -eq $s){ exit 130 }; $s=$s.Trim(); if([string]::IsNullOrWhiteSpace($s)){ exit 3 }; $s=$s.Replace([char]34,[char]39).Replace([char]33,'.').Replace([char]37,'_').Replace([char]38,'_').Replace([char]60,'_').Replace([char]62,'_').Replace([char]124,'_').Replace([char]94,'_'); [IO.File]::WriteAllText($env:BUILD_REASON_FILE, $s, [Text.Encoding]::Default); exit 0 } catch { exit 130 }"
set "ASK_REASON_RC=%ERRORLEVEL%"
if exist "%BUILD_REASON_FILE%" ( set /p "app.build_reason="<"%BUILD_REASON_FILE%" & del "%BUILD_REASON_FILE%" >nul 2>nul )
if "%ASK_REASON_RC%"=="0" (
    set "BUILD_REASON=%app.build_reason%"
    if defined app.build_reason exit /b 0
    call :Say app.color.fail "A build purpose is required. Press Ctrl+C to cancel."
    goto AskBuildReasonLoop
)
if "%ASK_REASON_RC%"=="3" ( call :Say app.color.fail "A build purpose is required. Press Ctrl+C to cancel." & goto AskBuildReasonLoop )
echo.
call :Warn "Build cancelled before anything was built."
set "app.rc=130"
exit /b 130

:: ============================================================
:_...USER_INPUT
:: ============================================================

:: ============================================================
:_COMPILER_SELECTION
:: ============================================================

:: ============================================================
:: :FindTCC
:: Finds the Tiny C Compiler executable.
:: Search order: configured bundled TCC, then configured TCC exe name from PATH.
:: Outputs app.tcc_exe.
:: Returns 0 when found, 1 when not found.
:: ============================================================
:FindTCC
set "app.tcc_exe="
if exist "%app.tcc_bundled_exe%" ( set "app.tcc_exe=%app.tcc_bundled_exe%" & exit /b 0 )
for %%T in (%app.tcc_exe_name%) do set "app.tcc_exe=%%~$PATH:T"
if defined app.tcc_exe exit /b 0
exit /b 1

:: ============================================================
:: :SelectTCC
:: Selects the Tiny C Compiler.
:: If TCC is unavailable, calls the configured gettcc script, then searches again.
:: Outputs app.tcc_exe.
:: Returns 0 when selected, 1 when unavailable.
:: ============================================================
:SelectTCC
call :Step "Selecting Tiny C Compiler"
call :FindTCC
if not errorlevel 1 (
    if /I "%app.tcc_exe%"=="%app.tcc_bundled_exe%" ( call :Ok "Using bundled Tiny C Compiler: %app.tcc_bundled_exe%" ) else ( call :Ok "Using Tiny C Compiler from PATH: %app.tcc_exe%" )
    exit /b 0
)
call :Warn "Tiny C Compiler was not found."
if exist "%app.gettcc_script%" (
    call :Info "Running %app.gettcc_script%..."
    call "%app.gettcc_script%"
    cd /d "%~dp0"
    if errorlevel 1 ( call :SetFailure "%app.gettcc_script% failed." & exit /b 1 )
) else (
    call :SetFailure "Tiny C Compiler was not found, and %app.gettcc_script% does not exist."
    exit /b 1
)
call :FindTCC
if errorlevel 1 ( call :SetFailure "%app.gettcc_script% ran, but Tiny C Compiler is still unavailable." & exit /b 1 )
if /I "%app.tcc_exe%"=="%app.tcc_bundled_exe%" ( call :Ok "Using bundled Tiny C Compiler after %app.gettcc_script%: %app.tcc_bundled_exe%" ) else ( call :Ok "Using Tiny C Compiler after %app.gettcc_script%: %app.tcc_exe%" )
exit /b 0

:: ============================================================
:_...COMPILER_SELECTION
:: ============================================================

:: ============================================================
:_PREREQUISITE_CHECKS
:: ============================================================

:: ============================================================
:: :RequireCommand
:: Checks that a command exists in PATH.
:: Usage: call :RequireCommand commandName "failure message"
:: Returns 0 when found, 1 when missing.
:: ============================================================
:RequireCommand
where %~1 >nul 2>nul
if errorlevel 1 ( call :SetFailure "%~2" & exit /b 1 )
exit /b 0

:: ============================================================
:: :RunCheckOnly
:: Performs build setup checks without compiling.
:: Checks configured resource generators, resource roots, .c files, and Git.
:: Uses local delayed expansion only inside this function for pseudoarray inspection.
:: Returns 0 if checks passed, 1 if important checks failed.
:: ============================================================
:RunCheckOnly
setlocal EnableDelayedExpansion
set "CHECK_FAILED=0"
call :Step "Checking project files"
set "CHECK_CFILES="
for %%F in (*.c) do set "CHECK_CFILES=1"
if defined CHECK_CFILES ( call :Ok "Found .c source files." ) else ( call :FailText "No .c source files were found." & set "CHECK_FAILED=1" )
if defined app.resource.ubound (
    call :Info "Checking configured resources..."
    for /L %%R in (%app.resource.lbound%,1,%app.resource.ubound%) do (
        call :ResourceLoad %%R
        if errorlevel 1 (
            set "CHECK_FAILED=1"
        ) else (
            if /I "!res.enabled!"=="0" (
                call :Warn "Resource disabled: !res.label!"
            ) else (
                if exist "!res.generator!" ( call :Ok "Found resource generator for !res.label!: !res.generator!" ) else ( call :FailText "Missing resource generator for !res.label!: !res.generator!" & set "CHECK_FAILED=1" )
                if exist "!res.root!" ( call :Ok "Found resource root for !res.label!: !res.root!" ) else ( call :FailText "Missing resource root for !res.label!: !res.root!" & set "CHECK_FAILED=1" )
                if defined res.output ( call :Ok "Resource output for !res.label!: !res.output!" ) else ( call :FailText "Missing resource output for !res.label!." & set "CHECK_FAILED=1" )
            )
        )
    )
) else (
    call :Warn "No app.resource.ubound configured. No generated resources will be checked."
)
if exist ".git" ( call :Ok "Git repository detected." ) else ( call :Warn "This folder is not a Git repository." )
where git >nul 2>nul
if errorlevel 1 ( call :Warn "git was not found. Build can run, but Git/GitHub actions will fail." ) else ( call :Ok "git found." )
if "%CHECK_FAILED%"=="1" ( endlocal & call :SetFailure "Build check found problems." & exit /b 1 )
endlocal & exit /b 0

:: ============================================================
:_...PREREQUISITE_CHECKS
:: ============================================================

:: ============================================================
:_RESOURCE_GENERATION
:: ============================================================

:: ============================================================
:: :ResourceLoad
:: Loads one app.resource[index] pseudoarray item into res.* variables.
:: Usage: call :ResourceLoad index
:: Example source variable:
::   app.resource[0].id
:: Returns 0 on success, 1 if required values are missing.
:: ============================================================
:ResourceLoad
set "res.index=%~1"
call set "res.id=%%app.resource[%~1].id%%"
call set "res.label=%%app.resource[%~1].label%%"
call set "res.enabled=%%app.resource[%~1].enabled%%"
call set "res.kind=%%app.resource[%~1].kind%%"
call set "res.root=%%app.resource[%~1].root%%"
call set "res.include=%%app.resource[%~1].include%%"
call set "res.generator=%%app.resource[%~1].generator%%"
call set "res.output=%%app.resource[%~1].output%%"
call set "res.hash=%%app.resource[%~1].hash%%"
call set "res.hash_new=%%app.resource[%~1].hash_new%%"
call set "res.group=%%app.resource[%~1].group%%"
call set "res.legacy_output=%%app.resource[%~1].legacy_output%%"
if not defined res.id ( call :SetFailure "Missing resource id: app.resource[%~1].id" & exit /b 1 )
if not defined res.enabled set "res.enabled=1"
if not defined res.label set "res.label=%res.id%"
if not defined res.include set "res.include=*"
if not defined res.kind set "res.kind=embedded"
if not defined res.root ( call :SetFailure "Missing resource root: app.resource[%~1].root" & exit /b 1 )
if not defined res.generator ( call :SetFailure "Missing resource generator: app.resource[%~1].generator" & exit /b 1 )
if not defined res.output ( call :SetFailure "Missing resource output: app.resource[%~1].output" & exit /b 1 )
if not defined res.hash ( call :SetFailure "Missing resource hash: app.resource[%~1].hash" & exit /b 1 )
if not defined res.hash_new ( call :SetFailure "Missing resource hash_new: app.resource[%~1].hash_new" & exit /b 1 )
if not defined res.group set "res.group=%res.id%"
set "res.stage_root=%app.temp_root%\resource_%res.id%_%app.build_stamp%"
exit /b 0

:: ============================================================
:: :ResourcesEnsureAll
:: Processes every resource group from build_config.bat.
:: Uses app.resource.lbound and app.resource.ubound.
:: app.resource.lbound defaults to 0 when omitted.
:: app.resource.ubound is inclusive.
:: Returns 0 on success, 1 on failure.
:: ============================================================
:ResourcesEnsureAll
if not defined app.resource.lbound set "app.resource.lbound=0"
if not defined app.resource.ubound exit /b 0
for /L %%R in (%app.resource.lbound%,1,%app.resource.ubound%) do (
    call :ResourceEnsure %%R
    if errorlevel 1 exit /b 1
)
exit /b 0

:: ============================================================
:: :ResourceEnsure
:: Ensures one generated resource C file is up to date.
:: Usage: call :ResourceEnsure index
:: Returns 0 on success, 1 on failure.
:: ============================================================
:ResourceEnsure
call :ResourceLoad %~1
if errorlevel 1 exit /b 1
if "%res.enabled%"=="0" ( call :Warn "Resource skipped: %res.label%" & exit /b 0 )
call :ResourceWriteInputHash
if errorlevel 1 exit /b 1
call :ResourceDecideRebuild
if not "%res.rebuild%"=="1" (
    call :Ok "%res.label% source is up to date."
    if exist "%res.hash_new%" del "%res.hash_new%" >nul 2>nul
    exit /b 0
)
call :ResourceRebuild
exit /b %ERRORLEVEL%

:: ============================================================
:: :ResourceWriteInputHash
:: Writes a hash file for one configured resource group.
:: The hash includes generator, config values, and matching input files.
:: Returns 0 on success, 1 on failure.
:: ============================================================
:ResourceWriteInputHash
call :Step "Checking %res.label%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $r='%res.root%'; $g='%res.generator%'; $o='%res.hash_new%'; $include='%res.include%'; $kind='%res.kind%'; $group='%res.group%'; $output='%res.output%'; $old='%app.oldbuilds_dir%'; $tmp='%app.temp_root%'; $tcc='%app.tcc_dir%'; $bp='%app.build_dir_prefix%'; $sp='%app.source_dir_prefix%'; $a=@(); $a += ('KIND ' + $kind); $a += ('GROUP ' + $group); $a += ('ROOT ' + $r); $a += ('INCLUDE ' + $include); $a += ('OUTPUT ' + $output); $skip={ param($rel) $parts=$rel -split '[\\/]' ; foreach($p in $parts){ if($p -like ($bp + '_*') -or $p -like ($sp + '_*') -or $p -ieq $old -or $p -ieq $tmp -or $p -ieq $tcc -or $p -ieq '.git'){ return $true } } return $false }; if(Test-Path $g){$a += ('GEN ' + (Get-FileHash $g).Hash)} else {$a += 'GEN_MISSING'}; if(Test-Path $r){$b=(Resolve-Path $r).Path; Get-ChildItem $r -Filter $include -File -Recurse | Sort-Object FullName | ForEach-Object { $rel=$_.FullName.Substring($b.Length).TrimStart('\','/').Replace('\','/'); if(-not (& $skip $rel)){ $a += ('FILE ' + $rel + ' ' + (Get-FileHash $_.FullName).Hash) } }} else {$a += 'ROOT_MISSING'}; $a | Set-Content -Encoding ASCII $o"
call :CheckError "%res.label% hash check failed."
exit /b %ERRORLEVEL%

:: ============================================================
:: :ResourceDecideRebuild
:: Sets res.rebuild to 1 when the generated resource C file must rebuild.
:: Returns 0.
:: ============================================================
:ResourceDecideRebuild
set "res.rebuild=0"
if not exist "%res.output%" set "res.rebuild=1"
if not exist "%res.hash%" set "res.rebuild=1"
if not exist "%res.hash_new%" set "res.rebuild=1"
if exist "%res.hash%" if exist "%res.hash_new%" fc /b "%res.hash%" "%res.hash_new%" >nul || set "res.rebuild=1"
exit /b 0

:: ============================================================
:: :ResourceRebuild
:: Rebuilds one generated resource C file.
:: Stages matching inputs first so generators do not read oldbuilds,
:: build folders, source snapshots, temp, tcc, or .git.
:: Supports:
::   kind=embedded  uses -Root -OutFile -Group -Include
::   kind=theme     uses -ThemeRoot -OutFile
:: Returns 0 on success, 1 on failure.
:: ============================================================
:ResourceRebuild
if defined res.legacy_output if exist "%res.legacy_output%" del "%res.legacy_output%" >nul 2>nul
call :Info "Preparing %res.label% input..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $src='%res.root%'; $dst='%res.stage_root%'; $include='%res.include%'; $old='%app.oldbuilds_dir%'; $tmp='%app.temp_root%'; $tcc='%app.tcc_dir%'; $bp='%app.build_dir_prefix%'; $sp='%app.source_dir_prefix%'; $skip={ param($rel) $parts=$rel -split '[\\/]' ; foreach($p in $parts){ if($p -like ($bp + '_*') -or $p -like ($sp + '_*') -or $p -ieq $old -or $p -ieq $tmp -or $p -ieq $tcc -or $p -ieq '.git'){ return $true } } return $false }; if(Test-Path $dst){Remove-Item $dst -Recurse -Force}; New-Item -ItemType Directory -Force -Path $dst | Out-Null; if(Test-Path $src){$base=(Resolve-Path $src).Path; Get-ChildItem $src -Filter $include -File -Recurse | ForEach-Object { $rel=$_.FullName.Substring($base.Length).TrimStart('\','/'); if(-not (& $skip $rel)){ $target=Join-Path $dst $rel; New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null; Copy-Item $_.FullName $target -Force } }}"
call :CheckError "%res.label% staging failed."
if errorlevel 1 exit /b 1
call :Info "Generating %res.label% source..."
if /I "%res.kind%"=="embedded" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%res.generator%" -Root "%res.stage_root%" -OutFile "%res.output%" -Group "%res.group%" -Include "%res.include%"
    call :CheckError "%res.label% generation failed."
    if errorlevel 1 exit /b 1
    move /Y "%res.hash_new%" "%res.hash%" >nul
    call :CheckError "%res.label% hash update failed."
    if errorlevel 1 exit /b 1
    if exist "%res.stage_root%" rmdir /S /Q "%res.stage_root%" >nul 2>nul
    call :Ok "%res.label% source regenerated."
    exit /b 0
)
if /I "%res.kind%"=="theme" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%res.generator%" -ThemeRoot "%res.stage_root%" -OutFile "%res.output%"
    call :CheckError "%res.label% generation failed."
    if errorlevel 1 exit /b 1
    move /Y "%res.hash_new%" "%res.hash%" >nul
    call :CheckError "%res.label% hash update failed."
    if errorlevel 1 exit /b 1
    if exist "%res.stage_root%" rmdir /S /Q "%res.stage_root%" >nul 2>nul
    call :Ok "%res.label% source regenerated."
    exit /b 0
)
call :SetFailure "Unknown resource kind for %res.label%: %res.kind%"
exit /b 1

:: ============================================================
:_...RESOURCE_GENERATION
:: ============================================================

:: ============================================================
:_GIT_GITHUB
:: ============================================================

:: ============================================================
:: :GitSync
:: Commits and optionally pushes after a successful build.
:: Controlled by app.git.commit and app.git.push.
:: Returns 0 on success or nothing to commit, 1 on Git/GitHub failure.
:: ============================================================
:GitSync
call :Step "Git sync"
if not exist ".git" ( call :Warn "Git sync skipped: this folder is not a Git repository." & exit /b 0 )
where git >nul 2>nul
if errorlevel 1 ( call :SetFailure "Git sync failed: git was not found." & exit /b 1 )
call :EnsureGitIgnoreSafety
set "GIT_DIRTY="
for /f "delims=" %%G in ('git status --porcelain') do set "GIT_DIRTY=1"
if defined GIT_DIRTY (
    call :GitCommitChanges
    if errorlevel 1 exit /b 1
) else (
    call :Ok "No Git changes to commit."
)
if "%app.git.push%"=="1" (
    call :GitPush
    if errorlevel 1 exit /b 1
    exit /b 0
)
call :Warn "Push skipped."
call :Info "Later, push local commits with:"
echo   just_push.bat
exit /b 0

:: ============================================================
:: :GitCommitChanges
:: Stages all changes and creates a Git commit using app.build_reason.
:: The temporary commit message file path is derived from setup values.
:: Returns 0 on success, 1 on failure.
:: ============================================================
:GitCommitChanges
call :Info "Successful build. These files changed:"
echo.
git status --short
echo.
call :Info "Commit message:"
call :Say app.color.summary "%app.build_reason%"
echo.
git add --all
if errorlevel 1 ( call :SetFailure "git add failed." & exit /b 1 )
set "app.commit_msg_file=%app.commit_msg_file_prefix%-%RANDOM%-%RANDOM%.txt"
set "COMMIT_MSG_FILE=%app.commit_msg_file%"
set "BUILD_REASON=%app.build_reason%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Set-Content -LiteralPath $env:COMMIT_MSG_FILE -Value $env:BUILD_REASON -Encoding UTF8"
if errorlevel 1 ( call :SetFailure "Could not create temporary commit message file." & exit /b 1 )
git commit -F "%COMMIT_MSG_FILE%"
set "GIT_COMMIT_RC=%ERRORLEVEL%"
if exist "%COMMIT_MSG_FILE%" del "%COMMIT_MSG_FILE%" >nul 2>nul
if not "%GIT_COMMIT_RC%"=="0" ( call :SetFailure "git commit failed." & exit /b 1 )
exit /b 0

:: ============================================================
:: :GitPush
:: Pushes local commits to GitHub using the configured upstream.
:: Returns 0 on success, 1 on failure.
:: ============================================================
:GitPush
call :Info "Pushing to GitHub..."
git push
if errorlevel 1 ( call :SetFailure "git push failed." & exit /b 1 )
call :Ok "GitHub sync complete."
exit /b 0

:: ============================================================
:: :EnsureGitIgnoreSafety
:: Makes sure common generated build outputs are ignored by Git.
:: Prevents accidental commits of build folders, snapshots, temp, tcc, exe, and object files.
:: Returns 0.
:: ============================================================
:EnsureGitIgnoreSafety
if not exist ".gitignore" type nul > ".gitignore"
call :EnsureGitIgnoreLine "%app.build_dir_prefix%_*/"
call :EnsureGitIgnoreLine "%app.source_dir_prefix%_*/"
call :EnsureGitIgnoreLine "%app.oldbuilds_dir%/"
call :EnsureGitIgnoreLine "%app.temp_root%/"
call :EnsureGitIgnoreLine "%app.tcc_dir%/"
call :EnsureGitIgnoreLine "*.exe"
call :EnsureGitIgnoreLine "*.obj"
call :EnsureGitIgnoreLine "*.pdb"
call :EnsureGitIgnoreLine "*.ilk"
call :EnsureGitIgnoreLine "*.res"
call :EnsureGitIgnoreLine "*.log"
exit /b 0

:: ============================================================
:: :EnsureGitIgnoreLine
:: Adds a line to .gitignore if it is not already present.
:: Usage: call :EnsureGitIgnoreLine "pattern"
:: Returns 0.
:: ============================================================
:EnsureGitIgnoreLine
set "GITIGNORE_LINE=%~1"
findstr /L /X /C:"%GITIGNORE_LINE%" ".gitignore" >nul 2>nul
if errorlevel 1 >> ".gitignore" echo(%GITIGNORE_LINE%
exit /b 0

:: ============================================================
:_...GIT_GITHUB
:: ============================================================

:: ============================================================
:_ERROR_HANDLING
:: ============================================================

:: ============================================================
:: :SetFailure
:: Records a failure message and sets app.rc to 1.
:: Usage: call :SetFailure "message"
:: Returns 1.
:: ============================================================
:SetFailure
set "app.rc=1"
set "app.fail_message=%~1"
call :FailText "%~1"
exit /b 1

:: ============================================================
:: :CheckError
:: Converts the previous command errorlevel into a build failure.
:: Usage: someCommand, then call :CheckError "failure message"
:: Returns 0 if previous command succeeded, 1 if it failed.
:: ============================================================
:CheckError
if errorlevel 1 ( call :SetFailure "%~1" & exit /b 1 )
exit /b 0

:: ============================================================
:: :CheckRobocopy
:: Checks Robocopy result codes.
:: Robocopy codes 0 through 7 are acceptable; 8 or higher is failure.
:: Returns 0 if acceptable, 1 if failed.
:: ============================================================
:CheckRobocopy
if errorlevel 8 ( call :SetFailure "%~1" & exit /b 1 )
exit /b 0

:: ============================================================
:_...ERROR_HANDLING
:: ============================================================

:: ============================================================
:_CLEANUP
:: ============================================================

:: ============================================================
:: :CleanupTemp
:: Removes temporary build folders and temporary resource files.
:: On failed builds, removes final folders partially created by this run.
:: Skips cleanup when no build run was prepared, such as help-only mode.
:: Returns 0.
:: ============================================================
:CleanupTemp
if not "%app.cleanup_enabled%"=="1" exit /b 0
if defined app.work_build_dir if exist "%app.work_build_dir%" rmdir /S /Q "%app.work_build_dir%" >nul 2>nul
if defined app.work_source_dir if exist "%app.work_source_dir%" rmdir /S /Q "%app.work_source_dir%" >nul 2>nul
if defined res.stage_root if exist "%res.stage_root%" rmdir /S /Q "%res.stage_root%" >nul 2>nul
if defined res.hash_new if exist "%res.hash_new%" del "%res.hash_new%" >nul 2>nul
if not "%app.build_complete%"=="1" (
    if "%app.created_final_build%"=="1" if defined app.build_dir if exist "%app.build_dir%" rmdir /S /Q "%app.build_dir%" >nul 2>nul
    if "%app.created_final_source%"=="1" if defined app.source_dir if exist "%app.source_dir%" rmdir /S /Q "%app.source_dir%" >nul 2>nul
)
if defined app.temp_root rmdir "%app.temp_root%" >nul 2>nul
exit /b 0

:: ============================================================
:_...CLEANUP
:: ============================================================

:: ============================================================
:_CONSOLE_OUTPUT_HELPERS
:: ============================================================

:: ============================================================
:: :Line
:: Prints a horizontal separator line.
:: ============================================================
:Line
echo(%app.color.gray%------------------------------------------------------------%app.color.reset%
exit /b 0

:: ============================================================
:: :Step
:: Prints a build step heading.
:: Usage: call :Step "message"
:: ============================================================
:Step
echo.
echo(%app.color.header%== %~1 ==%app.color.reset%
exit /b 0

:: ============================================================
:: :Info
:: Prints an informational message.
:: Usage: call :Info "message"
:: ============================================================
:Info
echo(%app.color.white%%~1%app.color.reset%
exit /b 0

:: ============================================================
:: :Ok
:: Prints a success message.
:: Usage: call :Ok "message"
:: ============================================================
:Ok
echo(%app.color.pass%OK: %~1%app.color.reset%
exit /b 0

:: ============================================================
:: :Warn
:: Prints a warning message.
:: Usage: call :Warn "message"
:: ============================================================
:Warn
echo(%app.color.skip%WARNING: %~1%app.color.reset%
exit /b 0

:: ============================================================
:: :FailText
:: Prints an error message.
:: Usage: call :FailText "message"
:: ============================================================
:FailText
echo(%app.color.fail%ERROR: %~1%app.color.reset%
exit /b 0

:: ============================================================
:: :Say
:: Prints a full line using a color variable.
:: Usage: call :Say app.color.cyan "message"
:: ============================================================
:Say
call set "say_color=%%%~1%%"
echo(%say_color%%~2%app.color.reset%
exit /b 0

:: ============================================================
:: :PrintWord
:: Prints text without a newline using a color variable.
:: Usage: call :PrintWord app.color.cyan "text"
:: ============================================================
:PrintWord
call set "word_color=%%%~1%%"
<nul set /p "=%word_color%%~2%app.color.reset%"
exit /b 0

:: ============================================================
:_...CONSOLE_OUTPUT_HELPERS
:: ============================================================

:: ============================================================
:_COLOR_SETUP
:: ============================================================

:: ============================================================
:: :SetNoColors
:: Clears all color variables.
:: Used when ANSI escape capture fails.
:: Returns 0.
:: ============================================================
:SetNoColors
set "app.esc="
for %%C in (black red green yellow blue magenta cyan white gray bold clear reset pass fail skip harnessfail header summary note) do set "app.color.%%C="
exit /b 0

:: ============================================================
:: :SetESC
:: Captures the ANSI escape character into the requested output variable.
:: Usage: call :SetESC outputVariable
:: Output: outputVariable = ANSI escape character.
:: Returns 0 on success, 2 if output variable is missing.
:: ============================================================
:SetESC
for /f "tokens=1 delims==" %%v in ('set sesc_ 2^>nul') do set "%%v="
if defined _sesc_rc ( set "_sesc_rc=" & exit /b %_sesc_rc% )
set "sesc_out=%~1"
if not defined sesc_out ( set "_sesc_rc=2" & goto :SetESC )
for /f %%a in ('echo prompt $E^| cmd') do set "%sesc_out%=%%a"
set "_sesc_rc=0"
goto :SetESC

:: ============================================================
:: :SetAppColors
:: Sets app ANSI color variables.
:: Usage: call :SetAppColors
:: Requires :SetESC.
:: Returns 0 when colors are set, 1 when ESC is unavailable.
:: ============================================================
:SetAppColors
if not defined app.esc call :SetESC app.esc
if not defined app.esc exit /b 1
for %%A in ("black=30" "red=31" "green=32" "yellow=33" "blue=34" "magenta=35" "cyan=36" "white=37" "gray=90" "bold=1" "clear=0") do for /f "tokens=1,2 delims==" %%B in ("%%~A") do set "app.color.%%B=%app.esc%[%%Cm"
set "app.color.reset=%app.color.clear%"
set "app.color.pass=%app.color.green%"
set "app.color.fail=%app.color.red%"
set "app.color.skip=%app.color.yellow%"
set "app.color.harnessfail=%app.color.magenta%"
set "app.color.header=%app.color.cyan%"
set "app.color.summary=%app.color.bold%"
set "app.color.note=%app.color.gray%"
exit /b 0

:: ============================================================
:_...COLOR_SETUP
:: ============================================================