# data-stats.ps1 - the DATASET integrity gate, the counterpart to source-stats for research projects.
#
# Why: /research captures SOURCES (documents, with provenance). A research SITE also needs DATA - rows you
# chart. Nothing in the kit knew what a dataset was, so a column could vanish, a unit could silently change
# from kg to lb, a scrape could return 3 rows instead of 300, and every gate stayed green because the code
# still compiled and the tests still passed. A chart drawn from that is confidently wrong.
#
# Same shape as SOURCES.md/source-stats, which is a proven pattern here: you DECLARE the dataset in
# docs/DATASETS.md, and this script checks the actual file against the declaration.
#
#   dad data-stats                     human-readable; exit 1 on any FAIL
#   dad data-stats -Json               machine-readable
#   dad data-stats -Dataset D001       just that one
#
# WHAT THIS DOES NOT DO: it does not verify that your numbers are TRUE. Neither does source-stats - it
# checks traceability, not truth. A harvest of 40 kg recorded as 400 passes every check here if 400 is in
# range. What this removes is the other failure: the file quietly not being what the design says it is.
#
# docs/DATASETS.md format (one section per dataset):
#
#   ## D001: harvest-log
#   - **File:** `data/harvest-log.csv`
#   - **Key:** date+bed
#   - **Min rows:** 10
#   - **Columns:**
#     | column | type | required | range |
#     |---|---|---|---|
#     | date | date | yes | 2020-01-01..2035-12-31 |
#     | bed  | text | yes | |
#     | crop | text | yes | |
#     | kg   | number | yes | 0..500 |
#
# types: text | number | integer | date | bool.
# range: 'lo..hi' for numbers/dates, or 'a;b;c' for an allowed-value SET. Semicolons, not pipes - the
#        range lives in a markdown table cell and a pipe would end the cell.
# required: yes/no.  Key: one or more columns joined with '+', for duplicate detection.

# CmdletBinding so a MISTYPED parameter is an ERROR rather than a silent default.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [string]$Dataset = "",
  [switch]$Json
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ProjectDir)) {
  Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red
  exit 2
}
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$ledgerPath = Join-Path $proj "docs\DATASETS.md"

$fails = New-Object System.Collections.Generic.List[string]
$warns = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $ledgerPath)) {
  Write-Host "no docs\DATASETS.md - this project declares no datasets (nothing to police)" -ForegroundColor Yellow
  exit 0
}

# --- parse the ledger ------------------------------------------------------------------------------
$raw = Get-Content -LiteralPath $ledgerPath -Raw
$specs = @()
foreach ($m in [regex]::Matches($raw, '(?ms)^##\s*(D\d+)\s*:\s*(.+?)\s*$(.*?)(?=^##\s|\z)')) {
  $id = $m.Groups[1].Value
  $name = $m.Groups[2].Value.Trim()
  $body = $m.Groups[3].Value
  $file = ([regex]::Match($body, '(?im)^\s*-\s*\**File\**\s*:\**\s*`?([^`\r\n*]+?)`?\**\s*$')).Groups[1].Value.Trim()
  $key  = ([regex]::Match($body, '(?im)^\s*-\s*\**Key\**\s*:\**\s*`?([^`\r\n*]+?)`?\**\s*$')).Groups[1].Value.Trim()
  $minRowsRaw = ([regex]::Match($body, '(?im)^\s*-\s*\**Min rows\**\s*:\**\s*(\d+)')).Groups[1].Value
  $minRows = if ($minRowsRaw) { [int]$minRowsRaw } else { 0 }
  $cols = @()
  foreach ($r in [regex]::Matches($body, '(?m)^\s*\|\s*([A-Za-z0-9_.\- ]+?)\s*\|\s*(text|number|integer|date|bool)\s*\|\s*(yes|no)\s*\|([^|\r\n]*)\|')) {
    $cols += [pscustomobject]@{
      Name = $r.Groups[1].Value.Trim()
      Type = $r.Groups[2].Value.Trim().ToLower()
      Required = ($r.Groups[3].Value.Trim().ToLower() -eq 'yes')
      Range = $r.Groups[4].Value.Trim()
    }
  }
  $specs += [pscustomobject]@{ Id=$id; Name=$name; File=$file; Key=$key; MinRows=$minRows; Columns=$cols }
}
if ($Dataset) { $specs = @($specs | Where-Object { $_.Id -eq $Dataset -or $_.Name -eq $Dataset }) }

