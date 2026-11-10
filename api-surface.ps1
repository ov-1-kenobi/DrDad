# api-surface.ps1 - regenerate .claude\API-SURFACE.md for a project: the exact public signatures of its own
# assemblies AND of the NuGet packages it references, read out of the compiled DLLs.
#
#   api-surface.ps1                      current folder
#   api-surface.ps1 -ProjectDir C:\src\App
#   api-surface.ps1 -Lookup TableClient  print just the signatures for one type/member (no regeneration)
#
# WHY: a dev model that cannot find a signature invents one. One project shipped 16 compile errors from
# guessed Magick.NET calls; a later task burned 4h25m and its own summary read "fixed all Azure Table
# Storage API calls to use proper generic type parameters". The answer was in the DLLs the whole time.
#
# WHERE IT LIVES (0.60.0): .claude\API-SURFACE.md - gitignored, outside docs\. It used to be written to
# docs\ so the RAG index carried it. In a real project that meant a 1.3 MB generated file (mostly the
# project's own TEST assembly) committed on every task close and chunked into the index beside the design.
# It is a build product: regenerated after every successful build by close-unit.ps1, never committed, and
# queried with -Lookup. Test projects are no longer emitted. An old docs\API-SURFACE.md is removed (and
# untracked) the next time this runs, or by upgrade-project (-Migrate).
#   api-surface.ps1 -Migrate             only move a legacy docs\API-SURFACE.md out of docs\ and out of git
#
# The reflection itself is in local-tools.exe (C#), not here: Windows PowerShell 5.1 runs on .NET
# Framework and cannot load a net8.0+ assembly at all.

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [string]$Lookup = "",
  [switch]$AnnotateFiles,
  [switch]$Migrate,
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$surface = Join-Path $proj ".claude\API-SURFACE.md"
$legacySurface = Join-Path $proj "docs\API-SURFACE.md"
# READ modes (-Lookup, -AnnotateFiles) fall back to a legacy docs\ copy when no new one exists yet, so a
# project that has not rebuilt since the kit upgrade still gets answers.
$readSurface = if ((-not (Test-Path -LiteralPath $surface)) -and (Test-Path -LiteralPath $legacySurface)) { $legacySurface } else { $surface }

# Take a legacy docs\API-SURFACE.md out of docs\ and out of git. Only a file that carries the generator's
# own header is touched - a hand-written document of the same name is left alone. Returns $true if it acted.
function Remove-LegacySurface {
  if (-not (Test-Path -LiteralPath $legacySurface -PathType Leaf)) { return $false }
  $first = (Get-Content -LiteralPath $legacySurface -TotalCount 1 -Encoding UTF8)
  if ([string]$first -notmatch '^# API surface \(generated') { return $false }
  New-Item -ItemType Directory -Force (Split-Path $surface -Parent) | Out-Null
  if (-not (Test-Path -LiteralPath $surface)) { Copy-Item -LiteralPath $legacySurface -Destination $surface -Force }
  if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
    $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try { & git -C $proj rm --cached --quiet --ignore-unmatch -- "docs/API-SURFACE.md" 2>$null | Out-Null } catch { }
    finally { $ErrorActionPreference = $prevEap }
  }
  Remove-Item -LiteralPath $legacySurface -Force
  return $true
}
# The new home must never be committed. .claude/ is in every scaffolded .gitignore; for a project whose
# .gitignore predates that, add the one narrow line rather than let `git add -A` bank a build product.
function Protect-SurfaceFromGit {
  if (-not (Get-Command git -ErrorAction SilentlyContinue) -or -not (Test-Path (Join-Path $proj ".git"))) { return }
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try {
    & git -C $proj check-ignore -q -- ".claude/API-SURFACE.md" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
      $gi = Join-Path $proj ".gitignore"
      $lead = ""
      if (Test-Path -LiteralPath $gi) { $raw = [System.IO.File]::ReadAllText($gi); if ($raw.Length -gt 0 -and $raw[$raw.Length - 1] -ne [char]10) { $lead = "`n" } }
      [System.IO.File]::AppendAllText($gi, ($lead + ".claude/API-SURFACE.md`n"), (New-Object System.Text.UTF8Encoding($false)))
    }
  } catch { } finally { $ErrorActionPreference = $prevEap }
}

if ($Migrate) {
  $did = Remove-LegacySurface
  if ($did) { Protect-SurfaceFromGit }
  if (-not $Quiet) {
    if ($did) { Write-Host "moved docs\API-SURFACE.md -> .claude\API-SURFACE.md (out of docs\ and out of git)" -ForegroundColor Green }
    else { Write-Host "no generated docs\API-SURFACE.md to move" -ForegroundColor DarkGray }
  }
  if ($did) { exit 0 } else { exit 3 }      # 3 = nothing to do (callers that only want to know)
}

