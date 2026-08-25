# upgrade-project.ps1 - retrofit an EXISTING DAD project to the current kit (deterministic, no model).
# The kit evolves; projects scaffolded earlier keep an old CLAUDE.md and miss new docs - and local models
# then improvise (root STATUS.md files, missed conventions). This closes that gap:
#   - docs\STATUS.md + docs\RECIPES.md created from templates if missing
#   - git init + .gitignore + baseline commit if the project has no repo
#   - CLAUDE.md: KIT-OWNED sections refreshed from the current template; YOUR sections preserved
#     (kit-owned: Modes / flow, Design doc(s), Proven recipes, Web / grounding, Working agreement;
#      preserved: Project name, Stack, Placeholder convention, Build / test, Human-in-loop, anything custom)
#
# Usage:  upgrade-project.ps1 [projectDir]     (default: current folder; safe to re-run)

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param([string]$ProjectDir = ".")
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$templates = Join-Path $kit "templates"
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path

if (-not (Test-Path (Join-Path $proj "CLAUDE.md"))) {
  Write-Host "No CLAUDE.md in $proj - not a DAD project (run new-project.ps1 to scaffold)." -ForegroundColor Yellow
  exit 1
}
$kitVer = if (Test-Path (Join-Path $kit "VERSION")) { (Get-Content (Join-Path $kit "VERSION") -Raw).Trim() } else { "unknown" }
$stampFile = Join-Path $proj ".dad-kit-version"
# Pre-0.11.0 the kit had a different name and the marker files were named for it (DAD-RENAME-OK).
# Migrate rather than orphan:
# an unmigrated project reads as "never scaffolded by this kit" to dad-doctor and the stop guard.
$legacyStamp = Join-Path $proj ".ad-kit-version"
if ((Test-Path $legacyStamp) -and -not (Test-Path $stampFile)) {
  Move-Item $legacyStamp $stampFile -Force
  Write-Host "  migrated .ad-kit-version -> .dad-kit-version (pre-rename marker)" -ForegroundColor Yellow
}
$legacyVerified = Join-Path $proj ".claude\.ad-verified"
if ((Test-Path $legacyVerified) -and -not (Test-Path (Join-Path $proj ".claude\.dad-verified"))) {
  Move-Item $legacyVerified (Join-Path $proj ".claude\.dad-verified") -Force
}
$was = if (Test-Path $stampFile) { (Get-Content $stampFile -Raw).Trim() } else { "pre-0.9.0 (unstamped)" }
Write-Host "Upgrading DAD project at $proj" -ForegroundColor Cyan
Write-Host "  project was built with kit $was -> upgrading to $kitVer" -ForegroundColor Cyan
New-Item -ItemType Directory -Force (Join-Path $proj "docs") | Out-Null

