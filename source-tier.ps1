# source-tier.ps1 - the HUMAN sets a source's tier, and the ledger records that a human did.
#
#   dad source-tier S012 primary                 one source
#   dad source-tier S012,S015,S020-S031 secondary  several: comma list and ranges
#   dad source-tier -List                        what still needs a human (unknown, or tiered without a stamp)
#
# WHY. docs\SOURCES.md says the tier is the one judgement no model makes: primary / secondary decides how
# much weight a claim can bear. In a real project 317 of 334 rows read "primary" (a third-party wiki among
# them), and the pass notes said so openly: "all labelled primary by the caller's instruction". Nothing
# recorded WHO had set a tier, so nothing could tell an assessment from a default.
#
# So the ledger has a last column, `tiered`, and this script is its only writer: it shows the sources,
# asks at the console, and writes the tier plus "human <date>". It refuses when input is not a console
# (an agent's shell), the same way `dad doctor -PrunePermissions` does. source-stats then reads the column:
# a tier with no stamp is a FAIL in a ledger that has the column, and a source the design cites cannot be
# unknown or unstamped when the design is locked (`source-stats -LockCheck`).
#
# It cannot stop someone typing the stamp by hand. It makes the honest path one command, and it makes a
# tier that nobody stamped visible as exactly that.

# CmdletBinding so a MISTYPED parameter is an ERROR rather than a silent default.
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Ids = "",
  [Parameter(Position = 1)][string]$Tier = "",
  [string]$ProjectDir = ".",
  [switch]$List
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $ProjectDir)) { Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red; exit 2 }
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$ledger = Join-Path $proj "docs\SOURCES.md"
if (-not (Test-Path -LiteralPath $ledger)) { Write-Host "no docs\SOURCES.md in $proj" -ForegroundColor Yellow; exit 2 }

$raw = [System.IO.File]::ReadAllText($ledger)
$eol = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = @($raw -split "`r?`n")

# cells of a ledger row: id, tier, fetched, title, url, published, tiered (the last two may be absent)
function Split-Row([string]$line) { return @(($line.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() }) }
$rowIx = @{}
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^\s*\|\s*(S\d+)\s*\|') { if (-not $rowIx.ContainsKey($Matches[1])) { $rowIx[$Matches[1]] = $i } }
}

if ($List -or -not $Ids) {
  Write-Host "== sources that need a human tier: $proj ==" -ForegroundColor Cyan
  $n = 0
  foreach ($id in ($rowIx.Keys | Sort-Object { [int]($_ -replace '\D', '') })) {
    $c = Split-Row $lines[$rowIx[$id]]
    $t = if ($c.Count -gt 1) { $c[1] } else { "" }
    $stamp = if ($c.Count -gt 6) { $c[6] } else { "" }
    if ($t -match '^<' ) { continue }                                  # the template's placeholder row
    $why = $null
    if (-not $t -or $t -eq 'unknown') { $why = "unknown" }
    elseif ($stamp -notmatch '^human \d{4}-\d{2}-\d{2}$') { $why = "'$t' with no human stamp" + $(if ($stamp) { " ($stamp)" } else { "" }) }
    if ($why) { $n++; Write-Host ("  {0,-6} {1,-34} {2}" -f $id, $why, $(if ($c.Count -gt 3) { $c[3] } else { "" })) }
  }
  if ($n -eq 0) { Write-Host "  none - every source carries a tier a human stamped." -ForegroundColor Green }
  else { Write-Host "`n  $n source(s). Tier them:  dad source-tier <id[,id,S10-S20]> primary|secondary" -ForegroundColor Yellow }
  exit 0
}

if ($Tier -notmatch '^(primary|secondary)$') { Write-Host "tier must be 'primary' or 'secondary' (got '$Tier')" -ForegroundColor Red; exit 2 }
$want = New-Object System.Collections.Generic.List[string]
foreach ($part in ($Ids -split ',')) {
  $p = $part.Trim(); if (-not $p) { continue }
  $rm = [regex]::Match($p, '^S(\d+)\s*-\s*S?(\d+)$')
  if ($rm.Success) {
    $a = [int]$rm.Groups[1].Value; $b = [int]$rm.Groups[2].Value
    foreach ($id in $rowIx.Keys) { $v = [int]($id -replace '\D', ''); if ($v -ge $a -and $v -le $b -and -not $want.Contains($id)) { $want.Add($id) } }
  } elseif ($rowIx.ContainsKey($p)) { if (-not $want.Contains($p)) { $want.Add($p) } }
  else { Write-Host "no ledger row for '$p'" -ForegroundColor Red; exit 2 }
}
if ($want.Count -eq 0) { Write-Host "no matching sources." -ForegroundColor Yellow; exit 2 }
$want = @($want | Sort-Object { [int]($_ -replace '\D', '') })

Write-Host "== tier as '$Tier': $($want.Count) source(s) ==" -ForegroundColor Cyan
foreach ($id in ($want | Select-Object -First 40)) {
  $c = Split-Row $lines[$rowIx[$id]]
  Write-Host ("  {0,-6} {1}  {2}" -f $id, $(if ($c.Count -gt 3) { $c[3] } else { "" }), $(if ($c.Count -gt 4) { $c[4] } else { "" }))
}
if ($want.Count -gt 40) { Write-Host "  ... and $($want.Count - 40) more" }

$redirected = $false
try { $redirected = [Console]::IsInputRedirected } catch { $redirected = $true }
if ($redirected) {
  Write-Host ""
  Write-Host "NOT changed: tiering is the human's judgement, and input is not a console." -ForegroundColor Yellow
  Write-Host "Run it yourself in a terminal:  dad source-tier $Ids $Tier" -ForegroundColor Yellow
  exit 3
}
$ans = Read-Host "You have looked at these and judge them '$Tier'? [y/N]"
if ($ans -notmatch '^(y|yes)$') { Write-Host "nothing changed." -ForegroundColor Cyan; exit 0 }

$stampNow = "human " + (Get-Date -Format 'yyyy-MM-dd')
foreach ($id in $want) {
  $c = New-Object System.Collections.Generic.List[string]
  foreach ($x in (Split-Row $lines[$rowIx[$id]])) { $c.Add($x) }
  while ($c.Count -lt 7) { $c.Add("") }
  $c[1] = $Tier; $c[6] = $stampNow
  $lines[$rowIx[$id]] = "| " + ($c -join " | ") + " |"
}
# make sure the header names the column (a ledger from before 0.61.0 that upgrade-project has not touched)
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^\s*\|\s*id\s*\|' -and $lines[$i] -notmatch '\|\s*tiered\s*\|') {
    $lines[$i] = $lines[$i].TrimEnd().TrimEnd('|').TrimEnd() + " | tiered |"
    if ($i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^\s*\|[\s:|-]+\|\s*$') { $lines[$i + 1] = $lines[$i + 1].TrimEnd().TrimEnd('|').TrimEnd() + "|------------|" }
    break
  }
}
[System.IO.File]::WriteAllText($ledger, ($lines -join $eol), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "tiered $($want.Count) source(s) as '$Tier' ($stampNow) in docs\SOURCES.md. Reindex when you are done." -ForegroundColor Green
exit 0
