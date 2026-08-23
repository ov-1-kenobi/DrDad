# source-stats.ps1 - the citation-integrity gate for /research.
#
#   source-stats.ps1 [-ProjectDir .]     human-readable; exit 1 on any FAIL
#   source-stats.ps1 -Json               machine-readable
#
# Research has no compiler. What it DOES have is something a script can check: whether the claims in the
# design doc trace to sources that actually exist, and whether those sources were ever assessed. That is
# the same move as close-unit refusing to tick a task over a failing build - the model does not get to
# assert that a corpus is sound.
#
# It verifies TRACEABILITY, NOT TRUTH. A perfectly-cited wrong number is still wrong; no script fixes
# that. What this removes is the other failure - confident assertions with nothing behind them.
#
# Checks:
#   FAIL  a citation [Snnn] in a design doc with no row in SOURCES.md          (a claim resting on nothing)
#   FAIL  a ledger row whose docs/sources/ file is missing                     (the corpus lost it)
#   WARN  a file in docs/sources/ with no ledger row                           (arrived unrecorded)
#   WARN  a source that is never cited anywhere                               (hoarded, not read)
#   WARN  tier 'unknown' or missing                                           (never assessed)
#   WARN  fetched more than -StaleDays ago                                    (may have moved on)

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [int]$StaleDays = 365,
  [switch]$Json
)
$ErrorActionPreference = "Stop"
# GUARD: -ProjectDir must exist. Resolve-Path ERRORS on a missing path but the .cmd wrapper still exited 0,
# so a mistyped path looked like a project with no stories and no tasks. Fail loudly instead.
if (-not (Test-Path -LiteralPath $ProjectDir)) {
  Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red
  exit 2
}
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$docs = Join-Path $proj "docs"
$ledgerPath = Join-Path $docs "SOURCES.md"
$sourcesDir = Join-Path $docs "sources"

$fails = New-Object System.Collections.Generic.List[string]
$warns = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path $ledgerPath)) {
  Write-Host "no docs\SOURCES.md - this project has no research ledger (upgrade-project.cmd adds it)" -ForegroundColor Yellow
  exit 0                                    # not a research project; nothing to police
}

# --- the ledger ----------------------------------------------------------------------------------
# Table rows only: | id | tier | fetched | title | url | published |. The template's placeholder row is skipped.
# 'published' is LAST on purpose. Parsing here is POSITIONAL, so inserting it next to 'fetched' - where it
# reads better - would make every ledger written before 0.19.1 parse its TITLE as a date and its URL as the
# title, silently. A trailing column leaves old rows parsing exactly as they did, with published = "".
$rows = @{}
foreach ($line in (Get-Content $ledgerPath -Encoding UTF8)) {
  if ($line -notmatch '^\s*\|\s*(S\d+)\s*\|') { continue }
  $cells = ($line.Trim() -split '\|') | ForEach-Object { $_.Trim() }
  # cells[0] is empty (leading pipe): id, tier, fetched, title, url, published
  $id = $cells[1]
  if ($rows.ContainsKey($id)) { $fails.Add("duplicate ledger id $id"); continue }
  $rows[$id] = [pscustomobject]@{
    Id = $id
    Tier = if ($cells.Count -gt 2) { $cells[2] } else { "" }
    Fetched = if ($cells.Count -gt 3) { $cells[3] } else { "" }
    Title = if ($cells.Count -gt 4) { $cells[4] } else { "" }
    Url = if ($cells.Count -gt 5) { $cells[5] } else { "" }
    Published = if ($cells.Count -gt 6) { $cells[6] } else { "" }
  }
}
# The shipped template row is a placeholder, not a real source.
$placeholders = @($rows.Values | Where-Object { $_.Url -match '^<' -or $_.Fetched -match '^<' })
foreach ($p in $placeholders) { $rows.Remove($p.Id) | Out-Null }

# --- files on disk -------------------------------------------------------------------------------
$files = @{}
if (Test-Path $sourcesDir) {
  foreach ($f in (Get-ChildItem $sourcesDir -File -Recurse)) {
    $m = [regex]::Match($f.Name, '^(S\d+)')
    if ($m.Success) {
      if (-not $files.ContainsKey($m.Groups[1].Value)) { $files[$m.Groups[1].Value] = @() }
      $files[$m.Groups[1].Value] += $f.Name
    } else {
      $warns.Add("docs\sources\$($f.Name) is not named S<nnn>-* so it cannot be tied to the ledger")
    }
  }
}

# --- citations in the design docs -----------------------------------------------------------------
$cited = @{}
foreach ($d in @("DESIGN.md","TEDD.md","STORIES.md","TASKS.md")) {
  $dp = Join-Path $docs $d
  if (-not (Test-Path $dp)) { continue }
  foreach ($m in [regex]::Matches((Get-Content $dp -Raw), '\[(S\d+)\]')) {
    $id = $m.Groups[1].Value
    if (-not $cited.ContainsKey($id)) { $cited[$id] = @() }
    if ($cited[$id] -notcontains $d) { $cited[$id] += $d }
  }
}

