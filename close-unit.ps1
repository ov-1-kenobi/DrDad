# close-unit.ps1 - deterministic close-out for ONE completed unit (task or story).
# Replaces a 5-step prose checklist in /build with a script, because mechanical bookkeeping is exactly
# what local models skip: tick the task box, roll the parent story up to DONE when all its tasks are
# ticked, reindex, commit, and VERIFY. Exits non-zero if anything did not actually happen.
#
# Usage (run from the project folder, or pass -ProjectDir):
#   close-unit.ps1 -Id T8.1 -Title "Add EncryptionKey to LeanHashConfig"
#   close-unit.ps1 -Id S3   -Title "Automatic GC"          (no task map: closes the story)
#   close-unit.ps1 -Id T8.1 -NoCommit -NoReindex           (bookkeeping only)
#
# Idempotent: re-running on an already-closed unit reports it and succeeds.

param(
  [Parameter(Mandatory)][string]$Id,
  [string]$Title = "",
  [string]$ProjectDir = ".",
  [string]$BuildCommand = "",
  [switch]$NoCommit,
  [switch]$NoReindex,
  [switch]$SkipVerify,
  [switch]$RequireGrade,
  [switch]$AcceptShrink
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$notes = New-Object System.Collections.Generic.List[string]
$problems = New-Object System.Collections.Generic.List[string]
$warns = New-Object System.Collections.Generic.List[string]

# Pull a command out of CLAUDE.md's "## Build / test" block ("Build" or "Test").
function Get-ClaudeCommand([string]$kind) {
  $cm = Join-Path $proj "CLAUDE.md"
  if (-not (Test-Path $cm)) { return "" }
  $m = [regex]::Match((Get-Content $cm -Raw), "(?m)^\s*-\s*\*{0,2}$kind\*{0,2}\s*:\s*``?([^``\r\n]+?)``?\s*$")
  if (-not $m.Success) { return "" }
  $v = $m.Groups[1].Value.Trim()
  if ($v -match '^<' -or $v -match 'set in .design') { return "" }   # unfilled placeholder
  return $v
}

# Run a command in a CHILD shell (never Invoke-Expression: a string containing 'exit' would kill us).
function Invoke-Verify([string]$cmd) {
  Push-Location $proj
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try   { $out = (cmd /c "$cmd" | Out-String); $code = $LASTEXITCODE }
  catch { $out = $_.Exception.Message; $code = 1 }
  finally { $ErrorActionPreference = $prevEap; Pop-Location }
  return [pscustomobject]@{ Output = $out; Code = $code }
}

function Show-Tail([string]$text) {
  foreach ($l in ($text -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 15)) {
    Write-Host "    $l" -ForegroundColor DarkYellow
  }
}

# When the build fails on a SIGNATURE error, hand over the real signature instead of leaving the model to
# go find it. This is the whole point of docs\API-SURFACE.md being mechanical rather than advisory: runA
# made ZERO search_datasheets calls, so a registry the model has to remember to consult is worth nothing.
# The compiler already names the type and member it could not resolve - we just look them up.
function Show-Signatures([string]$buildOutput) {
  $api = Join-Path $proj "docs\API-SURFACE.md"
  if (-not (Test-Path $api)) { return }
  # CS1501 no overload takes N args | CS1061/CS0117 no such member | CS7036 missing required parameter
  # | CS1503 argument type | CS0246 type not found. All of them quote the identifier in 'single quotes'.
  $names = New-Object System.Collections.Generic.HashSet[string]
  foreach ($m in [regex]::Matches($buildOutput, "error CS(?:1501|1061|0117|7036|1503|0246|1729|0029)[^\r\n]*")) {
    foreach ($q in [regex]::Matches($m.Value, "'([A-Za-z_][A-Za-z0-9_.<>]{2,})'")) {
      $n = $q.Groups[1].Value
      if ($n -match '\.') { $n = ($n -split '\.')[-1] }          # 'Foo.Bar(...)' -> Bar
      $n = ($n -split '[<(]')[0]
      if ($n.Length -ge 3) { [void]$names.Add($n) }
    }
  }
  if ($names.Count -eq 0) { return }
  $script = Join-Path $kit "api-surface.ps1"
  if (-not (Test-Path $script)) { return }
  Write-Host ""
  Write-Host "[close-unit] REAL SIGNATURES for what the compiler could not resolve (docs\API-SURFACE.md):" -ForegroundColor Cyan
  $shown = 0
  foreach ($n in ($names | Select-Object -First 6)) {
    $hit = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -ProjectDir $proj -Lookup $n 2>$null
    if ($LASTEXITCODE -eq 0 -and $hit) {
      Write-Host "  --- $n ---" -ForegroundColor Cyan
      $hit | Select-Object -First 12 | ForEach-Object { Write-Host "  $_" }
      $shown++
    }
  }
  if ($shown -eq 0) {
    Write-Host "  (nothing matched - the identifier may be yours and not yet built, or misspelled)" -ForegroundColor DarkGray
  } else {
    Write-Host "  Use these EXACTLY. Do not guess an overload - this list came out of the compiled assembly." -ForegroundColor Cyan
  }
}

# An ENVIRONMENT block is not a code failure, and the difference matters enormously to what happens next.
# Measured: qa-agent hit Windows App Control refusing to run the built test DLL, and - with no instruction
# for this case - spent the session trying to STOP the Application Identity service, add Defender
# exclusions, and disable AppLocker/WDAC. That is the worst possible response: it attacks the machine's
# security instead of reporting a wall it cannot (and must not) climb. A build/test failure that carries
# one of these signatures is environmental. Say so loudly, tell the human it is THEIRS to resolve, and
# forbid the security-tampering path in the same breath. Returns $true if it printed a block notice.
function Show-EnvBlock([string]$output) {
  $sig = '(?i)(App ?Control|AppLocker|WDAC|Windows Defender Application|Smart App Control|' +
         'not permitted to (run|load)|blocked by (group |)policy|0x800704C8|0x80070005|' +
         'ERROR_ACCESS_DENIED|program is blocked by group policy|this program is blocked|' +
         'operation.{0,20}not permitted|access is denied.{0,40}\.dll)'
  if ($output -notmatch $sig) { return $false }
  Write-Host ""
  Write-Host "[close-unit] THIS IS AN ENVIRONMENT BLOCK, NOT A CODE FAILURE." -ForegroundColor Magenta
  Write-Host "  Windows refused to run the built assembly (App Control / AppLocker / a policy / access denied)." -ForegroundColor Magenta
  Write-Host "  The code may be fine; the machine will not execute it as configured." -ForegroundColor Magenta
  Write-Host ""
  Write-Host "  DO NOT attempt to work around this. Specifically, DO NOT:" -ForegroundColor Yellow
  Write-Host "    - stop or disable any service (Application Identity / AppIDSvc, etc.)" -ForegroundColor Yellow
  Write-Host "    - add Windows Defender exclusions or change Defender settings" -ForegroundColor Yellow
  Write-Host "    - modify AppLocker / WDAC / Smart App Control policy" -ForegroundColor Yellow
  Write-Host "    - relaunch as administrator to force it through" -ForegroundColor Yellow
  Write-Host "  Changing a machine's security posture is the HUMAN's decision, never the agent's, and a" -ForegroundColor Yellow
  Write-Host "  local model has no way to judge whether it is safe. Trying it is how a run does real harm." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  STOP and report to the human: 'the build is blocked by Windows App Control / policy - this" -ForegroundColor Cyan
  Write-Host "  is an environment decision only you can make.' Then wait. The unit is NOT closed, but nothing" -ForegroundColor Cyan
  Write-Host "  is wrong with the code, so do not 'fix' it." -ForegroundColor Cyan
  return $true
}

# How many tests actually ran? -1 = could not tell. A story must never close on 0 or unknown: mediamotor
# had six test projects missing from the .sln, so 'dotnet test' printed "Build succeeded" and ran NOTHING.
function Get-TestCount([string]$out) {
  foreach ($rx in @('(?im)^\s*Total:\s*(\d+)', '(?i)Total tests:\s*(\d+)', '(?i)Tests run:\s*(\d+)',
                    '(?i)(\d+)\s+passed', '(?i)Passed:\s*(\d+)', '(?i)(\d+)\s+test\(s\)')) {
    $m = [regex]::Match($out, $rx)
    if ($m.Success) { return [int]$m.Groups[1].Value }
  }
  if ($out -match '(?i)(no tests? (were run|to run|ran|available)|zero tests|found 0 test)') { return 0 }
  return -1
}

# A grade card must be a real assessment, not a stub. Same thresholds the /build gate uses.
function Test-GradeCard([string]$unitId) {
  $card = Join-Path $proj "grades\$($unitId)_GRADE.md"
  if (-not (Test-Path $card)) { return "no grade card (grades\$($unitId)_GRADE.md)" }
  $len = (Get-Item $card).Length
  if ($len -lt 800) { return "grade card is a stub ($len bytes, needs >=800)" }
  if (-not (Select-String -Path $card -Pattern '##\s*Grade history' -Quiet)) { return "grade card has no '## Grade history'" }
  return $null
}

function Save-Text([string]$path, [string[]]$lines) {
  [System.IO.File]::WriteAllText($path, (($lines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
}

# --- where are the docs? (.mcp.json wins, else <proj>\docs) ---
$docs = Join-Path $proj "docs"
$mcp = Join-Path $proj ".mcp.json"
if (Test-Path $mcp) {
  try {
    $d = (Get-Content $mcp -Raw | ConvertFrom-Json).mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR
    if ($d -and (Test-Path $d)) { $docs = (Resolve-Path -LiteralPath $d).Path }
  } catch { }
}
$tasksFile   = Join-Path $docs "TASKS.md"
$storiesFile = Join-Path $docs "STORIES.md"
$esc = [regex]::Escape($Id)

# --- mark a story DONE in STORIES.md (handles both the template shape and looser real-world headings) ---
function Set-StoryDone([string]$storyId) {
  if (-not (Test-Path $storiesFile)) { $problems.Add("STORIES.md not found - cannot roll up $storyId"); return }
  $lines = Get-Content $storiesFile -Encoding UTF8
  $sEsc = [regex]::Escape($storyId)
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^#{1,6}\s' -and $lines[$i] -match "\b$sEsc\b") {
      if ($lines[$i] -match '<!--\s*Status:\s*DONE\s*-->') { $notes.Add("story $storyId already DONE"); return }
      if ($lines[$i] -match '<!--\s*Status:.*?-->') {
        $lines[$i] = [regex]::Replace($lines[$i], '<!--\s*Status:.*?-->', '<!-- Status: DONE -->')
      } else {
        $lines[$i] = $lines[$i].TrimEnd() + "   <!-- Status: DONE -->"
      }
      Save-Text $storiesFile $lines
      $notes.Add("story $storyId -> DONE (all its tasks are [x])")
      return
    }
  }
  $problems.Add("story $storyId not found in STORIES.md")
}

# --- 0) VERIFY THE BUILD before touching any bookkeeping ---
# Learned the hard way: a project once had 5 stories marked DONE, 6 tasks ticked and 4 checkpoint commits
# while `dotnet build` failed with 21 errors and NO tests had ever run (the test projects were not even in
# the .sln). Ticking a box over a broken build manufactures confident green state - refuse to do it.
# Will this close COMPLETE a story? Work it out BEFORE mutating anything, so tests can gate it.
$predictedStory = $null
if ((Test-Path $tasksFile) -and (Select-String -Path $tasksFile -Pattern "^###\s*\[[ x]\]\s*$esc\b" -Quiet)) {
  $taskLines = @(Get-Content $tasksFile -Encoding UTF8 | Where-Object { $_ -match '^###\s*\[[ x]\]' })
  $mine = $taskLines | Where-Object { $_ -match "^###\s*\[[ x]\]\s*$esc\b" } | Select-Object -First 1
  if ($mine -and $mine -match '\(Story\s+([A-Za-z0-9._-]+)\)') {
    $st = $Matches[1]
    $open = @($taskLines | Where-Object {
      $_ -match '^###\s*\[ \]' -and $_ -match ('\(Story\s+' + [regex]::Escape($st) + '\)') })
    if ($open.Count -le 1) { $predictedStory = $st }   # this task is the last one open
  }
}
elseif ((Test-Path $storiesFile) -and (Select-String -Path $storiesFile -Pattern "\b$esc\b" -Quiet)) {
  $predictedStory = $Id
}

if (-not $SkipVerify) {
  $cmd = if ($BuildCommand) { $BuildCommand } else { Get-ClaudeCommand 'Build' }
  if (-not $cmd) {
    Write-Host "[close-unit] WARNING: no build command found in CLAUDE.md - closing WITHOUT verification." -ForegroundColor Yellow
    Write-Host "             Fill CLAUDE.md's 'Build:' line (that is /design's job) so units get verified." -ForegroundColor Yellow
  } else {
    Write-Host "[close-unit] build: $cmd" -ForegroundColor Cyan
    $r = Invoke-Verify $cmd
    # A FILE-LOCK failure is not a code failure: a left-over apphost (a `dotnet run` nobody stopped) holds
    # the output DLL/exe, so the build cannot overwrite it - MSB3026 / "being used by another process". A
    # real run hit this seven times and could not clear it. Clear the project-owned lock and retry ONCE
    # before declaring failure. free-locks is scoped to processes running from THIS project's own folder,
    # so it is safe to invoke automatically.
    if ($r.Code -ne 0 -and $r.Output -match '(?i)MSB3026|being used by another process|cannot access the file.{0,40}\.(dll|exe)|locked by') {
      Write-Host "[close-unit] build blocked by a FILE LOCK (a left-over app process holds the output). Clearing it..." -ForegroundColor Yellow
      $fl = Join-Path $kit "free-locks.ps1"
      if (Test-Path $fl) { & powershell -NoProfile -ExecutionPolicy Bypass -File $fl -ProjectDir $proj 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray } }
      Write-Host "[close-unit] retrying the build once..." -ForegroundColor Yellow
      $r = Invoke-Verify $cmd
    }
    if ($r.Code -ne 0) {
      Write-Host "[close-unit] BUILD FAILED (exit $($r.Code)) - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
      Show-Tail $r.Output
      if (Show-EnvBlock $r.Output) { exit 1 }        # environmental: do not offer "fix the build"
      if ($r.Output -match '(?i)MSB3026|being used by another process') {
        Write-Host "             Still locked after clearing project processes. A process OUTSIDE this project" -ForegroundColor Red
        Write-Host "             may hold the file (an editor, a debugger). Close it, or run: dad free-locks" -ForegroundColor Red
        exit 1
      }
      Show-Signatures $r.Output
      Write-Host "             Fix the build, then re-run. (-SkipVerify overrides, but then 'done' means nothing.)" -ForegroundColor Red
      exit 1
    }
    $notes.Add("build verified ($cmd)")
    # The build just succeeded, so the assemblies are current: refresh the API surface while it is true.
    # Generated from the DLLs, so it cannot drift, and it lands in docs\ where the index already looks.
    try {
      $apiScript = Join-Path $kit "api-surface.ps1"
      if (Test-Path $apiScript) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $apiScript -ProjectDir $proj -Quiet | Out-Null
        if (Test-Path (Join-Path $proj "docs\API-SURFACE.md")) { $notes.Add("API surface regenerated (docs\API-SURFACE.md)") }
      }
    } catch { $warns.Add("could not refresh docs\API-SURFACE.md: $($_.Exception.Message)") }
  }

  # A STORY may only close on tests that actually RAN. Tasks skip this (too slow per task, and a partial
  # story is not claiming verification yet).
  if ($predictedStory) {
    $tcmd = Get-ClaudeCommand 'Test'
    if (-not $tcmd) {
      $warns.Add("story $predictedStory closing WITHOUT tests - no 'Test:' command in CLAUDE.md")
    } else {
      Write-Host "[close-unit] tests (story $predictedStory): $tcmd" -ForegroundColor Cyan
      $t = Invoke-Verify $tcmd
      $count = Get-TestCount $t.Output
      if ($t.Code -ne 0) {
        Write-Host "[close-unit] TESTS FAILED (exit $($t.Code)) - story $predictedStory is NOT closed. Nothing changed." -ForegroundColor Red
        Show-Tail $t.Output
        [void](Show-EnvBlock $t.Output)             # a refusal to RUN the test DLL lands here, not a real failure
        exit 1
      }
      if ($count -eq 0) {
        Write-Host "[close-unit] TESTS RAN ZERO TESTS - story $predictedStory is NOT closed. Nothing changed." -ForegroundColor Red
        Write-Host "             A green run of 0 tests verifies nothing. Usual cause: test projects missing from" -ForegroundColor Red
        Write-Host "             the solution (dotnet sln add tests/**/*.csproj)." -ForegroundColor Red
        Show-Tail $t.Output
        exit 1
      }
      if ($count -lt 0) {
        Write-Host "[close-unit] Could not find any evidence tests ran - story $predictedStory is NOT closed." -ForegroundColor Red
        Write-Host "             No test count in the output. Fix the test command, or use -SkipVerify knowingly." -ForegroundColor Red
        Show-Tail $t.Output
        exit 1
      }
      $notes.Add("tests verified ($count test(s) ran)")
    }
  }
}

