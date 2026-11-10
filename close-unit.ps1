# close-unit.ps1 - deterministic close-out for ONE completed unit (task or story).
# Replaces a 5-step prose checklist in /build with a script, because mechanical bookkeeping is exactly
# what local models skip: tick the task box, roll the parent story up to DONE when all its tasks are
# ticked, reindex, commit, and VERIFY. Exits non-zero if anything did not actually happen.
#
# Usage (run from the project folder, or pass -ProjectDir):
#   close-unit.ps1 -Id T8.1 -Title "Add EncryptionKey to LeanHashConfig"
#   close-unit.ps1 -Id S3   -Title "Automatic GC"          (no task map: closes the story)
#   close-unit.ps1 -Id T8.1 -NoCommit -NoReindex           (bookkeeping only)
#
# Idempotent: re-running on an already-closed unit reports it and succeeds.

param(
  [Parameter(Mandatory)][string]$Id,
  [string]$Title = "",
  [string]$ProjectDir = ".",
  [string]$BuildCommand = "",
  [switch]$NoCommit,
  [switch]$NoReindex,
  [switch]$SkipVerify,
  [switch]$RequireGrade,
  [switch]$AcceptShrink,
  [string]$Reason = "",
  # A visible-surface unit that went through the ux-agent -> ui-agent design pass sets this, and the close
  # stamps "UX-reviewed:" into the commit body. That token is the deterministic proof the pass happened -
  # doc-stats -Findings flags a project with visible surfaces but no such commit, the same way it flags a
  # hand-ticked story with no "closed:close-unit" stamp. Nothing about the review goes into the docs; the
  # code and its commit are the record.
  [switch]$UxReviewed,
  [string]$UxNote = "",
  # An experience (game/sim/XR) unit that passed a HUMAN playtest sets this, and the close stamps
  # "Playtested:" into the commit body. Feel is the part automated tests cannot reach, so the sign-off is
  # recorded rather than assumed - doc-stats -Findings flags an experience with a build but no such commit.
  [switch]$Playtested,
  [string]$PlaytestNote = ""
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$proj = (Resolve-Path -LiteralPath $ProjectDir).Path
$notes = New-Object System.Collections.Generic.List[string]
$problems = New-Object System.Collections.Generic.List[string]
$warns = New-Object System.Collections.Generic.List[string]

# Gate log (DESIGN C3/C3b, gate "close-unit-refusal"): one line per verdict via dad-gates-log.ps1, into the
# project's grades\gates-log.jsonl. Fail-open: logging never changes a verdict or exit code. -SkipVerify (the
# human's unverified escape hatch) does not log. Empty args are omitted (a native call drops them); the
# reason is flattened, quote-swapped and capped before the native call.
$script:allowLogged = $false
# NOTE: arg-cleanup here is deliberately duplicated in ratchet.ps1, close-unit.ps1, dad-guard.ps1, dad-loopguard.ps1 (hot path, no shared dot-source); keep the four copies in sync.
function Write-GateLog([string]$decision, [string]$why) {
  if ($SkipVerify) { return }
  try {
    $why = ([regex]::Replace([string]$why, '\s+', ' ')).Replace([string][char]34, "'").Trim()
    if ($why.Length -gt 300) { $why = $why.Substring(0, 300) }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "dad-gates-log.ps1") -ProjectDir $proj -Gate "close-unit-refusal" -Decision $decision -Reason $why 2>$null | Out-Null
  } catch { }
}

# Pull a command out of CLAUDE.md's "## Build / test" block ("Build" or "Test").
function Get-ClaudeCommand([string]$kind) {
  $cm = Join-Path $proj "CLAUDE.md"
  if (-not (Test-Path $cm)) { return "" }
  $raw = Get-Content $cm -Raw
  # Prefer the backtick-quoted command when the line has one. A model routinely appends trailing prose
  # after the closing backtick (e.g. "- Build: `npm run build` (root workspace)") - the old single regex
  # required only whitespace after the closing backtick, so that trailing text made the WHOLE line fail
  # to match and silently returned "". Match the backtick span on its own first; only if the line carries
  # no backticks at all, fall back to the rest of the line, trimmed.
  $m = [regex]::Match($raw, "(?m)^\s*-\s*\*{0,2}$kind\*{0,2}\s*:\s*``([^``\r\n]+)``")
  if (-not $m.Success) {
    $m = [regex]::Match($raw, "(?m)^\s*-\s*\*{0,2}$kind\*{0,2}\s*:\s*([^\r\n]+?)\s*$")
  }
  if (-not $m.Success) { return "" }
  $v = $m.Groups[1].Value.Trim()
  if ($v -match '^<' -or $v -match 'set in .design') { return "" }   # unfilled placeholder
  return $v
}

# Run a command in a CHILD shell (never Invoke-Expression: a string containing 'exit' would kill us).
function Invoke-Verify([string]$cmd) {
  Push-Location $proj
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try   { $out = (cmd /c "$cmd" | Out-String); $code = $LASTEXITCODE }
  catch { $out = $_.Exception.Message; $code = 1 }
  finally { $ErrorActionPreference = $prevEap; Pop-Location }
  return [pscustomobject]@{ Output = $out; Code = $code }
}

