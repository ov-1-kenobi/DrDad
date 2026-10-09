# install.ps1 - one-shot installer for the local Claude Code kit.
# Copy this whole folder anywhere on a Windows machine, then run from inside it:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
# Safe to re-run. It detects its own location, so the folder can live anywhere.
#   powershell -ExecutionPolicy Bypass -File .\install.ps1           CLOUD mode (Anthropic API), the default (no flag).
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Local    LOCAL mode: Ollama redirect + offline flags.
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Hybrid   HYBRID: cloud agent + local 5080 tools.
# A no-flag re-run KEEPS an already-installed Local or Hybrid mode (contract C6); -Cloud forces Cloud explicitly.
# -Local combined with -Cloud or -Hybrid exits non-zero before anything is written.
# Cloud (default; -Cloud forces it): same commands, agents, and gates, on Anthropic's frontier models. Each alias resolves to its
# models.json 'cloud' id (dev/coder/oss/gemma -> Sonnet 5, fast -> Haiku 4.5, quality -> Opus 5). The Ollama
# base-URL redirect is dropped - and its ABSENCE is what use-model and dad-doctor read back as "cloud" mode
# (no separate marker file). The local-tools RAG still uses Ollama on the GPU if present, so cloud mode
# VERIFIES the embed/vision models are pulled (else RAG degrades to a literal keyword scan).
# -Hybrid: the cloud agent loop of -Cloud PLUS the 5080 offered to the cloud model as a drudge co-processor -
# it sets LOCALTOOLS_HYBRID=1, which turns on the local_generate MCP tool (implementation guesses, test data)
# and pulls a local generation model. The presence of LOCALTOOLS_HYBRID is what dad-doctor reads as "hybrid".
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -CopilotCli  ALSO wire the gates into Copilot CLI.
# -CopilotCli: an ADDITIVE target, not a mode. It leaves the Claude Code install untouched and additionally
# writes %USERPROFILE%\.copilot\hooks\dad.json so the SAME two guard scripts run under GitHub Copilot CLI.
# Combine it with -Cloud/-Hybrid or use it on its own.
[CmdletBinding()]
param([switch]$Cloud, [switch]$Hybrid, [switch]$Local, [switch]$CopilotCli, [switch]$Yes)
$ErrorActionPreference = "Stop"
$root  = $PSScriptRoot
$old    = 'C:\Projects\Claude\MCP\DAD-kit'            # dev-path placeholder baked into the markdown command files
$claude = Join-Path $env:USERPROFILE ".claude"
# S29/C6: resolve the install mode BEFORE anything is written. A flag conflict exits here, with nothing touched.
. (Join-Path $root "install-mode.ps1")
$resolved = Resolve-InstallMode ([bool]$Local) ([bool]$Cloud) ([bool]$Hybrid) (Join-Path $claude "settings.json")
if ($resolved.Conflict) { Write-Host "ERROR: $($resolved.Conflict)" -ForegroundColor Red; exit 1 }
if ($resolved.Warn) { Write-Host "  [warn] $($resolved.Warn)" -ForegroundColor Yellow }
$mode = $resolved.Mode
$modeReason = $resolved.ReasonText
# Rebind so every downstream test of $Cloud/$Hybrid follows the RESOLVED mode.
# $Cloud is intentionally TRUE for Hybrid as well (Hybrid runs the cloud agent loop); only $Hybrid distinguishes them.
$Hybrid = [switch]($mode -eq 'Hybrid')
$Cloud  = [switch]($mode -ne 'Local')
# -Hybrid runs the cloud AGENT LOOP (base-URL dropped) like -Cloud, and additionally lights up the local GPU
# tools. $cloudLoop = "the agent talks to Anthropic, not Ollama" and drives the settings.json edit + labels.
$cloudLoop = $Cloud -or $Hybrid
# S29/C6 invariant (v) test seam (R35b): env-var ONLY (no parameter, no switch). Inert unless non-empty. When set, every
# machine-wide write below (USER Path, DAD_HOME, ~/.bashrc, Ollama tuning/pulls/builds, npm, VS Code extension) is
# redirected under this directory or skipped, so a full run touches only the sandbox profile + this directory.
$sandbox = $env:DAD_INSTALL_SANDBOX
if ($sandbox) {
  New-Item -ItemType Directory -Force $sandbox | Out-Null
  Write-Host "  [sandbox] DAD_INSTALL_SANDBOX=$sandbox - machine-wide writes redirected or skipped" -ForegroundColor Yellow
}
# The Copilot CLI version DESIGN.md's C2 contract was MEASURED against. Contract C2f makes this the ONE
# source of truth for that number, and test-kit.ps1 asserts it equals the version stamped in C2 - so the doc
# and the code cannot drift apart silently, which is the precise failure the contract exists to prevent.
# Bump it only after re-measuring C2a-C2e (hook location, event casing, block semantics, subagent coverage).
$CopilotMeasuredVersion = "1.0.89"
$ClaudeCodeMeasuredVersion = "2.1.285"

