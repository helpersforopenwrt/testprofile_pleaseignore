@echo off
:: ============================================================
:: just_diff_check.bat
:: Friendly tools-level launcher for git_diff_check.bat.
::
:: Intended location:
::   tools\just_diff_check.bat
::
:: A generic root stub with the same name may call this file.
::
:: Usage:
::   call tools\just_diff_check.bat [both|unstaged|staged|noprompt]
::
:: Returns: git_diff_check.bat result
:: Requires: tools\git_diff_check.bat
:: ============================================================
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
if not defined GIT_PROJECT_ROOT for %%A in ("%~dp0..") do set "GIT_PROJECT_ROOT=%%~fA"
call "%~dp0git_diff_check.bat" %*
set "just_diff_check_rc=%errorlevel%"
exit /b %just_diff_check_rc%
