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
# T8.1 shipped the skeleton (the report/exit-code contract, three stub checks that unconditionally
# returned SKIP "not yet implemented"). T8.2 (loop-guard), T8.3 (ratchet-close-refusal) and T8.4
# (dad-guard-stop) filled in the three real provocations one gate at a time - all three now real.
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

  # $i is intentionally read here after the loop's `break` - PowerShell for-loop variables are not
  # scoped to the loop body, so $i still holds the attempt number that triggered $blocked = $true.
  if ($blocked) {
    return [pscustomobject]@{ Result = "INTERCEPTED"; Reason = "4 identical consecutive Bash calls were blocked by attempt $i" }
  }
  return [pscustomobject]@{ Result = "SILENT-FAIL"; Reason = "loop-guard" }
}

function Test-RatchetCloseGate {
  # T8.3: Story S8's Behavior text loosely says "the ratchet ([ratchet] finding / R36 mechanism) refuses
  # the close" - but DESIGN.md's own pinned contract C1d (doc-stats.ps1, S6/T6.1) states the [ratchet]
  # finding is WARN-ONLY and "must never block /build, close-unit, or any LOCK gate." The mechanism that
  # ACTUALLY refuses a close on a shrinking verification surface is ratchet.ps1 (R28, a different,
  # differently-scoped script - tests/requirements/contracts/story+task totals/source rows/grade-card
  # bytes/CLAUDE.md's Build:/Test: lines), invoked by close-unit.ps1 (~line 383) and blocking with
  # "[close-unit] VERIFICATION SURFACE SHRANK" (exit 1) unless -AcceptShrink is passed. This gate
  # provokes THAT mechanism - named "ratchet-close-refusal" to keep it distinct from the WARN-only
  # [ratchet] finding.
  #
  # close-unit.ps1 and ratchet.ps1 are KIT-level files, resolved as siblings of THIS script (not inside
  # -ProjectDir), same as Test-LoopGuardGate resolves dad-loopguard.ps1.
  $cu = Join-Path $PSScriptRoot "close-unit.ps1"
  $rt = Join-Path $PSScriptRoot "ratchet.ps1"
  if (-not (Test-Path -LiteralPath $cu) -or -not (Test-Path -LiteralPath $rt)) {
    return [pscustomobject]@{ Result = "SKIP"; Reason = "close-unit.ps1 / ratchet.ps1 not found next to dad-gates-smoke.ps1" }
  }
  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if (-not $gitCmd) {
    return [pscustomobject]@{ Result = "SKIP"; Reason = "git not found on PATH - cannot construct the fixture" }
  }

  # A fresh, throwaway, self-constructed, git-initialized fixture in a TEMP directory - never the real
  # -ProjectDir target (R35: never provoke a real-state-touching violation against a live target). Shape
  # mirrors test-kit.ps1's own already-passing "close-unit REFUSES to close over a shrink..." Test-Case
  # (test-kit.ps1:1833-1861) exactly - reused, not invented.
  $fixture = Join-Path $env:TEMP "dad-gates-smoke-ratchet-$PID-$(Get-Random)"
  New-Item -ItemType Directory -Force -Path (Join-Path $fixture "docs") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $fixture "tests") | Out-Null
  try {
    "# Task map`n`n## Tasks`n`n### [ ] T1.1 - a   (Story S1)`n- **Goal:** x`n`n### [ ] T1.2 - b   (Story S1)`n- **Goal:** y" |
      Set-Content (Join-Path $fixture "docs\TASKS.md") -Encoding UTF8
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content (Join-Path $fixture "docs\STORIES.md") -Encoding UTF8
    # T1.2 is the LAST open task under Story S1, so close-unit.ps1 predicts a story close and requires its
    # Test: command to report a REAL parseable count (Get-TestCount) before it will even reach ratchet's
    # own shrink check - `exit 0` alone parses to "no evidence tests ran" and refuses the close for THAT
    # reason first, never exercising ratchet.ps1 at all. `echo Total: N` is cheap and always parses.
    "# Project: t`n`n## Build / test`n- Build: ``exit 0```n- Test:  ``echo Total: 10``" | Set-Content (Join-Path $fixture "CLAUDE.md") -Encoding UTF8
    $fixtureTests = (1..10 | ForEach-Object { "    [Fact]`r`n    public void Case$_() { }" }) -join "`r`n"
    "public class T {`r`n$fixtureTests`r`n}" | Set-Content (Join-Path $fixture "tests\ApiTests.cs") -Encoding UTF8

    $prevLoc = Get-Location
    $prevEap = $ErrorActionPreference
    try {
      Set-Location $fixture
      $ErrorActionPreference = "Continue"
      git init -q
      git config core.autocrlf false
      git add -A
      git -c user.name=gates-smoke -c user.email=gates-smoke@dad commit -q -m base
    } finally {
      $ErrorActionPreference = $prevEap
      Set-Location $prevLoc
    }

    # First close is clean -> should succeed and record the ratchet baseline.
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "gates-smoke fixture" -ProjectDir $fixture -NoReindex | Out-Null
    if ($LASTEXITCODE -ne 0) {
      return [pscustomobject]@{ Result = "SKIP"; Reason = "the fixture's own first clean close failed - cannot provoke the gate from a broken baseline" }
    }

    # Now shrink the verification surface: delete most of the [Fact] markers.
    "public class T {`r`n    [Fact]`r`n    public void One() { }`r`n}" | Set-Content (Join-Path $fixture "tests\ApiTests.cs") -Encoding UTF8

    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.2 -Title "gates-smoke shrink" -ProjectDir $fixture -NoReindex 2>&1 | Out-String)
    $code = $LASTEXITCODE

    if ($code -ne 0 -and $out -match 'SHRANK') {
      return [pscustomobject]@{ Result = "INTERCEPTED"; Reason = "close-unit.ps1 refused the second close (exit $code) after 9 of 10 [Fact] markers were deleted" }
    }
    return [pscustomobject]@{ Result = "SILENT-FAIL"; Reason = "ratchet-close-refusal" }
  } finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Test-DadGuardStopGate {
  # T8.4: dad-guard.ps1 is a KIT-level file (wired kit-wide as the Stop hook in settings.json, not
  # per-project state) - resolve it as a sibling of THIS script, same as the other two gates resolve
  # their kit-level scripts.
  $dg = Join-Path $PSScriptRoot "dad-guard.ps1"
  if (-not (Test-Path -LiteralPath $dg)) {
    return [pscustomobject]@{ Result = "SKIP"; Reason = "dad-guard.ps1 not found next to dad-gates-smoke.ps1" }
  }
  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if (-not $gitCmd) {
    return [pscustomobject]@{ Result = "SKIP"; Reason = "git not found on PATH - cannot construct the fixture" }
  }

  # A fresh, throwaway, self-constructed fixture in a TEMP directory - never the real -ProjectDir target
  # (R35: never provoke a real-state-touching violation against a live target). Shape mirrors
  # test-kit.ps1's own already-passing dad-guard Test-Cases (e.g. "dad-guard BLOCKS unverified code..."
  # and "the guard names commands that can actually be RUN"): docs\DESIGN.md so dad-guard.ps1 recognizes
  # it as a DAD project, a clean committed baseline, then ONE new untracked .cs file with no
  # .claude\.dad-verified stamp at all.
  $fixture = Join-Path $env:TEMP "dad-gates-smoke-guard-$PID-$(Get-Random)"
  New-Item -ItemType Directory -Force -Path (Join-Path $fixture "docs") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $fixture "src") | Out-Null
  try {
    "# Design`n`nStatus: LOCKED" | Set-Content (Join-Path $fixture "docs\DESIGN.md") -Encoding UTF8

    $prevLoc = Get-Location
    $prevEap = $ErrorActionPreference
    try {
      Set-Location $fixture
      $ErrorActionPreference = "Continue"
      git init -q
      git config core.autocrlf false
      git add -A
      git -c user.name=gates-smoke -c user.email=gates-smoke@dad commit -q -m base
    } finally {
      $ErrorActionPreference = $prevEap
      Set-Location $prevLoc
    }

    # ONE new, UNTRACKED .cs file - never staged, never committed, never stamped as verified.
    "public class GatesSmokeThing { }" | Set-Content (Join-Path $fixture "src\GatesSmokeThing.cs") -Encoding UTF8

    & powershell -NoProfile -ExecutionPolicy Bypass -File $dg -Check -ProjectDir $fixture 2>&1 | Out-Null
    $code = $LASTEXITCODE

    if ($code -eq 1) {
      return [pscustomobject]@{ Result = "INTERCEPTED"; Reason = "dad-guard.ps1 -Check blocked (exit 1) on an uncommitted, unverified .cs file" }
    }
    return [pscustomobject]@{ Result = "SILENT-FAIL"; Reason = "dad-guard-stop" }
  } finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
  }
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
# S8 AC4/AC5: exit 0 ONLY if every gate actually provoked was INTERCEPTED (zero SILENT-FAIL, at least
# one INTERCEPTED); non-zero AND naming the gate on any SILENT-FAIL; a SKIP is reported plainly and
# never counted as a pass; an all-SKIP run proved nothing and must never look like success either.
$silentFails  = @($results.Keys | Where-Object { $results[$_].Result -eq "SILENT-FAIL" })
$intercepted  = @($results.Keys | Where-Object { $results[$_].Result -eq "INTERCEPTED" })
$skipped      = @($results.Keys | Where-Object { $results[$_].Result -eq "SKIP" })

Write-Host ""
$summary = "gates-smoke: $($intercepted.Count) intercepted, $($silentFails.Count) silent, $($skipped.Count) skipped"
if ($silentFails.Count -gt 0) {
  Write-Host "[gates-smoke] SILENT-FAIL on: $($silentFails -join ', ') - a real violation got through unnoticed." -ForegroundColor Red
  Write-Host "$summary -> FAIL (silent-fail: $($silentFails -join ', '))" -ForegroundColor Red
  exit 1
}
if ($skipped.Count -eq $gates.Count) {
  Write-Host "[gates-smoke] every gate was SKIPPED - nothing was actually verified this run." -ForegroundColor Yellow
  Write-Host "$summary -> FAIL (all gates skipped)" -ForegroundColor Yellow
  exit 1
}
Write-Host "[gates-smoke] all provoked gates intercepted their violation ($($intercepted.Count) intercepted, $($skipped.Count) skipped)." -ForegroundColor Green
Write-Host "$summary -> PASS" -ForegroundColor Green
exit 0
