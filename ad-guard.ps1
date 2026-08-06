# ad-guard.ps1 - the Stop hook. The first gate in this kit the MODEL CANNOT SKIP.
#
# Why this exists: close-unit.ps1 verifies build + tests + grade beautifully - IF something calls it.
# In a real run (mediamotor_iiif, 2026-08-05) a 7,115-line /build made 106 file edits and ZERO shell
# calls: no build, no test, no close-unit, no commit. It wrote code, then wrote tests for the code,
# then reasoned in prose about whether the tests would pass. Every gate we had was model-invoked, and
# a gate the model chooses to invoke is just prose with a filename.
#
# Claude Code runs a Stop hook itself, at end of turn, whatever the model decided to do. So this is
# where the check belongs: you do not get to end a turn with uncommitted code that was never verified.
#
# It is a NAG WITH TEETH, not a wall. The harness sets stop_hook_active on the retry, and we allow the
# stop then - so a broken model can still stop after being told, and you can never be deadlocked. What
# it guarantees is that the failure is LOUD. In run002 nobody knew until the transcript was read.
#
# Modes:
#   (stdin JSON)          hook mode - what settings.json wires up
#   ad-guard.ps1 -Check   human/test mode: print the verdict, exit 1 if it would block
#   ad-guard.ps1 -Ack     "I know, this is deliberate" - stamps .claude\.ad-verified, allows the stop
#
# Fails OPEN by design. Not an AD project, no git, no code changes, git missing, anything unexpected
# -> allow. A guard that blocks on its own bugs would be worse than the problem it solves.

param(
  [switch]$Check,
  [switch]$Ack,
  [string]$ProjectDir = ""
)

$STAMP = ".claude\.ad-verified"

function Allow($why) {
  if ($Check) { Write-Host "ad-guard: ALLOW - $why" -ForegroundColor Green }
  exit 0
}

function Block($reason) {
  if ($Check) { Write-Host "ad-guard: BLOCK - $reason" -ForegroundColor Red; exit 1 }
  # Emit both shapes on purpose: some builds read the JSON decision, some read exit code 2 + stderr.
  # Whichever this build honors, the message lands; if it honors neither we fail open, which is the
  # documented behavior anyway.
  $payload = @{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress
  [Console]::Out.Write($payload)
  [Console]::Error.Write($reason)
  exit 2
}

# --- locate the project ---------------------------------------------------------------------------
$proj = $ProjectDir
if (-not $Check -and -not $Ack) {
  # Hook mode: the harness pipes {session_id, cwd, stop_hook_active, ...} on stdin.
  $raw = ""
  try { $raw = [Console]::In.ReadToEnd() } catch { }
  if ($raw) {
    try {
      $hook = $raw | ConvertFrom-Json
      # The retry pass. Allow it, or the model can never finish. One nag per stop is the whole design.
      if ($hook.stop_hook_active) { exit 0 }
      if ($hook.cwd) { $proj = $hook.cwd }
    } catch { }
  }
}
if (-not $proj) { $proj = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $proj)) { Allow "no such directory: $proj" }
$proj = (Resolve-Path -LiteralPath $proj).Path

if ($Ack) {
  $dir = Join-Path $proj ".claude"
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText((Join-Path $proj $STAMP),
    "verified-by: ad-guard -Ack`r`n", (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "ad-guard: acknowledged - the next stop is allowed." -ForegroundColor Yellow
  exit 0
}

# --- is this even an AD project? ------------------------------------------------------------------
$isAd = (Test-Path (Join-Path $proj ".ad-kit-version")) -or
        (Test-Path (Join-Path $proj "docs\DESIGN.md")) -or
        (Test-Path (Join-Path $proj "docs\TEDD.md"))
if (-not $isAd) { Allow "not an AD project" }
if (-not (Test-Path (Join-Path $proj ".git"))) { Allow "no git repo - nothing to compare against" }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Allow "git not on PATH" }

# --- what changed? --------------------------------------------------------------------------------
# Code only. Docs churn constantly and are the agents' job; blocking on a STATUS.md edit would train
# everyone to ignore this.
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$porcelain = @()
try {
  Push-Location $proj
  $porcelain = @(git status --porcelain)
  if ($LASTEXITCODE -ne 0) { $porcelain = @() }
} catch { $porcelain = @() } finally { Pop-Location; $ErrorActionPreference = $prevEap }

$codeExt = @(".cs",".fs",".vb",".py",".ts",".tsx",".js",".jsx",".go",".rs",".java",".kt",".c",".h",
             ".cpp",".hpp",".cc",".rb",".php",".swift",".m",".mm",".scala",".sql",".csproj",".fsproj",
             ".sln",".props",".targets")
$changed = @()
foreach ($line in $porcelain) {
  if ($line.Length -lt 4) { continue }
  $p = $line.Substring(3).Trim().Trim('"')
  if ($p -match '\s->\s') { $p = ($p -split '\s->\s')[-1].Trim().Trim('"') }   # renames
  $norm = $p.Replace('/', '\')
  if ($norm -like "docs\*" -or $norm -like ".claude\*" -or $norm -like "grades\*") { continue }
  if ($norm -like "*\bin\*" -or $norm -like "*\obj\*" -or $norm -like "bin\*" -or $norm -like "obj\*") { continue }
  if ($codeExt -notcontains [System.IO.Path]::GetExtension($norm)) { continue }
  $changed += $norm
}
if ($changed.Count -eq 0) { Allow "no uncommitted code changes" }

# --- has anything verified them since? ------------------------------------------------------------
# close-unit.ps1 stamps this file when a unit closes clean (build + tests + commit all verified).
$stampPath = Join-Path $proj $STAMP
$newestEdit = ($changed | ForEach-Object {
    $f = Join-Path $proj $_
    if (Test-Path -LiteralPath $f) { (Get-Item -LiteralPath $f).LastWriteTimeUtc } else { [DateTime]::UtcNow }
  } | Sort-Object -Descending | Select-Object -First 1)
if (Test-Path $stampPath) {
  if ((Get-Item $stampPath).LastWriteTimeUtc -ge $newestEdit) { Allow "verified since the last code edit" }
}

$show = ($changed | Select-Object -First 6) -join ", "
$more = if ($changed.Count -gt 6) { " (+$($changed.Count - 6) more)" } else { "" }
Block @"
AD-kit stop guard: $($changed.Count) code file(s) are changed and UNVERIFIED - $show$more

Nothing has built or tested this. Do not end the turn here; this is exactly how a run produces
thousands of lines of edits that were never compiled. Do ONE of these now:

  1. Close the unit properly (builds, runs tests, commits, verifies):
       close-unit.cmd -Id <task id> -Title "<short title>"
  2. If you are mid-unit and just need to see where you stand, RUN THE BUILD AND TESTS from
     CLAUDE.md's "## Build / test" block and report the real output - not a prediction of it.
  3. If this edit is genuinely not meant to be verified (spike, scratch, docs-adjacent):
       ad-guard.cmd -Ack

Reasoning about whether the tests would pass is not running them.
"@
