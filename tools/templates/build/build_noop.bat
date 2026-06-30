@echo off
:: ============================================================
:: build_noop.bat
:: Generic, intentionally minimal build implementation and template.
::
:: This file performs the common build lifecycle even when no compiler
:: or packager has been configured yet:
::   1. loads shared and suffix-specific configuration
::   2. parses the requested build mode
::   3. checks generic and project-specific prerequisites
::   4. creates temporary build work folders
::   5. runs the customizable build-operation functions
::   6. creates a source snapshot
::   7. promotes successful work folders to dated final folders
::   8. moves older dated folders into oldbuilds
::
:: Final layout:
::   build_YYYY-MM-DD.HHhmm.ss\
::   source_YYYY-MM-DD.HHhmm.ss\
::   oldbuilds\
::
:: The build folder is empty until :BuildOperations writes artifacts
:: into app.build.noop.work_build_dir. The source folder contains a
:: current project snapshot.
::
:: Source snapshot behavior:
::   - in a Git worktree, copies tracked files plus untracked files
::     that are not ignored by Git
::   - outside Git, falls back to a filesystem copy
::   - always excludes .git, build_*, source_*, oldbuilds, and the
::     configured temporary work folder
::
:: Primary customization points:
::   :CheckBuildPrerequisites
::   :BuildOperations
::   :ValidateBuildOutputs
::
:: Configuration order:
::   1. build_config.bat
::   2. build_config_noop.bat when present
::
:: Optional configuration values:
::   app.noop.default_mode=build
::   app.noop.title=Project build
::   app.noop.description=Description of the build
::   app.noop.build_dir_prefix=build
::   app.noop.source_dir_prefix=source
::   app.noop.oldbuilds_dir=oldbuilds
::   app.noop.temp_root=temp
::
:: Active placement:
::   build_noop.bat at the project root
::
:: Template storage:
::   tools\templates\build\build_noop.bat
::
:: Usage:
::   call build_noop.bat [build|rebuild|nosync|check|clean|help]
::
:: Returns: 0 on success
::          1 on setup, snapshot, build, promotion, or archive failure
::          2 on an invalid command-line argument
::          shared/suffix config exit code when a config fails
:: Requires: build_config.bat, PowerShell
::           Git for Git-aware snapshots
::           Robocopy for non-Git filesystem snapshots
:: ============================================================
:setup
set "app.build.noop.rc=0"
set "app.build.noop.root="
set "app.build.noop.shared_config="
set "app.build.noop.suffix_config="
set "app.build.noop.mode="
set "app.build.noop.timestamp="
set "app.build.noop.snapshot_mode="
set "app.build.noop.git="
set "app.build.noop.final_build_dir="
set "app.build.noop.final_source_dir="
set "app.build.noop.work_build_dir="
set "app.build.noop.work_source_dir="
set "app.build.noop.archive_dir="
set "app.build.noop.archive_failed="
set "app.build.noop.created_final_build="
set "app.build.noop.created_final_source="
set "app.build.noop.build_complete="
set "app.build.suffix=noop"
if not defined BUILD_SUFFIX set "BUILD_SUFFIX=noop"
if defined BUILD_PROJECT_ROOT set "app.build.noop.root=%BUILD_PROJECT_ROOT%"
if not defined app.build.noop.root for %%A in ("%~dp0.") do set "app.build.noop.root=%%~fA"
for %%A in ("%app.build.noop.root%\.") do set "app.build.noop.root=%%~fA"
:main
call :LoadConfiguration
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
call :SetDefaults
call :ParseArguments %*
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
cd /d "%app.build.noop.root%"
set "app.build.noop.rc=%errorlevel%"
if "%app.build.noop.rc%"=="0" goto :_main_dispatch
echo ERROR: Could not enter project root:
echo   "%app.build.noop.root%"
set "app.build.noop.rc=1"
goto :end
:_main_dispatch
if /I "%app.build.noop.mode%"=="help" call :ShowHelp
if /I "%app.build.noop.mode%"=="help" set "app.build.noop.rc=%errorlevel%"
if /I "%app.build.noop.mode%"=="help" goto :end
call :ShowHeader
if /I "%app.build.noop.mode%"=="check" call :CheckOnly
if /I "%app.build.noop.mode%"=="check" set "app.build.noop.rc=%errorlevel%"
if /I "%app.build.noop.mode%"=="check" goto :end
if /I "%app.build.noop.mode%"=="clean" call :Clean
if /I "%app.build.noop.mode%"=="clean" set "app.build.noop.rc=%errorlevel%"
if /I "%app.build.noop.mode%"=="clean" goto :end
call :CheckGenericPrerequisites
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
call :CheckBuildPrerequisites
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
call :PrepareRun
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
call :PrepareWorkFolders
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
call :BuildOperations
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
call :ValidateBuildOutputs
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
call :CreateSourceSnapshot
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
call :PromoteSuccessfulBuild
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
call :ArchiveOlderFolders
set "app.build.noop.rc=%errorlevel%"
if not "%app.build.noop.rc%"=="0" goto :end
call :ReportSuccess
set "app.build.noop.rc=%errorlevel%"
:end
call :CleanupFailedRun
exit /b %app.build.noop.rc%
:: ============================================================
:: :LoadConfiguration
:: Loads build_config.bat and then build_config_noop.bat.
::
:: Usage: call :LoadConfiguration
::
:: Returns: 0 when configuration succeeds
::          1 when shared configuration is missing
::          config exit code when a config fails
:: Requires: build_config.bat
:: ============================================================
:LoadConfiguration
set "app.build.noop.shared_config=%app.build.noop.root%\build_config.bat"
set "app.build.noop.suffix_config=%app.build.noop.root%\build_config_noop.bat"
if exist "%app.build.noop.shared_config%" goto :_LoadConfiguration_shared
echo.
echo ERROR: Shared build configuration was not found:
echo   "%app.build.noop.shared_config%"
echo.
exit /b 1
:_LoadConfiguration_shared
call "%app.build.noop.shared_config%"
set "lbc_rc=%errorlevel%"
if "%lbc_rc%"=="0" goto :_LoadConfiguration_suffix
echo.
echo ERROR: Shared build configuration failed:
echo   "%app.build.noop.shared_config%"
echo.
exit /b %lbc_rc%
:_LoadConfiguration_suffix
if not exist "%app.build.noop.suffix_config%" exit /b 0
call "%app.build.noop.suffix_config%"
set "lbc_rc=%errorlevel%"
if "%lbc_rc%"=="0" exit /b 0
echo.
echo ERROR: No-op build configuration failed:
echo   "%app.build.noop.suffix_config%"
echo.
exit /b %lbc_rc%
:: ============================================================
:: :SetDefaults
:: Applies generic no-op build defaults after configuration loads.
::
:: Usage: call :SetDefaults
::
:: Returns: 0
:: Requires: none
:: ============================================================
:SetDefaults
if not defined app.noop.default_mode set "app.noop.default_mode=%app.default_mode%"
if not defined app.noop.default_mode set "app.noop.default_mode=build"
if not defined app.noop.title set "app.noop.title=%app.display_name% template build"
if not defined app.noop.title set "app.noop.title=No-operation template build"
if not defined app.noop.description set "app.noop.description=No project-specific build operations are configured yet."
if not defined app.noop.build_dir_prefix set "app.noop.build_dir_prefix=build"
if not defined app.noop.source_dir_prefix set "app.noop.source_dir_prefix=source"
if not defined app.noop.oldbuilds_dir set "app.noop.oldbuilds_dir=oldbuilds"
if not defined app.noop.temp_root set "app.noop.temp_root=temp"
set "app.build.noop.archive_dir=%app.build.noop.root%\%app.noop.oldbuilds_dir%"
if not defined app.build.noop.mode set "app.build.noop.mode=%app.noop.default_mode%"
exit /b 0
:: ============================================================
:: :ParseArguments
:: Parses the requested build mode.
::
:: Usage: call :ParseArguments %*
::
:: Accepted modes:
::   build, rebuild, nosync, check, clean, help
::
:: Returns: 0 on success, 2 on an unknown argument
:: Requires: none
:: ============================================================
:ParseArguments
if "%~1"=="" exit /b 0
if /I "%~1"=="build" (set "app.build.noop.mode=build" & shift & goto :ParseArguments)
if /I "%~1"=="rebuild" (set "app.build.noop.mode=rebuild" & shift & goto :ParseArguments)
if /I "%~1"=="nosync" (set "app.build.noop.mode=nosync" & shift & goto :ParseArguments)
if /I "%~1"=="check" (set "app.build.noop.mode=check" & shift & goto :ParseArguments)
if /I "%~1"=="clean" (set "app.build.noop.mode=clean" & shift & goto :ParseArguments)
if /I "%~1"=="help" (set "app.build.noop.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="--help" (set "app.build.noop.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="/help" (set "app.build.noop.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="/?" (set "app.build.noop.mode=help" & shift & goto :ParseArguments)
echo ERROR: Unknown build_noop argument:
echo   %~1
exit /b 2
:: ============================================================
:: :ShowHeader
:: Prints the selected project, suffix, and mode.
::
:: Usage: call :ShowHeader
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHeader
echo.
echo ============================================================
echo  %app.noop.title%
echo ============================================================
echo.
echo Project root:
echo   %app.build.noop.root%
echo.
echo Suffix:
echo   noop
echo.
echo Mode:
echo   %app.build.noop.mode%
echo.
exit /b 0
:: ============================================================
:: :ShowHelp
:: Prints template usage, output layout, and customization points.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo build_noop.bat
echo.
echo Usage:
echo   build_noop.bat
echo   build_noop.bat build
echo   build_noop.bat rebuild
echo   build_noop.bat nosync
echo   build_noop.bat check
echo   build_noop.bat clean
echo   build_noop.bat help
echo.
echo Output:
echo   %app.noop.build_dir_prefix%_YYYY-MM-DD.HHhmm.ss\
echo   %app.noop.source_dir_prefix%_YYYY-MM-DD.HHhmm.ss\
echo   %app.noop.oldbuilds_dir%\
echo.
echo Customize these documented functions:
echo   :CheckBuildPrerequisites
echo   :BuildOperations
echo   :ValidateBuildOutputs
echo.
echo Build commands should write only into:
echo   app.build.noop.work_build_dir
echo.
echo The source snapshot is created only after build operations and
echo validation succeed. Final dated folders are promoted only after
echo the complete operation succeeds.
echo.
exit /b 0
:: ============================================================
:: :CheckOnly
:: Checks snapshot support and project-specific prerequisites
:: without creating build, source, or archive folders.
::
:: Usage: call :CheckOnly
::
:: Returns: 0 when ready, nonzero on failure
:: Requires: :CheckGenericPrerequisites, :CheckBuildPrerequisites
:: ============================================================
:CheckOnly
call :CheckGenericPrerequisites
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
call :CheckBuildPrerequisites
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
echo Snapshot mode:
echo   %app.build.noop.snapshot_mode%
echo.
echo Configuration check complete.
echo %app.noop.description%
echo.
exit /b 0
:: ============================================================
:: :CheckGenericPrerequisites
:: Checks PowerShell and determines how the source snapshot will
:: be created. Git-aware mode is preferred in a Git worktree.
::
:: Usage: call :CheckGenericPrerequisites
::
:: Output:
::   app.build.noop.snapshot_mode
::   app.build.noop.git
::
:: Returns: 0 when generic requirements are ready, 1 otherwise
:: Requires: where.exe, PowerShell, optional Git and Robocopy
:: ============================================================
:CheckGenericPrerequisites
where powershell.exe >nul 2>nul
if not errorlevel 1 goto :_CheckGenericPrerequisites_snapshot
echo ERROR: PowerShell is required to create dated timestamps and snapshots.
exit /b 1
:_CheckGenericPrerequisites_snapshot
call :DetectSnapshotMode
set "cgp_rc=%errorlevel%"
if not "%cgp_rc%"=="0" exit /b %cgp_rc%
if /I not "%app.build.noop.snapshot_mode%"=="filesystem" exit /b 0
where robocopy.exe >nul 2>nul
if not errorlevel 1 exit /b 0
echo ERROR: Robocopy is required for non-Git source snapshots.
exit /b 1
:: ============================================================
:: :DetectSnapshotMode
:: Selects Git-aware snapshotting inside a Git worktree and
:: filesystem snapshotting otherwise.
::
:: Usage: call :DetectSnapshotMode
::
:: Output:
::   app.build.noop.snapshot_mode=git|filesystem
::   app.build.noop.git
::
:: Returns: 0
:: Requires: optional git.exe
:: ============================================================
:DetectSnapshotMode
set "app.build.noop.snapshot_mode=filesystem"
set "app.build.noop.git="
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined app.build.noop.git set "app.build.noop.git=%%~fG"
if not defined app.build.noop.git exit /b 0
set "dsm_inside="
for /f "delims=" %%G in ('git.exe rev-parse --is-inside-work-tree 2^>nul') do if not defined dsm_inside set "dsm_inside=%%G"
if /I "%dsm_inside%"=="true" set "app.build.noop.snapshot_mode=git"
exit /b 0
:: ============================================================
:: :CheckBuildPrerequisites
:: TEMPLATE CUSTOMIZATION POINT.
::
:: Add project-specific checks here before any dated folders are
:: created. Examples include checking a compiler, SDK, source file,
:: manifest, resource directory, or packaging tool.
::
:: Usage: call :CheckBuildPrerequisites
::
:: Returns: 0 when project-specific requirements are ready
::          nonzero to stop the build
:: Requires: project-specific tools when customized
:: ============================================================
:CheckBuildPrerequisites
:: Example:
:: where compiler.exe >nul 2>nul
:: if errorlevel 1 (echo ERROR: compiler.exe was not found. & exit /b 1)
exit /b 0
:: ============================================================
:: :PrepareRun
:: Creates the timestamp and all final/work folder paths.
::
:: Usage: call :PrepareRun
::
:: Output:
::   app.build.noop.timestamp
::   app.build.noop.final_build_dir
::   app.build.noop.final_source_dir
::   app.build.noop.work_build_dir
::   app.build.noop.work_source_dir
::
:: Returns: 0 on success, 1 on timestamp or path collision failure
:: Requires: PowerShell
:: ============================================================
:PrepareRun
set "app.build.noop.timestamp="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Date).ToString('yyyy-MM-dd.HH''h''mm.ss')"`) do if not defined app.build.noop.timestamp set "app.build.noop.timestamp=%%A"
if defined app.build.noop.timestamp goto :_PrepareRun_paths
echo ERROR: Could not create a build timestamp.
exit /b 1
:_PrepareRun_paths
set "app.build.noop.final_build_dir=%app.build.noop.root%\%app.noop.build_dir_prefix%_%app.build.noop.timestamp%"
set "app.build.noop.final_source_dir=%app.build.noop.root%\%app.noop.source_dir_prefix%_%app.build.noop.timestamp%"
set "app.build.noop.work_build_dir=%app.build.noop.root%\%app.noop.temp_root%\%app.noop.build_dir_prefix%_noop_work_%app.build.noop.timestamp%_%RANDOM%"
set "app.build.noop.work_source_dir=%app.build.noop.root%\%app.noop.temp_root%\%app.noop.source_dir_prefix%_noop_work_%app.build.noop.timestamp%_%RANDOM%"
if exist "%app.build.noop.final_build_dir%\" goto :_PrepareRun_collision
if exist "%app.build.noop.final_source_dir%\" goto :_PrepareRun_collision
exit /b 0
:_PrepareRun_collision
echo ERROR: A dated output folder already exists for this timestamp.
echo   "%app.build.noop.timestamp%"
exit /b 1
:: ============================================================
:: :PrepareWorkFolders
:: Creates clean temporary build and source folders. Nothing is
:: visible as final build_*/source_* output until promotion.
::
:: Usage: call :PrepareWorkFolders
::
:: Returns: 0 on success, 1 on folder creation failure
:: Requires: app.build.noop.work_build_dir, work_source_dir
:: ============================================================
:PrepareWorkFolders
if not exist "%app.build.noop.root%\%app.noop.temp_root%\" mkdir "%app.build.noop.root%\%app.noop.temp_root%" >nul 2>nul
if not exist "%app.build.noop.root%\%app.noop.temp_root%\" goto :_PrepareWorkFolders_fail
if exist "%app.build.noop.work_build_dir%\" rmdir /S /Q "%app.build.noop.work_build_dir%" >nul 2>nul
if exist "%app.build.noop.work_source_dir%\" rmdir /S /Q "%app.build.noop.work_source_dir%" >nul 2>nul
mkdir "%app.build.noop.work_build_dir%" >nul 2>nul
mkdir "%app.build.noop.work_source_dir%" >nul 2>nul
if not exist "%app.build.noop.work_build_dir%\" goto :_PrepareWorkFolders_fail
if not exist "%app.build.noop.work_source_dir%\" goto :_PrepareWorkFolders_fail
echo Build workspace:
echo   %app.build.noop.work_build_dir%
echo.
exit /b 0
:_PrepareWorkFolders_fail
echo ERROR: Could not create temporary build work folders.
exit /b 1
:: ============================================================
:: :BuildOperations
:: TEMPLATE CUSTOMIZATION POINT.
::
:: Put the real build commands here. This function is called after
:: temporary folders exist and before the source snapshot is made.
::
:: Write all build products beneath:
::   %app.build.noop.work_build_dir%
::
:: Read project input from:
::   %app.build.noop.root%
::
:: Keep final build_*/source_* folder creation out of this function;
:: promotion and archival are handled by the shared lifecycle.
::
:: Usage: call :BuildOperations
::
:: Returns: 0 when build operations succeed
::          nonzero to stop and remove temporary work folders
:: Requires: project-specific tools when customized
:: ============================================================
:BuildOperations
echo Build operations:
echo   No compiler or packager is configured.
echo   Customize the :BuildOperations function in build_noop.bat.
echo.
:: Example:
:: compiler.exe -o "%app.build.noop.work_build_dir%\program.exe" source.c
:: if errorlevel 1 exit /b 1
exit /b 0
:: ============================================================
:: :ValidateBuildOutputs
:: TEMPLATE CUSTOMIZATION POINT.
::
:: Validate required artifacts here after :BuildOperations. Final
:: dated folders are not promoted unless this function succeeds.
::
:: Usage: call :ValidateBuildOutputs
::
:: Returns: 0 when outputs are valid
::          nonzero when expected output is missing or invalid
:: Requires: project-specific outputs when customized
:: ============================================================
:ValidateBuildOutputs
:: Example:
:: if not exist "%app.build.noop.work_build_dir%\program.exe" (
::   echo ERROR: Expected program.exe was not produced.
::   exit /b 1
:: )
exit /b 0
:: ============================================================
:: :CreateSourceSnapshot
:: Creates the current source snapshot using the selected strategy.
::
:: Usage: call :CreateSourceSnapshot
::
:: Returns: snapshot function exit code
:: Requires: :CreateGitSnapshot or :CreateFilesystemSnapshot
:: ============================================================
:CreateSourceSnapshot
echo Creating source snapshot:
echo   %app.build.noop.work_source_dir%
echo.
if /I not "%app.build.noop.snapshot_mode%"=="git" goto :_CreateSourceSnapshot_filesystem
call :CreateGitSnapshot
set "css_rc=%errorlevel%"
exit /b %css_rc%
:_CreateSourceSnapshot_filesystem
call :CreateFilesystemSnapshot
set "css_rc=%errorlevel%"
exit /b %css_rc%
:: ============================================================
:: :CreateGitSnapshot
:: Copies Git tracked files plus untracked, nonignored files while
:: preserving relative paths. Generated lifecycle folders are
:: excluded even if .gitignore does not contain them.
::
:: Usage: call :CreateGitSnapshot
::
:: Returns: 0 on success, 1 on snapshot failure
:: Requires: PowerShell, Git
:: ============================================================
:CreateGitSnapshot
set "NOOP_SNAPSHOT_ROOT=%app.build.noop.root%"
set "NOOP_SNAPSHOT_DEST=%app.build.noop.work_source_dir%"
set "NOOP_SNAPSHOT_GIT=%app.build.noop.git%"
set "NOOP_BUILD_PREFIX=%app.noop.build_dir_prefix%"
set "NOOP_SOURCE_PREFIX=%app.noop.source_dir_prefix%"
set "NOOP_OLDBUILDS=%app.noop.oldbuilds_dir%"
set "NOOP_TEMP_ROOT=%app.noop.temp_root%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root=[IO.Path]::GetFullPath($env:NOOP_SNAPSHOT_ROOT); $dest=[IO.Path]::GetFullPath($env:NOOP_SNAPSHOT_DEST); $git=$env:NOOP_SNAPSHOT_GIT; $bp=$env:NOOP_BUILD_PREFIX+'_'; $sp=$env:NOOP_SOURCE_PREFIX+'_'; $old=$env:NOOP_OLDBUILDS; $tmp=$env:NOOP_TEMP_ROOT; $files=& $git -C $root -c core.quotepath=false ls-files --cached --others --exclude-standard; if($LASTEXITCODE -ne 0){exit 2}; foreach($item in $files){if([string]::IsNullOrWhiteSpace($item)){continue}; $rel=$item.Replace('/','\'); $first=($rel -split '\\',2)[0]; if($first -ieq '.git' -or $first -ieq $old -or $first -ieq $tmp -or $first.StartsWith($bp,[StringComparison]::OrdinalIgnoreCase) -or $first.StartsWith($sp,[StringComparison]::OrdinalIgnoreCase)){continue}; $src=Join-Path $root $rel; if(-not (Test-Path -LiteralPath $src -PathType Leaf)){continue}; $out=Join-Path $dest $rel; $parent=Split-Path -Parent $out; if(-not (Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Force -Path $parent | Out-Null}; Copy-Item -LiteralPath $src -Destination $out -Force}; exit 0"
set "cgs_rc=%errorlevel%"
set "NOOP_SNAPSHOT_ROOT="
set "NOOP_SNAPSHOT_DEST="
set "NOOP_SNAPSHOT_GIT="
set "NOOP_BUILD_PREFIX="
set "NOOP_SOURCE_PREFIX="
set "NOOP_OLDBUILDS="
set "NOOP_TEMP_ROOT="
if "%cgs_rc%"=="0" exit /b 0
echo ERROR: Git-aware source snapshot failed with exit code %cgs_rc%.
exit /b 1
:: ============================================================
:: :CreateFilesystemSnapshot
:: Copies the project tree when the root is not a Git worktree.
:: This fallback excludes lifecycle-generated folders but cannot
:: interpret source-control ignore files.
::
:: Usage: call :CreateFilesystemSnapshot
::
:: Returns: 0 for Robocopy codes 0-7, 1 for codes 8 and higher
:: Requires: Robocopy
:: ============================================================
:CreateFilesystemSnapshot
echo WARNING: No Git worktree was detected.
echo The fallback snapshot excludes generated lifecycle folders,
echo but does not interpret source-control ignore files.
echo.
robocopy "%app.build.noop.root%" "%app.build.noop.work_source_dir%" /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XD "%app.build.noop.root%\.git" "%app.build.noop.root%\%app.noop.oldbuilds_dir%" "%app.build.noop.root%\%app.noop.temp_root%" "%app.build.noop.root%\%app.noop.build_dir_prefix%_*" "%app.build.noop.root%\%app.noop.source_dir_prefix%_*" >nul
set "cfs_rc=%errorlevel%"
if %cfs_rc% LSS 8 exit /b 0
echo ERROR: Filesystem source snapshot failed with Robocopy code %cfs_rc%.
exit /b 1
:: ============================================================
:: :PromoteSuccessfulBuild
:: Moves temporary build/source folders to their final dated names.
::
:: Usage: call :PromoteSuccessfulBuild
::
:: Returns: 0 on success, 1 on move failure
:: Requires: move
:: ============================================================
:PromoteSuccessfulBuild
echo Promoting successful build:
echo   %app.build.noop.final_build_dir%
echo   %app.build.noop.final_source_dir%
echo.
move "%app.build.noop.work_build_dir%" "%app.build.noop.final_build_dir%" >nul
set "psb_rc=%errorlevel%"
if not "%psb_rc%"=="0" goto :_PromoteSuccessfulBuild_fail_build
set "app.build.noop.created_final_build=1"
move "%app.build.noop.work_source_dir%" "%app.build.noop.final_source_dir%" >nul
set "psb_rc=%errorlevel%"
if not "%psb_rc%"=="0" goto :_PromoteSuccessfulBuild_fail_source
set "app.build.noop.created_final_source=1"
set "app.build.noop.build_complete=1"
exit /b 0
:_PromoteSuccessfulBuild_fail_build
echo ERROR: Could not promote the temporary build folder.
exit /b 1
:_PromoteSuccessfulBuild_fail_source
echo ERROR: Could not promote the temporary source folder.
exit /b 1
:: ============================================================
:: :ArchiveOlderFolders
:: Moves older final build_* and source_* folders into oldbuilds.
:: The folders created by the current successful run are retained.
::
:: Usage: call :ArchiveOlderFolders
::
:: Returns: 0 when all older folders are archived, 1 otherwise
:: Requires: :ArchiveOneFolder
:: ============================================================
:ArchiveOlderFolders
set "app.build.noop.archive_failed="
if not exist "%app.build.noop.archive_dir%\" mkdir "%app.build.noop.archive_dir%" >nul 2>nul
if exist "%app.build.noop.archive_dir%\" goto :_ArchiveOlderFolders_scan
echo ERROR: Could not create archive folder:
echo   "%app.build.noop.archive_dir%"
exit /b 1
:_ArchiveOlderFolders_scan
for /D %%D in ("%app.build.noop.root%\%app.noop.build_dir_prefix%_*") do call :ArchiveOneFolder "%%~fD"
for /D %%D in ("%app.build.noop.root%\%app.noop.source_dir_prefix%_*") do call :ArchiveOneFolder "%%~fD"
if defined app.build.noop.archive_failed exit /b 1
exit /b 0
:: ============================================================
:: :ArchiveOneFolder
:: Moves one older dated output folder into oldbuilds without
:: overwriting an existing archive folder of the same name.
::
:: Usage: call :ArchiveOneFolder "full folder path"
::
:: Returns: 0; records failure in app.build.noop.archive_failed
:: Requires: move
:: ============================================================
:ArchiveOneFolder
set "aof_source=%~1"
if not defined aof_source exit /b 0
if /I "%aof_source%"=="%app.build.noop.final_build_dir%" exit /b 0
if /I "%aof_source%"=="%app.build.noop.final_source_dir%" exit /b 0
for %%A in ("%aof_source%") do set "aof_name=%%~nxA"
set "aof_target=%app.build.noop.archive_dir%\%aof_name%"
if exist "%aof_target%\" set "aof_target=%app.build.noop.archive_dir%\%aof_name%.moved_%app.build.noop.timestamp%_%RANDOM%"
move "%aof_source%" "%aof_target%" >nul 2>nul
set "aof_rc=%errorlevel%"
if "%aof_rc%"=="0" exit /b 0
echo ERROR: Could not archive:
echo   "%aof_source%"
set "app.build.noop.archive_failed=1"
exit /b 0
:: ============================================================
:: :Clean
:: Moves all current dated build/source folders into oldbuilds.
:: It does not delete archived builds.
::
:: Usage: call :Clean
::
:: Returns: archive workflow exit code
:: Requires: :CreateTimestamp, :ArchiveOlderFolders
:: ============================================================
:Clean
call :CreateTimestamp
set "clean_rc=%errorlevel%"
if not "%clean_rc%"=="0" exit /b %clean_rc%
set "app.build.noop.final_build_dir="
set "app.build.noop.final_source_dir="
call :ArchiveOlderFolders
set "clean_rc=%errorlevel%"
if not "%clean_rc%"=="0" exit /b %clean_rc%
echo Clean complete.
echo Current dated build and source folders were moved to:
echo   %app.build.noop.archive_dir%
echo.
exit /b 0
:: ============================================================
:: :CreateTimestamp
:: Creates app.build.noop.timestamp without preparing a build run.
::
:: Usage: call :CreateTimestamp
::
:: Returns: 0 on success, 1 on failure
:: Requires: PowerShell
:: ============================================================
:CreateTimestamp
set "app.build.noop.timestamp="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Date).ToString('yyyy-MM-dd.HH''h''mm.ss')"`) do if not defined app.build.noop.timestamp set "app.build.noop.timestamp=%%A"
if defined app.build.noop.timestamp exit /b 0
echo ERROR: Could not create a timestamp.
exit /b 1
:: ============================================================
:: :ReportSuccess
:: Prints final output paths after promotion and archival.
::
:: Usage: call :ReportSuccess
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ReportSuccess
echo ============================================================
echo  Build complete
echo ============================================================
echo.
echo Build folder:
echo   %app.build.noop.final_build_dir%
echo.
echo Source snapshot:
echo   %app.build.noop.final_source_dir%
echo.
echo Older builds:
echo   %app.build.noop.archive_dir%
echo.
echo %app.noop.description%
if /I "%app.build.noop.mode%"=="nosync" echo No commit or push was performed.
echo.
exit /b 0
:: ============================================================
:: :CleanupFailedRun
:: Removes temporary work folders. If promotion failed halfway,
:: removes final folders created by this incomplete run. A complete
:: build remains intact even when later archival reports a failure.
::
:: Usage: call :CleanupFailedRun
::
:: Returns: 0
:: Requires: rmdir
:: ============================================================
:CleanupFailedRun
if defined app.build.noop.work_build_dir if exist "%app.build.noop.work_build_dir%\" rmdir /S /Q "%app.build.noop.work_build_dir%" >nul 2>nul
if defined app.build.noop.work_source_dir if exist "%app.build.noop.work_source_dir%\" rmdir /S /Q "%app.build.noop.work_source_dir%" >nul 2>nul
if defined app.build.noop.build_complete goto :_CleanupFailedRun_temp
if defined app.build.noop.created_final_build if exist "%app.build.noop.final_build_dir%\" rmdir /S /Q "%app.build.noop.final_build_dir%" >nul 2>nul
if defined app.build.noop.created_final_source if exist "%app.build.noop.final_source_dir%\" rmdir /S /Q "%app.build.noop.final_source_dir%" >nul 2>nul
:_CleanupFailedRun_temp
if defined app.noop.temp_root rmdir "%app.build.noop.root%\%app.noop.temp_root%" >nul 2>nul
exit /b 0