function Have($n) { [bool](Get-Command $n -ErrorAction SilentlyContinue) }
. (Join-Path $root "harness-versions.ps1")   # S17/R40: Get-HarnessVersion, Get-LatestVersion, Write-HarnessReport
# Consent prompt. -Yes = consent. Empty input, or no usable stdin (Read-Host throws/returns nothing) = the DEFAULT.
function Read-Consent($prompt, [bool]$defaultYes) {
  if ($Yes) { return $true }
  $ans = ""
  try { $ans = "$(Read-Host $prompt)".Trim() } catch { $ans = "" }
  if (-not $ans) { return $defaultYes }
  return ($ans -match '^(y|yes)$')
}
function Write-NoBom($path, $content) {
  [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}
# Pull an Ollama model only if it is not already present (idempotent). Used by cloud/hybrid to guarantee the
# local-tools RAG (and, in hybrid, local_generate) actually run on the GPU instead of silently degrading.
function Ensure-OllamaModel($tag, $why) {
  if (-not $tag) { return }
  if ($script:models -match [regex]::Escape($tag)) { Write-Host "  [ok]  $tag present ($why)" -ForegroundColor Green; return }
  if ($sandbox) {
    Write-Host "  SKIP (sandbox): ollama pull $tag ($why)" -ForegroundColor Yellow
  } else {
  Write-Host "  pulling $tag ($why)..." -ForegroundColor Cyan
  try { ollama pull $tag; Write-Host "  [ok]  $tag pulled" -ForegroundColor Green }
  catch { Write-Host "  [warn] could not pull $tag ($($_.Exception.Message)) - '$why' will not work until it is pulled" -ForegroundColor Yellow }
  }
}

Write-Host "== Prerequisites ==" -ForegroundColor Cyan
$haveOllama = Have ollama; $haveDotnet = Have dotnet; $haveNode = Have node; $haveCode = Have code
foreach ($t in @(@("ollama",$haveOllama),@("dotnet",$haveDotnet),@("node",$haveNode),@("code",$haveCode))) {
  if ($t[1]) { Write-Host "  [ok]   $($t[0])" -ForegroundColor Green }
  else       { Write-Host "  [MISS] $($t[0])" -ForegroundColor Yellow }
}
$models = ""
if ($haveOllama) { $models = (ollama list | Out-String) }
$haveNomic = $models -match "nomic-embed-text"
# Devstral is the default model; step 1 pulls it if missing.
if (-not $haveDotnet){ Write-Host "  [stop] .NET 8+ SDK required to build the server. Install it, then re-run." -ForegroundColor Yellow }

$kitVersion = if (Test-Path (Join-Path $root "VERSION")) { (Get-Content (Join-Path $root "VERSION") -Raw).Trim() } else { "unknown" }
Write-Host "`n== DAD-kit $kitVersion ==" -ForegroundColor Green

Write-Host "`n== 1) Models ==" -ForegroundColor Cyan
# One manifest drives everything (aliases, -cc variants, cloud ids). Add a model = one JSON entry.
if ($cloudLoop) {
  # Cloud/hybrid: the AGENT LOOP is Anthropic (aliases resolve to models.json 'cloud'), so we do NOT build the
  # local chat zoo. But the local-tools RAG still runs on Ollama if it is up - so verify the support models are
  # pulled (else search/describe_image quietly degrade to a literal scan). Hybrid also needs a generation model
  # for local_generate. This is the "your 5080 is not idle in cloud mode" guarantee, made explicit.
  $mf1 = Get-Content (Join-Path $root "models.json") -Raw | ConvertFrom-Json
  $draftTag = $mf1.models | Where-Object { $_.default } | Select-Object -First 1 -ExpandProperty from
  if (-not $draftTag) { $draftTag = "devstral" }
  if ($haveOllama) {
    Ensure-OllamaModel $mf1.embedModel  "semantic RAG - search_datasheets / corpus"
    Ensure-OllamaModel $mf1.visionModel "describe_image - the offline UI screenshot review"
    if ($Hybrid) { Ensure-OllamaModel $draftTag "local_generate - the 5080 drudge co-processor" }
    else { Write-Host "  aliases resolve to Anthropic ids via models.json 'cloud' (add -Hybrid to also run local_generate)." -ForegroundColor Green }
  } else {
    Write-Host "  [warn] ollama not found - RAG will fall back to a LITERAL keyword scan (no GPU semantics)." -ForegroundColor Yellow
    if ($Hybrid) { Write-Host "  [warn] hybrid needs Ollama for local_generate; install Ollama.Ollama, then re-run install.cmd -Hybrid." -ForegroundColor Yellow }
  }
} elseif ($haveOllama) {
  if ($sandbox) {
    Write-Host "  SKIP (sandbox): sync-models.ps1 (ollama pull / ollama create write the machine-wide Ollama model store)" -ForegroundColor Yellow
  } else {
  try { & (Join-Path $root "sync-models.ps1") }
  catch { Write-Host "  (sync-models failed: $($_.Exception.Message) - run sync-models.cmd manually)" -ForegroundColor Yellow }
  }
} else {
  Write-Host "  [warn] -Local needs Ollama, which was not found: install it (winget install Ollama.Ollama), then re-run install.cmd -Local." -ForegroundColor Yellow
  Write-Host "  skipped (need ollama)" -ForegroundColor Yellow
}

Write-Host "`n== 3) Claude Code engine + VS Code extension ==" -ForegroundColor Cyan
if (-not $haveNode) { Write-Host "  [warn] node missing - install Claude Code manually" -ForegroundColor Yellow }
else {
  # R40(a): report first; npm install runs ONLY inside a consent branch, at most once.
  $ccInstalled = Get-HarnessVersion claude
  $ccLatest = Get-LatestVersion "@anthropic-ai/claude-code"
  Write-HarnessReport -Name "claude-code" -Installed $ccInstalled -Latest $ccLatest -Measured $ClaudeCodeMeasuredVersion
  $ccUpdated = $false
  $ccPrevious = $ccInstalled   # captured BEFORE any npm install (T17.4: the way-back version)
  if (-not $ccInstalled) {
    if ($sandbox) { Write-Host "  SKIP (sandbox): npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow }
    else {
    if (Read-Consent "  install Claude Code now? [Y/n]" $true) { npm install -g @anthropic-ai/claude-code; $ccUpdated = $true }
    }
  } elseif ($ccLatest -and ((Compare-HarnessVersion $ccInstalled $ccLatest) -lt 0)) {
    Write-Host "  [harness] update available: $ccInstalled -> $ccLatest"
    if ($sandbox) { Write-Host "  SKIP (sandbox): npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow }
    else {
    if (Read-Consent "  update now? [y/N]" $false) { npm install -g @anthropic-ai/claude-code; $ccUpdated = $true }
    }
  }
  if ($ccUpdated) {
    $ccNow = Get-HarnessVersion claude
    if ($ccNow) { Write-HarnessReport -Name "claude-code" -Installed $ccNow -Latest $ccLatest -Measured $ClaudeCodeMeasuredVersion }
    # T17.4: post-update smoke (only when an update ran). Loud, never blocking: exit code stays 0.
    if (Get-Command Invoke-PostUpdateSmoke -ErrorAction SilentlyContinue) { $null = Invoke-PostUpdateSmoke -Name "claude-code" -Previous $ccPrevious -Package "@anthropic-ai/claude-code" }
  }
}
if ($haveCode) { if ($sandbox) { Write-Host "  SKIP (sandbox): code --install-extension anthropic.claude-code" -ForegroundColor Yellow } else { code --install-extension anthropic.claude-code } } else { Write-Host "  [warn] 'code' CLI missing - install the Claude Code extension from the VS Code marketplace" -ForegroundColor Yellow }

Write-Host "`n== 4) Build the C# local-tools server ==" -ForegroundColor Cyan
if ($sandbox) { Write-Host "  SKIP (sandbox): dotnet build" -ForegroundColor Yellow }
elseif ($haveDotnet) { dotnet build (Join-Path $root "local-tools\local-tools.csproj") -c Release }
else { Write-Host "  skipped (need .NET SDK)" -ForegroundColor Yellow }

Write-Host "`n== 5) Point .mcp.json files at this folder ==" -ForegroundColor Cyan
# Edit JSON via parse/serialize (NOT string-replace): JSON doubles backslashes, and this sets the
# path deterministically, so it is correct, idempotent, and works even if the folder was moved.
$exe = Join-Path $root "local-tools\bin\Release\net8.0\local-tools.exe"
if ($sandbox) {
  Write-Host "  SKIP (sandbox): .mcp.json rewrite" -ForegroundColor Yellow
} else {
foreach ($rel in @(".mcp.json","templates\_common\.mcp.json","templates\unity\.mcp.json")) {
  $p = Join-Path $root $rel
  if (-not (Test-Path $p)) { continue }
  $j = Get-Content $p -Raw | ConvertFrom-Json
  $j.mcpServers.'local-tools'.command = $exe
  # Only the dev/root .mcp.json keeps its corpus under the kit (its own docs\); templates keep the placeholder.
  if ($rel -eq ".mcp.json") {
    $j.mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR = (Join-Path $root "docs")
  }
  Write-NoBom $p ($j | ConvertTo-Json -Depth 10)
  Write-Host "  fixed $rel"
}
}

Write-Host "`n== 6) Install global commands + agents to $claude ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force (Join-Path $claude "commands") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $claude "agents")   | Out-Null

# Remove RETIRED names first. Renames would otherwise leave the old command installed alongside the new
# one, and a model could invoke the stale copy. Keep this list append-only.
$retiredCommands = @("forge","scribe","blueprint","librarian","plan")     # 0.9.8 rename; /plan predates it
$retiredAgents   = @("planner-agent")
foreach ($r in $retiredCommands) {
  $rp = Join-Path $claude "commands\$r.md"
  if (Test-Path $rp) { Remove-Item $rp -Force; Write-Host "  removed retired /$r" -ForegroundColor Yellow }
}
foreach ($r in $retiredAgents) {
  $rp = Join-Path $claude "agents\$r.md"
  if (Test-Path $rp) { Remove-Item $rp -Force; Write-Host "  removed retired $r" -ForegroundColor Yellow }
}
Get-ChildItem (Join-Path $root "global\commands") -File | ForEach-Object {
  Write-NoBom (Join-Path $claude "commands\$($_.Name)") ((Get-Content $_.FullName -Raw -Encoding UTF8).Replace($old, $root))
}
# Agents get the SAME placeholder rewrite as commands - librarian-agent invokes doc-stats.ps1 by absolute
# path, and a plain copy would leave it pointing at the dev machine's folder.
Get-ChildItem (Join-Path $root "global\agents") -File | ForEach-Object {
  Write-NoBom (Join-Path $claude "agents\$($_.Name)") ((Get-Content $_.FullName -Raw -Encoding UTF8).Replace($old, $root))
}
Write-Host "  commands: /scaffold /research /document /design /taskmap /proto /spec /build /assets /tidy /stories /diagram /audit /grade /retro /corpus /assess   agents: requirements/architect/taskmap/dev/ui/ux/playtest/grade/scribe/hygiene/qa/doc-researcher/research/survey/security/librarian/corpus/codebase-analyst"

$mode7 = switch ($mode) { 'Hybrid' { "HYBRID: Anthropic API + local 5080 tools" } 'Cloud' { "CLOUD: Anthropic API" } default { "LOCAL: Ollama redirect + offline flags" } }
Write-Host "`n== 7) Install settings.json ($mode7) ==" -ForegroundColor Cyan
Write-Host "  MODE: $mode - $modeReason" -ForegroundColor Cyan
$dst = Join-Path $claude "settings.json"
if (Test-Path $dst) { Copy-Item $dst "$dst.bak" -Force; Write-Host "  existing settings.json -> settings.json.bak (MERGE if you had custom settings)" -ForegroundColor Yellow }
$s = Get-Content (Join-Path $root "settings.json") -Raw | ConvertFrom-Json
# settings.json carries the dev-path placeholder too, in the Stop hook's command line. Rewrite it on the
# PARSED object, not the raw text: JSON escapes backslashes, so the on-disk form is C:\\Projects\\... and
# a text replace of C:\Projects\... silently matches nothing (same trap as the .mcp.json paths above).
# Walk EVERY hook event, not just Stop. 0.19.3 added a PreToolUse hook and a Stop-only loop here would
# have installed it still pointing at the dev machine's folder - the same stale-path bug that shipped in
# three consecutive releases (guard commands, project .mcp.json, pre-commit hook).
try {
  foreach ($evt in $s.hooks.PSObject.Properties.Name) {
    foreach ($entry in $s.hooks.$evt) {
      foreach ($h in $entry.hooks) { if ($h.command) { $h.command = $h.command.Replace($old, $root) } }
    }
  }
} catch { }
# CLOUD mode: drop the Ollama redirect + token so Claude Code uses its NORMAL Anthropic auth (subscription
# or `ant auth login`), and point the model + small-fast at their cloud ids from models.json. Removing
# ANTHROPIC_BASE_URL is the whole tell - use-model and dad-doctor read its absence back as "cloud".
if ($cloudLoop) {
  $mfc = Get-Content (Join-Path $root "models.json") -Raw | ConvertFrom-Json
  $defModel = @($mfc.models | Where-Object { $_.default }) | Select-Object -First 1
  $defCloud = if ($defModel -and $defModel.cloud) { $defModel.cloud } else { "claude-sonnet-5" }
  foreach ($k in @("ANTHROPIC_BASE_URL","ANTHROPIC_AUTH_TOKEN","ANTHROPIC_API_KEY")) {
    if ($s.env.PSObject.Properties.Name -contains $k) { $s.env.PSObject.Properties.Remove($k) }
  }
  $s.env.ANTHROPIC_MODEL = $defCloud
  $s.env.ANTHROPIC_SMALL_FAST_MODEL = if ($mfc.cloudSmallFast) { $mfc.cloudSmallFast } else { "claude-haiku-4-5" }
  Write-Host "  cloud: base-URL redirect dropped; ANTHROPIC_MODEL=$defCloud (uses your normal Anthropic login)" -ForegroundColor Green
}
# HYBRID mode marker: LOCALTOOLS_HYBRID=1 in settings.json env is inherited by the local-tools MCP server
# (turning on the local_generate tool) AND is what dad-doctor reads back as "hybrid". Set it for -Hybrid,
# and REMOVE any stale copy otherwise, so re-installing as cloud or local cleanly turns the local tools off.
if ($Hybrid) {
  # settings.json's env block has NO LOCALTOOLS_HYBRID key by default - this is a NEW property, and plain
  # dot-assignment to set it can only OVERWRITE an existing PSCustomObject property, never CREATE one; it
  # throws "the property ... cannot be found on this object" when the key does not already exist. Every
  # -Hybrid install hit this. Add-Member -Force both creates it (first install) and overwrites it (re-install).
  $s.env | Add-Member -NotePropertyName "LOCALTOOLS_HYBRID" -NotePropertyValue "1" -Force
  Write-Host "  hybrid: LOCALTOOLS_HYBRID=1 (the 5080 is offered to the cloud model via the local_generate tool)" -ForegroundColor Green
} elseif ($s.env.PSObject.Properties.Name -contains "LOCALTOOLS_HYBRID") {
  $s.env.PSObject.Properties.Remove("LOCALTOOLS_HYBRID")
}
# (apiKeyHelper intentionally NOT set: ANTHROPIC_AUTH_TOKEN alone skips login; setting both
#  triggers Claude Code's "auth may not work as expected" warning every session.)
Write-NoBom $dst ($s | ConvertTo-Json -Depth 10)
Write-Host "  wrote $dst"
$hookCmd = ""
try {
  $hookCmd = ($s.hooks.PSObject.Properties.Name | ForEach-Object { $s.hooks.$_ } |
              ForEach-Object { $_.hooks } | ForEach-Object { $_.command }) -join " "
} catch { }
# 'dad-guard\.' matches the FILE, so a future sibling script named ...guard cannot satisfy this check by
# accident. ("dad-loopguard" does not contain "dad-guard", but the next one might.)
if ($hookCmd -match 'dad-guard\.') { Write-Host "  Stop hook: dad-guard.ps1 (blocks a turn ending on unverified code)" -ForegroundColor Green }
else { Write-Host "  WARNING: no Stop hook in settings.json - the close-out gates are model-optional again" -ForegroundColor Yellow }
if ($hookCmd -match 'dad-loopguard') { Write-Host "  PreToolUse hook: dad-loopguard.ps1 (breaks command loops; rejects 2>nul under Bash)" -ForegroundColor Green }
else { Write-Host "  WARNING: no PreToolUse hook - a subagent can repeat one failing command indefinitely" -ForegroundColor Yellow }

Write-Host "`n== 7b) Put the kit on PATH so `dad` works from any shell ==" -ForegroundColor Cyan
# ONE entry point, on PATH, is what makes the kit shell-neutral. `dad doc-stats` runs identically from
# Git Bash, cmd and PowerShell, so the model never picks a shell dialect for a kit operation - which is
# how one run emitted cmd's `2>nul` under bash, got an empty result with no error, and looped 920 times.
# It also means the Claude Code allow list needs ONE entry, Bash(dad:*), instead of one per script; a
# permission prompt per call is what makes agents stall and start improvising.
try {
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $userPath) { $userPath = "" }
  $already = ($userPath -split ';' | Where-Object { $_ -and ((($_.TrimEnd('\')) -ieq $root.TrimEnd('\'))) })
  if ($sandbox) {
    # Seam: record the USER Path value this step WOULD have written (NAME=value) instead of touching the registry.
    $sepS = if ($userPath -and -not $userPath.EndsWith(';')) { ';' } else { '' }
    $pathS = if ($already) { $userPath } else { "$userPath$sepS$root" }
    Write-NoBom (Join-Path $sandbox "machine-env.txt") "Path=$pathS`n"
    Write-Host "  [sandbox] USER Path recorded to $(Join-Path $sandbox 'machine-env.txt') (registry untouched)" -ForegroundColor Yellow
  } elseif ($already) {
    Write-Host "  already on PATH: $root" -ForegroundColor Green
  } else {
    $sep = if ($userPath -and -not $userPath.EndsWith(';')) { ';' } else { '' }
    [Environment]::SetEnvironmentVariable("Path", "$userPath$sep$root", "User")
    Write-Host "  added to your USER PATH: $root" -ForegroundColor Green
    Write-Host "  (open a NEW shell for it to take effect)" -ForegroundColor Yellow
  }
  $env:Path = "$env:Path;$root"       # live for the rest of this install
} catch {
  Write-Host "  could not update PATH: $($_.Exception.Message)" -ForegroundColor Yellow
  Write-Host "  add $root to PATH by hand, or call the wrappers by full path" -ForegroundColor Yellow
}

# DAD_HOME: a named handle on the kit, set as a Windows USER variable so EVERY Windows-launched shell -
# cmd, PowerShell, AND Git Bash (which inherits the Windows environment) - sees it. Projects and scripts
# can reference it without hard-coding the install path.
try {
  if ($sandbox) {
    [System.IO.File]::AppendAllText((Join-Path $sandbox "machine-env.txt"), "DAD_HOME=$root`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  [sandbox] DAD_HOME=$root recorded to $(Join-Path $sandbox 'machine-env.txt') (registry untouched)" -ForegroundColor Yellow
  } else {
  [Environment]::SetEnvironmentVariable("DAD_HOME", $root, "User")
  }
  $env:DAD_HOME = $root
  Write-Host "  set DAD_HOME=$root (User; inherited by cmd, PowerShell, and Git Bash)" -ForegroundColor Green
} catch { Write-Host "  could not set DAD_HOME: $($_.Exception.Message)" -ForegroundColor Yellow }

# Git Bash reach. The Bash TOOL runs non-interactively and inherits the Windows PATH above, so a NEW
# session already finds the `dad` shim. But an INTERACTIVE Git Bash whose ~/.bashrc rewrites PATH would
# lose it - so drop an idempotent, clearly-marked, removable block there too. Bash form of the path
# (D:\x -> /d/x); written LF (a CRLF .bashrc breaks bash).
try {
  if ($sandbox) {
    $bashHome = $sandbox     # seam: the .bashrc lives under the sandbox dir, never $env:HOME
  } else {
  $bashHome = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
  }
  $bashrc = Join-Path $bashHome ".bashrc"
  $bashRoot = '/' + $root.Substring(0,1).ToLower() + ($root.Substring(2) -replace '\\','/')
  $begin = "# >>> DAD-kit >>>"; $end = "# <<< DAD-kit <<<"
  $block = "$begin`nexport DAD_HOME=`"$bashRoot`"`ncase `":`$PATH:`" in *`":`$DAD_HOME:`"*) ;; *) export PATH=`"`$DAD_HOME:`$PATH`";; esac`n$end`n"
  $existing = if (Test-Path $bashrc) { [System.IO.File]::ReadAllText($bashrc) } else { "" }
  # strip any prior managed block, then append the fresh one (idempotent)
  $stripped = [regex]::Replace($existing, "(?s)\r?\n?" + [regex]::Escape($begin) + ".*?" + [regex]::Escape($end) + "\r?\n?", "`n")
  $stripped = $stripped.TrimEnd("`r","`n")
  $out = if ($stripped) { $stripped + "`n`n" + $block } else { $block }
  [System.IO.File]::WriteAllText($bashrc, ($out -replace "`r`n","`n"), (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  updated $bashrc (DAD-kit block: exports DAD_HOME + adds it to PATH for interactive Git Bash)" -ForegroundColor Green
} catch { Write-Host "  could not update ~/.bashrc (Git Bash): $($_.Exception.Message) - not fatal; the Windows PATH already covers the Bash tool" -ForegroundColor Yellow }

if ($mode -ne 'Cloud') {
  Write-Host "`n== 8) Tune Ollama for the GPU ==" -ForegroundColor Cyan
  Write-Host "  This step sets user-scope OLLAMA_FLASH_ATTENTION, OLLAMA_KV_CACHE_TYPE and OLLAMA_KEEP_ALIVE and restarts Ollama." -ForegroundColor Yellow
  if ($sandbox) {
    Write-Host "  SKIP (sandbox): ollama-tuning.ps1 (user-scope OLLAMA_FLASH_ATTENTION / OLLAMA_KV_CACHE_TYPE / OLLAMA_KEEP_ALIVE and the Ollama restart)" -ForegroundColor Yellow
  } else {
  & (Join-Path $root "ollama-tuning.ps1")
  }
}

# GitHub Copilot CLI is a SECOND harness that runs the same two guard scripts. Opt-in, additive: the
# Claude Code wiring above is untouched, so a machine can run both.
# R40(b): report when copilot is present or opted in; ask before updating; NEVER install it when absent.
if ((Have copilot) -or $CopilotCli) {
  $cpInstalled = Get-HarnessVersion copilot
  $cpLatest = Get-LatestVersion "@github/copilot"
  Write-HarnessReport -Name "copilot-cli" -Installed $cpInstalled -Latest $cpLatest -Measured $CopilotMeasuredVersion
  if ($cpInstalled -and $cpLatest -and ((Compare-HarnessVersion $cpInstalled $cpLatest) -lt 0)) {
    Write-Host "  [harness] update available: $cpInstalled -> $cpLatest"
    if ($sandbox) { Write-Host "  SKIP (sandbox): npm install -g @github/copilot" -ForegroundColor Yellow }
    else {
    if (Read-Consent "  update Copilot CLI now? [y/N]" $false) { npm install -g @github/copilot }
    }
  }
} else {
  Write-Host "[harness] copilot-cli   skipped (not installed; use -CopilotCli to opt in)"
}
if ($CopilotCli) {
  Write-Host "`n== 9) Install GitHub Copilot CLI hooks ==" -ForegroundColor Cyan
  if (-not (Have copilot)) {
    Write-Host "  [warn] 'copilot' not on PATH - installing the hooks anyway; they activate once you" -ForegroundColor Yellow
    Write-Host "         run 'npm install -g @github/copilot' (needs Node 22+)." -ForegroundColor Yellow
  } else {
    # C2f: LOUD at setup, never at runtime. C2a-C2e are true of $CopilotMeasuredVersion and of nothing else,
    # and a harness that changed any of them breaks the gates SILENTLY - so say so here, where setup is
    # inspected. A WARN, not a stop: an unmeasured version is a known-unknown, not a known-broken.
    $cv = ""
    try { $cv = ((copilot --version 2>&1 | Out-String) -split "`n" | Select-Object -First 1).Trim() } catch { }
    # EXTRACT the version, then compare for EQUALITY. A substring/-match test is silently wrong here:
    # "1.0.890" and "11.0.89" both CONTAIN "1.0.89", so an unmeasured harness would report [ok] and C2f's
    # only drift mechanism would defeat itself - the exact silent-failure class this contract exists to stop.
    $cvNum = ""
    $vm = [regex]::Match($cv, '\d+(\.\d+)+')
    if ($vm.Success) { $cvNum = $vm.Value }
    if ($cvNum -and ($cvNum -ne $CopilotMeasuredVersion)) {
      Write-Host "  [warn] DESIGN.md contract C2 was measured against Copilot CLI $CopilotMeasuredVersion." -ForegroundColor Yellow
      Write-Host "         You are running: $cv" -ForegroundColor Yellow
      Write-Host "         Hook location, event casing and the Stop block contract may have changed - and a" -ForegroundColor Yellow
      Write-Host "         mismatch fails SILENTLY (the gate just stops firing). Re-measure C2a-C2e before" -ForegroundColor Yellow
      Write-Host "         trusting these gates. Installing anyway." -ForegroundColor Yellow
    } elseif ($cvNum) {
      Write-Host "  [ok]   Copilot CLI matches the measured contract version ($CopilotMeasuredVersion)" -ForegroundColor Green
    }
  }
  # USER-level only. Copilot CLI's DOCUMENTED repo-level location (.github/hooks/*.json) silently loads
  # nothing on 1.0.89 - measured 2026-09-29 - and its parser skips unrecognised keys without an error, so
  # an installer that followed the docs would report success and wire a hook that never fires.
  $copilotHooks = Join-Path $env:USERPROFILE ".copilot\hooks"
  New-Item -ItemType Directory -Force $copilotHooks | Out-Null
  $cdst = Join-Path $copilotHooks "dad.json"
  if (Test-Path $cdst) { Copy-Item $cdst "$cdst.bak" -Force; Write-Host "  existing dad.json -> dad.json.bak" -ForegroundColor Yellow }
  $cj = Get-Content (Join-Path $root "copilot-hooks.json") -Raw | ConvertFrom-Json
  # Same placeholder rewrite as settings.json, and for the same reason: do it on the PARSED object,
  # because JSON doubles backslashes and a text replace of C:\Projects\... matches nothing on disk.
  # Copilot puts the command under 'bash'/'powershell' keys rather than Claude Code's 'command'.
  try {
    foreach ($evt in $cj.hooks.PSObject.Properties.Name) {
      foreach ($h in $cj.hooks.$evt) {
        if ($h.bash)       { $h.bash       = $h.bash.Replace($old, $root) }
        if ($h.powershell) { $h.powershell = $h.powershell.Replace($old, $root) }
      }
    }
  } catch { }
  Write-NoBom $cdst ($cj | ConvertTo-Json -Depth 10)
  Write-Host "  wrote $cdst"
  $ccmd = ""
  try {
    $ccmd = ($cj.hooks.PSObject.Properties.Name | ForEach-Object { $cj.hooks.$_ } |
             ForEach-Object { @($_.bash) + @($_.powershell) }) -join " "
  } catch { }
  # dad-guard-copilot, NOT dad-guard: Copilot ignores exit code 2 and discards stdout with it, so
  # dad-guard.ps1 wired directly would emit the right JSON and still be ignored - the close-out gates
  # would quietly go back to being model-optional. The adapter re-emits the verdict with exit 0.
  if ($ccmd -match 'dad-guard-copilot') { Write-Host "  Stop hook: dad-guard-copilot.ps1 (adapts dad-guard's verdict to Copilot's JSON+exit-0 contract)" -ForegroundColor Green }
  else { Write-Host "  WARNING: no Copilot Stop hook - the close-out gates are model-optional under Copilot" -ForegroundColor Yellow }
  if ($ccmd -match 'dad-loopguard') { Write-Host "  PreToolUse hook: dad-loopguard.ps1 (unchanged - Copilot honors exit 2 for tool calls)" -ForegroundColor Green }
  else { Write-Host "  WARNING: no Copilot PreToolUse hook - a subagent can repeat one failing command indefinitely" -ForegroundColor Yellow }
  Write-Host "  Copilot CLI subagents ARE covered: its PreToolUse fires for a subagent's own tool calls." -ForegroundColor Cyan
  Write-Host "  RESTART Copilot CLI - it loads hooks at startup." -ForegroundColor Yellow
}

Write-Host "`n== DONE ==" -ForegroundColor Green
if ($Hybrid) {
  Write-Host "MODE = HYBRID (Anthropic API agent loop + local 5080 tools) [$modeReason]. DEFAULT = claude-sonnet-5 (alias 'dev')." -ForegroundColor Green
  Write-Host "The 5080 runs: semantic RAG (search/corpus), describe_image (UI review), AND local_generate - the" -ForegroundColor Green
  Write-Host "cloud model's drudge co-processor for implementation guesses + test data (LOCALTOOLS_HYBRID=1)." -ForegroundColor Green
  Write-Host "Switch cloud tiers with use-model: fast -> Haiku 4.5 | dev|coder|oss|gemma -> Sonnet 5 | quality -> Opus 5." -ForegroundColor Green
  Write-Host "Next: 1) make sure Claude Code is logged in (run 'claude' once if unsure) and Ollama is running." -ForegroundColor Green
  Write-Host "      2) RESTART Claude Code - hooks load at startup, and the MCP server picks up LOCALTOOLS_HYBRID." -ForegroundColor Green
  Write-Host "      3) Open a project in VS Code; the cloud model can now call local_generate for drafts + test data." -ForegroundColor Green
  Write-Host "      Verify with 'dad doctor' - it reports the local co-processor and lists local_generate." -ForegroundColor Cyan
} elseif ($mode -eq 'Cloud') {
  Write-Host "MODE = CLOUD (Anthropic API) [$modeReason]. DEFAULT = claude-sonnet-5 (alias 'dev')." -ForegroundColor Green
  Write-Host "Switch tiers with use-model:  fast -> Haiku 4.5 (cheap/bulk) | dev|coder|oss|gemma -> Sonnet 5 | quality -> Opus 5 (hard)." -ForegroundColor Green
  Write-Host "Cost: run bulk on a cheaper alias, 'use-model quality' for the hard parts; prompt caching is automatic." -ForegroundColor Cyan
  Write-Host "Your GPU is still used: local-tools RAG (search/corpus/describe_image) runs on Ollama if present." -ForegroundColor Cyan
  Write-Host "Next: 1) make sure Claude Code is logged in - it uses your normal Anthropic auth (run 'claude' once if unsure)." -ForegroundColor Green
  Write-Host "      2) RESTART Claude Code - hooks (the dad-guard stop guard) load at startup." -ForegroundColor Green
  Write-Host "      3) Open a project in VS Code, run /scaffold then index_datasheets (RAG uses Ollama if present, else a literal scan)." -ForegroundColor Green
  Write-Host "Local resilience mode: install.cmd -Local" -ForegroundColor Cyan
} else {
  Write-Host "MODE = LOCAL (Ollama redirect + offline flags) [$modeReason]" -ForegroundColor Green
  Write-Host "DEFAULT model = devstral-cc (Devstral). Switch with use-model.cmd: dev / coder / oss / fast / quality." -ForegroundColor Green
  Write-Host "Next: 1) RESTART Ollama (quit from tray, reopen) so tuning + the new models are live." -ForegroundColor Green
  Write-Host "      2) RESTART Claude Code - hooks (the dad-guard stop guard) load at startup." -ForegroundColor Green
  Write-Host "      3) Open a project folder in VS Code, run /scaffold then index_datasheets." -ForegroundColor Green
  Write-Host "      Optional pulls, then re-run: 'ollama pull gemma4' (optional dense generalist), 'ollama pull qwen3-coder-next:q4_K_M' (escalation)." -ForegroundColor Cyan
  Write-Host "Switch to the cloud with: install.cmd -Cloud" -ForegroundColor Cyan
}
