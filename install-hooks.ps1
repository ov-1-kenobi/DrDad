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
    # It is ours - but is it CURRENT, and can it still find the kit? Two ways it goes bad:
    #  - a v1 hook (before 0.60.0) names the scanner by one fixed absolute path. A hook left pointing at a
    #    moved or renamed kit fails CLOSED (every commit aborts), and one pointing at an OLD kit version that
    #    still exists on disk keeps running that old scanner forever. Both are rewritten to the v2 form.
    #  - a v2 hook resolves the kit through DAD_HOME, then its fallback path. Healthy if either resolves.
    $isV2 = ($existing -match 'dad-hook-version:\s*2\b')
    if ($isV2) {
      $fb = $null
      $m = [regex]::Match($existing, "(?m)^\s*fallback='([^']*)'")
      if ($m.Success) { $fb = $m.Groups[1].Value }
      $envKit = $env:DAD_HOME
      if (-not $envKit) { $envKit = [Environment]::GetEnvironmentVariable("DAD_HOME", "User") }
      $ok = ($envKit -and (Test-Path -LiteralPath (Join-Path $envKit "scan-secrets.ps1"))) -or
            ($fb -and (Test-Path -LiteralPath (Join-Path $fb "scan-secrets.ps1")))
      if ($ok) {
        Write-Host "  hooks: pre-commit already installed" -ForegroundColor Green
        return
      }
      Write-Host "  hooks: pre-commit could not find the kit (DAD_HOME and its fallback are both stale) - rewriting" -ForegroundColor Yellow
    } else {
      $refPath = $null
      $m = [regex]::Match($existing, '-File\s+"([^"]*scan-secrets\.ps1)"')
      if ($m.Success) { $refPath = $m.Groups[1].Value }
      if ($refPath -and (Test-Path -LiteralPath $refPath)) {
        Write-Host "  hooks: pre-commit named the kit by a fixed path - rewriting it to follow DAD_HOME" -ForegroundColor Yellow
      } else {
        Write-Host "  hooks: pre-commit pointed at a missing scanner - repointing at this kit" -ForegroundColor Yellow
      }
      if ($refPath) { Write-Host "         was: $refPath" -ForegroundColor DarkGray }
    }
    # fall through and rewrite
  } else {
    Write-Host "  hooks: a different pre-commit hook exists - leaving it alone (re-run with -Force to replace)" -ForegroundColor Yellow
    Write-Host "         to keep both, add to your hook: powershell -File `"$scannerPath`" -Staged" -ForegroundColor Yellow
    return
  }
}

# git for Windows runs hooks with sh, so this is a POSIX script that shells out to PowerShell.
# v2 (0.60.0): the kit is found at COMMIT time through DAD_HOME, which install.cmd sets for every shell, so
# the hook follows the kit when it is moved or a new version is installed - no project needs repairing.
# The fallback is the kit that wrote this hook, used only where DAD_HOME is unset (CI, a never-installed
# checkout). Forward slashes: safe inside sh single quotes and accepted by both `test -f` and powershell.
$fallback = $kit.Replace('\', '/').TrimEnd('/')
$hook = @"
#!/bin/sh
# DAD-kit pre-commit (dad-hook-version: 2): block credentials from entering history, and keep close-unit
# the only writer of a story's DONE marker. Bypass (rarely): git commit --no-verify
kit="`$DAD_HOME"
fallback='$fallback'
if [ -z "`$kit" ] || [ ! -f "`$kit/scan-secrets.ps1" ]; then kit="`$fallback"; fi
if [ ! -f "`$kit/scan-secrets.ps1" ]; then
  echo "pre-commit: DrDad kit not found (DAD_HOME unset or stale). Run the kit's install.cmd, then upgrade-project.cmd in this project. Commit aborted."
  exit 1
fi
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$kit/scan-secrets.ps1" -Staged -Quiet
status=`$?
if [ `$status -ne 0 ]; then
  echo "pre-commit: secret scan failed - commit aborted."
  exit 1
fi
if [ -f "`$kit/dad-status-guard.ps1" ]; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$kit/dad-status-guard.ps1" -Staged
  if [ `$? -ne 0 ]; then
    echo "pre-commit: story status guard refused - commit aborted."
    exit 1
  fi
fi
exit 0
"@
# LF endings + no BOM: sh will not run a CRLF/BOM script.
[System.IO.File]::WriteAllText($hookPath, ($hook -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  hooks: pre-commit installed (secret scan + story-status guard)" -ForegroundColor Green