# A file-lock build failure where the locked OUTPUT is already newer than every source input means the
# build output is current (a running app holds it; nothing changed) - killing that app would be pointless.
# True only when $lockedPath exists AND no source file under $projDir (excluding bin/ obj/ .git/ _tmp/)
# has a LastWriteTime newer than it.
function Test-BuildOutputCurrent([string]$lockedPath, [string]$projDir) {
  if (-not $lockedPath -or -not (Test-Path -LiteralPath $lockedPath -PathType Leaf)) { return $false }
  $stamp = (Get-Item -LiteralPath $lockedPath).LastWriteTime
  $root = (Resolve-Path -LiteralPath $projDir).Path.TrimEnd('\','/')
  $inc = '*.cs','*.csproj','*.props','*.targets','*.razor','*.xaml'
  $files = Get-ChildItem -LiteralPath $root -Recurse -File -Include $inc -ErrorAction SilentlyContinue
  foreach ($f in $files) {
    $rel = $f.FullName.Substring($root.Length).TrimStart('\','/')
    $segs = @($rel -split '[\\/]')
    if ($segs.Count -gt 1 -and (@($segs[0..($segs.Count - 2)]) | Where-Object { $_ -in 'bin','obj','.git','_tmp' })) { continue }
    if ($f.LastWriteTime -gt $stamp) { return $false }
  }
  return $true
}

function Show-Tail([string]$text) {
  foreach ($l in ($text -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 15)) {
    Write-Host "    $l" -ForegroundColor DarkYellow
  }
}

# When the build fails on a SIGNATURE error, hand over the real signature instead of leaving the model to
# go find it. This is the whole point of the API surface being mechanical rather than advisory: runA
# made ZERO search_datasheets calls, so a registry the model has to remember to consult is worth nothing.
# The compiler already names the type and member it could not resolve - we just look them up.
function Show-Signatures([string]$buildOutput) {
  # .claude\ since 0.60.0; a legacy docs\ copy still answers until the next successful build replaces it.
  $api = Join-Path $proj ".claude\API-SURFACE.md"
  if (-not (Test-Path $api)) { $api = Join-Path $proj "docs\API-SURFACE.md" }
  if (-not (Test-Path $api)) { return }
  # CS1501 no overload takes N args | CS1061/CS0117 no such member | CS7036 missing required parameter
  # | CS1503 argument type | CS0246 type not found. All of them quote the identifier in 'single quotes'.
  $names = New-Object System.Collections.Generic.HashSet[string]
  foreach ($m in [regex]::Matches($buildOutput, "error CS(?:1501|1061|0117|7036|1503|0246|1729|0029)[^\r\n]*")) {
    foreach ($q in [regex]::Matches($m.Value, "'([A-Za-z_][A-Za-z0-9_.<>]{2,})'")) {
      $n = $q.Groups[1].Value
      if ($n -match '\.') { $n = ($n -split '\.')[-1] }          # 'Foo.Bar(...)' -> Bar
      $n = ($n -split '[<(]')[0]
      if ($n.Length -ge 3) { [void]$names.Add($n) }
    }
  }
  if ($names.Count -eq 0) { return }
  $script = Join-Path $kit "api-surface.ps1"
  if (-not (Test-Path $script)) { return }
  Write-Host ""
  Write-Host "[close-unit] REAL SIGNATURES for what the compiler could not resolve (dad api-surface -Lookup <Name>):" -ForegroundColor Cyan
  $shown = 0
  foreach ($n in ($names | Select-Object -First 6)) {
    $hit = & powershell -NoProfile -ExecutionPolicy Bypass -File $script -ProjectDir $proj -Lookup $n 2>$null
    if ($LASTEXITCODE -eq 0 -and $hit) {
      Write-Host "  --- $n ---" -ForegroundColor Cyan
      $hit | Select-Object -First 12 | ForEach-Object { Write-Host "  $_" }
      $shown++
    }
  }
  if ($shown -eq 0) {
    Write-Host "  (nothing matched - the identifier may be yours and not yet built, or misspelled)" -ForegroundColor DarkGray
  } else {
    Write-Host "  Use these EXACTLY. Do not guess an overload - this list came out of the compiled assembly." -ForegroundColor Cyan
  }
}

# An ENVIRONMENT block is not a code failure, and the difference matters enormously to what happens next.
# Measured: qa-agent hit Windows App Control refusing to run the built test DLL, and - with no instruction
# for this case - spent the session trying to STOP the Application Identity service, add Defender
# exclusions, and disable AppLocker/WDAC. That is the worst possible response: it attacks the machine's
# security instead of reporting a wall it cannot (and must not) climb. A build/test failure that carries
# one of these signatures is environmental. Say so loudly, tell the human it is THEIRS to resolve, and
# forbid the security-tampering path in the same breath. Returns $true if it printed a block notice.
function Show-EnvBlock([string]$output) {
  $sig = '(?i)(App ?Control|AppLocker|WDAC|Windows Defender Application|Smart App Control|' +
         'not permitted to (run|load)|blocked by (group |)policy|0x800704C8|0x80070005|' +
         'ERROR_ACCESS_DENIED|program is blocked by group policy|this program is blocked|' +
         'operation.{0,20}not permitted|access is denied.{0,40}\.dll)'
  if ($output -notmatch $sig) { return $false }
  Write-Host ""
  Write-Host "[close-unit] THIS IS AN ENVIRONMENT BLOCK, NOT A CODE FAILURE." -ForegroundColor Magenta
  Write-Host "  Windows refused to run the built assembly (App Control / AppLocker / a policy / access denied)." -ForegroundColor Magenta
  Write-Host "  The code may be fine; the machine will not execute it as configured." -ForegroundColor Magenta
  Write-Host ""
  Write-Host "  DO NOT attempt to work around this. Specifically, DO NOT:" -ForegroundColor Yellow
  Write-Host "    - stop or disable any service (Application Identity / AppIDSvc, etc.)" -ForegroundColor Yellow
  Write-Host "    - add Windows Defender exclusions or change Defender settings" -ForegroundColor Yellow
  Write-Host "    - modify AppLocker / WDAC / Smart App Control policy" -ForegroundColor Yellow
  Write-Host "    - relaunch as administrator to force it through" -ForegroundColor Yellow
  Write-Host "  Changing a machine's security posture is the HUMAN's decision, never the agent's, and a" -ForegroundColor Yellow
  Write-Host "  local model has no way to judge whether it is safe. Trying it is how a run does real harm." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  STOP and report to the human: 'the build is blocked by Windows App Control / policy - this" -ForegroundColor Cyan
  Write-Host "  is an environment decision only you can make.' Then wait. The unit is NOT closed, but nothing" -ForegroundColor Cyan
  Write-Host "  is wrong with the code, so do not 'fix' it." -ForegroundColor Cyan
  return $true
}

# How many tests actually ran? -1 = could not tell. A story must never close on 0 or unknown: mediamotor
# had six test projects missing from the .sln, so 'dotnet test' printed "Build succeeded" and ran NOTHING.
# Each pattern takes its LAST match: runners print their totals at the END, so earlier "N passed" text (a
# test NAME, a log line) must not win. 2026-10-01: a test named "...; 0 passed refuses" printed on a PASS
# line made first-match read 0 and refuse a green 243-test run (T21.3).
function Get-TestCount([string]$out) {
  foreach ($rx in @('(?im)^\s*Total:\s*(\d+)', '(?i)Total tests:\s*(\d+)', '(?i)Tests run:\s*(\d+)',
                    '(?i)(\d+)\s+passed', '(?i)Passed:\s*(\d+)', '(?i)(\d+)\s+test\(s\)')) {
    $ms = [regex]::Matches($out, $rx)
    if ($ms.Count -gt 0) { return [int]$ms[$ms.Count - 1].Groups[1].Value }
  }
  # "No test matches the given testcase filter" is dotnet's exit-0 answer to a --filter that selects nothing.
  if ($out -match '(?i)(no tests? (were run|to run|ran|available)|zero tests|found 0 test|no test matches)') { return 0 }
  return -1
}

# A grade card must be a real assessment, not a stub. Same thresholds the /build gate uses.
# GRANDFATHER DECISION (S18): the citation checks below run only inside `close-unit -RequireGrade` at the
# moment a story is closed. They never rescan grades\, so the existing cards S1_GRADE.md..S12_GRADE.md are
# grandfathered and need NO backfill; doc-stats is unchanged (it only checks a card exists). A re-grade of
# an old story does go through the new check.
function Test-GradeCard([string]$unitId) {
  $card = Join-Path $proj "grades\$($unitId)_GRADE.md"
  if (-not (Test-Path $card)) { return "no grade card (grades\$($unitId)_GRADE.md)" }
  $len = (Get-Item $card).Length
  if ($len -lt 800) { return "grade card is a stub ($len bytes, needs >=800)" }
  if (-not (Select-String -Path $card -Pattern '##\s*Grade history' -Quiet)) { return "grade card has no '## Grade history'" }
  $text = Get-Content $card -Raw -Encoding UTF8
  $cites = $false
  # file:line citations: every one must resolve; report the first failure only.
  $fileLineRx = '([\w./\\-]+\.(ps1|cmd|md|cs|json|py|ts|js|yml|yaml|csproj|sln)):(\d+)(?:-(\d+))?'
  foreach ($m in [regex]::Matches($text, $fileLineRx)) {
    $rel = $m.Groups[1].Value
    $n = [int]$m.Groups[3].Value
    if ($m.Groups[4].Success) { $n = [Math]::Max($n, [int]$m.Groups[4].Value) }
    $target = Join-Path $proj ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
      $leaf = Split-Path $rel -Leaf
      $hits = @(Get-ChildItem -Path $proj -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName.Substring($proj.Length) -notmatch '(?i)[\\/](\.git|_tmp|bin|obj|node_modules)[\\/]' })
      if ($hits.Count -eq 1) { $target = $hits[0].FullName } else { return "grade card cites missing file $rel" }
    }
    $count = @(Get-Content -LiteralPath $target -Encoding UTF8).Count
    if ($n -gt $count) { return "grade card cites $rel`:$n but the file has $count lines" }
    $cites = $true
  }
  $tk = Join-Path $proj "test-kit.ps1"
  if (-not $cites -and (Test-Path $tk)) {
    if ($text -match 'test-kit\.ps1:\d+') { $cites = $true }
    else {
      foreach ($tm in [regex]::Matches((Get-Content $tk -Raw -Encoding UTF8), '(?m)^\s*Test-Case\s+"([^"]+)"')) {
        $nm = [regex]::Escape($tm.Groups[1].Value)
        if ($text -match ('`' + $nm + '`') -or $text -match ('"' + $nm + '"')) { $cites = $true; break }
      }
    }
  }
  if (-not $cites) { return 'grade card cites no test name, test-kit.ps1 line range or resolvable file:line (expected form: test-kit.ps1:<n>, or a backtick/double-quoted Test-Case name, or a full-relative-path file:line such as global/commands/build.md:150)' }
  # 0.61.0 (issue 5 option A): the card must carry the machine-made close evidence, and obey its cap.
  # The grader has no shell: it cannot see a red suite, and one project's cards read "code-review only" on
  # stories whose closes had just failed their tests - 40 cards, nothing below B+. So close-unit writes the
  # facts (grades\<id>_EVIDENCE.md) and the card has to QUOTE them. Only for a story that has such a file:
  # stories closed by an older kit, and their cards, are not re-judged.
  $evFile = Join-Path $proj "grades\$($unitId)_EVIDENCE.md"
  # (An evidence file written by THIS very run postdates the card being checked - nothing could have quoted it yet.)
  if ((Test-Path -LiteralPath $evFile) -and $script:evidenceFresh -ne $unitId) {
    $evLine = @([System.IO.File]::ReadAllLines($evFile) | Where-Object { $_ -match '^Evidence \(close-unit' }) | Select-Object -First 1
    if ($evLine) {
      $norm = { param($t) ([regex]::Replace([string]$t, '\s+', ' ')).Trim() }
      if (-not (& $norm $text).Contains((& $norm $evLine))) {
        return "grade card does not quote the close evidence - copy this line from grades\$($unitId)_EVIDENCE.md into the card's Assessment, unchanged: $evLine"
      }
      $capM = [regex]::Match($evLine, 'grade cap:\s*([A-F][+-]?)')
      if ($capM.Success) {
        $rank = @{ "A+"=1;"A"=2;"A-"=3;"B+"=4;"B"=5;"B-"=6;"C+"=7;"C"=8;"C-"=9;"D+"=10;"D"=11;"D-"=12;"F"=13 }
        $gm = [regex]::Match($text, '(?im)^\s*\**\s*Current grade:\s*\**\s*([A-F][+-]?)')
        if ($gm.Success -and $rank.ContainsKey($gm.Groups[1].Value) -and $rank[$gm.Groups[1].Value] -lt $rank[$capM.Groups[1].Value]) {
          return "grade $($gm.Groups[1].Value) is above the cap $($capM.Groups[1].Value) set by the close evidence ($evLine) - a story whose closes were blocked for failing tests, or that has open findings, is not an A"
        }
      }
    }
  }
  return $null
}

