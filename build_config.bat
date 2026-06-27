@echo off
rem ============================================================
rem build_config.bat
rem Project-specific settings for testprofile_pleaseignore.
rem
rem This file is the authoritative project-root marker.
rem Helper scripts locate it and change to its folder.
rem
rem Do not use setlocal here unless values are intentionally
rem exported back to the calling script.
rem ============================================================

rem ============================================================
rem Project identity
rem ============================================================

set "app.display_name=testprofile_pleaseignore"
set "app.name=testprofile_pleaseignore"

rem This demonstrator repository contains no buildable application.
rem set "app.default_mode=build"

rem ============================================================
rem Project folders
rem ============================================================

set "app.tools_dir=tools"

rem Generic build folders used by some projects.
rem set "app.build_dir=build"
rem set "app.temp_dir=%app.build_dir%\temp"
rem set "app.gen_dir=%app.build_dir%\gen"
rem set "app.classes_dir=%app.build_dir%\classes"
rem set "app.dex_dir=%app.build_dir%\dex"

rem Snapshot-oriented build folder names used by TCC projects.
rem set "app.build_dir_prefix=build"
rem set "app.source_dir_prefix=source"
rem set "app.temp_root=temp"
rem set "app.oldbuilds_dir=oldbuilds"

rem Temporary-file settings.
rem set "app.temp_file_dir=%TEMP%"
rem set "app.temp_file_prefix=%app.name%-build"

rem Timestamp format used by projects that create dated folders/files.
rem set "app.time_format=yyyy-MM-dd.HH'h'mm's'ss"

rem ============================================================
rem Git and GitHub
rem ============================================================

set "app.repo_url=https://github.com/helpersforopenwrt/testprofile_pleaseignore.git"
set "app.git_branch=main"

rem Optional repository-specific Git author identity.
rem If unset, helpers use an existing local/global value or prompt.
rem set "app.git_name=helpersforopenwrt"
rem set "app.git_email="

rem Optional directory for offline Git bundle backups.
rem Relative paths are interpreted from the project root.
rem set "app.git_backup_dir=backups\git"

rem ============================================================
rem Generic run settings
rem ============================================================

rem set "app.run_command=your command here"
rem set "app.run_file=relative\path\to\file"
rem set "app.output_exe=build\program.exe"

rem ============================================================
rem Generic Windows executable project
rem ============================================================

rem set "app.exe=program.exe"

rem ============================================================
rem Tiny C Compiler settings
rem ============================================================

rem set "app.gettcc_script=GetTCC.bat"
rem set "app.tcc_dir=tcc"
rem set "app.tcc_exe_name=tcc.exe"
rem set "app.libs=-luser32 -lgdi32 -lshell32"
rem set "app.tcc_flags=-mwindows"

rem ============================================================
rem Android application identity
rem ============================================================

rem set "app.package_name=org.example.application"

rem ============================================================
rem Android API levels
rem ============================================================

rem set "app.compile_api=22"
rem set "app.min_sdk=14"
rem set "app.target_sdk=22"

rem ============================================================
rem Java compiler settings
rem ============================================================

rem set "app.java_source=8"
rem set "app.java_target=8"

rem ============================================================
rem Android source and resource locations
rem ============================================================

rem set "app.manifest=AndroidManifest.xml"
rem set "app.source_dir=src"
rem set "app.resources_dir=resources"

rem ============================================================
rem Android and Java tools
rem ============================================================

rem set "app.jdk_dir=tools\jdk"
rem set "app.android_sdk_dir=tools\android-sdk"
rem set "app.android_sdk_fallback_dir=android-sdk"
rem set "app.build_tools_version=28.0.3"

rem ============================================================
rem Android build output
rem ============================================================

rem set "app.output_apk=%app.build_dir%\Application-debug.apk"
rem set "app.unsigned_apk=%app.build_dir%\Application-unsigned.apk"
rem set "app.aligned_apk=%app.build_dir%\Application-aligned.apk"
rem set "app.sources_file=%app.build_dir%\sources.txt"
rem set "app.classes_file=%app.build_dir%\classes.txt"

rem ============================================================
rem Android icon and generated strings
rem ============================================================

rem set "app.icon.source=resources\Application.png"
rem set "app.icon.resource=application"
rem set "app.auto_strings=1"

rem ============================================================
rem Android APK signing
rem ============================================================

rem set "app.keystore=tools\debug.keystore"
rem set "app.keystore_alias=androiddebugkey"
rem set "app.keystore_pass=android"

rem ============================================================
rem Android application launch
rem ============================================================

rem set "app.launch_activity=org.example.application/.MainActivity"

rem ============================================================
rem Generated resource groups
rem
rem app.resource.lbound is optional and normally defaults to 0.
rem app.resource.ubound is inclusive.
rem Leave app.resource.ubound undefined when no groups are used.
rem ============================================================

rem set "app.resource.lbound=0"
rem set "app.resource.ubound="

rem Example generated resource group: theme files.
rem set "app.resource[0].id=theme"
rem set "app.resource[0].label=theme resources"
rem set "app.resource[0].enabled=1"
rem set "app.resource[0].kind=theme"
rem set "app.resource[0].root=themes"
rem set "app.resource[0].include=*"
rem set "app.resource[0].generator=generate_theme_resources.ps1"
rem set "app.resource[0].output=theme_resources_generated.c"
rem set "app.resource[0].hash=.theme_resources.hash"
rem set "app.resource[0].hash_new=.theme_resources.hash.new"
rem set "app.resource[0].group=theme"
rem set "app.resource[0].legacy_output="

rem Example generated resource group: embedded INI files.
rem set "app.resource[1].id=ini"
rem set "app.resource[1].label=INI resources"
rem set "app.resource[1].enabled=1"
rem set "app.resource[1].kind=embedded"
rem set "app.resource[1].root=."
rem set "app.resource[1].include=*.ini"
rem set "app.resource[1].generator=generate_embedded_resources.ps1"
rem set "app.resource[1].output=embedded_resources_generated.c"
rem set "app.resource[1].hash=.embedded_resources.hash"
rem set "app.resource[1].hash_new=.embedded_resources.hash.new"
rem set "app.resource[1].group=ini"
rem set "app.resource[1].legacy_output=ini_resources_generated.c"

exit /b 0
