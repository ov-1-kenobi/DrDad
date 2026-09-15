# corpus.ps1 - manage DrDad knowledge CORPORA: named, persistent, cited knowledge banks that projects
# consult (via a [research] Ref) instead of re-researching the web each time. A corpus is a FOLDER - a
# CORPUS.md manifest + sources\ + SOURCES.md + a .index\ - under an environment's corpora\ dir (see env.ps1).
# build/search drive the EXISTING local-tools engine (no new server). REMOVE is SAFE: it archives to a dated
# zip, never a hard delete.
#
#   dad corpus [-Env <env>]                      list corpora in the environment (default: 'default')
#   dad corpus new <name> [-Env <env>]           scaffold the folder + CORPUS.md manifest
#   dad corpus build <name> [-Env <env>]         index the corpus (local-tools --reindex)
#   dad corpus refresh <name> [-Env <env>]       re-index; for the full grab-latest cycle use /corpus refresh
#   dad corpus search <name> "<query>" [-Env <env>]   semantic search of the corpus's index
#   dad corpus remove <name> [-Env <env>]        archive to _archive\<name>_<date>.zip, then remove
#   dad corpus restore <archive.zip> [-Env <env>]
[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Action = "list",
  [Parameter(Position=1)][string]$Name = "",
  [Parameter(Position=2)][string]$Query = "",
  [Alias('Env')][string]$Environment = "default",
  [switch]$Quiet
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot

$root = if ($env:DRDAD_ENV_ROOT) { $env:DRDAD_ENV_ROOT } else { Join-Path $env:USERPROFILE ".drdad\environments" }
$corporaDir = Join-Path (Join-Path $root $Environment) "corpora"
$archiveDir = Join-Path $corporaDir "_archive"
$corpusDir  = if ($Name) { Join-Path $corporaDir $Name } else { "" }

function Get-Exe {
  $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
  if (-not (Test-Path $exe)) { Write-Host "local-tools.exe not built - run: dotnet build `"$kit\local-tools\local-tools.csproj`" -c Release" -ForegroundColor Yellow; return "" }
  return $exe
}

switch ($Action.ToLower()) {
  "list" {
    $cs = if (Test-Path $corporaDir) { @(Get-ChildItem $corporaDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^_' }) } else { @() }
    if ($cs.Count -eq 0) { Write-Host "environment '$Environment' has no corpora yet (dad corpus new <name> -Env $Environment)"; exit 0 }
    Write-Host "corpora in '$Environment' (root: $root):"
    foreach ($c in $cs) {
      $idx = Join-Path $c.FullName ".index"
      $built = if (Test-Path $idx) { (Get-Item $idx).LastWriteTime.ToString('yyyy-MM-dd') } else { "not built" }
      Write-Host ("  {0,-24} indexed: {1}" -f $c.Name, $built)
    }
    exit 0
  }
  "new" {
    if (-not $Name) { Write-Host "usage: dad corpus new <name> [-Env <env>]" -ForegroundColor Yellow; exit 1 }
    if (Test-Path $corpusDir) { Write-Host "corpus '$Name' already exists in '$Environment': $corpusDir" -ForegroundColor Yellow; exit 1 }
    New-Item -ItemType Directory -Force (Join-Path $corpusDir "sources") | Out-Null
    $tmpl = Join-Path $kit "templates\_common\CORPUS.md"
    $body = if (Test-Path $tmpl) { (Get-Content $tmpl -Raw -Encoding UTF8).Replace("<name>", $Name) } else { "# Corpus: $Name`r`n" }
    [System.IO.File]::WriteAllText((Join-Path $corpusDir "CORPUS.md"), $body, (New-Object System.Text.UTF8Encoding($false)))
    $srcTmpl = Join-Path $kit "templates\_common\docs\SOURCES.md"
    if (Test-Path $srcTmpl) { Copy-Item $srcTmpl (Join-Path $corpusDir "SOURCES.md") -Force }
    if (-not $Quiet) { Write-Host "created corpus '$Name' at $corpusDir - fill CORPUS.md, add sources\, then: dad corpus build $Name -Env $Environment" -ForegroundColor Green }
    exit 0
  }
  "build" {
    if (-not $Name -or -not (Test-Path $corpusDir)) { Write-Host "no such corpus '$Name' in '$Environment'" -ForegroundColor Yellow; exit 1 }
    $exe = Get-Exe; if (-not $exe) { exit 1 }
    & $exe --reindex $corpusDir
    exit $LASTEXITCODE
  }
  "refresh" {
    # CLI refresh = re-index only. Grabbing the LATEST from the pinned sources is a WEB fetch (ingest_url),
    # which is agent-driven - so the full grab -> cite -> reindex cycle lives in /corpus <name> refresh.
    if (-not $Name -or -not (Test-Path $corpusDir)) { Write-Host "no such corpus '$Name' in '$Environment'" -ForegroundColor Yellow; exit 1 }
    $exe = Get-Exe; if (-not $exe) { exit 1 }
    & $exe --reindex $corpusDir
    $rc = $LASTEXITCODE
    Write-Host "  re-indexed. To also GRAB the latest from your pinned sources (agent-driven web fetch), run:" -ForegroundColor DarkGray
    Write-Host "    /corpus $Name refresh -env $Environment    (loopable: /loop 24h /corpus $Name refresh -env $Environment)" -ForegroundColor DarkGray
    exit $rc
  }
  "search" {
    if (-not $Name -or -not (Test-Path $corpusDir)) { Write-Host "no such corpus '$Name' in '$Environment'" -ForegroundColor Yellow; exit 1 }
    if (-not $Query) { Write-Host "usage: dad corpus search <name> `"<query>`" [-Env <env>]" -ForegroundColor Yellow; exit 1 }
    $exe = Get-Exe; if (-not $exe) { exit 1 }
    $prev = $env:LOCALTOOLS_DOCS_DIR
    $env:LOCALTOOLS_DOCS_DIR = $corpusDir
    try { & $exe --search $Query } finally { $env:LOCALTOOLS_DOCS_DIR = $prev }
    exit $LASTEXITCODE
  }
  "remove" {
    if (-not $Name -or -not (Test-Path $corpusDir)) { Write-Host "no such corpus '$Name' in '$Environment'" -ForegroundColor Yellow; exit 1 }
    New-Item -ItemType Directory -Force $archiveDir | Out-Null
    $zip = Join-Path $archiveDir ("{0}_{1}.zip" -f $Name, (Get-Date -Format 'yyyy-MM-dd_HHmmss'))
    Compress-Archive -Path (Join-Path $corpusDir "*") -DestinationPath $zip -Force
    Remove-Item -Recurse -Force $corpusDir
    if (-not $Quiet) { Write-Host "archived corpus '$Name' -> $zip, removed the live folder (restore: dad corpus restore `"$zip`" -Env $Environment)" -ForegroundColor Green }
    exit 0
  }
  "restore" {
    if (-not $Name -or -not (Test-Path -LiteralPath $Name)) { Write-Host "usage: dad corpus restore <archive.zip> [-Env <env>]" -ForegroundColor Yellow; exit 1 }
    $cname = [System.IO.Path]::GetFileNameWithoutExtension($Name) -replace '_\d{4}-\d{2}-\d{2}_\d{6}$',''
    $dest = Join-Path $corporaDir $cname
    if (Test-Path $dest) { Write-Host "corpus '$cname' already exists in '$Environment' - remove it first" -ForegroundColor Yellow; exit 1 }
    New-Item -ItemType Directory -Force $dest | Out-Null
    Expand-Archive -Path $Name -DestinationPath $dest -Force
    if (-not $Quiet) { Write-Host "restored corpus '$cname' into '$Environment' from $Name" -ForegroundColor Green }
    exit 0
  }
  "check" {
    # Deterministic manifest/corpus validation - the honesty gate /corpus runs BEFORE any dialogue, so the
    # agent starts from facts. A '## X' section still holding a <lowercase...> placeholder is UNFILLED.
    if (-not $Name -or -not (Test-Path $corpusDir)) { Write-Host "no such corpus '$Name' in '$Environment'" -ForegroundColor Yellow; exit 1 }
    $manifest = Join-Path $corpusDir "CORPUS.md"
    $text = if (Test-Path $manifest) { Get-Content $manifest -Raw -Encoding UTF8 } else { "" }
    $findings = New-Object System.Collections.Generic.List[string]
    Write-Host "== corpus '$Name' (env '$Environment') =="
    foreach ($sec in @("Goal","Scope","Sources","Build & refresh")) {
      $m = [regex]::Match($text, "(?ms)^##\s*$([regex]::Escape($sec))\b(.*?)(?=^##\s|\z)")
      if (-not $m.Success) { $findings.Add("[corpus] no '## $sec' section in CORPUS.md"); continue }
      $body = ($m.Groups[1].Value -replace '(?s)<!--.*?-->','').Trim()
      if ($body -eq "" -or $body -match '<[a-z][^>]{0,60}>') { $findings.Add("[corpus] '## $sec' is unfilled (still a <...> placeholder)") }
    }
    $urls = @([regex]::Matches($text, '(?m)^\s*-\s*https?://[^\s>]+')).Count   # a real URL, not the <https://...> placeholder
    $srcFiles = @(Get-ChildItem (Join-Path $corpusDir "sources") -File -Recurse -ErrorAction SilentlyContinue).Count
    if ($urls -eq 0) { $findings.Add("[corpus] no source URLs in '## Sources' - the agent has nothing authoritative to ingest") }
    $idx = Join-Path $corpusDir ".index"
    $idxState = if (Test-Path $idx) { (Get-Item $idx).LastWriteTime.ToString('yyyy-MM-dd') } else { "not built" }
    if (-not (Test-Path $idx)) { $findings.Add("[corpus] index not built - run: dad corpus build $Name -Env $Environment") }
    Write-Host ("  sources: {0} url(s) in manifest, {1} file(s) in sources\ | index: {2}" -f $urls, $srcFiles, $idxState)
    Write-Host "findings:"
    if ($findings.Count -eq 0) { Write-Host "  none - the corpus is filled, sourced, and indexed." -ForegroundColor Green }
    else { foreach ($f in $findings) { Write-Host "  $f" -ForegroundColor Yellow } }
    exit 0
  }
  default { Write-Host "dad corpus: unknown action '$Action' (list | new | check | build | refresh | search | remove | restore)" -ForegroundColor Yellow; exit 1 }
}
