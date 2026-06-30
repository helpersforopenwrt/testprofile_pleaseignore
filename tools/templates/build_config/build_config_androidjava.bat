@echo off
:: ============================================================
:: build_config.bat
:: Project-specific build settings for FoodSnap.
::
:: This file is called by build.bat.
:: Do not use setlocal here unless you intentionally export values back.
:: ============================================================

set "app.display_name=FoodSnap"
set "app.name=FoodSnap"
set "app.package_name=org.foodsnap"
set "app.default_mode=build"

set "app.compile_api=22"
set "app.min_sdk=14"
set "app.target_sdk=22"

set "app.java_source=8"
set "app.java_target=8"

set "app.manifest=AndroidManifest.xml"
set "app.source_dir=src"
set "app.resources_dir=resources"

set "app.tools_dir=tools"
set "app.jdk_dir=tools\jdk"
set "app.android_sdk_dir=tools\android-sdk"
set "app.android_sdk_fallback_dir=android-sdk"
set "app.build_tools_version=28.0.3"

set "app.build_dir=build"
set "app.temp_dir=%app.build_dir%\temp"
set "app.gen_dir=%app.build_dir%\gen"
set "app.classes_dir=%app.build_dir%\classes"
set "app.dex_dir=%app.build_dir%\dex"
set "app.output_apk=%app.build_dir%\FoodSnap-debug.apk"
set "app.unsigned_apk=%app.build_dir%\FoodSnap-unsigned.apk"
set "app.aligned_apk=%app.build_dir%\FoodSnap-aligned.apk"

set "app.sources_file=%app.build_dir%\sources.txt"
set "app.classes_file=%app.build_dir%\classes.txt"

set "app.icon.source=resources\FoodSnap.png"
set "app.icon.resource=foodsnap"
set "app.auto_strings=1"

set "app.keystore=tools\debug.keystore"
set "app.keystore_alias=androiddebugkey"
set "app.keystore_pass=android"

set "app.launch_activity=org.foodsnap/.MainActivity"

set "app.repo_url=https://github.com/FoodSnap2/FoodSnap.git"
set "app.git_branch=main"
set "app.git_name=FoodSnap2"
set "app.git_email="



exit /b 0
