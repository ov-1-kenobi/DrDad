# free-locks.ps1 - clear the build lock a left-over app process holds on a project's own output.
#
# Why: measured on a real run. A `dotnet run` left an apphost alive; the next `dotnet build` failed with
# MSB3026 ("could not copy ... being used by another process") SEVEN times. The model diagnosed it - "a
# running CMS process that I can't kill" - and could not clear it, so the story never closed even though
# the code was fine.
#
# SAFETY - this only ever kills things that unambiguously belong to THIS project:
#   1. processes whose EXECUTABLE PATH is under <project> (i.e. an apphost/binary running from the project's
#      own bin\ - nothing else legitimately runs from there), and
#   2. `dotnet`/`dotnet watch` processes whose COMMAND LINE names this project path.
# It never kills by image name alone, so it cannot touch Ollama, Claude Code, the local-tools MCP server
# (which runs from the KIT dir, not the project), or your unrelated work. `dotnet build-server shutdown`
# (harmless; the shared compiler just restarts next build) runs first, since VBCSCompiler can hold obj locks.
#
#   dad free-locks                     clear locks for the current project
#   dad free-locks -ProjectDir C:\src\app
#   dad free-locks -WhatIf             list what WOULD be killed, kill nothing

# CmdletBinding so a MISTYPED parameter is an ERROR rather than a silent default.
[CmdletBinding()]
param(
  [string]$ProjectDir = ".",
  [switch]$WhatIf
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ProjectDir)) {
  Write-Host "ERROR: -ProjectDir does not exist: $ProjectDir" -ForegroundColor Red
  exit 2
}
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path.TrimEnd('\')

# Guard: refuse to operate on a root or a home directory. Path-scoping is what makes this safe, so a $proj
# that is too broad (C:\, the user profile, Windows) would defeat the whole point. A real project has a
# CLAUDE.md; require it, and require the path to be reasonably deep.
$looksLikeProject = (Test-Path (Join-Path $proj "CLAUDE.md")) -or (Test-Path (Join-Path $proj "docs"))
$depth = ($proj -split '[\\/]' | Where-Object { $_ }).Count
if (-not $looksLikeProject -or $depth -lt 2) {
  Write-Host "REFUSING: '$proj' does not look like a project (no CLAUDE.md/docs, or too shallow)." -ForegroundColor Red
  Write-Host "  free-locks only ever kills processes running from a specific project's own folder." -ForegroundColor Yellow
  exit 2
}

$projPrefix = $proj + '\'
$targets = @()   # list of @{ Id; Name; Why }

# (1) processes whose executable lives under the project (the apphost is the usual MSB3026 culprit)
foreach ($p in (Get-Process -ErrorAction SilentlyContinue)) {
  $path = $null
  try { $path = $p.Path } catch { $path = $null }
  if ($path -and $path.StartsWith($projPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    $targets += @{ Id = $p.Id; Name = $p.ProcessName; Why = "runs from $($path.Substring($proj.Length).TrimStart('\'))" }
  }
}

# (2) dotnet / dotnet watch whose COMMAND LINE names this project (dotnet run --project <proj>, dotnet watch)
try {
  foreach ($c in (Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue)) {
    $cl = $c.CommandLine
    if ($cl -and $cl.IndexOf($proj, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      if (-not ($targets | Where-Object { $_.Id -eq $c.ProcessId })) {
        $targets += @{ Id = [int]$c.ProcessId; Name = "dotnet"; Why = "command line references this project" }
      }
    }
  }
} catch { }

Write-Host "== free-locks: $proj ==" -ForegroundColor Cyan

# Gentle first: shut down the shared build server (safe; it restarts on next build). Skip in -WhatIf.
if (-not $WhatIf) {
  try { & dotnet build-server shutdown 2>&1 | Out-Null; Write-Host "  dotnet build-server shutdown (VBCSCompiler released any obj locks)" -ForegroundColor DarkGray } catch { }
}

if ($targets.Count -eq 0) {
  Write-Host "  no project-owned processes are running - nothing to free." -ForegroundColor Green
  exit 0
}

$killed = 0
foreach ($t in $targets) {
  if ($WhatIf) {
    Write-Host ("  WOULD kill PID {0} ({1}) - {2}" -f $t.Id, $t.Name, $t.Why) -ForegroundColor Yellow
    continue
  }
  try {
    Stop-Process -Id $t.Id -Force -ErrorAction Stop
    Write-Host ("  killed PID {0} ({1}) - {2}" -f $t.Id, $t.Name, $t.Why) -ForegroundColor Yellow
    $killed++
  } catch {
    Write-Host ("  could NOT kill PID {0} ({1}): {2}" -f $t.Id, $t.Name, $_.Exception.Message.Split([char]10)[0]) -ForegroundColor Red
  }
}
if ($WhatIf) { Write-Host "  (-WhatIf: killed nothing)" -ForegroundColor DarkGray; exit 0 }
Write-Host "  freed $killed process(es). Re-run the build." -ForegroundColor Green
exit 0