# --- the close EVIDENCE for a story that just rolled up (issue 5 option A) ----------------------
# Facts only, computed here: what the story tests did at this close, how often closes of this story's
# units were blocked for failing tests or a failing build (from the gate log), and which open doc-stats
# findings name the story. A grade above B is not available to a story with test-failure blocks or open
# findings. Written once, when the story turns DONE, so the card can quote a line that will not change.
function Write-StoryEvidence([string]$storyId, [string]$testLine) {
  $ids = @($storyId)
  if (Test-Path $tasksFile) {
    foreach ($ln in (Get-Content $tasksFile -Encoding UTF8)) {
      if ($ln -match '^###\s*\[[ x]\]\s*([A-Za-z0-9._-]+)' -and $ln -match ('\(Story\s+' + [regex]::Escape($storyId) + '\)')) {
        $ids += ([regex]::Match($ln, '^###\s*\[[ x]\]\s*([A-Za-z0-9._-]+)')).Groups[1].Value
      }
    }
  }
  $testBlocks = New-Object System.Collections.Generic.List[string]
  $buildBlocks = 0
  $glog = Join-Path $proj "grades\gates-log.jsonl"
  if (Test-Path -LiteralPath $glog) {
    foreach ($ln in [System.IO.File]::ReadAllLines($glog)) {
      if ($ln -notmatch '"gate":"close-unit-refusal","decision":"block"') { continue }
      $rm = [regex]::Match($ln, '"ts":"([^"]*)".*"reason":"((?:story )?([A-Za-z0-9._-]+) not closed: ([^"]*))"')
      if (-not $rm.Success -or $ids -notcontains $rm.Groups[3].Value) { continue }
      if ($rm.Groups[4].Value -match 'tests failed|tests ran zero|no evidence tests ran') { $testBlocks.Add("$($rm.Groups[1].Value)  $($rm.Groups[2].Value)") }
      elseif ($rm.Groups[4].Value -match '^build failed') { $buildBlocks++ }
    }
  }
  $found = New-Object System.Collections.Generic.List[string]
  try {
    $fo = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $proj -Findings 2>$null | Out-String)
    $idRx = '\b(' + (($ids | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b'
    foreach ($fl in ($fo -split "`r?`n")) {
      # Not counted: the missing grade card (it is what the grader is about to write) and "no commit
      # mentions it" (true only because THIS close has not committed yet, and for the story until its
      # story-level close - the open-story rule already enforces that one).
      if ($fl -match '^\s*\[(?!grade\])[a-z-]+\]' -and $fl -match $idRx -and $fl -notmatch 'no commit mentions it') { $found.Add($fl.Trim()) }
    }
  } catch { }
  $cap = if ($testBlocks.Count -gt 0 -or $found.Count -gt 0) { "B" } else { "none" }
  $line = "Evidence (close-unit, $(Get-Date -Format 'yyyy-MM-dd')): $testLine; closes blocked for failing tests: $($testBlocks.Count); build-failure blocks: $buildBlocks; open findings naming $($storyId): $($found.Count); grade cap: $cap"
  $out = @("# Story $storyId - close evidence (generated by close-unit - do not edit)", "",
           "The grade card for $storyId must contain the next line UNCHANGED (close-unit -RequireGrade checks it):", "",
           $line, "",
           "A grade cap of B means: this story had closes refused for failing tests, or has open findings, so it",
           "cannot be graded above B whatever the code looks like now. `"none`" means no cap.", "")
  if ($testBlocks.Count) { $out += "## Closes blocked for failing tests"; $out += @($testBlocks | Select-Object -First 20 | ForEach-Object { "- $_" }); $out += "" }
  if ($found.Count) { $out += "## Open findings naming this story"; $out += @($found | Select-Object -First 20 | ForEach-Object { "- $_" }); $out += "" }
  $evPath = Join-Path $proj "grades\$($storyId)_EVIDENCE.md"
  $gd = Split-Path $evPath -Parent
  if (-not (Test-Path $gd)) { New-Item -ItemType Directory -Path $gd -Force | Out-Null }
  [System.IO.File]::WriteAllText($evPath, (($out -join "`n").TrimEnd() + "`n"), (New-Object System.Text.UTF8Encoding($false)))
  return $evPath
}

function Save-Text([string]$path, [string[]]$lines) {
  # LF, not CRLF: both call sites (STORIES.md, TASKS.md) are `* text=auto eol=lf` per .gitattributes.
  # A hardcoded `r`n here silently re-CRLFs the whole file on every tick - invisible to git status/diff
  # (the eol=lf clean filter normalizes it away for comparison) but caught by test-kit.ps1's raw-byte
  # line-ending check. Found via self-hosting: dogfooding /build against this kit's own TASKS.md.
  [System.IO.File]::WriteAllText($path, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}

# --- stories that rolled up to DONE and still owe their story-level close (issue 14, 0.60.0) ---
# One id per line in .claude\.dad-story-open. Written when a TASK close rolls its story up, removed by the
# story-level close (`close-unit -Id <story> ... -RequireGrade`, /build step 7). Local state on purpose:
# a project closed by an older kit has no such file, so nothing it did before the upgrade is ever blocked.
$storyOpenFile = Join-Path $proj ".claude\.dad-story-open"
function Get-OpenStories {
  if (-not (Test-Path -LiteralPath $storyOpenFile)) { return @() }
  return @([System.IO.File]::ReadAllLines($storyOpenFile) | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
}
function Set-OpenStories([string[]]$ids) {
  $ids = @($ids | Where-Object { $_ } | Select-Object -Unique)
  if ($ids.Count -eq 0) { if (Test-Path -LiteralPath $storyOpenFile) { Remove-Item -LiteralPath $storyOpenFile -Force }; return }
  $dir = Split-Path $storyOpenFile -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($storyOpenFile, (($ids -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}
# Is there a commit whose message has a line starting "<id>:"? That is what a close-unit commit looks like.
function Test-UnitCommit([string]$unitId) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue) -or -not (Test-Path (Join-Path $proj ".git"))) { return $false }
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { $o = (& git -C $proj log -1 --format=%h -E --grep ("^" + [regex]::Escape($unitId) + ":") 2>$null | Out-String).Trim() }
  catch { $o = "" } finally { $ErrorActionPreference = $prevEap }
  return [bool]$o
}

# --- where are the docs? (.mcp.json wins, else <proj>\docs) ---
. (Join-Path $PSScriptRoot "docs-dir.ps1")
$docs = Resolve-DocsDir $proj
$tasksFile   = Join-Path $docs "TASKS.md"
$storiesFile = Join-Path $docs "STORIES.md"
$esc = [regex]::Escape($Id)

# --- mark a story DONE in STORIES.md (handles both the template shape and looser real-world headings) ---
function Set-StoryDone([string]$storyId) {
  if (-not (Test-Path $storiesFile)) { $problems.Add("STORIES.md not found - cannot roll up $storyId"); return }
  $lines = Get-Content $storiesFile -Encoding UTF8
  $sEsc = [regex]::Escape($storyId)
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^#{1,6}\s' -and $lines[$i] -match "\b$sEsc\b") {
      if ($lines[$i] -match '<!--\s*Status:\s*DONE\b') { $notes.Add("story $storyId already DONE"); return }
      # PROVENANCE STAMP: only close-unit writes "closed:close-unit". A model that hand-ticks a story to
      # DONE writes a bare "<!-- Status: DONE -->" without it - and doc-stats then flags that as not closed
      # by close-unit. This is the deterministic half of "only close-unit may close a story": close-unit
      # reaches here only after the build passed, the story's tasks are all [x], and a commit was made.
      if ($lines[$i] -match '<!--\s*Status:.*?-->') {
        $lines[$i] = [regex]::Replace($lines[$i], '<!--\s*Status:.*?-->', '<!-- Status: DONE closed:close-unit -->')
      } else {
        $lines[$i] = $lines[$i].TrimEnd() + "   <!-- Status: DONE closed:close-unit -->"
      }
      Save-Text $storiesFile $lines
      $notes.Add("story $storyId -> DONE (all its tasks are [x], stamped closed:close-unit)")
      $script:storyFlipped = $storyId        # this run turned the story DONE (issue 5: write its evidence)
      return
    }
  }
  $problems.Add("story $storyId not found in STORIES.md")
}

# --- 0) VERIFY THE BUILD before touching any bookkeeping ---
# Learned the hard way: a project once had 5 stories marked DONE, 6 tasks ticked and 4 checkpoint commits
# while `dotnet build` failed with 21 errors and NO tests had ever run (the test projects were not even in
# the .sln). Ticking a box over a broken build manufactures confident green state - refuse to do it.
# Will this close COMPLETE a story? Work it out BEFORE mutating anything, so tests can gate it.
$predictedStory = $null
$myTaskStory = $null          # set only for a TASK close: the story that task belongs to
if ((Test-Path $tasksFile) -and (Select-String -Path $tasksFile -Pattern "^###\s*\[[ x]\]\s*$esc\b" -Quiet)) {
  $taskLines = @(Get-Content $tasksFile -Encoding UTF8 | Where-Object { $_ -match '^###\s*\[[ x]\]' })
  $mine = $taskLines | Where-Object { $_ -match "^###\s*\[[ x]\]\s*$esc\b" } | Select-Object -First 1
  if ($mine -and $mine -match '\(Story\s+([A-Za-z0-9._-]+)\)') {
    $st = $Matches[1]
    $myTaskStory = $st
    $open = @($taskLines | Where-Object {
      $_ -match '^###\s*\[ \]' -and $_ -match ('\(Story\s+' + [regex]::Escape($st) + '\)') })
    # This task is the last one open - or it is already ticked and NOTHING is open. (Until 0.60.0 this was
    # just "$open.Count -le 1", which also matched an already-ticked task with one OTHER task still open:
    # a re-run then ran the whole story suite and, worse, named a story this close would not roll up.)
    $mineOpen = ($mine -match '^###\s*\[ \]')
    if (($mineOpen -and $open.Count -le 1) -or (-not $mineOpen -and $open.Count -eq 0)) { $predictedStory = $st }
  }
}
elseif ((Test-Path $storiesFile) -and (Select-String -Path $storiesFile -Pattern "\b$esc\b" -Quiet)) {
  $predictedStory = $Id
}

# --- 0a) is a story marked DONE on disk that close-unit did not close? (issue 2, 0.60.0) ---------
# close-unit commits with `git add -A`, so a "Status: DONE" typed into STORIES.md by hand - or left there
# by an earlier close whose commit failed - would be banked by THIS close under an unrelated id. That is
# how a story whose close had just failed its tests ended up DONE in history. Refuse before doing anything.
# The one story this run may itself roll up ($predictedStory, which gets the story tests below) is exempt.
$statusGuard = Join-Path $kit "dad-status-guard.ps1"
if ((Test-Path $statusGuard) -and (Test-Path (Join-Path $proj ".git"))) {
  $sgArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $statusGuard, "-ProjectDir", $proj, "-WorkingTree")
  if ($predictedStory) { $sgArgs += @("-AllowStory", $predictedStory) }
  $sgOut = (& powershell @sgArgs | Out-String)
  if ($LASTEXITCODE -eq 1) {
    Write-Host "[close-unit] A STORY IS MARKED DONE BY HAND - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
    Write-Host ($sgOut.TrimEnd())
    Write-GateLog "block" "$Id not closed: a story Status marker was set to DONE outside close-unit"
    exit 1
  }
}

# --- 0g) recurring grader suggestions: warn, and hold the 6th story close for /retro (issue 6 A+C) --
# A suggestion the grader makes on card after card is a convention problem, and nothing turned it into
# work: one project had the same refactor suggested on five consecutive cards. /retro exists for exactly
# this and was never run. So at every story roll-up: list the suggestions that recur on 3+ cards (WARN);
# and when they exist AND five stories have closed since the last recorded retro, refuse this roll-up
# until /retro has run (it ends with `dad grade-trends -RecordRetro`). No recurring suggestion = no gate.
$retroWarn = @()
if ($predictedStory -and -not $SkipVerify) {
  $rollsUpNow = $true
  if (Test-Path $storiesFile) {
    $rollsUpNow = -not [bool](Get-Content $storiesFile -Encoding UTF8 | Where-Object {
      $_ -match '^#{1,6}\s' -and $_ -match ('\b' + [regex]::Escape($predictedStory) + '\b') -and $_ -match '<!--\s*Status:\s*DONE\b' } | Select-Object -First 1)
  }
  $gt = Join-Path $kit "grade-trends.ps1"
  if ($rollsUpNow -and (Test-Path $gt)) {
    $trend = $null
    try { $trend = (& powershell -NoProfile -ExecutionPolicy Bypass -File $gt -ProjectDir $proj -Json -EnsureBaseline 2>$null | Out-String | ConvertFrom-Json) } catch { $trend = $null }
    if ($trend -and @($trend.recurringSuggestions).Count -gt 0) {
      if ($trend.retroDue) {
        Write-Host "[close-unit] RETRO DUE - story $predictedStory is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
        Write-Host "             $($trend.storyClosesSinceRetro) stories have closed since the last retro, and the grader keeps making the same suggestion(s):" -ForegroundColor Red
        foreach ($rs in @($trend.recurringSuggestions | Select-Object -First 6)) { Write-Host "               - $rs" -ForegroundColor Yellow }
        Write-Host "             Run /retro now: it turns these into a convention, a recipe, a task or a design item, on the" -ForegroundColor Red
        Write-Host "             human's approval, and records itself (dad grade-trends -RecordRetro). Then close again." -ForegroundColor Red
        Write-GateLog "block" "$Id not closed: retro due - $(@($trend.recurringSuggestions).Count) recurring grader suggestion(s), $($trend.storyClosesSinceRetro) story closes since the last retro"
        exit 1
      }
      $retroWarn = @($trend.recurringSuggestions)
    }
  }
}
# --- 0f) human-gate WIP limit: do not START another story (issue 7 option B, 0.61.0) -----------
# When more stories than the project's limit are built and waiting only on a human, the first task of a
# NEW story does not close. Tasks of stories already started are untouched, so nothing in flight is
# stranded. The limit is the human's number in CLAUDE.md ("- Human-gate WIP limit: N"); raising it is the
# override, and with no such line nothing is enforced. doc-stats owns the definition and the count.
if ($myTaskStory -and -not $SkipVerify) {
  $wipCm = Join-Path $proj "CLAUDE.md"
  $wipLimit = -1
  if (Test-Path -LiteralPath $wipCm) {
    $wm = [regex]::Match([System.IO.File]::ReadAllText($wipCm), '(?im)^\s*-\s*\*{0,2}Human-gate WIP limit\*{0,2}\s*:\s*(\d+)')
    if ($wm.Success) { $wipLimit = [int]$wm.Groups[1].Value }
  }
  if ($wipLimit -ge 0) {
    $storyLines = @(Get-Content $tasksFile -Encoding UTF8 | Where-Object {
      $_ -match '^###\s*\[[ x]\]' -and $_ -match ('\(Story\s+' + [regex]::Escape($myTaskStory) + '\)') })
    $startsStory = (@($storyLines | Where-Object { $_ -match '^###\s*\[x\]' }).Count -eq 0)
    if ($startsStory) {
      $wip = $null
      try { $wip = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $proj -Json 2>$null | Out-String | ConvertFrom-Json) } catch { $wip = $null }
      $waiting = @(); if ($wip -and $wip.humanGateStories) { $waiting = @($wip.humanGateStories | Where-Object { $_ -ne $myTaskStory }) }
      if ($waiting.Count -gt $wipLimit) {
        Write-Host "[close-unit] HUMAN-GATE WIP LIMIT REACHED - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
        Write-Host "             '$Id' would START story $myTaskStory, but $($waiting.Count) stories are already built and waiting only" -ForegroundColor Red
        Write-Host "             on a human gate (limit: $wipLimit): $(($waiting | Select-Object -First 12) -join ', ')" -ForegroundColor Red
        Write-Host "             Building more on top of work nobody has tried is how a backlog of unverified stories grows." -ForegroundColor Red
        Write-Host "             STOP and give the human the checklist:   dad doc-stats -HumanGates" -ForegroundColor Yellow
        foreach ($g in @($wip.humanGateTasks | Select-Object -First 8)) { Write-Host "               [ ] $g" -ForegroundColor Yellow }
        Write-Host "             They clear gates (then close those tasks), or raise 'Human-gate WIP limit' in CLAUDE.md." -ForegroundColor Yellow
        Write-Host "             Tasks of stories ALREADY started still close. Do not edit the limit yourself." -ForegroundColor DarkGray
        Write-GateLog "block" "$Id not closed: human-gate WIP limit ($($waiting.Count) stories waiting on a human, limit $wipLimit) - would start story $myTaskStory"
        exit 1
      }
    }
  }
}
# --- 0e) is the story REACHABLE? one [e2e] task per story (issue 9 option A, 0.61.0) -------------
# A story whose tasks are all library pieces rolls up green while nothing a user can run calls the code.
# So the task map carries exactly one task per story tagged [e2e] in its title - the one whose acceptance
# runs the real entry point - and a story without one does not roll up. Enforced only where the project
# has grades\e2e-exempt.txt: new-project creates it empty, upgrade-project fills it with the stories that
# were already under way, so no story planned under the old rules is blocked after the fact.
if ($predictedStory -and $myTaskStory -and -not $SkipVerify) {
  $exemptFile = Join-Path $proj "grades\e2e-exempt.txt"
  if (Test-Path -LiteralPath $exemptFile) {
    $exempt = @([System.IO.File]::ReadAllLines($exemptFile) | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ })
    if ($exempt -notcontains $predictedStory) {
      $storyTasks = @(Get-Content $tasksFile -Encoding UTF8 | Where-Object {
        $_ -match '^###\s*\[[ x]\]' -and $_ -match ('\(Story\s+' + [regex]::Escape($predictedStory) + '\)') })
      if (@($storyTasks | Where-Object { $_ -match '(?i)\[e2e\]' }).Count -eq 0) {
        Write-Host "[close-unit] STORY $predictedStory HAS NO [e2e] TASK - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
        Write-Host "             This is the last open task of $predictedStory, so closing it would mark the story DONE - but" -ForegroundColor Red
        Write-Host "             none of its $($storyTasks.Count) task(s) is tagged [e2e]: nothing proves a user can reach this work" -ForegroundColor Red
        Write-Host "             through the real entry point (command, route, screen)." -ForegroundColor Red
        Write-Host "             Run /taskmap for story ${predictedStory} - it adds the one [e2e] task (or tags the task that already" -ForegroundColor Yellow
        Write-Host "             is the end-to-end path). Then build that task and close again." -ForegroundColor Yellow
        Write-Host "             (A story with genuinely no entry point is the HUMAN's call: they add its id to grades\e2e-exempt.txt.)" -ForegroundColor DarkGray
        Write-GateLog "block" "$Id not closed: story $predictedStory has no [e2e] task (no end-to-end path)"
        exit 1
      }
    }
  }
}
# --- 0b) does an earlier story still owe its story-level close? (issue 14, 0.60.0) ----------------
# When a story's last task closes, the story rolls up to DONE - and /build then owes it a grade, a hygiene
# pass and the story-level close (`close-unit -Id <story> -RequireGrade`), which is the story's own commit.
# Nothing enforced that. A real project has stories that are DONE with no grade card and no story commit,
# thirty task closes further on: the loop simply went to the next task. So a task of a DIFFERENT story
# does not close while an earlier story is still open in this sense. An entry is dropped on evidence (a
# commit "<story>: ..." exists) so a close made elsewhere is honoured. -SkipVerify (the human) skips this.
if ($myTaskStory -and -not $SkipVerify) {
  $stillOpen = @()
  foreach ($sid in (Get-OpenStories)) {
    if ($sid -eq $myTaskStory) { $stillOpen += $sid; continue }       # more work on the same story is fine
    if (Test-UnitCommit $sid) { continue }                            # closed after all: forget it
    $stillOpen += $sid
  }
  Set-OpenStories $stillOpen
  $owed = @($stillOpen | Where-Object { $_ -ne $myTaskStory })
  if ($owed.Count -gt 0) {
    Write-Host "[close-unit] STORY $($owed -join ', ') IS DONE BUT NOT CLOSED - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
    Write-Host "             Its last task rolled it up to DONE, but the story-level close never ran, so it has no" -ForegroundColor Red
    Write-Host "             story commit (and usually no grade). Finish it before starting on another story:" -ForegroundColor Red
    foreach ($sid in $owed) {
      Write-Host "               1. grade it (grade-agent -> grades\$($sid)_GRADE.md), run hygiene-agent" -ForegroundColor Yellow
      Write-Host "               2. dad close-unit -Id $sid -Title `"$sid polish`" -RequireGrade" -ForegroundColor Yellow
    }
    Write-Host "             Then re-run this close. (/build 'Per STORY' steps 5-7. Under /spec, where stories are" -ForegroundColor Red
    Write-Host "             not graded, step 2 without -RequireGrade is enough.)" -ForegroundColor Red
    Write-GateLog "block" "$Id not closed: story $($owed -join ', ') rolled up to DONE but has no story-level close yet"
    exit 1
  }
}

