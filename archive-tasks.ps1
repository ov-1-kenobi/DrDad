# archive-tasks.ps1 - move the BODIES of a closed story's ticked tasks out of docs\TASKS.md.
#
#   archive-tasks.ps1 -Story S3            one story (close-unit runs this at the story-level close)
#   archive-tasks.ps1 -AllDone             every story marked DONE (a one-time catch-up for an old project)
#   archive-tasks.ps1 ... -DryRun          say what would move; change nothing
#
# WHY. TASKS.md only ever grew. Each task block carries its Goal, Touches, Do, Acceptance, Context and Refs -
# about 4 KB - and none of that is read again once the task is ticked and its story closed. One project's
# TASKS.md reached 3.6 MB, most of it finished work, and every agent that was told to "read the next task"
# had to get past all of it.
#
# WHAT MOVES, AND WHAT STAYS. The HEADING of every task stays exactly where it is:
#     ### [x] T3.2 - Parse the header   (Story S3)
#     - archived: docs/archive/TASKS-S3.md (commit 1a2b3c4)
# so every count in the kit is unchanged - doc-stats, the ratchet (it counts headings, so nothing
# "shrank"), close-unit's already-closed check, the Build order. Only the body goes, appended verbatim to
# docs\archive\TASKS-<story>.md. Nothing is deleted; the archive is committed, but it is not indexed for
# search (local-tools skips docs\archive\).
#
# Only tasks that are [x] in a story whose heading says DONE are touched. Open tasks, and ticked tasks of a
# story that is still open, keep their bodies - they are still being read.

# CmdletBinding so a MISTYPED parameter is an ERROR rather than a silent default.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [string]$Story = "",
  [switch]$AllDone,
  [switch]$DryRun
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $ProjectDir)) { Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red; exit 2 }
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
. (Join-Path $PSScriptRoot "docs-dir.ps1")
$docs = Resolve-DocsDir $proj -Quiet
$tasksFile = Join-Path $docs "TASKS.md"
$storiesFile = Join-Path $docs "STORIES.md"
if (-not $Story -and -not $AllDone) { Write-Host "say which: -Story <id> or -AllDone" -ForegroundColor Yellow; exit 2 }
if (-not (Test-Path -LiteralPath $tasksFile)) { Write-Host "archive-tasks: moved=0 (no TASKS.md)"; exit 0 }

# which stories are DONE (only those may be archived)
$done = @{}
if (Test-Path -LiteralPath $storiesFile) {
  foreach ($ln in [System.IO.File]::ReadAllLines($storiesFile)) {
    if ($ln -match '^#{1,6}\s' -and $ln -match '<!--\s*Status:\s*DONE\b' -and $ln -match '\b(S\d+[A-Za-z0-9._-]*)\b') { $done[$Matches[1]] = $true }
  }
}
$targets = if ($AllDone) { @($done.Keys) } else { @($Story) }
if (-not $AllDone -and -not $done.ContainsKey($Story)) { Write-Host "archive-tasks: moved=0 (story $Story is not marked DONE - its tasks are still live)"; exit 0 }

$raw = [System.IO.File]::ReadAllText($tasksFile)
$eol = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = @($raw -split "`r?`n")
$out = New-Object System.Collections.Generic.List[string]
$archive = @{}                      # story -> list of lines to append
$moved = 0; $bytes = 0

function Get-TaskCommit([string]$id) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue) -or -not (Test-Path (Join-Path $proj ".git"))) { return "" }
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { return (& git -C $proj log -1 --format=%h -E --grep ("^" + [regex]::Escape($id) + ":") 2>$null | Out-String).Trim() }
  catch { return "" } finally { $ErrorActionPreference = $prevEap }
}

