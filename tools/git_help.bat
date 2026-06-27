@echo off
setlocal EnableExtensions
call "%~dp0_common.bat" init
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  %APP_DISPLAY_NAME% helper commands
echo ============================================================
echo.
echo Project root:
echo   %CD%
echo.
echo Root discovery order:
echo   1. current folder\build_config.bat
echo   2. parent folder\build_config.bat
echo   3. current folder\build.bat
echo   4. parent folder\build.bat
echo.
echo build_config.bat is preferred and is the authoritative root marker.
echo.
echo Common commands:
echo   just_status.bat       Show Git state and recommendation.
echo   just_diff.bat         Show changed files and diff summaries.
echo   just_commit.bat       Commit local changes without pushing.
echo   just_push.bat         Push existing local commits.
echo   just_getlatest.bat    Safely fast-forward from GitHub.
echo   just_help.bat         Show this help.
echo.
echo Other commands in tools:
echo   just_build.bat
echo   just_check.bat
echo   just_compileandrun.bat
echo   just_run.bat
echo   just_history.bat
echo   just_backup.bat
echo   just_verifygithub.bat
echo   git_commit_and_push_now.bat
echo   git_login.bat
echo   git_discard_local_changes_DANGEROUS.bat
echo.
echo Root shortcut files are identical. Each uses its own filename
echo to call the matching script under tools.
echo.
pause
exit /b 0
