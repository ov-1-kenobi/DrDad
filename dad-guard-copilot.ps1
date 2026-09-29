# dad-guard-copilot.ps1 - the Stop hook adapter for GitHub Copilot CLI.
#
# Why this exists: dad-guard.ps1's Block() emits BOTH shapes on purpose - the JSON decision on stdout
# AND exit code 2 + stderr - so whichever a harness honors, the message lands. Claude Code honors
# exit 2. Copilot CLI does NOT: measured on Copilot CLI 1.0.89 (2026-09-29), its Stop hook
#
#   exit 2 alone              -> IGNORED, the turn ends anyway
#   {"decision":"block"} + exit 0 -> BLOCKS, and the retry arrives with stop_hook_active=true
#   {"decision":"block"} + exit 2 -> IGNORED (a nonzero exit is treated as "the hook errored",
#                                    and stdout is discarded with it)
#
# That last line is the trap: dad-guard.ps1 already writes the exact JSON Copilot wants, so wiring it
# to Copilot directly LOOKS correct and silently does nothing - the close-out gates go back to being
# model-optional, with no error to say so. This adapter runs dad-guard.ps1 unchanged, keeps its JSON
# verdict, and re-emits it with exit 0 so Copilot honors the block.
#
# dad-guard.ps1 stays the single source of truth: all the project detection, the git diff, the
# stop_hook_active retry release and the fail-open policy live there, not here.
#
# Wired automatically by install.cmd -CopilotCli (writes %USERPROFILE%\.copilot\hooks\dad.json).
# You rarely run it by hand; to see the underlying verdict use: dad-guard.cmd -Check

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing.
# These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param([switch]$Check)
$ErrorActionPreference = "Stop"

$guard = Join-Path $PSScriptRoot "dad-guard.ps1"

# -Check is a passthrough so the adapter is testable and a human can ask "would this block?" without
# having to know the adapter exists.
if ($Check) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check
  exit $LASTEXITCODE
}

# Fail OPEN, exactly like dad-guard.ps1: a guard that blocks on its own bugs is worse than the problem
# it solves. Every failure path below ends in "allow the stop".
if (-not (Test-Path -LiteralPath $guard)) { exit 0 }

$raw = ""
try { $raw = [Console]::In.ReadToEnd() } catch { }

$tmpIn = $null
try {
  # Hand dad-guard.ps1 the ORIGINAL stdin verbatim. Copilot's Stop payload already carries the
  # snake_case fields dad-guard.ps1 reads (session_id, cwd, transcript_path, stop_hook_active), so no
  # translation is needed - only the exit code differs. A temp file rather than a pipe because
  # PS 5.1's `echo x | powershell -File` mangles payloads containing quotes.
  $tmpIn = [System.IO.Path]::GetTempFileName()
  [System.IO.File]::WriteAllText($tmpIn, $raw, (New-Object System.Text.UTF8Encoding($false)))

  $out = & cmd /c "powershell -NoProfile -ExecutionPolicy Bypass -File `"$guard`" < `"$tmpIn`" 2>nul"
  $code = $LASTEXITCODE
  $stdout = ($out | Out-String).Trim()

  # dad-guard.ps1 exits 2 to mean BLOCK. Re-emit its JSON verdict with exit 0, which is the only
  # combination Copilot CLI honors. If it blocked but produced no parsable JSON, synthesize one -
  # otherwise the block would evaporate.
  if ($code -eq 2) {
    $json = ""
    if ($stdout -match '\{.*\}') {
      $candidate = $Matches[0]
      try {
        $parsed = $candidate | ConvertFrom-Json
        if ($parsed.decision -eq "block") { $json = $candidate }
      } catch { }
    }
    if (-not $json) {
      $reason = if ($stdout) { $stdout } else { "dad-guard blocked this stop (see dad-guard.cmd -Check)." }
      $json = @{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress
    }
    [Console]::Out.Write($json)
    exit 0
  }
} catch {
  # fall through to allow
} finally {
  if ($tmpIn -and (Test-Path -LiteralPath $tmpIn)) { Remove-Item -LiteralPath $tmpIn -Force -ErrorAction SilentlyContinue }
}

exit 0
