# ratchet.ps1 - refuse to let the project's verification surface SHRINK.
#
#   ratchet.ps1 [-ProjectDir .]      compare against the baseline; exit 1 if anything dropped
#   ratchet.ps1 -Update              record the current counts as the new baseline
#   ratchet.ps1 -Json                machine-readable
#
# THE TRAP THIS CLOSES. Every gate in this kit asked "is X OK right now?" and none asked "did X shrink?"
# So the cheapest way to satisfy a gate was to delete the thing it measured. That is not hypothetical: a
# run set out to fix the IIIF tests, rewrote ImageApiControllerTests.cs to introduce a test fixture, and
# 15 of 16 tests did not survive the rewrite - including the C9 worked example, the level-2 conformance
# check and the byte-identical guarantee. The report then read "Iiif.Tests 8 passed, 3 failed" and every
# gate went green: the build passed, tests RAN (11 > 0), tests PASSED (8), the tree was clean.
#
# The model was not cheating. It was asked to make the tests pass, deleting a red test does that, nothing
# forbade it, and the scoreboard applauded. A model with no rule against it, an objective that rewards it
# and a gate that scores it will take that path every time - so the fix is a gate, not a paragraph.
#
# Five places the same trap was open (all covered here):
#   tests            delete a red test                -> suite goes green
#   stories/tasks    delete an undone unit            -> 6/14 becomes 6/9, "progress"
#   contracts/reqs   delete the contract              -> nothing left to violate
#   sources          delete the ledger row/citation   -> source-stats stops failing
#   build command    delete CLAUDE.md's Build: line   -> close-unit "closes WITHOUT verification"
#
# A drop is not always wrong - deleting a genuinely obsolete story is fine. It always needs a HUMAN, which
# is what -AcceptShrink (on close-unit) is for. What it must never be is silent.

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [switch]$Update,
  [switch]$Json
)
$ErrorActionPreference = "Stop"
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$docs = Join-Path $proj "docs"
$baselineFile = Join-Path $proj ".claude\.dad-ratchet.json"

function Count-Pattern([string]$file, [string]$pattern) {
  # A project with no design doc yields an empty path here, and Test-Path "" THROWS. A counter that
  # crashes on a legitimately empty project would block every close in it.
  if ([string]::IsNullOrWhiteSpace($file) -or -not (Test-Path -LiteralPath $file)) { return 0 }
  return @(Select-String -Path $file -Pattern $pattern).Count
}

# --- tests: language-agnostic, by the markers each ecosystem uses ---------------------------------
$testMarkers = '\[Fact\]|\[Theory\]|\[Test\]|\[TestMethod\]|^\s*def\s+test_|\bit\s*\(|\btest\s*\(|^func\s+Test|#\[test\]'
$testCount = 0
$srcFiles = @()
try {
  $srcFiles = Get-ChildItem $proj -Recurse -File -Include *.cs,*.fs,*.vb,*.py,*.ts,*.tsx,*.js,*.jsx,*.go,*.rs,*.java,*.kt -ErrorAction SilentlyContinue |
    Where-Object { $p = $_.FullName.Split([char]92); ($p -notcontains 'bin') -and ($p -notcontains 'obj') -and
                   ($p -notcontains 'node_modules') -and ($p -notcontains '.git') -and ($p -notcontains '.claude') }
} catch { }
foreach ($f in $srcFiles) {
  $testCount += @(Select-String -Path $f.FullName -Pattern $testMarkers).Count
}

# --- the design doc: requirements and contracts ---------------------------------------------------
$designFile = ""
foreach ($n in @("DESIGN.md","TEDD.md")) { $c = Join-Path $docs $n; if (Test-Path $c) { $designFile = $c; break } }
# Both requirement styles in the wild: '- [x] R1: ...' (this kit) and plain '- R1: ...' (a real project).
# Counting only the checkbox form reported 0 requirements for a doc that has 17 - and a baseline of 0 can
# never detect a drop, which would have left the largest surface in the design doc completely unguarded.
$requirements = Count-Pattern $designFile '^\s*[-*]\s*(\[[ x]\]\s*)?R\d+\s*:'
$contracts    = Count-Pattern $designFile '^#{2,4}\s*C\d+[A-Za-z0-9-]*\s*:'

