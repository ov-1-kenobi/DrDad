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

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param([string]$ProjectDir = ".", [switch]$Json, [switch]$UpdateStatus, [string]$Contract = "", [switch]$Findings, [switch]$Junk)
$ErrorActionPreference = "Stop"

# PROJECT-ROOT JUNK, computed in ONE place so `-Findings`, `-Junk` and `dad tidy` never disagree about what
# is junk. Scratch belongs in _tmp/ (gitignored, swept by tidy); anything junky at the ROOT is a mistake:
#   strayFiles  ad-hoc SUMMARY/COMPLETE/IMPLEMENTATION/notes files the kit forbids (NOT the user's run*.txt)
#   mangledDirs a dir whose name is a run-together path (a Windows path handed to bash, backslashes eaten)
#   binlogs     MSBuild .binlog build artifacts
#   extraSlns   a second .sln/.slnx (splits the build)
#   tmpDir      _tmp/ exists (sanctioned scratch - not junk, but tidy clears it)
function Get-ProjectJunk([string]$root) {
  $rootFiles = @(Get-ChildItem $root -File -ErrorAction SilentlyContinue)
  $strayRx = '(?i)(^|[_.-])(summary|complete|completed|notes?|results?|implementation|handoff|scratch|build_summary)([_.-]|\.md$|\.txt$)'
  $stray = @($rootFiles | Where-Object { $_.Name -match $strayRx -and $_.Name -notmatch '(?i)^(CHANGELOG|CONTRIBUTING)\b' } | ForEach-Object { $_.Name })
  $stray = @($stray | Where-Object { $_ -notmatch '(?i)run.*\.txt$|.*run\.txt$|.*run\d*\.txt$' })  # user run exports are not junk
  $leaf = (Split-Path $root -Leaf)
  $mangled = @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Where-Object {
    $n = $_.Name
    ($n -notmatch '[\\/ ._-]') -and (
      ($n.Length -ge 20 -and $n -match "(?i)$([regex]::Escape($leaf)).") -or
      ($n -match '(?i)^[a-z]:?(users|projects|documents|desktop|home|src)[a-z0-9]{6,}')
    )
  } | ForEach-Object { $_.Name })
  $binlogs = @($rootFiles | Where-Object { $_.Name -match '(?i)\.binlog$' } | ForEach-Object { $_.Name })
  $slns = @($rootFiles | Where-Object { $_.Name -match '(?i)\.slnx?$' } | ForEach-Object { $_.Name })
  $extraSlns = @()
  if ($slns.Count -gt 1) { $extraSlns = $slns }
  return [pscustomobject]@{
    StrayFiles = $stray; MangledDirs = $mangled; Binlogs = $binlogs
    ExtraSolutions = $extraSlns
    TmpDir = (Test-Path -LiteralPath (Join-Path $root "_tmp"))
  }
}

if (-not (Test-Path -LiteralPath $ProjectDir)) {
  Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red
  exit 2
}
if ($Junk) {
  $j = Get-ProjectJunk ((Resolve-Path -LiteralPath $ProjectDir).Path)
  $j | ConvertTo-Json -Depth 5
  exit 0
}
# GUARD: -ProjectDir must exist. Resolve-Path ERRORS on a missing path but the .cmd wrapper still exited 0,
# so a mistyped path looked like a project with no stories and no tasks. Fail loudly instead.
if (-not (Test-Path -LiteralPath $ProjectDir)) {
  Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red
  exit 2
}
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

