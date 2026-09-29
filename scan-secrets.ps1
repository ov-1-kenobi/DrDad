# scan-secrets.ps1 - block credentials from entering a repo (or the RAG corpus).
#
# Why this matters HERE specifically: everything under a project's docs\ is chunked into
# .index\chunks.json as PLAINTEXT and made searchable. A connection string pasted into a design doc
# becomes a searchable artifact, and the source doc is committable. This is the control for that.
#
# Usage:
#   scan-secrets.ps1                      scan the current folder (tracked-ish files, skips bin/obj/.git)
#   scan-secrets.ps1 -Path C:\src\App     scan a folder
#   scan-secrets.ps1 -Staged              scan only git-staged files (what the pre-commit hook uses)
#
# Exit codes: 0 = clean, 1 = findings, 2 = usage/error.
# NEVER prints the matched value - only file:line, the pattern name, and a short SHA-256 fingerprint,
# so a finding can be discussed and tracked without copying the secret anywhere.
#
# False positive? Put any of these in a comment on that line - the industry-standard markers are honored
# so you do not have to learn a kit-specific one:
#   pragma: allowlist secret   (detect-secrets)   gitleaks:allow   trufflehog:ignore   nosec
#   DAD-ALLOW-SECRET   (and the pre-rename AD-ALLOW-SECRET, still honored)   DAD-RENAME-OK

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param(
  [string]$Path = ".",
  [switch]$Staged,
  [switch]$Quiet,
  [switch]$PatternsOnly
)
$ErrorActionPreference = "Stop"

# name -> regex. Ordered most-specific first. Keep these high-signal; noisy rules train people to ignore.
#
# STRUCTURAL patterns (everything except $heuristic below) are NEVER placeholder-suppressed: a string
# shaped like a credential is a finding even if the line says "example" or "test". AWS's own documented
# EXAMPLE key id is exactly how a real leak slips past a naive filter - do not "helpfully" ignore it.
$patterns = [ordered]@{
  "AWS access key id"        = 'A(?:KIA|SIA|ROA|IDA)[0-9A-Z]{16}'
  "AWS secret access key"    = '(?i)aws_secret_access_key\s*[:=]\s*\S{40}'
  "GitHub token"             = 'gh[pousr]_[A-Za-z0-9]{36,}'
  "GitHub fine-grained PAT"  = 'github_pat_[A-Za-z0-9_]{22,}'
  "Slack token"              = 'xox[abopsr]-[A-Za-z0-9-]{10,}'
  "Google API key"           = 'AIza[0-9A-Za-z_\-]{35}'
  "Anthropic API key"        = 'sk-ant-[A-Za-z0-9_\-]{20,}'
  "OpenAI-style API key"     = 'sk-[A-Za-z0-9]{32,}'
  "Azure storage key"        = '(?i)(?:AccountKey|SharedAccessKey)\s*=\s*[A-Za-z0-9+/=]{40,}'
  "Azure client secret"      = '(?i)client[_-]?secret\s*[:=]\s*["'']?[A-Za-z0-9~._\-]{20,}'
  "Private key (PEM)"        = '-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY-----'
  "JWT"                      = 'eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}'
  "Password/secret literal"  = '(?i)\b(?:password|passwd|pwd|secret|token|api[_-]?key)\b\s*[:=]\s*["'']?[^"''\s<>${}]{8,}'
}

# Keyword-driven rules only: these fire on any 8+ char value after "password:"/"token="/etc, so they need
# placeholder suppression or they are unusable. Structural rules above do NOT get this treatment.
$heuristic = @("Password/secret literal", "Azure client secret")

# -PatternsOnly: for DOT-SOURCING (. scan-secrets.ps1 -PatternsOnly) by dad-gates-log.ps1, which redacts
# with THIS pattern list so the kit keeps ONE definition of a secret (R20, C3a). Defines $patterns and
# returns before any scanning; normal invocations are unchanged.
if ($PatternsOnly) { return }

# Obvious non-secrets - placeholders, env references, docs.
$placeholder = '(?i)(<[^>]*>|\$\{|%[A-Z_]+%|\$env:|xxx+|changeme|your[-_]|example|placeholder|dummy|redacted|\*\*\*|todo|n/?a$|process\.env|os\.environ|getenv)'
# '_tempReference' holds dropped reference projects, not kit source. It is skipped by default so the kit's
# own gate is about the kit - but the skip is ANNOUNCED (never silent), and you can scan it deliberately
# with -Path _tempReference. Do not add anything else here without the same reasoning.
$skipDirs = @('.git','bin','obj','node_modules','__pycache__','.index','.vs','packages','dist','.venv','_tempReference')
$skipExt  = @('.dll','.exe','.pdb','.png','.jpg','.jpeg','.gif','.webp','.bmp','.ico','.zip','.7z','.gz',
              '.onnx','.pdf','.wav','.mp3','.m4a','.flac','.ogg','.bin','.so','.dylib','.nupkg','.cache')