if (-not $SkipVerify) {
  $cmd = if ($BuildCommand) { $BuildCommand } else { Get-ClaudeCommand 'Build' }
  if (-not $cmd) {
    # A missing/unparseable Build: line used to WARN and then close anyway - a model never has to pass
    # -SkipVerify to get an unverified close, it just needs CLAUDE.md to be unfilled or unparseable.
    # -SkipVerify is the human's deliberate escape hatch (checked above, at the top of this block); make
    # this the ONLY other way past verification, and require the human to say so explicitly.
    # DANGLER: docs\DESIGN.md:201 (R28's prose, LOCKED - not editable here) still describes the OLD
    # behavior ("close-unit prints 'closing WITHOUT verification' and proceeds"). Correct it next time
    # DESIGN.md goes to DRAFT; ratchet.ps1's ROLE here is unaffected (it separately catches the Build:
    # LINE itself being deleted - a different failure mode from this one, which is the line existing but
    # not resolving to a command).
    Write-Host "[close-unit] NO BUILD COMMAND FOUND in CLAUDE.md - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
    Write-Host "             Fill CLAUDE.md's 'Build:' line (that is /design's job) so units get verified, or" -ForegroundColor Red
    Write-Host "             re-run with -SkipVerify if you (the human) really want an unverified close." -ForegroundColor Red
    Write-GateLog "block" "$Id not closed: no build command found in CLAUDE.md"
    exit 1
  } else {
    Write-Host "[close-unit] build: $cmd" -ForegroundColor Cyan
    $r = Invoke-Verify $cmd
    $lockCurrent = $false
    # A FILE-LOCK failure is not a code failure: a left-over apphost (a `dotnet run` nobody stopped) holds
    # the output DLL/exe, so the build cannot overwrite it - MSB3026 / "being used by another process". A
    # real run hit this seven times and could not clear it. Clear the project-owned lock and retry ONCE
    # before declaring failure. free-locks is scoped to processes running from THIS project's own folder,
    # so it is safe to invoke automatically.
    if ($r.Code -ne 0 -and $r.Output -match '(?i)MSB3026|being used by another process|cannot access the file.{0,40}\.(dll|exe)|locked by') {
      # Before killing anything: if the locked output is already newer than every source, it is current.
      $lockedPaths = @([regex]::Matches($r.Output, "(?i)cannot access the file '([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
      $upToDate = $false
      if ($lockedPaths.Count -gt 0) {
        $upToDate = $true
        foreach ($lp in $lockedPaths) { if (-not (Test-BuildOutputCurrent $lp $proj)) { $upToDate = $false; break } }
      }
      if ($upToDate) {
        Write-Host "[close-unit] build up-to-date (output locked by a running app; no sources changed since it was built) - nothing killed" -ForegroundColor Green
        $r = [pscustomobject]@{ Code = 0; Output = $r.Output }
        $lockCurrent = $true
      } else {
      Write-Host "[close-unit] build blocked by a FILE LOCK (a left-over app process holds the output). Clearing it..." -ForegroundColor Yellow
      $fl = Join-Path $kit "free-locks.ps1"
      if (Test-Path $fl) { & powershell -NoProfile -ExecutionPolicy Bypass -File $fl -ProjectDir $proj 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray } }
      Write-Host "[close-unit] retrying the build once..." -ForegroundColor Yellow
      $r = Invoke-Verify $cmd
      }
    }
    if ($r.Code -ne 0) {
      Write-Host "[close-unit] BUILD FAILED (exit $($r.Code)) - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
      Show-Tail $r.Output
      $buildWhy = "$Id not closed: build failed (exit $($r.Code))"
      if (Show-EnvBlock $r.Output) { Write-GateLog "block" "$buildWhy - environment block"; exit 1 }        # environmental: do not offer "fix the build"
      if ($r.Output -match '(?i)MSB3026|being used by another process') {
        Write-Host "             Still locked after clearing project processes. A process OUTSIDE this project" -ForegroundColor Red
        Write-Host "             may hold the file (an editor, a debugger). Close it, or run: dad free-locks" -ForegroundColor Red
        Write-GateLog "block" "$buildWhy - file lock"
        exit 1
      }
      Show-Signatures $r.Output
      Write-Host "             Fix the build, then re-run. (-SkipVerify overrides, but then 'done' means nothing.)" -ForegroundColor Red
      Write-GateLog "block" $buildWhy
      exit 1
    }
    if ($lockCurrent) { $notes.Add("build up-to-date (output locked by a running app; no sources changed since it was built) - nothing killed") }
    else { $notes.Add("build verified ($cmd)") }
    # The build just succeeded, so the assemblies are current: refresh the API surface while it is true.
    # Generated from the DLLs, so it cannot drift. 0.60.0: it lands in .claude\ (gitignored) - a build
    # product is not committed with every close and not indexed beside the design (issue 10).
    try {
      $apiScript = Join-Path $kit "api-surface.ps1"
      if (Test-Path $apiScript) {
        $hadLegacyApi = Test-Path (Join-Path $proj "docs\API-SURFACE.md")
        & powershell -NoProfile -ExecutionPolicy Bypass -File $apiScript -ProjectDir $proj -Quiet | Out-Null
        if (Test-Path (Join-Path $proj ".claude\API-SURFACE.md")) { $notes.Add("API surface regenerated (.claude\API-SURFACE.md - not committed; query: dad api-surface -Lookup <Name>)") }
        if ($hadLegacyApi -and -not (Test-Path (Join-Path $proj "docs\API-SURFACE.md"))) { $notes.Add("old docs\API-SURFACE.md removed from docs\ and from git (it is a build product now)") }
      }
    } catch { $warns.Add("could not refresh the API surface: $($_.Exception.Message)") }
  }

  # --- FAST TESTS on EVERY task close (issue 12, 0.60.0) -------------------------------------------
  # The full suite runs only at a story close ("too slow per task"), so a task close verified the BUILD
  # and nothing else. In a real project the tests that broke most often between story closes were the
  # cheapest ones in the suite: SOURCE-SCAN / static-guard tests (a banned literal, a word list, an
  # allow-set of files). A task added the offending line, closed green, and the failure surfaced several
  # tasks later at the story close - on main, attributed to the wrong unit, and fixed by a hand commit.
  # So a project may name a quick subset on an optional line in CLAUDE.md's Build / test section:
  #     - Fast test: `dotnet test --filter "Category=SourceScan"`
  # and close-unit runs it on every TASK close. No such line: nothing changes. A story close runs the
  # full Test command instead, which contains the subset.
  if (-not $predictedStory) {
    $fcmd = Get-ClaudeCommand 'Fast test'
    if ($fcmd) {
      Write-Host "[close-unit] fast tests (every task close): $fcmd" -ForegroundColor Cyan
      $ft = Invoke-Verify $fcmd
      $fcount = Get-TestCount $ft.Output
      if ($ft.Code -ne 0) {
        Write-Host "[close-unit] FAST TESTS FAILED (exit $($ft.Code)) - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
        Show-Tail $ft.Output
        [void](Show-EnvBlock $ft.Output)
        Write-Host "             These are the project's quick checks (CLAUDE.md 'Fast test:'). This unit broke one;" -ForegroundColor Red
        Write-Host "             fix it now, while the change that caused it is still in front of you." -ForegroundColor Red
        Write-GateLog "block" "$Id not closed: fast tests failed (exit $($ft.Code))"
        exit 1
      }
      if ($fcount -eq 0) {
        Write-Host "[close-unit] FAST TESTS RAN ZERO TESTS - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
        Write-Host "             CLAUDE.md's 'Fast test:' command selected nothing (a filter that matches no test" -ForegroundColor Red
        Write-Host "             exits 0). Fix the filter, or remove the line if the project has no quick subset." -ForegroundColor Red
        Show-Tail $ft.Output
        Write-GateLog "block" "$Id not closed: fast tests ran zero tests"
        exit 1
      }
      if ($fcount -lt 0) { $notes.Add("fast tests passed (exit 0; no test count in the output)") }
      else { $notes.Add("fast tests verified ($fcount test(s) ran)") }
    }
  }

  # A STORY may only close on tests that actually RAN. Tasks run only the optional 'Fast test:' subset
  # above (the full suite is too slow per task, and a partial story is not claiming verification yet).
  if ($predictedStory) {
    $tcmd = Get-ClaudeCommand 'Test'
    if (-not $tcmd) {
      $warns.Add("story $predictedStory closing WITHOUT tests - no 'Test:' command in CLAUDE.md")
    } else {
      Write-Host "[close-unit] tests (story $predictedStory): $tcmd" -ForegroundColor Cyan
      $t = Invoke-Verify $tcmd
      $count = Get-TestCount $t.Output
      if ($t.Code -ne 0) {
        Write-Host "[close-unit] TESTS FAILED (exit $($t.Code)) - story $predictedStory is NOT closed. Nothing changed." -ForegroundColor Red
        Show-Tail $t.Output
        [void](Show-EnvBlock $t.Output)             # a refusal to RUN the test DLL lands here, not a real failure
        Write-GateLog "block" "story $predictedStory not closed: tests failed (exit $($t.Code))"
        exit 1
      }
      if ($count -eq 0) {
        Write-Host "[close-unit] TESTS RAN ZERO TESTS - story $predictedStory is NOT closed. Nothing changed." -ForegroundColor Red
        Write-Host "             A green run of 0 tests verifies nothing. Usual cause: test projects missing from" -ForegroundColor Red
        Write-Host "             the solution (dotnet sln add tests/**/*.csproj)." -ForegroundColor Red
        Show-Tail $t.Output
        Write-GateLog "block" "story $predictedStory not closed: tests ran zero tests"
        exit 1
      }
      if ($count -lt 0) {
        Write-Host "[close-unit] Could not find any evidence tests ran - story $predictedStory is NOT closed." -ForegroundColor Red
        Write-Host "             No test count in the output. Fix the test command, or use -SkipVerify knowingly." -ForegroundColor Red
        Show-Tail $t.Output
        Write-GateLog "block" "story $predictedStory not closed: no evidence tests ran"
        exit 1
      }
      $notes.Add("tests verified ($count test(s) ran)")
    }
  }
}

# --- 0c) is this id ALREADY closed while new code is waiting? -----------------------------------
# The mismatch this catches, from a real run: a commit titled "T8.1: Implement ObjectStore" actually
# contained VariantProcessor.cs (T7.1's work), because close-unit does `git add -A` and banks whatever
# is dirty under whatever id you pass. Then `t8.1` (lower case) matched the already-ticked T8.1, took
# the idempotent path, and committed T8.2's MetadataStore under a no-op close - leaving T8.2 open with
# its implementation already in history. An id that is already [x] plus pending code is the signature
# of work being filed under the wrong unit, and it is cheap to detect.
$alreadyClosed = $false
if (Test-Path $tasksFile) {
  $alreadyClosed = [bool](Select-String -Path $tasksFile -Pattern "^###\s*\[x\]\s*$esc\b" -Quiet)
  # Report the CANONICAL id: matching is case-insensitive, so `t8.1` silently ticks `T8.1`.
  $canon = Select-String -Path $tasksFile -Pattern "^###\s*\[[ x]\]\s*($esc)\b" | Select-Object -First 1
  if ($canon -and $canon.Matches[0].Groups[1].Value -cne $Id) {
    $warns.Add("id '$Id' matched '$($canon.Matches[0].Groups[1].Value)' (case differs) - using the id as written in TASKS.md")
  }
}
if ($alreadyClosed -and -not $NoCommit -and (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $proj ".git"))) {
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $pending = @()
  try {
    Push-Location $proj
    foreach ($line in @(git status --porcelain -uall)) {
      if ($line.Length -lt 4) { continue }
      $f = $line.Substring(3).Trim().Trim('"')
      if ($f -match '\s->\s') { $f = ($f -split '\s->\s')[-1].Trim().Trim('"') }
      $n = $f.Replace('/', '\')
      if ($n -like "docs\*" -or $n -like ".claude\*" -or $n -like "grades\*") { continue }
      if ($n -like "*\bin\*" -or $n -like "*\obj\*" -or $n -like "bin\*" -or $n -like "obj\*") { continue }
      if (@(".cs",".fs",".vb",".py",".ts",".tsx",".js",".jsx",".go",".rs",".java",".kt",".c",".h",
            ".cpp",".hpp",".cc",".rb",".php",".swift",".sql",".csproj",".fsproj",".sln") -notcontains
          [System.IO.Path]::GetExtension($n)) { continue }
      $pending += $n
    }
  } catch { } finally { Pop-Location; $ErrorActionPreference = $prevEap }
  if ($pending.Count -gt 0) {
    Write-Host "[close-unit] '$Id' is ALREADY closed, but $($pending.Count) code file(s) are uncommitted:" -ForegroundColor Red
    foreach ($f in ($pending | Select-Object -First 8)) { Write-Host "               $f" -ForegroundColor Red }
    Write-Host "             Committing them under '$Id' would file this work against the wrong unit - the" -ForegroundColor Red
    Write-Host "             commit message would describe something the diff does not contain. Close them" -ForegroundColor Red
    Write-Host "             under the id that OWNS them (check docs\TASKS.md), or -NoCommit to skip banking." -ForegroundColor Red
    Write-GateLog "block" "$Id already closed but $($pending.Count) uncommitted code file(s) would be committed under the wrong id"
    exit 1
  }
}

# --- 0d) did the verification surface SHRINK? --------------------------------------------------
# Every other gate here asks "is X OK now?", which is satisfied by DELETING X. A run rewrote a test
# file to add a fixture, 15 of 16 tests did not survive, and every gate went green: build passed, tests
# RAN (11 > 0), tests PASSED (8), tree clean. Deleting a red test is the shortest path to "make the
# tests pass" and nothing forbade it. So: counts may not fall silently.
$script:shrinkAccepted = $false
$reasonText = (("$Reason") -replace '\s+', ' ').Trim()
$allowText = "clean close: $Id"
if (-not $SkipVerify) {
  $ratchet = Join-Path $kit "ratchet.ps1"
  if (Test-Path $ratchet) {
    $rOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $ratchet -ProjectDir $proj 2>&1 | Out-String
    $rCode = $LASTEXITCODE
    # FAIL OPEN on a broken checker. Exit 1 means "something shrank"; a CRASH (bad path, unreadable file,
    # a bug of mine) must not block a legitimate close. A gate that fails closed on its own defects stops
    # real work and gets switched off, which costs more than the case it was guarding. Same principle as
    # dad-guard, and it is why the first version of this check broke three passing close-unit tests.
    if ($rOut -match 'CategoryInfo|FullyQualifiedErrorId') {
      $warns.Add("ratchet could not run - shrink NOT verified this close")
      $rCode = 0
    }
    if ($rCode -ne 0 -and -not $AcceptShrink) {
      Write-Host "[close-unit] VERIFICATION SURFACE SHRANK - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
      Write-Host ($rOut.TrimEnd())
      Write-Host "             Find out WHAT vanished (and what merely moved to another file):" -ForegroundColor Red
      Write-Host "               powershell -File `"$kit\recover-lost.ps1`" -ProjectDir `"$proj`"" -ForegroundColor Yellow
      Write-Host "               ...add -Restore to put the vanished units back, KEEPING what the change added." -ForegroundColor Yellow
      Write-Host "             If the HUMAN decided the removal is deliberate, they re-run with BOTH" -ForegroundColor Red
      Write-Host "               -AcceptShrink -Reason `"<who approved it, when, and why>`"" -ForegroundColor Red
      Write-Host "             (lowers the baseline; the reason goes into the commit and the gate log). An agent" -ForegroundColor Red
      Write-Host "             does not pass -AcceptShrink on its own: ask the human, and quote their answer." -ForegroundColor Red
      # No log call here: ratchet.ps1 (the subprocess above) already logged its own block for this event.
      exit 1
    }
    # 0.60.0 (issue 3): -AcceptShrink WITHOUT a recorded reason is refused. It used to WARN and close, and
    # a real project's gate log shows what that was worth: five times a ratchet block was followed 10 to
    # 45 seconds later by a "clean close" of the same unit - the flag simply re-run, nothing written down about who
    # agreed to delete the tests or why. A bare switch is not a human decision; a sentence is at least a
    # record somebody can be asked about. Ten characters is the floor that keeps "ok" and "x" out.
    if ($rCode -ne 0 -and $AcceptShrink -and $reasonText.Length -lt 10) {
      Write-Host "[close-unit] -AcceptShrink NEEDS A REASON - '$Id' is NOT closed. Nothing was ticked or committed." -ForegroundColor Red
      Write-Host ($rOut.TrimEnd())
      Write-Host "             The verification surface shrank and -AcceptShrink was given with no (or a one-word) -Reason." -ForegroundColor Red
      Write-Host "             Lowering the baseline is the HUMAN's decision. Re-run with what they said:" -ForegroundColor Red
      Write-Host "               -AcceptShrink -Reason `"<who approved it, when, and why>`"" -ForegroundColor Yellow
      Write-Host "             It is recorded in the commit (Shrink-accepted:) and in grades\gates-log.jsonl." -ForegroundColor Red
      Write-GateLog "block" "$Id not closed: -AcceptShrink given without a recorded -Reason (the shrink stands refused)"
      exit 1
    }
    if ($rCode -ne 0 -and $AcceptShrink) {
      $script:shrinkAccepted = $true
      $warns.Add("shrink ACCEPTED by -AcceptShrink - baseline lowered. Recorded reason: $reasonText")
    }
  }
}
if ($reasonText -and -not $script:shrinkAccepted) { $notes.Add("-Reason ignored: nothing shrank, so there was no shrink to accept") }
# An accepted shrink always carries its reason (a reason-less -AcceptShrink is refused above since 0.60.0).
if ($script:shrinkAccepted -and $reasonText) { $allowText = "clean close: $Id - shrink accepted: $reasonText" }

# The bookkeeping files exactly as they are BEFORE this close writes to them (issue 2): if the commit
# below does not land, they are put back, so a tick and a DONE stamp never sit on disk unbacked.
$origTasks = $null; $origStories = $null; $origStatus = $null
$statusFile = Join-Path $docs "STATUS.md"
if (Test-Path $tasksFile)   { $origTasks = [System.IO.File]::ReadAllText($tasksFile) }
if (Test-Path $storiesFile) { $origStories = [System.IO.File]::ReadAllText($storiesFile) }
if (Test-Path $statusFile)  { $origStatus = [System.IO.File]::ReadAllText($statusFile) }
$commitFailed = $false
$rolledBack = $false
$script:storyFlipped = $null
$script:evidenceFresh = $null
$origRecipes = $null

# --- 1) tick the unit ---
$closedTask = $false
$parentStory = $null
if ((Test-Path $tasksFile) -and (Select-String -Path $tasksFile -Pattern "^###\s*\[[ x]\]\s*$esc\b" -Quiet)) {
  $lines = Get-Content $tasksFile -Encoding UTF8
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^###\s*\[( |x)\]\s*$esc\b") {
      if ($Matches[1] -eq 'x') { $notes.Add("task $Id already [x]") }
      else {
        $lines[$i] = [regex]::Replace($lines[$i], '^(###\s*\[)\s(\])', '$1x$2')
        Save-Text $tasksFile $lines
        $notes.Add("task $Id -> [x] in TASKS.md")
      }
      if ($lines[$i] -match '\(Story\s+([A-Za-z0-9._-]+)\)') { $parentStory = $Matches[1] }
      $closedTask = $true
      break
    }
  }

  # --- 2) story roll-up: only when EVERY task of the parent story is ticked ---
  if ($parentStory) {
    $all = Get-Content $tasksFile -Encoding UTF8 |
           Where-Object { $_ -match '^###\s*\[[ x]\]' -and $_ -match ('\(Story\s+' + [regex]::Escape($parentStory) + '\)') }
    $done = @($all | Where-Object { $_ -match '^###\s*\[x\]' }).Count
    if ($all.Count -gt 0 -and $done -eq $all.Count) { Set-StoryDone $parentStory; $storyClosed = $parentStory }
    else { $notes.Add("story $parentStory : $done/$($all.Count) tasks done - not rolling up yet") }
  }
}
elseif ((Test-Path $storiesFile) -and (Select-String -Path $storiesFile -Pattern "\b$esc\b" -Quiet)) {
  Set-StoryDone $Id      # no task map: the unit IS a story
  $storyClosed = $Id
}
else {
  Write-Host "[close-unit] '$Id' not found in TASKS.md or STORIES.md - check the id (nothing committed)." -ForegroundColor Red
  Write-GateLog "block" "$Id not found in TASKS.md or STORIES.md"
  exit 1
}

