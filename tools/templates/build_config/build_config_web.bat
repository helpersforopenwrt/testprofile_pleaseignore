@echo off
:: ============================================================
:: build_config_web.bat
:: Dual-use configuration template for framework-free websites.
::
:: This file supports two roles:
::
::   1. Web suffix configuration
::      Keep the name:
::        build_config_web.bat
::
::      Use it beside a shared:
::        build_config.bat
::
::      Shared project identity, repository metadata, and common
::      folders normally belong in build_config.bat. Website build
::      and deployment settings belong in this file.
::
::   2. Standalone website configuration
::      Rename or copy this file to:
::        build_config.bat
::
::      It then supplies safe shared project defaults plus all current
::      build_web.bat and install_web.bat settings. No separate
::      build_config_web.bat is required for a website-only project.
::
:: Shared defaults use "if not defined", so this file never replaces
:: values already loaded from a shared build_config.bat.
::
:: Current consumers:
::   build_web.bat
::   install_web.bat
::
:: Future specialized suffixes may extend or replace these settings:
::   build_config_web_composer.bat
::   build_config_web_node.bat
::   build_config_web_static.bat
::   build_config_web_frameworkname.bat
::
:: Do not use setlocal. Values must remain available to callers.
::
:: Boolean convention:
::   0 = disabled
::   1 = enabled
:: ============================================================
:: ============================================================
:: CONFIGURATION ROLE
:: ============================================================
set "app.config.web.file=%~nx0"
set "app.config.web.role="
if /I "%~nx0"=="build_config_web.bat" set "app.config.web.role=suffix"
if /I "%~nx0"=="build_config.bat" set "app.config.web.role=standalone"
if not defined app.config.web.role set "app.config.web.role=standalone-compatible"
:: ============================================================
:: ============================================================
:: SHARED PROJECT SETTINGS
::
:: In suffix role, these normally come from build_config.bat.
:: In standalone role, edit these values for the website project.
:: ============================================================
:: ============================================================
:: Project identity
:: ============================================================
if not defined app.display_name set "app.display_name=Website"
if not defined app.name set "app.name=%app.display_name%"
if not defined app.default_mode set "app.default_mode=build"
:: ============================================================
:: Shared project folders
:: ============================================================
if not defined app.tools_dir set "app.tools_dir=tools"
if not defined app.build_dir_prefix set "app.build_dir_prefix=build"
if not defined app.source_dir_prefix set "app.source_dir_prefix=source"
if not defined app.temp_root set "app.temp_root=temp"
if not defined app.oldbuilds_dir set "app.oldbuilds_dir=oldbuilds"
if not defined app.temp_file_dir set "app.temp_file_dir=%TEMP%"
if not defined app.temp_file_prefix set "app.temp_file_prefix=%app.name%-web"
if not defined app.time_format set "app.time_format=yyyy-MM-dd.HH'h'mm's'ss"
:: ============================================================
:: Repository, Git, and GitHub
:: ============================================================
:: Canonical repository URL.
:: set "app.repo_url=https://github.com/owner/website.git"
:: Preferred branch.
if not defined app.git_branch set "app.git_branch=main"
:: Explicit repository detection overrides are usually unnecessary.
:: set "app.repository.scm=git"
:: set "app.repository.provider=github"
:: set "app.repository.url=%app.repo_url%"
:: Optional repository-specific Git author identity.
:: set "app.git_name=Example Author"
:: set "app.git_email=author@example.invalid"
:: Optional offline Git bundle backup directory.
:: set "app.git_backup_dir=backups\git"
:: ============================================================
:: Generic run settings
:: ============================================================
:: These are available to generic project helpers but are not required
:: by build_web.bat or install_web.bat.
:: set "app.run_command=php -S 127.0.0.1:8000"
:: set "app.run_file=index.php"
:: ============================================================
:: ============================================================
:: WEB BUILD SETTINGS
::
:: These settings are consumed by build_web.bat.
:: ============================================================
:: ============================================================
:: Website build identity and mode
:: ============================================================
if not defined app.web.default_mode set "app.web.default_mode=%app.default_mode%"
if not defined app.web.default_mode set "app.web.default_mode=build"
if not defined app.web.title set "app.web.title=%app.display_name% website build"
if not defined app.web.description set "app.web.description=Framework-free website package."
:: Supported build modes:
::   build
::   rebuild
::   nosync
::   check
::   clean
::   help
:: ============================================================
:: Website entry file
:: ============================================================
:: Leave app.web.entry_file undefined to let build_web.bat detect:
::   index.php
::   index.html
::   index.htm
::
:: Set it explicitly when the site uses another entry point.
:: set "app.web.entry_file=index.php"
if not defined app.web.require_entry set "app.web.require_entry=1"
:: require_entry=1 fails when the configured or detected entry file is
:: missing from both the project and final deployment package.
:: ============================================================
:: PHP syntax checking
:: ============================================================
:: Values:
::   auto
::     Run php -l on every packaged PHP file when php.exe is available.
::     Warn and continue when PHP is unavailable.
::
::   required
::     Fail when PHP files exist and php.exe is unavailable.
::
::   off
::     Never run PHP syntax checking.
if not defined app.web.php_lint set "app.web.php_lint=auto"
:: ============================================================
:: Dated website output layout
:: ============================================================
if not defined app.web.build_dir_prefix set "app.web.build_dir_prefix=%app.build_dir_prefix%"
if not defined app.web.build_dir_prefix set "app.web.build_dir_prefix=build"
if not defined app.web.source_dir_prefix set "app.web.source_dir_prefix=%app.source_dir_prefix%"
if not defined app.web.source_dir_prefix set "app.web.source_dir_prefix=source"
if not defined app.web.oldbuilds_dir set "app.web.oldbuilds_dir=%app.oldbuilds_dir%"
if not defined app.web.oldbuilds_dir set "app.web.oldbuilds_dir=oldbuilds"
if not defined app.web.temp_root set "app.web.temp_root=%app.temp_root%"
if not defined app.web.temp_root set "app.web.temp_root=temp"
:: Successful builds create:
::   build_YYYY-MM-DD.HHhmm.ss\
::   source_YYYY-MM-DD.HHhmm.ss\
::
:: Older dated folders move into:
::   oldbuilds\
:: ============================================================
:: Deployable directory exclusions
:: ============================================================
:: Semicolon-separated exact directory names.
::
:: build_web.bat also independently excludes:
::   .git
::   build_*
::   source_*
::   oldbuilds
::   temp
::
:: Add project-specific development, cache, test, documentation, or
:: secret directories here.
if not defined app.web.deploy.exclude_dirs set "app.web.deploy.exclude_dirs=.git;tools;%app.web.oldbuilds_dir%;%app.web.temp_root%;.github;.idea;.vscode;node_modules"
:: Example additions:
:: set "app.web.deploy.exclude_dirs=%app.web.deploy.exclude_dirs%;tests;docs;cache;vendor-dev"
:: Do not exclude a runtime directory merely because it is writable.
:: Decide whether the deployment package should create it, preserve it,
:: or initialize it through a deployment/setup script.
:: ============================================================
:: Deployable file exclusions
:: ============================================================
:: Semicolon-separated file names, relative paths, or wildcard patterns.
::
:: The default excludes project helpers, source-control metadata,
:: documentation, and common environment-secret files.
if not defined app.web.deploy.exclude_files set "app.web.deploy.exclude_files=build.bat;build_*.bat;build_config*.bat;prepare.bat;prepare_*.bat;install.bat;install_*.bat;just_*.bat;README*;.gitignore;.gitattributes;.env;.env.*"
:: Example additions:
:: set "app.web.deploy.exclude_files=%app.web.deploy.exclude_files%;phpunit.xml;*.test.php;notes.txt"
:: ============================================================
:: Mutable runtime files
:: ============================================================
:: Files changed by the live website should usually not be overwritten
:: during every deployment.
::
:: For the example phase-task website, task-status.json is mutable.
:: One safe approach is to exclude it from the build and let
:: setup-permissions.sh create it on the server:
::
:: set "app.web.deploy.exclude_files=%app.web.deploy.exclude_files%;task-status.json"
::
:: Another approach is a custom deployment method that preserves the
:: existing destination copy while installing all other files.
::
:: The generic folder copy method overwrites every source file that is
:: present in the build package. It preserves destination-only files in
:: copy mode and removes them in mirror mode.
:: ============================================================
:: Source snapshot behavior
:: ============================================================
:: In a Git worktree, build_web.bat includes:
::   tracked files
::   untracked, nonignored files
::
:: It excludes Git-ignored files and generated lifecycle folders.
::
:: Outside Git, it uses recursive filesystem discovery and cannot
:: interpret source-control ignore files.
:: ============================================================
:: ============================================================
:: WEB INSTALL SETTINGS
::
:: These settings are consumed by install_web.bat.
:: ============================================================
:: ============================================================
:: Install mode and deployment method
:: ============================================================
if not defined app.web.install.default_mode set "app.web.install.default_mode=install"
if not defined app.web.install.method set "app.web.install.method=folder"
:: Supported generic modes:
::   install
::   check
::   plan
::   help
::
:: Implemented method:
::   folder
::
:: Future/custom method examples:
::   scp
::   sftp
::   rsync
::   ftp
::   cloud
::   container
::   provider-specific
:: ============================================================
:: Build folder selection
:: ============================================================
if not defined app.web.install.build_dir_prefix set "app.web.install.build_dir_prefix=%app.web.build_dir_prefix%"
if not defined app.web.install.require_entry set "app.web.install.require_entry=%app.web.require_entry%"
:: Leave the install entry file undefined to inherit the build entry.
if not defined app.web.install.entry_file if defined app.web.entry_file set "app.web.install.entry_file=%app.web.entry_file%"
:: install_web.bat selects the newest matching dated build folder unless
:: the command line supplies:
::   install_web.bat build build_YYYY-MM-DD.HHhmm.ss
:: ============================================================
:: Folder deployment destination
:: ============================================================
:: Intentionally no active default is supplied. A generic template must
:: not guess a real deployment destination.
::
:: Mapped-drive or mounted Samba share:
:: set "app.web.install.destination=T:\phase-task-website"
::
:: UNC share:
:: set "app.web.install.destination=\\server\share\phase-task-website"
::
:: Local web root:
:: set "app.web.install.destination=C:\inetpub\wwwroot\phase-task-website"
::
:: Command-line override:
::   install_web.bat destination T:\phase-task-website
if not defined app.web.install.destination set "app.web.install.destination="
:: ============================================================
:: Folder deployment behavior
:: ============================================================
:: Values:
::   copy
::     Copy and overwrite source files while preserving unrelated
::     destination-only files. This is the safe default.
::
::   mirror
::     Make the destination match the source and remove destination-only
::     files. Use only for a dedicated deployment directory.
if not defined app.web.install.folder_mode set "app.web.install.folder_mode=copy"
:: Create a missing destination folder automatically.
if not defined app.web.install.create_destination set "app.web.install.create_destination=1"
:: Direct deployment to a drive root such as T:\ is blocked by default.
:: Prefer a dedicated subfolder.
if not defined app.web.install.allow_drive_root set "app.web.install.allow_drive_root=0"
:: ============================================================
:: Deployment confirmation
:: ============================================================
:: Type DEPLOY before files are copied unless disabled or command-line
:: argument "yes" is supplied.
if not defined app.web.install.confirm set "app.web.install.confirm=1"
:: ============================================================
:: Folder deployment verification
:: ============================================================
:: Values:
::   size
::     Verify every source file exists at the destination with the same
::     byte length. Fast and suitable for normal local/share copies.
::
::   hash
::     Verify every source file with SHA-256. Slower over network shares.
::
::   none
::     Skip generic verification.
if not defined app.web.install.verify_mode set "app.web.install.verify_mode=size"
:: ============================================================
:: Deployment environment file
:: ============================================================
:: Applied before resolving source and destination. It can set mapped
:: drive, credential-helper, SSH, or other deployment environment data.
if not defined app.web.install.env_file set "app.web.install.env_file=env.bat"
:: ============================================================
:: Optional public website URL
:: ============================================================
:: Printed after successful deployment.
:: set "app.web.install.url=https://example.com/"
if not defined app.web.install.url set "app.web.install.url="
:: ============================================================
:: External deployment method script
:: ============================================================
:: Required when app.web.install.method is not "folder".
::
:: Relative paths are resolved from the project root.
:: set "app.web.install.method_script=tools\deploy_scp.bat"
if not defined app.web.install.method_script set "app.web.install.method_script="
:: The script receives:
::   WEB_INSTALL_METHOD
::   WEB_INSTALL_SOURCE
::   WEB_INSTALL_DESTINATION
::   WEB_INSTALL_FOLDER_MODE
::   WEB_INSTALL_ENTRY_FILE
::   WEB_INSTALL_PROJECT_ROOT
::
:: All app.web.install.* configuration variables also remain available
:: because the method script is called in the current cmd.exe.
:: ============================================================
:: Optional deployment verification script
:: ============================================================
:: A configured script replaces generic size/hash verification.
:: It is useful for remote deployments or application-level checks.
:: set "app.web.install.verify_script=tools\verify_web_deployment.bat"
if not defined app.web.install.verify_script set "app.web.install.verify_script="
:: The verification script receives the same WEB_INSTALL_* variables.
:: ============================================================
:: ============================================================
:: FUTURE SCP/SFTP METHOD PROVISION
::
:: These names are suggestions for a future deploy_scp.bat or
:: deploy_sftp.bat. install_web.bat does not interpret them directly.
:: A configured method script can read them.
:: ============================================================
:: set "app.web.install.method=scp"
:: set "app.web.install.method_script=tools\deploy_scp.bat"
:: set "app.web.install.verify_script=tools\verify_scp.bat"
:: set "app.web.install.destination=/var/www/phase-task-website"
:: set "app.web.install.scp.host=example.com"
:: set "app.web.install.scp.user=deploy"
:: set "app.web.install.scp.port=22"
:: set "app.web.install.scp.identity_file=%USERPROFILE%\.ssh\id_ed25519"
:: set "app.web.install.scp.options="
:: set "app.web.install.scp.preserve_runtime_files=task-status.json"
:: ============================================================
:: ============================================================
:: FUTURE RSYNC METHOD PROVISION
::
:: These names are suggestions for a future deploy_rsync.bat.
:: ============================================================
:: set "app.web.install.method=rsync"
:: set "app.web.install.method_script=tools\deploy_rsync.bat"
:: set "app.web.install.verify_script=tools\verify_rsync.bat"
:: set "app.web.install.destination=deploy@example.com:/var/www/site/"
:: set "app.web.install.rsync.executable=rsync.exe"
:: set "app.web.install.rsync.options=-az --delete-delay"
:: set "app.web.install.rsync.exclude=task-status.json"
:: ============================================================
:: ============================================================
:: FUTURE PREPARE_WEB PROVISION
::
:: prepare_web.bat has not been defined yet. Avoid treating these names
:: as a final contract until that implementation is created.
::
:: Likely preparation responsibilities:
::   - locate PHP when PHP linting or a local PHP server is requested
::   - locate Robocopy for folder deployment
::   - locate OpenSSH/scp/sftp for remote deployment methods
::   - load or write deployment environment settings
::   - validate mapped-drive or UNC availability
::   - never expose credentials in logs or committed configuration
:: ============================================================
:: ============================================================
:: WEBSITE-SPECIFIC CUSTOMIZATION EXAMPLE
::
:: Example settings for the supplied phase-task PHP website:
:: ============================================================
:: set "app.display_name=Phase Task Website"
:: set "app.name=phase-task-website"
:: set "app.repo_url=https://github.com/owner/phase-task-website.git"
:: set "app.web.entry_file=index.php"
:: set "app.web.php_lint=auto"
:: set "app.web.deploy.exclude_files=%app.web.deploy.exclude_files%;task-status.json"
:: set "app.web.install.destination=T:\phase-task-website"
:: set "app.web.install.folder_mode=copy"
:: set "app.web.install.verify_mode=size"
:: set "app.web.install.url=http://phase-task.local/"
:: ============================================================
:: ============================================================
:: STANDALONE USE CHECKLIST
::
:: To use this as the only configuration file:
::
::   1. Rename it to build_config.bat.
::   2. Set app.display_name and app.name.
::   3. Set app.repo_url when appropriate.
::   4. Set app.web.entry_file or keep automatic entry detection.
::   5. Review deployment exclusions, especially mutable runtime files.
::   6. Set app.web.install.destination.
::   7. Keep folder/copy/size for a safe first deployment.
::
:: build_web.bat and install_web.bat then require no separate
:: build_config_web.bat.
:: ============================================================
:: ============================================================
:: SUFFIX USE CHECKLIST
::
:: To use this beside a shared build_config.bat:
::
::   1. Keep the name build_config_web.bat.
::   2. Put shared identity and repository values in build_config.bat.
::   3. Put website package and deployment values here.
::   4. Shared fallbacks in this file do not replace loaded values.
:: ============================================================
exit /b 0