function Get-Fingerprint([string]$s) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($s))) -replace '-','').Substring(0,8).ToLower()
}

# --- build the file list ---
$files = @()
if ($Staged) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Host "git not found"; exit 2 }
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $names = git diff --cached --name-only --diff-filter=ACM
  $ErrorActionPreference = $prev
  foreach ($n in $names) { if ($n -and (Test-Path -LiteralPath $n)) { $files += (Resolve-Path -LiteralPath $n).Path } }
} else {
  $root = (Resolve-Path -LiteralPath $Path).Path
  $files = Get-ChildItem $root -Recurse -File -Force |
    Where-Object {
      $parts = $_.FullName.Substring($root.Length).Split([char]92)
      -not ($parts | Where-Object { $skipDirs -contains $_ }) -and ($skipExt -notcontains $_.Extension.ToLower())
    } | ForEach-Object { $_.FullName }
}

# --- scan ---
$findings = New-Object System.Collections.Generic.List[object]
foreach ($f in $files) {
  if ((Get-Item -LiteralPath $f).Length -gt 2MB) { continue }
  $lineNo = 0
  foreach ($line in [System.IO.File]::ReadLines($f)) {
    $lineNo++
    if ($line.Length -gt 4000) { continue }
    # Honor the standard allowlist markers as well as ours, so existing repos keep working.
    # The pre-rename spelling sits in USER source files, so dropping it would   DAD-RENAME-OK
    # silently stop suppressing lines someone already reviewed and cleared. Both are honored, forever.
    # DAD-RENAME-OK - (?:D)? is what keeps the pre-rename marker working.
    if ($line -match '(?i)((?:D)?AD-ALLOW-SECRET|pragma:\s*allowlist\s+secret|gitleaks:\s*allow|trufflehog:\s*ignore|\bnosec\b)') { continue }
    foreach ($name in $patterns.Keys) {
      $m = [regex]::Match($line, $patterns[$name])
      if (-not $m.Success) { continue }
      if (($heuristic -contains $name) -and ($m.Value -match $placeholder)) { continue }
      $findings.Add([pscustomobject]@{
        File = $f; Line = $lineNo; Pattern = $name; Fingerprint = (Get-Fingerprint $m.Value)
      })
      break   # one finding per line is enough
    }
  }
}

# Announce skipped reference drops - a silent skip is how a real credential hides.
if (-not $Staged) {
  $refDir = Join-Path (Resolve-Path -LiteralPath $Path).Path "_tempReference"
  if (Test-Path $refDir) {
    Write-Host "scan-secrets: NOTE - skipped _tempReference\ (reference drops, not kit source)." -ForegroundColor DarkYellow
    Write-Host "              scan it deliberately with:  scan-secrets.cmd -Path `"$refDir`"" -ForegroundColor DarkYellow
  }
}

if ($findings.Count -eq 0) {
  if (-not $Quiet) { Write-Host "scan-secrets: clean ($($files.Count) file(s) scanned)" -ForegroundColor Green }
  exit 0
}

Write-Host ""
Write-Host "scan-secrets: POSSIBLE CREDENTIALS FOUND - not committing." -ForegroundColor Red
foreach ($x in $findings) {
  Write-Host ("  {0}:{1}  [{2}]  fingerprint {3}" -f $x.File, $x.Line, $x.Pattern, $x.Fingerprint) -ForegroundColor Yellow
}
Write-Host ""
Write-Host "The value itself is deliberately NOT printed (only a fingerprint)." -ForegroundColor Cyan
Write-Host "If any of these is a REAL credential: treat it as exposed - ROTATE it, then remove it from the" -ForegroundColor Cyan
Write-Host "file (and from git history if it was ever committed). Report exposure per your org's process." -ForegroundColor Cyan
Write-Host "Use env vars / a gitignored .env and reference secrets BY NAME. False positive? add DAD-ALLOW-SECRET" -ForegroundColor Cyan
Write-Host "in a comment on that line." -ForegroundColor Cyan
exit 1