# --- 0c) is this id ALREADY closed while new code is waiting? -----------------------------------
# The mismatch this catches, from a real run: a commit titled "T8.1: Implement ObjectStore" actually
# contained VariantProcessor.cs (T7.1's work), because close-unit does `git add -A` and banks whatever
# is dirty under whatever id you pass. Then `t8.1` (lower case) matched the already-ticked T8.1, took
# the idempotent path, and committed T8.2's MetadataStore under a no-op close - leaving T8.2 open with
# its implementation already in history. An id that is already [x] plus pending code is the signature
# of work being filed under the wrong unit, and it is cheap to detect.
$alreadyClosed = $false
if (Test-Path $tasksFile) {
  $alreadyClosed = [bool](Select-String -Path $tasksFile -Pattern "^###\s*\[x\]\s*$esc\b" -Quiet)
  # Report the CANONICAL id: matching is case-insensitive, so `t8.1` silently ticks `T8.1`.
  $canon = Select-String -Path $tasksFile -Pattern "^###\s*\[[ x]\]\s*($esc)\b" | Select-Object -First 1
  if ($canon -and $canon.Matches[0].Groups[1].Value -cne $Id) {
    $warns.Add("id '$Id' matched '$($canon.Matches[0].Groups[1].Value)' (case differs) - using the id as written in TASKS.md")
  }
}
if ($alreadyClosed -and -not $NoCommit -and (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $pending = @()
  try {
    Push-Location $proj
    foreach ($line in @(git status --porcelain -uall)) {
      if ($line.Length -lt 4) { continue }
      $f = $line.Substring(3).Trim().Trim('"')
      if ($f -match '\s->\s') { $f = ($f -split '\s->\s')[-1].Trim().Trim('"') }
      $n = $f.Replace('/', '\')
      if ($n -like "docs\*" -or $n -like ".claude\*" -or $n -like "grades\*") { continue }
      if ($n -like "*\bin\*" -or $n -like "*\obj\*" -or $n -like "bin\*" -or $n -like "obj\*") { continue }
      if (@(".cs",".fs",".vb",".py",".ts",".tsx",".js",".jsx",".go",".rs",".java",".kt",".c",".h",
            ".cpp",".hpp",".cc",".rb",".php",".swift",".sql",".csproj",".fsproj",".sln") -notcontains
          [System.IO.Path]::GetExtension($n)) { continue }
      $pending += $n
    }
  } catch { } finally { Pop-Location; $ErrorActionPreference = $prevEap }
  if ($pending.Count -gt 0) {
    Write-Host "[close-unit] '$Id' is ALREADY closed, but $($pending.Count) code file(s) are uncommitted:" -ForegroundColor Red
    foreach ($f in ($pending | Select-Object -First 8)) { Write-Host "               $f" -ForegroundColor Red }
    Write-Host "             Committing them under '$Id' would file this work against the wrong unit - the" -ForegroundColor Red
    Write-Host "             commit message would describe something the diff does not contain. Close them" -ForegroundColor Red
    Write-Host "             under the id that OWNS them (check docs\TASKS.md), or -NoCommit to skip banking." -ForegroundColor Red
    exit 1
  }
}

# --- 0d) did the verification surface SHRINK? --------------------------------------------------
# Every other gate here asks "is X OK now?", which is satisfied by DELETING X. A run rewrote a test
# file to add a fixture, 15 of 16 tests did not survive, and every gate went green: build passed, tests
# RAN (11 > 0), tests PASSED (8), tree clean. Deleting a red test is the shortest path to "make the
# tests pass" and nothing forbade it. So: counts may not fall silently.
if (-not $SkipVerify) {
  $ratchet = Join-Path $kit "ratchet.ps1"
  if (Test-Path $ratchet) {
    $rOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $ratchet -ProjectDir $proj 2>&1 | Out-String
    $rCode = $LASTEXITCODE
    # FAIL OPEN on a broken checker. Exit 1 means "something shrank"; a CRASH (bad path, unreadable file,
    # a bug of mine) must not block a legitimate close. A gate that fails closed on its own defects stops
    # real work and gets switched off, which costs more than the case it was guarding. Same principle as
    # dad-guard, and it is why the first version of this check broke three passing close-unit tests.
    if ($rOut -match 'CategoryInfo|FullyQualifiedErrorId') {
      $warns.Add("ratchet could not run - shrink NOT verified this close")
      $rCode = 0
    }
    if ($rCode -ne 0 -and -not $AcceptShrink) {
      Write-Host "[close-unit] VERIFICATION SURFACE SHRANK - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
      Write-Host ($rOut.TrimEnd())
      Write-Host "             Find out WHAT vanished (and what merely moved to another file):" -ForegroundColor Red
      Write-Host "               powershell -File `"$kit\recover-lost.ps1`" -ProjectDir `"$proj`"" -ForegroundColor Yellow
      Write-Host "               ...add -Restore to put the vanished units back, KEEPING what the change added." -ForegroundColor Yellow
      Write-Host "             Or re-run with -AcceptShrink if the removal was deliberate (lowers the baseline)." -ForegroundColor Red
      exit 1
    }
    if ($rCode -ne 0 -and $AcceptShrink) { $warns.Add("shrink ACCEPTED by -AcceptShrink - baseline lowered") }
  }
}

# --- 1) tick the unit ---
$closedTask = $false
$parentStory = $null
if ((Test-Path $tasksFile) -and (Select-String -Path $tasksFile -Pattern "^###\s*\[[ x]\]\s*$esc\b" -Quiet)) {
  $lines = Get-Content $tasksFile -Encoding UTF8
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^###\s*\[( |x)\]\s*$esc\b") {
      if ($Matches[1] -eq 'x') { $notes.Add("task $Id already [x]") }
      else {
        $lines[$i] = [regex]::Replace($lines[$i], '^(###\s*\[)\s(\])', '$1x$2')
        Save-Text $tasksFile $lines
        $notes.Add("task $Id -> [x] in TASKS.md")
      }
      if ($lines[$i] -match '\(Story\s+([A-Za-z0-9._-]+)\)') { $parentStory = $Matches[1] }
      $closedTask = $true
      break
    }
  }

  # --- 2) story roll-up: only when EVERY task of the parent story is ticked ---
  if ($parentStory) {
    $all = Get-Content $tasksFile -Encoding UTF8 |
           Where-Object { $_ -match '^###\s*\[[ x]\]' -and $_ -match ('\(Story\s+' + [regex]::Escape($parentStory) + '\)') }
    $done = @($all | Where-Object { $_ -match '^###\s*\[x\]' }).Count
    if ($all.Count -gt 0 -and $done -eq $all.Count) { Set-StoryDone $parentStory; $storyClosed = $parentStory }
    else { $notes.Add("story $parentStory : $done/$($all.Count) tasks done - not rolling up yet") }
  }
}
elseif ((Test-Path $storiesFile) -and (Select-String -Path $storiesFile -Pattern "\b$esc\b" -Quiet)) {
  Set-StoryDone $Id      # no task map: the unit IS a story
  $storyClosed = $Id
}
else {
  Write-Host "[close-unit] '$Id' not found in TASKS.md or STORIES.md - check the id (nothing committed)." -ForegroundColor Red
  exit 1
}