# --- 2a) the story just turned DONE: write its close evidence for the grader (issue 5) ---
$evidenceWritten = $null
if ($script:storyFlipped) {
  try {
    $tl = if ($SkipVerify) { "tests NOT verified (-SkipVerify)" }
          elseif ($tcmd -and $null -ne $count) { "tests exit 0, $count ran" }
          else { "no Test command in CLAUDE.md - tests NOT run" }
    $evidenceWritten = Write-StoryEvidence $script:storyFlipped $tl
    $script:evidenceFresh = $script:storyFlipped
    $notes.Add("close evidence written for the grader: grades\$($script:storyFlipped)_EVIDENCE.md (the card must quote its Evidence line)")
  } catch { $warns.Add("could not write the close evidence for $($script:storyFlipped): $($_.Exception.Message)") }
}
if ($retroWarn.Count -gt 0) {
  $warns.Add("$($retroWarn.Count) grader suggestion(s) recur on 3+ cards and are still open - run /retro (close-unit holds the story close after 5 closes without one): " + (($retroWarn | Select-Object -First 3) -join ' | '))
}
# --- 2b) a DONE story needs a real grade card ---
# Grading is the step that keeps getting skipped. At task level this only warns (the card is written AFTER
# the story rolls up, per /build's order); pass -RequireGrade at the story-level close to make it binding.
if ($storyClosed) {
  $gradeIssue = Test-GradeCard $storyClosed
  if ($gradeIssue) {
    if ($RequireGrade) { $problems.Add("story $storyClosed : $gradeIssue - run /grade $storyClosed") }
    else { $warns.Add("story $storyClosed : $gradeIssue - run /grade $storyClosed") }
  } else { $notes.Add("story $storyClosed : grade card present") }
}

