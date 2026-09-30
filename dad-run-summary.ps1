# dad-run-summary.ps1 - what did this run cost? Computed from pinned sources, never narrated (DESIGN C4, R38(c)).
#
#   dad-run-summary.ps1 [-ProjectDir .] [-SinceCommit <ref>] [-StartTime <datetime>] [-TranscriptPath <file>]
#
# -SinceCommit / -StartTime / -TranscriptPath are OPTIONAL OVERRIDES that always win (C4b/C4c). They are NOT
# mandatory: a forgotten baseline falls back to .claude\.dad-session.json (written by dad-guard.ps1's Stop
# hook) and every figure is LABELLED with where its window came from.
#
# C4 INVARIANT: every printed figure names its provenance as "(source: ...)". READ-ONLY: writes no project
# state and never blocks anything. Exit 0, except exit 2 when -ProjectDir does not exist.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [string]$SinceCommit,
  [datetime]$StartTime,
  [string]$TranscriptPath
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) {
  [Console]::Error.WriteLine("dad-run-summary: -ProjectDir does not exist: $ProjectDir")
  exit 2
}
$pd = (Resolve-Path -LiteralPath $ProjectDir).ProviderPath
$inv = [Globalization.CultureInfo]::InvariantCulture
$sessionRel = ".claude\.dad-session.json"

function Emit([string]$label, [string]$text, [string]$source) {
  # source may be empty only for a not-available line whose reason is already inside $text.
  $left = "[run-summary] ${label}: $text"
  if ($source) { Write-Output ($left.PadRight(78) + " (source: $source)") } else { Write-Output $left }
}
function Fmt-Utc([datetime]$d) { return $d.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss", $inv) + "Z" }

# Run git in the project dir; returns stdout lines (array). Never throws; $script:gitExit holds the exit code.
function Invoke-Git {
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try {
    $out = @(& git -C $pd -c core.quotepath=false @args 2>$null)
    $script:gitExit = $LASTEXITCODE
    return $out
  } catch { $script:gitExit = 1; return @() } finally { $ErrorActionPreference = $old }
}

# ---- session pointer (C4b) ----
$sessionPath = Join-Path $pd $sessionRel
$session = $null; $sessionNote = ""
if (Test-Path -LiteralPath $sessionPath) {
  try { $session = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json }
  catch { $session = $null; $sessionNote = "unreadable" }
}
$sessionStart = $null
if ($session -and $session.first_seen_utc) {
  try {
    $fs = $session.first_seen_utc
    if ($fs -is [datetime]) { $sessionStart = $fs.ToUniversalTime() }   # PS 7 auto-converts ISO strings
    else {
      $sessionStart = [DateTimeOffset]::Parse([string]$fs, $inv, [Globalization.DateTimeStyles]::AssumeUniversal).UtcDateTime
    }
  } catch { $sessionStart = $null }
}

# ---- window (C4c) ----
# Start clock: -StartTime wins (caller-supplied); else the session pointer (session start); else undetermined.
$start = $null; $startSrc = ""
if ($PSBoundParameters.ContainsKey('StartTime')) {
  $start = $StartTime.ToUniversalTime(); $startSrc = "caller-supplied"
} elseif ($sessionStart) {
  $start = $sessionStart; $startSrc = "session start"
}
$now = (Get-Date).ToUniversalTime()
$startLabel = ""
if ($start) {
  if ($startSrc -eq "caller-supplied") { $startLabel = "caller-supplied -StartTime " + (Fmt-Utc $start) }
  else { $startLabel = "session start, $sessionRel first_seen_utc " + (Fmt-Utc $start) }
}
$noWindowMsg = "not available (no window: no -StartTime and no session pointer $sessionRel" + $(if ($sessionNote) { " ($sessionNote)" } else { " absent" }) + " - pass -StartTime or run under a Claude Code session with the Stop hook installed)"

# 1. wall-clock
try {
  if ($start) {
    $span = $now - $start
    if ($span.TotalSeconds -lt 0) { $span = [TimeSpan]::Zero }
    $h = [int][math]::Floor($span.TotalHours)
    $txt = if ($h -gt 0) { "{0}h {1:00}m {2:00}s" -f $h, $span.Minutes, $span.Seconds } else { "{0}m {1:00}s" -f $span.Minutes, $span.Seconds }
    Emit "wall-clock" $txt $startLabel
  } else { Emit "wall-clock" $noWindowMsg "" }
} catch { Emit "wall-clock" "not available (error: $($_.Exception.Message))" "" }

# 2. files touched (C4d): committed + uncommitted, deduplicated by path, reported SPLIT, no filters.
try {
  $isGit = $false
  $null = Invoke-Git rev-parse --is-inside-work-tree
  if ($script:gitExit -eq 0) { $isGit = $true }
  if (-not $isGit) {
    Emit "files touched" "not available (not a git work tree: $pd)" ""
  } else {
    $since = $null; $sinceLabel = ""
    if ($PSBoundParameters.ContainsKey('SinceCommit') -and $SinceCommit) {
      $r = @(Invoke-Git rev-parse --verify --quiet "$SinceCommit^{commit}")
      if ($script:gitExit -eq 0 -and $r.Count -gt 0) { $since = [string]$r[0]; $sinceLabel = "caller-supplied" }
      else { Emit "files touched" "not available (-SinceCommit does not resolve to a commit: $SinceCommit)" "" }
    } elseif ($start) {
      # Decision (C4 silent): with no -SinceCommit the range base is the last commit at or before the
      # effective window start (session first_seen_utc, or a caller -StartTime), and the label says so.
      $iso = $start.ToString("yyyy-MM-ddTHH:mm:ss", $inv) + "Z"
      $r = @(Invoke-Git rev-list -1 "--before=$iso" HEAD)
      if ($r.Count -gt 0 -and $r[0]) {
        $since = [string]$r[0]
        $sinceLabel = if ($startSrc -eq "session start") { "HEAD at session start" } else { "HEAD at -StartTime, caller-supplied" }
      } else {
        Emit "files touched" "not available (no commit at or before window start $(Fmt-Utc $start); pass -SinceCommit)" ""
      }
    } else {
      Emit "files touched" "not available (no window: no -SinceCommit, no -StartTime and no session pointer $sessionRel - pass -SinceCommit)" ""
    }
    if ($since) {
      $committed = @(Invoke-Git diff --name-only "$since..HEAD" | Where-Object { $_ })
      $tracked = @(Invoke-Git diff --name-only $since | Where-Object { $_ })
      $untracked = @(Invoke-Git ls-files --others --exclude-standard | Where-Object { $_ })
      $cset = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
      foreach ($p in $committed) { [void]$cset.Add($p) }
      $uset = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
      foreach ($p in @($tracked + $untracked)) { if (-not $cset.Contains($p)) { [void]$uset.Add($p) } }
      $short = [string](@(Invoke-Git rev-parse --short $since)[0])
      $total = $cset.Count + $uset.Count
      Emit "files touched" "$total ($($cset.Count) committed, $($uset.Count) uncommitted)" "git range $short..HEAD + working tree, $sinceLabel"
    }
  }
} catch { Emit "files touched" "not available (error: $($_.Exception.Message))" "" }

# 3. findings: count the generated [tag] lines doc-stats -Findings prints (no second findings mechanism).
try {
  $ds = Join-Path $PSScriptRoot "doc-stats.ps1"
  if (-not (Test-Path -LiteralPath $ds)) { throw "doc-stats.ps1 not found next to this script" }
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { $dsOut = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $pd -Findings 2>$null) }
  finally { $ErrorActionPreference = $old }
  $n = @($dsOut | Where-Object { ([string]$_) -match '^\s*\[[a-z]+\]' }).Count
  Emit "findings" "$n" "doc-stats -Findings"
} catch { Emit "findings" "not available (error: $($_.Exception.Message))" "" }

