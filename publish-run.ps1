# publish-run.ps1 - copy a session's transcript + a computed state snapshot into a proving-ground repo's
# runs/ folder, secret-scanned first, and commit it locally. This is the "runs as they happen" artifact:
# each published run is dated, carries the kit version + model + the project's git HEAD, and sits next to
# the commit trail close-unit already produced. That trail - build-verified, test-verified commits per
# unit - is the actual proof of work; this adds the human-readable context around it.
#
# It NEVER pushes. Publishing to a remote is outward-facing and stays your decision - this commits locally
# and stops, telling you to review and push.
#
#   dad publish-run -ProjectDir C:\src\cms3 -Transcript C:\...\run.txt -Label s2-auth
#   dad publish-run -ProjectDir . -Transcript run.txt                 (runs repo defaults to the project)
#   dad publish-run ... -RunsRepo C:\src\dad-kit-runs                 (a SEPARATE proving-ground repo)
#   dad publish-run ... -NoCommit                                     (stage the files, do not commit)
#
# THE SECRET GATE IS NOT OPTIONAL. The transcript is scanned before it is copied; any hit ABORTS the whole
# operation. A run transcript is exactly where a pasted key or a connection string ends up, and once it is
# in a public repo's history it is compromised even if later deleted.

# CmdletBinding so a MISTYPED parameter is an ERROR rather than a silent default.
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Transcript,
  [string]$ProjectDir = ".",
  [string]$RunsRepo = "",           # defaults to the project; pass a separate proving-ground repo if you keep one
  [string]$Label = "",
  [switch]$NoCommit
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot

if (-not (Test-Path -LiteralPath $ProjectDir)) { Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red; exit 2 }
if (-not (Test-Path -LiteralPath $Transcript)) { Write-Host "ERROR: -Transcript not found: $Transcript" -ForegroundColor Red; exit 2 }
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$tx = (Resolve-Path -LiteralPath $Transcript).Path
if (-not $RunsRepo) { $RunsRepo = $proj }
if (-not (Test-Path -LiteralPath $RunsRepo)) { Write-Host "ERROR: -RunsRepo does not exist: $RunsRepo" -ForegroundColor Red; exit 2 }
$repo = (Resolve-Path -LiteralPath $RunsRepo).Path
if (-not (Test-Path (Join-Path $repo ".git"))) {
  Write-Host "ERROR: -RunsRepo is not a git repo: $repo" -ForegroundColor Red
  Write-Host "  A published run's PROOF is its commit; publish into a git repo (the project, or a separate proving-ground)." -ForegroundColor Yellow
  exit 2
}

# --- THE GATE: scan the transcript for secrets BEFORE it is copied anywhere ------------------------
Write-Host "== scanning the transcript for secrets ==" -ForegroundColor Cyan
$scan = Join-Path $kit "scan-secrets.ps1"
if (Test-Path $scan) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $scan -Path $tx
  if ($LASTEXITCODE -eq 1) {
    Write-Host ""
    Write-Host "ABORTED: the transcript contains something that looks like a secret (see above)." -ForegroundColor Red
    Write-Host "  Nothing was copied or committed. Do NOT publish this transcript as-is." -ForegroundColor Red
    Write-Host "  Redact the secret from the transcript, and if it was a REAL credential, ROTATE it - a" -ForegroundColor Yellow
    Write-Host "  secret that reached a public repo's history is compromised even after deletion." -ForegroundColor Yellow
    exit 1
  } elseif ($LASTEXITCODE -ne 0) {
    Write-Host "  scan-secrets could not run (exit $LASTEXITCODE) - refusing to publish unscanned." -ForegroundColor Red
    exit 2
  }
  Write-Host "  clean." -ForegroundColor Green
} else {
  Write-Host "  scan-secrets.ps1 not found - refusing to publish unscanned." -ForegroundColor Red
  exit 2
}

# --- destination: runs/<date>-<project>[-<label>]/ ------------------------------------------------
# NOTE: the caller passes -Label to make the folder name meaningful; the date must be supplied by the OS
# here (this is a normal script, not the workflow sandbox), so Get-Date is fine.
$stamp = (Get-Date -Format "yyyy-MM-dd")
$projName = Split-Path $proj -Leaf
$slug = ($stamp + "-" + $projName + $(if ($Label) { "-" + $Label } else { "" })) -replace '[^A-Za-z0-9._-]', '-'
$destParent = Join-Path $repo "runs"
$dest = Join-Path $destParent $slug
# if today's slug already exists, suffix -2, -3, ... rather than clobbering an earlier publish
$n = 2; $base = $dest
while (Test-Path -LiteralPath $dest) { $dest = "$base-$n"; $n++ }
New-Item -ItemType Directory -Force $dest | Out-Null

