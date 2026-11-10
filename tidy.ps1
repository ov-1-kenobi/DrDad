# tidy.ps1 - clear the junk a run leaves at the project root, and empty the _tmp/ scratch folder.
#
# Two-part hygiene, paired with the _tmp convention: agents are told to do scratch work in _tmp/ (which is
# gitignored) instead of scattering it at the root, and this sweeps both - the sanctioned _tmp/ AND the
# junk that still lands at the root. It removes ONLY what `doc-stats -Junk` identifies (one source of
# truth, so tidy and the findings can never disagree): ad-hoc SUMMARY/COMPLETE/IMPLEMENTATION files, path-
# MANGLED directories (a Windows path handed to bash), and .binlog build logs. It never touches src/,
# docs/, tests/, or a solution file - deleting the right .sln is a judgement, so those are only reported.
#
#   dad tidy                     LIST what would be removed (default; changes nothing)
#   dad tidy -Fix                remove the junk and empty _tmp/
#   dad tidy -Fix -KeepTmp       remove the junk but leave _tmp/ alone
#   dad tidy -Fix -TmpOnly -OlderThanHours 1
#                                sweep ONLY _tmp/, and only files not written in the last hour. This is what
#                                close-unit runs at every story close (0.60.0): scratch was meant to be
#                                emptied by someone remembering to run tidy, and one project's _tmp/ reached
#                                175 entries (logs, .bak/.orig copies, one-off scripts) across six weeks.
#                                The age floor leaves the scratch of an agent that is still working alone.

# CmdletBinding so a MISTYPED parameter is an ERROR rather than a silent default.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [switch]$Fix,
  [switch]$KeepTmp,
  [switch]$TmpOnly,
  [double]$OlderThanHours = 0
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot

if (-not (Test-Path -LiteralPath $ProjectDir)) { Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red; exit 2 }
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path.TrimEnd('\')
# Same guard as free-locks: never operate on a root or home path; a real project has a CLAUDE.md/docs.
$looksLikeProject = (Test-Path (Join-Path $proj "CLAUDE.md")) -or (Test-Path (Join-Path $proj "docs"))
$depth = ($proj -split '[\\/]' | Where-Object { $_ }).Count
if (-not $looksLikeProject -or $depth -lt 2) {
  Write-Host "REFUSING: '$proj' does not look like a project (no CLAUDE.md/docs, or too shallow)." -ForegroundColor Red
  exit 2
}

# --- -TmpOnly: sweep the scratch folder and nothing else ------------------------------------------
if ($TmpOnly) {
  $tmpDir = Join-Path $proj "_tmp"
  if (-not (Test-Path -LiteralPath $tmpDir -PathType Container)) { Write-Host "tmp-sweep: removed=0 kept=0 (no _tmp/)"; exit 0 }
  # Never delete what git TRACKS. _tmp/ is gitignored in every scaffolded project; if a project tracks it,
  # those files are somebody's source and this sweep has no business with them.
  if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $trackedTmp = ""
    try { $trackedTmp = (& git -C $proj ls-files -- "_tmp" 2>$null | Select-Object -First 1 | Out-String).Trim() } catch { }
    finally { $ErrorActionPreference = $prevEap }
    if ($trackedTmp) { Write-Host "tmp-sweep: removed=0 kept=0 (_tmp/ holds files tracked by git - not swept)"; exit 0 }
  }
  $cut = (Get-Date).AddHours(-1 * [Math]::Max(0, $OlderThanHours))
  $all = @(Get-ChildItem -LiteralPath $tmpDir -Recurse -Force -File -ErrorAction SilentlyContinue)
  $old = @($all | Where-Object { $_.LastWriteTime -lt $cut })
  $removed = 0
  foreach ($f in $old) {
    if ($Fix) { try { $f.Attributes = 'Normal'; Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $removed++ } catch { } }
    else { Write-Host ("  WOULD remove: {0}" -f $f.FullName.Substring($proj.Length + 1)) -ForegroundColor Yellow }
  }
  if ($Fix) {
    # empty folders left behind, deepest first; _tmp/ itself stays
    foreach ($d in @(Get-ChildItem -LiteralPath $tmpDir -Recurse -Force -Directory -ErrorAction SilentlyContinue | Sort-Object { $_.FullName.Length } -Descending)) {
      if (@(Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0) { try { Remove-Item -LiteralPath $d.FullName -Force -ErrorAction Stop } catch { } }
    }
  }
  $kept = if ($Fix) { $all.Count - $removed } else { $all.Count - $old.Count }
  $shown = if ($Fix) { $removed } else { $old.Count }
  Write-Host "tmp-sweep: removed=$shown kept=$kept$(if (-not $Fix) { ' (dry run: -Fix to remove)' })"
  exit 0
}

# ONE detector: ask doc-stats what the junk is.
$ds = Join-Path $kit "doc-stats.ps1"
if (-not (Test-Path $ds)) { Write-Host "ERROR: doc-stats.ps1 not found next to tidy" -ForegroundColor Red; exit 2 }
$junk = $null
try { $junk = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $proj -Junk 2>$null | Out-String | ConvertFrom-Json) }
catch { Write-Host "ERROR: could not read junk list from doc-stats: $($_.Exception.Message)" -ForegroundColor Red; exit 2 }

