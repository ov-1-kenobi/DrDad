# dad-status-guard.ps1 - close-unit is the ONLY writer of a story's DONE marker. This is the check.
#
#   dad-status-guard.ps1 -Staged                    pre-commit mode: compare the STAGED STORIES.md with HEAD
#   dad-status-guard.ps1 -WorkingTree [-ProjectDir] close-unit mode: compare the file on disk with HEAD
#   dad-status-guard.ps1 ... -AllowStory S3         the one story THIS close-unit run is rolling up itself
#
# Exit 0 = fine. Exit 1 = a story heading went to "Status: DONE" by some other hand; the ids are printed.
#
# THE INCIDENT THIS CLOSES (a real project, story S55). The story-level close refused: the tests failed.
# A later close passed its checks, wrote the task tick and the "DONE closed:close-unit" stamp to disk, and
# then its COMMIT failed - so the stamp sat in the working tree with nothing behind it. A hand-made commit
# ("T55.8: ...; S55 DONE") banked it, while the next story-level close was still failing its tests. The
# stamp was meant to be the proof that close-unit closed the story, but it is only text: anyone can type
# it, and `git add -A` in ANY later close will commit whatever is on disk.
#
# So the proof moves from the text to the moment of writing. A story may become DONE in a commit only when
# close-unit itself is making that commit for that story - it says so through DAD_CLOSE_UNIT_STORY, which
# it sets for the lifetime of its own `git commit` and nowhere else. Everything else is refused: by the
# pre-commit hook for a hand-made commit, and by close-unit's own start-up check for a marker that is
# sitting in the working tree when a close for a DIFFERENT unit begins.
#
# A human who really means to mark a story DONE by hand (importing finished work, repairing history) sets
# DAD_ALLOW_STATUS_EDIT=1 for that one commit. It is named in the refusal, deliberately: the point is that
# it is a decision somebody made, not something that happened.
#
# FAILS OPEN on its own defects (no git, unreadable file, a bug here): a guard that blocks every commit
# when IT is broken gets switched off, which costs more than the case it guards. Same rule as dad-guard.

# CmdletBinding so a MISTYPED parameter is an ERROR rather than a silent default.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [switch]$Staged,
  [switch]$WorkingTree,
  [string]$AllowStory = ""
)
$ErrorActionPreference = "Continue"

# Story id -> $true when its heading carries "Status: DONE". Headings only: prose that quotes a marker
# (a story describing this very rule) must not count.
function Get-DoneStories([string]$text) {
  $done = @{}
  if (-not $text) { return $done }
  foreach ($ln in ($text -split "`r?`n")) {
    if ($ln -notmatch '^#{1,6}\s') { continue }
    $m = [regex]::Match($ln, '\b(S\d+[A-Za-z0-9._-]*)\b')
    if (-not $m.Success) { continue }
    if ($ln -match '<!--\s*Status:\s*DONE\b') { $done[$m.Groups[1].Value] = $true }
  }
  return $done
}

try {
  if ($env:DAD_ALLOW_STATUS_EDIT -eq '1') { exit 0 }
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { exit 0 }
  if (-not (Test-Path -LiteralPath $ProjectDir)) { exit 0 }
  $proj = (Resolve-Path -LiteralPath $ProjectDir).Path
  $top = (& git -C $proj rev-parse --show-toplevel 2>$null | Out-String).Trim()
  if (-not $top) { exit 0 }
  & git -C $top rev-parse --verify --quiet HEAD 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { exit 0 }                       # no commit yet: nothing to compare against

  $allowed = @{}
  foreach ($a in @($AllowStory, $env:DAD_CLOSE_UNIT_STORY)) { if ($a) { $allowed[$a.Trim()] = $true } }

  # Which STORIES.md files are in play? Any path whose leaf is STORIES.md (the docs folder can be moved).
  $paths = @()
  if ($Staged) {
    $paths = @(& git -C $top diff --cached --name-only --diff-filter=AM 2>$null | Where-Object { $_ -match '(^|/)STORIES\.md$' })
  } else {
    $paths = @(& git -C $top status --porcelain -uall 2>$null | ForEach-Object {
      if ($_.Length -gt 3) { $_.Substring(3).Trim().Trim('"') } } | Where-Object { $_ -match '(^|/)STORIES\.md$' })
  }
  $bad = New-Object System.Collections.Generic.List[string]
  foreach ($rel in $paths) {
    $old = (& git -C $top show "HEAD:$rel" 2>$null | Out-String)
    if ($LASTEXITCODE -ne 0) { continue }                   # the file is NEW in this commit: an import, allowed
    if ($Staged) { $new = (& git -C $top show ":$rel" 2>$null | Out-String) }
    else {
      $full = Join-Path $top ($rel -replace '/', '\')
      if (-not (Test-Path -LiteralPath $full)) { continue }
      $new = [System.IO.File]::ReadAllText($full)
    }
    $was = Get-DoneStories $old
    $now = Get-DoneStories $new
    foreach ($id in $now.Keys) {
      if (-not $was.ContainsKey($id) -and -not $allowed.ContainsKey($id)) { $bad.Add("$id ($rel)") }
    }
  }
  if ($bad.Count -eq 0) { exit 0 }

  Write-Host ""
  Write-Host "[status-guard] REFUSED: a story was marked DONE by hand: $($bad -join ', ')" -ForegroundColor Red
  Write-Host "  Only close-unit may write a story's 'Status: DONE' marker - it does so after the build and the" -ForegroundColor Red
  Write-Host "  story's tests pass, and it commits the marker itself. A marker typed in by hand (or left on disk" -ForegroundColor Red
  Write-Host "  by a close that did not finish) claims a verification that did not happen." -ForegroundColor Red
  Write-Host "  Put the heading back to what git has:" -ForegroundColor Yellow
  foreach ($rel in ($paths | Select-Object -Unique)) { Write-Host "      git checkout HEAD -- `"$rel`"     (or edit only that story's marker back)" -ForegroundColor Yellow }
  Write-Host "  then close the story properly:  dad close-unit -Id <story or its last task> -Title `"...`"" -ForegroundColor Yellow
  Write-Host "  (A HUMAN who means to mark it by hand sets DAD_ALLOW_STATUS_EDIT=1 for that one commit.)" -ForegroundColor DarkGray
  exit 1
} catch {
  exit 0
}
