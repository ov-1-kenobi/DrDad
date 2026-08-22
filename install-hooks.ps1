# install-hooks.ps1 - install the project's git pre-commit hook (secret scan).
# Called by new-project.ps1 and upgrade-project.ps1; also runnable on its own. Safe to re-run.
#
#   install-hooks.ps1 [-ProjectDir .] [-Force]
#
# The hook runs scan-secrets.ps1 over STAGED files and blocks the commit on a finding. Stopping a
# credential before it enters git history is the control that matters - history is the hard part to undo.
# Bypass for one commit (only if you are certain): git commit --no-verify

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param([string]$ProjectDir = ".", [switch]$Force)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$gitDir = Join-Path $proj ".git"

if (-not (Test-Path $gitDir)) {
  Write-Host "  hooks: no .git here - skipped (git init first)" -ForegroundColor Yellow
  return
}
$hookDir = Join-Path $gitDir "hooks"
New-Item -ItemType Directory -Force $hookDir | Out-Null
$hookPath = Join-Path $hookDir "pre-commit"

$scannerPath = Join-Path $kit "scan-secrets.ps1"

# Coexistence: never hijack another tool's hook setup. If the project already manages hooks (husky,
# pre-commit, lefthook) or has its own pre-commit, leave it and print how to add our scan to THEIR config.
$foreign = @()
if (Test-Path (Join-Path $proj ".husky"))                  { $foreign += "husky (.husky/)" }
if (Test-Path (Join-Path $proj ".pre-commit-config.yaml")) { $foreign += "pre-commit (.pre-commit-config.yaml)" }
if (Test-Path (Join-Path $proj "lefthook.yml"))            { $foreign += "lefthook (lefthook.yml)" }
if ($foreign.Count -gt 0) {
  Write-Host "  hooks: this project uses $($foreign -join ', ') - NOT touching it" -ForegroundColor Yellow
  Write-Host "         add this line as a hook step in that config instead:" -ForegroundColor Yellow
  Write-Host "         powershell -NoProfile -ExecutionPolicy Bypass -File `"$scannerPath`" -Staged" -ForegroundColor Yellow
  return
}

if ((Test-Path $hookPath) -and -not $Force) {
  $existing = Get-Content $hookPath -Raw
  if ($existing -match 'scan-secrets\.ps1') {
    # It is ours - but does the scanner it names still EXIST? A hook left pointing at a moved or renamed
    # kit fails CLOSED: every commit in the project aborts with "secret scan failed", and this branch
    # reported that as "already installed". upgrade-project calls us, so nothing ever repaired it.
    $refPath = $null
    $m = [regex]::Match($existing, '-File\s+"([^"]*scan-secrets\.ps1)"')
    if ($m.Success) { $refPath = $m.Groups[1].Value }
    if ($refPath -and (Test-Path -LiteralPath $refPath)) {
      Write-Host "  hooks: pre-commit already installed" -ForegroundColor Green
      return
    }
    Write-Host "  hooks: pre-commit pointed at a missing scanner - repointing at this kit" -ForegroundColor Yellow
    if ($refPath) { Write-Host "         was: $refPath" -ForegroundColor DarkGray }
    # fall through and rewrite
  } else {
    Write-Host "  hooks: a different pre-commit hook exists - leaving it alone (re-run with -Force to replace)" -ForegroundColor Yellow
    Write-Host "         to keep both, add to your hook: powershell -File `"$scannerPath`" -Staged" -ForegroundColor Yellow
    return
  }
}

# git for Windows runs hooks with sh, so this is a POSIX script that shells out to PowerShell.
$scanner = $scannerPath
$hook = @"
#!/bin/sh
# DAD-kit pre-commit: block credentials from entering history. Bypass (rarely): git commit --no-verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$scanner" -Staged -Quiet
status=`$?
if [ `$status -ne 0 ]; then
  echo "pre-commit: secret scan failed - commit aborted."
  exit 1
fi
exit 0
"@
# LF endings + no BOM: sh will not run a CRLF/BOM script.
[System.IO.File]::WriteAllText($hookPath, ($hook -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  hooks: pre-commit installed (secret scan)" -ForegroundColor Green