# --- the backlog: TOTALS, not done-counts. Deleting an undone unit is what improves the ratio. -----
$stories = Count-Pattern (Join-Path $docs "STORIES.md") '^#{1,6}\s.*\bS\d+'
$tasks   = Count-Pattern (Join-Path $docs "TASKS.md")   '^###\s*\[[ x]\]'
$sources = Count-Pattern (Join-Path $docs "SOURCES.md") '^\s*\|\s*S\d+\s*\|'

# --- grade cards: total bytes, so a real assessment cannot be replaced by a passing stub ----------
$gradeBytes = 0
$gradesDir = Join-Path $proj "grades"
if (Test-Path $gradesDir) {
  $gradeBytes = (Get-ChildItem $gradesDir -Filter *_GRADE.md -File | Measure-Object -Property Length -Sum).Sum
  if (-not $gradeBytes) { $gradeBytes = 0 }
}

# --- the verification commands themselves. Deleting the Build: line disables close-unit's check. ---
$claudeMd = Join-Path $proj "CLAUDE.md"
$hasBuild = 0; $hasTest = 0
if (Test-Path $claudeMd) {
  $cm = Get-Content $claudeMd -Raw
  if ($cm -match '(?im)^\s*-\s*Build:\s*`[^`]+`') { $hasBuild = 1 }
  if ($cm -match '(?im)^\s*-\s*Test:\s*`[^`]+`')  { $hasTest = 1 }
}

$current = [ordered]@{
  tests = $testCount; requirements = $requirements; contracts = $contracts
  stories = $stories; tasks = $tasks; sources = $sources
  gradeBytes = [int]$gradeBytes; hasBuildCommand = $hasBuild; hasTestCommand = $hasTest
}

# Record WHICH COMMIT the baseline was taken at. Without it, "git has it" is true but useless - you would
# have to go find the right commit yourself, which is the difference between a recoverable incident and a
# lost afternoon. With it, the restore command below can be exact.
$headSha = ""
if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { Push-Location $proj; $headSha = (git rev-parse HEAD 2>$null | Out-String).Trim() }
  catch { } finally { Pop-Location; $ErrorActionPreference = $prevEap }
}
$current["commit"] = $headSha

# WHICH FILE lost the markers? The count alone ("tests 15 -> 1") is not actionable - recovery needs a path.
# Compare each file's marker count now against the same file at the baseline commit.
function Find-ShrunkFiles([string]$sha) {
  $hits = @()
  if (-not $sha -or -not (Get-Command git -ErrorAction SilentlyContinue)) { return $hits }
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try {
    Push-Location $proj
    foreach ($rel in @(git diff --name-only $sha -- . 2>$null)) {
      if (-not $rel) { continue }
      $ext = [System.IO.Path]::GetExtension($rel)
      if (@(".cs",".fs",".vb",".py",".ts",".tsx",".js",".jsx",".go",".rs",".java",".kt") -notcontains $ext) { continue }
      $old = (git show "$sha`:$rel" 2>$null | Out-String)
      if (-not $old) { continue }
      $oldN = @([regex]::Matches($old, $testMarkers)).Count
      $full = Join-Path $proj $rel
      $newN = 0
      if (Test-Path -LiteralPath $full) { $newN = @([regex]::Matches((Get-Content $full -Raw), $testMarkers)).Count }
      if ($newN -lt $oldN) { $hits += [pscustomobject]@{ Path = $rel; Was = $oldN; Now = $newN } }
    }
  } catch { } finally { Pop-Location; $ErrorActionPreference = $prevEap }
  return $hits
}

if ($Update) {
  $dir = Split-Path $baselineFile -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($baselineFile, (($current | ConvertTo-Json)), (New-Object System.Text.UTF8Encoding($false)))
  if (-not $Json) { Write-Host "ratchet baseline updated: $(($current.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')" -ForegroundColor Green }
  exit 0
}

if (-not (Test-Path $baselineFile)) {
  if ($Json) { [pscustomobject]@{ baseline = $null; current = $current; drops = @() } | ConvertTo-Json -Depth 5; exit 0 }
  Write-Host "no ratchet baseline yet - run with -Update to record one (close-unit does this on a clean close)." -ForegroundColor Yellow
  Write-Host "current: $(($current.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')"
  exit 0
}

