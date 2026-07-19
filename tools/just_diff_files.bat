@echo off
:: ============================================================
:: just_diff_files.bat
:: Tools-level launcher for git_diff_files.bat.
::
:: Usage:
::   call tools\just_diff_files.bat [unstaged|staged|both] PATH [PATH...]
::
:: Returns: git_diff_files.bat result
:: Requires: tools\git_diff_files.bat
:: ============================================================
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
if not defined GIT_PROJECT_ROOT for %%A in ("%~dp0..") do set "GIT_PROJECT_ROOT=%%~fA"
call "%~dp0git_diff_files.bat" %*
set "just_diff_files_rc=%errorlevel%"
exit /b %just_diff_files_rc%
