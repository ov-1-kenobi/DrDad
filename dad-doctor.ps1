# dad-doctor.ps1 - readiness check for the DAD-kit stack. Read-only: it DIAGNOSES and points at the fixer,
# it never changes anything (same split as the librarian: inspect + route).
#
# Named dad-doctor, not /doctor, because Claude Code already owns the /doctor command.
#
#   dad-doctor.ps1                       check prerequisites + the kit + the global install
#   dad-doctor.ps1 -ProjectDir C:\src\App   also check that project's wiring
#
# Exit code: 0 = no FAILs (warnings are fine), 1 = at least one FAIL.

param([string]$ProjectDir = "")
$ErrorActionPreference = "Continue"     # this script probes things that are ALLOWED to be missing
$kit = $PSScriptRoot
$script:fails = 0
$script:warns = 0
$script:fixes = New-Object System.Collections.Generic.List[string]

function Say([string]$state, [string]$what, [string]$detail = "", [string]$fix = "") {
  $color = switch ($state) { "OK" { "DarkGreen" } "WARN" { "Yellow" } "FAIL" { "Red" } default { "Gray" } }
  $pad = $what.PadRight(34)
  Write-Host ("  [{0}] {1} {2}" -f $state.PadRight(4), $pad, $detail) -ForegroundColor $color
  if ($state -eq "FAIL") { $script:fails++ } elseif ($state -eq "WARN") { $script:warns++ }
  if ($fix -and $state -ne "OK") { $script:fixes.Add($fix) }
}
function Get-Exe([string]$n) { return (Get-Command $n -ErrorAction SilentlyContinue) }
function Get-Ver([string]$n, [string]$arg = "--version") {
  $c = Get-Exe $n; if (-not $c) { return $null }
  try { return ((& $n $arg 2>$null | Out-String) -split "`n")[0].Trim() } catch { return "present" }
}

$kitVersion = if (Test-Path (Join-Path $kit "VERSION")) { (Get-Content (Join-Path $kit "VERSION") -Raw).Trim() } else { "unknown" }
Write-Host ""
Write-Host "== DAD-kit doctor ==" -ForegroundColor Cyan
Write-Host "kit: $kit  (version $kitVersion)"

# ---------------------------------------------------------------- prerequisites
Write-Host "`n-- prerequisites --" -ForegroundColor Cyan
Say "OK" "PowerShell" "$($PSVersionTable.PSVersion) on $([Environment]::OSVersion.VersionString)"

if (Get-Exe "dotnet") { Say "OK" ".NET SDK" (Get-Ver "dotnet") }
else { Say "FAIL" ".NET SDK" "not found" "winget install Microsoft.DotNet.SDK.8   (needed to build local-tools)" }

if (Get-Exe "node") { Say "OK" "Node" (Get-Ver "node") }
else { Say "FAIL" "Node" "not found" "winget install OpenJS.NodeJS.LTS   (Claude Code engine needs it)" }

if (Get-Exe "claude") { Say "OK" "claude CLI" "on PATH" }
else { Say "WARN" "claude CLI" "not on PATH" "npm install -g @anthropic-ai/claude-code" }

if (Get-Exe "code") { Say "OK" "VS Code CLI" "on PATH" }
else { Say "WARN" "VS Code 'code'" "not on PATH" "install VS Code with 'Add to PATH' (extension install needs it)" }

if (Get-Exe "git") { Say "OK" "git" (Get-Ver "git") }
else { Say "FAIL" "git" "not found" "winget install Git.Git   (checkpoints + /audit recover need it)" }

if (Get-Exe "uv") { Say "OK" "uv (optional)" (Get-Ver "uv") }
else { Say "WARN" "uv (optional)" "not found" "winget install astral-sh.uv   (only for voice.cmd + transcribe_audio)" }

# GPU - informational, drives the fit advice below
$smi = Get-Exe "nvidia-smi"
$vramGb = $null
if ($smi) {
  $q = (& nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null | Out-String).Trim()
  if ($q) {
    $parts = $q -split ","
    if ($parts.Count -ge 2 -and $parts[1] -match '(\d+)') { $vramGb = [int]([int]$Matches[1] / 1024) }
    Say "OK" "GPU" $q
  } else { Say "WARN" "GPU" "nvidia-smi gave no output" }
} else { Say "WARN" "GPU" "nvidia-smi not found (CPU-only inference will be slow)" }

