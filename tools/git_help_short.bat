@echo off
:: ============================================================
:: git_help_short.bat
:: Displays a compact categorized reference for all 50 public
:: git_*.bat helpers.
::
:: Usage:
::   call tools\git_help_short.bat
::
:: Returns: 0 after displaying help
::          _common.bat exit code when initialization fails
:: Requires: _common.bat, :Main, :PauseIfNeeded, :IsConsole
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_help_short.rc=0"
call "%~dp0_common.bat" init
if not errorlevel 1 goto :run
set "app.git_help_short.rc=%errorlevel%"
goto :end
:run
call :Main
set "app.git_help_short.rc=%errorlevel%"
:end
call :PauseIfNeeded
exit /b %app.git_help_short.rc%
:: ============================================================
:: :Main
:: Prints a categorized command and purpose summary for every
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
echo( Short Git and GitHub helper reference
echo(============================================================
echo(
echo(Project:
echo(  %APP_DISPLAY_NAME%
echo(
echo(Common root shortcuts:
echo(  just_status.bat      just_getlatest.bat   just_commit.bat
echo(  just_push.bat        just_help.bat        just_short_help.bat
echo(  git_doctor.bat
echo(
echo(============================================================
echo( Daily workflow
echo(============================================================
echo(
echo(git_status_check.bat
echo(  Shows repository status, branch tracking, and common warnings.
echo(  Usage: tools\git_status_check.bat
echo(
echo(git_get_latest.bat
echo(  Fetches tracking data and applies only a clean fast-forward update.
echo(  Usage: tools\git_get_latest.bat
echo(
echo(git_commit_and_push_now.bat
echo(  Stages, commits, and pushes current changes in one workflow.
echo(  Usage: tools\git_commit_and_push_now.bat
echo(
echo(git_push_local.bat
echo(  Pushes the current local branch to its configured remote.
echo(  Usage: tools\git_push_local.bat
echo(
echo(git_show_history.bat
echo(  Displays a concise decorated Git commit history.
echo(  Usage: tools\git_show_history.bat
echo(
echo(git_help.bat
echo(  Displays the complete Git and GitHub helper reference.
echo(  Usage: tools\git_help.bat
echo(
echo(============================================================
echo( Branches and worktrees
echo(============================================================
echo(
echo(git_create_branch.bat
echo(  Creates and switches to a new branch, optionally publishing it.
echo(  Usage: tools\git_create_branch.bat [name BRANCH] [start REV] [push yes^|no] [allowdirty yes^|no]
echo(
echo(git_switch_branch.bat
echo(  Switches safely to an existing local or origin branch.
echo(  Usage: tools\git_switch_branch.bat [name BRANCH] [fetch yes^|no] [allowdirty yes^|no]
echo(
echo(git_delete_branch.bat
echo(  Deletes a non-current local branch and optionally its origin branch.
echo(  Usage: tools\git_delete_branch.bat [name BRANCH] [remote yes^|no] [force yes^|no]
echo(
echo(git_rename_branch.bat
echo(  Renames a local branch and can publish the new name.
echo(  Usage: tools\git_rename_branch.bat [old BRANCH] new BRANCH [push yes^|no] [deleteoldremote yes^|no]
echo(
echo(git_merge_branch.bat
echo(  Merges another branch, defaulting to fast-forward-only.
echo(  Usage: tools\git_merge_branch.bat branch BRANCH [mode ff-only^|merge] [fetch yes^|no]
echo(
echo(git_compare_branches.bat
echo(  Compares unique commits and file changes between revisions.
echo(  Usage: tools\git_compare_branches.bat [left REV] [right REV] [fetch yes^|no]
echo(
echo(git_list_branches.bat
echo(  Lists local and remote branches with optional refresh.
echo(  Usage: tools\git_list_branches.bat [scope local^|remote^|all] [fetch yes^|no]
echo(
echo(git_worktree_manage.bat
echo(  Lists, creates, removes, or prunes Git worktrees.
echo(  Usage: tools\git_worktree_manage.bat list^|add^|remove^|prune [arguments]
echo(
echo(============================================================
echo( Recovery and history editing
echo(============================================================
echo(
echo(git_abort_operation.bat
echo(  Detects and aborts an active merge, rebase, cherry-pick, or revert.
echo(  Usage: tools\git_abort_operation.bat [operation OPERATION]
echo(
echo(git_continue_operation.bat
echo(  Continues an active merge, rebase, cherry-pick, or revert.
echo(  Usage: tools\git_continue_operation.bat [operation OPERATION]
echo(
echo(git_find_conflicts.bat
echo(  Reports unresolved index entries and the active Git operation.
echo(  Usage: tools\git_find_conflicts.bat [details yes^|no]
echo(
echo(git_restore_file.bat
echo(  Restores one tracked file from a selected revision.
echo(  Usage: tools\git_restore_file.bat path FILE [source REV] [staged yes^|no]
echo(
echo(git_revert_commit.bat
echo(  Creates a new commit that reverses an older commit.
echo(  Usage: tools\git_revert_commit.bat commit REV [mainline N] [edit yes^|no]
echo(
echo(git_undo_last_commit.bat
echo(  Removes the latest local commit while preserving file changes.
echo(  Usage: tools\git_undo_last_commit.bat [mode mixed^|soft] [allowdirty yes^|no] [allowpushed yes^|no]
echo(
echo(git_amend_last_commit.bat
echo(  Amends the newest local commit and refuses pushed history by default.
echo(  Usage: tools\git_amend_last_commit.bat [message TEXT] [stage yes^|no] [allowpushed yes^|no]
echo(
echo(git_cherry_pick.bat
echo(  Applies one existing commit to the current branch.
echo(  Usage: tools\git_cherry_pick.bat commit REV [mainline N] [nocommit yes^|no]
echo(
echo(git_discard_local_changes_DANGEROUS.bat
echo(  Permanently resets tracked changes and removes untracked non-ignored paths.
echo(  Usage: tools\git_discard_local_changes_DANGEROUS.bat
echo(
echo(============================================================
echo( Stashes and inspection
echo(============================================================
echo(
echo(git_stash_changes.bat
echo(  Saves current changes in a new Git stash.
echo(  Usage: tools\git_stash_changes.bat [message TEXT] [includeuntracked yes^|no] [keepindex yes^|no]
echo(
echo(git_stash_manage.bat
echo(  Lists, inspects, restores, or deletes Git stashes.
echo(  Usage: tools\git_stash_manage.bat list^|show^|apply^|pop^|drop [STASH_REF] [allowdirty yes^|no]
echo(
echo(git_search_history.bat
echo(  Searches history by message, file, text, regex, author, or commit.
echo(  Usage: tools\git_search_history.bat mode MODE query VALUE [all yes^|no] [fetch yes^|no]
echo(
echo(git_blame_file.bat
echo(  Shows the commit and author responsible for selected file lines.
echo(  Usage: tools\git_blame_file.bat path FILE [revision REV] [start N] [end N] [ignorewhitespace yes^|no]
echo(
echo(git_find_large_files.bat
echo(  Finds the largest tracked files and historical Git blobs.
echo(  Usage: tools\git_find_large_files.bat [mode tracked^|history^|both] [limit N] [minimumbytes N]
echo(
echo(git_clean_preview.bat
echo(  Previews untracked or ignored paths without deleting anything.
echo(  Usage: tools\git_clean_preview.bat [mode untracked^|ignored^|all]
echo(
echo(git_check_ignored_files.bat
echo(  Checks ignored and untracked local dependency paths.
echo(  Usage: tools\git_check_ignored_files.bat
echo(
echo(git_check_remotes.bat
echo(  Checks remote URLs, reachability, configuration, and permissions.
echo(  Usage: tools\git_check_remotes.bat
echo(
echo(git_doctor.bat
echo(  Runs comprehensive diagnostics for Git, GitHub, remotes, and helpers.
echo(  Usage: tools\git_doctor.bat
echo(
echo(============================================================
echo( GitHub repositories and collaboration
echo(============================================================
echo(
echo(git_login.bat
echo(  Authenticates GitHub CLI and prepares Git credentials.
echo(  Usage: tools\git_login.bat
echo(
echo(git_logout.bat
echo(  Logs out of GitHub CLI and clears cached GitHub credentials.
echo(  Usage: tools\git_logout.bat
echo(
echo(git_clone_repository.bat
echo(  Clones a repository into a new empty destination.
echo(  Usage: tools\git_clone_repository.bat repo URL_OR_OWNER/REPO [destination FOLDER] [branch NAME] [login yes^|no]
echo(
echo(git_fork.bat
echo(  Creates a true fork or delegates a same-owner repository copy.
echo(  Usage: tools\git_fork.bat [source REPO] [owner OWNER] [name NAME] [visibility public^|private^|internal]
echo(
echo(git_create_repository.bat
echo(  Creates a new independent GitHub repository from local history.
echo(  Usage: tools\git_create_repository.bat [owner OWNER] [name NAME] [source URL] [visibility public^|private^|internal] [branch NAME] [message TEXT]
echo(
echo(git_create_issue.bat
echo(  Creates a GitHub issue after preview and typed confirmation.
echo(  Usage: tools\git_create_issue.bat title TEXT [body TEXT] [labels LIST] [assignees LIST] [milestone NAME] [repo OWNER/REPO]
echo(
echo(git_list_issues.bat
echo(  Lists GitHub issues with common filters and search expressions.
echo(  Usage: tools\git_list_issues.bat [repo OWNER/REPO] [state open^|closed^|all] [assignee LOGIN] [author LOGIN] [labels LIST] [search QUERY] [limit N]
echo(
echo(git_create_pull_request.bat
echo(  Creates a GitHub pull request from the current branch.
echo(  Usage: tools\git_create_pull_request.bat [base BRANCH] [title TEXT] [body TEXT] [draft yes^|no] [push yes^|no]
echo(
echo(git_list_pull_requests.bat
echo(  Lists GitHub pull requests with common filters.
echo(  Usage: tools\git_list_pull_requests.bat [repo OWNER/REPO] [state open^|closed^|merged^|all] [author LOGIN] [search QUERY] [limit N]
echo(
echo(git_checkout_pull_request.bat
echo(  Checks out a GitHub pull request locally for inspection or testing.
echo(  Usage: tools\git_checkout_pull_request.bat number N [repo OWNER/REPO] [branch NAME] [detach yes^|no] [allowclosed yes^|no]
echo(
echo(git_sync_fork.bat
echo(  Fast-forwards a fork branch from upstream and optionally pushes origin.
echo(  Usage: tools\git_sync_fork.bat [branch NAME] [push yes^|no]
echo(
echo(git_remote_manage.bat
echo(  Lists or safely changes Git remote configuration.
echo(  Usage: tools\git_remote_manage.bat list^|add^|seturl^|rename^|remove [arguments]
echo(
echo(============================================================
echo( Tags, releases, and packaging
echo(============================================================
echo(
echo(git_create_tag.bat
echo(  Creates an annotated tag and optionally pushes it.
echo(  Usage: tools\git_create_tag.bat [name TAG] [message TEXT] [target REV] [push yes^|no]
echo(
echo(git_create_release.bat
echo(  Creates a GitHub release from an existing local tag.
echo(  Usage: tools\git_create_release.bat tag TAG [title TEXT] [notes TEXT] [draft yes^|no] [prerelease yes^|no] [pushtag yes^|no]
echo(
echo(git_archive_source.bat
echo(  Creates a ZIP from files committed at a selected revision.
echo(  Usage: tools\git_archive_source.bat [revision REV] [output FILE.zip] [prefix FOLDER] [overwrite yes^|no]
echo(
echo(git_backup_bundle.bat
echo(  Creates a portable Git bundle containing committed repository history.
echo(  Usage: tools\git_backup_bundle.bat
echo(
echo(git_generate_changelog.bat
echo(  Generates a Markdown changelog between two commit revisions.
echo(  Usage: tools\git_generate_changelog.bat from REV to REV [output FILE] [merges yes^|no] [overwrite yes^|no]
echo(
echo(git_help_short.bat
echo(  Displays a compact categorized helper reference.
echo(  Usage: tools\git_help_short.bat
echo(
echo(Use tools\git_help.bat for examples and the full reference.
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
