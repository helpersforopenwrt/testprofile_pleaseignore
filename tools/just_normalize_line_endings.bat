@echo off
:: ============================================================
:: just_normalize_line_endings.bat
:: Friendly tools-level launcher for git_normalize_line_endings.bat.
::
:: Intended location:
::   tools\just_normalize_line_endings.bat
::
:: A generic root stub with the same name may call this file.
::
:: Usage:
::   call tools\just_normalize_line_endings.bat [arguments]
::
:: Returns: git_normalize_line_endings.bat result
:: Requires: tools\git_normalize_line_endings.bat
:: ============================================================
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
if not defined GIT_PROJECT_ROOT for %%A in ("%~dp0..") do set "GIT_PROJECT_ROOT=%%~fA"
call "%~dp0git_normalize_line_endings.bat" %*
set "just_normalize_line_endings_rc=%errorlevel%"
exit /b %just_normalize_line_endings_rc%
