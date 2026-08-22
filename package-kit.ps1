# package-kit.ps1 - build a clean, movable copy of the kit (the folder-copy distribution path).
# Excludes build output, dropped reference projects, the RAG index and session state; verifies the
# dev-path PLACEHOLDER is intact (install.ps1 rewrites it on the target, so a baked-in absolute path
# would break the move); and refuses to ship if scan-secrets finds anything.
#
#   package-kit.ps1                       -> ..\DAD-kit-v<version>.zip
#   package-kit.ps1 -OutDir D:\transfer   -> D:\transfer\DAD-kit-v<version>.zip
#   package-kit.ps1 -Folder               -> an unzipped folder instead of a .zip
#   package-kit.ps1 -IncludeGit           -> keep .git (history + tags travel; two repos can then diverge)
#
# On the target: extract anywhere, then run install.cmd (it fixes all paths for the new location).

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param(
  [string]$OutDir = "",
  [switch]$Folder,
  [switch]$IncludeGit
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$version = if (Test-Path (Join-Path $kit "VERSION")) { (Get-Content (Join-Path $kit "VERSION") -Raw).Trim() } else { "0.0.0" }
if (-not $OutDir) { $OutDir = Split-Path $kit -Parent }
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$name = "DAD-kit-v$version"

# --- refuse to package a tree with credentials in it ---
& (Join-Path $kit "scan-secrets.ps1") -Path $kit -Quiet
if ($LASTEXITCODE -ne 0) { Write-Host "package-kit: ABORTED - scan-secrets found something. Fix it first." -ForegroundColor Red; exit 1 }

$exclude = @("bin","obj","_tempReference",".index",".claude","__pycache__",".vs")
if (-not $IncludeGit) { $exclude += ".git" }

$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("adkit-pkg-" + [guid]::NewGuid().ToString("N").Substring(0,8))
$dest = Join-Path $stage $name
New-Item -ItemType Directory -Force $dest | Out-Null

Write-Host "Packaging DAD-kit $version" -ForegroundColor Cyan
$copied = 0
Get-ChildItem $kit -Recurse -File -Force | ForEach-Object {
  $rel = $_.FullName.Substring($kit.Length).TrimStart([char]92)
  $parts = $rel.Split([char]92)
  if ($parts | Where-Object { $exclude -contains $_ }) { return }
  if ($_.Extension -eq ".zip") { return }
  $target = Join-Path $dest $rel
  New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
  Copy-Item $_.FullName $target -Force
  $copied++
}
Write-Host "  staged $copied file(s)" -ForegroundColor Green

# --- move-safety self-check: the placeholder MUST survive, or install cannot fix paths on the target ---
$bad = @()
foreach ($rel in @(".mcp.json", "templates\_common\.mcp.json", "templates\unity\.mcp.json")) {
  $p = Join-Path $dest $rel
  if (-not (Test-Path $p)) { $bad += "$rel missing"; continue }
  $t = Get-Content $p -Raw
  if ($t -notmatch 'DAD-kit') { $bad += "$rel lost the dev-path placeholder" }
}
foreach ($rel in @("VERSION", "install.cmd", "install.ps1", "models.json", "test-kit.ps1")) {
  if (-not (Test-Path (Join-Path $dest $rel))) { $bad += "$rel missing" }
}
if ($bad.Count) {
  Write-Host "package-kit: ABORTED -" -ForegroundColor Red
  foreach ($b in $bad) { Write-Host "  $b" -ForegroundColor Red }
  Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
  exit 1
}
Write-Host "  placeholder intact - safe to install at any path on the target" -ForegroundColor Green

if ($Folder) {
  $final = Join-Path $OutDir $name
  if (Test-Path $final) { Remove-Item $final -Recurse -Force }
  Move-Item $dest $final
  Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "`nReady: $final" -ForegroundColor Green
} else {
  $zip = Join-Path $OutDir "$name.zip"
  if (Test-Path $zip) { Remove-Item $zip -Force }
  Compress-Archive -Path $dest -DestinationPath $zip
  Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
  $mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
  Write-Host "`nReady: $zip  ($mb MB)" -ForegroundColor Green
}
Write-Host "On the target: extract, then run install.cmd (it rewrites paths for the new location)." -ForegroundColor Cyan
exit 0
