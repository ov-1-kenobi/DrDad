# doc-stats.ps1 - print the REAL counts for docs/STATUS.md. The librarian must RUN this rather than
# eyeball the files: a hand-counted dashboard reported "Stories: 1/1  Tasks: 1/1" on a project with 13
# stories (5 done) and 16 tasks (6 done). Deterministic beats estimation.
#
#   doc-stats.ps1 [-ProjectDir .]        human-readable
#   doc-stats.ps1 -Json                  machine-readable (same numbers)
#   doc-stats.ps1 -UpdateStatus          WRITE the Snapshot line into docs/STATUS.md, deterministically
#   doc-stats.ps1 -Contract C6           does contract C6 exist? exit 0 + its heading and line, or exit 1
#   doc-stats.ps1 -Contract *            list every contract in the design doc
#   doc-stats.ps1 -Findings              the STATE findings, computed - the librarian must not author these
#
# Counts: story headings + DONE markers in STORIES.md, task blocks + [x] in TASKS.md, DESIGN Status,
# the next ready task (first unchecked whose deps are all [x]), and which DONE units lack a real grade card.

param([string]$ProjectDir = ".", [switch]$Json, [switch]$UpdateStatus, [string]$Contract = "", [switch]$Findings)
$ErrorActionPreference = "Stop"
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path

$docs = Join-Path $proj "docs"
# --- contract existence: settle it with a script, never on the model's word ------------------------
# A real run halted claiming "the contracts C6 and C7 are not present in DESIGN.md - a critical gap
# preventing implementation". Both were there, at lines 299 and 334. It had also invented the CONTENTS of
# C5 (quoting an "Azure Storage Adapters" section that exists nowhere in the project). A fabricated blocker
# costs a whole session, and whether a heading exists is exactly the kind of question a grep settles.
if ($Contract) {
  $dp = $null
  foreach ($n in @("DESIGN.md","TEDD.md")) { $c = Join-Path $docs $n; if (Test-Path $c) { $dp = $c; break } }
  if (-not $dp) { Write-Host "no design doc in $docs" -ForegroundColor Yellow; exit 1 }
  $all = Select-String -Path $dp -Pattern '^#{2,4}\s*(C[0-9]+[A-Za-z0-9-]*)\s*:\s*(.*)$'
  if ($Contract -eq "*" -or $Contract -eq "all") {
    if (-not $all) { Write-Host "no '## C<n>: ...' contracts in $(Split-Path $dp -Leaf)" -ForegroundColor Yellow; exit 1 }
    Write-Host "$($all.Count) contract(s) in $(Split-Path $dp -Leaf):" -ForegroundColor Cyan
    foreach ($m in $all) { Write-Host ("  {0,-8} {1}  (line {2})" -f $m.Matches[0].Groups[1].Value, $m.Matches[0].Groups[2].Value.Trim(), $m.LineNumber) }
    exit 0
  }
  $hit = $all | Where-Object { $_.Matches[0].Groups[1].Value -eq $Contract } | Select-Object -First 1
  if ($hit) {
    Write-Host "$Contract EXISTS: $($hit.Matches[0].Groups[2].Value.Trim())  ($(Split-Path $dp -Leaf) line $($hit.LineNumber))" -ForegroundColor Green
    Write-Host "  -> it is pinned. Do NOT report it missing; search_datasheets for it and implement it." -ForegroundColor Green
    exit 0
  }
  Write-Host "$Contract is NOT in $(Split-Path $dp -Leaf). Contracts present:" -ForegroundColor Yellow
  foreach ($m in $all) { Write-Host "  $($m.Matches[0].Groups[1].Value)" -ForegroundColor Yellow -NoNewline; Write-Host "" }
  exit 1
}
$mcp = Join-Path $proj ".mcp.json"
if (Test-Path $mcp) {
  try {
    $d = (Get-Content $mcp -Raw | ConvertFrom-Json).mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR
    if ($d -and (Test-Path $d)) { $docs = (Resolve-Path -LiteralPath $d).Path }
  } catch { }
}
$storiesFile = Join-Path $docs "STORIES.md"
$tasksFile   = Join-Path $docs "TASKS.md"
$gradesDir   = Join-Path $proj "grades"

