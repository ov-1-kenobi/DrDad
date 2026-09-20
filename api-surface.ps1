# api-surface.ps1 - regenerate docs\API-SURFACE.md for a project: the exact public signatures of its own
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
# The file lands in docs\, so the EXISTING RAG index carries it - search_datasheets finds it with no new
# tool. Regenerated after every successful build by close-unit.ps1, so it cannot drift from the code.
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
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$surface = Join-Path $proj "docs\API-SURFACE.md"

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
  Add-SourceFiles $proj $surface
  if (-not $Quiet) { Write-Host "annotated docs\API-SURFACE.md type headings with their source files" -ForegroundColor Green }
  exit 0
}

# --- lookup mode: answer one question from the existing file, cheaply -----------------------------
if ($Lookup) {
  if (-not (Test-Path $surface)) {
    Write-Host "no docs\API-SURFACE.md yet - run api-surface.cmd first (needs a successful build)" -ForegroundColor Yellow
    exit 1
  }
  $esc = [regex]::Escape($Lookup)
  $lines = Get-Content $surface -Encoding UTF8
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
  if ($hits -eq 0) { Write-Host "no match for '$Lookup' in docs\API-SURFACE.md" -ForegroundColor Yellow; exit 1 }
  exit 0
}

# --- generate ------------------------------------------------------------------------------------
$exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
if (-not (Test-Path $exe)) {
  Write-Host "local-tools.exe not built - run: dotnet build `"$kit\local-tools\local-tools.csproj`" -c Release" -ForegroundColor Yellow
  exit 1
}
$out = & $exe --api-surface $proj 2>&1 | Out-String
$code = $LASTEXITCODE
if (-not $Quiet) { Write-Host $out.Trim() }
if ($code -ne 0) { exit $code }

# Reflection cannot know which .cs file a type lives in - add it BEFORE the reindex so the indexed copy
# carries "class Foo   (in Foo.cs)" too, and every -Lookup (including close-unit's on a build error) shows it.
Add-SourceFiles $proj $surface

# It lives in docs\, so it belongs to the index. Refresh so the next search sees it.
if (Test-Path (Join-Path $proj "docs")) {
  # Best-effort: a native exe writes to stderr, which try/catch does NOT swallow, so redirect it. Without
  # this, close-unit printed "reindex failed: Embedding failed. Is Ollama running?" after a SUCCESSFUL
  # close - which reads like the close-out broke when nothing did.
  try { & $exe --reindex (Join-Path $proj "docs") 2>$null | Out-Null } catch { }
  if ($LASTEXITCODE -ne 0 -and -not $Quiet) {
    Write-Host "  (index not refreshed - Ollama offline? the file is written either way)" -ForegroundColor DarkGray
  }
}
exit 0
