@echo off
:: ============================================================
:: just_status.bat
:: Friendly tools-level launcher for git_status_summary.bat.
::
:: This file is intended to live in:
::   tools\just_status.bat
::
:: A generic root stub named just_status.bat may call this file.
::
:: Usage:
::   call tools\just_status.bat
::   call tools\just_status.bat help
::
:: Returns: git_status_summary.bat result
:: Requires: tools\git_status_summary.bat
:: ============================================================
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
if not defined GIT_PROJECT_ROOT for %%A in ("%~dp0..") do set "GIT_PROJECT_ROOT=%%~fA"
call "%~dp0git_status_summary.bat" %*
set "just_status_rc=%errorlevel%"
exit /b %just_status_rc%