# --- 2b) a DONE story needs a real grade card ---
# Grading is the step that keeps getting skipped. At task level this only warns (the card is written AFTER
# the story rolls up, per /build's order); pass -RequireGrade at the story-level close to make it binding.
if ($storyClosed) {
  $gradeIssue = Test-GradeCard $storyClosed
  if ($gradeIssue) {
    if ($RequireGrade) { $problems.Add("story $storyClosed : $gradeIssue - run /grade $storyClosed") }
    else { $warns.Add("story $storyClosed : $gradeIssue - run /grade $storyClosed") }
  } else { $notes.Add("story $storyClosed : grade card present") }
}

# --- 3) reindex so the next unit's agents see the updated state ---
if (-not $NoReindex) {
  $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
  if (Test-Path $exe) {
    # NOTE: never '2>&1' a native exe here - in PS 5.1 that wraps stderr in NativeCommandError, which
    # ErrorActionPreference=Stop turns into a terminating error even on exit code 0.
    & $exe --reindex $docs | Out-Null
    if ($LASTEXITCODE -eq 0) { $notes.Add("reindexed $docs") } else { $problems.Add("reindex failed (exit $LASTEXITCODE)") }
  } else { $problems.Add("local-tools.exe not built - skipped reindex") }
}

# --- 4) commit: this unit becomes a restore point ---
$committed = $false
if (-not $NoCommit) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $problems.Add("git not found - no checkpoint") }
  elseif (-not (Test-Path (Join-Path $proj ".git"))) { $problems.Add("no git repo here - run upgrade-project.cmd to add one") }
  else {
    Push-Location $proj
    # git writes harmless notices (CRLF normalization) to stderr. In PS 5.1 those become
    # NativeCommandError records, which ErrorActionPreference=Stop would treat as fatal - so relax it
    # here and judge git ONLY by $LASTEXITCODE. Never add '2>&1' to these calls.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $msg = if ($Title) { "$Id`: $Title" } else { "$Id" }
      git add -A | Out-Null
      $staged = (git diff --cached --name-only | Out-String).Trim()
      if (-not $staged) { $notes.Add("nothing to commit (working tree already clean)") ; $committed = $true }
      else {
        git -c user.name="DAD-kit" -c user.email="dad-kit@local" commit -q -m $msg | Out-Null
        if ($LASTEXITCODE -ne 0) { $problems.Add("git commit exited $LASTEXITCODE") }
        # --- 5) VERIFY the commit actually landed and mentions this unit ---
        $last = (git log --oneline -1 | Out-String).Trim()
        if ($last -match [regex]::Escape($Id)) { $notes.Add("committed: $last"); $committed = $true }
        else { $problems.Add("commit did not land or does not mention $Id (last: $last)") }
      }
    } catch { $problems.Add("git commit failed: $($_.Exception.Message)") }
    finally { $ErrorActionPreference = $prevEap; Pop-Location }
  }
}

