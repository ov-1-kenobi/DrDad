# harness-versions.ps1 - dot-sourced library (S17, R40). No work at load; READS versions only.
# Never installs or changes anything. Calls claude/copilot/npm by bare name so PATH stubs work.

# Small table (not a manifest: C2f defers harnesses.json until a second non-Claude harness).
$HarnessTable = @{
  'claude-code' = @{ Cli = 'claude';  Package = '@anthropic-ai/claude-code' }
  'copilot-cli' = @{ Cli = 'copilot'; Package = '@github/copilot' }
}

function Get-HarnessVersion {
  param([string]$Cli)
  try {
    $out = & $Cli --version 2>$null | Select-Object -First 1
    if ($out -and ("$out" -match '\d+(\.\d+)+')) { return $Matches[0] }
  } catch { }
  return ""
}

function Get-LatestVersion {
  param([string]$Package, [int]$TimeoutSec = 10)
  $job = $null
  try {
    $job = Start-Job -ScriptBlock {
      param($p)
      try {
        $o = & npm view $p version 2>$null | Select-Object -First 1
        if ($LASTEXITCODE -ne 0) { return "" }
        "$o"
      } catch { "" }
    } -ArgumentList $Package
    if (-not (Wait-Job $job -Timeout $TimeoutSec)) { return "" }
    $res = Receive-Job $job 2>$null | Select-Object -First 1
    if ($res -and ("$res" -match '\d+(\.\d+)+')) { return $Matches[0] }
  } catch { }
  finally {
    if ($job) { try { Remove-Job $job -Force -ErrorAction SilentlyContinue } catch { } }
  }
  return ""
}

function Compare-HarnessVersion {
  param([string]$A, [string]$B)
  $pa = @(); $pb = @()
  if ($A) { $pa = @($A.Split('.') | ForEach-Object { [long]($_ -replace '\D', '0') }) }
  if ($B) { $pb = @($B.Split('.') | ForEach-Object { [long]($_ -replace '\D', '0') }) }
  $n = [Math]::Max($pa.Count, $pb.Count)
  for ($i = 0; $i -lt $n; $i++) {
    $x = 0; $y = 0
    if ($i -lt $pa.Count) { $x = $pa[$i] }
    if ($i -lt $pb.Count) { $y = $pb[$i] }
    if ($x -lt $y) { return -1 }
    if ($x -gt $y) { return 1 }
  }
  return 0
}

function Write-HarnessReport {
  param([string]$Name, [string]$Installed, [string]$Latest, [string]$Measured, [switch]$AskLine)
  try {
    if (-not $Installed) {
      $lat = $Latest
      if (-not $lat) { $lat = "unknown (registry unreachable)" }
      Write-Host "[harness] $Name   not installed   latest $lat"
      return
    }
    $lat = $Latest
    if (-not $lat) { $lat = "unknown (registry unreachable)" }
    $line = "[harness] $Name   installed $Installed   latest $lat   measured against $Measured"
    if ($Latest -and (Compare-HarnessVersion $Installed $Latest) -eq 0) { $line += "   (current)" }
    Write-Host $line
    if ($AskLine -and $Latest -and (Compare-HarnessVersion $Installed $Latest) -lt 0) {
      Write-Host "[harness]   update available - update now? [y/N]"
    }
    if ($Measured -and (Compare-HarnessVersion $Installed $Measured) -gt 0) {
      Write-Host "[harness] $Name now $Installed (newer than measured $Measured) - re-check: hooks/payload (C2, T9.5), usage fields (C4a), local model catalog" -ForegroundColor Yellow
    }
  } catch { }
}

