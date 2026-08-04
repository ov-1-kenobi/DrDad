# doc-stats.ps1 - print the REAL counts for docs/STATUS.md. The librarian must RUN this rather than
# eyeball the files: a hand-counted dashboard reported "Stories: 1/1  Tasks: 1/1" on a project with 13
# stories (5 done) and 16 tasks (6 done). Deterministic beats estimation.
#
#   doc-stats.ps1 [-ProjectDir .]        human-readable
#   doc-stats.ps1 -Json                  machine-readable (same numbers)
#
# Counts: story headings + DONE markers in STORIES.md, task blocks + [x] in TASKS.md, DESIGN Status,
# the next ready task (first unchecked whose deps are all [x]), and which DONE units lack a real grade card.

param([string]$ProjectDir = ".", [switch]$Json)
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
