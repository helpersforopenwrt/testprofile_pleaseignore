@echo off
:: ============================================================
:: install_web.bat
:: Generic deployer for framework-free website build folders.
::
:: Primary implemented method:
::   folder
::     Copies the selected dated build_* website package to a local,
::     mapped-drive, UNC, Samba-mounted, or other Windows-accessible
::     destination folder.
::
:: Additional method provision:
::   Any non-folder method may be implemented by configuring:
::     app.web.install.method=method-name
::     app.web.install.method_script=relative\or\absolute\script.bat
::
::   The method script receives deployment information through:
::     WEB_INSTALL_METHOD
::     WEB_INSTALL_SOURCE
::     WEB_INSTALL_DESTINATION
::     WEB_INSTALL_FOLDER_MODE
::     WEB_INSTALL_ENTRY_FILE
::     WEB_INSTALL_PROJECT_ROOT
::
::   This supports future scp, sftp, rsync, FTP, cloud, container,
::   hosting-provider, or framework-specific deployment scripts without
::   changing this generic installer.
::
:: Folder deployment modes:
::   copy
::     Copies and overwrites source files but preserves unrelated files
::     already at the destination. This is the safe default.
::
::   mirror
::     Makes the destination match the build folder and may delete
::     destination-only files. Use only for a dedicated deployment
::     directory.
::
:: Install lifecycle:
::   1. load build_config.bat
::   2. load optional build_config_web.bat
::   3. apply optional env.bat
::   4. select an explicit or newest dated build folder
::   5. validate the website package
::   6. resolve and safety-check the destination
::   7. show the deployment plan
::   8. request DEPLOY confirmation unless disabled
::   9. deploy using folder copy or a configured method script
::  10. verify copied folder content or call a verification script
::
:: Configuration order:
::   1. build_config.bat
::   2. build_config_web.bat when present
::
:: Primary configuration:
::   app.web.install.default_mode=install
::   app.web.install.method=folder
::   app.web.install.destination=
::   app.web.install.folder_mode=copy
::   app.web.install.confirm=1
::   app.web.install.create_destination=1
::   app.web.install.allow_drive_root=0
::   app.web.install.verify_mode=size
::   app.web.install.method_script=
::   app.web.install.verify_script=
::   app.web.install.url=
::
:: verify_mode values for folder deployments:
::   size  verify every source file exists with the same size
::   hash  verify every source file with SHA-256
::   none  skip generic post-copy verification
::
:: Active placement:
::   install_web.bat at the project root
::
:: Template storage:
::   tools\templates\install\install_web.bat
::
:: Usage:
::   call install_web.bat
::   call install_web.bat install
::   call install_web.bat check
::   call install_web.bat plan
::   call install_web.bat build build_YYYY-MM-DD.HHhmm.ss
::   call install_web.bat destination T:\website
::   call install_web.bat copy
::   call install_web.bat mirror
::   call install_web.bat yes
::   call install_web.bat help
::
:: Returns: 0 on success
::          1 on setup, source, destination, deployment, or verification failure
::          2 on invalid command-line arguments or configuration
::          130 when confirmation is cancelled
::          configured method/verification script exit code on failure
:: Requires: PowerShell
::           Robocopy for folder deployment
:: ============================================================
:setup
set "app.install.web.rc=0"
set "app.install.web.root="
set "app.install.web.shared_config="
set "app.install.web.suffix_config="
set "app.install.web.mode="
set "app.install.web.request.build="
set "app.install.web.request.destination="
set "app.install.web.assume_yes="
set "app.install.web.source="
set "app.install.web.destination="
set "app.install.web.entry_file="
set "app.install.web.method_script="
set "app.install.web.verify_script="
set "app.install.web.file_count=0"
set "app.install.web.total_bytes=0"
set "app.install.web.confirm.answer="
set "app.install.web.destination.exists="
set "app.install.suffix=web"
if not defined INSTALL_SUFFIX set "INSTALL_SUFFIX=web"
if defined INSTALL_PROJECT_ROOT set "app.install.web.root=%INSTALL_PROJECT_ROOT%"
if not defined app.install.web.root for %%A in ("%~dp0.") do set "app.install.web.root=%%~fA"
for %%A in ("%app.install.web.root%\.") do set "app.install.web.root=%%~fA"
:main
call :LoadConfiguration
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
call :SetDefaults
call :ParseArguments %*
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
if /I "%app.install.web.mode%"=="help" call :ShowHelp
if /I "%app.install.web.mode%"=="help" set "app.install.web.rc=%errorlevel%"
if /I "%app.install.web.mode%"=="help" goto :end
cd /d "%app.install.web.root%"
set "app.install.web.rc=%errorlevel%"
if "%app.install.web.rc%"=="0" goto :_main_environment
echo.
echo ERROR: Could not enter the project root:
echo   "%app.install.web.root%"
echo.
set "app.install.web.rc=1"
goto :end
:_main_environment
call :ApplyEnvironmentFile
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
call :ShowHeader
call :ResolveInstallSource
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
call :ValidateInstallSource
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
call :ResolveInstallDestination
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
call :ValidateInstallDestination
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
call :CheckDeploymentMethod
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
if /I "%app.install.web.mode%"=="check" call :ReportCheck
if /I "%app.install.web.mode%"=="check" set "app.install.web.rc=%errorlevel%"
if /I "%app.install.web.mode%"=="check" goto :end
call :ShowDeploymentPlan
if /I "%app.install.web.mode%"=="plan" goto :end
call :ConfirmDeployment
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
call :DeployWebsite
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
call :VerifyDeployment
set "app.install.web.rc=%errorlevel%"
if not "%app.install.web.rc%"=="0" goto :end
call :ReportSuccess
set "app.install.web.rc=%errorlevel%"
:end
call :ClearDeploymentEnvironment
exit /b %app.install.web.rc%
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
set "app.install.web.shared_config=%app.install.web.root%\build_config.bat"
set "app.install.web.suffix_config=%app.install.web.root%\build_config_web.bat"
if exist "%app.install.web.shared_config%" goto :_LoadConfiguration_shared
echo.
echo ERROR: Shared build configuration was not found:
echo   "%app.install.web.shared_config%"
echo.
exit /b 1
:_LoadConfiguration_shared
call "%app.install.web.shared_config%"
set "lc_rc=%errorlevel%"
if "%lc_rc%"=="0" goto :_LoadConfiguration_suffix
echo.
echo ERROR: Shared build configuration failed:
echo   "%app.install.web.shared_config%"
echo.
exit /b %lc_rc%
:_LoadConfiguration_suffix
if not exist "%app.install.web.suffix_config%" exit /b 0
call "%app.install.web.suffix_config%"
set "lc_rc=%errorlevel%"
if "%lc_rc%"=="0" exit /b 0
echo.
echo ERROR: Web configuration failed:
echo   "%app.install.web.suffix_config%"
echo.
exit /b %lc_rc%
:: ============================================================
:: :SetDefaults
:: Applies generic web deployment defaults after configuration.
::
:: Usage: call :SetDefaults
::
:: Returns: 0
:: Requires: none
:: ============================================================
:SetDefaults
if not defined app.web.install.default_mode set "app.web.install.default_mode=install"
if not defined app.install.web.mode set "app.install.web.mode=%app.web.install.default_mode%"
if not defined app.web.install.method set "app.web.install.method=folder"
if not defined app.web.install.folder_mode set "app.web.install.folder_mode=copy"
if not defined app.web.install.confirm set "app.web.install.confirm=1"
if not defined app.web.install.create_destination set "app.web.install.create_destination=1"
if not defined app.web.install.allow_drive_root set "app.web.install.allow_drive_root=0"
if not defined app.web.install.verify_mode set "app.web.install.verify_mode=size"
if not defined app.web.install.method_script set "app.web.install.method_script="
if not defined app.web.install.verify_script set "app.web.install.verify_script="
if not defined app.web.install.env_file set "app.web.install.env_file=env.bat"
if not defined app.web.install.build_dir_prefix set "app.web.install.build_dir_prefix=%app.web.build_dir_prefix%"
if not defined app.web.install.build_dir_prefix set "app.web.install.build_dir_prefix=%app.build_dir_prefix%"
if not defined app.web.install.build_dir_prefix set "app.web.install.build_dir_prefix=build"
if not defined app.web.install.require_entry set "app.web.install.require_entry=%app.web.require_entry%"
if not defined app.web.install.require_entry set "app.web.install.require_entry=1"
if not defined app.web.install.entry_file set "app.web.install.entry_file=%app.web.entry_file%"
if not defined app.web.install.entry_file if exist "%app.install.web.root%\index.php" set "app.web.install.entry_file=index.php"
if not defined app.web.install.entry_file if exist "%app.install.web.root%\index.html" set "app.web.install.entry_file=index.html"
if not defined app.web.install.entry_file if exist "%app.install.web.root%\index.htm" set "app.web.install.entry_file=index.htm"
exit /b 0
:: ============================================================
:: :ParseArguments
:: Parses install mode and command-line overrides.
::
:: Usage: call :ParseArguments %*
::
:: Accepted:
::   install, check, plan, help
::   build FOLDER
::   destination FOLDER
::   method NAME
::   copy, mirror
::   yes
::
:: Returns: 0 on success, 2 on invalid syntax
:: Requires: none
:: ============================================================
:ParseArguments
if "%~1"=="" exit /b 0
if /I "%~1"=="install" (set "app.install.web.mode=install" & shift & goto :ParseArguments)
if /I "%~1"=="check" (set "app.install.web.mode=check" & shift & goto :ParseArguments)
if /I "%~1"=="plan" (set "app.install.web.mode=plan" & shift & goto :ParseArguments)
if /I "%~1"=="copy" (set "app.web.install.folder_mode=copy" & shift & goto :ParseArguments)
if /I "%~1"=="mirror" (set "app.web.install.folder_mode=mirror" & shift & goto :ParseArguments)
if /I "%~1"=="yes" (set "app.install.web.assume_yes=1" & shift & goto :ParseArguments)
if /I "%~1"=="--yes" (set "app.install.web.assume_yes=1" & shift & goto :ParseArguments)
if /I "%~1"=="/yes" (set "app.install.web.assume_yes=1" & shift & goto :ParseArguments)
if /I "%~1"=="build" goto :_ParseArguments_build
if /I "%~1"=="destination" goto :_ParseArguments_destination
if /I "%~1"=="method" goto :_ParseArguments_method
if /I "%~1"=="help" (set "app.install.web.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="--help" (set "app.install.web.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="/help" (set "app.install.web.mode=help" & shift & goto :ParseArguments)
if /I "%~1"=="/?" (set "app.install.web.mode=help" & shift & goto :ParseArguments)
echo.
echo ERROR: Unknown install_web argument:
echo   %~1
echo.
exit /b 2
:_ParseArguments_build
if not "%~2"=="" goto :_ParseArguments_build_value
echo ERROR: build requires a folder path.
exit /b 2
:_ParseArguments_build_value
set "app.install.web.request.build=%~2"
shift
shift
goto :ParseArguments
:_ParseArguments_destination
if not "%~2"=="" goto :_ParseArguments_destination_value
echo ERROR: destination requires a folder path.
exit /b 2
:_ParseArguments_destination_value
set "app.install.web.request.destination=%~2"
shift
shift
goto :ParseArguments
:_ParseArguments_method
if not "%~2"=="" goto :_ParseArguments_method_value
echo ERROR: method requires a method name.
exit /b 2
:_ParseArguments_method_value
set "app.web.install.method=%~2"
shift
shift
goto :ParseArguments
:: ============================================================
:: :ApplyEnvironmentFile
:: Applies the configured optional environment batch file.
::
:: Usage: call :ApplyEnvironmentFile
::
:: Returns: env file result, or 0 when absent
:: Requires: optional env.bat
:: ============================================================
:ApplyEnvironmentFile
set "aef_file=%app.install.web.root%\%app.web.install.env_file%"
if not exist "%aef_file%" exit /b 0
call "%aef_file%"
set "aef_rc=%errorlevel%"
if "%aef_rc%"=="0" exit /b 0
echo.
echo ERROR: Environment file failed:
echo   "%aef_file%"
echo.
exit /b %aef_rc%
:: ============================================================
:: :ShowHeader
:: Prints the selected website deployment request.
::
:: Usage: call :ShowHeader
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHeader
echo.
echo ============================================================
echo  %app.display_name% website deployment
echo ============================================================
echo.
echo Project root:
echo   %app.install.web.root%
echo.
echo Suffix:
echo   web
echo.
echo Mode:
echo   %app.install.web.mode%
echo.
echo Method:
echo   %app.web.install.method%
echo.
exit /b 0
:: ============================================================
:: :ShowHelp
:: Prints usage and method configuration.
::
:: Usage: call :ShowHelp
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowHelp
echo.
echo install_web.bat
echo.
echo Usage:
echo   install_web.bat
echo   install_web.bat install
echo   install_web.bat check
echo   install_web.bat plan
echo   install_web.bat build build_YYYY-MM-DD.HHhmm.ss
echo   install_web.bat destination T:\website
echo   install_web.bat copy
echo   install_web.bat mirror
echo   install_web.bat yes
echo   install_web.bat help
echo.
echo Folder method:
echo   app.web.install.method=folder
echo   app.web.install.destination=T:\website
echo   app.web.install.folder_mode=copy
echo.
echo copy preserves destination-only files.
echo mirror may delete destination-only files.
echo.
echo Drive-root safety:
echo   Deploying directly to T:\ or another drive root is blocked by
echo   default. Deliberately enable it with:
echo     app.web.install.allow_drive_root=1
echo.
echo Verification:
echo   app.web.install.verify_mode=size
echo   Supported values: size, hash, none
echo.
echo Other deployment methods:
echo   Set app.web.install.method to a descriptive name and configure:
echo     app.web.install.method_script=tools\deploy_scp.bat
echo.
echo The method script receives source, destination, method, folder
echo mode, entry file, and project root through WEB_INSTALL_* variables.
echo.
exit /b 0
:: ============================================================
:: :ResolveInstallSource
:: Selects an explicit build folder or the newest dated build folder.
::
:: Usage: call :ResolveInstallSource
::
:: Output:
::   app.install.web.source
::
:: Returns: 0 when selected, 1 when none exists
:: Requires: dir, :UseBuildFolderIfUnset
:: ============================================================
:ResolveInstallSource
set "app.install.web.source="
if defined app.install.web.request.build goto :_ResolveInstallSource_requested
for /f "delims=" %%D in ('dir /b /ad /o-n "%app.install.web.root%\%app.web.install.build_dir_prefix%_*" 2^>nul') do call :UseBuildFolderIfUnset "%%D"
if defined app.install.web.source exit /b 0
echo ERROR: No dated website build folder was found.
echo Expected:
echo   "%app.install.web.root%\%app.web.install.build_dir_prefix%_*"
echo.
echo Run build_web.bat first or select a folder with:
echo   install_web.bat build path\to\build_folder
exit /b 1
:_ResolveInstallSource_requested
for %%A in ("%app.install.web.request.build%") do set "app.install.web.source=%%~fA"
exit /b 0
:: ============================================================
:: :UseBuildFolderIfUnset
:: Records the first build folder supplied by newest-first discovery.
::
:: Usage: call :UseBuildFolderIfUnset "folder name"
::
:: Returns: 0
:: Requires: none
:: ============================================================
:UseBuildFolderIfUnset
if defined app.install.web.source exit /b 0
for %%A in ("%app.install.web.root%\%~1") do set "app.install.web.source=%%~fA"
exit /b 0
:: ============================================================
:: :ValidateInstallSource
:: Verifies the selected package exists, is nonempty, and contains the
:: configured entry file when required.
::
:: Usage: call :ValidateInstallSource
::
:: Output:
::   app.install.web.file_count
::   app.install.web.total_bytes
::   app.install.web.entry_file
::
:: Returns: 0 when valid, 1 otherwise
:: Requires: PowerShell
:: ============================================================
:ValidateInstallSource
where powershell.exe >nul 2>nul
if not errorlevel 1 goto :_ValidateInstallSource_folder
echo ERROR: PowerShell is required for website deployment validation.
exit /b 1
:_ValidateInstallSource_folder
if exist "%app.install.web.source%\" goto :_ValidateInstallSource_count
echo ERROR: Selected website build folder does not exist:
echo   "%app.install.web.source%"
exit /b 1
:_ValidateInstallSource_count
set "WEB_INSTALL_VALIDATE_SOURCE=%app.install.web.source%"
set "app.install.web.file_count=0"
set "app.install.web.total_bytes=0"
for /f "tokens=1,2" %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=@(Get-ChildItem -LiteralPath $env:WEB_INSTALL_VALIDATE_SOURCE -File -Recurse); $bytes=($f | Measure-Object Length -Sum).Sum; if($null -eq $bytes){$bytes=0}; Write-Output ($f.Count.ToString()+' '+$bytes.ToString())"') do set "app.install.web.file_count=%%A" & set "app.install.web.total_bytes=%%B"
set "WEB_INSTALL_VALIDATE_SOURCE="
if not "%app.install.web.file_count%"=="0" goto :_ValidateInstallSource_entry
echo ERROR: Selected website build folder is empty:
echo   "%app.install.web.source%"
exit /b 1
:_ValidateInstallSource_entry
set "app.install.web.entry_file=%app.web.install.entry_file%"
if not "%app.web.install.require_entry%"=="1" exit /b 0
if defined app.install.web.entry_file if exist "%app.install.web.source%\%app.install.web.entry_file%" exit /b 0
echo ERROR: Required website entry file was not found in the build package.
if defined app.install.web.entry_file echo   "%app.install.web.source%\%app.install.web.entry_file%"
if not defined app.install.web.entry_file echo   Configure app.web.install.entry_file in build_config_web.bat.
exit /b 1
:: ============================================================
:: :ResolveInstallDestination
:: Resolves command-line or configured deployment destination.
::
:: Usage: call :ResolveInstallDestination
::
:: Output:
::   app.install.web.destination
::
:: Returns: 0 when configured, 1 when missing
:: Requires: none
:: ============================================================
:ResolveInstallDestination
set "app.install.web.destination=%app.web.install.destination%"
if defined app.install.web.request.destination set "app.install.web.destination=%app.install.web.request.destination%"
if defined app.install.web.destination goto :_ResolveInstallDestination_normalize
echo ERROR: No website deployment destination is configured.
echo.
echo Configure build_config_web.bat:
echo   set "app.web.install.destination=T:\website"
echo.
echo Or supply:
echo   install_web.bat destination T:\website
exit /b 1
:_ResolveInstallDestination_normalize
if /I not "%app.web.install.method%"=="folder" exit /b 0
for %%A in ("%app.install.web.destination%\.") do set "app.install.web.destination=%%~fA"
exit /b 0
:: ============================================================
:: :ValidateInstallDestination
:: Performs safety checks for folder deployments.
::
:: Prevents:
::   - source and destination being the same folder
::   - destination nested inside source
::   - source nested inside destination
::   - destination equal to the project root
::   - drive-root deployment unless explicitly allowed
::
:: Usage: call :ValidateInstallDestination
::
:: Returns: 0 when safe, 1 otherwise
:: Requires: PowerShell for folder method
:: ============================================================
:ValidateInstallDestination
if /I not "%app.web.install.method%"=="folder" exit /b 0
set "WEB_INSTALL_SAFE_SOURCE=%app.install.web.source%"
set "WEB_INSTALL_SAFE_DEST=%app.install.web.destination%"
set "WEB_INSTALL_SAFE_ROOT=%app.install.web.root%"
set "WEB_INSTALL_ALLOW_DRIVE_ROOT=%app.web.install.allow_drive_root%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $src=[IO.Path]::GetFullPath($env:WEB_INSTALL_SAFE_SOURCE).TrimEnd('\'); $dst=[IO.Path]::GetFullPath($env:WEB_INSTALL_SAFE_DEST).TrimEnd('\'); $root=[IO.Path]::GetFullPath($env:WEB_INSTALL_SAFE_ROOT).TrimEnd('\'); $sep=[IO.Path]::DirectorySeparatorChar; if($src -ieq $dst){exit 10}; if($dst.StartsWith($src+$sep,[StringComparison]::OrdinalIgnoreCase)){exit 11}; if($src.StartsWith($dst+$sep,[StringComparison]::OrdinalIgnoreCase)){exit 12}; if($dst -ieq $root){exit 13}; $drive=[IO.Path]::GetPathRoot($dst).TrimEnd('\'); if($dst -ieq $drive -and $env:WEB_INSTALL_ALLOW_DRIVE_ROOT -ne '1'){exit 14}; exit 0"
set "vid_rc=%errorlevel%"
set "WEB_INSTALL_SAFE_SOURCE="
set "WEB_INSTALL_SAFE_DEST="
set "WEB_INSTALL_SAFE_ROOT="
set "WEB_INSTALL_ALLOW_DRIVE_ROOT="
if "%vid_rc%"=="0" goto :_ValidateInstallDestination_exists
if "%vid_rc%"=="10" echo ERROR: Source and destination are the same folder.
if "%vid_rc%"=="11" echo ERROR: Destination cannot be inside the source build folder.
if "%vid_rc%"=="12" echo ERROR: Source build folder cannot be inside the destination.
if "%vid_rc%"=="13" echo ERROR: Destination cannot be the project root.
if "%vid_rc%"=="14" echo ERROR: Direct deployment to a drive root is blocked.
if "%vid_rc%"=="14" echo Enable app.web.install.allow_drive_root=1 only for a dedicated deployment drive.
if not "%vid_rc%"=="10" if not "%vid_rc%"=="11" if not "%vid_rc%"=="12" if not "%vid_rc%"=="13" if not "%vid_rc%"=="14" echo ERROR: Destination safety validation failed with exit code %vid_rc%.
exit /b 1
:_ValidateInstallDestination_exists
set "app.install.web.destination.exists="
if exist "%app.install.web.destination%\" set "app.install.web.destination.exists=1"
if defined app.install.web.destination.exists exit /b 0
if "%app.web.install.create_destination%"=="1" exit /b 0
echo ERROR: Destination folder does not exist and automatic creation is disabled:
echo   "%app.install.web.destination%"
exit /b 1
:: ============================================================
:: :CheckDeploymentMethod
:: Verifies the configured folder method or external method script.
::
:: Usage: call :CheckDeploymentMethod
::
:: Output:
::   app.install.web.method_script
::   app.install.web.verify_script
::
:: Returns: 0 when ready, 1 or 2 otherwise
:: Requires: Robocopy for folder method
:: ============================================================
:CheckDeploymentMethod
if /I "%app.web.install.method%"=="folder" goto :_CheckDeploymentMethod_folder
call :ResolveConfiguredScript "%app.web.install.method_script%" app.install.web.method_script
set "cdm_rc=%errorlevel%"
if "%cdm_rc%"=="0" goto :_CheckDeploymentMethod_verify
echo ERROR: Deployment method "%app.web.install.method%" requires a method script.
echo Configure:
echo   set "app.web.install.method_script=tools\deploy_%app.web.install.method%.bat"
exit /b 1
:_CheckDeploymentMethod_folder
where robocopy.exe >nul 2>nul
if not errorlevel 1 goto :_CheckDeploymentMethod_verify_mode
echo ERROR: Robocopy is required for folder website deployment.
exit /b 1
:_CheckDeploymentMethod_verify_mode
if /I "%app.web.install.folder_mode%"=="copy" goto :_CheckDeploymentMethod_verify
if /I "%app.web.install.folder_mode%"=="mirror" goto :_CheckDeploymentMethod_verify
echo ERROR: app.web.install.folder_mode must be copy or mirror.
exit /b 2
:_CheckDeploymentMethod_verify
if /I "%app.web.install.verify_mode%"=="size" goto :_CheckDeploymentMethod_verify_script
if /I "%app.web.install.verify_mode%"=="hash" goto :_CheckDeploymentMethod_verify_script
if /I "%app.web.install.verify_mode%"=="none" goto :_CheckDeploymentMethod_verify_script
echo ERROR: app.web.install.verify_mode must be size, hash, or none.
exit /b 2
:_CheckDeploymentMethod_verify_script
if not defined app.web.install.verify_script exit /b 0
call :ResolveConfiguredScript "%app.web.install.verify_script%" app.install.web.verify_script
set "cdm_rc=%errorlevel%"
if "%cdm_rc%"=="0" exit /b 0
echo ERROR: Configured deployment verification script was not found:
echo   "%app.web.install.verify_script%"
exit /b 1
:: ============================================================
:: :ResolveConfiguredScript
:: Resolves an absolute script or a path relative to the project root.
::
:: Usage: call :ResolveConfiguredScript "configured path" outputVariable
::
:: Returns: 0 when found, 1 when missing
:: Requires: none
:: ============================================================
:ResolveConfiguredScript
set "rcs_input=%~1"
set "rcs_output=%~2"
if not defined rcs_input exit /b 1
if exist "%rcs_input%" for %%A in ("%rcs_input%") do set "%rcs_output%=%%~fA"
if defined %rcs_output% exit /b 0
if exist "%app.install.web.root%\%rcs_input%" for %%A in ("%app.install.web.root%\%rcs_input%") do set "%rcs_output%=%%~fA"
if defined %rcs_output% exit /b 0
exit /b 1
:: ============================================================
:: :ReportCheck
:: Prints resolved deployment readiness without making changes.
::
:: Usage: call :ReportCheck
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ReportCheck
echo Deployment check complete.
echo.
echo Source:
echo   %app.install.web.source%
echo.
echo Files:
echo   %app.install.web.file_count%
echo.
echo Bytes:
echo   %app.install.web.total_bytes%
echo.
echo Destination:
echo   %app.install.web.destination%
echo.
echo Method:
echo   %app.web.install.method%
if /I "%app.web.install.method%"=="folder" echo.
if /I "%app.web.install.method%"=="folder" echo Folder mode:
if /I "%app.web.install.method%"=="folder" echo   %app.web.install.folder_mode%
echo.
exit /b 0
:: ============================================================
:: :ShowDeploymentPlan
:: Prints source, destination, overwrite, deletion, and verification details.
::
:: Usage: call :ShowDeploymentPlan
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ShowDeploymentPlan
echo ============================================================
echo  Website deployment plan
echo ============================================================
echo.
echo Source build:
echo   %app.install.web.source%
echo.
echo Source files:
echo   %app.install.web.file_count%
echo.
echo Source bytes:
echo   %app.install.web.total_bytes%
echo.
echo Destination:
echo   %app.install.web.destination%
echo.
echo Method:
echo   %app.web.install.method%
echo.
if /I not "%app.web.install.method%"=="folder" goto :_ShowDeploymentPlan_external
echo Folder mode:
echo   %app.web.install.folder_mode%
echo.
if /I "%app.web.install.folder_mode%"=="copy" echo Destination-only files will be preserved.
if /I "%app.web.install.folder_mode%"=="mirror" echo WARNING: Destination-only files may be deleted.
if not defined app.install.web.destination.exists echo The destination folder will be created.
echo.
goto :_ShowDeploymentPlan_verify
:_ShowDeploymentPlan_external
echo Method script:
echo   %app.install.web.method_script%
echo.
:_ShowDeploymentPlan_verify
echo Verification:
if defined app.install.web.verify_script echo   script: %app.install.web.verify_script%
if not defined app.install.web.verify_script echo   %app.web.install.verify_mode%
if defined app.web.install.url echo.
if defined app.web.install.url echo Website URL:
if defined app.web.install.url echo   %app.web.install.url%
echo.
exit /b 0
:: ============================================================
:: :ConfirmDeployment
:: Requests explicit DEPLOY confirmation unless disabled or "yes"
:: was supplied on the command line.
::
:: Usage: call :ConfirmDeployment
::
:: Returns: 0 when confirmed, 130 when cancelled
:: Requires: set /p
:: ============================================================
:ConfirmDeployment
if defined app.install.web.assume_yes exit /b 0
if not "%app.web.install.confirm%"=="1" exit /b 0
set "app.install.web.confirm.answer="
set /p "app.install.web.confirm.answer=Type DEPLOY to continue: "
if "%app.install.web.confirm.answer%"=="DEPLOY" exit /b 0
echo.
echo Deployment cancelled before changes were made.
echo.
exit /b 130
:: ============================================================
:: :DeployWebsite
:: Dispatches the implemented folder method or configured method script.
::
:: Usage: call :DeployWebsite
::
:: Returns: deployment result
:: Requires: :DeployToFolder or :DeployWithMethodScript
:: ============================================================
:DeployWebsite
call :SetDeploymentEnvironment
if /I "%app.web.install.method%"=="folder" call :DeployToFolder
if /I "%app.web.install.method%"=="folder" set "dw_rc=%errorlevel%"
if /I not "%app.web.install.method%"=="folder" call :DeployWithMethodScript
if /I not "%app.web.install.method%"=="folder" set "dw_rc=%errorlevel%"
exit /b %dw_rc%
:: ============================================================
:: :DeployToFolder
:: Copies or mirrors the website package using Robocopy.
::
:: Robocopy result codes 0 through 7 are successful.
:: Codes 8 and above are failures.
::
:: Usage: call :DeployToFolder
::
:: Returns: 0 on successful Robocopy result, 1 otherwise
:: Requires: Robocopy
:: ============================================================
:DeployToFolder
if exist "%app.install.web.destination%\" goto :_DeployToFolder_copy
if not "%app.web.install.create_destination%"=="1" goto :_DeployToFolder_create_fail
mkdir "%app.install.web.destination%" >nul 2>nul
if exist "%app.install.web.destination%\" goto :_DeployToFolder_copy
:_DeployToFolder_create_fail
echo ERROR: Could not create website destination:
echo   "%app.install.web.destination%"
exit /b 1
:_DeployToFolder_copy
echo Deploying website files...
echo.
if /I "%app.web.install.folder_mode%"=="mirror" goto :_DeployToFolder_mirror
robocopy "%app.install.web.source%" "%app.install.web.destination%" /E /COPY:DAT /DCOPY:DAT /R:2 /W:2 /XJ
set "dtf_rc=%errorlevel%"
goto :_DeployToFolder_result
:_DeployToFolder_mirror
robocopy "%app.install.web.source%" "%app.install.web.destination%" /MIR /COPY:DAT /DCOPY:DAT /R:2 /W:2 /XJ
set "dtf_rc=%errorlevel%"
:_DeployToFolder_result
if %dtf_rc% LSS 8 exit /b 0
echo.
echo ERROR: Robocopy failed with exit code %dtf_rc%.
exit /b 1
:: ============================================================
:: :DeployWithMethodScript
:: Calls a configured external deployment method.
::
:: Usage: call :DeployWithMethodScript
::
:: Returns: method script exit code
:: Requires: configured app.install.web.method_script
:: ============================================================
:DeployWithMethodScript
echo Running deployment method script:
echo   %app.install.web.method_script%
echo.
call "%app.install.web.method_script%"
set "dwms_rc=%errorlevel%"
if "%dwms_rc%"=="0" exit /b 0
echo ERROR: Deployment method script failed with exit code %dwms_rc%.
exit /b %dwms_rc%
:: ============================================================
:: :VerifyDeployment
:: Calls a configured verification script or performs generic folder
:: size/hash verification.
::
:: Usage: call :VerifyDeployment
::
:: Returns: verification result
:: Requires: PowerShell for generic folder verification
:: ============================================================
:VerifyDeployment
if defined app.install.web.verify_script goto :_VerifyDeployment_script
if /I not "%app.web.install.method%"=="folder" goto :_VerifyDeployment_external_none
if /I "%app.web.install.verify_mode%"=="none" goto :_VerifyDeployment_none
set "WEB_INSTALL_VERIFY_SOURCE=%app.install.web.source%"
set "WEB_INSTALL_VERIFY_DEST=%app.install.web.destination%"
set "WEB_INSTALL_VERIFY_MODE=%app.web.install.verify_mode%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $src=[IO.Path]::GetFullPath($env:WEB_INSTALL_VERIFY_SOURCE); $dst=[IO.Path]::GetFullPath($env:WEB_INSTALL_VERIFY_DEST); $mode=$env:WEB_INSTALL_VERIFY_MODE; $files=@(Get-ChildItem -LiteralPath $src -File -Recurse); foreach($file in $files){$rel=$file.FullName.Substring($src.Length).TrimStart('\'); $target=Join-Path $dst $rel; if(-not (Test-Path -LiteralPath $target -PathType Leaf)){Write-Host ('Missing: '+$rel); exit 10}; $other=Get-Item -LiteralPath $target; if($file.Length -ne $other.Length){Write-Host ('Size mismatch: '+$rel); exit 11}; if($mode -eq 'hash'){if((Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash -ne (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash){Write-Host ('Hash mismatch: '+$rel); exit 12}}}; exit 0"
set "vd_rc=%errorlevel%"
set "WEB_INSTALL_VERIFY_SOURCE="
set "WEB_INSTALL_VERIFY_DEST="
set "WEB_INSTALL_VERIFY_MODE="
if "%vd_rc%"=="0" goto :_VerifyDeployment_ok
echo ERROR: Website deployment verification failed with exit code %vd_rc%.
exit /b 1
:_VerifyDeployment_script
echo Running deployment verification script:
echo   %app.install.web.verify_script%
echo.
call "%app.install.web.verify_script%"
set "vd_rc=%errorlevel%"
if "%vd_rc%"=="0" goto :_VerifyDeployment_ok
echo ERROR: Deployment verification script failed with exit code %vd_rc%.
exit /b %vd_rc%
:_VerifyDeployment_external_none
echo WARNING: No generic verification is available for method "%app.web.install.method%".
echo Configure app.web.install.verify_script for method-specific checks.
echo.
exit /b 0
:_VerifyDeployment_none
echo Deployment verification was skipped.
echo.
exit /b 0
:_VerifyDeployment_ok
echo Deployment verification complete.
echo.
exit /b 0
:: ============================================================
:: :SetDeploymentEnvironment
:: Exports deployment values for configured method/verification scripts.
::
:: Usage: call :SetDeploymentEnvironment
::
:: Returns: 0
:: Requires: none
:: ============================================================
:SetDeploymentEnvironment
set "WEB_INSTALL_METHOD=%app.web.install.method%"
set "WEB_INSTALL_SOURCE=%app.install.web.source%"
set "WEB_INSTALL_DESTINATION=%app.install.web.destination%"
set "WEB_INSTALL_FOLDER_MODE=%app.web.install.folder_mode%"
set "WEB_INSTALL_ENTRY_FILE=%app.install.web.entry_file%"
set "WEB_INSTALL_PROJECT_ROOT=%app.install.web.root%"
exit /b 0
:: ============================================================
:: :ClearDeploymentEnvironment
:: Clears temporary WEB_INSTALL_* variables created by this script.
::
:: Usage: call :ClearDeploymentEnvironment
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ClearDeploymentEnvironment
set "WEB_INSTALL_METHOD="
set "WEB_INSTALL_SOURCE="
set "WEB_INSTALL_DESTINATION="
set "WEB_INSTALL_FOLDER_MODE="
set "WEB_INSTALL_ENTRY_FILE="
set "WEB_INSTALL_PROJECT_ROOT="
set "WEB_INSTALL_VALIDATE_SOURCE="
set "WEB_INSTALL_SAFE_SOURCE="
set "WEB_INSTALL_SAFE_DEST="
set "WEB_INSTALL_SAFE_ROOT="
set "WEB_INSTALL_ALLOW_DRIVE_ROOT="
set "WEB_INSTALL_VERIFY_SOURCE="
set "WEB_INSTALL_VERIFY_DEST="
set "WEB_INSTALL_VERIFY_MODE="
exit /b 0
:: ============================================================
:: :ReportSuccess
:: Prints the completed website deployment summary.
::
:: Usage: call :ReportSuccess
::
:: Returns: 0
:: Requires: none
:: ============================================================
:ReportSuccess
echo ============================================================
echo  Website deployment complete
echo ============================================================
echo.
echo Source:
echo   %app.install.web.source%
echo.
echo Destination:
echo   %app.install.web.destination%
echo.
echo Method:
echo   %app.web.install.method%
if /I "%app.web.install.method%"=="folder" echo.
if /I "%app.web.install.method%"=="folder" echo Folder mode:
if /I "%app.web.install.method%"=="folder" echo   %app.web.install.folder_mode%
echo.
echo Files deployed:
echo   %app.install.web.file_count%
if defined app.web.install.url echo.
if defined app.web.install.url echo Website URL:
if defined app.web.install.url echo   %app.web.install.url%
echo.
exit /b 0
