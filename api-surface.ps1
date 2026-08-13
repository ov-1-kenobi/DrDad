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

param(
  [string]$ProjectDir = ".",
  [string]$Lookup = "",
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$surface = Join-Path $proj "docs\API-SURFACE.md"

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
