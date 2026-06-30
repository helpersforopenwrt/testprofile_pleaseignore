@echo off
:: ============================================================
:: git_normalize_line_endings.bat
:: Checks and optionally normalizes text-file line endings.
::
:: Modes:
::   prompt  ask for each mismatched file
::   fix     normalize each mismatched file immediately
::   check   report mismatches without changing files
::   ignore  add a local-only .git/info/attributes override
::   reset   remove this helper's local override for each path
::
:: Targets:
::   crlf    Windows CRLF line endings; default
::   lf      Unix LF line endings
::
:: File selection:
::   changed scans existing modified, staged, and untracked files
::   deleted paths are skipped because they have no working-tree bytes
::   otherwise supply one or more explicit paths
::
:: Prompt choices:
::   F  fix now
::   S  skip this time
::   I  ignore locally in future
::
:: "Ignore locally" does not change the committed .gitattributes file.
:: It writes a path-specific rule to .git/info/attributes:
::   text eol=lf
::   text eol=crlf
:: or, for mixed endings only:
::   -text
::
:: A harmless custom attribute with a path hash marks the rule so this
:: helper can remove only that file's local override later.
::
:: Usage:
::   call git_normalize_line_endings.bat
::   call git_normalize_line_endings.bat prompt changed
::   call git_normalize_line_endings.bat fix crlf .gitignore
::   call git_normalize_line_endings.bat check changed
::   call git_normalize_line_endings.bat ignore .gitignore
::   call git_normalize_line_endings.bat reset .gitignore
::
:: Returns: 0 when completed
::          1 when Git/repository/PowerShell is unavailable
::          2 on invalid arguments
::          3 when check mode finds mismatches
::          4 when one or more files cannot be processed
:: Requires: git.exe, powershell.exe, where.exe, find.exe, choice.exe
:: ============================================================
:setup
if not defined app.launch.path set "app.launch.path=%~f0"
if not defined app.launch.name set "app.launch.name=%~nx0"
set "app.git_eol.rc=0"
set "app.git_eol.root="
set "app.git_eol.mode=prompt"
set "app.git_eol.target=crlf"
set "app.git_eol.total=0"
set "app.git_eol.clean=0"
set "app.git_eol.mismatch=0"
set "app.git_eol.fixed=0"
set "app.git_eol.skipped=0"
set "app.git_eol.ignored=0"
set "app.git_eol.reset=0"
set "app.git_eol.errors=0"
set "app.git_eol.changed="
set "app.git_eol.marker=git-normalize-line-endings-managed"
if defined GIT_PROJECT_ROOT set "app.git_eol.root=%GIT_PROJECT_ROOT%"
if not defined app.git_eol.root for %%A in ("%~dp0..") do set "app.git_eol.root=%%~fA"
for %%A in ("%app.git_eol.root%\.") do set "app.git_eol.root=%%~fA"
call :ParseArguments %*
set "app.git_eol.rc=%errorlevel%"
if not "%app.git_eol.rc%"=="0" goto :end
if /I "%app.git_eol.mode%"=="help" goto :help
call :CheckPrerequisites
set "app.git_eol.rc=%errorlevel%"
if not "%app.git_eol.rc%"=="0" goto :end
cd /d "%app.git_eol.root%"
set "app.git_eol.rc=%errorlevel%"
if "%app.git_eol.rc%"=="0" goto :_setup_repository
echo.
echo ERROR: Could not enter the project root:
echo   "%app.git_eol.root%"
echo.
set "app.git_eol.rc=1"
goto :end
:_setup_repository
git.exe rev-parse --is-inside-work-tree >nul 2>nul
set "app.git_eol.rc=%errorlevel%"
if "%app.git_eol.rc%"=="0" goto :run
echo.
echo ERROR: Project root is not inside a Git worktree:
echo   "%app.git_eol.root%"
echo.
set "app.git_eol.rc=1"
goto :end
:run
echo.
echo ============================================================
echo  Check and normalize line endings
echo ============================================================
echo.
echo Repository:
echo   %app.git_eol.root%
echo.
echo Mode:
echo   %app.git_eol.mode%
echo.
echo Target:
echo   %app.git_eol.target%
echo.
if defined app.git_eol.changed goto :changed
if "%~1"=="" goto :changed
call :ProcessExplicitArguments %*
goto :summary
:changed
call :ProcessChangedFiles
set "pcf_rc=%errorlevel%"
if not "%pcf_rc%"=="0" if "%app.git_eol.rc%"=="0" set "app.git_eol.rc=%pcf_rc%"
goto :summary
:summary
echo ============================================================
echo  Line-ending summary
echo ============================================================
echo.
echo Files checked: %app.git_eol.total%
echo Already clean: %app.git_eol.clean%
echo Mismatches:    %app.git_eol.mismatch%
echo Fixed:         %app.git_eol.fixed%
echo Skipped:       %app.git_eol.skipped%
echo Ignored local: %app.git_eol.ignored%
echo Overrides reset: %app.git_eol.reset%
echo Errors:        %app.git_eol.errors%
echo.
if /I "%app.git_eol.mode%"=="check" if not "%app.git_eol.mismatch%"=="0" if "%app.git_eol.rc%"=="0" set "app.git_eol.rc=3"
goto :end
:help
echo.
echo git_normalize_line_endings.bat
echo.
echo Usage:
echo   just_normalize_line_endings.bat
echo   just_normalize_line_endings.bat prompt changed
echo   just_normalize_line_endings.bat fix crlf PATH [PATH...]
echo   just_normalize_line_endings.bat check changed
echo   just_normalize_line_endings.bat ignore PATH [PATH...]
echo   just_normalize_line_endings.bat reset PATH [PATH...]
echo.
echo Prompt choices:
echo   F = normalize now
echo   S = skip this time
echo   I = suppress future conversion warnings locally
echo.
echo Local ignore rules are written only to .git\info\attributes.
echo They are not committed.
echo.
set "app.git_eol.rc=0"
:end
call :PauseIfNeeded
exit /b %app.git_eol.rc%
:: ============================================================
:: :ParseArguments
:: Parses mode, target, and changed-file selection.
::
:: Usage: call :ParseArguments %*
::
:: Returns: 0 on success, 2 on invalid arguments
:: Requires: none
:: ============================================================
:ParseArguments
if "%~1"=="" (set "app.git_eol.changed=1" & exit /b 0)
if /I "%~1"=="help" (set "app.git_eol.mode=help" & exit /b 0)
if /I "%~1"=="--help" (set "app.git_eol.mode=help" & exit /b 0)
if /I "%~1"=="/help" (set "app.git_eol.mode=help" & exit /b 0)
if /I "%~1"=="/?" (set "app.git_eol.mode=help" & exit /b 0)
if /I "%~1"=="prompt" (set "app.git_eol.mode=prompt" & shift & goto :_ParseArguments_target)
if /I "%~1"=="fix" (set "app.git_eol.mode=fix" & shift & goto :_ParseArguments_target)
if /I "%~1"=="check" (set "app.git_eol.mode=check" & shift & goto :_ParseArguments_target)
if /I "%~1"=="ignore" (set "app.git_eol.mode=ignore" & shift & goto :_ParseArguments_target)
if /I "%~1"=="reset" (set "app.git_eol.mode=reset" & shift & goto :_ParseArguments_target)
:_ParseArguments_target
if /I "%~1"=="crlf" (set "app.git_eol.target=crlf" & shift)
if /I "%~1"=="lf" (set "app.git_eol.target=lf" & shift)
if /I "%~1"=="changed" (set "app.git_eol.changed=1" & shift)
if defined app.git_eol.changed if not "%~1"=="" goto :_ParseArguments_invalid
set "app.git_eol.args=%*"
if defined app.git_eol.changed exit /b 0
if not "%~1"=="" exit /b 0
echo.
echo ERROR: Supply changed or at least one file path.
echo.
exit /b 2
:_ParseArguments_invalid
echo.
echo ERROR: changed cannot be combined with explicit file paths.
echo.
exit /b 2
:: ============================================================
:: :CheckPrerequisites
:: Verifies Git, PowerShell, and repository support commands.
::
:: Usage: call :CheckPrerequisites
::
:: Returns: 0 when ready, 1 otherwise
:: Requires: where.exe
:: ============================================================
:CheckPrerequisites
where git.exe >nul 2>nul
if not errorlevel 1 goto :_CheckPrerequisites_powershell
echo ERROR: git.exe was not found in PATH.
exit /b 1
:_CheckPrerequisites_powershell
where powershell.exe >nul 2>nul
if not errorlevel 1 exit /b 0
echo ERROR: powershell.exe was not found in PATH.
exit /b 1
:: ============================================================
:: :ProcessExplicitArguments
:: Processes the explicit paths remaining after parsed options.
::
:: Usage: call :ProcessExplicitArguments PATH [PATH...]
::
:: Returns: 0
:: Requires: :ProcessOne
:: ============================================================
:ProcessExplicitArguments
if "%~1"=="" exit /b 0
call :ProcessOne "%~1"
shift
goto :ProcessExplicitArguments
:: ============================================================
:: :ProcessChangedFiles
:: Enumerates changed, staged, and untracked files.
::
:: Usage: call :ProcessChangedFiles
::
:: Returns: 0 on success, 4 on enumeration failure
:: Requires: git.exe, PowerShell, :ProcessOne
:: ============================================================
:ProcessChangedFiles
set "GIT_EOL_ROOT=%app.git_eol.root%"
for /f "usebackq delims=" %%F in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Set-Location -LiteralPath $env:GIT_EOL_ROOT; $raw=& git status --porcelain=v1 -z --untracked-files=all; if($LASTEXITCODE -ne 0){exit 4}; $items=@($raw -split [char]0); for($i=0;$i-lt$items.Count;$i++){ $entry=$items[$i]; if([string]::IsNullOrEmpty($entry)-or$entry.Length-lt4){continue}; $status=$entry.Substring(0,2); $p=$entry.Substring(3); if($status[0]-eq'R'-or$status[0]-eq'C'-or$status[1]-eq'R'-or$status[1]-eq'C'){ if($i+1-lt$items.Count){$i++;$p=$items[$i]} }; $full=Join-Path $env:GIT_EOL_ROOT $p; if(Test-Path -LiteralPath $full -PathType Leaf){Write-Output $p} }"`) do call :ProcessOne "%%F"
set "pcf_rc=%errorlevel%"
set "GIT_EOL_ROOT="
if "%pcf_rc%"=="0" exit /b 0
echo ERROR: Could not enumerate changed files.
exit /b 4
:: ============================================================
:: :ProcessOne
:: Checks one file and applies the selected action.
::
:: Usage: call :ProcessOne "path"
::
:: Returns: 0; aggregate errors are recorded
:: Requires: :ClassifyFile, :NormalizeFile, :AddLocalOverride
:: ============================================================
:ProcessOne
set /a app.git_eol.total+=1 >nul
set "po_path=%~1"
if exist "%po_path%" goto :_ProcessOne_file
echo File:
echo   %po_path%
echo Result:
echo   MISSING OR DELETED - SKIPPED
echo.
set /a app.git_eol.skipped+=1 >nul
exit /b 0
:_ProcessOne_file
if /I "%app.git_eol.mode%"=="reset" goto :_ProcessOne_reset
call :ClassifyFile "%po_path%"
set "po_state=%errorlevel%"
if "%po_state%"=="20" goto :_ProcessOne_binary
if "%po_state%"=="21" goto :_ProcessOne_no_newlines
if "%po_state%"=="22" goto :_ProcessOne_crlf
if "%po_state%"=="23" goto :_ProcessOne_lf
if "%po_state%"=="24" goto :_ProcessOne_mixed
goto :_ProcessOne_error
:_ProcessOne_binary
echo File:
echo   %po_path%
echo Result:
echo   BINARY OR UNSUPPORTED
echo.
set /a app.git_eol.skipped+=1 >nul
exit /b 0
:_ProcessOne_no_newlines
echo File:
echo   %po_path%
echo Result:
echo   NO LINE ENDINGS
echo.
set /a app.git_eol.clean+=1 >nul
exit /b 0
:_ProcessOne_crlf
set "po_current=crlf"
goto :_ProcessOne_compare
:_ProcessOne_lf
set "po_current=lf"
goto :_ProcessOne_compare
:_ProcessOne_mixed
set "po_current=mixed"
:_ProcessOne_compare
if /I "%po_current%"=="%app.git_eol.target%" goto :_ProcessOne_clean
set /a app.git_eol.mismatch+=1 >nul
echo File:
echo   %po_path%
echo Current:
echo   %po_current%
echo Target:
echo   %app.git_eol.target%
echo.
if /I "%app.git_eol.mode%"=="check" goto :_ProcessOne_report_only
if /I "%app.git_eol.mode%"=="fix" goto :_ProcessOne_fix
if /I "%app.git_eol.mode%"=="ignore" goto :_ProcessOne_ignore
choice /C FSI /N /M "[F]ix now, [S]kip once, or [I]gnore locally in future? "
set "po_choice=%errorlevel%"
echo.
if "%po_choice%"=="1" goto :_ProcessOne_fix
if "%po_choice%"=="2" goto :_ProcessOne_skip
if "%po_choice%"=="3" goto :_ProcessOne_ignore
goto :_ProcessOne_skip
:_ProcessOne_clean
echo File:
echo   %po_path%
echo Result:
echo   ALREADY %app.git_eol.target%
echo.
set /a app.git_eol.clean+=1 >nul
exit /b 0
:_ProcessOne_report_only
echo Result:
echo   NEEDS NORMALIZATION
echo.
exit /b 0
:_ProcessOne_fix
call :NormalizeFile "%po_path%" "%app.git_eol.target%"
set "po_fix_rc=%errorlevel%"
if "%po_fix_rc%"=="0" goto :_ProcessOne_fixed
echo ERROR: Could not normalize:
echo   %po_path%
echo.
set /a app.git_eol.errors+=1 >nul
if "%app.git_eol.rc%"=="0" set "app.git_eol.rc=4"
exit /b 0
:_ProcessOne_fixed
echo Result:
echo   NORMALIZED TO %app.git_eol.target%
echo.
set /a app.git_eol.fixed+=1 >nul
exit /b 0
:_ProcessOne_skip
echo Result:
echo   SKIPPED THIS TIME
echo.
set /a app.git_eol.skipped+=1 >nul
exit /b 0
:_ProcessOne_ignore
call :AddLocalOverride "%po_path%" "%po_current%"
set "po_ignore_rc=%errorlevel%"
if "%po_ignore_rc%"=="0" goto :_ProcessOne_ignored
echo ERROR: Could not add local line-ending override:
echo   %po_path%
echo.
set /a app.git_eol.errors+=1 >nul
if "%app.git_eol.rc%"=="0" set "app.git_eol.rc=4"
exit /b 0
:_ProcessOne_ignored
echo Result:
echo   FUTURE WARNING IGNORED LOCALLY
echo.
set /a app.git_eol.ignored+=1 >nul
exit /b 0
:_ProcessOne_reset
call :RemoveLocalOverride "%po_path%"
set "po_reset_rc=%errorlevel%"
if "%po_reset_rc%"=="0" goto :_ProcessOne_reset_ok
echo ERROR: Could not remove local line-ending override:
echo   %po_path%
echo.
set /a app.git_eol.errors+=1 >nul
if "%app.git_eol.rc%"=="0" set "app.git_eol.rc=4"
exit /b 0
:_ProcessOne_reset_ok
echo File:
echo   %po_path%
echo Result:
echo   LOCAL OVERRIDE REMOVED
echo.
set /a app.git_eol.reset+=1 >nul
exit /b 0
:_ProcessOne_error
echo ERROR: Could not inspect:
echo   %po_path%
echo.
set /a app.git_eol.errors+=1 >nul
if "%app.git_eol.rc%"=="0" set "app.git_eol.rc=4"
exit /b 0
:: ============================================================
:: :ClassifyFile
:: Classifies raw line endings without altering the file.
::
:: Usage: call :ClassifyFile "path"
::
:: Returns: 20 binary/unsupported
::          21 no line endings
::          22 CRLF only
::          23 LF only
::          24 mixed or CR-only
::          25 inspection failure
:: Requires: PowerShell
:: ============================================================
:ClassifyFile
set "GIT_EOL_FILE=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $b=[IO.File]::ReadAllBytes($env:GIT_EOL_FILE); $utf16=($b.Length-ge 2 -and (($b[0]-eq 255-and$b[1]-eq 254)-or($b[0]-eq 254-and$b[1]-eq 255))); $utf32=($b.Length-ge 4 -and (($b[0]-eq 255-and$b[1]-eq 254-and$b[2]-eq 0-and$b[3]-eq 0)-or($b[0]-eq 0-and$b[1]-eq 0-and$b[2]-eq 254-and$b[3]-eq 255))); if(-not $utf16 -and -not $utf32 -and $b -contains 0){exit 20}; if($utf32){$enc=if($b[0]-eq 255){[Text.UTF32Encoding]::new($false,$true)}else{[Text.UTF32Encoding]::new($true,$true)}; $t=$enc.GetString($b,4,$b.Length-4); $crlf=[regex]::Matches($t,'\r\n').Count; $loneLf=[regex]::Matches($t,'(?<!\r)\n').Count; $loneCr=[regex]::Matches($t,'\r(?!\n)').Count}elseIf($utf16){$enc=if($b[0]-eq 255){[Text.UnicodeEncoding]::new($false,$true)}else{[Text.UnicodeEncoding]::new($true,$true)}; $t=$enc.GetString($b,2,$b.Length-2); $crlf=[regex]::Matches($t,'\r\n').Count; $loneLf=[regex]::Matches($t,'(?<!\r)\n').Count; $loneCr=[regex]::Matches($t,'\r(?!\n)').Count}else{$crlf=0;$loneLf=0;$loneCr=0;for($i=0;$i-lt$b.Length;$i++){if($b[$i]-eq13){if($i+1-lt$b.Length-and$b[$i+1]-eq10){$crlf++;$i++}else{$loneCr++}}elseif($b[$i]-eq10){$loneLf++}}}; if($crlf-eq0-and$loneLf-eq0-and$loneCr-eq0){exit 21}; if($crlf-gt0-and$loneLf-eq0-and$loneCr-eq0){exit 22}; if($crlf-eq0-and$loneLf-gt0-and$loneCr-eq0){exit 23}; exit 24"
set "cf_rc=%errorlevel%"
set "GIT_EOL_FILE="
exit /b %cf_rc%
:: ============================================================
:: :NormalizeFile
:: Converts line endings while preserving all non-newline bytes and
:: preserving UTF-16/UTF-32 byte order marks.
::
:: Usage: call :NormalizeFile "path" crlf|lf
::
:: Returns: 0 on success, 1 on failure
:: Requires: PowerShell
:: ============================================================
:NormalizeFile
set "GIT_EOL_FILE=%~1"
set "GIT_EOL_TARGET=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $p=$env:GIT_EOL_FILE; $target=if($env:GIT_EOL_TARGET-eq'lf'){[Environment]::NewLine.Replace([char]13+[char]10,[char]10)}else{[char]13+[char]10}; $b=[IO.File]::ReadAllBytes($p); $utf32=$b.Length-ge4-and(($b[0]-eq255-and$b[1]-eq254-and$b[2]-eq0-and$b[3]-eq0)-or($b[0]-eq0-and$b[1]-eq0-and$b[2]-eq254-and$b[3]-eq255)); $utf16=$b.Length-ge2-and(($b[0]-eq255-and$b[1]-eq254)-or($b[0]-eq254-and$b[1]-eq255)); if($utf32){$enc=if($b[0]-eq255){[Text.UTF32Encoding]::new($false,$true)}else{[Text.UTF32Encoding]::new($true,$true)};$offset=4;$t=$enc.GetString($b,$offset,$b.Length-$offset);$t=[regex]::Replace($t,'\r\n|\r|\n',$target);$out=New-Object byte[] ($enc.GetPreamble().Length+$enc.GetByteCount($t));[Array]::Copy($enc.GetPreamble(),0,$out,0,$enc.GetPreamble().Length);[Array]::Copy($enc.GetBytes($t),0,$out,$enc.GetPreamble().Length,$enc.GetByteCount($t));[IO.File]::WriteAllBytes($p,$out);exit 0}; if($utf16){$enc=if($b[0]-eq255){[Text.UnicodeEncoding]::new($false,$true)}else{[Text.UnicodeEncoding]::new($true,$true)};$offset=2;$t=$enc.GetString($b,$offset,$b.Length-$offset);$t=[regex]::Replace($t,'\r\n|\r|\n',$target);$pre=$enc.GetPreamble();$body=$enc.GetBytes($t);$out=New-Object byte[] ($pre.Length+$body.Length);[Array]::Copy($pre,0,$out,0,$pre.Length);[Array]::Copy($body,0,$out,$pre.Length,$body.Length);[IO.File]::WriteAllBytes($p,$out);exit 0}; if($b-contains0){exit 2}; $nl=if($env:GIT_EOL_TARGET-eq'lf'){[byte[]](10)}else{[byte[]](13,10)};$m=New-Object IO.MemoryStream;for($i=0;$i-lt$b.Length;$i++){if($b[$i]-eq13){if($i+1-lt$b.Length-and$b[$i+1]-eq10){$i++};$m.Write($nl,0,$nl.Length)}elseif($b[$i]-eq10){$m.Write($nl,0,$nl.Length)}else{$m.WriteByte($b[$i])}};[IO.File]::WriteAllBytes($p,$m.ToArray());$m.Dispose();exit 0"
set "nf_rc=%errorlevel%"
set "GIT_EOL_FILE="
set "GIT_EOL_TARGET="
if "%nf_rc%"=="0" exit /b 0
exit /b 1
:: ============================================================
:: :AddLocalOverride
:: Adds or replaces a marked local .git/info/attributes rule.
::
:: Usage: call :AddLocalOverride "path" currentStyle
::
:: Returns: 0 on success, 1 on failure
:: Requires: Git, PowerShell
:: ============================================================
:AddLocalOverride
set "GIT_EOL_FILE=%~1"
set "GIT_EOL_STYLE=%~2"
set "GIT_EOL_MARKER=%app.git_eol.marker%"
set "GIT_EOL_ROOT=%app.git_eol.root%"
set "GIT_EOL_ATTRIBUTES="
for /f "usebackq delims=" %%G in (`git.exe rev-parse --git-path info/attributes 2^>nul`) do if not defined GIT_EOL_ATTRIBUTES set "GIT_EOL_ATTRIBUTES=%%G"
if not defined GIT_EOL_ATTRIBUTES goto :_AddLocalOverride_fail
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root=[IO.Path]::GetFullPath($env:GIT_EOL_ROOT); $candidate=$env:GIT_EOL_FILE; if([IO.Path]::IsPathRooted($candidate)){$full=[IO.Path]::GetFullPath($candidate)}else{$full=[IO.Path]::GetFullPath((Join-Path -Path $root -ChildPath $candidate))}; $prefix=$root.TrimEnd('\')+'\'; if($full -ine $root -and -not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Path is outside the repository root.'}; $rel=$full.Substring($root.Length).TrimStart('\').Replace('\','/'); $pattern=([char]34)+$rel+([char]34); $attr=if($env:GIT_EOL_STYLE -eq 'lf'){'text eol=lf'}elseif($env:GIT_EOL_STYLE -eq 'crlf'){'text eol=crlf'}else{'-text'}; $sha=[Security.Cryptography.SHA256]::Create(); try{$hashBytes=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($rel))}finally{$sha.Dispose()}; $hash=[BitConverter]::ToString($hashBytes).Replace('-','').ToLowerInvariant(); $marker=$env:GIT_EOL_MARKER+'='+$hash; $line=$pattern+' '+$attr+' '+$marker; $p=[IO.Path]::GetFullPath($env:GIT_EOL_ATTRIBUTES); $dir=Split-Path -Parent $p; if(-not (Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Force -Path $dir | Out-Null}; $lines=if(Test-Path -LiteralPath $p){@(Get-Content -LiteralPath $p)}else{@()}; $suffix=' '+$marker; $lines=@($lines | Where-Object {-not $_.EndsWith($suffix,[StringComparison]::Ordinal)}); $lines+=$line; [IO.File]::WriteAllLines($p,$lines,[Text.UTF8Encoding]::new($false))"
set "alo_rc=%errorlevel%"
set "GIT_EOL_FILE="
set "GIT_EOL_STYLE="
set "GIT_EOL_MARKER="
set "GIT_EOL_ROOT="
set "GIT_EOL_ATTRIBUTES="
if "%alo_rc%"=="0" exit /b 0
:_AddLocalOverride_fail
set "GIT_EOL_FILE="
set "GIT_EOL_STYLE="
set "GIT_EOL_MARKER="
set "GIT_EOL_ROOT="
set "GIT_EOL_ATTRIBUTES="
exit /b 1
:: ============================================================
:: :RemoveLocalOverride
:: Removes this helper's path-specific local override.
::
:: Usage: call :RemoveLocalOverride "path"
::
:: Returns: 0 on success, 1 on failure
:: Requires: Git, PowerShell
:: ============================================================
:RemoveLocalOverride
set "GIT_EOL_FILE=%~1"
set "GIT_EOL_MARKER=%app.git_eol.marker%"
set "GIT_EOL_ROOT=%app.git_eol.root%"
set "GIT_EOL_ATTRIBUTES="
for /f "usebackq delims=" %%G in (`git.exe rev-parse --git-path info/attributes 2^>nul`) do if not defined GIT_EOL_ATTRIBUTES set "GIT_EOL_ATTRIBUTES=%%G"
if not defined GIT_EOL_ATTRIBUTES goto :_RemoveLocalOverride_fail
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $p=[IO.Path]::GetFullPath($env:GIT_EOL_ATTRIBUTES); if(-not (Test-Path -LiteralPath $p)){exit 0}; $root=[IO.Path]::GetFullPath($env:GIT_EOL_ROOT); $candidate=$env:GIT_EOL_FILE; if([IO.Path]::IsPathRooted($candidate)){$full=[IO.Path]::GetFullPath($candidate)}else{$full=[IO.Path]::GetFullPath((Join-Path -Path $root -ChildPath $candidate))}; $prefix=$root.TrimEnd('\')+'\'; if($full -ine $root -and -not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Path is outside the repository root.'}; $rel=$full.Substring($root.Length).TrimStart('\').Replace('\','/'); $sha=[Security.Cryptography.SHA256]::Create(); try{$hashBytes=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($rel))}finally{$sha.Dispose()}; $hash=[BitConverter]::ToString($hashBytes).Replace('-','').ToLowerInvariant(); $marker=$env:GIT_EOL_MARKER+'='+$hash; $suffix=' '+$marker; $lines=@(Get-Content -LiteralPath $p); $keep=@($lines | Where-Object {-not $_.EndsWith($suffix,[StringComparison]::Ordinal)}); [IO.File]::WriteAllLines($p,$keep,[Text.UTF8Encoding]::new($false))"
set "rlo_rc=%errorlevel%"
set "GIT_EOL_FILE="
set "GIT_EOL_MARKER="
set "GIT_EOL_ROOT="
set "GIT_EOL_ATTRIBUTES="
if "%rlo_rc%"=="0" exit /b 0
:_RemoveLocalOverride_fail
set "GIT_EOL_FILE="
set "GIT_EOL_MARKER="
set "GIT_EOL_ROOT="
set "GIT_EOL_ATTRIBUTES="
exit /b 1
:: ============================================================
:: :PauseIfNeeded
:: Pauses only when this script is the outer cmd.exe /c target.
::
:: Usage: call :PauseIfNeeded
::
:: Returns: 0
:: Requires: :IsConsole
:: ============================================================
:PauseIfNeeded
call :IsConsole
if not errorlevel 1 exit /b 0
echo.
pause
exit /b 0
:: ============================================================
:: :IsConsole
:: Detects whether execution is already inside an interactive console.
::
:: Usage: call :IsConsole
::
:: Returns: 0 for an existing console
::          1 when app.launch.name is the outer cmd.exe /c target
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
