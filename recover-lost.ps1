# recover-lost.ps1 - find named units that VANISHED from files, and put back the ones that should come back.
#
#   recover-lost.ps1                          what was lost since the ratchet baseline (report only)
#   recover-lost.ps1 -Since <sha>             compare against a specific commit instead
#   recover-lost.ps1 -Path src/Foo.cs         just one file
#   recover-lost.ps1 -Restore                 write the missing units back
#   recover-lost.ps1 -Json
#
# THE SHAPE THIS HANDLES, and it is worth recognising in the wild:
#   "a change removed far more than it added, the result still compiles, and nothing is obviously broken."
#
# The worked example. A run was asked to fix failing IIIF tests. It rewrote ImageApiControllerTests.cs to
# introduce a CustomWebApplicationFactory - a real, correct fix - and of 16 tests only 1 survived the
# rewrite. 160 lines became 30. Gone: the C9 worked example, the level-2 conformance check, the
# byte-identical guarantee. The suite then read "8 passed, 3 failed" and EVERY gate went green, because
# every gate asked "do the tests pass?" and none asked "are the tests still there?".
#
# WHY A WHOLE-FILE REVERT IS THE WRONG ANSWER. The rest of that change was GOOD - the fixture, a JSON-LD
# @context fix, a .NET 10 PipeWriter fix. `git checkout` would have thrown all of it away and re-broken
# what had just been fixed. So this works at the level of NAMED UNITS: methods, tests, functions, headings.
# It restores what disappeared and leaves what arrived.
#
# "AND SENSIBLE" - what it deliberately does NOT bring back:
#   - a unit that still exists somewhere ELSE in the tree (moved or renamed, not lost)
#   - anything, ever, without -Restore. Deletion is sometimes correct, and a tool that silently undoes
#     deliberate work is worse than the problem.
# What comes back may not COMPILE on its own (a restored test can need a using, a fixture, a helper that
# also changed). That is expected: this hands you back the content and the diff to reconcile against, not
# a finished merge.

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [string]$Since = "",
  [string]$Path = "",
  [switch]$Restore,
  [switch]$Json
)
$ErrorActionPreference = "Stop"
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Host "git not on PATH" -ForegroundColor Yellow; exit 0 }
if (-not (Test-Path (Join-Path $proj ".git"))) { Write-Host "no git repo here - nothing to recover from" -ForegroundColor Yellow; exit 0 }

# Default to the ratchet's baseline: the last commit at which everything was verified. That is the
# meaningful "before", and it is why the two scripts share a file.
if (-not $Since) {
  $bl = Join-Path $proj ".claude\.dad-ratchet.json"
  if (Test-Path $bl) {
    try { $Since = [string]((Get-Content $bl -Raw | ConvertFrom-Json).commit) } catch { }
  }
}
if (-not $Since) { $Since = "HEAD" }

# A "named unit" is anything a person would notice the absence of. Language-agnostic by construction:
# these patterns capture the NAME, and a name that was there and is now nowhere is the signal.
$unitPatterns = @(
  '(?m)^\s*(?:\[[^\]]+\]\s*)*(?:public|private|protected|internal)?\s*(?:static\s+|async\s+|virtual\s+|override\s+|sealed\s+|partial\s+)*(?:[\w<>\[\],\.\?]+\s+)?([A-Za-z_]\w*)\s*\([^;]*\)\s*(?:where[^{]*)?\{',  # C#/Java/TS method
  '(?m)^\s*(?:public|internal|private)?\s*(?:abstract\s+|sealed\s+|static\s+|partial\s+)*(?:class|interface|struct|record|enum)\s+([A-Za-z_]\w*)',                                                            # type
  '(?m)^\s*def\s+([A-Za-z_]\w*)\s*\(',                                                                                                                                                                        # python
  '(?m)^\s*func\s+(?:\([^)]*\)\s*)?([A-Za-z_]\w*)\s*\(',                                                                                                                                                      # go
  '(?m)^\s*(?:pub\s+)?fn\s+([A-Za-z_]\w*)',                                                                                                                                                                   # rust
  '(?m)^\s*(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_]\w*)',                                                                                                                                             # js
  '(?m)^\s*(?:it|test|describe)\s*\(\s*[''"]([^''"]+)[''"]',                                                                                                                                                  # js/ts test names
  '(?m)^#{2,4}\s+(.+?)\s*$'                                                                                                                                                                                   # markdown headings
)

function Get-Units([string]$text) {
  $names = New-Object System.Collections.Generic.HashSet[string]
  if (-not $text) { return $names }
  foreach ($p in $unitPatterns) {
    foreach ($m in [regex]::Matches($text, $p)) {
      $n = $m.Groups[1].Value.Trim()
      # Control-flow keywords look like calls; they are not units.
      if ($n -and $n -notmatch '^(if|for|foreach|while|switch|catch|using|lock|return|new|get|set|do|else|try)$') {
        [void]$names.Add($n)
      }
    }
  }
  return $names
}

$prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
Push-Location $proj
try {
  $changed = @()
  if ($Path) { $changed = @($Path.Replace('\','/')) }
  else       { $changed = @(git diff --name-only $Since -- . 2>$null | Where-Object { $_ }) }

  $report = @()
  foreach ($rel in $changed) {
    $ext = [System.IO.Path]::GetExtension($rel)
    if (@(".cs",".fs",".vb",".py",".ts",".tsx",".js",".jsx",".go",".rs",".java",".kt",".md") -notcontains $ext) { continue }
    $old = (git show "$Since`:$rel" 2>$null | Out-String)
    if (-not $old) { continue }                       # new file - nothing can have been lost from it
    $full = Join-Path $proj $rel
    $new = if (Test-Path -LiteralPath $full) { Get-Content $full -Raw } else { "" }

    $oldUnits = Get-Units $old
    $newUnits = Get-Units $new
    $missing = @($oldUnits | Where-Object { -not $newUnits.Contains($_) })
    if ($missing.Count -eq 0) { continue }

    # MOVED, not lost: if the name exists anywhere else in the tree now, it was relocated or renamed
    # around - restoring it here would duplicate it. This is most of what separates a real loss from a
    # refactor, and getting it wrong is how a "recovery" introduces duplicate definitions.
    $reallyGone = @(); $moved = @()
    foreach ($n in $missing) {
      $hit = @(git grep -l -F -- $n 2>$null | Where-Object { $_ -and $_ -ne $rel })
      if ($hit.Count -gt 0) { $moved += "$n (now in $($hit[0]))" } else { $reallyGone += $n }
    }
    $oldLines = ($old -split "`n").Count; $newLines = ($new -split "`n").Count
    $report += [pscustomobject]@{
      Path = $rel; OldLines = $oldLines; NewLines = $newLines
      Lost = $reallyGone; Moved = $moved; OldText = $old
    }
  }
} finally { Pop-Location; $ErrorActionPreference = $prevEap }

$withLoss = @($report | Where-Object { $_.Lost.Count -gt 0 })

if ($Json) {
  $withLoss | Select-Object Path, OldLines, NewLines, Lost, Moved | ConvertTo-Json -Depth 5
  exit $(if ($withLoss.Count) { 1 } else { 0 })
}

Write-Host "== recover-lost: since $Since ==" -ForegroundColor Cyan
if ($withLoss.Count -eq 0) {
  Write-Host "  nothing named has vanished." -ForegroundColor Green
  if ($report.Count) {
    foreach ($r in $report) { if ($r.Moved.Count) { Write-Host "  (moved, not lost) $($r.Path): $($r.Moved -join ', ')" -ForegroundColor DarkGray } }
  }
  exit 0
}

foreach ($r in $withLoss) {
  Write-Host ""
  Write-Host "  $($r.Path)  ($($r.OldLines) -> $($r.NewLines) lines)" -ForegroundColor Yellow
  Write-Host "    GONE ($($r.Lost.Count)):" -ForegroundColor Red
  foreach ($n in ($r.Lost | Select-Object -First 25)) { Write-Host "      - $n" -ForegroundColor Red }
  if ($r.Lost.Count -gt 25) { Write-Host "      ... +$($r.Lost.Count - 25) more" -ForegroundColor Red }
  if ($r.Moved.Count) { Write-Host "    moved elsewhere (NOT restored): $($r.Moved -join ', ')" -ForegroundColor DarkGray }
}

if (-not $Restore) {
  Write-Host ""
  Write-Host "Report only. To put the vanished units back (keeping everything that ARRIVED):" -ForegroundColor Cyan
  Write-Host "  recover-lost.cmd -Restore" -ForegroundColor Green
  Write-Host "Then RECONCILE and build - restored code can need a using, a fixture or a helper that also" -ForegroundColor Cyan
  Write-Host "changed. Compare with:  git diff $Since -- <path>" -ForegroundColor Cyan
  exit 1
}

# --- restore ---------------------------------------------------------------------------------------
# Append the OLD file's body under a clearly marked block rather than splicing unit by unit. Splicing
# needs a parser per language and gets it subtly wrong; a marked block is honest about being a starting
# point, keeps every arriving change intact, and is trivial to trim by hand.
foreach ($r in $withLoss) {
  $full = Join-Path $proj $r.Path
  $cur = if (Test-Path -LiteralPath $full) { Get-Content $full -Raw } else { "" }
  $isMd = ([System.IO.Path]::GetExtension($r.Path) -eq ".md")
  $open = if ($isMd) { "<!-- RECOVERED from $Since - reconcile and delete this marker" } else { "/* ===== RECOVERED from $Since =====" }
  $close = if ($isMd) { "-->" } else { "===== end RECOVERED ===== */" }
  $body = @(
    "",
    $open,
    "  These named units were in this file at $Since and are not here now:",
    ("    " + (($r.Lost | Select-Object -First 40) -join ", ")),
    "  The ORIGINAL file follows. Move back what belongs, delete the rest, then build.",
    "  Full diff:  git diff $Since -- $($r.Path)",
    $close,
    "",
    $(if ($isMd) { "<!--" } else { "/*" }),
    $r.OldText.TrimEnd(),
    $(if ($isMd) { "-->" } else { "*/" })
  ) -join "`r`n"
  [System.IO.File]::WriteAllText($full, ($cur.TrimEnd() + "`r`n" + $body + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  restored into $($r.Path) (commented block at the end)" -ForegroundColor Green
}
Write-Host ""
Write-Host "The recovered content is COMMENTED OUT on purpose - it is a starting point, not a merge." -ForegroundColor Yellow
Write-Host "Move back what belongs, delete the block, and BUILD before closing anything." -ForegroundColor Yellow
exit 0