# --- the checks -----------------------------------------------------------------------------------
foreach ($id in $cited.Keys) {
  if (-not $rows.ContainsKey($id)) {
    $fails.Add("[$id] is cited in $($cited[$id] -join ', ') but has NO row in SOURCES.md - the claim rests on nothing")
  }
}
foreach ($id in $rows.Keys) {
  if (-not $files.ContainsKey($id)) {
    $fails.Add("$id is in the ledger but docs\sources\$id-*.* is missing - the corpus lost it")
  }
  # When NOTHING is cited, that is ONE problem, not one per source. Measured on the CMS run: 11 sources
  # captured, a 17-contract design, and `cited in docs: 0` - the research was decorative. Printing eleven
  # identical "hoarded" lines buries that under noise; it is said once, loudly, below instead.
  if ($cited.Count -gt 0 -and -not $cited.ContainsKey($id)) {
    $warns.Add("$id is captured but never cited - hoarded, not used")
  }
  $tier = $rows[$id].Tier
  if (-not $tier -or $tier -match '^(unknown|<)') { $warns.Add("$id has no tier yet - YOU assess it; a script cannot") }
  elseif ($tier -notmatch '^(primary|secondary)$') { $warns.Add("$id tier '$tier' is not primary/secondary/unknown") }
  # -as, not [datetime]::TryParse: PS 5.1 cannot bind [ref]$null to the out parameter and throws
  # "Cannot find an overload for TryParse and the argument count 2".
  $d = $rows[$id].Fetched -as [datetime]
  if ($d) {
    $age = ([datetime]::Today - $d).Days
    if ($age -gt $StaleDays) { $warns.Add("$id was fetched $age days ago - re-check it still says what you cited") }
  } else { $warns.Add("$id has no parsable fetched date ('$($rows[$id].Fetched)')") }
}
# PUBLICATION age, which is a different question from fetch age and the one that actually matters for
# security guidance. Everything in a fresh run was FETCHED today, so -StaleDays 180 on 'fetched' cannot
# catch anything on the first pass - it only helps months later. A 2019 article fetched this morning is
# the failure mode: current-looking, and it may name an API that has since been deprecated or a library
# that has since had a CVE. Only cited sources are checked; uncited ones are already flagged as hoarded.
$noPubDate = @()
foreach ($id in $rows.Keys) {
  if (-not $cited.ContainsKey($id)) { continue }
  $pub = $rows[$id].Published
  if (-not $pub -or $pub -match '^<') { $noPubDate += $id; continue }
  if ($pub -match '^(n/?a|none|undated|unknown)$') { continue }   # honestly recorded as undated
  $pd = $pub -as [datetime]
  if ($pd) {
    $pAge = ([datetime]::Today - $pd).Days
    if ($pAge -gt $StaleDays) {
      $warns.Add("$id was PUBLISHED $pAge days ago ($pub) - older than the $StaleDays-day bar; confirm it has not been superseded")
    }
  } else { $warns.Add("$id has an unparsable published date ('$pub') - use YYYY-MM-DD, or 'undated' if the page has none") }
}
# Aggregated, not one WARN per source: a ledger written before this column existed would otherwise bury
# every real finding under a wall of identical lines.
if ($noPubDate.Count) {
  $shown = ($noPubDate | Sort-Object | Select-Object -First 6) -join ', '
  $warns.Add("$($noPubDate.Count) cited source(s) have no published date in the ledger ($shown) - add the last column so recency is a fact rather than an impression")
}
foreach ($id in $files.Keys) {
  if (-not $rows.ContainsKey($id)) { $warns.Add("docs\sources\$($files[$id][0]) has no ledger row - arrived unrecorded") }
}
# A corpus that nothing cites is DECORATIVE, and that is one finding rather than one per source. Measured
# on the CMS run: 11 sources captured, a 17-contract design doc, and ZERO [Snnn] citations anywhere. The
# research phase ran, produced files, and changed nothing downstream - and "cited in docs: 0" printed as a
# bare number, which reads like a project that has not started citing yet rather than one that never will.
if ($rows.Count -gt 0 -and $cited.Count -eq 0) {
  $warns.Add("$($rows.Count) source(s) captured and NOT ONE is cited - the design rests on nothing you gathered. Cite them as [Snnn] where they decided something, or drop them; a corpus nobody references is cost without benefit")
}

$result = [pscustomobject]@{
  sources = $rows.Count
  files = $files.Count
  cited = $cited.Count
  untiered = @($rows.Values | Where-Object { -not $_.Tier -or $_.Tier -match '^(unknown|<)' }).Count
  fails = $fails
  warns = $warns
}
if ($Json) { $result | ConvertTo-Json -Depth 5; exit $(if ($fails.Count) { 1 } else { 0 }) }

Write-Host "== source-stats: $proj ==" -ForegroundColor Cyan
Write-Host ("  sources in ledger : {0}" -f $rows.Count)
Write-Host ("  files on disk     : {0}" -f $files.Count)
Write-Host ("  cited in docs     : {0}" -f $cited.Count)
Write-Host ("  not yet tiered    : {0}" -f $result.untiered) -ForegroundColor $(if ($result.untiered) { "Yellow" } else { "Green" })
foreach ($w in $warns) { Write-Host "  WARN $w" -ForegroundColor Yellow }
foreach ($f in $fails) { Write-Host "  FAIL $f" -ForegroundColor Red }
Write-Host ""
if ($fails.Count) {
  Write-Host "$($fails.Count) FAIL(s) - the design doc cites sources that are not there. Fix before locking." -ForegroundColor Red
  exit 1
}
Write-Host "citations resolve." -ForegroundColor Green
exit 0