# --- 2d) the story is closed: archive its task bodies (issue 11 option A, 0.61.0) ---------------
# At the story-level close the story's ticked tasks are finished reading. archive-tasks moves their BODIES
# to docs\archive\TASKS-<story>.md and leaves each heading with a one-line pointer, so TASKS.md stops
# growing without any count changing. In this commit; undone with the rest if the commit fails.
$archiveFile = $null; $origArchive = $null
if (-not $closedTask -and $storyClosed -and $problems.Count -eq 0 -and (Test-Path $tasksFile)) {
  try {
    $at = Join-Path $kit "archive-tasks.ps1"
    if (Test-Path $at) {
      $archiveFile = Join-Path $docs "archive\TASKS-$storyClosed.md"
      if (Test-Path -LiteralPath $archiveFile) { $origArchive = [System.IO.File]::ReadAllText($archiveFile) }
      $ao = (& powershell -NoProfile -ExecutionPolicy Bypass -File $at -ProjectDir $proj -Story $storyClosed 2>$null | Out-String)
      $am = [regex]::Match($ao, 'archive-tasks: moved=(\d+) bytes=(\d+)')
      if ($am.Success -and [int]$am.Groups[1].Value -gt 0) {
        $notes.Add("archived $($am.Groups[1].Value) task bod(y/ies) of $storyClosed to docs\archive\TASKS-$storyClosed.md (TASKS.md is $([math]::Round([int]$am.Groups[2].Value / 1KB)) KB smaller; headings and counts unchanged)")
      }
    }
  } catch { $warns.Add("could not archive the task bodies of ${storyClosed}: $($_.Exception.Message)") }
}
# --- 2c) keep the dashboard true: regenerate the STATUS.md Snapshot (issue 4, 0.60.0) ---
# docs\STATUS.md is what every session reads first, and it was refreshed only when somebody remembered to
# run /audit status: one project's dashboard was 200 closed tasks behind. The counts are computed, so
# compute them here, in the same commit as the tick they describe. Only when this run changed the
# bookkeeping (a re-run of a closed unit must not dirty the tree), and never fatal - a dashboard that
# cannot be refreshed is a WARN, not a reason to refuse a verified close.
$bookkeepingChanged = (($null -ne $origTasks -and [System.IO.File]::ReadAllText($tasksFile) -ne $origTasks) -or
                       ($null -ne $origStories -and [System.IO.File]::ReadAllText($storiesFile) -ne $origStories))
