# dad-gates-log.ps1 - append to / query the gate-decision log, grades\gates-log.jsonl (DESIGN C3, R38(b)).
#
#   APPEND: dad-gates-log.ps1 -ProjectDir . -Gate loop-guard -Decision block -Tool Bash -Reason "..." -Session s1
#   QUERY : dad-gates-log.ps1 -ProjectDir . -Query [-Gate <id>] [-Decision allow|block] [-Since <dt>] [-Last <n>] [-Count]
#
# Contract (all in docs\DESIGN.md C3):
#   C3a  file is grades\gates-log.jsonl under -ProjectDir, COMMITTED. reason pipeline, in this order:
#        collapse whitespace -> redact with scan-secrets.ps1's OWN patterns -> truncate to 300 chars.
#   C3b  one compact JSON object per line, SEVEN keys in fixed order: v, ts, gate, decision, tool, reason, session.
#   C3c  FileStream (AppendData right, NOT FileMode.Append - see the open below) + FileShare.ReadWrite, ONE Write of the whole line incl. LF; 3 retries 40/80/160ms.
#        NEVER AppendAllText (it opens FileShare.Read: a concurrent writer's line is silently lost).
#        INVARIANT: one line must be UNDER 4096 BYTES. The 300-char reason truncation is what keeps that true
#        (single-write atomicity); it may not be raised without revisiting C3c.
#   C3e  query: stdout is VERBATIM JSONL only; human notes go to STDERR; -Count prints a bare integer.
# FAILS OPEN: every error is swallowed and the script exits 0 - logging must never become a reason a gate's
# own block fails. (C3d's genesis record on a fresh log is T9.6's job, not this task's.)
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [string]$Gate = "",
  [string]$Decision = "",
  [string]$Tool = "",
  [string]$Reason = "",
  [string]$Session = "",
  [switch]$Query,
  [datetime]$Since,
  [int]$Last,
  [switch]$Count
)
$ErrorActionPreference = "Stop"

# Redact with scan-secrets.ps1's own pattern list (dot-sourced with -PatternsOnly inside a function so its
# params/variables stay out of this script's scope). Returns $null if the patterns cannot be loaded: the
# caller then writes NOTHING rather than an unredacted line (C3 invariant ii).
function Get-SecretPatterns {
  $ss = Join-Path $PSScriptRoot "scan-secrets.ps1"
  if (-not (Test-Path -LiteralPath $ss)) { return $null }
  $patterns = $null   # assigned by the dot-sourced scan-secrets.ps1
  . $ss -PatternsOnly
  return $patterns
}

function Get-CleanReason([string]$raw, $pats) {
  $r = ($raw -replace '\s+', ' ').Trim()                      # 1. collapse whitespace
  foreach ($name in $pats.Keys) { $r = [regex]::Replace($r, $pats[$name], '[REDACTED]') }   # 2. redact
  if ($r.Length -gt 300) { $r = $r.Substring(0, 300) }        # 3. truncate
  return $r
}

try {
  if ($Query) {
    $pd = $ProjectDir
    $log = Join-Path $pd "grades\gates-log.jsonl"
    $lines = @()
    if (Test-Path -LiteralPath $log) { $lines = @([System.IO.File]::ReadAllLines($log) | Where-Object { $_.Trim() }) }
    if ($lines.Count -eq 0) {
      [Console]::Error.WriteLine("dad-gates-log: no gate log yet ($log)")
      if ($Count) { Write-Output 0 }
      exit 0
    }
    $sinceUtc = $null
    if ($PSBoundParameters.ContainsKey('Since')) { $sinceUtc = $Since.ToUniversalTime() }
    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($l in $lines) {
      try { $o = $l | ConvertFrom-Json } catch { continue }
      if ($Gate -and [string]$o.gate -ne $Gate) { continue }
      if ($Decision -and [string]$o.decision -ne $Decision) { continue }
      if ($sinceUtc) {
        $t = [datetime]::MinValue
        if (-not [datetime]::TryParseExact([string]$o.ts, "yyyy-MM-ddTHH:mm:ss.fffZ",
              [Globalization.CultureInfo]::InvariantCulture,
              [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal, [ref]$t)) { continue }
        if ($t -lt $sinceUtc) { continue }
      }
      $hits.Add($l)
    }
    $out = @($hits)
    if ($PSBoundParameters.ContainsKey('Last') -and $Last -gt 0 -and $out.Count -gt $Last) {
      $out = @($out[($out.Count - $Last)..($out.Count - 1)])
    }
    if ($Count) { Write-Output $out.Count } else { foreach ($l in $out) { Write-Output $l } }
    exit 0
  }

  # ---- append ----
  if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) { exit 0 }
  $pats = Get-SecretPatterns
  if ($null -eq $pats) { exit 0 }
  $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ", [Globalization.CultureInfo]::InvariantCulture)
  $rec = New-Object System.Collections.Specialized.OrderedDictionary
  $rec.Add("v", 1)
  $rec.Add("ts", $ts)
  $rec.Add("gate", [string]$Gate)
  $rec.Add("decision", [string]$Decision)
  $rec.Add("tool", [string]$Tool)
  $rec.Add("reason", (Get-CleanReason $Reason $pats))
  $rec.Add("session", [string]$Session)
  $json = ($rec | ConvertTo-Json -Compress)
  $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($json + "`n")
  if ($bytes.Length -ge 4096) { exit 0 }   # C3c invariant; cannot happen with the 300-char cap, but never split a write

  $dir = Join-Path $ProjectDir "grades"
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $path = Join-Path $dir "gates-log.jsonl"
  $delays = @(40, 80, 160)
  for ($i = 0; $i -le $delays.Count; $i++) {
    try {
      # NOT FileMode.Append: on .NET Framework (PS 5.1) it seeks to EOF ONCE at open and then writes at a
      # private file position, so two concurrent writers overwrite each other's lines (measured: 19-23 of 24
      # lines survived). FileSystemRights.AppendData makes the OS place EVERY write atomically at the current
      # end of file, which is what concurrent appenders need.
      $fs = New-Object System.IO.FileStream($path, [IO.FileMode]::OpenOrCreate, [System.Security.AccessControl.FileSystemRights]::AppendData, [IO.FileShare]::ReadWrite, 4096, [IO.FileOptions]::None)
      try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
      break
    } catch [System.IO.IOException] {
      if ($i -ge $delays.Count) { break }
      Start-Sleep -Milliseconds ($delays[$i] + (Get-Random -Minimum 0 -Maximum ([int]($delays[$i] / 2))))
    }
  }
} catch { }
exit 0
