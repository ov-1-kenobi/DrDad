# docs-find.ps1 - search the project's indexed docs FROM THE SHELL.
#
#   docs-find.ps1 "what does C9 say about tile sizes"
#   docs-find.ps1 "TableClient upsert" -Top 8
#   docs-find.ps1 "eligibility" -ProjectDir C:\src\App
#
# WHY THIS EXISTS, when search_datasheets already does it. Across NINE graded runs the MCP tool
# search_datasheets was called ZERO times - while `doc-stats.ps1` was called 17 times in a single run and
# Bash 94 times. The model reaches for the shell. Prose telling it to prefer an MCP tool has been in
# dev-agent, qa-agent and /build the whole time and has never once worked.
#
# So this is the same corpus, behind the interface that actually gets used. Two further advantages:
#   - it works when the MCP server is NOT connected (a stale .mcp.json path, a server that failed to
#     start) - precisely when you most need to look something up and are least likely to notice you can't
#   - it is greppable and pipeable, so a run can feed the result into its next command
#
# Needs Ollama for the embedding (semantic search). If Ollama is down it says so and falls back to a plain
# text scan, which is worse but not nothing.

param(
  [Parameter(Mandatory, Position=0)][string]$Query,
  [int]$Top = 5,
  [string]$ProjectDir = "."
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
# GUARD: -ProjectDir must exist. Resolve-Path ERRORS on a missing path but the .cmd wrapper still exited 0,
# so a mistyped path looked like a project with no stories and no tasks. Fail loudly instead.
if (-not (Test-Path -LiteralPath $ProjectDir)) {
  Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red
  exit 2
}
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
# The corpus location is the project's own, exactly as the MCP server would resolve it.
$docs = Join-Path $proj "docs"
$mcp = Join-Path $proj ".mcp.json"
if (Test-Path $mcp) {
  try {
    $d = (Get-Content $mcp -Raw | ConvertFrom-Json).mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR
    if ($d) { $docs = $d }
  } catch { }
}

$exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
if (-not (Test-Path $exe)) {
  Write-Host "local-tools.exe not built - run: dotnet build `"$kit\local-tools\local-tools.csproj`" -c Release" -ForegroundColor Yellow
  exit 1
}

$prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
$env:LOCALTOOLS_DOCS_DIR = $docs
$out = (& $exe --search $Query $Top 2>&1 | Out-String)
$code = $LASTEXITCODE
$ErrorActionPreference = $prevEap

if ($code -eq 0 -and $out.Trim()) {
  Write-Host $out.Trim()
  exit 0
}

# Semantic search needs Ollama for the query embedding. When it is down, a literal scan over the same
# corpus is a poor substitute but far better than returning nothing and letting the run guess.
Write-Host "(semantic search unavailable - $($out.Trim() -split "`n" | Select-Object -First 1))" -ForegroundColor DarkGray
Write-Host "falling back to a literal scan of $docs" -ForegroundColor DarkGray
if (-not (Test-Path $docs)) { Write-Host "no docs folder at $docs" -ForegroundColor Yellow; exit 1 }
$terms = @($Query -split '\s+' | Where-Object { $_.Length -ge 4 })
if ($terms.Count -eq 0) { $terms = @($Query) }
$hits = 0
foreach ($f in (Get-ChildItem $docs -Recurse -File -Include *.md,*.txt -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '\\\.index\\' })) {
  foreach ($m in (Select-String -Path $f.FullName -Pattern ($terms -join '|') -ErrorAction SilentlyContinue | Select-Object -First 3)) {
    Write-Host ("{0}:{1}: {2}" -f $f.Name, $m.LineNumber, $m.Line.Trim())
    $hits++
  }
  if ($hits -ge ($Top * 3)) { break }
}
if ($hits -eq 0) { Write-Host "no match for '$Query'" -ForegroundColor Yellow; exit 1 }
exit 0
