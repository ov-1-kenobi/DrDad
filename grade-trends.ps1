# grade-trends.ps1 - the computed half of a retrospective.
#
#   grade-trends.ps1 [-ProjectDir .]     human-readable
#   grade-trends.ps1 -Json               machine-readable
#
# Grade cards are per-unit islands: each one says how ONE story went, and nothing ever asks what keeps
# going wrong ACROSS units. So the same defect gets found, written down, and found again three stories
# later. This reads every card in grades\ and reports the patterns - which is the half a script can do.
# /retro then has a model propose convention changes from these numbers, and a human approves them.
#
# It reports TRENDS, not causes. "Six cards mention error handling" is a fact; whether that means the
# convention is missing or the model is sloppy is a judgement, and it stays with the human.

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param([string]$ProjectDir = ".", [switch]$Json)
$ErrorActionPreference = "Stop"
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$gradesDir = Join-Path $proj "grades"

if (-not (Test-Path $gradesDir)) {
  Write-Host "no grades\ folder - nothing to retrospect on yet" -ForegroundColor Yellow
  exit 0
}
$cards = @(Get-ChildItem $gradesDir -Filter *_GRADE.md -File | Sort-Object Name)
if ($cards.Count -eq 0) {
  Write-Host "no grade cards yet - run /build (or /grade <id>) first" -ForegroundColor Yellow
  exit 0
}

# Letter grades, newest entry per card. A card keeps a "## Grade history" table, so the LAST grade in it
# is the current one; a unit that needed three rounds tells you more than its final letter does.
$rows = @()
foreach ($c in $cards) {
  $text = Get-Content $c.FullName -Raw
  $id = $c.BaseName -replace '_GRADE$',''
  # Read the grade from the two places a card actually STATES it - never by scanning prose for a capital
  # letter. '\bA\b' matches the word "A", so "A worked example..." would have scored a card as an A.
  # Cards carry '**Current grade: X**' and a '## Grade history' table.
  $grade = "?"
  $m = [regex]::Match($text, '(?im)^\s*\**\s*Current grade:\s*\**\s*([A-F][+-]?)\b')
  if ($m.Success) { $grade = $m.Groups[1].Value }
  # History rows look like:  | 1 | 2026-08-04 | F | initial implementation |
  # The date is not in a fixed column, so match the ROW and pull whichever cell is a bare grade.
  # No trailing '$': in .NET multiline, '$' matches before \n, so on a CRLF file the position after
  # [^\r\n]* is before \r and the anchor never matches. Cards written on Windows counted zero rounds.
  $histRows = @([regex]::Matches($text, '(?m)^\s*\|(?=[^\r\n]*\d{4}-\d{2}-\d{2})[^\r\n]*') | ForEach-Object { $_.Value })
  if ($grade -eq "?" -and $histRows.Count) {
    $cells = ($histRows[-1] -split '\|') | ForEach-Object { $_.Trim() }
    $g = @($cells | Where-Object { $_ -match '^[A-F][+-]?$' }) | Select-Object -First 1
    if ($g) { $grade = $g }
  }
  $rounds = [Math]::Max($histRows.Count, 1)
  # Order by WHEN it was graded, not by filename. Sorted by name, S2..S6 precede T2.1..T6.1 even though
  # the tasks were graded first - so "early vs late" measured alphabetical order, which is noise. The
  # history table carries real dates; use the latest one.
  $when = [datetime]::MinValue
  foreach ($d in [regex]::Matches($text, '\d{4}-\d{2}-\d{2}')) {
    $parsed = $d.Value -as [datetime]
    if ($parsed -and $parsed -gt $when) { $when = $parsed }
  }
  $rows += [pscustomobject]@{
    Id = $id
    When = $when
    Grade = $grade
    Rounds = [Math]::Max($rounds, 1)
    Bytes = $c.Length
    Stub = ($c.Length -lt 800)
  }
}

# Recurring themes. These are the words that actually show up in suggestions; a theme appearing in half
# the cards is a CONVENTION problem, not a run-of-bad-luck problem, and that is the whole point of a retro.
$themes = [ordered]@{
  "error handling"      = 'error handling|exception|try/catch|swallow'
  "tests / coverage"    = '\btest(s|ing)?\b|coverage|assert'
  "naming"              = 'naming|rename|inconsistent name'
  "async correctness"   = '\basync\b|await|GetAwaiter|\.Result\b|deadlock'
  "null / validation"   = '\bnull\b|validation|guard clause|argument check'
  "duplication"         = 'duplicat|copy-paste|DRY'
  "contract adherence"  = 'contract|worked example|C\d+\b'
  "docs / comments"     = 'comment|xml doc|document'
  "dependency hygiene"  = 'dependency|package|csproj|\.sln\b'
  "logging"             = 'logging|logger|trace'
}
$themeHits = [ordered]@{}
foreach ($k in $themes.Keys) { $themeHits[$k] = @() }
foreach ($c in $cards) {
  $text = Get-Content $c.FullName -Raw
  $id = $c.BaseName -replace '_GRADE$',''
  foreach ($k in $themes.Keys) {
    if ($text -match $themes[$k]) { $themeHits[$k] += $id }
  }
}

