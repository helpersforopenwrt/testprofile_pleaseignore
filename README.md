# testprofile_pleaseignore

A code-less demonstration repository for reusable Windows batch helpers.

## Project-root rule

`build_config.bat` is the authoritative project-root marker.

Every helper searches in this exact order:

1. Current folder: `build_config.bat`
2. Parent folder: `build_config.bat`
3. Current folder: `build.bat`
4. Parent folder: `build.bat`

After finding a marker, the helper changes its current directory to that
folder. This supports both common launch styles:

```bat
just_status.bat
tools\just_status.bat
```

It also supports running a helper while already inside `tools`.

## Root shortcuts

The root shortcut files are intentionally identical. A shortcut uses its own
filename to call the matching script in `tools`.

To expose another helper at the project root:

1. Copy `_root_helper_stub_TEMPLATE.bat`.
2. Rename the copy to the exact helper filename, such as `just_history.bat`.
3. Confirm that `tools\just_history.bat` exists.

## First setup

```bat
tools\git_login.bat
just_status.bat
just_commit.bat "Initial commit"
just_push.bat
tools\just_verifygithub.bat
```

If the GitHub repository already contains an independently created README,
license, or `.gitignore`, inspect its history before pushing a separate local
history.

## Notes

`git_backup_bundle.bat` backs up committed Git history. Git bundles do not
contain uncommitted, untracked, or ignored files.

`git_discard_local_changes_DANGEROUS.bat` previews untracked files with
`git clean -nd` and requires the exact confirmation word `DISCARD`.
