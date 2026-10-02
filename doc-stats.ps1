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
  # the kit's own scripts (dad-*.ps1 / dad-*.cmd) ARE the kit, never stray - but ONLY when the scanned root
  # IS the kit root (the folder holding this script). The exemption is kit-root-only: a user project's own
  # dad-*.ps1/.cmd is still stray. Only script extensions are exempt, so dad-notes.md / dad-summary.txt stay junk.
  # Kit root = normalised paths match OR the root directly holds doc-stats.ps1 (a user project never does). The
  # second test survives junctions, subst drives and 8.3 short names, and covers another kit checkout or an
  # installed copy scanned by a doc-stats living elsewhere.
  $isKitRoot = ($root.TrimEnd('\','/') -ieq ([string]$PSScriptRoot).TrimEnd('\','/'))
  if (-not $isKitRoot) { $isKitRoot = (Test-Path -LiteralPath (Join-Path $root 'doc-stats.ps1') -PathType Leaf) }
  if ($isKitRoot) {
    $stray = @($stray | Where-Object { $_ -notmatch '(?i)^dad-.+\.(ps1|cmd)$' })
  }
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
. (Join-Path $PSScriptRoot "docs-dir.ps1")
$docs = Resolve-DocsDir $proj
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
  $securityWaiverFact = $null

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
    $contractHeadingRx = '(?m)^#{2,4}\s*(C[0-9]+[A-Za-z0-9-]*)\s*:'
    if ($designStatus -eq 'LOCKED' -and $designRaw -match '(?m)^##\s*Contracts\b') {
      $pinned = @([regex]::Matches($designRaw, $contractHeadingRx))
      if ($pinned.Count -eq 0) {
        $f.Add("[design] $designName is LOCKED and its '## Contracts' section is EMPTY - /design step 5 (architect-agent) never landed anything. /build will start dev-agents against a design with no pinned semantics, which is exactly what LOCKED is supposed to prevent.")
      }
    }
    # REFERENCED but never PINNED (S22, R24): a contract id the docs cite that resolves to no heading. A
    # design promised "a new contract (C5)" from a spike; the spike closed and C5 was never written into
    # '## Contracts' - nothing caught it for days. "Does the heading exist" is a grep, so it is computed here.
    # Same section gate as the empty-Contracts finding, but in DRAFT and LOCKED alike (a to-do list in DRAFT,
    # a contract gap in LOCKED). The reference regex is [regex] (case-SENSITIVE: -match/Select-String would
    # also hit a lowercase 'c1') and does not match C2PA / C# / C++. A sub-id resolves via its parent
    # (C4a -> C4, C3-b -> C3); likewise a capitalised
    # word after a hyphen ('C1-Based') parses as a sub-id and resolves via its parent. Grade cards are history and are NOT scanned. Fenced code blocks are NOT
    # skipped: a C<n> inside a code sample counts as a reference like any other line.
    if ($designRaw -match '(?m)^##\s*Contracts\b') {
      $pinnedIds = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
      foreach ($pm in [regex]::Matches($designRaw, $contractHeadingRx)) { [void]$pinnedIds.Add($pm.Groups[1].Value) }
      $unpinned = [ordered]@{}
      $refSources = @(@($designPath, $designName), @($storiesFile, "STORIES.md"), @($tasksFile, "TASKS.md"))
      foreach ($src in $refSources) {
        if (-not (Test-Path -LiteralPath $src[0])) { continue }
        $refLines = @(Get-Content -LiteralPath $src[0] -Encoding UTF8)
        $seenHere = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        for ($i = 0; $i -lt $refLines.Count; $i++) {
          foreach ($rm in [regex]::Matches([string]$refLines[$i], '\bC[0-9]+[a-z]?(?:-[A-Za-z0-9]+)?\b')) {
            $rid = $rm.Value
            $rparent = [regex]::Match($rid, '^C[0-9]+').Value
            if ($pinnedIds.Contains($rid) -or $pinnedIds.Contains($rparent)) { continue }
            if (-not $seenHere.Add($rid)) { continue }
            if (-not $unpinned.Contains($rid)) { $unpinned[$rid] = New-Object System.Collections.Generic.List[string] }
            $unpinned[$rid].Add("$($src[1]):$($i + 1)")
          }
        }
      }
      if ($unpinned.Count -gt 0) {
        $entries = @($unpinned.Keys | Select-Object -First 8 | ForEach-Object { "$_ ($($unpinned[$_] -join ', '))" })
        $more = if ($unpinned.Count -gt 8) { " ..." } else { "" }
        $f.Add("[design] $($unpinned.Count) contract id(s) are REFERENCED but never PINNED in ${designName}: " + ($entries -join ', ') + $more + " - pin them via /design (unlock -> architect-agent -> relock), or fix the reference.")
      }
    }
    # [domain] COARSE + informative (WARN): the design's '## Domain model' pins the shared nouns; API-SURFACE
    # reflects what got BUILT. A pinned entity that no built type matches is the "dev invented its own shape
    # per story" signal - surfaced WITH the full pinned list so the model has the target to build toward. NOT
    # forced: names only (no field-level match yet), and SILENT when there is no model, no surface, or no
    # drift - a finding that fires on good or early input is noise, and noise is how findings stop being read.
    $dmSection = [regex]::Match($designRaw, '(?ms)^##\s*Domain model\b.*?(?=^##\s|\z)')
    if ($dmSection.Success -and $dmSection.Value -notmatch '(?im)^\s*None\b') {
      $pinnedEntities = @([regex]::Matches($dmSection.Value, '(?m)^###\s+([A-Za-z_]\w*)') | ForEach-Object { $_.Groups[1].Value })
      $apiSurface = Join-Path $docs "API-SURFACE.md"
      if ($pinnedEntities.Count -gt 0 -and (Test-Path -LiteralPath $apiSurface)) {
        $builtTypes = @([regex]::Matches((Get-Content -LiteralPath $apiSurface -Raw), ('(?m)^' + [char]96 + '(?:class|struct|interface|enum|record) ([A-Za-z_]\w*)')) | ForEach-Object { $_.Groups[1].Value }) | Select-Object -Unique
        $unbuilt = @($pinnedEntities | Where-Object { $builtTypes -notcontains $_ })
        if ($unbuilt.Count -gt 0) {
          $f.Add("[domain] $($unbuilt.Count) of $($pinnedEntities.Count) entit(ies) pinned in '## Domain model' are NOT in the built surface: $($unbuilt -join ', ') - build them, or reconcile the name with DESIGN so dev builds against the pinned model, not a per-story invention. Pinned: $($pinnedEntities -join ', ') (coarse/WARN - names only).")
        }
      }
    }
    $hm = [regex]::Match($designRaw, '(?m)^##\s')
    $designHeader = if ($hm.Success) { $designRaw.Substring(0, $hm.Index) } else { $designRaw }
    # The review status is a HEADER field (before the first '## '); a body line with the same prefix is ordinary text.
    $sr = [regex]::Match($designHeader, '(?im)^\s*Security review:\s*(.+?)\s*$')
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
      # ADMISSIBILITY, not just existence: a reason can be present and still be false. A real run waived
      # the review as "small personal project..." (>=4 chars, passes the check above) on an app that
      # demonstrably implemented bcrypt password hashing and JWT auth - this doc's own rule ("anything that
      # handles auth, user data, uploads, payments or is internet-facing stays REQUIRED") did not hold in
      # practice. Grep the project's OWN content for the words that make REQUIRED apply and flag the
      # contradiction. WARN, not FAIL: the words could legitimately appear in an out-of-scope note, so this
      # is a nudge for a human to look, not a hard gate - same shape as the [research] keyword findings.
      $authKw = '(?i)\b(auth|login|password|token|session)\b'
      # S23: a human-dated 'Security waiver confirmed: <date> (human; auth-keyword hits: <N>)' header line
      # acknowledges the waiver. M is a MATCH COUNT over the design doc + STORIES.md, EXCLUDING the
      # confirmation line itself (its own 'auth-keyword' matches \bauth\b and would make M = N+1 forever).
      # M <= N -> no finding, a STATE FACTS line instead; M > N, malformed, or no line -> the WARN fires.
      # The confirmation is a HEADER line (before the first '## ' heading); a body line with the same
      # prefix is ordinary text: never honoured, never malformed, and counted in M.
      $wl = [regex]::Match($designHeader, '(?im)^\s*Security waiver confirmed:\s*(.*?)\s*$')
      $designForCount = if ($wl.Success) { $designRaw.Remove($wl.Index, $wl.Length) } else { $designRaw }
      $M = [regex]::Matches($designForCount, $authKw).Count
      if (Test-Path $storiesFile) { $M += [regex]::Matches((Get-Content $storiesFile -Raw), $authKw).Count }
      $today = (Get-Date).ToString('yyyy-MM-dd')
      $base = "[design] Security review: NOT-REQUIRED, but $designName (or STORIES.md) mentions auth/login/password/token/session - the waiver may not be admissible. This doc's own rule keeps anything handling auth REQUIRED; a human should confirm NOT-REQUIRED still holds here."
      $addLine = "Security waiver confirmed: $today (human; auth-keyword hits: $M)"
      $wValid = $false; $wDate = $null; $wN = 0
      if ($wl.Success) {
        $wm = [regex]::Match($wl.Groups[1].Value, '^(\d{4}-\d{2}-\d{2})\s*\(human;\s*auth-keyword hits:\s*(\d+)\)$')
        if ($wm.Success) {
          $dt = [datetime]::MinValue
          if ([datetime]::TryParseExact($wm.Groups[1].Value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$dt)) {
            $wValid = $true; $wDate = $wm.Groups[1].Value; $wN = [int]$wm.Groups[2].Value
          }
        }
      }
      if (-not $wl.Success) {
        if ($M -gt 0) { $f.Add("$base To acknowledge it, the human adds this header line via /design: $addLine") }
      } elseif (-not $wValid) {
        if ($M -gt 0) {
          $f.Add("$base The 'Security waiver confirmed:' line is malformed (expected: Security waiver confirmed: YYYY-MM-DD (human; auth-keyword hits: N)), so it is NOT honoured; fix it via /design, e.g.: $addLine")
        } else {
          # M = 0: no keyword mentions exist, so $base's 'mentions auth/login...' claim would be false
          $f.Add("[design] Security review: NOT-REQUIRED, but the 'Security waiver confirmed:' line is malformed (expected: Security waiver confirmed: YYYY-MM-DD (human; auth-keyword hits: N)), so it is NOT honoured; fix it via /design, e.g.: $addLine")
        }
      } elseif ($M -le $wN) {
        $securityWaiverFact = "security waiver: confirmed $wDate at $wN auth-keyword hits (now $M) - not re-raised"
      } else {
        $f.Add("$base - $($M - $wN) new auth-keyword mention(s) since the $wDate confirmation; re-confirm by updating the line to: $addLine")
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
        elseif ($line -notmatch '<!--\s*Status:\s*(TODO|DOING|IN-PROGRESS|DONE|BLOCKED)\b') {
          $bad = [regex]::Match($line, '<!--\s*Status:\s*(.*?)\s*-->').Groups[1].Value.Trim()
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

  # Default-scaffold ENTRY POINT = a bare front door. cms3 shipped Views/Home/Index.cshtml as the stock
  # "Welcome / Learn about ASP.NET Core" template - a real first visitor lands on nothing. The entry point
  # owns no [ui] task and no review touches it, so it silently stays scaffold. Stock markers are greppable.
  if ($surfaces.Count -ge 1) {
    $scaffoldRe = '(?i)(building Web apps with ASP\.NET Core|Edit\s+.{0,3}src[\\/]App|Get started by editing|Vite \+ React|create-next-app)'   # stock ASP.NET link text is split by an <a>, so match the contiguous half
    $scaffolded = @($surfaces |
      Where-Object { $_.Name -match '(?i)^(Index|Home|App)\.' -or $_.FullName -match '(?i)[\\/]Home[\\/]' } |
      Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match $scaffoldRe })
    if ($scaffolded.Count -gt 0) {
      $f.Add("[ui] the entry point is still the DEFAULT SCAFFOLD ($($scaffolded[0].Name)) - a first visitor lands on stock template content with no path into the app. Make the home page a real entry point (a [ui] task): links to the main functions + public content, usable by an ANONYMOUS visitor (WARN).")
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

  # --- STYLE conformance (surface projects with a FILLED STYLE.md palette, WARN) --------------------
  # docs\STYLE.md is the VISUAL contract; its ## Palette pins the colors. Read those hexes and flag project
  # CSS that uses colors OUTSIDE them - "complete UI" drifting from its target, computed rather than
  # eyeballed. An UNFILLED palette (placeholders, <2 real hexes) is ignored; vendor/min/lib CSS is excluded.
  $styleFile = Join-Path $docs "STYLE.md"
  if (Test-Path $styleFile) {
    $palette = @([regex]::Matches((Get-Content $styleFile -Raw), '#[0-9a-fA-F]{6}\b') | ForEach-Object { $_.Value.ToLower() } | Select-Object -Unique)
    if ($palette.Count -ge 2) {
      $cssFiles = @(Get-ChildItem $proj -Recurse -Filter *.css -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch '(?i)\\(bin|obj|node_modules|dist|lib|vendor)\\' -and $_.Name -notmatch '(?i)\.min\.css$' })
      $offenders = New-Object System.Collections.Generic.List[string]
      foreach ($cf in $cssFiles) {
        foreach ($m in [regex]::Matches((Get-Content $cf.FullName -Raw), '#[0-9a-fA-F]{6}\b')) {
          $h = $m.Value.ToLower()
          if ($palette -notcontains $h) { [void]$offenders.Add($h) }
        }
      }
      $off = @($offenders | Select-Object -Unique)
      if ($off.Count -gt 3) {
        $f.Add("[style] the project CSS uses $($off.Count) color(s) NOT in the STYLE.md palette (e.g. $(($off | Select-Object -First 5) -join ', ')) - the visual contract is drifting. Use the palette tokens, or update docs\STYLE.md if the palette changed (WARN).")
      }
    }
  }

  # [research] COARSE + informative (WARN): opinion-heavy / boilerplate tasks - OAuth, antiforgery, JWT,
  # SAML/SSO, payments, EF migrations, ASP.NET Identity - must carry a pinned APPROACH and `Refs:` (contract
  # / SOURCE / RECIPE ids) so dev implements a DECIDED how instead of inventing the mechanics. A real run
  # spiralled 26h reinventing antiforgery-in-integration-tests that NO task pinned (the C3 contract covered
  # production code, not the test harness). Fires on a [research]-tagged OR keyword-matched task that has no
  # `- **Refs:**` line. Names only, not forced - phase 2 will ground the Refs against the real versions.
  if (Test-Path $tasksFile) {
    # Leading \b only (prefix match): a trailing \b would miss "antiforgeR-Y", "migratioN-S", "identitiE-S".
    $opinionKw = '(?i)\b(oauth|antiforger|anti-forger|csrf|jwt|saml|sso|payment|stripe|webhook|migrat|identit)'
    $ungrounded = New-Object System.Collections.Generic.List[string]
    $curTask = ""; $curOpinion = $false; $curRefs = $false
    foreach ($ln in (Get-Content $tasksFile -Encoding UTF8)) {
      if ($ln -match '^###\s*\[( |x)\]\s*([A-Za-z0-9._-]+)') {
        if ($curTask -and $curOpinion -and -not $curRefs) { [void]$ungrounded.Add($curTask) }
        $curTask = $Matches[2]
        $curOpinion = (($ln -match '\[research\]') -or ($ln -match $opinionKw))
        $curRefs = $false
      } elseif ($curTask) {
        if ($ln -match '^\s*[-*]\s*\*\*Refs:\*\*\s*\S') { $curRefs = $true }
        elseif ($ln -match $opinionKw) { $curOpinion = $true }
      }
    }
    if ($curTask -and $curOpinion -and -not $curRefs) { [void]$ungrounded.Add($curTask) }
    if ($ungrounded.Count -gt 0) {
      $f.Add("[research] $($ungrounded.Count) opinion-heavy task(s) have NO pinned Refs (approach ungrounded): $(($ungrounded | Select-Object -First 8) -join ', ') - dev will INVENT the how (a run spiralled 26h reinventing antiforgery-in-tests). Add '- **Refs:** C<n>, S<n>, R<n>' pointing at the contract / SOURCE / RECIPE that decides it - including the TEST approach - or research it before /build (WARN).")
    }
  }

  # Done units with no commit mentioning them: a missed checkpoint one at a time, and IN BULK the fabrication
  # signature. A real run ticked 36 tasks DONE while HEAD never moved - it -Ack'd the stop guard and never
  # ran close-unit. 36 separate [dev] lines is noise that reads like a to-do list; one loud [integrity] line
  # (with the frozen HEAD and the -Ack override count) is the signal that the green state is manufactured.
  # $uncommittedTaskCount feeds the STATE FACTS line below: how many of the [x] TASKS no commit mentions. A
  # real audit read "tasks 44/44 [x]" off the FACTS line as "44 verified" while [integrity] said 32 were
  # fake - so the FACTS line now qualifies the count instead of presenting the fabricated total as a fact.
  $uncommittedTaskCount = $null
  if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $uncommittedDone = New-Object System.Collections.Generic.List[string]
    $headSha = ""
    try {
      Push-Location $proj
      $log = (git log --oneline | Out-String)
      $headSha = (git rev-parse --short HEAD 2>$null | Out-String).Trim()
      foreach ($u in (@($storiesDone) + @($tasksDone | ForEach-Object { $_.Id }) | Select-Object -Unique)) {
        if ($log -notmatch [regex]::Escape($u)) { [void]$uncommittedDone.Add($u) }
      }
      $uncommittedTaskCount = @($tasksDone | Where-Object { $log -notmatch [regex]::Escape($_.Id) }).Count
    } catch { } finally { Pop-Location; $ErrorActionPreference = $prevEap }
    if ($uncommittedDone.Count -ge 5) {
      $ackNote = ""
      $ackLog = Join-Path $proj ".claude\.dad-ack-log"
      if (Test-Path $ackLog) { $ackNote = " The stop guard was overridden (-Ack) $(@(Get-Content $ackLog).Count) time(s)." }
      $f.Add("[integrity] $($uncommittedDone.Count) unit(s) are ticked DONE but NO commit mentions them (HEAD $headSha) - the run manufactured green state: hand-ticked, never closed via close-unit.$ackNote Bank each with 'dad close-unit -Id <id>', or revert the ticks. e.g. $(($uncommittedDone | Select-Object -First 8) -join ', ')")
    } else {
      foreach ($u in $uncommittedDone) { $f.Add("[dev] $u is done but no commit mentions it - missed checkpoint") }
    }
  }

  # --- HAND-COMMITTED AROUND close-unit: a DOC-ONLY commit ticked the box, in a shape close-unit never
  # writes ---------------------------------------------------------------------------------------------
  # The block above only fires when NO commit mentions the id at all. A real run's [x] tasks were EVERY
  # one covered by SOME commit - just not one close-unit made: it hand-ticked the checkbox, then committed
  # docs\TASKS.md ALONE with a message like "Mark T1.1 complete", separate from the real implementation
  # commit - so the "no commit mentions it" check stayed silent. close-unit.ps1 never produces a
  # docs-only commit standalone (it ticks, reindexes and commits in the SAME invocation as the verified
  # build, close-unit.ps1's commit step) and its message is always exactly "$Id" or "$Id`: $Title" - never
  # "Mark <id> complete". A commit that touches ONLY docs\TASKS.md/docs\STORIES.md, mentions a done id, and
  # does NOT match that shape is a CANDIDATE - but mentioning the id is not enough by itself: this kit's own
  # history false-positived on it TWICE. (1) scribe-agent/taskmap-agent SHARDING new work ("TASKS: shard S5
  # into T5.1...") is also a doc-only commit naming the id, but it ADDS T5.1 as `[ ]`, it never ticks it - so
  # the candidate's own DIFF must show the id's line being ADDED already ticked (`+### [x] <id>` or
  # `+...<id>...Status: DONE`); a sharding commit's added line is `[ ]`/no DONE marker and is now excluded.
  # (2) STORY ids specifically: close-unit's OWN roll-up commit (e.g. stamping `closed:close-unit` onto an
  # already-DONE story from before the stamp existed) is shaped around the TASK it closed ("T1.2: ..."), never
  # the story id - so the shape-exclusion above never matches for the story, and the diff legitimately DOES
  # show its Status:DONE line changing (`git show 9afc835` on this repo - real, not a hand-tick). Stories
  # already have a purpose-built, more reliable detector (the `closed:close-unit` STAMP check just above,
  # which reads STORIES.md directly rather than inferring from commit shape) - so this check covers TASKS
  # ONLY, where no other detector exists. Candidate ids also need `\b` boundaries: a plain substring match let
  # "T1" match inside "T10"/"T11" and "S1" match inside "...ps1" (a real file extension).
  if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $handCommitted = New-Object System.Collections.Generic.List[string]
    try {
      Push-Location $proj
      $raw = (git log --format="%x01%H%x02%s" --name-only | Out-String)
      $SOH = [char]1; $STX = [char]2
      $doneTaskIds = @($tasksDone | ForEach-Object { $_.Id } | Select-Object -Unique)
      foreach ($blk in ($raw.Split($SOH) | Where-Object { $_ })) {
        $lines = $blk -split "`r?`n"
        $head = $lines[0].Split($STX)
        if ($head.Count -lt 2) { continue }
        $fullSha = $head[0]; $sha = $fullSha.Substring(0, [Math]::Min(7, $fullSha.Length)); $subject = $head[1]
        $changed = @($lines | Select-Object -Skip 1 | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim().Replace('\','/') })
        if ($changed.Count -eq 0) { continue }
        $docOnly = @($changed | Where-Object { $_ -notin @('docs/TASKS.md','docs/STORIES.md') }).Count -eq 0
        if (-not $docOnly) { continue }
        $candidateIds = @($doneTaskIds | Where-Object {
          $subject -match ('\b' + [regex]::Escape($_) + '\b') -and
          $subject -notmatch ('^' + [regex]::Escape($_) + '(:\s.+)?$')
        })
        if ($candidateIds.Count -eq 0) { continue }
        $diff = (git show --unified=0 --format= $fullSha -- docs/TASKS.md docs/STORIES.md 2>$null | Out-String)
        foreach ($id in $candidateIds) {
          $tickPattern = '(?m)^\+.*\b' + [regex]::Escape($id) + '\b.*(\[x\]|Status:\s*DONE\b)'
          if ($diff -match $tickPattern) { [void]$handCommitted.Add("$id (commit $sha`: '$subject')") }
        }
      }
      Pop-Location
    } catch { try { Pop-Location } catch {} } finally { $ErrorActionPreference = $prevEap }
    if ($handCommitted.Count -gt 0) {
      $shown = ($handCommitted | Select-Object -Unique | Select-Object -First 6) -join '; '
      $f.Add("[integrity] $($handCommitted.Count) unit(s) were ticked by a DOC-ONLY commit close-unit never made (message shape does not match close-unit's own '<id>' / '<id>: <title>'): $shown - close-unit ticks and commits atomically and never writes a standalone docs-only commit, so this is the hand-tick signature (a model committed around a blocked or degraded close-unit). Re-close properly via close-unit, or revert the tick.")
    }
  }

  # --- [ratchet] planning-mass WARN (R36b/C1, Option B - C1a formula, C1b message/tag): fires when the
  # doc's planning mass (stories + tasks scoped) has grown far ahead of its proven/DONE footprint. WARN
  # only - never blocks /build, close-unit or any LOCK gate (C1d), same class as [research]/[style]/[ux].
  # Uses ONLY the counters already computed above (no new data source) - $storyIds.Count/$storiesDone.Count/
  # $tasks.Count/$tasksDone.Count, per C1a (doc-stats.ps1:126,152,192-198).
  $ratchetMassFloor = 15
  $ratchetDoneRatioFloor = 0.15
  $ratchetMass = $storyIds.Count + $tasks.Count
  if ($ratchetMass -gt 0) {
    $ratchetDoneMass = $storiesDone.Count + $tasksDone.Count
    $ratchetDoneRatio = $ratchetDoneMass / $ratchetMass
    if ($ratchetMass -ge $ratchetMassFloor -and $ratchetDoneRatio -lt $ratchetDoneRatioFloor) {
      $ratchetDoneRatioPct = [Math]::Round($ratchetDoneRatio * 100, 1)
      $f.Add("[ratchet] planning mass ($($storyIds.Count) stories + $($tasks.Count) tasks = $ratchetMass) is far ahead of proven footprint ($($storiesDone.Count) stories + $($tasksDone.Count) tasks = $ratchetDoneMass done, $ratchetDoneRatioPct% of mass) - the walking-skeleton ratchet (R36b/C1) fires once mass >= 15 and the done ratio stays under 15%. Build out what is already scoped (S1 must close first, per R30) before sharding more, or explicitly re-confirm scope growth via /design or /stories now that the cost is visible.")
    }
  }

  Write-Host "== STATE FACTS (computed - do NOT contradict these) ==" -ForegroundColor Cyan
  # [x] counts CHECKBOXES, which a hand-tick fakes. When no commit backs them, say so ON THE FACTS LINE so
  # "44/44 [x]" cannot be read as "44 verified" - a real audit wrote exactly that over 32 fabricated ticks.
  $taskFacts = "$($tasksDone.Count)/$($tasks.Count) [x]"
  if ($null -ne $uncommittedTaskCount -and $uncommittedTaskCount -gt 0) {
    $verifiedTasks = $tasksDone.Count - $uncommittedTaskCount
    $taskFacts = "$($tasksDone.Count)/$($tasks.Count) [x] ($verifiedTasks committed, $uncommittedTaskCount UNVERIFIED)"
  }
  $nextId = if ($next) { $next.Id } else { "none" }
  Write-Host "  design ${designName}: Status $designStatus | stories $($storiesDone.Count)/$($storyIds.Count) DONE | tasks $taskFacts | next $nextId"
  if ($securityWaiverFact) { Write-Host "  $securityWaiverFact" }
  if ($null -ne $uncommittedTaskCount -and $uncommittedTaskCount -gt 0) {
    Write-Host "  ^ $uncommittedTaskCount of the [x] tasks are hand-ticked with NO commit - a green [x] is not 'verified'. See [integrity]." -ForegroundColor Red
  }
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
  # LF, not CRLF: .gitattributes mandates LF for *.md (only *.cmd/*.bat keep CRLF), and this write used
  # to hard-code "`r`n" for both the join and the terminator. Every `-UpdateStatus` - which /audit
  # MANDATES - therefore rewrote docs\STATUS.md as CRLF and broke the kit's own line-ending gate
  # ("STATUS.md is CRLF but should be LF"). Still WriteAllText + UTF8Encoding($false) (no BOM).
  [System.IO.File]::WriteAllText($statusPath, (($out -join "`n").TrimEnd() + "`n"), (New-Object System.Text.UTF8Encoding($false)))
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