# --- 1a) Migrate the old name: docs\COMMANDS.md was renamed to RECIPES.md (it clashed conceptually with
#         the kit's slash COMMANDS). Preserve the project's accumulated entries.
$oldRecipes = Join-Path $proj "docs\COMMANDS.md"
$newRecipes = Join-Path $proj "docs\RECIPES.md"
if ((Test-Path $oldRecipes) -and -not (Test-Path $newRecipes)) {
  Move-Item $oldRecipes $newRecipes
  $t = [System.IO.File]::ReadAllText($newRecipes).Replace('COMMANDS.md', 'RECIPES.md')
  [System.IO.File]::WriteAllText($newRecipes, $t, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  migrated docs\COMMANDS.md -> docs\RECIPES.md (entries preserved)" -ForegroundColor Green
}

# --- 0b) Repoint .mcp.json at THIS kit ---------------------------------------------------------
# install.ps1 only rewrites the .mcp.json files inside the kit folder; nothing rewrote a PROJECT's.
# So moving or renaming the kit left every existing project launching local-tools.exe from a path that
# may no longer exist - silently, because a dead MCP server just means no search_datasheets. Observed
# after the rename: a project still pointed at the old kit folder while the kit had moved. DAD-RENAME-OK
# Parse/serialize, never string-replace: JSON doubles backslashes.
$mcpPath = Join-Path $proj ".mcp.json"
if (Test-Path $mcpPath) {
  try {
    $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
    $j = Get-Content $mcpPath -Raw | ConvertFrom-Json
    $cur = $j.mcpServers.'local-tools'.command
    if ($cur -ne $exe) {
      $j.mcpServers.'local-tools'.command = $exe
      # The corpus stays the PROJECT's own docs - only the server binary moves.
      [System.IO.File]::WriteAllText($mcpPath, ($j | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
      Write-Host "  .mcp.json repointed at this kit's local-tools.exe" -ForegroundColor Green
      Write-Host "    was: $cur" -ForegroundColor DarkGray
    }
  } catch { Write-Host "  could not repoint .mcp.json: $($_.Exception.Message)" -ForegroundColor Yellow }
}

# --- 1) Missing docs from templates (never overwrite existing) ---
foreach ($doc in @("STATUS.md","RECIPES.md","SOURCES.md","DATASETS.md")) {
  $dst = Join-Path $proj "docs\$doc"
  if (-not (Test-Path $dst)) {
    Copy-Item (Join-Path $templates "_common\docs\$doc") $dst
    Write-Host "  added docs\$doc" -ForegroundColor Green
  }
}
New-Item -ItemType Directory -Force (Join-Path $proj "docs\sources") | Out-Null

# --- 2) Git safety net (same as scaffold) ---
if (Get-Command git -ErrorAction SilentlyContinue) {
  $gi = Join-Path $proj ".gitignore"
  $secretIgnores = @(".env",".env.*","!.env.example","*.pem","*.pfx","*.key","secrets/","appsettings.*.local.json")
  # `nul` is what a bash `2>nul` leaves behind - a reserved Windows device name, awkward to delete and
  # poisonous in a repo other Windows machines clone. Never commit one.
  $noiseIgnores2 = @("nul","NUL")
  # .claude/ holds agent worktrees - one project showed 247 of them as "changed". Never source.
  $noiseIgnores  = @(".claude/")
  if (-not (Test-Path $gi)) {
    $ignore = ((@("bin/","obj/","docs/.index/",".tmp/","__pycache__/","node_modules/","*.user",".claude/") + $secretIgnores + $noiseIgnores2) -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($gi, $ignore, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  added .gitignore" -ForegroundColor Green
  } else {
    # Append only the secret-bearing entries that are missing (never rewrite the user's file).
    $cur = Get-Content $gi -Encoding UTF8
    $missing = ($secretIgnores + $noiseIgnores + $noiseIgnores2) | Where-Object { $cur -notcontains $_ }
    if ($missing) {
      Add-Content $gi (($missing -join "`r`n"))
      Write-Host "  .gitignore: added $($missing.Count) secret-file pattern(s)" -ForegroundColor Green
    }
    if ($cur -notcontains "bin/") {
      Add-Content $gi "bin/`r`nobj/`r`ndocs/.index/"
      Write-Host "  .gitignore: added build-output patterns" -ForegroundColor Green
    }
  }
  # A .gitignore does NOT untrack files already in the index - build output committed before the upgrade
  # keeps showing up in every diff (and in close-unit's commits). Untrack it now; files stay on disk.
  if (Test-Path (Join-Path $proj ".git")) {
    Push-Location $proj
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try {
      $tracked = @(git ls-files | Where-Object { $_ -match '(^|/)(bin|obj)/' -or $_ -match '^docs/\.index/' })
      if ($tracked.Count -gt 0) {
        git rm -r --cached --quiet -- $tracked 2>$null | Out-Null
        Write-Host "  git: untracked $($tracked.Count) build-output/index file(s) (still on disk)" -ForegroundColor Green
      }
    } catch { } finally { $ErrorActionPreference = $prevEap; Pop-Location }
  }
  if (-not (Test-Path (Join-Path $proj ".git"))) {
    # Same rule as new-project.ps1: never init AROUND existing repos, and never leave a .git with no HEAD.
    # A baseline-less repo looks version-controlled to every gate while guaranteeing nothing - the ratchet
    # has no baseline, recover-lost has nothing to diff, dad-guard sees every file as untracked forever.
    $embedded = @()
    try {
      $embedded = @(Get-ChildItem $proj -Directory -Force -ErrorAction SilentlyContinue |
                    Where-Object { Test-Path (Join-Path $_.FullName ".git") } |
                    Select-Object -First 5 -ExpandProperty Name)
    } catch { }
    if ($embedded.Count -gt 0) {
      Write-Host "  git: SKIPPED - this folder contains git repositories ($($embedded -join ', ')); a repo" -ForegroundColor Yellow
      Write-Host "       wrapped around them cannot produce a usable baseline." -ForegroundColor Yellow
    } else {
      Push-Location $proj
      $gitOk = $false
      try {
        git init -q
        git config core.autocrlf false   # see new-project.ps1: predictable endings, no CRLF notices
        git add -A
        git -c user.name="DAD-kit" -c user.email="dad-kit@local" commit -q -m "DAD upgrade: baseline commit"
        $gitOk = [bool](git rev-parse --verify HEAD 2>$null)   # a commit must EXIST, not merely not-throw
        if ($gitOk) { Write-Host "  git: initialized + baseline commit" -ForegroundColor Green }
      } catch { Write-Host "  git init/commit failed" -ForegroundColor Yellow } finally { Pop-Location }
      if (-not $gitOk) {
        $dotGit = Join-Path $proj ".git"
        if (Test-Path $dotGit) {
          try { Remove-Item $dotGit -Recurse -Force; Write-Host "  git: removed the baseline-less repo it left behind" -ForegroundColor Yellow } catch { }
        }
        Write-Host "  git: continuing WITHOUT checkpoints" -ForegroundColor Yellow
      }
    }
  }
  & (Join-Path $kit "install-hooks.ps1") -ProjectDir $proj
} else { Write-Host "  git not found - skipped safety net" -ForegroundColor Yellow }

# --- 3) CLAUDE.md section refresh (kit-owned sections from the template; yours preserved) ---
# Sections are blocks starting at a '## ' header. Kit-owned blocks are matched by header PREFIX so older
# header wordings still match (e.g. '## Modes (forge / proto / spec)' -> '## Modes').
$kitPrefixes = @("## Modes", "## Design doc", "## Proven recipes", "## Secrets", "## Web / grounding", "## Working agreement")

function Split-Sections([string[]]$lines) {
  $sections = @(); $current = New-Object System.Collections.Generic.List[string]; $header = ""
  foreach ($ln in $lines) {
    if ($ln -match '^## ') {
      $sections += ,@($header, $current.ToArray()); $current = New-Object System.Collections.Generic.List[string]; $header = $ln
    } else { $current.Add($ln) }
  }
  $sections += ,@($header, $current.ToArray())
  return ,$sections
}
function Get-KitPrefix([string]$header) {
  foreach ($p in $kitPrefixes) { if ($header -like "$p*") { return $p } }
  return $null
}
# Canonical emit (idempotent): trailing blank lines trimmed, exactly one blank line between sections.
function Add-Section($out, [string]$header, [string[]]$body) {
  $n = $body.Count
  while ($n -gt 0 -and $body[$n-1] -match '^\s*$') { $n-- }
  if ($header -ne "") { $out.Add($header) | Out-Null }
  for ($i = 0; $i -lt $n; $i++) { $out.Add($body[$i]) | Out-Null }
  $out.Add("") | Out-Null
}

$cmPath = Join-Path $proj "CLAUDE.md"
$projSecs = Split-Sections (Get-Content $cmPath -Encoding UTF8)
$tmplSecs = Split-Sections (Get-Content (Join-Path $templates "generic\CLAUDE.md") -Encoding UTF8)

# Resolve the design-doc token from what the project actually has.
$docName = if (Test-Path (Join-Path $proj "docs\TEDD.md")) { "TEDD.md" } else { "DESIGN.md" }

# Index the template's kit-owned blocks by prefix.
$tmplByPrefix = @{}
foreach ($s in $tmplSecs) { $p = Get-KitPrefix $s[0]; if ($p -and -not $tmplByPrefix.ContainsKey($p)) { $tmplByPrefix[$p] = $s } }

$out = New-Object System.Collections.Generic.List[string]
$seenPrefixes = @()
foreach ($s in $projSecs) {
  $p = Get-KitPrefix $s[0]
  if ($p -and $tmplByPrefix.ContainsKey($p)) {
    $t = $tmplByPrefix[$p]; $seenPrefixes += $p
    Add-Section $out $t[0] $t[1]
    Write-Host "  CLAUDE.md: refreshed '$($t[0])'" -ForegroundColor Green
  } else {
    Add-Section $out $s[0] $s[1]
  }
}
# Append kit-owned sections the project never had (in template order).
foreach ($s in $tmplSecs) {
  $p = Get-KitPrefix $s[0]
  if ($p -and $tmplByPrefix.ContainsKey($p) -and ($seenPrefixes -notcontains $p) -and $tmplByPrefix[$p][0] -eq $s[0]) {
    Add-Section $out $s[0] $s[1]
    $seenPrefixes += $p
    Write-Host "  CLAUDE.md: added '$($s[0])'" -ForegroundColor Green
  }
}
$text = ((($out -join "`r`n") -replace '__DESIGN_DOC__', "``docs/$docName``")).TrimEnd() + "`r`n"
[System.IO.File]::WriteAllText($cmPath, $text, (New-Object System.Text.UTF8Encoding($false)))

[System.IO.File]::WriteAllText($stampFile, "$kitVer`r`n", (New-Object System.Text.UTF8Encoding($false)))

# The security-review header is deliberately NOT injected here. Adding 'Security review: REQUIRED' to a
# project already mid-build would block its very next /build - a kit upgrade must not stop work that was
# running fine. Absent = WARN by design. But silence would mean an existing web app never gets gated at
# all, so name the one-line edit and let the human choose.
# Join-Path $proj, NOT a $docs variable - upgrade-project has no such variable (doc-stats does). Reaching
# for a name that exists in a NEIGHBOURING script is the third bug of this exact shape in this release;
# it never errors, it just silently evaluates to nothing and the check quietly passes.
$designPath = Join-Path $proj "docs\$docName"
$needsSecHeader = $false
if (Test-Path -LiteralPath $designPath) {
  $needsSecHeader = -not (Select-String -Path $designPath -Pattern '^\s*Security review:' -Quiet)
}

Write-Host ""
Write-Host "Done. Next:" -ForegroundColor Green
Write-Host "  1. Review CLAUDE.md (your Stack/Build/test sections were preserved; kit sections refreshed)."
Write-Host "  2. Reindex: run index_datasheets in a session (or reindex.cmd $proj\docs)."
Write-Host "  3. /audit status  - populate the new docs\STATUS.md dashboard."
if ($needsSecHeader) {
  Write-Host ""
  Write-Host "  NOTE: docs\$docName has no 'Security review:' header, so /build will WARN and continue." -ForegroundColor Yellow
  Write-Host "        If this project handles auth, user data, uploads or is internet-facing, add this line" -ForegroundColor Yellow
  Write-Host "        under 'Status:' to make /build gate on it (then run /design to satisfy it):" -ForegroundColor Yellow
  Write-Host "          Security review: REQUIRED" -ForegroundColor Cyan
  Write-Host "        Otherwise record the decision instead, so a later reader knows it was one:" -ForegroundColor Yellow
  Write-Host "          Security review: NOT-REQUIRED (local-only tool, no auth, never deployed)" -ForegroundColor Cyan
}
