# dad-loopguard.ps1 - a Claude Code PreToolUse hook that breaks tight command loops and rejects shell
# redirections that HIDE their own errors.
#
# Why this exists (measured, CMS run, 2026-08-21):
#   A taskmap subagent ran
#       dir "D:\projects\Claude\projects\cms\src" 2>nul
#   NINE HUNDRED AND TWENTY times in a row and the session had to be killed by hand. Two things combined:
#
#   1. `2>nul` is cmd.exe syntax. Under the Bash tool it does not silence anything - it redirects stderr
#      into a FILE named "nul". So the model received: empty stdout, no error text, nothing. It had no way
#      to learn that the path did not exist, so it tried again. And again. (It also littered 28 zero-byte
#      files named `nul` across the project, including inside .git\objects - and `nul` is a reserved
#      device name on Windows, so those are awkward to delete.)
#   2. Nothing in the harness noticed that the same command was failing identically forever.
#
#   The agent's `tools:` frontmatter did NOT include Bash, and it ran Bash anyway - so per-agent tool
#   restriction cannot be relied on as the guard. A hook is enforced by the harness, not by the model.
#
# Contract: PreToolUse hooks receive the tool call as JSON on stdin. Exit 0 = allow. Exit 2 = BLOCK, with
# the reason on stderr for the model to read. Anything else is treated as a non-blocking error, which is
# why every failure path here exits 0: a guard that breaks the session when IT has a bug gets switched off.
#
# Usage:
#   (wired by install.ps1 as a PreToolUse hook)
#   dad-loopguard.ps1 -Check            self-test: prints what it would do for sample commands
#   dad-loopguard.ps1 -Reset            forget the streak state for every session

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param(
  [switch]$Check,
  [switch]$Reset,
  [int]$MaxRepeats = 4          # the Nth CONSECUTIVE identical command is blocked
)

$ErrorActionPreference = "Stop"

$stateDir = Join-Path $env:TEMP "dad-loopguard"

function Normalize([string]$s) {
  if (-not $s) { return "" }
  # collapse whitespace so trivial reformatting is still recognised as the same command
  return ([regex]::Replace($s.Trim(), '\s+', ' '))
}

