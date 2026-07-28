# new-project.ps1 - deterministic, STACK-AGNOSTIC AD-kit scaffolder (no local-model involved).
# Lays down the AD structure: a generic CLAUDE.md + .mcp.json (wired) + docs/ + the design doc as DRAFT.
# The KIND (general vs experience) picks WHICH design doc is created; the STACK is still decided LATE
# in /forge once the stories are implementable.
#
# Usage:
#   new-project.ps1 general                 (general software -> docs\DESIGN.md, into the CURRENT folder)
#   new-project.ps1 experience              (interactive/game/XR/sim -> docs\TEDD.md)
#   new-project.ps1 general C:\src\MyApp    (scaffold into a named folder)

param(
  [string]$Kind = "",
  [string]$ProjectDir = "."
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$templates = Join-Path $kit "templates"

$kinds = @{
  "general"    = "DESIGN.md"
  "experience" = "TEDD.md"
}

if (-not $kinds.ContainsKey($Kind)) {
  Write-Host "Specify the project KIND so the right design doc is created:" -ForegroundColor Yellow
  Write-Host "  general     -> docs\DESIGN.md  (general software project)"
  Write-Host "  experience  -> docs\TEDD.md    (interactive / game / XR / infographic / simulation)"
  Write-Host ""
  Write-Host "Usage: new-project.ps1 <general|experience> [projectDir]"
  exit 1
}
$docName = $kinds[$Kind]

if (-not (Test-Path $ProjectDir)) { New-Item -ItemType Directory -Force $ProjectDir | Out-Null }
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
Write-Host "Scaffolding a stack-agnostic AD project ($Kind) at $proj" -ForegroundColor Cyan
New-Item -ItemType Directory -Force (Join-Path $proj "docs") | Out-Null

# Generic, stack-agnostic CLAUDE.md (build/test/stack get filled during /forge's architecture step).
Copy-Item (Join-Path $templates "generic\CLAUDE.md") (Join-Path $proj "CLAUDE.md") -Force
# Record the chosen design doc path in CLAUDE.md (replace the __DESIGN_DOC__ token).
$cm = Join-Path $proj "CLAUDE.md"
$cmText = (Get-Content $cm -Raw -Encoding UTF8).Replace("__DESIGN_DOC__", "``docs/$docName``")
[System.IO.File]::WriteAllText($cm, $cmText, (New-Object System.Text.UTF8Encoding($false)))

# The design doc itself, created as Status: DRAFT from the matching template.
Copy-Item (Join-Path $templates "_common\docs\$docName") (Join-Path $proj "docs\$docName") -Force

# Provenance: record which kit version scaffolded this project, so ad-doctor can tell you when the project
# has fallen behind the kit (a stale project CLAUDE.md is what makes local models improvise).
$verFile = Join-Path $kit "VERSION"
if (Test-Path $verFile) {
  $kitVer = (Get-Content $verFile -Raw).Trim()
  [System.IO.File]::WriteAllText((Join-Path $proj ".ad-kit-version"), "$kitVer`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

# Proven-commands log (indexed; agents look up working shell syntax here and append new successes).
Copy-Item (Join-Path $templates "_common\docs\COMMANDS.md") (Join-Path $proj "docs\COMMANDS.md") -Force
# Status dashboard (indexed; librarian-agent is its only writer - done/next/blockers at a glance).
Copy-Item (Join-Path $templates "_common\docs\STATUS.md") (Join-Path $proj "docs\STATUS.md") -Force

# Shared MCP config (RAG over this project's docs).
Copy-Item (Join-Path $templates "_common\.mcp.json") (Join-Path $proj ".mcp.json") -Force
$mp = Join-Path $proj ".mcp.json"
$j = Get-Content $mp -Raw | ConvertFrom-Json
$j.mcpServers.'local-tools'.command = (Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe")
$j.mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR = (Join-Path $proj "docs")
[System.IO.File]::WriteAllText($mp, ($j | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))

# Git safety net: init + first commit, so /build can checkpoint each passing unit and a mangled file
# can be restored (git checkout) instead of hand-reconstructed.
if (Get-Command git -ErrorAction SilentlyContinue) {
  if (-not (Test-Path (Join-Path $proj ".git"))) {
    $gi = Join-Path $proj ".gitignore"
    if (-not (Test-Path $gi)) {
      # Includes the secret-bearing files that must never be committed.
      $ignore = (@("bin/","obj/","docs/.index/",".tmp/","__pycache__/","node_modules/","*.user",
                   ".env",".env.*","!.env.example","*.pem","*.pfx","*.key","secrets/",
                   "appsettings.*.local.json") -join "`r`n") + "`r`n"
      [System.IO.File]::WriteAllText($gi, $ignore, (New-Object System.Text.UTF8Encoding($false)))
    }
    Push-Location $proj
    try {
      git init -q
      # Commit files exactly as written - avoids git's "LF will be replaced by CRLF" notices (which PS 5.1
      # can escalate into errors) and keeps line endings predictable for the agents editing these files.
      git config core.autocrlf false
      git add -A
      # -c fallbacks so the commit works even if git user.name/email is not configured on this box.
      git -c user.name="AD-kit" -c user.email="ad-kit@local" commit -q -m "AD scaffold: initial commit"
      Write-Host "  git: initialized + initial commit (each /build unit will be a checkpoint)" -ForegroundColor Green
    } catch {
      Write-Host "  git: init/commit failed ($($_.Exception.Message)) - continuing without checkpoints" -ForegroundColor Yellow
    } finally { Pop-Location }
    & (Join-Path $kit "install-hooks.ps1") -ProjectDir $proj
  }
} else {
  Write-Host "  git not found - skipping the safety net (install git so /build can checkpoint + recover)" -ForegroundColor Yellow
}

Write-Host "  created: CLAUDE.md (generic), .mcp.json (docs -> $proj\docs), docs\$docName (Status: DRAFT), docs\COMMANDS.md, docs\STATUS.md" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Green
Write-Host "  1. Open $proj in VS Code (Claude Code); approve the local-tools server."
Write-Host "  2. Run /forge (design-first) or /proto (build-as-you-go) - grow docs\$docName while DRAFT."
Write-Host "     /forge decides the stack LATE and fills CLAUDE.md's build/test."
Write-Host "  3. When stories + architecture are set, /forge or /proto will offer to set Status: LOCKED."
Write-Host "  4. Optional: /blueprint shards stories into docs\TASKS.md. Then /spec or /build to implement."
