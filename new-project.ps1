# new-project.ps1 - deterministic, STACK-AGNOSTIC DAD-kit scaffolder (no local-model involved).
# Lays down the DAD structure: a generic CLAUDE.md + .mcp.json (wired) + docs/ + the design doc as DRAFT.
# The KIND (general vs experience) picks WHICH design doc is created. The STACK is decided FIRST inside
# /design (step 2) - scaffold stays stack-agnostic so the choice is made with the requirements in view.
#
# Usage:
#   new-project.ps1 general                 (general software -> docs\DESIGN.md, into the CURRENT folder)
#   new-project.ps1 experience              (interactive/game/XR/sim -> docs\TEDD.md)
#   new-project.ps1 general C:\src\MyApp    (scaffold into a named folder)

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
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
Write-Host "Scaffolding a stack-agnostic DAD project ($Kind) at $proj" -ForegroundColor Cyan
New-Item -ItemType Directory -Force (Join-Path $proj "docs") | Out-Null

# Generic, stack-agnostic CLAUDE.md (build/test/stack get filled during /design's architecture step).
Copy-Item (Join-Path $templates "generic\CLAUDE.md") (Join-Path $proj "CLAUDE.md") -Force
# Record the chosen design doc path in CLAUDE.md (replace the __DESIGN_DOC__ token).
$cm = Join-Path $proj "CLAUDE.md"
$cmText = (Get-Content $cm -Raw -Encoding UTF8).Replace("__DESIGN_DOC__", "``docs/$docName``")
[System.IO.File]::WriteAllText($cm, $cmText, (New-Object System.Text.UTF8Encoding($false)))

# The design doc itself, created as Status: DRAFT from the matching template.
Copy-Item (Join-Path $templates "_common\docs\$docName") (Join-Path $proj "docs\$docName") -Force

# Provenance: record which kit version scaffolded this project, so dad-doctor can tell you when the project
# has fallen behind the kit (a stale project CLAUDE.md is what makes local models improvise).
$verFile = Join-Path $kit "VERSION"
if (Test-Path $verFile) {
  $kitVer = (Get-Content $verFile -Raw).Trim()
  [System.IO.File]::WriteAllText((Join-Path $proj ".dad-kit-version"), "$kitVer`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

# Proven-commands log (indexed; agents look up working shell syntax here and append new successes).
Copy-Item (Join-Path $templates "_common\docs\RECIPES.md") (Join-Path $proj "docs\RECIPES.md") -Force
# Status dashboard (indexed; librarian-agent is its only writer - done/next/blockers at a glance).
Copy-Item (Join-Path $templates "_common\docs\STATUS.md") (Join-Path $proj "docs\STATUS.md") -Force
# The research corpus: captured sources live here, their provenance in SOURCES.md. Both exist from the
# start so /research has somewhere to put things and source-stats has something to check.
Copy-Item (Join-Path $templates "_common\docs\SOURCES.md") (Join-Path $proj "docs\SOURCES.md") -Force
New-Item -ItemType Directory -Force (Join-Path $proj "docs\sources") | Out-Null

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
      # .claude/ holds agent worktrees - one project showed 247 of them as "changed" code.
    $ignore = (@("bin/","obj/","docs/.index/",".tmp/","__pycache__/","node_modules/","*.user",".claude/",
                   ".env",".env.*","!.env.example","*.pem","*.pfx","*.key","secrets/",
                   "appsettings.*.local.json","nul","NUL") -join "`r`n") + "`r`n"
      [System.IO.File]::WriteAllText($gi, $ignore, (New-Object System.Text.UTF8Encoding($false)))
    }
    # Refuse to init over a folder that CONTAINS other repositories. git accepts this and warns
    # ("adding embedded git repository"), the commit then fails, and what is left behind is a .git with
    # NO commits - strictly worse than no repo at all, because the ratchet has no baseline, recover-lost
    # has nothing to diff, and dad-guard sees every file as untracked forever. Observed for real when a
    # scaffold landed one level above an existing kit checkout.
    $embedded = @()
    try {
      $embedded = @(Get-ChildItem $proj -Directory -Force -ErrorAction SilentlyContinue |
                    Where-Object { Test-Path (Join-Path $_.FullName ".git") } |
                    Select-Object -First 5 -ExpandProperty Name)
    } catch { }
    if ($embedded.Count -gt 0) {
      Write-Host "  git: SKIPPED - this folder already contains git repositories ($($embedded -join ', '))." -ForegroundColor Yellow
      Write-Host "       Scaffolding a repo AROUND existing repos produces a baseline-less repo and every" -ForegroundColor Yellow
      Write-Host "       git-based gate (ratchet, recover-lost, dad-guard) then misreports. Scaffold into" -ForegroundColor Yellow
      Write-Host "       its OWN empty folder instead:  new-project.cmd $Kind C:\src\<project>" -ForegroundColor Yellow
    } else {
      Push-Location $proj
      $gitOk = $false
      try {
        git init -q
        # Commit files exactly as written - avoids git's "LF will be replaced by CRLF" notices (which PS 5.1
        # can escalate into errors) and keeps line endings predictable for the agents editing these files.
        git config core.autocrlf false
        git add -A
        # -c fallbacks so the commit works even if git user.name/email is not configured on this box.
        git -c user.name="DAD-kit" -c user.email="dad-kit@local" commit -q -m "DAD scaffold: initial commit"
        # Verify a commit EXISTS rather than trusting that the command did not throw - git reports plenty
        # of failures through its exit code and stderr without raising anything PowerShell would catch.
        $head = (git rev-parse --verify HEAD 2>$null)
        $gitOk = [bool]$head
        if ($gitOk) { Write-Host "  git: initialized + initial commit (each /build unit will be a checkpoint)" -ForegroundColor Green }
      } catch {
        Write-Host "  git: init/commit failed ($($_.Exception.Message))" -ForegroundColor Yellow
      } finally { Pop-Location }
      if (-not $gitOk) {
        # Remove the half-made repo. A .git with no HEAD makes the project LOOK version-controlled to
        # every gate while providing none of the guarantees, which is the worst of both.
        $dotGit = Join-Path $proj ".git"
        if (Test-Path $dotGit) {
          try { Remove-Item $dotGit -Recurse -Force; Write-Host "  git: removed the baseline-less repo it left behind" -ForegroundColor Yellow } catch { }
        }
        Write-Host "  git: continuing WITHOUT checkpoints - 'git init' + a first commit by hand restores them" -ForegroundColor Yellow
      }
    }
    & (Join-Path $kit "install-hooks.ps1") -ProjectDir $proj
  }
} else {
  Write-Host "  git not found - skipping the safety net (install git so /build can checkpoint + recover)" -ForegroundColor Yellow
}

Write-Host "  created: CLAUDE.md (generic), .mcp.json (docs -> $proj\docs), docs\$docName (Status: DRAFT), docs\RECIPES.md, docs\STATUS.md, docs\SOURCES.md + docs\sources\" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Green
Write-Host "  1. Open $proj in VS Code (Claude Code); approve the local-tools server."
Write-Host "  2. Run /design (design-first) or /proto (build-as-you-go) - grow docs\$docName while DRAFT."
Write-Host "     /design decides the STACK FIRST (step 2) and fills CLAUDE.md's build/test."
Write-Host "  3. When stories + architecture are set, /design or /proto will offer to set Status: LOCKED."
Write-Host "  4. Optional: /taskmap shards stories into docs\TASKS.md. Then /spec or /build to implement."