# Returns $null to allow, or a reason string to block.
function Test-Command([string]$command, [string]$sessionId) {
  $norm = Normalize $command
  if (-not $norm) { return $null }

  # An explicit opt-out, for the rare case where hammering the same command IS the intent (polling).
  if ($norm -match 'dad-allow-repeat') { return $null }

  # --- 1) redirections that hide the error -------------------------------------------------------
  # `2>nul` / `1>nul` / `>nul` are cmd.exe. Under bash they create a FILE called nul and discard nothing;
  # under PowerShell the token is $null, not nul. Either way the model loses the error message - which is
  # the difference between "retry" and "learn". Caught on the FIRST occurrence, not the fourth: the point
  # is to stop an invisible failure from ever being invisible.
  if ($norm -match '(?i)\d?>\s*nul(\s|$|;|&|\|)') {
    return @"
BLOCKED: '2>nul' is cmd.exe syntax and this is not cmd.exe.

Under Bash it does not silence stderr - it redirects it into a FILE named 'nul' (a reserved device name
on Windows), so you get empty output and NO error message, and cannot tell a missing path from an empty
one. A real run of this kit looped the same command 920 times for exactly this reason.

Use instead:
  bash        <cmd> 2>/dev/null
  PowerShell  <cmd> 2>`$null
  existence   powershell -NoProfile -Command "Test-Path -LiteralPath 'C:\path'"   -> True/False

If you were checking whether a path exists, use Test-Path. Do not re-run this command.
"@
  }

  # --- 2) the same command, over and over ---------------------------------------------------------
  # CONSECUTIVE repeats only. A build-fix-build-fix cycle is legitimate and has edits in between; four
  # identical calls with nothing at all between them is a loop, not progress.
  if (-not $sessionId) { $sessionId = "nosession" }
  $safe = ($sessionId -replace '[^A-Za-z0-9_.-]', '_')
  if ($safe.Length -gt 64) { $safe = $safe.Substring(0, 64) }
  $stateFile = Join-Path $stateDir "$safe.json"

  $last = ""; $streak = 0
  if (Test-Path -LiteralPath $stateFile) {
    try {
      $j = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
      $last = [string]$j.last
      $streak = [int]$j.streak
    } catch { $last = ""; $streak = 0 }
  }

  if ($norm -eq $last) { $streak = $streak + 1 } else { $streak = 1 }

  if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Force $stateDir | Out-Null }
  $obj = [pscustomobject]@{ last = $norm; streak = $streak }
  [System.IO.File]::WriteAllText($stateFile, ($obj | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false)))

  if ($streak -ge $MaxRepeats) {
    # Reset so the model gets to try ONE different thing without being blocked again on the next call.
    $obj2 = [pscustomobject]@{ last = ""; streak = 0 }
    [System.IO.File]::WriteAllText($stateFile, ($obj2 | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false)))
    $short = if ($norm.Length -gt 160) { $norm.Substring(0, 160) + "..." } else { $norm }
    return @"
BLOCKED: you have now run this SAME command $streak times in a row, with nothing in between:

  $short

Repeating it will produce the same result again. The result you are getting IS the answer - read it as one:

  - empty output is a RESULT (the thing is not there, or the command wrote to stderr you discarded)
  - a path that does not exist will not exist on the next attempt either
  - if you are waiting for something, say so and stop, rather than spinning

Do something DIFFERENT: check the path with `Test-Path`, look at the parent directory, read the file you
are actually after, or report what you found and why it blocks you. If a directory you expected is
missing, that may simply be the truth of this project - say that instead of probing again.
"@
  }

  return $null
}

# ---------------- self-test ------------------------------------------------------------------------
if ($Reset) {
  if (Test-Path -LiteralPath $stateDir) { Remove-Item -LiteralPath $stateDir -Recurse -Force }
  Write-Host "dad-loopguard: state cleared"
  exit 0
}

if ($Check) {
  Write-Host "== dad-loopguard self-test ==" -ForegroundColor Cyan
  $sid = "selftest-$PID"
  $cases = @(
    @{ c = 'dir "D:\p\src" 2>nul';        expect = "BLOCK (cmd redirection)" },
    @{ c = 'ls -la src 2>/dev/null';      expect = "allow" },
    @{ c = 'dotnet build';                expect = "allow" }
  )
  foreach ($k in $cases) {
    $r = Test-Command $k.c $sid
    $got = if ($r) { "BLOCK" } else { "allow" }
    Write-Host ("  {0,-34} -> {1,-6} (expected {2})" -f $k.c, $got, $k.expect)
  }
  Write-Host "  -- the same command four times in a row --"
  for ($i = 1; $i -le 4; $i++) {
    $r = Test-Command 'ls -la nowhere' $sid
    Write-Host ("    attempt {0}: {1}" -f $i, $(if ($r) { "BLOCKED" } else { "allowed" }))
  }
  Remove-Item -LiteralPath (Join-Path $stateDir "$($sid -replace '[^A-Za-z0-9_.-]','_').json") -Force -ErrorAction SilentlyContinue
  exit 0
}

# ---------------- hook mode -----------------------------------------------------------------------
# Everything below fails OPEN. A PreToolUse hook sits in front of EVERY tool call; one that errors on its
# own bugs would make the session unusable, and the first thing anyone would do is delete it.
try {
  $raw = [Console]::In.ReadToEnd()
  if (-not $raw) { exit 0 }
  $payload = $raw | ConvertFrom-Json

  # Only shell-ish tools carry a command to loop on. Everything else is none of this guard's business.
  $toolName = [string]$payload.tool_name
  if ($toolName -and $toolName -notmatch '(?i)bash|powershell|shell|terminal') { exit 0 }

  $cmd = ""
  try { $cmd = [string]$payload.tool_input.command } catch { }
  if (-not $cmd) { exit 0 }

  $sessionId = ""
  try { $sessionId = [string]$payload.session_id } catch { }

  $reason = Test-Command $cmd $sessionId
  if ($reason) {
    [Console]::Error.WriteLine($reason)
    exit 2
  }
  exit 0
} catch {
  exit 0
}
