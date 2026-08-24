# dad-watch.ps1 - the watchdog. Run it in a SECOND terminal while a session works.
#
# Why this exists: three runs were lost to a subagent spiralling - 920, 947 and 1023 tool calls - and two
# of them ran for HOURS before anyone noticed. Nothing can interrupt a subagent from outside:
#   - PreToolUse hooks do not fire for a subagent's tool calls (proven: 1023 identical calls, matcher set
#     to every tool, not one block);
#   - the `tools:` frontmatter does not restrain it (it looped on a tool it does not list);
#   - while a Task is running the ORCHESTRATOR IS SUSPENDED awaiting the result, so it cannot poll, cannot
#     read a progress file, and cannot cut the call short;
#   - asking the agent to "check in" is a prose gate, and a spiralling agent is by definition one that is
#     not following instructions. That was tried on a real run and it spiralled anyway.
#
# So this does not try to prevent or interrupt anything. It converts "hours lost" into "three minutes
# lost", which is the whole of the available win: a spiral produces NO FILE WRITES, so silence on disk is
# the signal. It watches mtimes and gets loud.
#
#   dad watch                       watch the current folder, alert after 3 idle minutes
#   dad watch -IdleMinutes 2        more impatient
#   dad watch -ProjectDir C:\src\app
#
# Ctrl+C to stop. It NEVER writes to the project - a watcher that changes what it watches is useless.

# CmdletBinding so a MISTYPED parameter is an ERROR rather than a silent default.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [double]$IdleMinutes = 3,
  [int]$PollSeconds = 15,
  [switch]$NoBeep
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ProjectDir)) {
  Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red
  exit 2
}
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path

# Anything the model would legitimately write while working. Deliberately EXCLUDES the noise that changes
# without progress: git internals, build output, the RAG index, and agent worktrees.
function Get-Newest {
  $newest = [datetime]::MinValue
  $name = ""
  $count = 0
  foreach ($f in [System.IO.Directory]::EnumerateFiles($proj, "*", [System.IO.SearchOption]::AllDirectories)) {
    if ($f -match '\\(\.git|bin|obj|node_modules|\.claude)\\' -or $f -match '\\docs\\\.index\\') { continue }
    $count++
    try { $t = [System.IO.File]::GetLastWriteTimeUtc($f) } catch { continue }
    if ($t -gt $newest) { $newest = $t; $name = $f.Substring($proj.Length).TrimStart('\') }
  }
  return [pscustomobject]@{ When = $newest; What = $name; Count = $count }
}

function Alarm([double]$idleMin, [string]$lastFile, [datetime]$lastWhen) {
  Write-Host ""
  Write-Host "  ############################################################" -ForegroundColor Red
  Write-Host "  #  NOTHING HAS BEEN WRITTEN FOR $([math]::Round($idleMin,1)) MINUTES" -ForegroundColor Red
  Write-Host "  ############################################################" -ForegroundColor Red
  Write-Host "  last write : $lastFile" -ForegroundColor Yellow
  Write-Host "  at         : $($lastWhen.ToLocalTime().ToString('HH:mm:ss'))" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  If a subagent is running, it may be spiralling. A spiral writes NOTHING." -ForegroundColor Yellow
  Write-Host "  Three runs were lost this way at 920, 947 and 1023 tool calls." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  GO LOOK AT THE SESSION. If you see the same call repeating, or a" -ForegroundColor Cyan
  Write-Host "  collapsed 'agent(...)' line whose tool count keeps climbing:" -ForegroundColor Cyan
  Write-Host "    - interrupt it (Esc / Ctrl+C in the session)" -ForegroundColor Cyan
  Write-Host "    - then:  dad doc-stats -Findings     (what actually landed?)" -ForegroundColor Cyan
  Write-Host "  Nothing can break the loop for you - that is why you are being told." -ForegroundColor Cyan
  Write-Host ""
  if (-not $NoBeep) {
    try { foreach ($i in 1..3) { [Console]::Beep(880, 250); Start-Sleep -Milliseconds 120 } } catch { }
  }
}

Write-Host "== dad watch ==" -ForegroundColor Cyan
Write-Host "  project : $proj"
Write-Host "  alerts after $IdleMinutes idle minute(s); polling every $PollSeconds s"
Write-Host "  Ctrl+C to stop. This never writes to the project."
Write-Host ""

$state = Get-Newest
$lastWhen = $state.When
$lastWhat = $state.What
$lastCount = $state.Count
$alarmedAt = [datetime]::MinValue
$startedUtc = (Get-Date).ToUniversalTime()

while ($true) {
  Start-Sleep -Seconds $PollSeconds
  $now = Get-Newest
  # A file COUNT change is progress too - a new file may carry an older timestamp than an edited one.
  if ($now.When -gt $lastWhen -or $now.Count -ne $lastCount) {
    $lastWhen = $now.When; $lastWhat = $now.What; $lastCount = $now.Count
    $alarmedAt = [datetime]::MinValue                       # progress: re-arm
    Write-Host ("  [{0}] wrote {1}" -f (Get-Date -Format "HH:mm:ss"), $lastWhat) -ForegroundColor Green
    continue
  }
  # Idle. Measure from the last write, or from when this started if nothing has been written at all.
  $since = if ($lastWhen -gt [datetime]::MinValue) { $lastWhen } else { $startedUtc }
  $idle = ((Get-Date).ToUniversalTime() - $since).TotalMinutes
  if ($idle -ge $IdleMinutes) {
    # Re-alarm on each further whole interval, so it keeps nagging rather than shouting once at 3 minutes
    # and then letting the next two hours pass in silence.
    if ($alarmedAt -eq [datetime]::MinValue -or ((Get-Date).ToUniversalTime() - $alarmedAt).TotalMinutes -ge $IdleMinutes) {
      Alarm $idle $lastWhat $since
      $alarmedAt = (Get-Date).ToUniversalTime()
    }
  } else {
    Write-Host ("  [{0}] quiet {1}m" -f (Get-Date -Format "HH:mm:ss"), [math]::Round($idle,1)) -ForegroundColor DarkGray
  }
}
