# use-model.ps1 - switch the Claude Code session model in one command.
# Edits ANTHROPIC_MODEL in %USERPROFILE%\.claude\settings.json. Start a NEW Claude Code
# session (or reload the extension) afterward to apply.
#
# Usage:
#   .\use-model.ps1 <alias>     -> aliases + roles are defined in models.json (dev/coder/oss/plan/quality/fast)
#   .\use-model.ps1 <name>      -> any Ollama model/tag you have created
# See what exists:  sync-models.cmd -Report

param([Parameter(Mandatory)][string]$which)
$ErrorActionPreference = "Stop"

# Aliases come from models.json (single source of truth). Any raw Ollama tag also works.
$map = @{}
$manifest = Join-Path $PSScriptRoot "models.json"
if (Test-Path $manifest) {
  foreach ($m in (Get-Content $manifest -Raw | ConvertFrom-Json).models) { $map[$m.alias] = $m.name }
}
$model = if ($map.ContainsKey($which)) { $map[$which] } else { $which }
if (-not $map.ContainsKey($which) -and $map.Count -gt 0 -and $which -notmatch '[:\\/]') {
  Write-Host "('$which' is not an alias in models.json - passing it through as a model tag.)" -ForegroundColor DarkYellow
  Write-Host "Known aliases: $((($map.Keys | Sort-Object) -join ', '))" -ForegroundColor DarkYellow
}

$settings = Join-Path $env:USERPROFILE ".claude\settings.json"
if (-not (Test-Path $settings)) { throw "Not found: $settings  (run install.ps1 first)" }

$json = Get-Content $settings -Raw | ConvertFrom-Json
$json.env.ANTHROPIC_MODEL = $model
$out = $json | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($settings, $out, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "ANTHROPIC_MODEL = $model" -ForegroundColor Green
Write-Host "Start a new Claude Code session (or reload the extension) to apply." -ForegroundColor Cyan