# --- verify bookkeeping on disk ---
if ($closedTask -and -not (Select-String -Path $tasksFile -Pattern "^###\s*\[x\]\s*$esc\b" -Quiet)) {
  $problems.Add("VERIFY FAILED: $Id is still not [x] in TASKS.md")
}

# --- record the commands that ACTUALLY WORKED --------------------------------------------------
# docs\RECIPES.md was designed as a proven-commands log that agents append to on success. After NINE runs
# on a real project it contained 18 lines: the bare template, zero entries. Asking a model to remember to
# write down what worked is the same class of instruction as asking it to remember to run close-unit, and
# it failed the same way. Meanwhile runs kept emitting broken shell - one used bash syntax and a wrong
# path (`cd D:/projects/mediamotor_iiif`, missing two segments) and lost the turn to it.
# So the close-out writes the entry. These two commands are the ones just VERIFIED to work on this machine.
if ($problems.Count -eq 0) {
  try {
    $recipes = Join-Path $docs "RECIPES.md"
    if (Test-Path $recipes) {
      $rt = Get-Content $recipes -Raw
      $add = @()
      foreach ($pair in @(@{ K='Build'; V=(Get-ClaudeCommand 'Build') }, @{ K='Test'; V=(Get-ClaudeCommand 'Test') })) {
        if (-not $pair.V) { continue }
        # One row per distinct command, never a duplicate on every close.
        if ($rt -match [regex]::Escape($pair.V)) { continue }
        $add += "| ``$($pair.V)`` | $($pair.K.ToLower()) this project | from the project root | verified by close-unit on $Id | $(Get-Date -Format 'yyyy-MM-dd') |"
      }
      if ($add.Count) {
        if ($rt -notmatch '(?m)^##\s*Verified by close-unit') {
          $rt = $rt.TrimEnd() + "`r`n`r`n## Verified by close-unit`r`n" +
                "<!-- Appended automatically when a unit closes clean. These ran and worked ON THIS MACHINE. -->`r`n" +
                "| Command | Does | When | Gotcha | Verified |`r`n|---|---|---|---|---|`r`n"
        }
        $rt = $rt.TrimEnd() + "`r`n" + ($add -join "`r`n") + "`r`n"
        [System.IO.File]::WriteAllText($recipes, $rt, (New-Object System.Text.UTF8Encoding($false)))
        $notes.Add("recorded $($add.Count) verified command(s) in docs\RECIPES.md")
      }
    }
  } catch { $warns.Add("could not update docs\RECIPES.md: $($_.Exception.Message)") }
}