# ---- T17.4 / R40(d): post-update smoke check and the way back ----------------------------------------
# Local-model rule, copied from the T16.1 measured record (grades/S16_GRADE.md, "Recommendation for
# /design"): "local model resolves" = `claude -p "<tiny prompt>" --max-turns 1 --model <-cc name>
# --output-format json` with per-process env ANTHROPIC_BASE_URL=http://localhost:11434 and a dummy
# ANTHROPIC_AUTH_TOKEN, ideally `--setting-sources project,local` so the user settings.json env cannot
# override, exits 0 with a non-empty result and `modelUsage` keyed by the -cc name. The
# probe's stderr is captured and an `unrecognized_model` warning is PRINTED as a WARN (never a FAIL). Probe only when Ollama is reachable, otherwise SKIP
# (reported as skipped, never as a pass). Per-process env only: settings.json / use-model state / any
# security setting is never touched.
# Test hook: env DAD_SMOKE_LOCALMODEL = pass | fail | skip forces the outcome (stubs in tests).
# Test hook: env DAD_SMOKE_OLLAMA = up | down forces Ollama reachability (no request is made).
function Test-LocalModelResolves {
  param([string]$ModelsJson = "")
  $res = { param($r, $ok, $why) [pscustomobject]@{ Result = $r; Ok = $ok; Reason = $why } }
  $force = "$env:DAD_SMOKE_LOCALMODEL"
  if ($force -eq "pass") { return (& $res "PASS" $true "forced pass (test hook)") }
  if ($force -eq "fail") { return (& $res "FAIL" $false "local model did not resolve (forced by test hook)") }
  if ($force -eq "skip") { return (& $res "SKIP" $false "skipped (forced by test hook)") }
  if (-not $ModelsJson) { $ModelsJson = Join-Path $PSScriptRoot "models.json" }
  $model = ""
  try {
    $m = Get-Content $ModelsJson -Raw | ConvertFrom-Json
    $pick = @($m.models | Where-Object { $_.alias -eq "fast" }) + @($m.models) | Select-Object -First 1
    if ($pick) { $model = "$($pick.name)" }
  } catch { }
  if (-not $model) { return (& $res "SKIP" $false "skipped (no model name in models.json)") }
  $reachable = $false
  $o = "$env:DAD_SMOKE_OLLAMA"
  if ($o -eq "up") { $reachable = $true }
  elseif ($o -eq "down") { $reachable = $false }
  else {
    try {
      $null = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
      $reachable = $true
    } catch { }
  }
  if (-not $reachable) { return (& $res "SKIP" $false "skipped (Ollama not reachable at localhost:11434)") }
  $saveUrl = $env:ANTHROPIC_BASE_URL; $saveTok = $env:ANTHROPIC_AUTH_TOKEN
  try {
    $ErrorActionPreference = 'Continue'
    $errFile = [IO.Path]::GetTempFileName()
    $env:ANTHROPIC_BASE_URL = "http://localhost:11434"
    $env:ANTHROPIC_AUTH_TOKEN = "ollama"
    $raw = (& claude -p "Reply with the single word: pong" --max-turns 1 --model $model --output-format json --setting-sources project,local 2> $errFile | Out-String)
    $code = $LASTEXITCODE
    $errText = ""
    if (Test-Path $errFile) { $errText = "$(Get-Content $errFile -Raw)" }
    if ($errText -match 'unrecognized_model') { Write-Host "[harness] local model ${model}: WARN unrecognized_model (Claude Code assumes a 200000 context window; Ollama serves unknown)" -ForegroundColor Yellow }
    if ($code -ne 0) { return (& $res "FAIL" $false "claude exited $code for model $model") }
    $j = $null
    try { $j = $raw | ConvertFrom-Json } catch { }
    if (-not $j) { return (& $res "FAIL" $false "claude output was not JSON for model $model") }
    if (-not "$($j.result)".Trim()) { return (& $res "FAIL" $false "empty result from model $model") }
    $keys = @()
    if ($j.modelUsage) { $keys = @($j.modelUsage.PSObject.Properties.Name) }
    if ($keys -notcontains $model) { return (& $res "FAIL" $false "modelUsage not keyed by $model") }
    return (& $res "PASS" $true "model $model answered")
  } catch {
    return (& $res "FAIL" $false "probe error: $($_.Exception.Message)")
  } finally {
    $env:ANTHROPIC_BASE_URL = $saveUrl; $env:ANTHROPIC_AUTH_TOKEN = $saveTok
    if ($errFile) { Remove-Item $errFile -Force -ErrorAction SilentlyContinue }
  }
}

# Runs `dad gates-smoke` (dad-gates-smoke.ps1) and, for claude-code, Test-LocalModelResolves.
# Prints only; NEVER runs npm, never rolls back, never touches settings. Returns $true when passed.
# Test hook: env DAD_SMOKE_GATES = pass | fail forces the gates result.
function Invoke-PostUpdateSmoke {
  param([string]$Name, [string]$Previous, [string]$Package)
  $reason = ""
  try {
    $g = "$env:DAD_SMOKE_GATES"
    if ($g -eq "fail") { $reason = "dad gates-smoke failed (forced by test hook)" }
    elseif ($g -ne "pass") {
      $gs = Join-Path $PSScriptRoot "dad-gates-smoke.ps1"
      if (-not (Test-Path $gs)) { $reason = "dad-gates-smoke.ps1 not found" }
      else {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $gs -ProjectDir $PSScriptRoot *> $null
        if ($LASTEXITCODE -ne 0) { $reason = "dad gates-smoke exited $LASTEXITCODE" }
      }
    }
    if (-not $reason -and $Name -eq "claude-code") {
      $lm = Test-LocalModelResolves
      if ($lm.Result -eq "FAIL") { $reason = "local model: $($lm.Reason)" }
      elseif ($lm.Result -eq "SKIP") { Write-Host "[harness] $Name local-model check $($lm.Reason)" }
    }
  } catch { $reason = "smoke error: $($_.Exception.Message)" }
  if ($reason -and -not $Previous) {
    Write-Host "[harness] $Name smoke check FAILED ($reason). No previous version was installed, so there is nothing to return to." -ForegroundColor Red
    return $false
  }
  if ($reason) {
    Write-Host "[harness] $Name smoke check FAILED ($reason). Previous version was $Previous. To return to it: npm install -g $Package@$Previous" -ForegroundColor Red
    return $false
  }
  Write-Host "[harness] $Name smoke check passed"
  return $true
}