# --- helpers ---------------------------------------------------------------------------------------
function Test-Value($value, $col) {
  # returns $null if OK, else the reason
  $v = if ($null -eq $value) { "" } else { [string]$value }
  if ($v.Trim() -eq "") { if ($col.Required) { return "required but empty" } else { return $null } }
  switch ($col.Type) {
    'number'  { if (-not ($v -as [double]))   { return "not a number ('$v')" } }
    'integer' { if (-not ($v -as [int]))      { return "not an integer ('$v')" } }
    'date'    { if (-not ($v -as [datetime])) { return "not a date ('$v')" } }
    'bool'    { if ($v -notmatch '(?i)^(true|false|yes|no|0|1)$') { return "not a bool ('$v')" } }
  }
  if ($col.Range) {
    if ($col.Range -match '^(.+?)\.\.(.+)$') {
      $lo = $Matches[1].Trim(); $hi = $Matches[2].Trim()
      if ($col.Type -eq 'date') {
        $d = $v -as [datetime]
        if ($d -and (($d -lt ($lo -as [datetime])) -or ($d -gt ($hi -as [datetime])))) { return "date $v outside $lo..$hi" }
      } else {
        $d = $v -as [double]
        if ($null -ne $d -and (($d -lt [double]$lo) -or ($d -gt [double]$hi))) { return "value $v outside $lo..$hi" }
      }
    } elseif ($col.Range -match ';') {
      # ';' not '|': the range lives in a markdown TABLE CELL, and '|' would end the cell.
      $allowed = @($col.Range -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
      if ($allowed.Count -gt 0 -and $allowed -notcontains $v) { return "'$v' not one of $($allowed -join ', ')" }
    }
  }
  return $null
}

function Read-Rows($path) {
  $ext = [System.IO.Path]::GetExtension($path).ToLower()
  if ($ext -eq '.csv') { return @(Import-Csv -LiteralPath $path) }
  if ($ext -eq '.tsv') { return @(Import-Csv -LiteralPath $path -Delimiter "`t") }
  if ($ext -eq '.json') {
    $j = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    return @($j)                                    # array of objects; a single object unrolls, hence @()
  }
  return $null
}

# --- the checks ------------------------------------------------------------------------------------
$report = @()
foreach ($s in $specs) {
  if (-not $s.File) { $fails.Add("$($s.Id) declares no File:"); continue }
  $full = Join-Path $proj $s.File
  if (-not (Test-Path -LiteralPath $full)) {
    $fails.Add("$($s.Id) ($($s.Name)): declared file is MISSING - $($s.File)")
    continue
  }
  $rows = $null
  try { $rows = Read-Rows $full } catch { $fails.Add("$($s.Id): could not read $($s.File) - $($_.Exception.Message)"); continue }
  if ($null -eq $rows) { $warns.Add("$($s.Id): $($s.File) is not .csv/.tsv/.json - not checked"); continue }

  $n = $rows.Count
  if ($n -lt $s.MinRows) {
    $fails.Add("$($s.Id) ($($s.Name)): $n row(s), declared minimum $($s.MinRows) - a partial load looks exactly like this")
  }

  $present = @()
  if ($n -gt 0) { $present = @($rows[0].PSObject.Properties.Name) }

  foreach ($c in $s.Columns) {
    if ($present -notcontains $c.Name) {
      $fails.Add("$($s.Id) ($($s.Name)): declared column '$($c.Name)' is NOT in the file - every chart using it renders empty")
      continue
    }
    $bad = @(); $i = 1
    foreach ($row in $rows) {
      $i++
      $why = Test-Value $row.($c.Name) $c
      if ($why) { $bad += "row $i $why" }
      if ($bad.Count -ge 4) { break }
    }
    if ($bad.Count -gt 0) {
      $fails.Add("$($s.Id) ($($s.Name)) column '$($c.Name)': $($bad -join '; ')$(if($bad.Count -ge 4){' (more not shown)'})")
    }
  }
  # columns in the file nobody declared: drift, not necessarily an error
  foreach ($p in $present) {
    if (($s.Columns | ForEach-Object { $_.Name }) -notcontains $p) {
      $warns.Add("$($s.Id): column '$p' is in the file but not declared - add it to DATASETS.md or drop it")
    }
  }
  # duplicate keys
  if ($s.Key -and $n -gt 0) {
    $keyCols = @($s.Key -split '\+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $missingKey = @($keyCols | Where-Object { $present -notcontains $_ })
    if ($missingKey.Count -gt 0) {
      $warns.Add("$($s.Id): Key names column(s) not in the file: $($missingKey -join ', ')")
    } else {
      $seen = @{}; $dupes = @()
      foreach ($row in $rows) {
        $k = ($keyCols | ForEach-Object { [string]$row.$_ }) -join '|'
        if ($seen.ContainsKey($k)) { if ($dupes.Count -lt 4) { $dupes += $k } } else { $seen[$k] = 1 }
      }
      if ($dupes.Count -gt 0) { $fails.Add("$($s.Id) ($($s.Name)): duplicate key(s) [$($s.Key)]: $($dupes -join ', ')") }
    }
  }
  $report += [pscustomobject]@{ id=$s.Id; name=$s.Name; file=$s.File; rows=$n; columns=$s.Columns.Count }
}

# --- output ------------------------------------------------------------------------------------------
$result = [pscustomobject]@{ datasets = $report; fails = $fails; warns = $warns }
if ($Json) { $result | ConvertTo-Json -Depth 6; exit $(if ($fails.Count) { 1 } else { 0 }) }

Write-Host "== data-stats: $proj ==" -ForegroundColor Cyan
foreach ($d in $report) {
  Write-Host ("  {0,-6} {1,-24} {2,6} rows  {3} declared column(s)  [{4}]" -f $d.id, $d.name, $d.rows, $d.columns, $d.file)
}
if ($report.Count -eq 0) { Write-Host "  (no datasets matched)" -ForegroundColor Yellow }
foreach ($w in $warns) { Write-Host "  WARN $w" -ForegroundColor Yellow }
foreach ($f in $fails) { Write-Host "  FAIL $f" -ForegroundColor Red }
Write-Host ""
if ($fails.Count) {
  Write-Host "$($fails.Count) FAIL(s) - the data is not what docs\DATASETS.md says it is. A chart built on this is" -ForegroundColor Red
  Write-Host "confidently wrong, which is worse than a chart that is obviously broken." -ForegroundColor Red
  exit 1
}
Write-Host "datasets match their declarations." -ForegroundColor Green
Write-Host "(This checks SHAPE, not TRUTH - a wrong number inside the declared range still passes.)" -ForegroundColor DarkGray
exit 0
