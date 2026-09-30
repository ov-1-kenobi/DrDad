# docs-dir.ps1 - shared helper (dot-source it): Resolve-DocsDir <projectDir> [-Quiet]  (Story S19)
# Returns the docs folder the kit scripts should read. A LOCALTOOLS_DOCS_DIR override in <proj>\.mcp.json is
# honoured ONLY when it is a real directory holding DESIGN.md, TEDD.md or STORIES.md; otherwise <proj>\docs is
# returned and (unless -Quiet) ONE WARN line is printed. It never creates a directory.
function Resolve-DocsDir([string]$Proj, [switch]$Quiet) {
  $docs = Join-Path $Proj "docs"
  $mcp = Join-Path $Proj ".mcp.json"
  $d = $null
  if (Test-Path -LiteralPath $mcp) {
    try { $d = (Get-Content -LiteralPath $mcp -Raw | ConvertFrom-Json).mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR } catch { $d = $null }
  }
  if ($d) {
    $ok = $false
    try {
      if (Test-Path -LiteralPath $d -PathType Container) {
        foreach ($n in @("DESIGN.md", "TEDD.md", "STORIES.md")) {
          if (Test-Path -LiteralPath (Join-Path $d $n)) { $ok = $true }
        }
      }
    } catch { $ok = $false }
    if ($ok) { return (Resolve-Path -LiteralPath $d).Path }
    if (-not $Quiet) {
      Write-Host "WARN: ignoring LOCALTOOLS_DOCS_DIR $d (no DESIGN/TEDD/STORIES there); using $Proj\docs" -ForegroundColor Yellow
    }
  }
  return $docs
}