# Annotate each SOLUTION type heading with the .cs file it is declared in - the one fact reflection over the
# DLLs cannot give (a compiled assembly carries no source paths), and the exact thing a model kept re-guessing
# (file name vs class name, editing the wrong file and walking it back). A grep of the source settles it; a
# partial/duplicate type lists both files. Idempotent - a heading already carrying "(in ...)" is left alone.
function Add-SourceFiles([string]$projDir, [string]$surfaceFile) {
  if (-not (Test-Path $surfaceFile)) { return }
  $srcRoot = Join-Path $projDir "src"
  if (-not (Test-Path $srcRoot)) { $srcRoot = $projDir }
  $decl = '(?m)^\s*(?:(?:public|private|internal|protected|sealed|abstract|static|partial|file)\s+)*(?:class|interface|record|struct|enum)\s+([A-Za-z_]\w*)'
  $typeToFile = @{}
  foreach ($cf in @(Get-ChildItem $srcRoot -Recurse -Filter *.cs -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' })) {
    $rel = $cf.FullName.Substring($projDir.Length).TrimStart('\')
    foreach ($m in [regex]::Matches((Get-Content $cf.FullName -Raw), $decl)) {
      $t = $m.Groups[1].Value
      if (-not $typeToFile.ContainsKey($t)) { $typeToFile[$t] = New-Object System.Collections.Generic.List[string] }
      if (-not $typeToFile[$t].Contains($rel)) { [void]$typeToFile[$t].Add($rel) }
    }
  }
  $hdr = '^' + [char]96 + '(?:class|struct|interface|enum|record) ([A-Za-z_]\w*)'
  $lines = Get-Content $surfaceFile -Encoding UTF8
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $hm = [regex]::Match($lines[$i], $hdr)
    if ($hm.Success -and $lines[$i] -notmatch '\(in ') {
      $tn = $hm.Groups[1].Value
      if ($typeToFile.ContainsKey($tn)) {
        $lines[$i] = $lines[$i].TrimEnd() + "   (in " + (($typeToFile[$tn] | Select-Object -First 2) -join ', ') + ")"
      }
    }
  }
  # LF, not CRLF: docs\*.md is `* text=auto eol=lf` per .gitattributes. Same bug class as
  # close-unit.ps1's Save-Text (fixed in commit 9be3aec) - a hardcoded `r`n here silently re-CRLFs
  # API-SURFACE.md on every regeneration, invisible to git status/diff until test-kit.ps1's raw-byte
  # line-ending check catches it. Found via self-hosting assessment, 2026-09-20.
  [System.IO.File]::WriteAllText($surfaceFile, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}

# --- annotate-only mode: (re)add source files to an existing bank without a rebuild ----------------
if ($AnnotateFiles) {
  Add-SourceFiles $proj $readSurface
  if (-not $Quiet) { Write-Host "annotated API-SURFACE.md type headings with their source files" -ForegroundColor Green }
  exit 0
}

# --- lookup mode: answer one question from the existing file, cheaply -----------------------------
if ($Lookup) {
  if (-not (Test-Path $readSurface)) {
    Write-Host "no .claude\API-SURFACE.md yet - run api-surface.cmd first (needs a successful build)" -ForegroundColor Yellow
    exit 1
  }
  $esc = [regex]::Escape($Lookup)
  $lines = Get-Content $readSurface -Encoding UTF8
  $hits = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    # A type heading: print it and its members. A member line: print it with its owning type.
    if ($lines[$i] -match ("^" + [char]96 + "(class|struct|interface|enum) .*\b$esc\b")) {
      Write-Host $lines[$i] -ForegroundColor Cyan
      for ($j = $i + 1; $j -lt $lines.Count -and $lines[$j] -match '^\s+- '; $j++) { Write-Host $lines[$j] }
      $hits++
    }
    elseif ($lines[$i] -match '^\s+- ' -and $lines[$i] -match "\b$esc\b") {
      # walk back to the owning type heading so the signature is not orphaned
      $owner = ""
      $hdr = "^" + [char]96 + "(class|struct|interface|enum) "
      for ($k = $i - 1; $k -ge 0; $k--) { if ($lines[$k] -match $hdr) { $owner = $lines[$k].Trim([char]96); break } }
      Write-Host ("{0,-46} {1}" -f $owner, $lines[$i].Trim())
      $hits++
    }
  }
  if ($hits -eq 0) { Write-Host "no match for '$Lookup' in the API surface" -ForegroundColor Yellow; exit 1 }
  exit 0
}

# --- generate ------------------------------------------------------------------------------------
$exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
if (-not (Test-Path $exe)) {
  Write-Host "local-tools.exe not built - run: dotnet build `"$kit\local-tools\local-tools.csproj`" -c Release" -ForegroundColor Yellow
  exit 1
}
# The output path is passed EXPLICITLY, so the location is this script's decision and does not depend on
# which build of local-tools.exe happens to be installed.
New-Item -ItemType Directory -Force (Split-Path $surface -Parent) | Out-Null
$out = & $exe --api-surface $proj $surface 2>&1 | Out-String
$code = $LASTEXITCODE
if (-not $Quiet) { Write-Host $out.Trim() }
if ($code -ne 0) { exit $code }

# Reflection cannot know which .cs file a type lives in - add it so every -Lookup (including close-unit's
# on a build error) shows "class Foo   (in Foo.cs)".
Add-SourceFiles $proj $surface

# Not in docs\ any more, so there is nothing to reindex. Clear out a legacy docs\ copy (it would otherwise
# sit in the index and in git, going stale), and make sure the new one cannot be committed.
if (Remove-LegacySurface) {
  if (-not $Quiet) { Write-Host "  removed the old docs\API-SURFACE.md (now .claude\API-SURFACE.md - not indexed, not committed)" -ForegroundColor Yellow }
}
Protect-SurfaceFromGit
exit 0