# ---------------------------------------------------------------- ollama + models
Write-Host "`n-- ollama --" -ForegroundColor Cyan
$ollamaUp = $false
$installedModels = ""
if (-not (Get-Exe "ollama")) {
  Say "FAIL" "ollama" "not found" "winget install Ollama.Ollama"
} else {
  Say "OK" "ollama" (Get-Ver "ollama")
  try {
    $null = Invoke-WebRequest -Uri "http://localhost:11434/api/version" -TimeoutSec 4 -UseBasicParsing
    $ollamaUp = $true
    Say "OK" "ollama server" "responding on :11434"
  } catch {
    Say "FAIL" "ollama server" "not responding on :11434" "start Ollama (system tray), then re-run"
  }
  $installedModels = (ollama list 2>$null | Out-String)
}

$manifest = Join-Path $kit "models.json"
if (-not (Test-Path $manifest)) {
  Say "FAIL" "models.json" "missing" "restore models.json - it drives aliases + variants"
} else {
  $mf = Get-Content $manifest -Raw | ConvertFrom-Json
  Say "OK" "models.json" "$($mf.models.Count) model(s) declared, num_ctx $($mf.numCtx)"
  if ($installedModels) {
    foreach ($s in @($mf.embedModel, $mf.visionModel) | Select-Object -Unique) {
      if ($installedModels -match [regex]::Escape($s)) { Say "OK" "support model" $s }
      else { Say "WARN" "support model" "$s missing" "ollama pull $s   (RAG embeddings / describe_image)" }
    }
    $built = 0
    # Fit must include the KV cache: at numCtx 64K it adds a few GB, which is what pushes several
    # "14 GB" models over a 16 GB card. Weights-only numbers read as comfortable when they are not.
    $budget = if ($vramGb) { $vramGb } elseif ($mf.assumeVramGb) { $mf.assumeVramGb } else { 16 }
    foreach ($m in $mf.models) {
      $have = $installedModels -match [regex]::Escape($m.name)
      # Plain statements - see sync-models.ps1: a multi-line `$x = if ...` with elseif on the next
      # line parses fine and fails at RUNTIME.
      $kvGb = 0
      if ($mf.kvCacheGbAt64k) { $kvGb = $mf.kvCacheGbAt64k }
      if (($m.PSObject.Properties.Name -contains 'kvGb') -and $m.kvGb) { $kvGb = $m.kvGb }
      $effGb = $m.approxVramGb + $kvGb
      $detail = "$($m.name) (~$($m.approxVramGb) GB + ~$kvGb KV = $effGb GB vs $budget GB)"
      if (-not $have) {
        Say "WARN" "model $($m.alias)" "$($m.name) not built" "ollama pull $($m.from); sync-models.cmd -Only $($m.alias)"
      } elseif (($effGb + 1.5) -le $budget) {
        $built++; Say "OK" "model $($m.alias)" "$detail - fits GPU"
      } elseif ($effGb -le ($budget + 1)) {
        $built++
        Say "WARN" "model $($m.alias)" "$detail - BORDERLINE, partial offload likely (results may vary)" `
            "lower numCtx in models.json to 32768 to pull '$($m.alias)' back onto the GPU"
      } else {
        $built++; Say "OK" "model $($m.alias)" "$detail - offloads to RAM (expected for this size)"
      }
    }
    if ($built -eq 0) { Say "FAIL" "chat models" "none built" "sync-models.cmd   (builds every variant whose base is pulled)" }
  }
  # Ollama tuning env vars
  foreach ($v in @("OLLAMA_FLASH_ATTENTION","OLLAMA_KV_CACHE_TYPE","OLLAMA_KEEP_ALIVE")) {
    $val = [Environment]::GetEnvironmentVariable($v, "User")
    if ($val) { Say "OK" "tuning $v" $val } else { Say "WARN" "tuning $v" "unset" "run ollama-tuning.ps1, then restart Ollama" }
  }
}

# ---------------------------------------------------------------- the kit itself
Write-Host "`n-- kit --" -ForegroundColor Cyan
$exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
if (Test-Path $exe) {
  Say "OK" "local-tools.exe" "built"
  # does it actually speak MCP?
  $tools = @()
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe; $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.WriteLine('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"doctor","version":"1"}}}')
    $p.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"notifications/initialized"}')
    $p.StandardInput.WriteLine('{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
    $p.StandardInput.Flush()
    $deadline = [DateTime]::Now.AddSeconds(20)
    while ([DateTime]::Now -lt $deadline -and $tools.Count -eq 0) {
      $t = $p.StandardOutput.ReadLineAsync(); if (-not $t.Wait(6000)) { break }
      $line = $t.Result; if ($null -eq $line) { break }
      if ($line -match '"id":2') { $tools = @(($line | ConvertFrom-Json).result.tools | ForEach-Object { $_.name }) }
    }
    try { $p.Kill() } catch {}
  } catch {}
  if ($tools.Count -gt 0) { Say "OK" "MCP server" "$($tools.Count) tools: $(($tools | Sort-Object) -join ', ')" }
  else { Say "FAIL" "MCP server" "did not answer tools/list" "rebuild: dotnet build local-tools\local-tools.csproj -c Release" }
} else {
  Say "FAIL" "local-tools.exe" "not built" "run install.cmd (or: dotnet build local-tools\local-tools.csproj -c Release)"
}

$cmdCount = (Get-ChildItem (Join-Path $kit "global\commands") -Filter *.md -ErrorAction SilentlyContinue).Count
$agtCount = (Get-ChildItem (Join-Path $kit "global\agents")   -Filter *.md -ErrorAction SilentlyContinue).Count
Say "OK" "kit sources" "$cmdCount commands, $agtCount agents"

# ---------------------------------------------------------------- global install (%USERPROFILE%\.claude)
Write-Host "`n-- global install --" -ForegroundColor Cyan
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$settings = Join-Path $claudeDir "settings.json"
if (-not (Test-Path $settings)) {
  Say "FAIL" "settings.json" "not installed" "run install.cmd"
} else {
  try {
    $s = Get-Content $settings -Raw | ConvertFrom-Json
    Say "OK" "settings.json" "valid JSON"
    if ($s.env.ANTHROPIC_BASE_URL -match '11434') { Say "OK" "ANTHROPIC_BASE_URL" $s.env.ANTHROPIC_BASE_URL }
    else { Say "FAIL" "ANTHROPIC_BASE_URL" "not pointing at Ollama ('$($s.env.ANTHROPIC_BASE_URL)')" "re-run install.cmd" }

    $model = $s.env.ANTHROPIC_MODEL
    if ($installedModels -and $model -and ($installedModels -match [regex]::Escape($model))) {
      Say "OK" "ANTHROPIC_MODEL" "$model (present in Ollama)"
    } elseif ($model) {
      Say "WARN" "ANTHROPIC_MODEL" "$model not found in ollama list" "use-model.cmd <alias>, or sync-models.cmd to build it"
    }
    if ($s.PSObject.Properties.Name -contains 'apiKeyHelper' -and $s.env.ANTHROPIC_AUTH_TOKEN) {
      Say "WARN" "auth" "apiKeyHelper AND ANTHROPIC_AUTH_TOKEN both set" "remove apiKeyHelper - the token alone is enough (avoids a startup warning)"
    } else { Say "OK" "auth" "no conflicting auth settings" }
    if ($s.env.CLAUDE_CODE_MAX_OUTPUT_TOKENS) { Say "OK" "max output tokens" $s.env.CLAUDE_CODE_MAX_OUTPUT_TOKENS }
    else { Say "WARN" "max output tokens" "unset" "add CLAUDE_CODE_MAX_OUTPUT_TOKENS to settings env" }

    # The bug that cost a whole /build session: commands invoke close-unit.ps1 via powershell. If that is
    # not in the allow list, the call hits a permission prompt and the loop silently skips ALL bookkeeping
    # (no ticks, no story roll-ups, no checkpoint commits).
    $allowed = @($s.permissions.allow | ForEach-Object { if ($_ -match '^Bash\(([^:)]+)') { $Matches[1] } })
    if ($allowed -contains 'powershell') { Say "OK" "close-out permitted" "Bash(powershell:*) allowed" }
    else {
      Say "FAIL" "close-out NOT permitted" "/build cannot run close-unit.ps1 - bookkeeping will be skipped" `
          "re-run install.cmd (adds Bash(powershell:*)), then RESTART Claude Code"
    }
    # Same failure, wider blast radius: a run that cannot reach the shell at all cannot build or test,
    # and will happily write code for hours anyway.
    $needTools = @('dotnet','git')
    $missingTools = @($needTools | Where-Object { $allowed -notcontains $_ })
    if ($missingTools.Count -eq 0) { Say "OK" "toolchain permitted" "dotnet + git allowed" }
    else {
      Say "WARN" "toolchain NOT permitted" "missing Bash($($missingTools -join ':*, '):*)" `
          "re-run install.cmd; without these the model gets prompted on every build/test and stops trying"
    }
    if ($s.permissions.defaultMode -eq 'acceptEdits') { Say "OK" "permission mode" "acceptEdits" }
    else { Say "WARN" "permission mode" "$($s.permissions.defaultMode) - agents may stall on prompts" "set permissions.defaultMode to acceptEdits" }

    # The stop guard. Without it, every gate in the kit is one the model can decline to invoke.
    $stopCmd = ""
    try { $stopCmd = ($s.hooks.Stop | ForEach-Object { $_.hooks } | ForEach-Object { $_.command }) -join " " } catch { }
    if ($stopCmd -match 'dad-guard') {
      # Compare against THIS kit's real path, the way the .mcp.json check does. Matching on the
      # substring 'DAD-kit\dad-guard' was wrong: a correctly installed kit whose folder is simply
      # NAMED DAD-kit contains that substring too, so a healthy install got reported as broken.
      $expectedGuard = Join-Path $kit "dad-guard.ps1"
      $devPlaceholder = 'C:\Projects\Claude\MCP\DAD-kit\dad-guard.ps1'
      if ($stopCmd -like "*$expectedGuard*") {
        Say "OK" "stop guard" "dad-guard.ps1 wired as a Stop hook"
      } elseif ($stopCmd -like "*$devPlaceholder*") {
        Say "WARN" "stop guard" "still points at the dev placeholder path" "re-run install.cmd from the kit's real location"
      } else {
        Say "WARN" "stop guard" "points at another copy of the kit, not $expectedGuard" `
            "re-run install.cmd from the folder you actually want to use"
      }
    } else {
      Say "FAIL" "stop guard" "no Stop hook - nothing stops a turn ending on unverified code" `
          "re-run install.cmd, then RESTART Claude Code (hooks load at startup)"
    }
  } catch { Say "FAIL" "settings.json" "invalid JSON" "re-run install.cmd" }
}
$iCmd = (Get-ChildItem (Join-Path $claudeDir "commands") -Filter *.md -ErrorAction SilentlyContinue).Count
$iAgt = (Get-ChildItem (Join-Path $claudeDir "agents")   -Filter *.md -ErrorAction SilentlyContinue).Count
if ($iCmd -eq $cmdCount -and $iAgt -eq $agtCount) { Say "OK" "commands/agents installed" "$iCmd / $iAgt (match the kit)" }
else { Say "WARN" "commands/agents installed" "$iCmd/$iAgt vs kit $cmdCount/$agtCount" "re-run install.cmd to sync them" }

# ---------------------------------------------------------------- optional: a project
if ($ProjectDir) {
  Write-Host "`n-- project --" -ForegroundColor Cyan
  if (-not (Test-Path $ProjectDir)) { Say "FAIL" "project" "$ProjectDir not found" }
  else {
    $p = (Resolve-Path $ProjectDir).Path
    Write-Host "  $p"
    $stamp = Join-Path $p ".dad-kit-version"
    if (-not (Test-Path $stamp)) {
      $legacyStamp = Join-Path $p ".ad-kit-version"      # pre-rename projects
      if (Test-Path $legacyStamp) { $stamp = $legacyStamp }
    }
    if (Test-Path $stamp) {
      $pv = (Get-Content $stamp -Raw).Trim()
      if ($pv -eq $kitVersion) { Say "OK" "kit version" "$pv (matches the kit)" }
      else { Say "WARN" "kit version" "project built with $pv, kit is $kitVersion" "upgrade-project.cmd `"$p`"" }
    } else {
      Say "WARN" "kit version" "project is unstamped (predates 0.9.0)" "upgrade-project.cmd `"$p`""
    }
    if (Test-Path (Join-Path $p "CLAUDE.md")) {
      $cm = Get-Content (Join-Path $p "CLAUDE.md") -Raw
      Say "OK" "CLAUDE.md" "present"
      foreach ($sec in @("## Secrets","docs/STATUS.md","Task tool")) {
        if ($cm -match [regex]::Escape($sec)) { Say "OK" "CLAUDE.md has" $sec }
        else { Say "WARN" "CLAUDE.md missing" $sec "upgrade-project.cmd `"$p`"" }
      }
      if ($cm -match '<set in|<decided in') { Say "WARN" "CLAUDE.md" "Stack/Build/test still placeholders" "finish /design's architecture step" }
    } else { Say "FAIL" "CLAUDE.md" "missing" "new-project.cmd <general|experience>" }

    $mcp = Join-Path $p ".mcp.json"
    if (Test-Path $mcp) {
      try {
        $j = Get-Content $mcp -Raw | ConvertFrom-Json
        $cmd = $j.mcpServers.'local-tools'.command
        if ($cmd -eq $exe) { Say "OK" ".mcp.json" "points at this kit's exe" }
        else { Say "WARN" ".mcp.json" "exe path is '$cmd'" "re-run install.cmd (it rewrites paths)" }
        $dd = $j.mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR
        if ($dd -and (Test-Path $dd)) { Say "OK" "docs dir" $dd } else { Say "WARN" "docs dir" "'$dd' not found" }
        if ($dd -and (Test-Path (Join-Path $dd ".index\chunks.json"))) { Say "OK" "RAG index" "built" }
        else { Say "WARN" "RAG index" "not built" "run index_datasheets in a session, or reindex.cmd `"$dd`"" }
      } catch { Say "FAIL" ".mcp.json" "invalid JSON" }
    } else { Say "FAIL" ".mcp.json" "missing" "new-project.cmd / upgrade-project.cmd" }

    foreach ($d in @("DESIGN.md","TEDD.md")) { if (Test-Path (Join-Path $p "docs\$d")) { Say "OK" "design doc" "docs\$d" } }
    foreach ($d in @("STATUS.md","RECIPES.md")) {
      if (Test-Path (Join-Path $p "docs\$d")) { Say "OK" "doc" "docs\$d" }
      else { Say "WARN" "doc" "docs\$d missing" "upgrade-project.cmd `"$p`"" }
    }
    if (Test-Path (Join-Path $p ".git")) {
      Say "OK" "git repo" "present (checkpoints + recover available)"
      if (Test-Path (Join-Path $p ".git\hooks\pre-commit")) { Say "OK" "pre-commit hook" "secret scan installed" }
      else { Say "WARN" "pre-commit hook" "missing" "install-hooks.ps1 -ProjectDir `"$p`"" }
    } else { Say "FAIL" "git repo" "none - a mangled file cannot be recovered" "upgrade-project.cmd `"$p`"" }

    # A project's own allow list ACCRETES. Every "yes, just this once" writes a literal one-off entry
    # here, and a list full of them is the fingerprint of a session that spent its time answering
    # permission prompts. One real project collected ten - Bash(xargs cat), Bash(</) - and then made
    # 106 file edits without ever running a build.
    $localSettings = Join-Path $p ".claude\settings.local.json"
    if (Test-Path $localSettings) {
      try {
        $ls = Get-Content $localSettings -Raw | ConvertFrom-Json
        $bashRules = @($ls.permissions.allow | Where-Object { $_ -like 'Bash(*' })
        # A rule is "durable" if it grants a whole executable (Bash(dotnet:*)); anything else is a
        # frozen snapshot of one command line and will never match again.
        $oneOff = @($bashRules | Where-Object { $_ -notmatch '^Bash\([A-Za-z0-9_.\-]+:\*\)$' })
        if ($oneOff.Count -ge 3) {
          Say "WARN" "project allow list" "$($oneOff.Count) one-off Bash approvals accreted" `
              "delete permissions.allow in $localSettings - the kit's global list already covers dotnet/git/powershell"
        } elseif ($bashRules.Count) { Say "OK" "project allow list" "$($bashRules.Count) Bash rule(s), no clutter" }
      } catch { Say "WARN" "project allow list" "settings.local.json is not valid JSON" "fix or delete $localSettings" }
    }

    $stamp = Join-Path $p ".claude\.dad-verified"
    $guard = Join-Path $kit "dad-guard.ps1"
    if (Test-Path $guard) {
      & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $p | Out-Null
      if ($LASTEXITCODE -eq 0) { Say "OK" "stop guard state" "no unverified code changes" }
      else {
        Say "WARN" "stop guard state" "uncommitted code that nothing has built or tested" `
            "close-unit.cmd -Id <id> -Title `"...`" in that project, or dad-guard.cmd -Ack to accept it"
      }
    }
  }
}

# ---------------------------------------------------------------- summary
Write-Host ""
if ($script:fails -eq 0 -and $script:warns -eq 0) { Write-Host "== all clear ==" -ForegroundColor Green }
else { Write-Host ("== {0} fail, {1} warn ==" -f $script:fails, $script:warns) -ForegroundColor $(if ($script:fails) { "Red" } else { "Yellow" }) }
if ($script:fixes.Count) {
  Write-Host "`nSuggested next steps:" -ForegroundColor Cyan
  foreach ($f in ($script:fixes | Select-Object -Unique)) { Write-Host "  - $f" }
}
exit $(if ($script:fails) { 1 } else { 0 })
