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
  [switch]$RequireGrade
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
    if ($r.Code -ne 0) {
      Write-Host "[close-unit] BUILD FAILED (exit $($r.Code)) - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
      Show-Tail $r.Output
      Write-Host "             Fix the build, then re-run. (-SkipVerify overrides, but then 'done' means nothing.)" -ForegroundColor Red
      exit 1
    }
    $notes.Add("build verified ($cmd)")
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
        git -c user.name="AD-kit" -c user.email="ad-kit@local" commit -q -m $msg | Out-Null
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

Write-Host "== close-unit $Id ==" -ForegroundColor Cyan
foreach ($n in $notes) { Write-Host "  ok   $n" -ForegroundColor Green }
foreach ($w in $warns) { Write-Host "  WARN $w" -ForegroundColor Yellow }
foreach ($p in $problems) { Write-Host "  FAIL $p" -ForegroundColor Red }
if ($problems.Count -gt 0) { Write-Host "close-unit INCOMPLETE - fix the above before moving on." -ForegroundColor Red; exit 1 }
Write-Host "close-unit OK" -ForegroundColor Green
