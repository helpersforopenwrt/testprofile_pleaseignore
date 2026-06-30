@echo off
:: ============================================================
:: build_web.bat
:: Generic builder for framework-free websites.
::
:: Intended projects:
::   - plain HTML, CSS, and JavaScript websites
::   - small PHP websites
::   - websites containing images, fonts, JSON, media, .htaccess,
::     shell deployment helpers, and other directly served files
::
:: This builder deliberately does not assume npm, Composer, a bundler,
:: a static-site generator, or a framework. More specialized suffixes
:: can add those workflows later.
::
:: Build lifecycle:
::   1. load build_config.bat
::   2. load optional build_config_web.bat
::   3. check the website and local tools
::   4. create temporary build/source work folders
::   5. copy deployable website files into the build workspace
::   6. optionally lint copied PHP files
::   7. validate the website package
::   8. create a Git-aware source snapshot
::   9. promote successful work folders to dated final folders
::  10. move older dated folders into oldbuilds
::
:: Final layout:
::   build_YYYY-MM-DD.HHhmm.ss\
::   source_YYYY-MM-DD.HHhmm.ss\
::   oldbuilds\
::
:: The build folder contains deployable website files directly at its
:: root. The source folder contains the complete current project source
:: except ignored/generated lifecycle folders.
::
:: Git worktree behavior:
::   - tracked files are included
::   - untracked, nonignored files are included
::   - ignored files are excluded
::
:: Filesystem fallback:
::   Outside a Git worktree, files are discovered recursively.
::   Source-control ignore files cannot be interpreted in this mode.
::
:: Configuration order:
::   1. build_config.bat
::   2. build_config_web.bat when present
::
:: Primary configuration:
::   app.web.default_mode=build
::   app.web.entry_file=index.php
::   app.web.require_entry=1
::   app.web.php_lint=auto
::   app.web.build_dir_prefix=build
::   app.web.source_dir_prefix=source
::   app.web.oldbuilds_dir=oldbuilds
::   app.web.temp_root=temp
::   app.web.deploy.exclude_dirs=semicolon-separated names
::   app.web.deploy.exclude_files=semicolon-separated wildcard patterns
::
:: php_lint values:
::   auto      lint PHP when php.exe is available; otherwise warn
::   required  fail when PHP files exist and php.exe is unavailable
::   off       never run PHP syntax checks
::
:: Active placement:
::   build_web.bat at the project root
::
:: Template storage:
::   tools\templates\build\build_web.bat
::
:: Usage:
::   call build_web.bat [build|rebuild|nosync|check|clean|help]
::
:: Returns: 0 on success
::          1 on setup, copy, lint, validation, promotion, or archive failure
::          2 on an invalid command-line argument
::          config exit code when configuration fails
:: Requires: PowerShell
::           Git for Git-aware file selection
:: ============================================================
:setup
set "app.build.web.rc=0"
set "app.build.web.root="
set "app.build.web.shared_config="
set "app.build.web.suffix_config="
set "app.build.web.mode="
set "app.build.web.timestamp="
set "app.build.web.snapshot_mode="
set "app.build.web.git="
set "app.build.web.php="
set "app.build.web.php_count=0"
set "app.build.web.php_failed="
set "app.build.web.php_lint_log="
set "app.build.web.final_build_dir="
set "app.build.web.final_source_dir="
set "app.build.web.work_build_dir="
set "app.build.web.work_source_dir="
set "app.build.web.archive_dir="
set "app.build.web.archive_failed="
set "app.build.web.created_final_build="
set "app.build.web.created_final_source="
set "app.build.web.build_complete="
set "app.build.web.file_count=0"
set "app.build.web.total_bytes=0"
set "app.build.suffix=web"
if not defined BUILD_SUFFIX set "BUILD_SUFFIX=web"
if defined BUILD_PROJECT_ROOT set "app.build.web.root=%BUILD_PROJECT_ROOT%"
if not defined app.build.web.root for %%A in ("%~dp0.") do set "app.build.web.root=%%~fA"
for %%A in ("%app.build.web.root%\.") do set "app.build.web.root=%%~fA"
:main
call :LoadConfiguration
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
call :SetDefaults
call :ParseArguments %*
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
cd /d "%app.build.web.root%"
set "app.build.web.rc=%errorlevel%"
if "%app.build.web.rc%"=="0" goto :_main_dispatch
echo.
echo ERROR: Could not enter the project root:
echo   "%app.build.web.root%"
echo.
set "app.build.web.rc=1"
goto :end
:_main_dispatch
if /I "%app.build.web.mode%"=="help" call :ShowHelp
if /I "%app.build.web.mode%"=="help" set "app.build.web.rc=%errorlevel%"
if /I "%app.build.web.mode%"=="help" goto :end
call :ShowHeader
if /I "%app.build.web.mode%"=="check" call :CheckOnly
if /I "%app.build.web.mode%"=="check" set "app.build.web.rc=%errorlevel%"
if /I "%app.build.web.mode%"=="check" goto :end
if /I "%app.build.web.mode%"=="clean" call :Clean
if /I "%app.build.web.mode%"=="clean" set "app.build.web.rc=%errorlevel%"
if /I "%app.build.web.mode%"=="clean" goto :end
call :CheckGenericPrerequisites
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
call :CheckWebsitePrerequisites
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
call :PrepareRun
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
call :PrepareWorkFolders
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
call :CreateWebsitePackage
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
call :ValidateWebsitePackage
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
call :CreateSourceSnapshot
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
call :PromoteSuccessfulBuild
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
call :ArchiveOlderFolders
set "app.build.web.rc=%errorlevel%"
if not "%app.build.web.rc%"=="0" goto :end
call :ReportSuccess
set "app.build.web.rc=%errorlevel%"
:end
call :CleanupRun
exit /b %app.build.web.rc%
:: ============================================================
:: :LoadConfiguration
:: Loads build_config.bat and then optional build_config_web.bat.
::
:: Usage: call :LoadConfiguration
::
:: Returns: 0 when configuration succeeds
::          1 when shared configuration is missing
::          config exit code when a config fails
:: Requires: build_config.bat
:: ============================================================
:LoadConfiguration
set "app.build.web.shared_config=%app.build.web.root%\build_config.bat"
set "app.build.web.suffix_config=%app.build.web.root%\build_config_web.bat"
if exist "%app.build.web.shared_config%" goto :_LoadConfiguration_shared
echo.
echo ERROR: Shared build configuration was not found:
echo   "%app.build.web.shared_config%"
echo.
exit /b 1
:_LoadConfiguration_shared
call "%app.build.web.shared_config%"
set "lc_rc=%errorlevel%"
if "%lc_rc%"=="0" goto :_LoadConfiguration_suffix
echo.
echo ERROR: Shared build configuration failed:
echo   "%app.build.web.shared_config%"
echo.
exit /b %lc_rc%
:_LoadConfiguration_suffix
if not exist "%app.build.web.suffix_config%" exit /b 0
call "%app.build.web.suffix_config%"
set "lc_rc=%errorlevel%"
if "%lc_rc%"=="0" exit /b 0
echo.
echo ERROR: Web build configuration failed:
echo   "%app.build.web.suffix_config%"
echo.
exit /b %lc_rc%
:: ============================================================
:: :SetDefaults
:: Applies framework-free website defaults after configuration.
::
:: Usage: call :SetDefaults
::
:: Returns: 0
:: Requires: none
:: ============================================================
:SetDefaults
if not defined app.web.default_mode set "app.web.default_mode=%app.default_mode%"
if not defined app.web.default_mode set "app.web.default_mode=build"
if not defined app.build.web.mode set "app.build.web.mode=%app.web.default_mode%"
if not defined app.web.title set "app.web.title=%app.display_name% website build"
if not defined app.web.title set "app.web.title=Website build"
if not defined app.web.description set "app.web.description=Framework-free website package."
if not defined app.web.build_dir_prefix set "app.web.build_dir_prefix=%app.build_dir_prefix%"
if not defined app.web.build_dir_prefix set "app.web.build_dir_prefix=build"
if not defined app.web.source_dir_prefix set "app.web.source_dir_prefix=%app.source_dir_prefix%"
if not defined app.web.source_dir_prefix set "app.web.source_dir_prefix=source"
if not defined app.web.oldbuilds_dir set "app.web.oldbuilds_dir=%app.oldbuilds_dir%"
if not defined app.web.oldbuilds_dir set "app.web.oldbuilds_dir=oldbuilds"
if not defined app.web.temp_root set "app.web.temp_root=%app.temp_root%"
if not defined app.web.temp_root set "app.web.temp_root=temp"
if not defined app.web.require_entry set "app.web.require_entry=1"
if not defined app.web.php_lint set "app.web.php_lint=auto"
if not defined app.web.deploy.exclude_dirs set "app.web.deploy.exclude_dirs=.git;tools;%app.web.oldbuilds_dir%;%app.web.temp_root%;.github;.idea;.vscode;node_modules"
if not defined app.web.deploy.exclude_files set "app.web.deploy.exclude_files=build.bat;build_*.bat;build_config*.bat;prepare.bat;prepare_*.bat;install.bat;install_*.bat;just_*.bat;README*;.gitignore;.gitattributes;.env;.env.local;.env.production"
if not defined app.web.entry_file if exist "%app.build.web.root%\index.php" set "app.web.entry_file=index.php"
if not defined app.web.entry_file if exist "%app.build.web.root%\index.html" set "app.web.entry_file=index.html"
if not defined app.web.entry_file if exist "%app.build.web.root%\index.htm" set "app.web.entry_file=index.htm"
set "app.build.web.archive_dir=%app.build.web.root%\%app.web.oldbuilds_dir%"
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
if /I "%~1"=="build" (set "app.build.web.mode=build" & shift & goto :ParseArguments)
if /I "%~1"=="rebuild" (set "app.build.web.mode=rebuild" & shift & goto :ParseArguments)
if /I "%~1"=="nosync" (set "app.build.web.mode=nosync" & shift & goto :ParseArguments)
if /I "%~1"=="check" (set "app.build.web.mode=check" & shift & goto :ParseArguments)
if /I "%~1"=="clean" (set "app.build.web.mode=clean" & shift & goto :ParseArguments)
if /I "%~1"=="help" (set "app.build.web.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="--help" (set "app.build.web.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="/help" (set "app.build.web.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="/?" (set "app.build.web.mode=help" & shift & goto :ParseArguments)
echo.
echo ERROR: Unknown build_web argument:
echo   %~1
echo.
exit /b 2
:: ============================================================
:: :ShowHeader
:: Prints the selected website build request.
::
:: Usage: call :ShowHeader
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHeader
echo.
echo ============================================================
echo  %app.web.title%
echo ============================================================
echo.
echo Project root:
echo   %app.build.web.root%
echo.
echo Suffix:
echo   web
echo.
echo Mode:
echo   %app.build.web.mode%
echo.
echo Entry file:
if defined app.web.entry_file echo   %app.web.entry_file%
if not defined app.web.entry_file echo   not detected
echo.
exit /b 0
:: ============================================================
:: :ShowHelp
:: Prints usage, defaults, and website package behavior.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo build_web.bat
echo.
echo Usage:
echo   build_web.bat
echo   build_web.bat build
echo   build_web.bat rebuild
echo   build_web.bat nosync
echo   build_web.bat check
echo   build_web.bat clean
echo   build_web.bat help
echo.
echo Output:
echo   %app.web.build_dir_prefix%_YYYY-MM-DD.HHhmm.ss\
echo   %app.web.source_dir_prefix%_YYYY-MM-DD.HHhmm.ss\
echo   %app.web.oldbuilds_dir%\
echo.
echo Website entry:
echo   app.web.entry_file=%app.web.entry_file%
echo   app.web.require_entry=%app.web.require_entry%
echo.
echo PHP syntax checking:
echo   app.web.php_lint=%app.web.php_lint%
echo   auto, required, or off
echo.
echo Deployment exclusions:
echo   Directories:
echo     %app.web.deploy.exclude_dirs%
echo   Files:
echo     %app.web.deploy.exclude_files%
echo.
echo The build package copies deployable project files while excluding
echo project helpers, build configuration, Git metadata, editor folders,
echo node_modules, secrets such as .env, and generated lifecycle folders.
echo.
echo Customize build_config_web.bat for project-specific entry files,
echo exclusions, PHP lint policy, and dated output folder names.
echo.
exit /b 0
:: ============================================================
:: :CheckGenericPrerequisites
:: Verifies PowerShell and selects Git-aware or filesystem discovery.
::
:: Usage: call :CheckGenericPrerequisites
::
:: Output:
::   app.build.web.snapshot_mode
::   app.build.web.git
::
:: Returns: 0 when ready, 1 otherwise
:: Requires: where.exe, PowerShell, optional Git
:: ============================================================
:CheckGenericPrerequisites
where powershell.exe >nul 2>nul
if not errorlevel 1 goto :_CheckGenericPrerequisites_mode
echo ERROR: PowerShell is required for timestamps and file copying.
exit /b 1
:_CheckGenericPrerequisites_mode
call :DetectSnapshotMode
exit /b %errorlevel%
:: ============================================================
:: :DetectSnapshotMode
:: Selects Git-aware discovery inside a Git worktree.
::
:: Usage: call :DetectSnapshotMode
::
:: Output:
::   app.build.web.snapshot_mode=git|filesystem
::   app.build.web.git
::
:: Returns: 0
:: Requires: optional git.exe
:: ============================================================
:DetectSnapshotMode
set "app.build.web.snapshot_mode=filesystem"
set "app.build.web.git="
for /f "delims=" %%G in ('where git.exe 2^>nul') do if not defined app.build.web.git set "app.build.web.git=%%~fG"
if not defined app.build.web.git exit /b 0
set "dsm_inside="
for /f "delims=" %%G in ('git.exe rev-parse --is-inside-work-tree 2^>nul') do if not defined dsm_inside set "dsm_inside=%%G"
if /I "%dsm_inside%"=="true" set "app.build.web.snapshot_mode=git"
exit /b 0
:: ============================================================
:: :CheckWebsitePrerequisites
:: Verifies the configured entry file policy and php_lint value.
::
:: Usage: call :CheckWebsitePrerequisites
::
:: Returns: 0 when acceptable, 1 on missing entry, 2 on bad config
:: Requires: none
:: ============================================================
:CheckWebsitePrerequisites
if /I "%app.web.php_lint%"=="auto" goto :_CheckWebsitePrerequisites_entry
if /I "%app.web.php_lint%"=="required" goto :_CheckWebsitePrerequisites_entry
if /I "%app.web.php_lint%"=="off" goto :_CheckWebsitePrerequisites_entry
echo ERROR: app.web.php_lint must be auto, required, or off.
exit /b 2
:_CheckWebsitePrerequisites_entry
if not "%app.web.require_entry%"=="1" exit /b 0
if defined app.web.entry_file if exist "%app.build.web.root%\%app.web.entry_file%" exit /b 0
echo ERROR: Required website entry file was not found.
if defined app.web.entry_file echo   "%app.build.web.root%\%app.web.entry_file%"
if not defined app.web.entry_file echo   Configure app.web.entry_file in build_config_web.bat.
exit /b 1
:: ============================================================
:: :CheckOnly
:: Builds and validates a temporary website package without creating
:: final dated output or a source snapshot.
::
:: Usage: call :CheckOnly
::
:: Returns: first nonzero child result
:: Requires: build package functions
:: ============================================================
:CheckOnly
call :CheckGenericPrerequisites
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
call :CheckWebsitePrerequisites
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
call :PrepareRun
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
call :PrepareWorkFolders
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
call :CreateWebsitePackage
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
call :ValidateWebsitePackage
set "co_rc=%errorlevel%"
if not "%co_rc%"=="0" exit /b %co_rc%
echo Website build check complete.
echo.
echo Discovery mode:
echo   %app.build.web.snapshot_mode%
echo.
echo Deployable files:
echo   %app.build.web.file_count%
echo.
echo PHP files checked:
echo   %app.build.web.php_count%
echo.
exit /b 0
:: ============================================================
:: :PrepareRun
:: Creates the timestamp and final/work folder paths.
::
:: Usage: call :PrepareRun
::
:: Returns: 0 on success, 1 on timestamp or collision failure
:: Requires: PowerShell
:: ============================================================
:PrepareRun
set "app.build.web.timestamp="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Date).ToString('yyyy-MM-dd.HH''h''mm.ss')"`) do if not defined app.build.web.timestamp set "app.build.web.timestamp=%%A"
if defined app.build.web.timestamp goto :_PrepareRun_paths
echo ERROR: Could not create a build timestamp.
exit /b 1
:_PrepareRun_paths
set "app.build.web.final_build_dir=%app.build.web.root%\%app.web.build_dir_prefix%_%app.build.web.timestamp%"
set "app.build.web.final_source_dir=%app.build.web.root%\%app.web.source_dir_prefix%_%app.build.web.timestamp%"
set "app.build.web.work_build_dir=%app.build.web.root%\%app.web.temp_root%\%app.web.build_dir_prefix%_web_work_%app.build.web.timestamp%_%RANDOM%"
set "app.build.web.work_source_dir=%app.build.web.root%\%app.web.temp_root%\%app.web.source_dir_prefix%_web_work_%app.build.web.timestamp%_%RANDOM%"
set "app.build.web.php_lint_log=%app.build.web.root%\%app.web.temp_root%\php-lint.%app.build.web.timestamp%_%RANDOM%.log"
if exist "%app.build.web.final_build_dir%\" goto :_PrepareRun_collision
if exist "%app.build.web.final_source_dir%\" goto :_PrepareRun_collision
exit /b 0
:_PrepareRun_collision
echo ERROR: A dated output folder already exists for this timestamp.
echo   %app.build.web.timestamp%
exit /b 1
:: ============================================================
:: :PrepareWorkFolders
:: Creates clean temporary build and source folders.
::
:: Usage: call :PrepareWorkFolders
::
:: Returns: 0 on success, 1 on folder creation failure
:: Requires: mkdir, rmdir
:: ============================================================
:PrepareWorkFolders
if not exist "%app.build.web.root%\%app.web.temp_root%\" mkdir "%app.build.web.root%\%app.web.temp_root%" >nul 2>nul
if not exist "%app.build.web.root%\%app.web.temp_root%\" goto :_PrepareWorkFolders_fail
if exist "%app.build.web.work_build_dir%\" rmdir /S /Q "%app.build.web.work_build_dir%" >nul 2>nul
if exist "%app.build.web.work_source_dir%\" rmdir /S /Q "%app.build.web.work_source_dir%" >nul 2>nul
mkdir "%app.build.web.work_build_dir%" >nul 2>nul
mkdir "%app.build.web.work_source_dir%" >nul 2>nul
if not exist "%app.build.web.work_build_dir%\" goto :_PrepareWorkFolders_fail
if not exist "%app.build.web.work_source_dir%\" goto :_PrepareWorkFolders_fail
exit /b 0
:_PrepareWorkFolders_fail
echo ERROR: Could not create temporary website work folders.
exit /b 1
:: ============================================================
:: :CreateWebsitePackage
:: Copies deployable files and then runs optional PHP syntax checks.
::
:: Usage: call :CreateWebsitePackage
::
:: Returns: first nonzero child result
:: Requires: :CopyDeployableFiles, :LintWebsitePhp
:: ============================================================
:CreateWebsitePackage
echo Creating deployable website package:
echo   %app.build.web.work_build_dir%
echo.
call :CopyDeployableFiles
set "cwp_rc=%errorlevel%"
if not "%cwp_rc%"=="0" exit /b %cwp_rc%
call :LintWebsitePhp
set "cwp_rc=%errorlevel%"
exit /b %cwp_rc%
:: ============================================================
:: :CopyDeployableFiles
:: Copies Git-selected or filesystem-discovered project files while
:: applying configured deployment exclusions.
::
:: Usage: call :CopyDeployableFiles
::
:: Returns: 0 on success, 1 on copy failure
:: Requires: PowerShell, optional Git
:: ============================================================
:CopyDeployableFiles
set "WEB_COPY_ROOT=%app.build.web.root%"
set "WEB_COPY_DEST=%app.build.web.work_build_dir%"
set "WEB_COPY_MODE=%app.build.web.snapshot_mode%"
set "WEB_COPY_GIT=%app.build.web.git%"
set "WEB_BUILD_PREFIX=%app.web.build_dir_prefix%"
set "WEB_SOURCE_PREFIX=%app.web.source_dir_prefix%"
set "WEB_OLDBUILDS=%app.web.oldbuilds_dir%"
set "WEB_TEMP_ROOT=%app.web.temp_root%"
set "WEB_EXCLUDE_DIRS=%app.web.deploy.exclude_dirs%"
set "WEB_EXCLUDE_FILES=%app.web.deploy.exclude_files%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root=[IO.Path]::GetFullPath($env:WEB_COPY_ROOT); $dest=[IO.Path]::GetFullPath($env:WEB_COPY_DEST); $mode=$env:WEB_COPY_MODE; $git=$env:WEB_COPY_GIT; $bp=$env:WEB_BUILD_PREFIX+'_'; $sp=$env:WEB_SOURCE_PREFIX+'_'; $old=$env:WEB_OLDBUILDS; $tmp=$env:WEB_TEMP_ROOT; $excludeDirs=@($env:WEB_EXCLUDE_DIRS -split ';' | Where-Object {$_}); $excludeFiles=@($env:WEB_EXCLUDE_FILES -split ';' | Where-Object {$_}); if($mode -eq 'git'){ $items=& $git -C $root -c core.quotepath=false ls-files --cached --others --exclude-standard; if($LASTEXITCODE -ne 0){exit 2}; $files=@($items) } else { $files=@(Get-ChildItem -LiteralPath $root -File -Recurse | ForEach-Object {$_.FullName.Substring($root.Length).TrimStart('\','/')}) }; foreach($item in $files){ if([string]::IsNullOrWhiteSpace($item)){continue}; $rel=$item.Replace('/','\'); $parts=@($rel -split '\\'); if($parts.Count -eq 0){continue}; $first=$parts[0]; if($first -ieq '.git' -or $first -ieq $old -or $first -ieq $tmp -or $first.StartsWith($bp,[StringComparison]::OrdinalIgnoreCase) -or $first.StartsWith($sp,[StringComparison]::OrdinalIgnoreCase)){continue}; $skip=$false; foreach($part in $parts[0..([Math]::Max(0,$parts.Count-2))]){ foreach($name in $excludeDirs){ if($part -ieq $name){$skip=$true;break} }; if($skip){break} }; if($skip){continue}; $leaf=$parts[$parts.Count-1]; foreach($pattern in $excludeFiles){ if($leaf -like $pattern -or $rel -like $pattern){$skip=$true;break} }; if($skip){continue}; $src=Join-Path $root $rel; if(-not (Test-Path -LiteralPath $src -PathType Leaf)){continue}; $out=Join-Path $dest $rel; $parent=Split-Path -Parent $out; if(-not (Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Force -Path $parent | Out-Null}; Copy-Item -LiteralPath $src -Destination $out -Force }; exit 0"
set "cdf_rc=%errorlevel%"
set "WEB_COPY_ROOT="
set "WEB_COPY_DEST="
set "WEB_COPY_MODE="
set "WEB_COPY_GIT="
set "WEB_BUILD_PREFIX="
set "WEB_SOURCE_PREFIX="
set "WEB_OLDBUILDS="
set "WEB_TEMP_ROOT="
set "WEB_EXCLUDE_DIRS="
set "WEB_EXCLUDE_FILES="
if "%cdf_rc%"=="0" exit /b 0
echo ERROR: Website package copy failed with exit code %cdf_rc%.
exit /b 1
:: ============================================================
:: :LintWebsitePhp
:: Lints copied PHP files according to app.web.php_lint.
::
:: Usage: call :LintWebsitePhp
::
:: Output:
::   app.build.web.php
::   app.build.web.php_count
::
:: Returns: 0 when lint passes or is skipped, 1 on required/malformed PHP
:: Requires: optional php.exe, :LintOnePhp
:: ============================================================
:LintWebsitePhp
set "app.build.web.php_count=0"
set "app.build.web.php_failed="
set "app.build.web.php="
for /R "%app.build.web.work_build_dir%" %%F in (*.php) do set /a app.build.web.php_count+=1 >nul
if "%app.build.web.php_count%"=="0" exit /b 0
if /I "%app.web.php_lint%"=="off" goto :_LintWebsitePhp_off
for /f "delims=" %%P in ('where php.exe 2^>nul') do if not defined app.build.web.php set "app.build.web.php=%%~fP"
if defined app.build.web.php goto :_LintWebsitePhp_run
if /I "%app.web.php_lint%"=="required" goto :_LintWebsitePhp_required
echo WARNING: %app.build.web.php_count% PHP file(s) were packaged, but php.exe was not found.
echo PHP syntax checking was skipped because app.web.php_lint=auto.
echo.
exit /b 0
:_LintWebsitePhp_required
echo ERROR: PHP files exist, app.web.php_lint=required, and php.exe was not found.
exit /b 1
:_LintWebsitePhp_off
echo PHP syntax checking is disabled.
echo.
exit /b 0
:_LintWebsitePhp_run
if exist "%app.build.web.php_lint_log%" del /Q "%app.build.web.php_lint_log%" >nul 2>nul
echo Checking PHP syntax with:
echo   %app.build.web.php%
echo.
for /R "%app.build.web.work_build_dir%" %%F in (*.php) do call :LintOnePhp "%%~fF"
if not defined app.build.web.php_failed goto :_LintWebsitePhp_ok
echo ERROR: PHP syntax checking failed.
if exist "%app.build.web.php_lint_log%" type "%app.build.web.php_lint_log%"
exit /b 1
:_LintWebsitePhp_ok
echo PHP syntax check complete:
echo   %app.build.web.php_count% file(s)
echo.
exit /b 0
:: ============================================================
:: :LintOnePhp
:: Runs php -l for one copied PHP file and records failures.
::
:: Usage: call :LintOnePhp "full file path"
::
:: Returns: 0; failure is recorded in app.build.web.php_failed
:: Requires: php.exe
:: ============================================================
:LintOnePhp
"%app.build.web.php%" -l "%~1" >>"%app.build.web.php_lint_log%" 2>&1
set "lop_rc=%errorlevel%"
if not "%lop_rc%"=="0" set "app.build.web.php_failed=1"
exit /b 0
:: ============================================================
:: :ValidateWebsitePackage
:: Validates package file count and configured entry file.
::
:: Usage: call :ValidateWebsitePackage
::
:: Output:
::   app.build.web.file_count
::   app.build.web.total_bytes
::
:: Returns: 0 when valid, 1 otherwise
:: Requires: PowerShell
:: ============================================================
:ValidateWebsitePackage
set "WEB_VALIDATE_DIR=%app.build.web.work_build_dir%"
set "app.build.web.file_count=0"
set "app.build.web.total_bytes=0"
for /f "tokens=1,2" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=@(Get-ChildItem -LiteralPath $env:WEB_VALIDATE_DIR -File -Recurse); $bytes=($f | Measure-Object Length -Sum).Sum; if($null -eq $bytes){$bytes=0}; Write-Output ($f.Count.ToString()+' '+$bytes.ToString())"') do set "app.build.web.file_count=%%A" & set "app.build.web.total_bytes=%%B"
set "WEB_VALIDATE_DIR="
if not "%app.build.web.file_count%"=="0" goto :_ValidateWebsitePackage_entry
echo ERROR: The website build package is empty.
exit /b 1
:_ValidateWebsitePackage_entry
if not "%app.web.require_entry%"=="1" exit /b 0
if defined app.web.entry_file if exist "%app.build.web.work_build_dir%\%app.web.entry_file%" exit /b 0
echo ERROR: The configured entry file was not copied into the website package.
if defined app.web.entry_file echo   "%app.build.web.work_build_dir%\%app.web.entry_file%"
exit /b 1
:: ============================================================
:: :CreateSourceSnapshot
:: Copies complete current source using Git ignore rules when available.
::
:: Usage: call :CreateSourceSnapshot
::
:: Returns: 0 on success, 1 on failure
:: Requires: PowerShell, optional Git
:: ============================================================
:CreateSourceSnapshot
echo Creating source snapshot:
echo   %app.build.web.work_source_dir%
echo.
set "WEB_SOURCE_ROOT=%app.build.web.root%"
set "WEB_SOURCE_DEST=%app.build.web.work_source_dir%"
set "WEB_SOURCE_MODE=%app.build.web.snapshot_mode%"
set "WEB_SOURCE_GIT=%app.build.web.git%"
set "WEB_BUILD_PREFIX=%app.web.build_dir_prefix%"
set "WEB_SOURCE_PREFIX=%app.web.source_dir_prefix%"
set "WEB_OLDBUILDS=%app.web.oldbuilds_dir%"
set "WEB_TEMP_ROOT=%app.web.temp_root%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root=[IO.Path]::GetFullPath($env:WEB_SOURCE_ROOT); $dest=[IO.Path]::GetFullPath($env:WEB_SOURCE_DEST); $mode=$env:WEB_SOURCE_MODE; $git=$env:WEB_SOURCE_GIT; $bp=$env:WEB_BUILD_PREFIX+'_'; $sp=$env:WEB_SOURCE_PREFIX+'_'; $old=$env:WEB_OLDBUILDS; $tmp=$env:WEB_TEMP_ROOT; if($mode -eq 'git'){ $items=& $git -C $root -c core.quotepath=false ls-files --cached --others --exclude-standard; if($LASTEXITCODE -ne 0){exit 2}; $files=@($items) } else { $files=@(Get-ChildItem -LiteralPath $root -File -Recurse | ForEach-Object {$_.FullName.Substring($root.Length).TrimStart('\','/')}) }; foreach($item in $files){if([string]::IsNullOrWhiteSpace($item)){continue}; $rel=$item.Replace('/','\'); $first=($rel -split '\\',2)[0]; if($first -ieq '.git' -or $first -ieq $old -or $first -ieq $tmp -or $first.StartsWith($bp,[StringComparison]::OrdinalIgnoreCase) -or $first.StartsWith($sp,[StringComparison]::OrdinalIgnoreCase)){continue}; $src=Join-Path $root $rel; if(-not (Test-Path -LiteralPath $src -PathType Leaf)){continue}; $out=Join-Path $dest $rel; $parent=Split-Path -Parent $out; if(-not (Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Force -Path $parent | Out-Null}; Copy-Item -LiteralPath $src -Destination $out -Force}; exit 0"
set "css_rc=%errorlevel%"
set "WEB_SOURCE_ROOT="
set "WEB_SOURCE_DEST="
set "WEB_SOURCE_MODE="
set "WEB_SOURCE_GIT="
set "WEB_BUILD_PREFIX="
set "WEB_SOURCE_PREFIX="
set "WEB_OLDBUILDS="
set "WEB_TEMP_ROOT="
if "%css_rc%"=="0" exit /b 0
echo ERROR: Source snapshot failed with exit code %css_rc%.
exit /b 1
:: ============================================================
:: :PromoteSuccessfulBuild
:: Moves temporary website and source folders to final dated names.
::
:: Usage: call :PromoteSuccessfulBuild
::
:: Returns: 0 on success, 1 on move failure
:: Requires: move
:: ============================================================
:PromoteSuccessfulBuild
echo Promoting successful website build:
echo   %app.build.web.final_build_dir%
echo   %app.build.web.final_source_dir%
echo.
move "%app.build.web.work_build_dir%" "%app.build.web.final_build_dir%" >nul
set "psb_rc=%errorlevel%"
if not "%psb_rc%"=="0" goto :_PromoteSuccessfulBuild_build_fail
set "app.build.web.created_final_build=1"
move "%app.build.web.work_source_dir%" "%app.build.web.final_source_dir%" >nul
set "psb_rc=%errorlevel%"
if not "%psb_rc%"=="0" goto :_PromoteSuccessfulBuild_source_fail
set "app.build.web.created_final_source=1"
set "app.build.web.build_complete=1"
exit /b 0
:_PromoteSuccessfulBuild_build_fail
echo ERROR: Could not promote the temporary website build folder.
exit /b 1
:_PromoteSuccessfulBuild_source_fail
echo ERROR: Could not promote the temporary source snapshot folder.
exit /b 1
:: ============================================================
:: :ArchiveOlderFolders
:: Moves older final build/source folders into oldbuilds.
::
:: Usage: call :ArchiveOlderFolders
::
:: Returns: 0 when archived, 1 when any move fails
:: Requires: :ArchiveOneFolder
:: ============================================================
:ArchiveOlderFolders
set "app.build.web.archive_failed="
if not exist "%app.build.web.archive_dir%\" mkdir "%app.build.web.archive_dir%" >nul 2>nul
if exist "%app.build.web.archive_dir%\" goto :_ArchiveOlderFolders_scan
echo ERROR: Could not create archive folder:
echo   "%app.build.web.archive_dir%"
exit /b 1
:_ArchiveOlderFolders_scan
for /D %%D in ("%app.build.web.root%\%app.web.build_dir_prefix%_*") do call :ArchiveOneFolder "%%~fD"
for /D %%D in ("%app.build.web.root%\%app.web.source_dir_prefix%_*") do call :ArchiveOneFolder "%%~fD"
if defined app.build.web.archive_failed exit /b 1
exit /b 0
:: ============================================================
:: :ArchiveOneFolder
:: Moves one older dated folder without overwriting an existing archive.
::
:: Usage: call :ArchiveOneFolder "full folder path"
::
:: Returns: 0; records failure in app.build.web.archive_failed
:: Requires: move
:: ============================================================
:ArchiveOneFolder
set "aof_source=%~1"
if not defined aof_source exit /b 0
if /I "%aof_source%"=="%app.build.web.final_build_dir%" exit /b 0
if /I "%aof_source%"=="%app.build.web.final_source_dir%" exit /b 0
for %%A in ("%aof_source%") do set "aof_name=%%~nxA"
set "aof_target=%app.build.web.archive_dir%\%aof_name%"
if exist "%aof_target%\" set "aof_target=%app.build.web.archive_dir%\%aof_name%.moved_%app.build.web.timestamp%_%RANDOM%"
move "%aof_source%" "%aof_target%" >nul 2>nul
set "aof_rc=%errorlevel%"
if "%aof_rc%"=="0" exit /b 0
echo ERROR: Could not archive:
echo   "%aof_source%"
set "app.build.web.archive_failed=1"
exit /b 0
:: ============================================================
:: :Clean
:: Moves all current dated website build/source folders into oldbuilds.
::
:: Usage: call :Clean
::
:: Returns: archive workflow result
:: Requires: :CreateTimestamp, :ArchiveOlderFolders
:: ============================================================
:Clean
call :CreateTimestamp
set "clean_rc=%errorlevel%"
if not "%clean_rc%"=="0" exit /b %clean_rc%
set "app.build.web.final_build_dir="
set "app.build.web.final_source_dir="
call :ArchiveOlderFolders
set "clean_rc=%errorlevel%"
if not "%clean_rc%"=="0" exit /b %clean_rc%
echo Clean complete.
echo Current dated website build and source folders were moved to:
echo   %app.build.web.archive_dir%
echo.
exit /b 0
:: ============================================================
:: :CreateTimestamp
:: Creates a timestamp for clean/archive collision handling.
::
:: Usage: call :CreateTimestamp
::
:: Returns: 0 on success, 1 on failure
:: Requires: PowerShell
:: ============================================================
:CreateTimestamp
set "app.build.web.timestamp="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "(Get-Date).ToString('yyyy-MM-dd.HH''h''mm.ss')"`) do if not defined app.build.web.timestamp set "app.build.web.timestamp=%%A"
if defined app.build.web.timestamp exit /b 0
echo ERROR: Could not create a timestamp.
exit /b 1
:: ============================================================
:: :ReportSuccess
:: Prints final website package details.
::
:: Usage: call :ReportSuccess
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ReportSuccess
echo ============================================================
echo  Website build complete
echo ============================================================
echo.
echo Website package:
echo   %app.build.web.final_build_dir%
echo.
echo Source snapshot:
echo   %app.build.web.final_source_dir%
echo.
echo Older builds:
echo   %app.build.web.archive_dir%
echo.
echo Deployable files:
echo   %app.build.web.file_count%
echo.
echo Package bytes:
echo   %app.build.web.total_bytes%
echo.
echo PHP files checked:
echo   %app.build.web.php_count%
echo.
echo %app.web.description%
if /I "%app.build.web.mode%"=="nosync" echo No commit or push was performed.
echo.
exit /b 0
:: ============================================================
:: :CleanupRun
:: Removes temporary folders and lint logs. If promotion fails midway,
:: removes final folders created by the incomplete run.
::
:: Usage: call :CleanupRun
::
:: Returns: 0
:: Requires: rmdir, del
:: ============================================================
:CleanupRun
if defined app.build.web.php_lint_log if exist "%app.build.web.php_lint_log%" del /Q "%app.build.web.php_lint_log%" >nul 2>nul
if defined app.build.web.work_build_dir if exist "%app.build.web.work_build_dir%\" rmdir /S /Q "%app.build.web.work_build_dir%" >nul 2>nul
if defined app.build.web.work_source_dir if exist "%app.build.web.work_source_dir%\" rmdir /S /Q "%app.build.web.work_source_dir%" >nul 2>nul
if defined app.build.web.build_complete goto :_CleanupRun_temp
if defined app.build.web.created_final_build if exist "%app.build.web.final_build_dir%\" rmdir /S /Q "%app.build.web.final_build_dir%" >nul 2>nul
if defined app.build.web.created_final_source if exist "%app.build.web.final_source_dir%\" rmdir /S /Q "%app.build.web.final_source_dir%" >nul 2>nul
:_CleanupRun_temp
if defined app.web.temp_root rmdir "%app.build.web.root%\%app.web.temp_root%" >nul 2>nul
exit /b 0
