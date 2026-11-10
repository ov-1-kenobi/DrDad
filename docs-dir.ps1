# docs-dir.ps1 - shared helper (dot-source it): Resolve-DocsDir <projectDir> [-Quiet]  (Story S19)
# Returns the docs folder the kit scripts should read. A LOCALTOOLS_DOCS_DIR override in <proj>\.mcp.json is
# honoured ONLY when it is a real directory holding DESIGN.md, TEDD.md or STORIES.md; otherwise <proj>\docs is
# returned and (unless -Quiet) ONE WARN line is printed. It never creates a directory.
# 0.60.0: a RELATIVE override (new projects write "docs") is resolved against the project root, never the
# caller's current directory. Also home of the portable .mcp.json 'command' form, shared by new-project,
# upgrade-project and dad-doctor so the three cannot drift.
# (A function, not a variable: a variable assigned here and read in another file resolves to $null
# without any error if the dot-source is ever dropped - the kit's own static check refuses that shape.)
function Get-DadPortableExe { return '${DAD_HOME}\local-tools\bin\Release\net8.0\local-tools.exe' }
# Expand ${DAD_HOME} the way Claude Code will, for scripts that need the real path. "" when it cannot.
function Expand-DadHome([string]$Text) {
  if (-not $Text) { return "" }
  if (-not $Text.Contains('${DAD_HOME}')) { return $Text }
  $h = $env:DAD_HOME
  if (-not $h) { $h = [Environment]::GetEnvironmentVariable("DAD_HOME", "User") }
  if (-not $h) { return "" }
  return $Text.Replace('${DAD_HOME}', $h.TrimEnd('\', '/'))
}
function Resolve-DocsDir([string]$Proj, [switch]$Quiet) {
  $docs = Join-Path $Proj "docs"
  $mcp = Join-Path $Proj ".mcp.json"
  $d = $null
  if (Test-Path -LiteralPath $mcp) {
    try { $d = (Get-Content -LiteralPath $mcp -Raw | ConvertFrom-Json).mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR } catch { $d = $null }
  }
  if ($d) {
    # ';'-separated multi-root lists: the first root is primary, as in the server. Relative -> under $Proj.
    $first = (([string]$d) -split ';')[0].Trim()
    if ($first -and -not [System.IO.Path]::IsPathRooted($first)) { $d = Join-Path $Proj $first }
  }
  if ($d) {
    $ok = $false
    try {
      if (Test-Path -LiteralPath $d -PathType Container) {
        foreach ($n in @("DESIGN.md", "TEDD.md", "STORIES.md")) {
          if (Test-Path -LiteralPath (Join-Path $d $n)) { $ok = $true; break }
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
