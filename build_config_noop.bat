@echo off
:: ============================================================
:: build_config_noop.bat
:: Supplemental settings used only by build_noop.bat.
::
:: This file is loaded after build_config.bat, so values here may
:: override shared project settings for the no-op build only.
::
:: Do not use setlocal; these values must return to the caller.
:: ============================================================
set "app.noop.default_mode=build"
set "app.noop.title=%app.display_name% demonstrator build"
set "app.noop.description=This demonstrator has no source code to compile."
exit /b 0
