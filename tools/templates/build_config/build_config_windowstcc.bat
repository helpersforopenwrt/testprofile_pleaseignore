@echo off
:: ============================================================
:: build_config.bat
:: Project-specific build settings for FindReplaceMark.
::
:: This file is called by build.bat if it exists.
:: Do not use setlocal here unless you intentionally export values back.
:: ============================================================

set "app.display_name=FindReplaceMark"
set "app.name=window"
set "app.exe=window.exe"
set "app.default_mode=build"

set "app.repo_url=https://github.com/npp-findreplace-prototype/npp-findreplace-prototype.git"

set "app.gettcc_script=GetTCC.bat"
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

:: ============================================================
:: Resource groups
::
:: app.resource.lbound is optional and defaults to 0.
:: app.resource.ubound is inclusive.
:: ============================================================

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