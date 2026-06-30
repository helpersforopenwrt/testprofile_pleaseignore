@echo off
:: ============================================================
:: just_check_tracked_files.bat
:: Friendly tools-level launcher for git_check_tracked_files.bat.
::
:: This file is intended to live in:
::   tools\just_check_tracked_files.bat
::
:: A generic root stub with the same name may call this file.
::
:: Usage:
::   call tools\just_check_tracked_files.bat PATH [PATH...]
::   call tools\just_check_tracked_files.bat help
::
:: Returns: git_check_tracked_files.bat result
:: Requires: tools\git_check_tracked_files.bat
:: ============================================================
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
if not defined GIT_PROJECT_ROOT for %%A in ("%~dp0..") do set "GIT_PROJECT_ROOT=%%~fA"
call "%~dp0git_check_tracked_files.bat" %*
set "just_check_tracked_rc=%errorlevel%"
exit /b %just_check_tracked_rc%
