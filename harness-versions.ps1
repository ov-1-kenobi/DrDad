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