$order = @{ "A+"=1;"A"=2;"A-"=3;"B+"=4;"B"=5;"B-"=6;"C+"=7;"C"=8;"C-"=9;"D+"=10;"D"=11;"D-"=12;"F"=13;"?"=99 }
# Chronological, so the trend means something. Cards with no date fall to the end in name order.
$graded = @($rows | Where-Object { $_.Grade -ne "?" } | Sort-Object When, Id)
$avgIdx = if ($graded.Count) { [Math]::Round((($graded | ForEach-Object { $order[$_.Grade] }) | Measure-Object -Average).Average, 1) } else { 0 }
# Trend: cards are named by unit id, which sorts roughly in build order - compare the first half to the last.
$trend = "n/a"
if ($graded.Count -ge 4) {
  $half = [int]($graded.Count / 2)
  $early = (($graded[0..($half-1)] | ForEach-Object { $order[$_.Grade] }) | Measure-Object -Average).Average
  $late  = (($graded[$half..($graded.Count-1)] | ForEach-Object { $order[$_.Grade] }) | Measure-Object -Average).Average
  $delta = $early - $late          # lower index = better grade, so positive delta = improving
  $trend = if ($delta -gt 0.5) { "improving" } elseif ($delta -lt -0.5) { "DEGRADING" } else { "flat" }
}

$repeat = @($rows | Where-Object { $_.Rounds -ge 2 })
$stubs  = @($rows | Where-Object { $_.Stub })
$recurring = @($themeHits.Keys | Where-Object { $themeHits[$_].Count -ge [Math]::Max(2, [int]($cards.Count * 0.4)) })

$result = [pscustomobject]@{
  cards = $cards.Count
  averageGradeIndex = $avgIdx
  trend = $trend
  needingRework = @($repeat | ForEach-Object { "$($_.Id) x$($_.Rounds)" })
  stubCards = @($stubs | ForEach-Object { $_.Id })
  recurringThemes = @($recurring | ForEach-Object { "$_ ($($themeHits[$_].Count)/$($cards.Count) cards: $($themeHits[$_] -join ', '))" })
  grades = @(($rows | Sort-Object When, Id) | ForEach-Object { "$($_.Id)=$($_.Grade)" })
}
if ($Json) { $result | ConvertTo-Json -Depth 5; exit 0 }

Write-Host "== grade trends: $proj ==" -ForegroundColor Cyan
Write-Host ("  cards            : {0}" -f $cards.Count)
Write-Host ("  grades (oldest first): {0}" -f ((($rows | Sort-Object When, Id) | ForEach-Object { "$($_.Id)=$($_.Grade)" }) -join "  "))
Write-Host ("  direction        : {0}" -f $trend) -ForegroundColor $(if ($trend -eq "DEGRADING") { "Red" } elseif ($trend -eq "improving") { "Green" } else { "Gray" })
if ($repeat.Count) {
  Write-Host "  needed rework    : $(($repeat | ForEach-Object { "$($_.Id) x$($_.Rounds)" }) -join ', ')" -ForegroundColor Yellow
}
if ($stubs.Count) {
  Write-Host "  STUB cards       : $(($stubs.Id) -join ', ') - graded but not really assessed" -ForegroundColor Red
}
Write-Host ""
if ($recurring.Count) {
  Write-Host "  RECURRING THEMES - these are convention problems, not bad luck:" -ForegroundColor Yellow
  foreach ($r in $recurring) { Write-Host "    - $r" -ForegroundColor Yellow }
} else {
  Write-Host "  no theme appears in enough cards to call it a pattern yet." -ForegroundColor Green
}
Write-Host ""
Write-Host "Themes seen (any count):" -ForegroundColor DarkGray
foreach ($k in $themeHits.Keys) {
  if ($themeHits[$k].Count -gt 0) { Write-Host ("    {0,-20} {1}" -f $k, $themeHits[$k].Count) -ForegroundColor DarkGray }
}
Write-Host ""
Write-Host "These are TRENDS, not causes. /retro turns them into proposed convention changes; you approve them." -ForegroundColor Cyan
exit 0
