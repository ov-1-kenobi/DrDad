# install.ps1 - one-shot installer for the local Claude Code kit.
# Copy this whole folder anywhere on a Windows machine, then run from inside it:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
# Safe to re-run. It detects its own location, so the folder can live anywhere.

$ErrorActionPreference = "Stop"
$root   = $PSScriptRoot
$old    = 'C:\Projects\Claude\MCP\AD-kit'            # dev-path placeholder baked into the markdown command files
$claude = Join-Path $env:USERPROFILE ".claude"

function Have($n) { [bool](Get-Command $n -ErrorAction SilentlyContinue) }
function Write-NoBom($path, $content) {
  [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host "== Prerequisites ==" -ForegroundColor Cyan
$haveOllama = Have ollama; $haveDotnet = Have dotnet; $haveNode = Have node; $haveCode = Have code
foreach ($t in @(@("ollama",$haveOllama),@("dotnet",$haveDotnet),@("node",$haveNode),@("code",$haveCode))) {
  if ($t[1]) { Write-Host "  [ok]   $($t[0])" -ForegroundColor Green }
  else       { Write-Host "  [MISS] $($t[0])" -ForegroundColor Yellow }
}
$models = ""
if ($haveOllama) { $models = (ollama list | Out-String) }
$haveNomic = $models -match "nomic-embed-text"
# Devstral is the default model; step 1 pulls it if missing.
if (-not $haveDotnet){ Write-Host "  [stop] .NET 8+ SDK required to build the server. Install it, then re-run." -ForegroundColor Yellow }

$kitVersion = if (Test-Path (Join-Path $root "VERSION")) { (Get-Content (Join-Path $root "VERSION") -Raw).Trim() } else { "unknown" }
Write-Host "`n== AD-kit $kitVersion ==" -ForegroundColor Green

Write-Host "`n== 1) Models: reconcile Ollama with models.json ==" -ForegroundColor Cyan
# One manifest drives everything (aliases, -cc variants, support models). Add a model = one JSON entry.
if ($haveOllama) {
  try { & (Join-Path $root "sync-models.ps1") }
  catch { Write-Host "  (sync-models failed: $($_.Exception.Message) - run sync-models.cmd manually)" -ForegroundColor Yellow }
} else { Write-Host "  skipped (need ollama)" -ForegroundColor Yellow }

Write-Host "`n== 3) Claude Code engine + VS Code extension ==" -ForegroundColor Cyan
if ($haveNode) { npm install -g @anthropic-ai/claude-code } else { Write-Host "  [warn] node missing - install Claude Code manually" -ForegroundColor Yellow }
if ($haveCode) { code --install-extension anthropic.claude-code } else { Write-Host "  [warn] 'code' CLI missing - install the Claude Code extension from the VS Code marketplace" -ForegroundColor Yellow }

Write-Host "`n== 4) Build the C# local-tools server ==" -ForegroundColor Cyan
if ($haveDotnet) { dotnet build (Join-Path $root "local-tools\local-tools.csproj") -c Release }
else { Write-Host "  skipped (need .NET SDK)" -ForegroundColor Yellow }

Write-Host "`n== 5) Point .mcp.json files at this folder ==" -ForegroundColor Cyan
# Edit JSON via parse/serialize (NOT string-replace): JSON doubles backslashes, and this sets the
# path deterministically, so it is correct, idempotent, and works even if the folder was moved.
$exe = Join-Path $root "local-tools\bin\Release\net8.0\local-tools.exe"
foreach ($rel in @(".mcp.json","templates\_common\.mcp.json","templates\unity\.mcp.json")) {
  $p = Join-Path $root $rel
  if (-not (Test-Path $p)) { continue }
  $j = Get-Content $p -Raw | ConvertFrom-Json
  $j.mcpServers.'local-tools'.command = $exe
  # Only the dev/root .mcp.json keeps its corpus under the kit (its own docs\); templates keep the placeholder.
  if ($rel -eq ".mcp.json") {
    $j.mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR = (Join-Path $root "docs")
  }
  Write-NoBom $p ($j | ConvertTo-Json -Depth 10)
  Write-Host "  fixed $rel"
}

Write-Host "`n== 6) Install global commands + agents to $claude ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force (Join-Path $claude "commands") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $claude "agents")   | Out-Null
Get-ChildItem (Join-Path $root "global\commands") -File | ForEach-Object {
  Write-NoBom (Join-Path $claude "commands\$($_.Name)") ((Get-Content $_.FullName -Raw -Encoding UTF8).Replace($old, $root))
}
# Agents get the SAME placeholder rewrite as commands - librarian-agent invokes doc-stats.ps1 by absolute
# path, and a plain copy would leave it pointing at the dev machine's folder.
Get-ChildItem (Join-Path $root "global\agents") -File | ForEach-Object {
  Write-NoBom (Join-Path $claude "agents\$($_.Name)") ((Get-Content $_.FullName -Raw -Encoding UTF8).Replace($old, $root))
}
Write-Host "  commands: /scaffold /forge /blueprint /proto /spec /build /assets /tidy /scribe /diagram /librarian /grade   agents: requirements/architect/planner/dev/grade/scribe/hygiene/qa/doc-researcher/librarian"

Write-Host "`n== 7) Install settings.json (Ollama redirect + offline flags) ==" -ForegroundColor Cyan
$dst = Join-Path $claude "settings.json"
if (Test-Path $dst) { Copy-Item $dst "$dst.bak" -Force; Write-Host "  existing settings.json -> settings.json.bak (MERGE if you had custom settings)" -ForegroundColor Yellow }
$s = Get-Content (Join-Path $root "settings.json") -Raw | ConvertFrom-Json
# (apiKeyHelper intentionally NOT set: ANTHROPIC_AUTH_TOKEN alone skips login; setting both
#  triggers Claude Code's "auth may not work as expected" warning every session.)
Write-NoBom $dst ($s | ConvertTo-Json -Depth 10)
Write-Host "  wrote $dst"

Write-Host "`n== 8) Tune Ollama for the GPU ==" -ForegroundColor Cyan
& (Join-Path $root "ollama-tuning.ps1")

Write-Host "`n== DONE ==" -ForegroundColor Green
Write-Host "DEFAULT model = devstral-cc (Devstral). Switch with use-model.cmd: dev / plan / fast / quality." -ForegroundColor Green
Write-Host "Next: 1) RESTART Ollama (quit from tray, reopen) so tuning + the new models are live." -ForegroundColor Green
Write-Host "      2) Open a project folder in VS Code, run /scaffold then index_datasheets." -ForegroundColor Green
Write-Host "      Optional pulls, then re-run: 'ollama pull gemma4' (deep planning), 'ollama pull qwen3-coder-next:q4_K_M' (escalation)." -ForegroundColor Cyan