Copy-Item -LiteralPath $tx (Join-Path $dest "transcript.txt") -Force

# --- computed state snapshot (the same tools the kit trusts, not a hand summary) -------------------
$ds = Join-Path $kit "doc-stats.ps1"
if (Test-Path $ds) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $proj              *>  (Join-Path $dest "doc-stats.txt")
  & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $proj -Findings    *>  (Join-Path $dest "findings.txt")
}

# --- provenance: kit version, model, dates, the project's verified commit --------------------------
$kitVer = if (Test-Path (Join-Path $kit "VERSION")) { (Get-Content (Join-Path $kit "VERSION") -Raw).Trim() } else { "unknown" }
$model = ""
try {
  $sj = Join-Path $env:USERPROFILE ".claude\settings.json"
  if (Test-Path $sj) { $model = (Get-Content $sj -Raw | ConvertFrom-Json).env.ANTHROPIC_MODEL }
} catch { }
$projHead = ""
try {
  Push-Location $proj
  if (Test-Path (Join-Path $proj ".git")) { $projHead = (git rev-parse --short HEAD 2>$null) }
  Pop-Location
} catch { }
$meta = @(
  "run: $slug",
  "published: $((Get-Date).ToString('yyyy-MM-dd HH:mm'))",
  "project: $projName",
  "kit version: $kitVer",
  "model: $(if ($model) { $model } else { '(unknown)' })",
  "project git HEAD: $(if ($projHead) { $projHead } else { '(not a git repo / unknown)' })",
  "",
  "The project's own git log is the verified record - each close-unit commit built and tested before it",
  "landed. This folder is the human-readable context around that run.")
[System.IO.File]::WriteAllText((Join-Path $dest "meta.txt"), (($meta -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))

# --- append one line to runs/INDEX.md -------------------------------------------------------------
$index = Join-Path $destParent "INDEX.md"
if (-not (Test-Path $index)) {
  [System.IO.File]::WriteAllText($index, "# Runs`n`nEach row is a published DAD-kit run: the transcript, the computed state at publish time, and provenance.`n`n| date | project | tasks done | kit | model | folder |`n|------|---------|-----------|-----|-------|--------|`n", (New-Object System.Text.UTF8Encoding($false)))
}
$tasksLine = ""
try { $tasksLine = (Select-String -Path (Join-Path $dest "doc-stats.txt") -Pattern 'tasks\s*:\s*(.+)$' | Select-Object -First 1).Matches[0].Groups[1].Value.Trim() } catch { }
$row = "| $stamp | $projName | $(if ($tasksLine) { $tasksLine } else { '-' }) | $kitVer | $(if ($model) { $model } else { '-' }) | ``runs/$slug`` |`n"
Add-Content -LiteralPath $index -Value $row -Encoding UTF8

Write-Host "== published to $dest ==" -ForegroundColor Green
Get-ChildItem $dest | ForEach-Object { Write-Host "  runs/$slug/$($_.Name)" }

# --- commit LOCALLY (never push) ------------------------------------------------------------------
if ($NoCommit) {
  Write-Host "`n  -NoCommit: files staged in the repo, not committed. Review, then commit + push yourself." -ForegroundColor Yellow
  exit 0
}
Push-Location $repo
$prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
try {
  git add -- "runs/$slug" "runs/INDEX.md" 2>&1 | Out-Null
  git -c user.name="DAD-kit" -c user.email="dad-kit@local" commit -q -m "run: $slug (kit $kitVer)" 2>&1 | Out-Null
  $ok = [bool](git rev-parse --verify HEAD 2>$null)
} catch { $ok = $false } finally { $ErrorActionPreference = $prev; Pop-Location }
if ($ok) {
  Write-Host "`n  committed locally in $repo. Review it, then PUSH when you are ready (this never pushes for you)." -ForegroundColor Green
} else {
  Write-Host "`n  files copied but the commit did not complete - commit by hand in $repo." -ForegroundColor Yellow
}
exit 0