# --- stories: headings that carry an S-id, how many are DONE, and which were HAND-ticked ---
# DONE match is prefix-tolerant ('DONE' followed by anything) because close-unit now stamps a provenance
# token: '<!-- Status: DONE closed:close-unit -->'. A story marked DONE WITHOUT that token was ticked by
# hand, not closed by close-unit - which is how a run reported 5/5 done with 21 tasks still open.
$storyIds = @(); $storiesDone = @(); $handTicked = @()
if (Test-Path $storiesFile) {
  foreach ($line in Get-Content $storiesFile -Encoding UTF8) {
    if ($line -match '^#{1,6}\s' -and $line -match '\b(S\d+[A-Za-z0-9._-]*)\b') {
      $id = $Matches[1]
      if ($storyIds -notcontains $id) { $storyIds += $id }
      if ($line -match '<!--\s*Status:\s*DONE\b') {
        $storiesDone += $id
        if ($line -notmatch 'closed:close-unit') { $handTicked += $id }
      }
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

# --- DONE STORIES missing a REAL grade card (>=800 bytes and has a history table) ---
# STORIES ONLY. This used to include every done TASK, contradicting the rest of the kit - /build:2
# ("grade + hygiene per story"), /build:98 ("grade the completed STORY"), DESIGN.md R18 ("per STORY grade")
# and close-unit, which only demands a card under -RequireGrade on a story close. On any project with a
# task map that produced a permanent [grade] finding for every closed task: findings that can never be
# resolved, which is how a model learns to ignore the findings list entirely.
$missing = @()
$doneUnits = @($storiesDone)
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

  # The security review is a header field like Status:, so its state is computable. REQUIRED means nobody
  # has decided yet - not that the project is safe. /build Gate 2b refuses on it.
  # $designName is the FILE NAME; doc-stats never held a full path for it (that variable lives in
  # ratchet.ps1) - referencing it here silently skipped the whole check.
  $designPath = if ($designName) { Join-Path $docs $designName } else { "" }
  if ($designPath -and (Test-Path -LiteralPath $designPath)) {
    $designRaw = Get-Content -LiteralPath $designPath -Raw
    # LOCKED is the kit's central gate - /build Gate 2 STOPs on DRAFT because a run once made 106 blind
    # edits against an unfinished contract. But the gate only reads the WORD "LOCKED", and locking is a
    # one-word edit. A design locked with ZERO pinned contracts is the same unfinished state the gate
    # exists to refuse: /design step 5 (architect-agent) either never ran or wrote nothing, and every
    # dev-agent downstream then improvises the semantics. Computable, so it should not be prose.
    # Gated on the '## Contracts' SECTION existing: the template ships it, so every scaffolded project has
    # one and an EMPTY one means step 5 never landed. A design that deliberately carries no such section
    # (the kit's own is requirement-based, and a script-only project has no data formats to pin) is silent -
    # a finding that fires on good input is noise, and noise is how findings stop being read.
    if ($designStatus -eq 'LOCKED' -and $designRaw -match '(?m)^##\s*Contracts\b') {
      $pinned = @([regex]::Matches($designRaw, '(?m)^#{2,4}\s*(C[0-9]+[A-Za-z0-9-]*)\s*:'))
      if ($pinned.Count -eq 0) {
        $f.Add("[design] $designName is LOCKED and its '## Contracts' section is EMPTY - /design step 5 (architect-agent) never landed anything. /build will start dev-agents against a design with no pinned semantics, which is exactly what LOCKED is supposed to prevent.")
      }
    }
    $sr = [regex]::Match($designRaw, '(?im)^\s*Security review:\s*(.+?)\s*$')
    if (-not $sr.Success) {
      $f.Add("[design] no 'Security review:' header in $designName - scaffolded before this existed; add REQUIRED or NOT-REQUIRED (<why>)")
    } elseif ($sr.Groups[1].Value.Trim() -match '^NOT-REQUIRED') {
      # NOT-REQUIRED is the escape hatch from a gate that STOPS /build, and it costs one word to write.
      # The reason is the whole point: it is what tells a later reader this was a DECISION and not an
      # omission. An empty parenthetical, or none at all, is the model waving the gate through.
      $reason = [regex]::Match($sr.Groups[1].Value, '\(([^)]*)\)')
      if (-not $reason.Success -or $reason.Groups[1].Value.Trim().Length -lt 4) {
        $f.Add("[design] Security review: NOT-REQUIRED with no stated reason - write 'NOT-REQUIRED (<why>)', e.g. 'poc, no auth, never deployed'. Without it nobody can tell a decision from an omission.")
      }
    } elseif ($sr.Groups[1].Value.Trim() -match '^DONE') {
      # DONE is also one word. What makes it true is security-agent having written CITED decisions into
      # the doc; the header alone proves nothing, and flipping it is the cheapest way past Gate 2b.
      $secSection = [regex]::Match($designRaw, '(?ms)^##\s*Security decisions\b.*?(?=^##\s|\z)')
      $citedLines = if ($secSection.Success) { ([regex]::Matches($secSection.Value, '\[S\d+\]')).Count } else { 0 }
      if (-not $secSection.Success) {
        $f.Add("[design] Security review: DONE but there is no '## Security decisions' section - nothing was recorded, so the review cannot be reviewed")
      } elseif ($citedLines -eq 0) {
        $f.Add("[design] Security review: DONE but '## Security decisions' cites no sources - security-agent pins one dated [Snnn] per decision, so zero citations means it never ran or wrote nothing")
      }
    }
    if ($sr.Groups[1].Value.Trim() -match '^REQUIRED') {
      $f.Add("[design] Security review: REQUIRED and not done - /design spawns security-agent. /build will refuse to start.")
    }
  }

  if ($designStatus -eq "(no design doc)") { $f.Add("[design] no design doc in docs\ - run /scaffold or /design") }
  elseif ($designStatus -notin @("DRAFT","LOCKED")) { $f.Add("[design] $designName Status: is '$designStatus' - must be DRAFT or LOCKED") }

  # story headings carrying an id but no Status marker at all
  if (Test-Path $storiesFile) {
    foreach ($line in Get-Content $storiesFile -Encoding UTF8) {
      if ($line -match '^#{1,6}\s' -and $line -match '\b(S\d+[A-Za-z0-9._-]*)\b') {
        $sid = $Matches[1]
        if ($line -notmatch '<!--\s*Status:') { $f.Add("[scribe] story $sid has no <!-- Status: ... --> marker on its heading") }
        # IN-PROGRESS is accepted as a synonym for DOING: an older STORIES template shipped it, real projects
        # still carry it (cms3 did), and it is the natural English term - flagging it 'bad' is a false positive.
        elseif ($line -notmatch '<!--\s*Status:\s*(TODO|DOING|IN-PROGRESS|DONE|BLOCKED)\s*-->') {
          $bad = [regex]::Match($line, '<!--\s*Status:\s*([^-]*)-->').Groups[1].Value.Trim()
          $f.Add("[scribe] story $sid Status marker is '$bad' - use TODO / DOING / IN-PROGRESS / DONE / BLOCKED")
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

  # DUPLICATE IDS - document corruption, and trivially computable. A whole-file regeneration once left
  # STORIES.md with every story twice (28 headings, 14 distinct ids) and TASKS.md with a stray "RECOVERED"
  # block, and NOTHING noticed: the close was clean, so the ratchet baselined the corrupted counts as its
  # floor. The later repair then looked like a regression. An id appearing twice is never right.
  foreach ($pair in @(
    @{ File = $storiesFile; Pattern = '^#{1,6}\s.*?\b(S\d+[A-Za-z0-9._-]*)\b'; Owner = 'scribe';  What = 'story' },
    @{ File = $tasksFile;   Pattern = '^###\s*\[[ x]\]\s*([A-Za-z0-9._-]+)';   Owner = 'taskmap'; What = 'task'  }
  )) {
    if (-not (Test-Path $pair.File)) { continue }
    $seen = @{}
    foreach ($m in (Select-String -Path $pair.File -Pattern $pair.Pattern)) {
      $id = $m.Matches[0].Groups[1].Value
      if (-not $seen.ContainsKey($id)) { $seen[$id] = @() }
      $seen[$id] += $m.LineNumber
    }
    foreach ($id in ($seen.Keys | Sort-Object)) {
      if ($seen[$id].Count -gt 1) {
        $f.Add("[$($pair.Owner)] DUPLICATE $($pair.What) id $id - appears $($seen[$id].Count)x (lines $($seen[$id] -join ', ')). A regenerated file was appended, not replaced.")
      }
    }
  }

  # UNREADABLE LEDGER - a file full of work that no gate can parse. Measured on a CMS run: a 40 KB
  # TASKS.md whose "## Build order" named T1.1 -> T3.6 while NOT ONE of those ids appeared anywhere else
  # in the file; the actual work was anonymous "- [ ]" bullets under "### S1.1: Dashboard Overview"
  # headings. doc-stats reported "tasks: 0/0" - a NUMBER, as though the project simply had no tasks yet -
  # so nothing looked wrong, while close-unit could tick nothing and /build could select no unit.
  # "Zero tasks" and "a task ledger I cannot read" are completely different facts and must not print alike.
  foreach ($pair in @(
    @{ File = $tasksFile;   Found = $tasks.Count;      What = 'task';  Owner = 'taskmap'
       Shape = '### [ ] T1.1 - <title>   (Story S1.1)' },
    @{ File = $storiesFile; Found = $storyIds.Count;   What = 'story'; Owner = 'scribe'
       Shape = '### Story S1.1: <title>   <!-- Status: TODO -->' }
  )) {
    if (-not (Test-Path -LiteralPath $pair.File)) { continue }
    if ($pair.Found -gt 0) { continue }
    # Substantive content, but nothing parseable. A freshly scaffolded template is small and is NOT this.
    $bytes = (Get-Item -LiteralPath $pair.File).Length
    if ($bytes -lt 2000) { continue }
    $name = [System.IO.Path]::GetFileName($pair.File)
    $f.Add("[$($pair.Owner)] $name is $([math]::Round($bytes/1KB))KB but NOT ONE $($pair.What) id is parseable - every gate reads this file as EMPTY (close-unit cannot tick, /build cannot pick a unit). Required heading shape: '$($pair.Shape)'")
  }

  # Build-order ids that resolve to nothing. Same incident: 19 ids sequenced in "## Build order", zero of
  # them defined. /build walks that list to choose work, so a dangling id sends it looking for a task that
  # does not exist - and the run stalls without an error.
  if (Test-Path -LiteralPath $tasksFile) {
    $raw = Get-Content -LiteralPath $tasksFile -Raw
    $bo = [regex]::Match($raw, '(?ms)^##\s+Build order\b.*?(?=^##\s|\z)')
    if ($bo.Success) {
      $defined = @($tasks | ForEach-Object { $_.Id })
      $dangling = @()
      foreach ($m in [regex]::Matches($bo.Value, '\b([A-Z]\d+\.\d+[A-Za-z0-9._-]*)\b')) {
        $id = $m.Groups[1].Value
        if ($defined -notcontains $id -and $dangling -notcontains $id) { $dangling += $id }
      }
      if ($dangling.Count -gt 0) {
        $shown = ($dangling | Select-Object -First 8) -join ', '
        $f.Add("[taskmap] Build order sequences $($dangling.Count) id(s) that are DEFINED NOWHERE in the file ($shown) - /build walks this list to choose work and will find nothing")
      }
    }
  }

  # STORIES WITH NO TASKS - how a truncated taskmap goes unnoticed. Measured on the CMS run: 5 epics and
  # ~30 stories, and the task map covered E1-E3 then stopped, because the agent hung partway through E4.
  # Nothing said so. The totals looked plausible, and 13 stories had simply never been planned.
  # Only meaningful once SOME tasks parse - otherwise the unreadable-ledger finding above already owns it.
  if ($tasks.Count -gt 0 -and $storyIds.Count -gt 0) {
    $mapped = @($tasks | Where-Object { $_.Story } | ForEach-Object { $_.Story } | Select-Object -Unique)
    $unmapped = @($storyIds | Where-Object { $mapped -notcontains $_ })
    if ($unmapped.Count -gt 0) {
      $shown = ($unmapped | Select-Object -First 10) -join ', '
      $f.Add("[taskmap] $($unmapped.Count) of $($storyIds.Count) stories have NO tasks ($shown) - /taskmap stopped early or skipped them; /build will never reach that work")
    }
  }

  foreach ($m in $missing) { $f.Add("[grade] $m") }
  foreach ($o in $orphanTests) { $f.Add("[dev] test project not in the solution (dotnet test silently skips it): $o") }

  # --- HAND-TICKED STORIES: DONE without close-unit provenance --------------------------------------
  # Only close-unit may close a story (it stamps 'closed:close-unit' after the build passed, the tasks are
  # all [x], and a commit was made). A DONE marker WITHOUT that stamp was written by hand. To avoid
  # false-positiving a legitimate close from before the stamp existed, a stamp-less DONE is only flagged
  # when it does NOT also look genuinely closed - i.e. some of its tasks are still open, OR no commit
  # mentions it. cms3 marked 5/5 DONE with 21 tasks open and 4 commits: every one lights up here.
  if ($handTicked.Count -gt 0) {
    $coveringLog = ""
    if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
      try { Push-Location $proj; $coveringLog = (git log --oneline 2>$null | Out-String); Pop-Location } catch { }
    }
    foreach ($sid in $handTicked) {
      $mine = @($tasks | Where-Object { $_.Story -eq $sid })
      $allDone = ($mine.Count -gt 0) -and (@($mine | Where-Object { -not $_.Done }).Count -eq 0)
      $hasCommit = ($coveringLog -match [regex]::Escape($sid))
      if (-not ($allDone -and $hasCommit)) {
        $f.Add("[scribe] story $sid is marked DONE but has NO close-unit stamp - only close-unit may close a story (it verifies the build + tests). Either run close-unit on it, or revert the marker; a hand-ticked DONE is how a run claimed completion it had not done.")
      }
    }
  }

  # --- PROJECT-ROOT JUNK ---------------------------------------------------------------------------
  # A real run left the project root littered: ten ad-hoc SUMMARY/COMPLETE/IMPLEMENTATION files (which
  # CLAUDE.md explicitly forbids - "NEVER create ad-hoc status/summary/notes files"), four path-MANGLED
  # directories (a Windows path passed to bash, backslashes eaten, so `mkdir` made one literal dir named
  # DprojectsClaudeprojectscms3srcCMS), and a committed msbuild.binlog. This was the librarian's remit in
  # PROSE, and it did not hold - so it is computed now.
  $rootJunk = Get-ProjectJunk $proj
  if ($rootJunk.StrayFiles.Count -gt 0) {
    $f.Add("[hygiene] $($rootJunk.StrayFiles.Count) ad-hoc status/summary file(s) at the project root - CLAUDE.md forbids these; state belongs in TASKS/STORIES/STATUS (or _tmp/ for scratch). Run 'dad tidy -Fix'. $(($rootJunk.StrayFiles | Select-Object -First 8) -join ', ')")
  }
  if ($rootJunk.MangledDirs.Count -gt 0) {
    $f.Add("[hygiene] $($rootJunk.MangledDirs.Count) MANGLED path director(y/ies) at the root - a Windows path was passed to bash and the backslashes were eaten. Run 'dad tidy -Fix'; and use forward-slash or relative paths: $(($rootJunk.MangledDirs | Select-Object -First 4) -join ', ')")
  }
  if ($rootJunk.Binlogs.Count -gt 0) {
    $f.Add("[hygiene] a .binlog (MSBuild binary log) is in the tree - a build artifact, not source. 'dad tidy -Fix' removes it; *.binlog is now gitignored.")
  }
  if ($rootJunk.ExtraSolutions.Count -gt 1) {
    $f.Add("[hygiene] $($rootJunk.ExtraSolutions.Count) solution files at the root ($(($rootJunk.ExtraSolutions) -join ', ')) - keep ONE; a second .sln/.slnx splits the build")
  }

  # --- NAVIGABILITY (web projects, WARN) -----------------------------------------------------------
  # A run shipped 5 controllers whose shared layout linked to NONE of them - the site had no navigation.
  # ui-agent was never routed (that routing is prose), and even it does not check this. So: for a web app,
  # count the controllers/pages that exist and how many the shared layout actually links to. WARN, not
  # FAIL - navigation design varies and a hard rule would false-positive - but a layout that links to
  # nothing while N controllers exist is a real, computable smell.
  $viewsDir = Join-Path $proj "src"
  $layouts = @(Get-ChildItem $proj -Recurse -Filter "_Layout.cshtml" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' })
  $controllers = @(Get-ChildItem $proj -Recurse -Filter "*Controller.cs" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' } |
                   ForEach-Object { ($_.Name -replace 'Controller\.cs$','') } | Where-Object { $_ -ne 'Error' } | Select-Object -Unique)
  if ($layouts.Count -gt 0 -and $controllers.Count -ge 2) {
    $layoutText = ($layouts | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
    $linked = @($controllers | Where-Object {
      $layoutText -match ("(?i)asp-controller\s*=\s*[""']" + [regex]::Escape($_) + "[""']") -or
      $layoutText -match ("(?i)href\s*=\s*[""'][^""']*/" + [regex]::Escape($_) + "(/|[""'])")
    })
    if ($linked.Count -eq 0) {
      $f.Add("[ui] the shared layout links to NONE of the $($controllers.Count) controllers ($(($controllers | Select-Object -First 6) -join ', ')) - the app has no navigation. Add a nav to _Layout.cshtml (this is a WARN).")
    } elseif ($linked.Count -lt [math]::Ceiling($controllers.Count / 2)) {
      $f.Add("[ui] the shared layout links to only $($linked.Count) of $($controllers.Count) controllers - most of the app is unreachable from the nav (WARN).")
    }
  }

  # --- UX REVIEW (visible surfaces, WARN) ----------------------------------------------------------
  # A visible surface is meant to pass through ux-agent -> ui-agent (a build-time design review, applied and
  # recorded) before it closes. That routing is prose in /build, and prose routing is exactly what failed for
  # ui-agent - 0 spawns across 39 on the cms3 run. So if the project HAS visible surfaces but NOT ONE commit
  # records a review (close-unit stamps "UX-reviewed:" in the commit body when /build passes -UxReviewed),
  # say so once. WARN, not FAIL: a local box may have no ux-agent, and this must never deadlock a close.
  $surfaces = @(Get-ChildItem $proj -Recurse -Include *.cshtml,*.razor,*.jsx,*.tsx,*.vue,*.svelte -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\(bin|obj|node_modules)\\' -and $_.Name -notmatch '(?i)^_View(Imports|Start)\.cshtml$' })
  if ($surfaces.Count -ge 1 -and (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $uxSeen = $false
    try {
      Push-Location $proj
      $bodies = (git log --format=%B | Out-String)
      if ($bodies -match '(?im)^\s*UX-reviewed:') { $uxSeen = $true }
    } catch { } finally { Pop-Location; $ErrorActionPreference = $prevEap }
    if (-not $uxSeen) {
      $f.Add("[ux] $($surfaces.Count) visible surface(s) but NO commit records a UX review - ux-agent was never routed. Spawn it after ui-agent, apply its P1/P2 items, then close with -UxReviewed (WARN).")
    }
  }

  # --- PLAYTEST (experience projects, WARN) --------------------------------------------------------
  # An experience (the design doc is TEDD.md) is mostly FEEL, which no test can score - and for a game that
  # is most of the point. The kit routes feel to the human, but "hand me a checklist" is prose and gets
  # skipped. So if this is an experience with commits but NOT ONE records a playtest (close-unit stamps
  # "Playtested:" when /build passes -Playtested), say so once. WARN, not FAIL: a local box may have no one
  # at the controls, and this must never deadlock a close.
  if ($designName -eq 'TEDD.md' -and (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $ptSeen = $false
    try {
      Push-Location $proj
      $ptBodies = (git log --format=%B | Out-String)
      if ($ptBodies -match '(?im)^\s*Playtested:') { $ptSeen = $true }
    } catch { } finally { Pop-Location; $ErrorActionPreference = $prevEap }
    if (-not $ptSeen) {
      $f.Add("[playtest] this is an experience (docs\TEDD.md) but NO commit records a playtest - feel was never verified. Run playtest-agent after a build, play it, then close with -Playtested (WARN).")
    }
  }

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
  Write-Host "mangled markup, prose quality. Stray/ad-hoc files, mangled dirs and navigation are computed above now." -ForegroundColor DarkGray
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
