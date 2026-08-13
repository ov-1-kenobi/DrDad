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

param(
  [string]$ProjectDir = ".",
  [int]$StaleDays = 365,
  [switch]$Json
)
$ErrorActionPreference = "Stop"
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
# Table rows only: | id | tier | fetched | title | url |. The template's own placeholder row is skipped.
$rows = @{}
foreach ($line in (Get-Content $ledgerPath -Encoding UTF8)) {
  if ($line -notmatch '^\s*\|\s*(S\d+)\s*\|') { continue }
  $cells = ($line.Trim() -split '\|') | ForEach-Object { $_.Trim() }
  # cells[0] is empty (leading pipe): id, tier, fetched, title, url
  $id = $cells[1]
  if ($rows.ContainsKey($id)) { $fails.Add("duplicate ledger id $id"); continue }
  $rows[$id] = [pscustomobject]@{
    Id = $id
    Tier = if ($cells.Count -gt 2) { $cells[2] } else { "" }
    Fetched = if ($cells.Count -gt 3) { $cells[3] } else { "" }
    Title = if ($cells.Count -gt 4) { $cells[4] } else { "" }
    Url = if ($cells.Count -gt 5) { $cells[5] } else { "" }
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
  if (-not $cited.ContainsKey($id)) { $warns.Add("$id is captured but never cited - hoarded, not used") }
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
foreach ($id in $files.Keys) {
  if (-not $rows.ContainsKey($id)) { $warns.Add("docs\sources\$($files[$id][0]) has no ledger row - arrived unrecorded") }
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
