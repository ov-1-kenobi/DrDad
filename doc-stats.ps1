# doc-stats.ps1 - print the REAL counts for docs/STATUS.md. The librarian must RUN this rather than
# eyeball the files: a hand-counted dashboard reported "Stories: 1/1  Tasks: 1/1" on a project with 13
# stories (5 done) and 16 tasks (6 done). Deterministic beats estimation.
#
#   doc-stats.ps1 [-ProjectDir .]        human-readable
#   doc-stats.ps1 -Json                  machine-readable (same numbers)
#   doc-stats.ps1 -UpdateStatus          WRITE the Snapshot line into docs/STATUS.md, deterministically
#
# Counts: story headings + DONE markers in STORIES.md, task blocks + [x] in TASKS.md, DESIGN Status,
# the next ready task (first unchecked whose deps are all [x]), and which DONE units lack a real grade card.

param([string]$ProjectDir = ".", [switch]$Json, [switch]$UpdateStatus)
$ErrorActionPreference = "Stop"
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path

$docs = Join-Path $proj "docs"
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