$base = Get-Content $baselineFile -Raw | ConvertFrom-Json
$labels = @{
  tests = "TESTS - a red test deleted is not a test fixed"
  requirements = "requirements in the design doc"
  contracts = "contracts - nothing left to violate is not conformance"
  stories = "stories in the backlog (total, not done)"
  tasks = "tasks in the map (total, not done)"
  sources = "sources in the research ledger"
  gradeBytes = "total grade-card bytes - a real assessment replaced by a passing stub"
  hasBuildCommand = "CLAUDE.md's Build: command - without it close-unit closes WITHOUT verification"
  hasTestCommand = "CLAUDE.md's Test: command"
}
$drops = @()
foreach ($k in $current.Keys) {
  if ($k -eq "commit") { continue }        # provenance, not a count
  $was = if ($base.PSObject.Properties.Name -contains $k) { [int]$base.$k } else { $null }
  if ($null -eq $was) { continue }
  $now = [int]$current[$k]
  if ($now -lt $was) { $drops += [pscustomobject]@{ what = $k; was = $was; now = $now; why = $labels[$k] } }
}

if ($Json) { [pscustomobject]@{ baseline = $base; current = $current; drops = $drops } | ConvertTo-Json -Depth 5; exit $(if ($drops.Count) { 1 } else { 0 }) }

Write-Host "== ratchet: $proj ==" -ForegroundColor Cyan
foreach ($k in $current.Keys) {
  if ($k -eq "commit") { continue }
  $was = if ($base.PSObject.Properties.Name -contains $k) { [int]$base.$k } else { 0 }
  $now = [int]$current[$k]
  $mark = if ($now -lt $was) { "DROP" } elseif ($now -gt $was) { "  +" } else { "   =" }
  $col = if ($now -lt $was) { "Red" } elseif ($now -gt $was) { "Green" } else { "DarkGray" }
  Write-Host ("  {0,-4} {1,-16} {2} -> {3}" -f $mark, $k, $was, $now) -ForegroundColor $col
}
Write-Host ""
if ($drops.Count -eq 0) { Write-Host "nothing shrank." -ForegroundColor Green; exit 0 }
Write-Host "$($drops.Count) THING(S) SHRANK:" -ForegroundColor Red
foreach ($d in $drops) { Write-Host "  $($d.what): $($d.was) -> $($d.now)  - $($d.why)" -ForegroundColor Red }
Write-Host ""

# RECOVERY, spelled out. "Restore it (git has it)" is true and useless - the same unresolvable-advice
# defect the stop guard shipped with in 0.12.0. Name the file, the commit, and the command.
$baseSha = ""
if ($base.PSObject.Properties.Name -contains 'commit') { $baseSha = [string]$base.commit }
# @(...) is load-bearing: PowerShell unrolls a single-element return, so one shrunk file comes back as a
# bare object whose .Count is $null - and `$null -gt 0` is false, so the recovery block silently vanished
# in exactly the one-file case that matters most.
$shrunk = @(Find-ShrunkFiles $baseSha)
if ($shrunk.Count -gt 0) {
  Write-Host "WHAT WAS REMOVED, and how to put it back:" -ForegroundColor Cyan
  foreach ($s in $shrunk) {
    Write-Host "  $($s.Path)  ($($s.Was) -> $($s.Now) test(s))" -ForegroundColor Cyan
    Write-Host "      git show $baseSha`:$($s.Path) > `"$($s.Path)`"" -ForegroundColor Green
  }
  Write-Host "  Then reconcile by hand - the rest of the change may be GOOD and worth keeping." -ForegroundColor Cyan
  Write-Host ""
  Write-Host "  Better: let recover-lost work out WHICH named units vanished - and which merely MOVED:" -ForegroundColor Cyan
  Write-Host "    recover-lost.cmd                 report" -ForegroundColor Green
  Write-Host "    recover-lost.cmd -Restore        put the vanished ones back, KEEPING what arrived" -ForegroundColor Green
  Write-Host "  A whole-file restore would also discard everything the change ADDED." -ForegroundColor Cyan
} elseif ($baseSha) {
  Write-Host "Baseline commit: $baseSha" -ForegroundColor Cyan
  Write-Host "  What changed since:  git diff $baseSha" -ForegroundColor Cyan
  Write-Host "  Recover a file:      git show $baseSha`:<path> > <path>" -ForegroundColor Cyan
} else {
  Write-Host "No baseline commit recorded (project had no git when the baseline was taken)." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "A drop is not always wrong - an obsolete story deleted on purpose is fine. It is never something" -ForegroundColor Yellow
Write-Host "a run gets to do SILENTLY. Restore it, or acknowledge the removal deliberately:" -ForegroundColor Yellow
Write-Host "  close-unit.ps1 ... -AcceptShrink      (records the smaller number as the new baseline)" -ForegroundColor Yellow
exit 1
