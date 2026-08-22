# uninstall.ps1 - reverse what install.ps1 did to %USERPROFILE%\.claude.
# Default: remove the kit's commands/agents and restore settings.json from its .bak.
# -Full:   also remove the Ollama -cc model variants and the OLLAMA_* tuning env vars.
# Never removes: the kit folder, the npm Claude Code CLI, or the VS Code extension (manual).
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 [-Full]

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param([switch]$Full)
$ErrorActionPreference = "Stop"
$claude = Join-Path $env:USERPROFILE ".claude"

# Keep these lists in sync with install.ps1 (global\commands and global\agents).
$commands = @("scaffold","research","document","design","taskmap","proto","spec","build","assets","tidy","stories","diagram","audit","grade","retro")
$agents   = @("requirements-agent","architect-agent","taskmap-agent","dev-agent","grade-agent","qa-agent","doc-researcher","research-agent","survey-agent","ui-agent","security-agent","hygiene-agent","scribe-agent","librarian-agent")
# Retired names, so a teardown also clears anything an older kit installed. Append-only.
$commands += @("forge","scribe","blueprint","librarian","plan")
$agents   += @("planner-agent")

Write-Host "== Removing kit commands ==" -ForegroundColor Cyan
foreach ($c in $commands) {
  $p = Join-Path $claude "commands\$c.md"
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "  removed commands\$c.md" }
}

Write-Host "== Removing kit agents ==" -ForegroundColor Cyan
foreach ($a in $agents) {
  $p = Join-Path $claude "agents\$a.md"
  if (Test-Path $p) { Remove-Item $p -Force; Write-Host "  removed agents\$a.md" }
}

Write-Host "== Restoring settings.json ==" -ForegroundColor Cyan
$settings = Join-Path $claude "settings.json"
$bak = "$settings.bak"
if (Test-Path $bak) {
  Copy-Item $bak $settings -Force
  Write-Host "  restored settings.json from settings.json.bak"
} else {
  Write-Host "  no settings.json.bak found - leaving settings.json as-is." -ForegroundColor Yellow
  Write-Host "  (It redirects Claude Code to local Ollama; delete/edit it by hand to get defaults back.)" -ForegroundColor Yellow
  # But DO drop the Stop hook. Uninstalling removes dad-guard.ps1's folder from the picture; a hook left
  # pointing at a deleted script would fire on every single turn and fail.
  if (Test-Path $settings) {
    try {
      $s = Get-Content $settings -Raw | ConvertFrom-Json
      $stop = @()
      try { $stop = @($s.hooks.Stop | ForEach-Object { $_.hooks } | ForEach-Object { $_.command }) } catch { }
      if (($stop -join " ") -match 'dad-guard') {
        $s.hooks.PSObject.Properties.Remove('Stop')
        if (-not $s.hooks.PSObject.Properties.Name) { $s.PSObject.Properties.Remove('hooks') }
        [System.IO.File]::WriteAllText($settings, ($s | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  removed the dad-guard Stop hook (it would fail once this folder is gone)" -ForegroundColor Yellow
      }
    } catch { Write-Host "  could not edit settings.json - remove the 'hooks' block by hand" -ForegroundColor Yellow }
  }
}

if ($Full) {
  Write-Host "`n== -Full: removing model variants ==" -ForegroundColor Cyan
  if (Get-Command ollama -ErrorAction SilentlyContinue) {
    $list = (ollama list | Out-String)
    # Variant names come from models.json so this never goes stale.
    $mp = Join-Path $PSScriptRoot "models.json"
    $variants = if (Test-Path $mp) { (Get-Content $mp -Raw | ConvertFrom-Json).models.name } else { @() }
    foreach ($m in $variants) {
      if ($list -like "*$m*") { ollama rm $m; Write-Host "  removed $m" } else { Write-Host "  ($m not present)" }
    }
  } else { Write-Host "  ollama not found - skipped" -ForegroundColor Yellow }

  Write-Host "== -Full: removing Ollama tuning env vars ==" -ForegroundColor Cyan
  foreach ($v in @("OLLAMA_FLASH_ATTENTION","OLLAMA_KV_CACHE_TYPE","OLLAMA_KEEP_ALIVE")) {
    [Environment]::SetEnvironmentVariable($v, $null, "User"); Write-Host "  unset $v (User)"
  }
}

Write-Host "`n== DONE ==" -ForegroundColor Green
Write-Host "Manual (not removed): the kit folder, npm '@anthropic-ai/claude-code', the VS Code extension." -ForegroundColor Green
Write-Host "Restart Claude Code so it stops loading the removed commands/agents." -ForegroundColor Green