if ((Test-Path $statusFile) -and $bookkeepingChanged) {
  try {
    $ds = Join-Path $kit "doc-stats.ps1"
    if (Test-Path $ds) {
      & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $proj -UpdateStatus -FromClose | Out-Null
      if ($LASTEXITCODE -eq 0) { $notes.Add("docs\STATUS.md Snapshot regenerated (counts + next task)") }
      else { $warns.Add("docs\STATUS.md Snapshot NOT refreshed (doc-stats exit $LASTEXITCODE) - run: dad doc-stats -UpdateStatus") }
    }
  } catch { $warns.Add("docs\STATUS.md Snapshot NOT refreshed: $($_.Exception.Message)") }
}

# --- 3) reindex so the next unit's agents see the updated state ---
if (-not $NoReindex) {
  $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
  if (Test-Path $exe) {
    # NOTE: never '2>&1' a native exe here - in PS 5.1 that wraps stderr in NativeCommandError, which
    # ErrorActionPreference=Stop turns into a terminating error even on exit code 0.
    & $exe --reindex $docs | Out-Null
    if ($LASTEXITCODE -eq 0) { $notes.Add("reindexed $docs") } else { $problems.Add("reindex failed (exit $LASTEXITCODE)") }
  } else { $problems.Add("local-tools.exe not built - skipped reindex") }
}

# 0.60.0 (issue 14): this block used to run AFTER the commit, so the first close of a project left
# docs\RECIPES.md modified and uncommitted - and a re-run of the same unit then had a 'real' file to stage
# and made a duplicate commit. It now runs before staging, so the rows land in the unit's own commit.
# --- record the commands that ACTUALLY WORKED --------------------------------------------------
# docs\RECIPES.md was designed as a proven-commands log that agents append to on success. After NINE runs
# on a real project it contained 18 lines: the bare template, zero entries. Asking a model to remember to
# write down what worked is the same class of instruction as asking it to remember to run close-unit, and
# it failed the same way. Meanwhile runs kept emitting broken shell - one used bash syntax and a wrong
# path (`cd D:/projects/mediamotor_iiif`, missing two segments) and lost the turn to it.
# So the close-out writes the entry. These two commands are the ones just VERIFIED to work on this machine.
if ($problems.Count -eq 0) {
  try {
    $recipes = Join-Path $docs "RECIPES.md"
    if (Test-Path $recipes) {
      $origRecipes = [System.IO.File]::ReadAllText($recipes)
      $rt = Get-Content $recipes -Raw
      $add = @()
      foreach ($pair in @(@{ K='Build'; V=(Get-ClaudeCommand 'Build') }, @{ K='Test'; V=(Get-ClaudeCommand 'Test') })) {
        if (-not $pair.V) { continue }
        # One row per distinct command, never a duplicate on every close.
        if ($rt -match [regex]::Escape($pair.V)) { continue }
        $add += "| ``$($pair.V)`` | $($pair.K.ToLower()) this project | from the project root | verified by close-unit on $Id | $(Get-Date -Format 'yyyy-MM-dd') |"
      }
      if ($add.Count) {
        if ($rt -notmatch '(?m)^##\s*Verified by close-unit') {
          $rt = $rt.TrimEnd() + "`r`n`r`n## Verified by close-unit`r`n" +
                "<!-- Appended automatically when a unit closes clean. These ran and worked ON THIS MACHINE. -->`r`n" +
                "| Command | Does | When | Gotcha | Verified |`r`n|---|---|---|---|---|`r`n"
        }
        $rt = $rt.TrimEnd() + "`r`n" + ($add -join "`r`n") + "`r`n"
        [System.IO.File]::WriteAllText($recipes, $rt, (New-Object System.Text.UTF8Encoding($false)))
        $notes.Add("recorded $($add.Count) verified command(s) in docs\RECIPES.md")
      }
    }
  } catch { $warns.Add("could not update docs\RECIPES.md: $($_.Exception.Message)") }
}

# --- 4) commit: this unit becomes a restore point ---
$committed = $false
if (-not $NoCommit) {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $problems.Add("git not found - no checkpoint") }
  elseif (-not (Test-Path (Join-Path $proj ".git"))) { $problems.Add("no git repo here - run upgrade-project.cmd to add one") }
  else {
    Push-Location $proj
    # git writes harmless notices (CRLF normalization) to stderr. In PS 5.1 those become
    # NativeCommandError records, which ErrorActionPreference=Stop would treat as fatal - so relax it
    # here and judge git ONLY by $LASTEXITCODE. Never add '2>&1' to these calls.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      # A title that already starts with the id ("T68.5: IUser32 wrapper") used to produce the subject
      # "T68.5: T68.5: IUser32 wrapper" - 36 commits in one project. Strip a leading "<id>:" / "<id> -".
      $cleanTitle = "$Title".Trim()
      $idPrefix = '^(?i)' + [regex]::Escape($Id) + '\s*[:\-]\s*'
      while ($cleanTitle -match $idPrefix) { $cleanTitle = $cleanTitle.Substring($Matches[0].Length).Trim() }
      $msg = if ($cleanTitle) { "$Id`: $cleanTitle" } else { "$Id" }
      # Log the clean-close allow BEFORE staging so the tracked grades\gates-log.jsonl line lands in this
      # unit's own commit. Written only while nothing has failed so far; if the commit/verify then fails,
      # the aggregate refusal below logs a block after it (honest sequence).
      if ($problems.Count -eq 0) { Write-GateLog "allow" $allowText; $script:allowLogged = $true }
      git add -A | Out-Null
      $stagedFiles = @(git diff --cached --name-only)
      $staged = ($stagedFiles -join "`n").Trim()

      # A visible surface that changed but did NOT go through the ux-agent -> ui-agent design pass is worth a
      # nudge here, in the loop, not only later in the grade. WARN, never block: ux-agent may be unavailable
      # on a local box and a close must not deadlock on a design review. doc-stats -Findings carries the
      # [ux] finding that costs the grade; this is the in-loop reminder that fires the moment a surface lands
      # without a recorded review.
      $stagedClean = @($stagedFiles | ForEach-Object { $_.Trim().Trim('"') })
      $surfRx = '(?i)\.(cshtml|razor|jsx|tsx|vue|svelte)$'
      $touchedSurface = @($stagedClean | Where-Object { $_ -match $surfRx -and $_ -notmatch '(?i)_View(Imports|Start)\.cshtml$' })
      if ($touchedSurface.Count -gt 0 -and -not $UxReviewed) {
        $warns.Add("visible surface changed ($($touchedSurface.Count) file(s): $(($touchedSurface | Select-Object -First 4) -join ', ')) but no UX pass recorded - run ux-agent, apply its review with ui-agent, and close with -UxReviewed. doc-stats -Findings will flag [ux] until a commit records it.")
      }

      # An EXPERIENCE (a project with docs\TEDD.md) whose gameplay code changed but that nobody playtested is
      # worth the same nudge: feel is the part tests cannot verify, and for a game it is most of the point.
      # WARN, never block (a pure-logic unit may not need a playtest, and a local box may have no one at the
      # controls). doc-stats carries the [playtest] finding that costs the grade.
      $isExperience = Test-Path (Join-Path $docs "TEDD.md")
      $touchedCode = @($stagedClean | Where-Object { [System.IO.Path]::GetExtension($_) -in @(".cs",".gd",".cpp",".h",".lua",".js",".ts",".rs") })
      if ($isExperience -and $touchedCode.Count -gt 0 -and -not $Playtested) {
        $warns.Add("experience code changed ($($touchedCode.Count) file(s)) but no playtest recorded - run playtest-agent, play it, and close with -Playtested. doc-stats -Findings will flag [playtest] until a commit records it.")
      }

      # Only close-unit writes these trailers; a model that closes by hand cannot fake them, the same way it
      # cannot fake "closed:close-unit". Each is its own -m (subject + body paragraphs; never a here-string -
      # PS 5.1 mangles `-m @'...'@`).
      $trailers = @()
      if ($UxReviewed) {
        $note = if ($UxNote) { $UxNote } else { "ui-agent applied ux-agent design review" }
        $trailers += @('-m', "UX-reviewed: $note (ux-agent)")
      }
      if ($Playtested) {
        $pnote = if ($PlaytestNote) { $PlaytestNote } else { "human playtest via playtest-agent protocol" }
        $trailers += @('-m', "Playtested: $pnote (human sign-off)")
      }
      if ($script:shrinkAccepted -and $reasonText) { $trailers += @('-m', "Shrink-accepted: $reasonText (human)") }

      # (ii) A RE-RUN of a unit that already has its commit must not make another one. It always had
      # something to stage - the gate-log lines this very run just wrote - so it committed a second
      # "<id>: <title>" holding nothing but log noise (three such pairs in one project's history). When
      # the unit's commit exists and only kit bookkeeping is staged, unstage it; the lines ride along
      # with the next real close.
      $storyLevelClose = (-not $closedTask -and [bool]$storyClosed)
      $hasUnitCommit = Test-UnitCommit $Id
      $kitNoise = @('grades/gates-log.jsonl', 'docs/API-SURFACE.md')
      $realStaged = @($stagedClean | Where-Object { $_ -and ($kitNoise -notcontains $_) })
      if ($staged -and $realStaged.Count -eq 0 -and $hasUnitCommit) {
        git reset -q | Out-Null
        $staged = ""
        $notes.Add("'$Id' already has its commit and nothing new is staged - no duplicate commit made")
        $committed = $true
      }
      elseif (-not $staged -and $storyLevelClose -and -not $hasUnitCommit) {
        # (iii) The story-level close IS the story's commit. With a clean tree it used to report "nothing
        # to commit" and leave no trace in history that the story was ever closed; record it.
        $prevStoryEnv = $env:DAD_CLOSE_UNIT_STORY
        $env:DAD_CLOSE_UNIT_STORY = $storyClosed
        try { git -c user.name="DAD-kit" -c user.email="dad-kit@local" commit -q --allow-empty -m $msg @trailers | Out-Null }
        finally { $env:DAD_CLOSE_UNIT_STORY = $prevStoryEnv }
        if ($LASTEXITCODE -eq 0) { $notes.Add("story commit recorded: $((git log --oneline -1 | Out-String).Trim())"); $committed = $true }
        else { $problems.Add("git commit (story commit) exited $LASTEXITCODE"); $commitFailed = $true }
      }
      elseif (-not $staged) { $notes.Add("nothing to commit (working tree already clean)") ; $committed = $true }
      else {
        # The pre-commit status guard lets a story become DONE only in a commit made right here, for the
        # story this run rolled up. Set for the lifetime of this one git call and removed again.
        $prevStoryEnv = $env:DAD_CLOSE_UNIT_STORY
        if ($storyClosed) { $env:DAD_CLOSE_UNIT_STORY = $storyClosed }
        try { git -c user.name="DAD-kit" -c user.email="dad-kit@local" commit -q -m $msg @trailers | Out-Null }
        finally { $env:DAD_CLOSE_UNIT_STORY = $prevStoryEnv }
        if ($LASTEXITCODE -ne 0) { $problems.Add("git commit exited $LASTEXITCODE"); $commitFailed = $true }
        # --- 5) VERIFY the commit actually landed and mentions this unit ---
        $last = (git log --oneline -1 | Out-String).Trim()
        if ($last -match [regex]::Escape($Id)) {
          $notes.Add("committed: $last")
          if ($UxReviewed) { $notes.Add("UX pass recorded in the commit (UX-reviewed:)") }
          if ($Playtested) { $notes.Add("playtest recorded in the commit (Playtested:)") }
          if ($script:shrinkAccepted -and $reasonText) { $notes.Add("shrink acceptance recorded in the commit (Shrink-accepted:)") }
          $committed = $true
        }
        else { $problems.Add("commit did not land or does not mention $Id (last: $last)"); $commitFailed = $true }
      }
      # --- 5b) the commit did not land: UNDO the bookkeeping (issue 2) ---
      # Without this the tick and the "DONE closed:close-unit" stamp stay on disk with no commit behind
      # them, and the next `git add -A` - any close, any hand commit - banks a story close that never
      # completed. Restore both files, and unstage, so the project is exactly as it was before this run.
      if ($commitFailed) {
        try {
          $enc = New-Object System.Text.UTF8Encoding($false)
          if ($null -ne $origTasks -and [System.IO.File]::ReadAllText($tasksFile) -ne $origTasks) { [System.IO.File]::WriteAllText($tasksFile, $origTasks, $enc); $rolledBack = $true }
          if ($null -ne $origStories -and [System.IO.File]::ReadAllText($storiesFile) -ne $origStories) { [System.IO.File]::WriteAllText($storiesFile, $origStories, $enc); $rolledBack = $true }
          if ($null -ne $origStatus -and (Test-Path $statusFile) -and [System.IO.File]::ReadAllText($statusFile) -ne $origStatus) { [System.IO.File]::WriteAllText($statusFile, $origStatus, $enc) }
          if ($null -ne $origRecipes) { $rp = Join-Path $docs "RECIPES.md"; if ((Test-Path $rp) -and [System.IO.File]::ReadAllText($rp) -ne $origRecipes) { [System.IO.File]::WriteAllText($rp, $origRecipes, $enc) } }
          if ($evidenceWritten -and (Test-Path -LiteralPath $evidenceWritten)) { Remove-Item -LiteralPath $evidenceWritten -Force }
          if ($archiveFile) {
            if ($null -ne $origArchive) { [System.IO.File]::WriteAllText($archiveFile, $origArchive, $enc) }
            elseif (Test-Path -LiteralPath $archiveFile) { Remove-Item -LiteralPath $archiveFile -Force }
          }
          git reset -q | Out-Null
          if ($rolledBack) { $problems.Add("bookkeeping ROLLED BACK: the TASKS.md tick and any STORIES.md DONE marker were restored, because the commit did not land - '$Id' is NOT closed") }
        } catch { $problems.Add("could not roll the bookkeeping back after the failed commit: $($_.Exception.Message) - check docs\TASKS.md and docs\STORIES.md by hand") }
      }
    } catch { $problems.Add("git commit failed: $($_.Exception.Message)") }
    finally { $ErrorActionPreference = $prevEap; Pop-Location }
  }
}
elseif ($storyClosed) {
  $warns.Add("-NoCommit: story $storyClosed is marked DONE on disk but NOT committed. The pre-commit guard refuses a hand commit of that marker; a human who means it sets DAD_ALLOW_STATUS_EDIT=1 for that commit.")
}

