# dad-guard.ps1 - the Stop hook. The first gate in this kit the MODEL CANNOT SKIP.
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
#   dad-guard.ps1 -Check   human/test mode: print the verdict, exit 1 if it would block
#   dad-guard.ps1 -Ack     "I know, this is deliberate" - stamps .claude\.dad-verified, allows the stop
#
# Fails OPEN by design. Not a DAD project, no git, no code changes, git missing, anything unexpected
# -> allow. A guard that blocks on its own bugs would be worse than the problem it solves.

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param(
  [switch]$Check,
  [switch]$Ack,
  [string]$ProjectDir = ""
)

$STAMP = ".claude\.dad-verified"
# Projects scaffolded before the AD -> DAD rename carry the old marker names (DAD-RENAME-OK).
# Accept them: a project should not fall outside the guard just because it predates a rename.
$LEGACY_STAMP  = ".claude\.ad-verified"
$LEGACY_MARKER = ".ad-kit-version"

function Allow($why) {
  if ($Check) { Write-Host "dad-guard: ALLOW - $why" -ForegroundColor Green }
  exit 0
}

function Block($reason) {
  if ($Check) { Write-Host "dad-guard: BLOCK - $reason" -ForegroundColor Red; exit 1 }
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
$sessionStart = $null
if (-not $Check -and -not $Ack) {
  # Hook mode: the harness pipes {session_id, cwd, transcript_path, stop_hook_active, ...} on stdin.
  $raw = ""
  try { $raw = [Console]::In.ReadToEnd() } catch { }
  if ($raw) {
    try {
      $hook = $raw | ConvertFrom-Json
      # The retry pass. Allow it, or the model can never finish. One nag per stop is the whole design.
      if ($hook.stop_hook_active) { exit 0 }
      if ($hook.cwd) { $proj = $hook.cwd }
      # When this session began. Used to separate what THIS run changed from what it walked into.
      # On a project that was already dirty, blaming the session for inherited mess made the guard
      # fire on turn one with "this is exactly how a run produces thousands of unverified edits" -
      # an accusation about work it had not done, which is how a guard becomes background noise.
      if ($hook.transcript_path -and (Test-Path -LiteralPath $hook.transcript_path)) {
        $sessionStart = (Get-Item -LiteralPath $hook.transcript_path).CreationTimeUtc
      }
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
    "verified-by: dad-guard -Ack`r`n", (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "dad-guard: acknowledged - the next stop is allowed." -ForegroundColor Yellow
  exit 0
}

# --- is this even a DAD project? ------------------------------------------------------------------
$isAd = (Test-Path (Join-Path $proj ".dad-kit-version")) -or
        (Test-Path (Join-Path $proj $LEGACY_MARKER)) -or
        (Test-Path (Join-Path $proj "docs\DESIGN.md")) -or
        (Test-Path (Join-Path $proj "docs\TEDD.md"))
if (-not $isAd) { Allow "not a DAD project" }
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
  # -uall, NOT the default: git COLLAPSES an untracked directory to a single "?? src/" entry, which has
  # no file extension and so slipped straight through the code-file filter. A session that created a new
  # source folder was invisible to this guard - the exact case it exists to catch.
  $porcelain = @(git status --porcelain -uall)
  if ($LASTEXITCODE -ne 0) { $porcelain = @() }
} catch { $porcelain = @() } finally { Pop-Location; $ErrorActionPreference = $prevEap }

$codeExt = @(".cs",".fs",".vb",".py",".ts",".tsx",".js",".jsx",".go",".rs",".java",".kt",".c",".h",
             ".cpp",".hpp",".cc",".rb",".php",".swift",".m",".mm",".scala",".sql",".csproj",".fsproj",
             ".sln",".props",".targets",
             # WEB/UI SOURCE. Omitting these meant that for the project types this kit is most likely to
             # be pointed at - an ASP.NET Razor Pages site, or anything ui-agent touches - the actual
             # user-facing files were NOT code as far as this guard was concerned. A turn could end with
             # every .cshtml uncommitted and unverified and the guard would say the tree was clean.
             ".cshtml",".razor",".razor.css",".html",".htm",".css",".scss",".sass",".less",
             ".vue",".svelte",".astro",
             # Runtime configuration is load-bearing: a connection string or an upload size limit in
             # appsettings.json decides whether the app works at all.
             # (matching is on GetExtension, so a compound name like .env.example would arrive as
             #  ".example" - do not list compound names here, they can never match)
             ".json",".yml",".yaml",".toml",".xml",".config",
             # Schema/migration text that is not .cs
             ".prisma",".graphql",".proto")
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
if (-not (Test-Path $stampPath)) {
  $legacy = Join-Path $proj $LEGACY_STAMP
  if (Test-Path $legacy) { $stampPath = $legacy }
}
$newestEdit = ($changed | ForEach-Object {
    $f = Join-Path $proj $_
    if (Test-Path -LiteralPath $f) { (Get-Item -LiteralPath $f).LastWriteTimeUtc } else { [DateTime]::UtcNow }
  } | Sort-Object -Descending | Select-Object -First 1)
if (Test-Path $stampPath) {
  if ((Get-Item $stampPath).LastWriteTimeUtc -ge $newestEdit) { Allow "verified since the last code edit" }
}

# --- whose mess is it? ----------------------------------------------------------------------------
# Only block on what THIS session touched. Inherited dirt is reported as context, never as the charge.
$mine = $changed
$inherited = @()
if ($sessionStart) {
  $mine = @(); $inherited = @()
  foreach ($c in $changed) {
    $f = Join-Path $proj $c
    $mtime = if (Test-Path -LiteralPath $f) { (Get-Item -LiteralPath $f).LastWriteTimeUtc } else { [DateTime]::UtcNow }
    if ($mtime -ge $sessionStart) { $mine += $c } else { $inherited += $c }
  }
  if ($mine.Count -eq 0) {
    Allow "this session changed no code ($($inherited.Count) file(s) were already dirty on arrival)"
  }
}

# Commands the model can actually RUN. The first version printed bare `close-unit.cmd`, which is not on
# PATH on a target machine: a real run was blocked, went looking for the script, could not find it, and
# ended with 36 verified-but-uncommitted files. A gate that demands an action must name it exactly.
$kitDir = $PSScriptRoot
$closeCmd = "powershell -ExecutionPolicy Bypass -File `"$kitDir\close-unit.ps1`" -Id <task id> -Title `"<short title>`""
$ackCmd   = "powershell -ExecutionPolicy Bypass -File `"$kitDir\dad-guard.ps1`" -Ack"

$show = ($mine | Select-Object -First 6) -join ", "
$more = if ($mine.Count -gt 6) { " (+$($mine.Count - 6) more)" } else { "" }
$context = if ($inherited.Count) { "`n($($inherited.Count) other file(s) were already uncommitted when this session started - not yours to answer for, but they still need closing eventually.)`n" } else { "" }
Block @"
DAD-kit stop guard: this session changed $($mine.Count) code file(s) and nothing has verified them - $show$more
$context
Do not end the turn here. Do ONE of these now:

  1. Close the unit properly (builds, runs tests, commits, verifies):
       $closeCmd
  2. If you are mid-unit and just need to see where you stand, RUN THE BUILD AND TESTS from
     CLAUDE.md's "## Build / test" block and report the real output - not a prediction of it.
  3. If this edit is genuinely not meant to be verified (spike, scratch, docs-adjacent):
       $ackCmd

Reasoning about whether the tests would pass is not running them.
"@
