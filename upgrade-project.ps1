# upgrade-project.ps1 - retrofit an EXISTING AD project to the current kit (deterministic, no model).
# The kit evolves; projects scaffolded earlier keep an old CLAUDE.md and miss new docs - and local models
# then improvise (root STATUS.md files, missed conventions). This closes that gap:
#   - docs\STATUS.md + docs\COMMANDS.md created from templates if missing
#   - git init + .gitignore + baseline commit if the project has no repo
#   - CLAUDE.md: KIT-OWNED sections refreshed from the current template; YOUR sections preserved
#     (kit-owned: Modes / flow, Design doc(s), Proven commands, Web / grounding, Working agreement;
#      preserved: Project name, Stack, Placeholder convention, Build / test, Human-in-loop, anything custom)
#
# Usage:  upgrade-project.ps1 [projectDir]     (default: current folder; safe to re-run)

param([string]$ProjectDir = ".")
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$templates = Join-Path $kit "templates"
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path

if (-not (Test-Path (Join-Path $proj "CLAUDE.md"))) {
  Write-Host "No CLAUDE.md in $proj - not an AD project (run new-project.ps1 to scaffold)." -ForegroundColor Yellow
  exit 1
}
$kitVer = if (Test-Path (Join-Path $kit "VERSION")) { (Get-Content (Join-Path $kit "VERSION") -Raw).Trim() } else { "unknown" }
$stampFile = Join-Path $proj ".ad-kit-version"
$was = if (Test-Path $stampFile) { (Get-Content $stampFile -Raw).Trim() } else { "pre-0.9.0 (unstamped)" }
Write-Host "Upgrading AD project at $proj" -ForegroundColor Cyan
Write-Host "  project was built with kit $was -> upgrading to $kitVer" -ForegroundColor Cyan
New-Item -ItemType Directory -Force (Join-Path $proj "docs") | Out-Null

# --- 1) Missing docs from templates (never overwrite existing) ---
foreach ($doc in @("STATUS.md","COMMANDS.md")) {
  $dst = Join-Path $proj "docs\$doc"
  if (-not (Test-Path $dst)) {
    Copy-Item (Join-Path $templates "_common\docs\$doc") $dst
    Write-Host "  added docs\$doc" -ForegroundColor Green
  }
}

# --- 2) Git safety net (same as scaffold) ---
if (Get-Command git -ErrorAction SilentlyContinue) {
  $gi = Join-Path $proj ".gitignore"
  $secretIgnores = @(".env",".env.*","!.env.example","*.pem","*.pfx","*.key","secrets/","appsettings.*.local.json")
  if (-not (Test-Path $gi)) {
    $ignore = ((@("bin/","obj/","docs/.index/",".tmp/","__pycache__/","node_modules/","*.user") + $secretIgnores) -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($gi, $ignore, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  added .gitignore" -ForegroundColor Green
  } else {
    # Append only the secret-bearing entries that are missing (never rewrite the user's file).
    $cur = Get-Content $gi -Encoding UTF8
    $missing = $secretIgnores | Where-Object { $cur -notcontains $_ }
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
    Push-Location $proj
    try {
      git init -q
      git config core.autocrlf false   # see new-project.ps1: predictable endings, no CRLF notices
      git add -A
      git -c user.name="AD-kit" -c user.email="ad-kit@local" commit -q -m "AD upgrade: baseline commit"
      Write-Host "  git: initialized + baseline commit" -ForegroundColor Green
    } catch { Write-Host "  git init/commit failed - continuing" -ForegroundColor Yellow } finally { Pop-Location }
  }
  & (Join-Path $kit "install-hooks.ps1") -ProjectDir $proj
} else { Write-Host "  git not found - skipped safety net" -ForegroundColor Yellow }

# --- 3) CLAUDE.md section refresh (kit-owned sections from the template; yours preserved) ---
# Sections are blocks starting at a '## ' header. Kit-owned blocks are matched by header PREFIX so older
# header wordings still match (e.g. '## Modes (forge / proto / spec)' -> '## Modes').
$kitPrefixes = @("## Modes", "## Design doc", "## Proven commands", "## Secrets", "## Web / grounding", "## Working agreement")

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

Write-Host ""
Write-Host "Done. Next:" -ForegroundColor Green
Write-Host "  1. Review CLAUDE.md (your Stack/Build/test sections were preserved; kit sections refreshed)."
Write-Host "  2. Reindex: run index_datasheets in a session (or reindex.cmd $proj\docs)."
Write-Host "  3. /librarian status  - populate the new docs\STATUS.md dashboard."
