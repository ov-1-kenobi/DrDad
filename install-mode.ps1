# install-mode.ps1 - dot-sourced library (Story S29, contract C6). No work at load.
# Resolve-InstallMode is PURE: it reads $SettingsPath (only when no flag is given), and writes
# and prints nothing. install.ps1 acts on the returned object.
#
# Returns [pscustomobject] Mode ('Cloud'|'Local'|'Hybrid', $null on conflict),
#   Reason ('default'|'kept'|'explicit'), ReasonText, Conflict (string|$null), Warn (string|$null).

function Resolve-InstallMode {
  param([bool]$LocalFlag, [bool]$CloudFlag, [bool]$HybridFlag, [string]$SettingsPath)

  $mode = $null; $reason = 'default'; $conflict = $null; $warn = $null

  if ($LocalFlag -and ($CloudFlag -or $HybridFlag)) {
    if ($CloudFlag -and $HybridFlag) { $conflict = '-Local conflicts with -Cloud and -Hybrid' }
    elseif ($HybridFlag)             { $conflict = '-Local conflicts with -Hybrid' }
    else                             { $conflict = '-Local conflicts with -Cloud' }
    return [pscustomobject]@{ Mode = $null; Reason = $null; ReasonText = $null; Conflict = $conflict; Warn = $null }
  }

  if ($HybridFlag -or $CloudFlag -or $LocalFlag) {
    $reason = 'explicit'
    if ($HybridFlag)     { $mode = 'Hybrid' }
    elseif ($CloudFlag)  { $mode = 'Cloud' }
    else                 { $mode = 'Local' }
  } else {
    $mode = 'Cloud'; $reason = 'default'
    if ($SettingsPath -and (Test-Path -LiteralPath $SettingsPath)) {
      $cfg = $null; $ok = $true
      try { $cfg = Get-Content -LiteralPath $SettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
      catch { $ok = $false; $warn = "could not parse $SettingsPath - treating it as nothing to keep (Cloud)" }
      if ($ok -and $cfg -and (@($cfg.PSObject.Properties | ForEach-Object { $_.Name }) -contains 'env') -and $cfg.env) {
        $names = @($cfg.env.PSObject.Properties | ForEach-Object { $_.Name })
        if (($names -contains 'ANTHROPIC_BASE_URL') -and "$($cfg.env.ANTHROPIC_BASE_URL)") {
          $mode = 'Local'; $reason = 'kept'
        } elseif (($names -contains 'LOCALTOOLS_HYBRID') -and ("$($cfg.env.LOCALTOOLS_HYBRID)" -eq '1')) {
          $mode = 'Hybrid'; $reason = 'kept'
        }
      }
    }
  }

  $text = switch ($reason) {
    'default'  { 'default (no flag, nothing installed to keep)' }
    'kept'     { 'kept from the existing install (pass -Cloud to switch)' }
    'explicit' { 'explicit flag' }
  }
  [pscustomobject]@{ Mode = $mode; Reason = $reason; ReasonText = $text; Conflict = $null; Warn = $warn }
}
