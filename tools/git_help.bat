@echo off
:: ============================================================
:: git_help.bat
:: Displays the complete reference for all 50 public git_*.bat
:: helpers, followed by shared support utilities and an index.
::
:: Usage:
::   call tools\git_help.bat
::
:: Returns: 0 after displaying help
::          _common.bat exit code when initialization fails
:: Requires: _common.bat, :Main, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_help.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_help.rc=%errorlevel%"
goto :end
:run
call :Main
set "app.git_help.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_help.rc%
:: ============================================================
:: :Main
:: Prints detailed usage, descriptions, and examples for every
:: public Git and GitHub helper.
::
:: Usage: call :Main
::
:: Returns: 0
:: Requires: none
:: ============================================================
:Main
echo(
echo(============================================================
echo( Complete Git and GitHub helper reference
echo(============================================================
echo(
echo(Project:
echo(  %APP_DISPLAY_NAME%
echo(
echo(Run commands from the repository root. Root just_*.bat wrappers
echo(are optional; every implementation remains available under tools.
echo(Arguments in square brackets are optional.
echo(
echo(============================================================
echo(git_abort_operation.bat - Detects and aborts an active merge, rebase, cherry-pick, or revert.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_abort_operation.bat [operation OPERATION]
echo(
echo(Examples:
echo(  tools\git_abort_operation.bat
echo(  tools\git_abort_operation.bat operation merge
echo(
echo(============================================================
echo(git_amend_last_commit.bat - Amends the newest local commit and refuses pushed history by default.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_amend_last_commit.bat [message TEXT] [stage yes^|no] [allowpushed yes^|no]
echo(
echo(Examples:
echo(  tools\git_amend_last_commit.bat message "Corrected message"
echo(  tools\git_amend_last_commit.bat stage yes
echo(
echo(============================================================
echo(git_archive_source.bat - Creates a ZIP from files committed at a selected revision.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_archive_source.bat [revision REV] [output FILE.zip] [prefix FOLDER] [overwrite yes^|no]
echo(
echo(Examples:
echo(  tools\git_archive_source.bat revision v1.0.0
echo(  tools\git_archive_source.bat revision HEAD output releases\source.zip
echo(
echo(============================================================
echo(git_backup_bundle.bat - Creates a portable Git bundle containing committed repository history.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_backup_bundle.bat
echo(
echo(Examples:
echo(  tools\git_backup_bundle.bat
echo(
echo(============================================================
echo(git_blame_file.bat - Shows the commit and author responsible for selected file lines.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_blame_file.bat path FILE [revision REV] [start N] [end N] [ignorewhitespace yes^|no]
echo(
echo(Examples:
echo(  tools\git_blame_file.bat path README.md
echo(  tools\git_blame_file.bat path README.md start 10 end 30
echo(
echo(============================================================
echo(git_check_ignored_files.bat - Checks ignored and untracked local dependency paths.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_check_ignored_files.bat
echo(
echo(Examples:
echo(  tools\git_check_ignored_files.bat
echo(
echo(============================================================
echo(git_check_remotes.bat - Checks remote URLs, reachability, configuration, and permissions.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_check_remotes.bat
echo(
echo(Examples:
echo(  tools\git_check_remotes.bat
echo(
echo(============================================================
echo(git_checkout_pull_request.bat - Checks out a GitHub pull request locally for inspection or testing.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_checkout_pull_request.bat number N [repo OWNER/REPO] [branch NAME] [detach yes^|no] [allowclosed yes^|no]
echo(
echo(Examples:
echo(  tools\git_checkout_pull_request.bat number 12
echo(  tools\git_checkout_pull_request.bat number 12 branch review-pr-12
echo(
echo(============================================================
echo(git_cherry_pick.bat - Applies one existing commit to the current branch.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_cherry_pick.bat commit REV [mainline N] [nocommit yes^|no]
echo(
echo(Examples:
echo(  tools\git_cherry_pick.bat commit abc123
echo(  tools\git_cherry_pick.bat commit abc123 nocommit yes
echo(
echo(============================================================
echo(git_clean_preview.bat - Previews untracked or ignored paths without deleting anything.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_clean_preview.bat [mode untracked^|ignored^|all]
echo(
echo(Examples:
echo(  tools\git_clean_preview.bat
echo(  tools\git_clean_preview.bat mode all
echo(
echo(============================================================
echo(git_clone_repository.bat - Clones a repository into a new empty destination.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_clone_repository.bat repo URL_OR_OWNER/REPO [destination FOLDER] [branch NAME] [login yes^|no]
echo(
echo(Examples:
echo(  tools\git_clone_repository.bat repo OWNER/REPO
echo(  tools\git_clone_repository.bat repo OWNER/REPO destination C:\work\repo
echo(
echo(============================================================
echo(git_commit_and_push_now.bat - Stages, commits, and pushes current changes in one workflow.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_commit_and_push_now.bat
echo(
echo(Examples:
echo(  tools\git_commit_and_push_now.bat
echo(
echo(============================================================
echo(git_compare_branches.bat - Compares unique commits and file changes between revisions.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_compare_branches.bat [left REV] [right REV] [fetch yes^|no]
echo(
echo(Examples:
echo(  tools\git_compare_branches.bat main feature/test
echo(  tools\git_compare_branches.bat left origin/main right HEAD fetch no
echo(
echo(============================================================
echo(git_continue_operation.bat - Continues an active merge, rebase, cherry-pick, or revert.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_continue_operation.bat [operation OPERATION]
echo(
echo(Examples:
echo(  tools\git_continue_operation.bat
echo(  tools\git_continue_operation.bat operation cherry-pick
echo(
echo(============================================================
echo(git_create_branch.bat - Creates and switches to a new branch, optionally publishing it.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_create_branch.bat [name BRANCH] [start REV] [push yes^|no] [allowdirty yes^|no]
echo(
echo(Examples:
echo(  tools\git_create_branch.bat feature/new-tool
echo(  tools\git_create_branch.bat name feature/new-tool push yes
echo(
echo(============================================================
echo(git_create_issue.bat - Creates a GitHub issue after preview and typed confirmation.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_create_issue.bat title TEXT [body TEXT] [labels LIST] [assignees LIST] [milestone NAME] [repo OWNER/REPO]
echo(
echo(Examples:
echo(  tools\git_create_issue.bat title "Build fails on Windows"
echo(  tools\git_create_issue.bat title "Bug" labels "bug,windows"
echo(
echo(============================================================
echo(git_create_pull_request.bat - Creates a GitHub pull request from the current branch.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_create_pull_request.bat [base BRANCH] [title TEXT] [body TEXT] [draft yes^|no] [push yes^|no]
echo(
echo(Examples:
echo(  tools\git_create_pull_request.bat base main title "Add feature"
echo(  tools\git_create_pull_request.bat draft yes push yes
echo(
echo(============================================================
echo(git_create_release.bat - Creates a GitHub release from an existing local tag.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_create_release.bat tag TAG [title TEXT] [notes TEXT] [draft yes^|no] [prerelease yes^|no] [pushtag yes^|no]
echo(
echo(Examples:
echo(  tools\git_create_release.bat tag v1.0.0
echo(  tools\git_create_release.bat tag v1.0.0 draft yes
echo(
echo(============================================================
echo(git_create_repository.bat - Creates a new independent GitHub repository from local history.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_create_repository.bat [owner OWNER] [name NAME] [source URL] [visibility public^|private^|internal] [branch NAME] [message TEXT]
echo(
echo(Examples:
echo(  tools\git_create_repository.bat
echo(  tools\git_create_repository.bat owner myorg name newrepo visibility private
echo(
echo(============================================================
echo(git_create_tag.bat - Creates an annotated tag and optionally pushes it.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_create_tag.bat [name TAG] [message TEXT] [target REV] [push yes^|no]
echo(
echo(Examples:
echo(  tools\git_create_tag.bat v1.0.0
echo(  tools\git_create_tag.bat name v1.0.0 message "First release" push yes
echo(
echo(============================================================
echo(git_delete_branch.bat - Deletes a non-current local branch and optionally its origin branch.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_delete_branch.bat [name BRANCH] [remote yes^|no] [force yes^|no]
echo(
echo(Examples:
echo(  tools\git_delete_branch.bat feature/old
echo(  tools\git_delete_branch.bat name feature/old remote yes
echo(
echo(============================================================
echo(git_discard_local_changes_DANGEROUS.bat - Permanently resets tracked changes and removes untracked non-ignored paths.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_discard_local_changes_DANGEROUS.bat
echo(
echo(Examples:
echo(  tools\git_discard_local_changes_DANGEROUS.bat
echo(
echo(============================================================
echo(git_doctor.bat - Runs comprehensive diagnostics for Git, GitHub, remotes, and helpers.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_doctor.bat
echo(
echo(Examples:
echo(  git_doctor.bat
echo(  tools\git_doctor.bat
echo(
echo(============================================================
echo(git_find_conflicts.bat - Reports unresolved index entries and the active Git operation.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_find_conflicts.bat [details yes^|no]
echo(
echo(Examples:
echo(  tools\git_find_conflicts.bat
echo(  tools\git_find_conflicts.bat details no
echo(
echo(============================================================
echo(git_find_large_files.bat - Finds the largest tracked files and historical Git blobs.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_find_large_files.bat [mode tracked^|history^|both] [limit N] [minimumbytes N]
echo(
echo(Examples:
echo(  tools\git_find_large_files.bat
echo(  tools\git_find_large_files.bat mode history limit 30
echo(
echo(============================================================
echo(git_fork.bat - Creates a true fork or delegates a same-owner repository copy.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_fork.bat [source REPO] [owner OWNER] [name NAME] [visibility public^|private^|internal]
echo(
echo(Examples:
echo(  tools\git_fork.bat
echo(  tools\git_fork.bat source OWNER/REPO owner myaccount
echo(
echo(============================================================
echo(git_generate_changelog.bat - Generates a Markdown changelog between two commit revisions.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_generate_changelog.bat from REV to REV [output FILE] [merges yes^|no] [overwrite yes^|no]
echo(
echo(Examples:
echo(  tools\git_generate_changelog.bat from v1.0.0 to v1.1.0
echo(  tools\git_generate_changelog.bat from v1.0.0 to HEAD output CHANGELOG.md
echo(
echo(============================================================
echo(git_get_latest.bat - Fetches tracking data and applies only a clean fast-forward update.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_get_latest.bat
echo(
echo(Examples:
echo(  just_getlatest.bat
echo(  tools\git_get_latest.bat
echo(
echo(============================================================
echo(git_help.bat - Displays the complete Git and GitHub helper reference.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_help.bat
echo(
echo(Examples:
echo(  just_help.bat
echo(  tools\git_help.bat
echo(
echo(============================================================
echo(git_help_short.bat - Displays a compact categorized helper reference.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_help_short.bat
echo(
echo(Examples:
echo(  just_short_help.bat
echo(  tools\git_help_short.bat
echo(
echo(============================================================
echo(git_list_branches.bat - Lists local and remote branches with optional refresh.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_list_branches.bat [scope local^|remote^|all] [fetch yes^|no]
echo(
echo(Examples:
echo(  tools\git_list_branches.bat
echo(  tools\git_list_branches.bat scope remote
echo(
echo(============================================================
echo(git_list_issues.bat - Lists GitHub issues with common filters and search expressions.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_list_issues.bat [repo OWNER/REPO] [state open^|closed^|all] [assignee LOGIN] [author LOGIN] [labels LIST] [search QUERY] [limit N]
echo(
echo(Examples:
echo(  tools\git_list_issues.bat state open
echo(  tools\git_list_issues.bat assignee @me
echo(
echo(============================================================
echo(git_list_pull_requests.bat - Lists GitHub pull requests with common filters.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_list_pull_requests.bat [repo OWNER/REPO] [state open^|closed^|merged^|all] [author LOGIN] [search QUERY] [limit N]
echo(
echo(Examples:
echo(  tools\git_list_pull_requests.bat state open
echo(  tools\git_list_pull_requests.bat search "review-requested:@me"
echo(
echo(============================================================
echo(git_login.bat - Authenticates GitHub CLI and prepares Git credentials.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_login.bat
echo(
echo(Examples:
echo(  just_login.bat
echo(  tools\git_login.bat
echo(
echo(============================================================
echo(git_logout.bat - Logs out of GitHub CLI and clears cached GitHub credentials.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_logout.bat
echo(
echo(Examples:
echo(  just_logout.bat
echo(  tools\git_logout.bat
echo(
echo(============================================================
echo(git_merge_branch.bat - Merges another branch, defaulting to fast-forward-only.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_merge_branch.bat branch BRANCH [mode ff-only^|merge] [fetch yes^|no]
echo(
echo(Examples:
echo(  tools\git_merge_branch.bat branch feature/test
echo(  tools\git_merge_branch.bat branch feature/test mode merge
echo(
echo(============================================================
echo(git_push_local.bat - Pushes the current local branch to its configured remote.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_push_local.bat
echo(
echo(Examples:
echo(  just_push.bat
echo(  tools\git_push_local.bat
echo(
echo(============================================================
echo(git_remote_manage.bat - Lists or safely changes Git remote configuration.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_remote_manage.bat list^|add^|seturl^|rename^|remove [arguments]
echo(
echo(Examples:
echo(  tools\git_remote_manage.bat list
echo(  tools\git_remote_manage.bat add name upstream url OWNER/REPO
echo(
echo(============================================================
echo(git_rename_branch.bat - Renames a local branch and can publish the new name.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_rename_branch.bat [old BRANCH] new BRANCH [push yes^|no] [deleteoldremote yes^|no]
echo(
echo(Examples:
echo(  tools\git_rename_branch.bat new feature/new-name
echo(  tools\git_rename_branch.bat old feature/old new feature/new push yes
echo(
echo(============================================================
echo(git_restore_file.bat - Restores one tracked file from a selected revision.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_restore_file.bat path FILE [source REV] [staged yes^|no]
echo(
echo(Examples:
echo(  tools\git_restore_file.bat path README.md
echo(  tools\git_restore_file.bat path src\main.c source origin/main
echo(
echo(============================================================
echo(git_revert_commit.bat - Creates a new commit that reverses an older commit.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_revert_commit.bat commit REV [mainline N] [edit yes^|no]
echo(
echo(Examples:
echo(  tools\git_revert_commit.bat commit abc123
echo(  tools\git_revert_commit.bat commit abc123 mainline 1
echo(
echo(============================================================
echo(git_search_history.bat - Searches history by message, file, text, regex, author, or commit.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_search_history.bat mode MODE query VALUE [all yes^|no] [fetch yes^|no]
echo(
echo(Examples:
echo(  tools\git_search_history.bat mode message query "login"
echo(  tools\git_search_history.bat mode file query tools\git_login.bat
echo(
echo(============================================================
echo(git_show_history.bat - Displays a concise decorated Git commit history.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_show_history.bat
echo(
echo(Examples:
echo(  tools\git_show_history.bat
echo(
echo(============================================================
echo(git_stash_changes.bat - Saves current changes in a new Git stash.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_stash_changes.bat [message TEXT] [includeuntracked yes^|no] [keepindex yes^|no]
echo(
echo(Examples:
echo(  tools\git_stash_changes.bat message "Work in progress"
echo(  tools\git_stash_changes.bat includeuntracked no
echo(
echo(============================================================
echo(git_stash_manage.bat - Lists, inspects, restores, or deletes Git stashes.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_stash_manage.bat list^|show^|apply^|pop^|drop [STASH_REF] [allowdirty yes^|no]
echo(
echo(Examples:
echo(  tools\git_stash_manage.bat list
echo(  tools\git_stash_manage.bat show stash@{0}
echo(
echo(============================================================
echo(git_status_check.bat - Shows repository status, branch tracking, and common warnings.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_status_check.bat
echo(
echo(Examples:
echo(  just_status.bat
echo(  tools\git_status_check.bat
echo(
echo(============================================================
echo(git_switch_branch.bat - Switches safely to an existing local or origin branch.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_switch_branch.bat [name BRANCH] [fetch yes^|no] [allowdirty yes^|no]
echo(
echo(Examples:
echo(  tools\git_switch_branch.bat feature/test
echo(  tools\git_switch_branch.bat name feature/test fetch no
echo(
echo(============================================================
echo(git_sync_fork.bat - Fast-forwards a fork branch from upstream and optionally pushes origin.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_sync_fork.bat [branch NAME] [push yes^|no]
echo(
echo(Examples:
echo(  tools\git_sync_fork.bat
echo(  tools\git_sync_fork.bat branch main push no
echo(
echo(============================================================
echo(git_undo_last_commit.bat - Removes the latest local commit while preserving file changes.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_undo_last_commit.bat [mode mixed^|soft] [allowdirty yes^|no] [allowpushed yes^|no]
echo(
echo(Examples:
echo(  tools\git_undo_last_commit.bat
echo(  tools\git_undo_last_commit.bat mode soft
echo(
echo(============================================================
echo(git_worktree_manage.bat - Lists, creates, removes, or prunes Git worktrees.
echo(============================================================
echo(
echo(Usage:
echo(  tools\git_worktree_manage.bat list^|add^|remove^|prune [arguments]
echo(
echo(Examples:
echo(  tools\git_worktree_manage.bat list
echo(  tools\git_worktree_manage.bat add folder ..\feature branch feature/test
echo(
echo(============================================================
echo( Shared support utilities
echo(============================================================
echo(
echo(tools\GetGit.bat
echo(  Prepares the portable Git dependency.
echo(
echo(tools\GetGithubCLI.bat
echo(  Prepares the portable GitHub CLI dependency.
echo(
echo(tools\github_verify_clone.bat
echo(  Verifies that the configured repository can be cloned.
echo(
echo(============================================================
echo( Alphabetical git_*.bat index
echo(============================================================
echo(git_abort_operation.bat - Detects and aborts an active merge, rebase, cherry-pick, or revert.
echo(git_amend_last_commit.bat - Amends the newest local commit and refuses pushed history by default.
echo(git_archive_source.bat - Creates a ZIP from files committed at a selected revision.
echo(git_backup_bundle.bat - Creates a portable Git bundle containing committed repository history.
echo(git_blame_file.bat - Shows the commit and author responsible for selected file lines.
echo(git_check_ignored_files.bat - Checks ignored and untracked local dependency paths.
echo(git_check_remotes.bat - Checks remote URLs, reachability, configuration, and permissions.
echo(git_checkout_pull_request.bat - Checks out a GitHub pull request locally for inspection or testing.
echo(git_cherry_pick.bat - Applies one existing commit to the current branch.
echo(git_clean_preview.bat - Previews untracked or ignored paths without deleting anything.
echo(git_clone_repository.bat - Clones a repository into a new empty destination.
echo(git_commit_and_push_now.bat - Stages, commits, and pushes current changes in one workflow.
echo(git_compare_branches.bat - Compares unique commits and file changes between revisions.
echo(git_continue_operation.bat - Continues an active merge, rebase, cherry-pick, or revert.
echo(git_create_branch.bat - Creates and switches to a new branch, optionally publishing it.
echo(git_create_issue.bat - Creates a GitHub issue after preview and typed confirmation.
echo(git_create_pull_request.bat - Creates a GitHub pull request from the current branch.
echo(git_create_release.bat - Creates a GitHub release from an existing local tag.
echo(git_create_repository.bat - Creates a new independent GitHub repository from local history.
echo(git_create_tag.bat - Creates an annotated tag and optionally pushes it.
echo(git_delete_branch.bat - Deletes a non-current local branch and optionally its origin branch.
echo(git_discard_local_changes_DANGEROUS.bat - Permanently resets tracked changes and removes untracked non-ignored paths.
echo(git_doctor.bat - Runs comprehensive diagnostics for Git, GitHub, remotes, and helpers.
echo(git_find_conflicts.bat - Reports unresolved index entries and the active Git operation.
echo(git_find_large_files.bat - Finds the largest tracked files and historical Git blobs.
echo(git_fork.bat - Creates a true fork or delegates a same-owner repository copy.
echo(git_generate_changelog.bat - Generates a Markdown changelog between two commit revisions.
echo(git_get_latest.bat - Fetches tracking data and applies only a clean fast-forward update.
echo(git_help.bat - Displays the complete Git and GitHub helper reference.
echo(git_help_short.bat - Displays a compact categorized helper reference.
echo(git_list_branches.bat - Lists local and remote branches with optional refresh.
echo(git_list_issues.bat - Lists GitHub issues with common filters and search expressions.
echo(git_list_pull_requests.bat - Lists GitHub pull requests with common filters.
echo(git_login.bat - Authenticates GitHub CLI and prepares Git credentials.
echo(git_logout.bat - Logs out of GitHub CLI and clears cached GitHub credentials.
echo(git_merge_branch.bat - Merges another branch, defaulting to fast-forward-only.
echo(git_push_local.bat - Pushes the current local branch to its configured remote.
echo(git_remote_manage.bat - Lists or safely changes Git remote configuration.
echo(git_rename_branch.bat - Renames a local branch and can publish the new name.
echo(git_restore_file.bat - Restores one tracked file from a selected revision.
echo(git_revert_commit.bat - Creates a new commit that reverses an older commit.
echo(git_search_history.bat - Searches history by message, file, text, regex, author, or commit.
echo(git_show_history.bat - Displays a concise decorated Git commit history.
echo(git_stash_changes.bat - Saves current changes in a new Git stash.
echo(git_stash_manage.bat - Lists, inspects, restores, or deletes Git stashes.
echo(git_status_check.bat - Shows repository status, branch tracking, and common warnings.
echo(git_switch_branch.bat - Switches safely to an existing local or origin branch.
echo(git_sync_fork.bat - Fast-forwards a fork branch from upstream and optionally pushes origin.
echo(git_undo_last_commit.bat - Removes the latest local commit while preserving file changes.
echo(git_worktree_manage.bat - Lists, creates, removes, or prunes Git worktrees.
echo(
exit /b 0
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when the outermost launcher is the cmd.exe /c target.
::
:: Usage: call :PauseIfNeeded
::
:: Returns: 0
:: Requires: :IsConsole
:: ============================================================
:PauseIfNeeded
for /f "tokens=1 delims==" %%v in ('set pif_ 2^>nul') do set "%%v="
if defined _pif_rc (set "_pif_rc=" & exit /b %_pif_rc%)
call :IsConsole
if not errorlevel 1 (set "_pif_rc=0" & goto :PauseIfNeeded)
echo.
pause
set "_pif_rc=0" & goto :PauseIfNeeded
:: ============================================================
:: :IsConsole
:: Detects whether the outermost launcher is running in an existing
:: interactive console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 when running in an existing console
::          1 when the outermost launcher is the cmd.exe /c target
:: Requires: find.exe
:: ============================================================
:IsConsole
setlocal EnableDelayedExpansion
set "ic_cmdline=!CMDCMDLINE!"
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I " /c " >nul
if errorlevel 1 (endlocal & exit /b 0)
echo(!ic_cmdline!| "%SystemRoot%\System32\find.exe" /I "!app.launch.name!" >nul
if errorlevel 1 (endlocal & exit /b 0)
endlocal & exit /b 1
