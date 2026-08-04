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
if (-not $SkipVerify) {
  $cmd = $BuildCommand
  if (-not $cmd) {
    $cm = Join-Path $proj "CLAUDE.md"
    if (Test-Path $cm) {
      $m = [regex]::Match((Get-Content $cm -Raw), '(?m)^\s*-\s*\*{0,2}Build\*{0,2}\s*:\s*`?([^`\r\n]+?)`?\s*$')
      if ($m.Success) { $cmd = $m.Groups[1].Value.Trim() }
    }
  }
  if ($cmd -match '^<' -or $cmd -match 'set in .forge') { $cmd = "" }   # unfilled placeholder

  if (-not $cmd) {
    Write-Host "[close-unit] WARNING: no build command found in CLAUDE.md - closing WITHOUT verification." -ForegroundColor Yellow
    Write-Host "             Fill CLAUDE.md's 'Build:' line (that is /forge's job) so units get verified." -ForegroundColor Yellow
  } else {
    Write-Host "[close-unit] verifying: $cmd" -ForegroundColor Cyan
    # Run it in a CHILD shell, never Invoke-Expression: a command string containing 'exit' would otherwise
    # terminate this script (and appear to succeed without doing the bookkeeping).
    Push-Location $proj
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $buildOut = ""
    try   { $buildOut = (cmd /c "$cmd" | Out-String); $code = $LASTEXITCODE }
    catch { $code = 1; $buildOut = $_.Exception.Message }
    finally { $ErrorActionPreference = $prevEap; Pop-Location }
    if ($code -ne 0) {
      Write-Host "[close-unit] BUILD FAILED (exit $code) - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
      $tail = ($buildOut -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 15)
      foreach ($l in $tail) { Write-Host "    $l" -ForegroundColor DarkYellow }
      Write-Host "             Fix the build, then re-run. (-SkipVerify overrides, but then 'done' means nothing.)" -ForegroundColor Red
      exit 1
    }
    $notes.Add("build verified ($cmd)")
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