# --- stamp for the stop guard -----------------------------------------------------------------
# dad-guard.ps1 blocks a turn from ending on uncommitted, unverified code. A clean close IS the
# verification, so record it. Only on success - a failed close must stay blocked.
if ($problems.Count -eq 0) {
  try {
    $dotClaude = Join-Path $proj ".claude"
    if (-not (Test-Path $dotClaude)) { New-Item -ItemType Directory -Path $dotClaude -Force | Out-Null }
    [System.IO.File]::WriteAllText((Join-Path $dotClaude ".dad-verified"),
      "verified-by: close-unit $Id`r`n", (New-Object System.Text.UTF8Encoding($false)))
  } catch { $warns.Add("could not write the .dad-verified stamp: $($_.Exception.Message)") }
}

Write-Host "== close-unit $Id ==" -ForegroundColor Cyan
foreach ($n in $notes) { Write-Host "  ok   $n" -ForegroundColor Green }
foreach ($w in $warns) { Write-Host "  WARN $w" -ForegroundColor Yellow }
foreach ($p in $problems) { Write-Host "  FAIL $p" -ForegroundColor Red }
if ($problems.Count -gt 0) { Write-Host "close-unit INCOMPLETE - fix the above before moving on." -ForegroundColor Red; exit 1 }
# The close verified: build (and tests at a story close), bookkeeping landed, commit landed. THIS is the
# state worth ratcheting to - never on a failed close, or a bad run would raise the bar it just failed.
try {
  $ratchet = Join-Path $kit "ratchet.ps1"
  if (Test-Path $ratchet) { & powershell -NoProfile -ExecutionPolicy Bypass -File $ratchet -ProjectDir $proj -Update | Out-Null }
} catch { }
Write-Host "close-unit OK" -ForegroundColor Green