# --- design status ---
$designStatus = "(no design doc)"
$designName = ""
foreach ($n in @("DESIGN.md", "TEDD.md")) {
  $p = Join-Path $docs $n
  if (Test-Path $p) {
    $designName = $n
    $m = Select-String -Path $p -Pattern '^\s*Status:\s*(\w+)' | Select-Object -First 1
    if ($m) { $designStatus = $m.Matches[0].Groups[1].Value }
    break
  }
}

# --- stories: headings that carry an S-id, and how many are marked DONE ---
$storyIds = @(); $storiesDone = @()
if (Test-Path $storiesFile) {
  foreach ($line in Get-Content $storiesFile -Encoding UTF8) {
    if ($line -match '^#{1,6}\s' -and $line -match '\b(S\d+[A-Za-z0-9._-]*)\b') {
      $id = $Matches[1]
      if ($storyIds -notcontains $id) { $storyIds += $id }
      if ($line -match '<!--\s*Status:\s*DONE\s*-->') { $storiesDone += $id }
    }
  }
}

# --- tasks: '### [ ] <id>' blocks ---
$tasks = @()
if (Test-Path $tasksFile) {
  foreach ($line in Get-Content $tasksFile -Encoding UTF8) {
    if ($line -match '^###\s*\[( |x)\]\s*([A-Za-z0-9._-]+)') {
      $story = if ($line -match '\(Story\s+([A-Za-z0-9._-]+)\)') { $Matches[1] } else { "" }
      # NOTE: $Matches was overwritten above - re-match for the id/state
      $m2 = [regex]::Match($line, '^###\s*\[( |x)\]\s*([A-Za-z0-9._-]+)')
      $tasks += [pscustomobject]@{ Id = $m2.Groups[2].Value; Done = ($m2.Groups[1].Value -eq 'x'); Story = $story }
    }
  }
}
$tasksDone = @($tasks | Where-Object { $_.Done })

# --- next ready: first unchecked task in file order (deps unresolved here - the map's Build order rules) ---
$next = ($tasks | Where-Object { -not $_.Done } | Select-Object -First 1)

# --- DONE units missing a REAL grade card (>=800 bytes and has a history table) ---
$missing = @()
$doneUnits = @($storiesDone) + @($tasksDone | ForEach-Object { $_.Id })
foreach ($u in ($doneUnits | Select-Object -Unique)) {
  $card = Join-Path $gradesDir "$($u)_GRADE.md"
  if (-not (Test-Path $card)) { $missing += "$u (no card)"; continue }
  $len = (Get-Item $card).Length
  $hasHist = Select-String -Path $card -Pattern '##\s*Grade history' -Quiet
  if ($len -lt 800 -or -not $hasHist) { $missing += "$u (stub: $len bytes$(if(-not $hasHist){', no history'}))" }
}

# --- test projects that exist on disk but are NOT in the solution ---
# `dotnet test` on a .sln that lists no test projects exits 0 having run NOTHING. Six orphaned test
# projects are how a build with 21 errors carried five "DONE" stories.
$orphanTests = @()
$sln = Get-ChildItem $proj -Filter *.sln -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sln) {
  $slnText = Get-Content $sln.FullName -Raw
  $testProjs = Get-ChildItem $proj -Recurse -Filter *.csproj -File -ErrorAction SilentlyContinue |
    Where-Object {
      $parts = $_.FullName.Split([char]92)
      $_.FullName -match '(\\tests?\\|\.Tests?\.csproj$|Tests\.csproj$)' -and
      -not ($parts | Where-Object { $_ -in @('bin','obj','.claude','.git','node_modules','worktrees') }) }
  foreach ($tp in $testProjs) {
    if ($slnText -notmatch [regex]::Escape($tp.Name)) {
      $orphanTests += $tp.FullName.Substring($proj.Length).TrimStart([char]92)
    }
  }
}

$result = [ordered]@{
  design        = $designName
  designStatus  = $designStatus
  storiesTotal  = $storyIds.Count
  storiesDone   = $storiesDone.Count
  tasksTotal    = $tasks.Count
  tasksDone     = $tasksDone.Count
  nextTask      = if ($next) { "$($next.Id)$(if($next.Story){" (Story $($next.Story))"})" } else { "none" }
  gradesMissing = $missing
  orphanTests   = $orphanTests
}

