# env.ps1 - manage DrDad knowledge ENVIRONMENTS: isolated trees that hold corpora (see corpus.ps1). An
# environment is just a directory under the environments ROOT (default %USERPROFILE%\.drdad\environments;
# override with the DRDAD_ENV_ROOT env var). Separate trees are the data-governance wall - keep personal and
# work/client knowledge apart - and make an environment portable (zip it, move it). REMOVE is SAFE: it
# archives to a dated zip under _archive\, never a hard delete.
#
#   dad env                       list environments
#   dad env new <name>            create one
#   dad env remove <name>         archive to _archive\<name>_<date>.zip, then remove the live tree
#   dad env restore <archive.zip> un-archive
#   dad env where [<name>]        print the root, or one environment's path
[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Action = "list",
  [Parameter(Position=1)][string]$Name = "",
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"

$root = if ($env:DRDAD_ENV_ROOT) { $env:DRDAD_ENV_ROOT } else { Join-Path $env:USERPROFILE ".drdad\environments" }
$archiveDir = Join-Path $root "_archive"

switch ($Action.ToLower()) {
  "where" {
    if ($Name) { Write-Host (Join-Path $root $Name) } else { Write-Host $root }
    exit 0
  }
  "list" {
    $envs = if (Test-Path $root) { @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^_' }) } else { @() }
    if ($envs.Count -eq 0) { Write-Host "no environments yet (root: $root). Create one: dad env new <name>"; exit 0 }
    Write-Host "environments (root: $root):"
    foreach ($e in $envs) {
      $cdir = Join-Path $e.FullName "corpora"
      $n = if (Test-Path $cdir) { @(Get-ChildItem $cdir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^_' }).Count } else { 0 }
      Write-Host ("  {0,-24} {1} corpus(es)" -f $e.Name, $n)
    }
    exit 0
  }
  "new" {
    if (-not $Name) { Write-Host "usage: dad env new <name>" -ForegroundColor Yellow; exit 1 }
    $ed = Join-Path $root $Name
    if (Test-Path $ed) { Write-Host "environment '$Name' already exists: $ed" -ForegroundColor Yellow; exit 1 }
    New-Item -ItemType Directory -Force (Join-Path $ed "corpora") | Out-Null
    $marker = "# Environment: $Name`r`n`r`nCreated: $(Get-Date -Format 'yyyy-MM-dd')`r`nScope: <what this environment is for - stack + org/context; keep personal and work/client knowledge SEPARATE>`r`n"
    [System.IO.File]::WriteAllText((Join-Path $ed "ENV.md"), $marker, (New-Object System.Text.UTF8Encoding($false)))
    if (-not $Quiet) { Write-Host "created environment '$Name' at $ed  (add a corpus: dad corpus new <name> -Env $Name)" -ForegroundColor Green }
    exit 0
  }
  "remove" {
    if (-not $Name) { Write-Host "usage: dad env remove <name>" -ForegroundColor Yellow; exit 1 }
    $ed = Join-Path $root $Name
    if (-not (Test-Path $ed)) { Write-Host "no such environment: $Name" -ForegroundColor Yellow; exit 1 }
    New-Item -ItemType Directory -Force $archiveDir | Out-Null
    $zip = Join-Path $archiveDir ("{0}_{1}.zip" -f $Name, (Get-Date -Format 'yyyy-MM-dd_HHmmss'))
    Compress-Archive -Path (Join-Path $ed "*") -DestinationPath $zip -Force
    Remove-Item -Recurse -Force $ed
    if (-not $Quiet) { Write-Host "archived '$Name' -> $zip, removed the live tree (restore: dad env restore `"$zip`")" -ForegroundColor Green }
    exit 0
  }
  "restore" {
    if (-not $Name -or -not (Test-Path -LiteralPath $Name)) { Write-Host "usage: dad env restore <archive.zip>" -ForegroundColor Yellow; exit 1 }
    $envName = [System.IO.Path]::GetFileNameWithoutExtension($Name) -replace '_\d{4}-\d{2}-\d{2}_\d{6}$',''
    $ed = Join-Path $root $envName
    if (Test-Path $ed) { Write-Host "environment '$envName' already exists - remove it first" -ForegroundColor Yellow; exit 1 }
    New-Item -ItemType Directory -Force $ed | Out-Null
    Expand-Archive -Path $Name -DestinationPath $ed -Force
    if (-not $Quiet) { Write-Host "restored '$envName' from $Name" -ForegroundColor Green }
    exit 0
  }
  default { Write-Host "dad env: unknown action '$Action' (list | new | remove | restore | where)" -ForegroundColor Yellow; exit 1 }
}
