@echo off
:: ============================================================
:: just_status.bat
:: Root launcher for the read-only Git status summary.
::
:: Usage:
::   just_status.bat
::   just_status.bat help
::
:: Returns: git_status_summary.bat result
:: Requires: tools\git_status_summary.bat
:: ============================================================
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "GIT_PROJECT_ROOT=%~dp0"
call "%~dp0tools\git_status_summary.bat" %*
set "just_status_rc=%errorlevel%"
set "GIT_PROJECT_ROOT="
exit /b %just_status_rc%