# 4. gate interventions (C3b + C4c).
# COUNTING RULE (C3b): the log also holds `allow` lines that are NOT interventions - the GENESIS record
# (gate gates-log, "log created; ..."), ratchet "no shrink (...)", close-unit-refusal "clean close: <Id>".
# So: blocks = decision "block" (any gate); armed = decision "allow" AND reason exactly "armed".
# Genesis and every other allow line count in NEITHER. A bare count of returned lines would over-count.
try {
  $logRel = "grades/gates-log.jsonl"
  if (-not $start) {
    Emit "gate interventions" $noWindowMsg ""
  } elseif (-not (Test-Path -LiteralPath (Join-Path $pd "grades\gates-log.jsonl"))) {
    Emit "gate interventions" "0 block, 0 armed" "gate log, $logRel - no log file present yet; window start: $startSrc"
  } else {
    $gl = Join-Path $PSScriptRoot "dad-gates-log.ps1"
    $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try { $lines = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $gl -ProjectDir $pd -Query 2>$null) }
    finally { $ErrorActionPreference = $old }
    $blocks = 0; $armed = 0
    foreach ($l in $lines) {
      $s = [string]$l
      if (-not $s.Trim()) { continue }
      try { $o = $s | ConvertFrom-Json } catch { continue }
      # Window on the parsed ts (UTC ms yyyy-MM-ddTHH:mm:ss.fffZ) in [start, now].
      $t = [datetime]::MinValue
      if (-not [datetime]::TryParseExact([string]$o.ts, "yyyy-MM-ddTHH:mm:ss.fffZ", $inv,
            ([Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal), [ref]$t)) { continue }
      if ($t -lt $start -or $t -gt $now) { continue }
      if ([string]$o.decision -eq "block") { $blocks++ }
      elseif ([string]$o.decision -eq "allow" -and [string]$o.reason -ceq "armed") { $armed++ }
    }
    Emit "gate interventions" "$blocks block, $armed armed" "gate log, $logRel; window start: $startSrc"
  }
} catch { Emit "gate interventions" "not available (error: $($_.Exception.Message))" "" }

# 5. tokens (C4a). T10.6 has not measured the transcript's token fields yet, so this prints C4a's FALLBACK
# line NAMING ITS REASON. It never parses the transcript yet, never fabricates a number.
try {
  $tp = ""; $from = ""
  if ($PSBoundParameters.ContainsKey('TranscriptPath') -and $TranscriptPath) { $tp = $TranscriptPath; $from = "-TranscriptPath" }
  elseif ($session -and $session.transcript_path) { $tp = [string]$session.transcript_path; $from = $sessionRel }
  if ($tp) {
    if (Test-Path -LiteralPath $tp -PathType Leaf) {
      Emit "tokens" "not available (transcript present but token fields not yet measured - T10.6)" ""
    } else {
      Emit "tokens" "not available (transcript path recorded but file missing: $from -> $tp)" ""
    }
  } elseif ($session) {
    Emit "tokens" "not available (session pointer $sessionRel has no transcript_path)" ""
  } elseif ($sessionNote) {
    Emit "tokens" "not available (session pointer $sessionRel unreadable)" ""
  } else {
    Emit "tokens" "not available (no session pointer: $sessionRel absent - run under a Claude Code session with the Stop hook installed)" ""
  }
} catch { Emit "tokens" "not available (error: $($_.Exception.Message))" "" }

exit 0