# --- verify bookkeeping on disk ---
if ($closedTask -and -not $rolledBack -and -not (Select-String -Path $tasksFile -Pattern "^###\s*\[x\]\s*$esc\b" -Quiet)) {
  $problems.Add("VERIFY FAILED: $Id is still not [x] in TASKS.md")
}

# --- the open-story list (issue 14) ------------------------------------------------------------
# A TASK close that rolled its story up leaves the story owing its story-level close; that close clears it.
if ($problems.Count -eq 0 -and $storyClosed -and -not $NoCommit) {
  try {
    $openNow = @(Get-OpenStories)
    if ($closedTask) {
      if (-not (Test-UnitCommit $storyClosed)) {
        Set-OpenStories (@($openNow) + @($storyClosed))
        $notes.Add("story $storyClosed now owes its story-level close: grade + hygiene, then 'dad close-unit -Id $storyClosed -Title `"$storyClosed polish`" -RequireGrade'. Tasks of OTHER stories will not close until then.")
      }
    } else {
      Set-OpenStories @($openNow | Where-Object { $_ -ne $storyClosed })
    }
  } catch { $warns.Add("could not update the open-story list: $($_.Exception.Message)") }
}

# --- sweep _tmp\ at a story close (issue 18, 0.60.0) -------------------------------------------
# Scratch belongs in _tmp\ and "dad tidy empties it" - when somebody runs tidy, which nobody did: one
# project's _tmp\ held 175 entries after six weeks. A story close is the natural boundary: the work is
# verified and committed, so its scratch is dead. Only files untouched for an hour go (an agent still
# working on another unit keeps its files), never anything git tracks, and never fatal.
if ($problems.Count -eq 0 -and $storyClosed) {
  try {
    $tidy = Join-Path $kit "tidy.ps1"
    if ((Test-Path $tidy) -and (Test-Path (Join-Path $proj "_tmp"))) {
      $sw = (& powershell -NoProfile -ExecutionPolicy Bypass -File $tidy -ProjectDir $proj -Fix -TmpOnly -OlderThanHours 1 2>$null | Out-String)
      $swm = [regex]::Match($sw, 'tmp-sweep: removed=(\d+) kept=(\d+)')
      if ($swm.Success -and [int]$swm.Groups[1].Value -gt 0) {
        $notes.Add("_tmp\ swept at story close: $($swm.Groups[1].Value) scratch file(s) older than 1h removed, $($swm.Groups[2].Value) recent kept")
      }
    }
  } catch { $warns.Add("could not sweep _tmp\: $($_.Exception.Message)") }
}

# --- is this shell ELEVATED? (issue 16, 0.60.0 - warning only) ----------------------------------
# An agent session started from an Administrator terminal runs EVERY command with admin rights: a wrong
# path in a delete is a system-wide mistake, and tools that (rightly) refuse to run elevated fail in ways
# that look like code bugs. One project's dashboard carried the note "agent shell is elevated" for weeks as
# the reason its human smoke tests could not be run by the agent. Nobody chose that; say it every close.
# DAD_ASSUME_ELEVATED=1/0 overrides the probe (the test suite uses it; nothing else should).
$elevated = $false
try {
  if ($env:DAD_ASSUME_ELEVATED -eq '1') { $elevated = $true }
  elseif ($env:DAD_ASSUME_ELEVATED -eq '0') { $elevated = $false }
  else { $elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
} catch { $elevated = $false }
if ($elevated) {
  $warns.Add("this shell is ELEVATED (Administrator). Every command the agent runs has admin rights, and tools that refuse elevation will fail. Unless you chose this, close the editor/terminal and start it NON-elevated. (dad doctor reports it too.)")
}

# --- stamp for the stop guard -----------------------------------------------------------------
# dad-guard.ps1 blocks a turn from ending on uncommitted, unverified code. A clean close IS the
# verification, so record it. Only on success - a failed close must stay blocked.
if ($problems.Count -eq 0) {
  try {
    $dotClaude = Join-Path $proj ".claude"
    if (-not (Test-Path $dotClaude)) { New-Item -ItemType Directory -Path $dotClaude -Force | Out-Null }
    [System.IO.File]::WriteAllText((Join-Path $dotClaude ".dad-verified"),
      "verified-by: close-unit $Id`r`n", (New-Object System.Text.UTF8Encoding($false)))
  } catch { $warns.Add("could not write the .dad-verified stamp: $($_.Exception.Message)") }
}

Write-Host "== close-unit $Id ==" -ForegroundColor Cyan
foreach ($n in $notes) { Write-Host "  ok   $n" -ForegroundColor Green }
foreach ($w in $warns) { Write-Host "  WARN $w" -ForegroundColor Yellow }
foreach ($p in $problems) { Write-Host "  FAIL $p" -ForegroundColor Red }
if ($problems.Count -gt 0) {
  Write-Host "close-unit INCOMPLETE - fix the above before moving on." -ForegroundColor Red
  Write-GateLog "block" "$Id INCOMPLETE: $($problems -join '; ')"
  exit 1
}
# -NoCommit closes (no commit to land in) log here; committed closes already logged before staging.
if (-not $script:allowLogged) { Write-GateLog "allow" $allowText; $script:allowLogged = $true }
# The close verified: build (and tests at a story close), bookkeeping landed, commit landed. THIS is the
# state worth ratcheting to - never on a failed close, or a bad run would raise the bar it just failed.
try {
  $ratchet = Join-Path $kit "ratchet.ps1"
  if (Test-Path $ratchet) { & powershell -NoProfile -ExecutionPolicy Bypass -File $ratchet -ProjectDir $proj -Update | Out-Null }
} catch { }
Write-Host "close-unit OK" -ForegroundColor Green
