# use-model.ps1 - switch the Claude Code session model in one command.
# Edits ANTHROPIC_MODEL in %USERPROFILE%\.claude\settings.json. Start a NEW Claude Code
# session (or reload the extension) afterward to apply.
#
# Usage:
#   .\use-model.ps1 <alias>     -> aliases + roles are in models.json (dev/coder/oss/gemma/quality/fast)
#   .\use-model.ps1 <name|id>   -> any Ollama tag, or any Anthropic model id, passes through
#
# LOCAL vs CLOUD is DERIVED from settings.json (an Ollama base-URL = local, its absence = cloud - exactly
# how install.ps1 vs install.ps1 -Cloud leave it). An alias then resolves to its Ollama tag OR its Anthropic
# 'cloud' id to match how the kit was installed. See what exists (local): sync-models.cmd -Report

param([Parameter(Mandatory)][string]$which)
$ErrorActionPreference = "Stop"

$settings = Join-Path $env:USERPROFILE ".claude\settings.json"
if (-not (Test-Path $settings)) { throw "Not found: $settings  (run install.ps1 first)" }
$json = Get-Content $settings -Raw | ConvertFrom-Json

# Mode: an Ollama base-URL means LOCAL; its absence means CLOUD.
$baseUrl = ""
try { $baseUrl = "$($json.env.ANTHROPIC_BASE_URL)" } catch { }
$cloud = -not ($baseUrl -match '11434|localhost')
$modeLabel = if ($cloud) { "cloud" } else { "local" }

# Aliases come from models.json (single source of truth); a raw tag/id also works.
$map = @{}
$manifest = Join-Path $PSScriptRoot "models.json"
if (Test-Path $manifest) {
  foreach ($m in (Get-Content $manifest -Raw | ConvertFrom-Json).models) {
    $map[$m.alias] = if ($cloud -and $m.cloud) { $m.cloud } else { $m.name }
  }
}
$model = if ($map.ContainsKey($which)) { $map[$which] } else { $which }
if (-not $map.ContainsKey($which) -and $map.Count -gt 0 -and $which -notmatch '[:\\/]') {
  Write-Host "('$which' is not an alias in models.json - passing it through as a model tag.)" -ForegroundColor DarkYellow
  Write-Host "Known aliases: $((($map.Keys | Sort-Object) -join ', '))" -ForegroundColor DarkYellow
}

$json.env.ANTHROPIC_MODEL = $model
$out = $json | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($settings, $out, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "ANTHROPIC_MODEL = $model  ($modeLabel mode)" -ForegroundColor Green
Write-Host "Start a new Claude Code session (or reload the extension) to apply." -ForegroundColor Cyan