$i = 0
while ($i -lt $lines.Count) {
  $ln = $lines[$i]
  $hm = [regex]::Match($ln, '^###\s*\[x\]\s*([A-Za-z0-9._-]+)')
  $sm = [regex]::Match($ln, '\(Story\s+([A-Za-z0-9._-]+)\)')
  if (-not ($hm.Success -and $sm.Success -and ($targets -contains $sm.Groups[1].Value) -and $done.ContainsKey($sm.Groups[1].Value))) {
    $out.Add($ln); $i++; continue
  }
  # a ticked task of a DONE target story: collect its body (up to the next heading of level 1-3)
  $story = $sm.Groups[1].Value; $id = $hm.Groups[1].Value
  # The body runs to the next heading of level 1-3 - but a '# comment' line INSIDE a fenced code block is
  # not a heading, and cutting there would split the task in two.
  $j = $i + 1; $body = New-Object System.Collections.Generic.List[string]; $inFence = $false
  while ($j -lt $lines.Count) {
    if ($lines[$j] -match '^\s*(```|~~~)') { $inFence = -not $inFence }
    elseif (-not $inFence -and $lines[$j] -match '^#{1,3}\s') { break }
    $body.Add($lines[$j]); $j++
  }
  $real = @($body | Where-Object { $_.Trim() })
  if ($real.Count -eq 0 -or ($real.Count -eq 1 -and $real[0] -match '^\s*-\s*archived:')) {
    $out.Add($ln); foreach ($b in $body) { $out.Add($b) }       # nothing to move (already a stub)
    $i = $j; continue
  }
  if (-not $archive.ContainsKey($story)) { $archive[$story] = New-Object System.Collections.Generic.List[string] }
  # The archive is appended BEFORE TASKS.md is rewritten (losing a body is worse than keeping two copies).
  # If an earlier run died between the two writes, this task's body is already in the archive: do not
  # append it a second time, just finish the job by stubbing TASKS.md.
  $afPath = Join-Path (Join-Path $docs "archive") "TASKS-$story.md"
  $alreadyArchived = (Test-Path -LiteralPath $afPath) -and ([System.IO.File]::ReadAllText($afPath) -replace "`r`n", "`n").Contains("`n" + $ln.TrimEnd() + "`n")
  if (-not $alreadyArchived) {
    $archive[$story].Add($ln)
    foreach ($b in $body) { $archive[$story].Add($b) }
    if ($body.Count -eq 0 -or $body[$body.Count - 1].Trim()) { $archive[$story].Add("") }
  }
  $c = Get-TaskCommit $id
  $out.Add($ln)
  $out.Add("- archived: docs/archive/TASKS-$story.md" + $(if ($c) { " (commit $c)" } else { "" }))
  $out.Add("")
  $moved++; $bytes += (($body -join "`n").Length)
  $i = $j
}

if ($moved -eq 0) { Write-Host "archive-tasks: moved=0 (nothing to archive)"; exit 0 }
if ($DryRun) {
  Write-Host ("archive-tasks: WOULD move {0} task bod(y/ies), about {1} KB, for: {2} (dry run - nothing changed)" -f $moved, [math]::Round($bytes / 1KB), (($archive.Keys | Sort-Object) -join ', '))
  exit 0
}
$enc = New-Object System.Text.UTF8Encoding($false)
$archDir = Join-Path $docs "archive"
if (-not (Test-Path $archDir)) { New-Item -ItemType Directory -Path $archDir -Force | Out-Null }
foreach ($s in $archive.Keys) {
  if ($archive[$s].Count -eq 0) { continue }                  # everything for this story was already archived
  $af = Join-Path $archDir "TASKS-$s.md"
  $head = ""
  if (-not (Test-Path -LiteralPath $af)) {
    $head = "# Archived tasks - story $s`n<!-- Task bodies moved out of docs/TASKS.md by archive-tasks.ps1 when the story closed. The task HEADINGS`n     (and their [x]) are still in TASKS.md; this file is the record of what each task asked for. Not indexed. -->`n`n"
  }
  [System.IO.File]::AppendAllText($af, (($head + (($archive[$s]) -join "`n") + "`n") -replace "`r?`n", $eol), $enc)
}
[System.IO.File]::WriteAllText($tasksFile, ($out -join $eol), $enc)
Write-Host ("archive-tasks: moved={0} bytes={1} stories={2}" -f $moved, $bytes, (($archive.Keys | Sort-Object) -join ','))
exit 0