$targets = @()   # @{ Path; Kind; Recurse }
foreach ($n in @($junk.StrayFiles)) { $targets += @{ Path = (Join-Path $proj $n); Kind = "ad-hoc file"; Recurse = $false } }
foreach ($n in @($junk.MangledDirs)) { $targets += @{ Path = (Join-Path $proj $n); Kind = "mangled dir"; Recurse = $true } }
foreach ($n in @($junk.Binlogs))    { $targets += @{ Path = (Join-Path $proj $n); Kind = "binlog";      Recurse = $false } }
$tmp = Join-Path $proj "_tmp"
$sweepTmp = ($junk.TmpDir -and -not $KeepTmp)

Write-Host "== tidy: $proj ==" -ForegroundColor Cyan
if ($targets.Count -eq 0 -and -not $sweepTmp) {
  Write-Host "  clean - no root junk and no _tmp/ to sweep." -ForegroundColor Green
  if (@($junk.ExtraSolutions).Count -gt 1) { Write-Host "  NOTE: $((@($junk.ExtraSolutions)) -join ', ') - two solution files; keep one (not auto-removed)." -ForegroundColor Yellow }
  exit 0
}

$verb = if ($Fix) { "removing" } else { "WOULD remove (-Fix to do it)" }
foreach ($t in $targets) {
  if (-not (Test-Path -LiteralPath $t.Path)) { continue }
  Write-Host ("  {0}: {1}  [{2}]" -f $verb, (Split-Path $t.Path -Leaf), $t.Kind) -ForegroundColor Yellow
  if ($Fix) {
    try { Remove-Item -LiteralPath $t.Path -Force -Recurse:$t.Recurse -ErrorAction Stop }
    catch { Write-Host ("    could not remove: {0}" -f $_.Exception.Message.Split([char]10)[0]) -ForegroundColor Red }
  }
}
if ($sweepTmp) {
  $items = @(Get-ChildItem -LiteralPath $tmp -Force -ErrorAction SilentlyContinue)
  Write-Host ("  {0}: _tmp/ contents ({1} item(s))" -f $verb, $items.Count) -ForegroundColor Yellow
  if ($Fix) {
    foreach ($it in $items) { try { Remove-Item -LiteralPath $it.FullName -Force -Recurse -ErrorAction Stop } catch { } }
  }
}
if (@($junk.ExtraSolutions).Count -gt 1) {
  Write-Host "  NOTE: $((@($junk.ExtraSolutions)) -join ', ') - two solution files; keep one (not auto-removed, that is your call)." -ForegroundColor Yellow
}

if ($Fix) { Write-Host "  done." -ForegroundColor Green }
else { Write-Host "  nothing changed. Re-run with -Fix to remove the above." -ForegroundColor Cyan }
exit 0