if ($Findings) {
  # The STATE half of an audit, computed rather than observed. An /audit on a healthy project reported
  # "DESIGN.md Status: LOCKED header missing" (it is on line 5), "STORIES.md missing <!-- Status --> markers
  # for S2-S6" (all 14 stories have them), and "TASKS.md has 0 tasks with [x]" (10 are ticked) - having just
  # run this script, which printed the real numbers. Saying yes to those "fixes" would have rewritten a
  # correct header, re-marked marked stories, and re-ticked ticked tasks.
  #
  # So the librarian no longer gets to author this category. These findings are generated; its remit is what
  # a script cannot do - scope contamination, traceability judgement, orphan files.
  $f = New-Object System.Collections.Generic.List[string]

  if ($designStatus -eq "(no design doc)") { $f.Add("[design] no design doc in docs\ - run /scaffold or /design") }
  elseif ($designStatus -notin @("DRAFT","LOCKED")) { $f.Add("[design] $designName Status: is '$designStatus' - must be DRAFT or LOCKED") }

  # story headings carrying an id but no Status marker at all
  if (Test-Path $storiesFile) {
    foreach ($line in Get-Content $storiesFile -Encoding UTF8) {
      if ($line -match '^#{1,6}\s' -and $line -match '\b(S\d+[A-Za-z0-9._-]*)\b') {
        $sid = $Matches[1]
        if ($line -notmatch '<!--\s*Status:') { $f.Add("[scribe] story $sid has no <!-- Status: ... --> marker on its heading") }
        elseif ($line -notmatch '<!--\s*Status:\s*(TODO|DOING|DONE|BLOCKED)\s*-->') {
          $bad = [regex]::Match($line, '<!--\s*Status:\s*([^-]*)-->').Groups[1].Value.Trim()
          $f.Add("[scribe] story $sid Status marker is '$bad' - use TODO / DOING / DONE / BLOCKED")
        }
      }
    }
  }

  # roll-up disagreement, both directions
  foreach ($sid in ($tasks | Where-Object { $_.Story } | ForEach-Object { $_.Story } | Select-Object -Unique)) {
    $mine = @($tasks | Where-Object { $_.Story -eq $sid })
    $open = @($mine | Where-Object { -not $_.Done })
    $isDone = $storiesDone -contains $sid
    if ($isDone -and $open.Count -gt 0) {
      $f.Add("[taskmap] story $sid is DONE but $($open.Count) of its task(s) are still [ ]: $(($open.Id) -join ', ')")
    }
    if (-not $isDone -and $open.Count -eq 0 -and $mine.Count -gt 0) {
      $f.Add("[scribe] story $sid has all $($mine.Count) task(s) [x] but is not marked DONE")
    }
  }

  foreach ($m in $missing) { $f.Add("[grade] $m") }
  foreach ($o in $orphanTests) { $f.Add("[dev] test project not in the solution (dotnet test silently skips it): $o") }

  # a done unit with no commit mentioning it - a missed checkpoint
  if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try {
      Push-Location $proj
      $log = (git log --oneline | Out-String)
      foreach ($u in (@($storiesDone) + @($tasksDone | ForEach-Object { $_.Id }) | Select-Object -Unique)) {
        if ($log -notmatch [regex]::Escape($u)) { $f.Add("[dev] $u is done but no commit mentions it - missed checkpoint") }
      }
    } catch { } finally { Pop-Location; $ErrorActionPreference = $prevEap }
  }

  Write-Host "== STATE FACTS (computed - do NOT contradict these) ==" -ForegroundColor Cyan
  Write-Host ("  design {0}: Status {1} | stories {2}/{3} DONE | tasks {4}/{5} [x] | next {6}" -f `
    $designName, $designStatus, $storiesDone.Count, $storyIds.Count, $tasksDone.Count, $tasks.Count,
    $(if ($next) { $next.Id } else { "none" }))
  Write-Host ""
  Write-Host "== STATE FINDINGS (generated; the librarian must not author this category) ==" -ForegroundColor Cyan
  if ($f.Count -eq 0) { Write-Host "  none - document state is consistent." -ForegroundColor Green }
  else { foreach ($x in $f) { Write-Host "  $x" -ForegroundColor Yellow } }
  Write-Host ""
  Write-Host "Librarian's remit is what this CANNOT compute: scope contamination, traceability judgement," -ForegroundColor DarkGray
  Write-Host "stray/ad-hoc files, mangled markup. Anything above is already handled." -ForegroundColor DarkGray
  exit 0
}
if ($Json) { $result | ConvertTo-Json -Depth 5; exit 0 }
if ($UpdateStatus) {
  # Take the counting away from the model entirely. Telling the librarian to run this script was not
  # enough - a real audit reported "STATUS.md has been refreshed with current progress metrics" having
  # never invoked it, so the dashboard carried estimates. The Snapshot line is now generated here; the
  # librarian owns only the prose sections below it.
  $statusPath = Join-Path $docs "STATUS.md"
  if (-not (Test-Path $statusPath)) {
    Write-Host "no docs\STATUS.md to update (upgrade-project.cmd creates it)" -ForegroundColor Yellow
    exit 0
  }
  $today = (Get-Date).ToString("yyyy-MM-dd")
  $snapshot = @(
    "## Snapshot",
    "- As of: $today  (counts generated by doc-stats.ps1 - do not hand-edit this section)",
    ("- DESIGN: {0}   Stories: {1}/{2}   Tasks: {3}/{4}" -f $result.designStatus, $result.storiesDone, $result.storiesTotal, $result.tasksDone, $result.tasksTotal),
    "- NEXT: $($result.nextTask)"
  )
  if ($result.gradesMissing.Count) { $snapshot += "- Grade cards missing: $($result.gradesMissing.Count)" }
  if ($result.orphanTests.Count)   { $snapshot += "- ORPHAN test projects (not in the .sln, silently skipped): $($result.orphanTests.Count)" }

  $lines = Get-Content $statusPath -Encoding UTF8
  $out = New-Object System.Collections.Generic.List[string]
  $i = 0; $replaced = $false
  while ($i -lt $lines.Count) {
    if ($lines[$i] -match '^##\s+Snapshot\b') {
      foreach ($s in $snapshot) { $out.Add($s) | Out-Null }
      $out.Add("") | Out-Null
      $i++
      while ($i -lt $lines.Count -and $lines[$i] -notmatch '^##\s') { $i++ }   # drop the old block
      $replaced = $true
      continue
    }
    $out.Add($lines[$i]) | Out-Null; $i++
  }
  if (-not $replaced) {
    # No Snapshot section (hand-made STATUS): insert after the title.
    $out = New-Object System.Collections.Generic.List[string]
    if ($lines.Count) { $out.Add($lines[0]) | Out-Null; $out.Add("") | Out-Null }
    foreach ($s in $snapshot) { $out.Add($s) | Out-Null }
    $out.Add("") | Out-Null
    for ($j = 1; $j -lt $lines.Count; $j++) { $out.Add($lines[$j]) | Out-Null }
  }
  [System.IO.File]::WriteAllText($statusPath, (($out -join "`r`n").TrimEnd() + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "docs\STATUS.md Snapshot updated: $($result.storiesDone)/$($result.storiesTotal) stories, $($result.tasksDone)/$($result.tasksTotal) tasks, next $($result.nextTask)" -ForegroundColor Green
  exit 0
}


Write-Host "== doc-stats: $proj ==" -ForegroundColor Cyan
Write-Host ("  design        : {0}  Status: {1}" -f $result.design, $result.designStatus)
Write-Host ("  stories       : {0}/{1} done" -f $result.storiesDone, $result.storiesTotal)
Write-Host ("  tasks         : {0}/{1} done" -f $result.tasksDone, $result.tasksTotal)
Write-Host ("  next task     : {0}" -f $result.nextTask)
if ($missing.Count) {
  Write-Host ("  grades missing: {0}" -f $missing.Count) -ForegroundColor Yellow
  foreach ($m in $missing) { Write-Host "      $m" -ForegroundColor Yellow }
} else {
  Write-Host "  grades missing: none" -ForegroundColor Green
}
if ($orphanTests.Count) {
  Write-Host ("  ORPHAN TESTS  : {0} test project(s) NOT in the solution - 'dotnet test' skips them silently" -f $orphanTests.Count) -ForegroundColor Red
  foreach ($o in $orphanTests) { Write-Host "      $o" -ForegroundColor Red }
  Write-Host "      fix: dotnet sln add <each path above>" -ForegroundColor Red
} elseif ($sln) {
  Write-Host "  test projects : all in the solution" -ForegroundColor Green
}
Write-Host ""
Write-Host "Use these numbers verbatim in docs/STATUS.md - do not estimate." -ForegroundColor Cyan
exit 0
