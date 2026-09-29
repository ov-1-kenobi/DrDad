# dad-gates-smoke.ps1 - prove the kit's gates actually FIRE, not merely that the hook files exist.
#
#   dad-gates-smoke.ps1 [-ProjectDir .]
#
# THE GAP THIS CLOSES (Story S8). A gate's presence (the script/hook file sitting on disk) is not the same
# claim as "it fires on the exact violation it says it catches". This script deliberately PROVOKES each
# real gate - 4 identical consecutive tool calls against the loop guard, a shrunk verification surface
# against ratchet/close-unit, uncommitted+unstamped code against dad-guard's Stop hook - and reports
# whether the violation was actually INTERCEPTED, whether it SILENTLY got through (SILENT-FAIL, named), or
# whether this run could not safely construct that violation (SKIP, with a reason - never a fabricated
# pass in its place).
#
# THIS TASK (T8.1) ships only the skeleton: the report/exit-code contract, wired to three stub checks that
# unconditionally return SKIP "not yet implemented". T8.2/T8.3/T8.4 fill in the real provocations one gate
# at a time - each is free to change without touching this contract.
#
# Exit code: 0 only if every gate actually provoked was INTERCEPTED (zero SILENT-FAIL, at least one
# INTERCEPTED). Non-zero if any gate is a SILENT-FAIL (named), or if every gate is SKIP (an all-SKIP run
# proved nothing and must never look like success).

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param(
  [string]$ProjectDir = "."
)
$ErrorActionPreference = "Stop"

# GUARD: -ProjectDir must exist. Resolve-Path ERRORS on a missing path but a .cmd wrapper still exits 0 if
# the error is not turned into a loud, distinct exit code - so a mistyped path would look like a project
# with nothing to smoke-test. Fail loudly instead (matches ratchet.ps1/doc-stats.ps1/source-stats.ps1).
if (-not (Test-Path -LiteralPath $ProjectDir)) {
  Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red
  exit 2
}
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path

# --- gate result contract --------------------------------------------------------------------------
# Every Test-*Gate function returns a [pscustomobject] with:
#   Result  "INTERCEPTED" | "SILENT-FAIL" | "SKIP"
#   Reason  string, required for SILENT-FAIL (names what got through) and SKIP (states why); optional
#           (but encouraged) for INTERCEPTED.
# No other shape is valid - the reporting loop below trusts these three strings exactly.

function Test-LoopGuardGate {
  # T8.2: dad-loopguard.ps1 is a KIT-level file (wired kit-wide as a PreToolUse hook in settings.json,
  # not per-project state) - resolve it as a sibling of THIS script, not inside -ProjectDir.
  $lg = Join-Path $PSScriptRoot "dad-loopguard.ps1"
  if (-not (Test-Path -LiteralPath $lg)) {
    return [pscustomobject]@{ Result = "SKIP"; Reason = "dad-loopguard.ps1 not found next to dad-gates-smoke.ps1" }
  }

  # A session id scoped to this run only, so this provocation never collides with a real Claude Code
  # session's own streak state. Reset it first in case a prior crashed run left state behind.
  $sid = "gates-smoke-$PID-$(Get-Random)"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null

  # Exact payload shape proven by test-kit.ps1's own already-passing loop-guard Test-Case
  # (test-kit.ps1:2894-2898's Invoke-Guard helper) - reused unchanged, not invented.
  function Invoke-LoopGuard($session) {
    $j = @{ session_id = $session; tool_name = "Bash"; tool_input = @{ command = "ls -la nowhere-at-all-gates-smoke" } } | ConvertTo-Json -Compress
    $j | & powershell -NoProfile -ExecutionPolicy Bypass -File $lg 2>&1 | Out-Null
    return $LASTEXITCODE
  }

  # Send the identical payload up to 4 times in a row, nothing else run in between. Blocking as early
  # as the 3rd call is fine (mirrors test-kit.ps1:2933-2939's own tolerance) - never blocking by the
  # 4th is the bug.
  # $ErrorActionPreference=Stop (set at the top of this script) turns the loop guard's own BLOCKED
  # message - written to stderr, merged in via 2>&1 - into a terminating NativeCommandError. Relax it
  # for just this provocation, same as test-kit.ps1 does around its own Invoke-Guard calls.
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $blocked = $false
  try {
    for ($i = 1; $i -le 4; $i++) {
      $code = Invoke-LoopGuard $sid
      if ($code -eq 2) { $blocked = $true; break }
    }
  } finally {
    $ErrorActionPreference = $prevEap
  }

  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null

  if ($blocked) {
    return [pscustomobject]@{ Result = "INTERCEPTED"; Reason = "4 identical consecutive Bash calls were blocked by attempt $i" }
  }
  return [pscustomobject]@{ Result = "SILENT-FAIL"; Reason = "loop-guard" }
}

function Test-RatchetCloseGate {
  # Stubbed in T8.1. T8.3 implements this by engineering a shrunk verification surface on a throwaway
  # fixture and confirming close-unit.ps1 refuses the close via ratchet.ps1 (R28).
  [pscustomobject]@{ Result = "SKIP"; Reason = "not yet implemented" }
}

function Test-DadGuardStopGate {
  # Stubbed in T8.1. T8.4 implements this by leaving uncommitted, unstamped code and confirming
  # dad-guard.ps1 blocks the Stop hook.
  [pscustomobject]@{ Result = "SKIP"; Reason = "not yet implemented" }
}

# --- run the ordered gate list ---------------------------------------------------------------------
# Order matches S8's Behavior list (loop guard, ratchet/close-unit, dad-guard Stop).
$gates = [ordered]@{
  "loop-guard"            = ${function:Test-LoopGuardGate}
  "ratchet-close-refusal" = ${function:Test-RatchetCloseGate}
  "dad-guard-stop"        = ${function:Test-DadGuardStopGate}
}

Write-Host "== dad gates-smoke: $proj ==" -ForegroundColor Cyan

$results = [ordered]@{}
foreach ($name in $gates.Keys) {
  $outcome = & $gates[$name]
  $results[$name] = $outcome
  $line = "[gates-smoke] $name`: $($outcome.Result)"
  if ($outcome.Reason) { $line += " - $($outcome.Reason)" }
  $color = switch ($outcome.Result) {
    "INTERCEPTED" { "Green" }
    "SILENT-FAIL" { "Red" }
    "SKIP"        { "Yellow" }
    default       { "Red" }
  }
  Write-Host $line -ForegroundColor $color
}

# --- compute the overall result --------------------------------------------------------------------
$silentFails  = @($results.Keys | Where-Object { $results[$_].Result -eq "SILENT-FAIL" })
$intercepted  = @($results.Keys | Where-Object { $results[$_].Result -eq "INTERCEPTED" })
$skipped      = @($results.Keys | Where-Object { $results[$_].Result -eq "SKIP" })

Write-Host ""
if ($silentFails.Count -gt 0) {
  Write-Host "[gates-smoke] SILENT-FAIL on: $($silentFails -join ', ') - a real violation got through unnoticed." -ForegroundColor Red
  exit 1
}
if ($skipped.Count -eq $gates.Count) {
  Write-Host "[gates-smoke] every gate was SKIPPED - nothing was actually verified this run." -ForegroundColor Yellow
  exit 1
}
Write-Host "[gates-smoke] all provoked gates intercepted their violation ($($intercepted.Count) intercepted, $($skipped.Count) skipped)." -ForegroundColor Green
exit 0
