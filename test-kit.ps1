# test-kit.ps1 - the kit's own test suite. Runs WITHOUT Ollama, a GPU, or network (after restore), so it
# works in CI. This is the safety net for editing prompt files: it catches the bug classes that actually
# bit us - stale uninstall lists, agents referenced but not installed, commands that forget to name the
# Task tool, non-ASCII creeping in, scaffold/upgrade/close-unit regressions.
#
#   test-kit.ps1              full suite
#   test-kit.ps1 -SkipBuild   skip the dotnet build + MCP tests (fast doc/script-only pass)
#
# Exit code 0 = all passed, 1 = at least one failure.

param([switch]$SkipBuild)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot
$script:pass = 0
$script:fail = 0
$script:failures = New-Object System.Collections.Generic.List[string]

function Test-Case([string]$name, [scriptblock]$body) {
  # Child processes (git, dotnet, the exe) write notices to stderr. If the suite's own stderr is being
  # captured/merged (CI, or a '2>&1' pipeline), PS 5.1 turns those into NativeCommandError records - which
  # ErrorActionPreference=Stop would treat as a test failure. Verdicts come from Assert, so relax it here.
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $body
    $script:pass++
    Write-Host ("  PASS  " + $name) -ForegroundColor DarkGreen
  } catch {
    $script:fail++
    $script:failures.Add("$name -> $($_.Exception.Message)")
    Write-Host ("  FAIL  " + $name + " -> " + $_.Exception.Message) -ForegroundColor Red
  } finally { $ErrorActionPreference = $prev }
}
# Untyped $cond on purpose: a [bool] parameter in PS 5.1 refuses strings ("accepts only Boolean values
# and numbers"), so Assert ($someString) would fail the TEST rather than evaluate truthiness.
function Assert($cond, [string]$msg) { if (-not $cond) { throw $msg } }
function New-Sandbox { $p = Join-Path $env:TEMP ("dadkit_t_" + [guid]::NewGuid().ToString("N").Substring(0,8)); New-Item -ItemType Directory -Force $p | Out-Null; return $p }
function Remove-Sandbox([string]$p) {
  if (-not (Test-Path $p)) { return }
  Get-ChildItem $p -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { try { $_.Attributes = 'Normal' } catch {} }
  try { [System.IO.Directory]::Delete($p, $true) } catch {}
}
function Get-KitFiles([string[]]$include) {
  Get-ChildItem $kit -Recurse -File -Include $include | Where-Object {
    $parts = $_.FullName.Split([char]92)
    ($parts -notcontains 'bin') -and ($parts -notcontains 'obj') -and ($parts -notcontains '__pycache__') -and
    ($parts -notcontains '_tempReference') -and ($parts -notcontains '.claude') -and ($parts -notcontains '.git')
  }
}

Write-Host "== DAD-kit test suite ==" -ForegroundColor Cyan

# ---------------------------------------------------------------- static hygiene
Write-Host "-- static --" -ForegroundColor Cyan

Test-Case "all .ps1 parse" {
  foreach ($f in Get-KitFiles @('*.ps1')) {
    $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs) | Out-Null
    Assert ($errs.Count -eq 0) "$($f.Name): $($errs[0].Message)"
  }
}

Test-Case "no multi-line if-EXPRESSION assignments (they parse, then fail at runtime)" {
  # `$x = if (c) { a }` <newline> `elseif (d) { b }` is VALID SYNTAX - PowerShell ends the assignment at
  # the closing brace and reads the next line as a command - so it sails past "all .ps1 parse" and dies
  # only when that line executes. It shipped in 0.9.9's fit math and broke install.cmd on the target
  # machine; the -Report test missed it because this box has no ollama, so the code never ran.
  $bad = @()
  foreach ($f in (Get-KitFiles @("*.ps1"))) {
    $lines = Get-Content $f.FullName
    for ($i = 0; $i -lt $lines.Count - 1; $i++) {
      # an assignment whose value is an if-block that CLOSES on this line...
      if ($lines[$i] -notmatch '=\s*if\s*\(') { continue }
      if ($lines[$i] -notmatch '\}\s*$') { continue }
      # ...followed by a line STARTING with elseif/else = a command invocation, not a branch
      if ($lines[$i+1] -match '^\s*(elseif|else)\b') { $bad += "$($f.Name):$($i+2)" }
    }
    # Sibling trap, and the one that actually broke install.cmd: `$((if(...){...}else{...}))`. The
    # subexpression $( ) accepts statements, but the extra inner parens make it an EXPRESSION context
    # where `if` is read as a command name -> "The term 'if' is not recognized". Also parses clean.
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '[^$]\(\s*if\s*\(' -and $lines[$i] -notmatch '^\s*#') { $bad += "$($f.Name):$($i+1)" }
    }
  }
  Assert ($bad.Count -eq 0) "if used where PowerShell expects an expression, at: $($bad -join ', ')"
}

Test-Case "config JSON parses" {
  foreach ($rel in @("settings.json", ".mcp.json", "templates\_common\.mcp.json", "templates\unity\.mcp.json")) {
    $p = Join-Path $kit $rel
    if (Test-Path $p) { Get-Content $p -Raw | ConvertFrom-Json | Out-Null }
  }
}

Test-Case "kit text is ASCII-only" {
  foreach ($f in Get-KitFiles @('*.ps1','*.cmd','*.md','*.json','*.py','*.cs')) {
    $bad = ([System.IO.File]::ReadAllBytes($f.FullName) | Where-Object { $_ -gt 127 }).Count
    Assert ($bad -eq 0) "$($f.Name) has $bad non-ASCII byte(s)"
  }
}

Test-Case "python helpers compile" {
  if (-not (Get-Command python -ErrorAction SilentlyContinue)) { return }   # optional on CI
  foreach ($f in @("voice.py", "transcribe.py")) {
    $p = Join-Path $kit $f
    if (Test-Path $p) { python -m py_compile $p; Assert ($LASTEXITCODE -eq 0) "$f failed to compile" }
  }
}

Test-Case "VERSION is semver and matches the CHANGELOG's top entry" {
  $vf = Join-Path $kit "VERSION"
  Assert (Test-Path $vf) "VERSION file missing"
  $v = (Get-Content $vf -Raw).Trim()
  Assert ($v -match '^\d+\.\d+\.\d+$') "'$v' is not semver"
  $cl = Join-Path $kit "CHANGELOG.md"
  Assert (Test-Path $cl) "CHANGELOG.md missing"
  $top = (Select-String -Path $cl -Pattern '^##\s+(\d+\.\d+\.\d+)' | Select-Object -First 1)
  Assert $top "CHANGELOG has no version heading"
  Assert ($top.Matches[0].Groups[1].Value -eq $v) "CHANGELOG top is $($top.Matches[0].Groups[1].Value), VERSION is $v"
}

Test-Case "scaffold stamps the project with the kit version" {
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "v"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "new-project.ps1") general $p | Out-Null
    $stamp = Join-Path $p ".dad-kit-version"
    Assert (Test-Path $stamp) ".dad-kit-version not written"
    Assert ((Get-Content $stamp -Raw).Trim() -eq (Get-Content (Join-Path $kit "VERSION") -Raw).Trim()) "stamp does not match VERSION"
  } finally { Remove-Sandbox $sb }
}

Test-Case "stack profiles are FRAGMENTS (no kit-owned sections to go stale)" {
  # They used to be full CLAUDE.md files and drifted badly behind templates/generic (old Modes wording,
  # no Secrets, no Task-tool rule). Keeping them fragments makes that impossible.
  $owned = @('## Modes', '## Design doc', '## Working agreement', '## Web / grounding', '## Secrets',
             '## Proven recipes')
  foreach ($p in Get-ChildItem (Join-Path $kit "templates") -Directory) {
    if ($p.Name -in @('generic', '_common')) { continue }
    $prof = Join-Path $p.FullName "PROFILE.md"
    Assert (Test-Path $prof) "$($p.Name) has no PROFILE.md"
    Assert (-not (Test-Path (Join-Path $p.FullName "CLAUDE.md"))) `
      "$($p.Name) still has a CLAUDE.md - stack profiles must be PROFILE.md fragments"
    $t = Get-Content $prof -Raw
    foreach ($s in $owned) {
      Assert ($t -notmatch [regex]::Escape($s)) "$($p.Name)/PROFILE.md contains kit-owned section '$s'"
    }
  }
}

Test-Case "stack profiles pin no toolchain version number" {
  # A hardcoded '.NET 8' is stale the day .NET 9 ships. Profiles must tell the model to DETECT instead.
  foreach ($p in Get-ChildItem (Join-Path $kit "templates") -Directory) {
    $prof = Join-Path $p.FullName "PROFILE.md"
    if (-not (Test-Path $prof)) { continue }
    $n = 0
    foreach ($line in Get-Content $prof) {
      $n++
      # allow the Unity editor-path placeholder <VER> and prose about LTS/odd-even
      if ($line -match '(?i)\.NET\s+\d+(\.\d+)?\b' -or $line -match '(?i)\bnet\d+\.0\b' -or $line -match '(?i)\bPython\s+3\.\d+\b') {
        Assert $false "$($p.Name)/PROFILE.md line $n pins a version: $($line.Trim())"
      }
    }
  }
}

Test-Case "the kit's own server keeps a broad TFM + RollForward" {
  # Deliberate: net8.0 + RollForward=LatestMajor builds on 8+ and RUNS on any 8+ runtime. Bumping the TFM
  # would narrow compatibility AND break the exe path baked into every .mcp.json.
  $csproj = Get-Content (Join-Path $kit "local-tools\local-tools.csproj") -Raw
  Assert ($csproj -match '<TargetFramework>net8\.0</TargetFramework>') "server TFM changed - .mcp.json exe paths would break"
  Assert ($csproj -match '<RollForward>LatestMajor</RollForward>') "RollForward=LatestMajor missing - the exe would demand exactly .NET 8"
  foreach ($rel in @(".mcp.json", "templates\_common\.mcp.json", "templates\unity\.mcp.json")) {
    $p = Join-Path $kit $rel
    if (Test-Path $p) { Assert ((Get-Content $p -Raw) -match 'net8\.0') "$rel exe path does not match the server TFM" }
  }
}

Test-Case "dev-path placeholder preserved in ALL configs (move-safety)" {
  # install.ps1 rewrites this token on the target machine. A baked-in absolute path here means a
  # folder-copy install lands broken - which is the primary distribution path, so check every config.
  foreach ($rel in @(".mcp.json", "templates\_common\.mcp.json", "templates\unity\.mcp.json")) {
    $p = Join-Path $kit $rel
    if (-not (Test-Path $p)) { continue }
    $s = Get-Content $p -Raw
    Assert ($s -match 'DAD-kit') "$rel lost the DAD-kit placeholder"
    Assert ($s -notmatch 'claude-local') "$rel has this machine's path baked in"
  }
}

Test-Case "package-kit produces a clean, installable copy" {
  $sb = New-Sandbox
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "package-kit.ps1") -OutDir $sb -Folder | Out-Null
    Assert ($LASTEXITCODE -eq 0) "package-kit exited $LASTEXITCODE"
    $v = (Get-Content (Join-Path $kit "VERSION") -Raw).Trim()
    $out = Join-Path $sb "DAD-kit-v$v"
    Assert (Test-Path $out) "package folder not created"
    foreach ($f in @("VERSION","install.cmd","models.json","test-kit.ps1","local-tools\Tools.cs")) {
      Assert (Test-Path (Join-Path $out $f)) "package missing $f"
    }
    foreach ($junk in @("local-tools\bin","local-tools\obj","_tempReference","docs\.index",".git")) {
      Assert (-not (Test-Path (Join-Path $out $junk))) "package should not contain $junk"
    }
    Assert ((Get-Content (Join-Path $out ".mcp.json") -Raw) -match 'DAD-kit') "packaged .mcp.json lost the placeholder"
  } finally { Remove-Sandbox $sb }
}

# ---------------------------------------------------------------- inventory consistency
Write-Host "-- inventory --" -ForegroundColor Cyan

$commands = (Get-ChildItem (Join-Path $kit "global\commands") -Filter *.md).BaseName
$agents   = (Get-ChildItem (Join-Path $kit "global\agents")   -Filter *.md).BaseName
$uninstall = Get-Content (Join-Path $kit "uninstall.ps1") -Raw

Test-Case "uninstall.ps1 lists every command (and no ghosts)" {
  $m = [regex]::Match($uninstall, '\$commands\s*=\s*@\(([^)]*)\)')
  Assert $m.Success "could not find `$commands array"
  $listed = [regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
  $missing = $commands | Where-Object { $listed -notcontains $_ }
  $ghosts  = $listed  | Where-Object { $commands -notcontains $_ }
  Assert (-not $missing) "not listed: $($missing -join ', ')"
  Assert (-not $ghosts)  "listed but no file: $($ghosts -join ', ')"
}

Test-Case "uninstall.ps1 lists every agent (and no ghosts)" {
  $m = [regex]::Match($uninstall, '\$agents\s*=\s*@\(([^)]*)\)')
  Assert $m.Success "could not find `$agents array"
  $listed = [regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
  $missing = $agents | Where-Object { $listed -notcontains $_ }
  $ghosts  = $listed | Where-Object { $agents  -notcontains $_ }
  Assert (-not $missing) "not listed: $($missing -join ', ')"
  Assert (-not $ghosts)  "listed but no file: $($ghosts -join ', ')"
}

Test-Case "each agent's frontmatter name matches its filename" {
  foreach ($f in Get-ChildItem (Join-Path $kit "global\agents") -Filter *.md) {
    $head = (Get-Content $f.FullName -TotalCount 6) -join "`n"
    $m = [regex]::Match($head, '(?m)^name:\s*(\S+)\s*$')
    Assert $m.Success "$($f.Name): no 'name:' in frontmatter"
    Assert ($m.Groups[1].Value -eq $f.BaseName) "$($f.Name): name '$($m.Groups[1].Value)' != filename"
  }
}

Test-Case "every agent referenced by a command exists" {
  foreach ($f in Get-ChildItem (Join-Path $kit "global\commands") -Filter *.md) {
    $text = Get-Content $f.FullName -Raw
    foreach ($mm in [regex]::Matches($text, '\b([a-z][a-z0-9-]*-agent)\b')) {
      $n = $mm.Groups[1].Value
      Assert ($agents -contains $n) "$($f.Name) references '$n' which is not in global\agents"
    }
  }
}

Test-Case "agent-spawning commands name the Task tool" {
  # A local model that reaches for the Skill tool gets 'Unknown skill' and stalls the whole run.
  foreach ($f in Get-ChildItem (Join-Path $kit "global\commands") -Filter *.md) {
    $text = Get-Content $f.FullName -Raw
    if ($text -match '\b[a-z][a-z0-9-]*-agent\b') {
      Assert ($text -match 'Task tool') "$($f.Name) mentions an agent but never says 'Task tool'"
    }
  }
}

# Anti-fragmentation: a custom command whose name matches a Claude Code built-in is SILENTLY SHADOWED
# (it just never loads), and there is a known bug where one collision can break all custom commands.
# Refresh this list from `claude` docs occasionally; it is a point-in-time snapshot.
$builtinCommands = @('init','memory','mcp','agents','permissions','plan','model','effort','context','compact',
 'btw','clear','reset','new','resume','continue','branch','fork','teleport','tp','remote-control','rc','cd',
 'add-dir','diff','code-review','simplify','review','security-review','rewind','checkpoint','undo','batch',
 'tasks','bashes','background','bg','stop','exit','quit','goal','loop','proactive','schedule','routines',
 'workflows','autofix-pr','config','settings','theme','tui','keybindings','statusline','color','scroll-speed',
 'terminal-setup','help','usage','cost','stats','status','export','copy','doctor','debug','hooks','insights',
 'feedback','bug','share','advisor','voice','recorder','ide','chrome','desktop','app','plugin',
 'install-github-app','install-slack-app','ultraplan','ultrareview','remote-env','web-setup','run','verify',
 'run-skill-generator','login','logout','mobile','ios','android','radio','upgrade','passes','release-notes',
 'powerup','team-onboarding','rename','focus','reload-plugins','reload-skills','heapdump','sandbox',
 'privacy-settings','usage-credits','extra-usage','setup-bedrock','setup-vertex','vendor-id','skill','vim',
 'pr-comments')
$builtinAgentTypes = @('claude','claude-code-guide','Explore','general-purpose','Plan','statusline-setup','fork')

Test-Case "no command shadows a Claude Code built-in" {
  $clash = $commands | Where-Object { $builtinCommands -contains $_.ToLower() }
  Assert (-not $clash) "these would be silently shadowed: $($clash -join ', ')"
}

Test-Case "no agent shadows a built-in agent type" {
  $clash = $agents | Where-Object { $builtinAgentTypes -contains $_ }
  Assert (-not $clash) "collides with a built-in agent type: $($clash -join ', ')"
}

Test-Case "install rewrites the dev-path placeholder in BOTH commands and agents" {
  # A plain Copy-Item for agents left librarian-agent's absolute doc-stats.ps1 path pointing at the DEV
  # machine, so the counter silently could not run after a folder-copy install.
  $lines = Get-Content (Join-Path $kit "install.ps1")
  foreach ($dir in @('commands', 'agents')) {
    $hasPlaceholder = @(Get-ChildItem (Join-Path $kit "global\$dir") -Filter *.md |
                        Where-Object { (Get-Content $_.FullName -Raw) -match 'DAD-kit' }).Count -gt 0
    if (-not $hasPlaceholder) { continue }
    # find the line that enumerates that folder, then look a few lines ahead for the placeholder rewrite
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -like "*global\$dir*" -and $lines[$i] -like "*Get-ChildItem*") { $idx = $i; break }
    }
    Assert ($idx -ge 0) "install.ps1 does not enumerate global\$dir with Get-ChildItem (a plain Copy-Item cannot rewrite paths)"
    $window = ($lines[$idx..([Math]::Min($idx + 4, $lines.Count - 1))] -join "`n")
    Assert ($window -like '*Replace($old*') `
      "install.ps1 enumerates global\$dir but does not Replace(`$old ...) - the dev-path placeholder would ship unrewritten"
  }
}

Test-Case "every executable a command tells the model to run is permitted" {
  # A command that shells out to something missing from settings.json's allow list hits a permission
  # prompt and gets silently skipped in an autonomous loop. That is exactly how close-unit.ps1 never ran
  # for a whole /build session: 'powershell' was not allowed.
  $allow = (Get-Content (Join-Path $kit "settings.json") -Raw | ConvertFrom-Json).permissions.allow
  $allowed = @($allow | ForEach-Object { if ($_ -match '^Bash\(([^:)]+)') { $Matches[1] } })
  foreach ($f in Get-ChildItem (Join-Path $kit "global\commands") -Filter *.md) {
    $text = Get-Content $f.FullName -Raw
    foreach ($mm in [regex]::Matches($text, '(?m)^\s*(?:```\s*)?([a-z][a-z0-9_.-]*)\s+[^\r\n]*(?:\.ps1|\.cmd|--reindex)')) {
      $exe = $mm.Groups[1].Value
      if ($exe -in @('rem','note','it','the','and','powershell','pwsh','cmd')) {
        Assert ($allowed -contains $exe -or $exe -notin @('powershell','pwsh','cmd')) `
          "$($f.Name) runs '$exe' but settings.json does not allow Bash($exe`:*)"
      }
    }
  }
  # explicit: the close-out script is the load-bearing one
  $usesPs = @(Get-ChildItem (Join-Path $kit "global\commands") -Filter *.md |
              Where-Object { (Get-Content $_.FullName -Raw) -match 'powershell\s' })
  if ($usesPs.Count -gt 0) {
    Assert ($allowed -contains 'powershell') `
      "$(($usesPs.Name) -join ', ') invoke powershell but Bash(powershell:*) is not in the allow list"
  }
}

Test-Case "install.ps1's command echo matches the actual commands" {
  # The echo drifted during the 0.9.8 rename (it advertised agents that do not exist). It is the first
  # thing a user reads after installing, so it must not lie.
  $echo = (Get-Content (Join-Path $kit "install.ps1") | Where-Object { $_ -like '*commands: /scaffold*' }) -join ' '
  Assert $echo "install.ps1 has no command echo line"
  # Only the part before 'agents:' - the agents half uses '/' as a separator, not as a command prefix.
  $cmdPart = ($echo -split 'agents:')[0]
  foreach ($c in $commands) { Assert ($cmdPart -match "/$([regex]::Escape($c))\b") "install echo omits /$c" }
  foreach ($m in [regex]::Matches($cmdPart, '/([a-z][a-z0-9-]*)')) {
    Assert ($commands -contains $m.Groups[1].Value) "install echo advertises /$($m.Groups[1].Value) which is not a command"
  }
}

Test-Case "no retired name is still shipped as a command or agent" {
  # install.ps1 deletes retired names from ~/.claude; the kit itself must not re-add them.
  $inst = Get-Content (Join-Path $kit "install.ps1") -Raw
  $m = [regex]::Match($inst, '\$retiredCommands\s*=\s*@\(([^)]*)\)')
  Assert $m.Success "install.ps1 has no `$retiredCommands list"
  $retired = [regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
  foreach ($r in $retired) {
    Assert ($commands -notcontains $r) "'$r' is listed as retired but still exists as a command"
  }
  $ma = [regex]::Match($inst, '\$retiredAgents\s*=\s*@\(([^)]*)\)')
  if ($ma.Success) {
    foreach ($r in ([regex]::Matches($ma.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })) {
      Assert ($agents -notcontains $r) "'$r' is listed as retired but still exists as an agent"
    }
  }
}

Test-Case "every .ps1 has a .cmd wrapper" {
  foreach ($f in Get-ChildItem $kit -Filter *.ps1 -File) {
    Assert (Test-Path (Join-Path $kit "$($f.BaseName).cmd")) "$($f.Name) has no .cmd wrapper"
  }
}

Test-Case "each command has description frontmatter" {
  foreach ($f in Get-ChildItem (Join-Path $kit "global\commands") -Filter *.md) {
    $head = (Get-Content $f.FullName -TotalCount 5) -join "`n"
    Assert ($head -match '(?m)^description:\s*\S') "$($f.Name): missing 'description:'"
  }
}

# ---------------------------------------------------------------- models manifest
Write-Host "-- models --" -ForegroundColor Cyan
$mfPath = Join-Path $kit "models.json"

Test-Case "README's version banner matches VERSION" {
  # It said 0.9.0 for eight releases. The version is the first thing a reader sees.
  $v = (Get-Content (Join-Path $kit "VERSION") -Raw).Trim()
  $readme = Get-Content (Join-Path $kit "README.md") -Raw
  Assert ($readme -match "\*\*Version\s+$([regex]::Escape($v))\*\*") "README banner does not say **Version $v**"
}

Test-Case "models.json is valid and complete" {
  Assert (Test-Path $mfPath) "models.json missing"
  $mf = Get-Content $mfPath -Raw | ConvertFrom-Json
  Assert ($mf.numCtx -ge 32768) "numCtx too small for the agent loop: $($mf.numCtx)"
  # Fit must be computable including the KV cache - weights-only numbers read as comfortable when they
  # are not (three "14-16 GB" models are actually at or over a 16 GB card at 64K context).
  Assert ($mf.assumeVramGb -ge 1) "models.json needs assumeVramGb for the fit calculation"
  Assert ($mf.kvCacheGbAt64k -ge 1) "models.json needs kvCacheGbAt64k - fit must account for the KV cache"
  Assert (-not ($mf.models | Where-Object { $_.alias -eq 'plan' })) "'plan' was retired - oss is the planner"
  Assert ($mf.embedModel) "no embedModel"
  Assert ($mf.models.Count -ge 1) "no models declared"
  foreach ($m in $mf.models) {
    foreach ($f in @('alias','name','from','role','approxVramGb')) {
      Assert ($m.PSObject.Properties.Name -contains $f) "model '$($m.name)' missing field '$f'"
    }
    Assert ($m.name -like "*-cc") "variant '$($m.name)' should end in -cc"
    Assert ($m.name -ne $m.from) "variant name must differ from the base tag ($($m.name))"
  }
  $dupA = ($mf.models.alias | Group-Object | Where-Object Count -gt 1).Name
  Assert (-not $dupA) "duplicate alias(es): $($dupA -join ', ')"
  $dupN = ($mf.models.name | Group-Object | Where-Object Count -gt 1).Name
  Assert (-not $dupN) "duplicate variant name(s): $($dupN -join ', ')"
  Assert ((@($mf.models | Where-Object { $_.default })).Count -eq 1) "exactly one model must be default"
}

Test-Case "no hand-written Modelfiles remain (generated from the manifest)" {
  $stale = Get-ChildItem $kit -Filter *.Modelfile -ErrorAction SilentlyContinue
  Assert (-not $stale) "found: $(($stale.Name) -join ', ') - models.json is the source of truth now"
}

Test-Case "settings.json default model matches the manifest default" {
  $mf = Get-Content $mfPath -Raw | ConvertFrom-Json
  $def = ($mf.models | Where-Object { $_.default }).name
  $s = Get-Content (Join-Path $kit "settings.json") -Raw | ConvertFrom-Json
  Assert ($s.env.ANTHROPIC_MODEL -eq $def) "settings says '$($s.env.ANTHROPIC_MODEL)', manifest default is '$def'"
  Assert ($s.env.ANTHROPIC_SMALL_FAST_MODEL -eq $mf.smallFastModel) "smallFastModel mismatch"
}

Test-Case "use-model resolves aliases from the manifest" {
  $src = Get-Content (Join-Path $kit "use-model.ps1") -Raw
  Assert ($src -match 'models\.json') "use-model.ps1 does not read models.json"
  Assert ($src -notmatch '\$map\s*=\s*@\{\s*dev\s*=') "use-model.ps1 still has a hard-coded alias map"
}

Test-Case "install/uninstall drive models from the manifest" {
  $inst = Get-Content (Join-Path $kit "install.ps1") -Raw
  Assert ($inst -match 'sync-models\.ps1') "install.ps1 does not call sync-models.ps1"
  Assert ($inst -notmatch '\.Modelfile') "install.ps1 still references .Modelfile paths"
  $un = Get-Content (Join-Path $kit "uninstall.ps1") -Raw
  Assert ($un -match 'models\.json') "uninstall.ps1 does not read models.json for variant names"
}

Test-Case "sync-models -Report runs without changing anything" {
  if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) { return }   # optional in CI
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "sync-models.ps1") -Report | Out-Null
  Assert ($LASTEXITCODE -eq 0) "exit $LASTEXITCODE"
}

Test-Case "sync-models -Report runs END TO END against a fake ollama" {
  # -Report exits at line 1 on a box with no ollama, so the entire report - including the BORDERLINE
  # warning that carried a fatal inline `if` - was never executed by any test. It shipped broken and
  # died on the target machine during install. Stub ollama so the whole script actually runs.
  $sb = New-Sandbox
  try {
    $bin = Join-Path $sb "bin"; New-Item -ItemType Directory -Force $bin | Out-Null
    $mf = Get-Content $mfPath -Raw | ConvertFrom-Json
    # Report every declared variant as present so every row renders and every branch is reached.
    $names = @($mf.models.name) + @($mf.embedModel, $mf.visionModel, $mf.smallFastModel) | Where-Object { $_ }
    Set-Content (Join-Path $bin "ollama.cmd") "@echo off`r`necho $($names -join ' ')" -Encoding ASCII

    $script = Join-Path $kit "sync-models.ps1"
    $cmd = "`$env:PATH = '$bin;' + `$env:PATH; & '$script' -Report; exit `$LASTEXITCODE"
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1 | Out-String
    $code = $LASTEXITCODE

    Assert ($out -notmatch 'is not recognized') "sync-models hit a runtime command error:`n$out"
    Assert ($out -notmatch 'CommandNotFound')   "sync-models hit CommandNotFound:`n$out"
    Assert ($code -eq 0) "sync-models -Report exited $code`n$out"
    Assert ($out -match 'BORDERLINE') "the BORDERLINE branch never rendered - it is still untested`n$out"
    Assert ($out -match 'Weights' -and $out -match 'PlusKV') "the fit table did not render`n$out"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the VRAM fit math runs and classifies correctly (no ollama needed)" {
  # The fit block lives inside sync-models' and dad-doctor's ollama sections, so on a box without
  # ollama nothing exercised it. Run the same rules here against the real manifest.
  $mf = Get-Content $mfPath -Raw | ConvertFrom-Json
  $budget = $mf.assumeVramGb
  $seen = @{}
  foreach ($m in $mf.models) {
    $kvGb = 0
    if ($mf.kvCacheGbAt64k) { $kvGb = $mf.kvCacheGbAt64k }
    if (($m.PSObject.Properties.Name -contains 'kvGb') -and $m.kvGb) { $kvGb = $m.kvGb }
    $effGb = $m.approxVramGb + $kvGb
    $fit = "offloads"
    if ($effGb -le ($budget + 1)) { $fit = "BORDERLINE" }
    if (($effGb + 1.5) -le $budget) { $fit = "fits GPU" }
    Assert ($effGb -gt 0) "$($m.alias): effective VRAM computed as $effGb"
    $seen[$fit] = $true
  }
  # A manifest where everything lands in one bucket means the thresholds are not doing any work.
  Assert ($seen.Keys.Count -ge 2) "every model classified the same way - check assumeVramGb/kvCacheGbAt64k"
  Assert ($seen.ContainsKey("BORDERLINE")) "nothing is BORDERLINE - the warning path is untested"
}

Test-Case "the stop-guard path check does not flag a healthy install" {
  # A kit installed at D:\...\DAD-kit\ is CORRECT, but its path contains the substring the check used
  # to look for, so a clean install reported "still points at the dev placeholder". Verify the rule
  # against all three cases. dad-doctor reads the real %USERPROFILE% settings, so exercise the rule
  # here rather than mutating the developer's own install.
  $rule = {
    param($stopCmd, $kitDir)
    $expected = Join-Path $kitDir "dad-guard.ps1"
    $placeholder = 'C:\Projects\Claude\MCP\DAD-kit\dad-guard.ps1'
    if ($stopCmd -like "*$expected*") { "OK" }
    elseif ($stopCmd -like "*$placeholder*") { "PLACEHOLDER" }
    else { "ELSEWHERE" }
  }
  # A REAL directory, named DAD-kit - the shape that broke. (Join-Path throws on a drive that does not
  # exist, so a made-up D:\ path would leave $expected null and -like "**" would match anything.)
  $sb = New-Sandbox
  try {
    $installed = Join-Path $sb "DAD-kit"; New-Item -ItemType Directory -Force $installed | Out-Null
    Assert ((& $rule "powershell -File `"$installed\dad-guard.ps1`"" $installed) -eq "OK") `
      "a correctly installed kit whose folder is named DAD-kit was flagged"
    Assert ((& $rule 'powershell -File "C:\Projects\Claude\MCP\DAD-kit\dad-guard.ps1"' $installed) -eq "PLACEHOLDER") `
      "an un-rewritten placeholder path was not detected"
    Assert ((& $rule "powershell -File `"$sb\other\dad-guard.ps1`"" $installed) -eq "ELSEWHERE") `
      "a hook pointing at a different kit copy was not detected"
  } finally { Remove-Sandbox $sb }
  # and the shipped script must use the resolved path, not the old substring
  $doc = Get-Content (Join-Path $kit "dad-doctor.ps1") -Raw
  Assert ($doc -match 'expectedGuard') "dad-doctor is not comparing against the resolved kit path"
  Assert ($doc -notmatch "'DAD-kit\\\\dad-guard'") "dad-doctor still uses the substring match that flagged healthy installs"
}

Test-Case "dad-doctor runs and reports (exit code reflects failures only)" {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "dad-doctor.ps1") | Out-Null
  Assert (($LASTEXITCODE -eq 0) -or ($LASTEXITCODE -eq 1)) "unexpected exit $LASTEXITCODE"
}

# ---------------------------------------------------------------- secret scanner
Write-Host "-- secrets --" -ForegroundColor Cyan

# Fixtures are BUILT BY CONCATENATION so this suite never itself contains a credential-shaped literal
# (which would trip the "kit is clean" test), and each family is planted ALONE so one family's finding
# cannot mask another's silent suppression - that is how the AKIA...EXAMPLE bug originally hid.
function Test-SecretPattern([string]$label, [string]$payload) {
  Test-Case "scan-secrets flags: $label" {
    $sb = New-Sandbox
    try {
      Set-Content "$sb\f.txt" $payload -Encoding UTF8
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "scan-secrets.ps1") -Path $sb -Quiet | Out-Null
      Assert ($LASTEXITCODE -eq 1) "not flagged (exit $LASTEXITCODE)"
    } finally { Remove-Sandbox $sb }
  }
}
Test-SecretPattern "AWS access key id"   ("aws_access_key_id = A" + "KIA" + "IOSFODNN7" + "ABCDEFG")
Test-SecretPattern "GitHub PAT"          ("gh" + "p_" + ('a' * 36))
Test-SecretPattern "Slack token"         ("xo" + "xb-" + "1234567890" + "-abcdefghij")
Test-SecretPattern "Google API key"      ("AI" + "za" + ('B' * 35))
Test-SecretPattern "Anthropic API key"   ("sk-" + "ant-" + ('c' * 24))
Test-SecretPattern "private key (PEM)"   ("-----BEGIN " + "RSA PRIVATE KEY" + "-----")
Test-SecretPattern "JWT"                 ("ey" + "J0eXAiOiJKV1Qi" + "." + ('a' * 20) + "." + ('b' * 20))
Test-SecretPattern "Azure storage key"   ("AccountKey" + "=" + ('d' * 44))

Test-Case "structural matches are NOT suppressed by the word 'example'" {
  # Regression: AWS's documented EXAMPLE key id was being silently ignored because the placeholder
  # filter applied to every rule. Placeholder suppression must apply ONLY to keyword-heuristic rules.
  $sb = New-Sandbox
  try {
    Set-Content "$sb\f.txt" ("aws_access_key_id = A" + "KIA" + "IOSFODNN7" + "EXAMPLE") -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "scan-secrets.ps1") -Path $sb -Quiet | Out-Null
    Assert ($LASTEXITCODE -eq 1) "an EXAMPLE-suffixed key id was suppressed (exit $LASTEXITCODE)"
  } finally { Remove-Sandbox $sb }
}

Test-Case "scan-secrets honors industry-standard allowlist markers" {
  # Don't force people to learn a kit-specific pragma when detect-secrets/gitleaks markers already exist.
  $sb = New-Sandbox
  try {
    $tok = "gh" + "p_" + ('e' * 36)
    Set-Content "$sb\a.txt" "$tok  # pragma: allowlist secret" -Encoding UTF8
    Set-Content "$sb\b.txt" "$tok  # gitleaks:allow" -Encoding UTF8
    Set-Content "$sb\c.txt" "$tok  # trufflehog:ignore" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "scan-secrets.ps1") -Path $sb -Quiet | Out-Null
    Assert ($LASTEXITCODE -eq 0) "standard allowlist markers were not honored (exit $LASTEXITCODE)"
  } finally { Remove-Sandbox $sb }
}

Test-Case "install-hooks does not hijack husky/pre-commit projects" {
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\.husky" | Out-Null
    Push-Location $p; $ErrorActionPreference = "Continue"; git init -q; Pop-Location
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "install-hooks.ps1") -ProjectDir $p | Out-Null
    Assert (-not (Test-Path (Join-Path $p ".git\hooks\pre-commit"))) "overwrote hook management in a husky project"
  } finally { Remove-Sandbox $sb }
}

Test-Case "scan-secrets ignores placeholders and honors DAD-ALLOW-SECRET" {
  $sb = New-Sandbox
  try {
    Set-Content "$sb\a.md"   'password: <your-password-here>' -Encoding UTF8
    Set-Content "$sb\b.md"   'api_key = ${MY_API_KEY}' -Encoding UTF8
    Set-Content "$sb\c.yml"  'token: $env:SOME_TOKEN' -Encoding UTF8
    Set-Content "$sb\d.txt"  ("gh" + "p_" + ('b' * 36) + '   # DAD-ALLOW-SECRET') -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "scan-secrets.ps1") -Path $sb -Quiet | Out-Null
    Assert ($LASTEXITCODE -eq 0) "scanner false-positived on placeholders (exit $LASTEXITCODE)"
  } finally { Remove-Sandbox $sb }
}

Test-Case "scan-secrets never prints the matched value" {
  $sb = New-Sandbox
  try {
    $secret = "gh" + "p_" + ('c' * 36)
    Set-Content "$sb\x.md" $secret -Encoding UTF8
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "scan-secrets.ps1") -Path $sb | Out-String)
    Assert ($out -notmatch [regex]::Escape($secret)) "the scanner echoed the secret"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the kit itself is clean of credentials" {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "scan-secrets.ps1") -Path $kit -Quiet | Out-Null
  Assert ($LASTEXITCODE -eq 0) "scan-secrets found something in the kit"
}

# ---------------------------------------------------------------- scaffold / upgrade / close-unit
Write-Host "-- stop guard --" -ForegroundColor Cyan

Test-Case "settings.json wires dad-guard as a Stop hook, at a rewritable path" {
  $s = Get-Content (Join-Path $kit "settings.json") -Raw | ConvertFrom-Json
  $cmds = @($s.hooks.Stop | ForEach-Object { $_.hooks } | ForEach-Object { $_.command })
  Assert ($cmds.Count -ge 1) "no Stop hook in settings.json"
  Assert (($cmds -join " ") -match 'dad-guard\.ps1') "the Stop hook does not run dad-guard.ps1"
  # It must carry the placeholder, and install must reach it through the PARSED object. JSON escapes
  # backslashes, so a raw-text replace of C:\Projects\... finds nothing on disk - a bug I shipped and
  # caught here. This asserts the shape install.ps1 depends on.
  $devPath = 'C:\Projects\Claude\MCP\DAD-kit'
  Assert ((($cmds -join " ") -match [regex]::Escape($devPath))) "hook command does not use the dev-path placeholder"
  $rewritten = @($cmds | ForEach-Object { $_.Replace($devPath, "D:\elsewhere") })
  Assert (($rewritten -join " ") -notmatch [regex]::Escape($devPath)) "placeholder is not rewritable via the parsed object"
  $inst = Get-Content (Join-Path $kit "install.ps1") -Raw
  Assert ($inst -match '\$h\.command\s*=\s*\$h\.command\.Replace') "install.ps1 does not rewrite the hook command"
  $unin = Get-Content (Join-Path $kit "uninstall.ps1") -Raw
  Assert ($unin -match "Remove\('Stop'\)") "uninstall.ps1 leaves a Stop hook pointing at a deleted script"
}

Test-Case "dad-guard BLOCKS unverified code and clears after close-unit" {
  # The run002 failure: 7,115 lines, 106 edits, zero shell calls, 47 dirty files at exit, and nobody
  # knew until the transcript was read. This is the one gate the model does not get to skip.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    New-Item -ItemType Directory -Force "$p\src" | Out-Null
    "# Design`n`nStatus: LOCKED" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    "# Task map`n`n## Tasks`n`n### [ ] T1.1 - thing   (Story S1)`n- **Goal:** x" |
      Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    "# Project: t`n`n## Build / test`n- Build: ``exit 0```n- Test:  ``exit 0``" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $guard = Join-Path $kit "dad-guard.ps1"
    # clean tree -> allow
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 0) "blocked with a clean tree"

    # a docs edit alone must NOT block - docs churn is the agents' job
    "# Design`n`nStatus: LOCKED`n`nmore" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 0) "a docs-only change blocked the stop"

    # uncommitted CODE -> block
    "public class Thing { }" | Set-Content "$p\src\Thing.cs" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 1) "unverified code did NOT block the stop"

    # closing the unit verifies + commits, so the guard must clear
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "close-unit.ps1") `
      -Id T1.1 -Title "thing" -ProjectDir $p -NoReindex | Out-Null
    Assert ($LASTEXITCODE -eq 0) "close-unit failed in the fixture"
    Assert (Test-Path "$p\.claude\.dad-verified") "close-unit did not write the .dad-verified stamp"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 0) "still blocking after a clean close-unit"

    # a NEW edit after the stamp must block again (the stamp is not a permanent pass)
    Start-Sleep -Milliseconds 1100
    "public class Other { }" | Set-Content "$p\src\Other.cs" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 1) "the stamp permanently disarmed the guard"

    # -Ack is the deliberate escape hatch
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Ack -ProjectDir $p | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 0) "-Ack did not clear the guard"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the old brand is gone, and pre-rename projects still work" {
  # Half-finished renames are how a kit ends up with two vocabularies. Assert the old brand is gone from
  # kit text - while leaving 'ad-hoc' alone, which a case-insensitive sweep would happily mangle.
  # CHANGELOG.md is a historical record - the entry announcing the rename has to be able to name the
  # old brand, and so do the entries written before it. Everything else must read DAD.
  $files = Get-KitFiles @("*.ps1","*.cmd","*.md","*.json","*.py","*.yml") |
    Where-Object { $_.Name -ne "CHANGELOG.md" }
  # Lines that legitimately NAME the old brand - the legacy marker constants, and prose explaining the
  # rename - opt out with a DAD-RENAME-OK marker. An explicit opt-out beats guessing at intent, and the
  # legacy constants' PRESENCE is asserted below so a future tidy-up cannot quietly delete them.
  $brandPattern = '\bAD\b(?!-ALLOW-SECRET)|BMAADD|\bAD-kit|\bad-doctor\b|\bad-guard\b'   # DAD-RENAME-OK
  $brand = @($files | Select-String -Pattern $brandPattern -CaseSensitive |
    Where-Object { $_.Line -notmatch 'DAD-RENAME-OK' })
  # DAD-RENAME-OK
  Assert ($brand.Count -eq 0) "old branding survives in: $(($brand | Select-Object -First 3 | ForEach-Object { "$($_.Filename):$($_.LineNumber)" }) -join ', ')"
  Assert (($files | Select-String -Pattern 'ad-hoc' -CaseSensitive).Count -ge 1) "the sweep ate 'ad-hoc'"
  # Built by concatenation so this line does not match itself - same idiom as the secret fixtures.
  $mangled = 'DAD' + '-hoc|D' + 'DAD'
  Assert (($files | Select-String -Pattern $mangled -CaseSensitive).Count -eq 0) "the sweep mangled a word into the brand"
  $guardSrc = Get-Content (Join-Path $kit "dad-guard.ps1") -Raw
  Assert ($guardSrc -match '\.ad-verified' -and $guardSrc -match '\.ad-kit-version') "dad-guard dropped pre-rename project support"
  Assert ((Get-Content (Join-Path $kit "scan-secrets.ps1") -Raw) -match 'AD-ALLOW-SECRET') "scan-secrets dropped the pre-rename allowlist marker"

  # The pre-rename allowlist marker lives in USER source files. Dropping it would silently un-suppress
  # lines someone already reviewed - the scanner must honor both spellings forever.
  $sb = New-Sandbox
  try {
    Set-Content "$sb\legacy.txt" ("AKIA" + ("Q" * 16) + "   # AD-ALLOW-SECRET") -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "scan-secrets.ps1") -Path $sb | Out-Null
    Assert ($LASTEXITCODE -eq 0) "the pre-rename AD-ALLOW-SECRET marker stopped suppressing"
  } finally { Remove-Sandbox $sb }
}

Test-Case "upgrade-project migrates a pre-rename project's markers" {   # DAD-RENAME-OK
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    New-Item -ItemType Directory -Force "$p\.claude" | Out-Null
    "# Project: t`n`n## Stack`n- x" | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    "0.9.7" | Set-Content "$p\.ad-kit-version" -Encoding UTF8
    "verified-by: old" | Set-Content "$p\.claude\.ad-verified" -Encoding UTF8

    # Before the upgrade the guard must still SEE it as a DAD project - an unmigrated project silently
    # falling outside the guard is exactly the failure the guard exists to prevent.
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "dad-guard.ps1") -Check -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 0) "guard errored on a pre-rename project"

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "upgrade-project.ps1") $p 2>$null | Out-Null
    Assert (Test-Path "$p\.dad-kit-version") ".ad-kit-version was not migrated"
    Assert (-not (Test-Path "$p\.ad-kit-version")) "the old .ad-kit-version was left behind"
    # upgrade RE-STAMPS to the current kit version - that is its job. The migration is proven by the
    # old file being gone and the new one carrying a real version, not by preserving the old number.
    $kitVer = (Get-Content (Join-Path $kit "VERSION") -Raw).Trim()
    Assert ((Get-Content "$p\.dad-kit-version" -Raw).Trim() -eq $kitVer) "the migrated stamp does not hold the current kit version"
    Assert (Test-Path "$p\.claude\.dad-verified") ".ad-verified was not migrated"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the guard names commands that can actually be RUN" {
  # Observed: the guard blocked, the model went looking for `close-unit.cmd`, could not find it (the kit
  # folder is not on PATH on a target machine), and the session ended with 36 verified-but-uncommitted
  # files. A gate that demands an action has to name it exactly, with a resolvable path.
  $g = Get-Content (Join-Path $kit "dad-guard.ps1") -Raw
  Assert ($g -match '\$kitDir\s*=\s*\$PSScriptRoot') "the guard does not resolve its own kit folder"
  Assert ($g -match '\$closeCmd' -and $g -match 'close-unit\.ps1') "the guard does not name close-unit.ps1 by path"
  # the bare form must be gone from the message it emits
  Assert ($g -notmatch '(?m)^\s+close-unit\.cmd -Id') "the guard still prints bare close-unit.cmd (not on PATH)"
  Assert ($g -notmatch '(?m)^\s+dad-guard\.cmd -Ack') "the guard still prints bare dad-guard.cmd (not on PATH)"

  # prove the emitted text really contains a runnable path
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    New-Item -ItemType Directory -Force "$p\src" | Out-Null
    "# Design`n`nStatus: LOCKED" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location
    # An UNTRACKED directory: git reports it as "?? src/" unless you pass -uall, and that bare directory
    # name has no code extension. This is the shape that slipped through - a whole new source folder.
    "public class X { }" | Set-Content "$p\src\X.cs" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "dad-guard.ps1") -Check -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 1) "guard missed code inside an untracked directory (needs git status -uall)"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the guard blames only THIS session, not inherited dirt" {
  # It fired on turn one of a real run over 35 files left by the PREVIOUS session, with "this is exactly
  # how a run produces thousands of unverified edits" - an accusation about work it had not done. A guard
  # that opens by crying wolf is one everybody learns to scroll past.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    New-Item -ItemType Directory -Force "$p\src" | Out-Null
    "# Design`n`nStatus: LOCKED" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    # dirt from a PREVIOUS session
    "public class Old { }" | Set-Content "$p\src\Old.cs" -Encoding UTF8
    Start-Sleep -Milliseconds 1100
    # a transcript created AFTER that edit == this session started later
    $tr = Join-Path $sb "transcript.jsonl"; "{}" | Set-Content $tr -Encoding UTF8

    $hook = @{ cwd = $p; transcript_path = $tr; stop_hook_active = $false } | ConvertTo-Json -Compress
    $hook | & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "dad-guard.ps1") | Out-Null
    Assert ($LASTEXITCODE -eq 0) "the guard blocked a session for dirt it inherited"

    # now THIS session touches code -> it must block, and say so
    Start-Sleep -Milliseconds 1100
    "public class New { }" | Set-Content "$p\src\New.cs" -Encoding UTF8
    $out = ($hook | & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "dad-guard.ps1") 2>&1) | Out-String
    Assert ($LASTEXITCODE -eq 2) "the guard did not block on code THIS session changed"
    Assert ($out -match 'New\.cs') "the block did not name the file this session changed"
    Assert ($out -match 'already uncommitted when this session started') "inherited files were not reported as context"
  } finally { Remove-Sandbox $sb }
}

Test-Case "doc-stats -UpdateStatus writes the Snapshot; the model never counts" {
  # A real audit claimed "STATUS.md refreshed with current progress metrics" having never run doc-stats.
  # Prose telling an agent to run a script is not a gate. The counts are generated now.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Design`n`nStatus: LOCKED" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    "# Stories`n`n### Story S1: One   <!-- Status: DONE -->`n`n### Story S2: Two   <!-- Status: TODO -->" |
      Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    "# Task map`n`n## Tasks`n`n### [x] T1.1 - a   (Story S1)`n- **Goal:** x`n`n### [ ] T2.1 - b   (Story S2)`n- **Goal:** y" |
      Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    Copy-Item (Join-Path $kit "templates\_common\docs\STATUS.md") "$p\docs\STATUS.md"
    "- <YYYY-MM-DD> stale hand-written blocker" | Add-Content "$p\docs\STATUS.md"

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -UpdateStatus | Out-Null
    Assert ($LASTEXITCODE -eq 0) "-UpdateStatus exited $LASTEXITCODE"
    $s = Get-Content "$p\docs\STATUS.md" -Raw
    Assert ($s -match 'Stories: 1/2') "Snapshot has the wrong story count:`n$s"
    Assert ($s -match 'Tasks: 1/2')   "Snapshot has the wrong task count:`n$s"
    Assert ($s -match 'NEXT: T2\.1')  "Snapshot does not name the next ready task:`n$s"
    Assert ($s -match 'do not hand-edit') "Snapshot is not marked as generated"
    # the librarian's own sections must survive
    Assert ($s -match 'Issues & blockers') "-UpdateStatus destroyed the prose sections"
    Assert ($s -match 'stale hand-written blocker') "-UpdateStatus discarded librarian-owned content"
    # and it must be idempotent - not stack a second Snapshot on every audit
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -UpdateStatus | Out-Null
    $s2 = Get-Content "$p\docs\STATUS.md" -Raw
    Assert (([regex]::Matches($s2, '## Snapshot')).Count -eq 1) "a second run stacked another Snapshot block"

    # /audit and the librarian must both point at the generating flag
    Assert ((Get-Content (Join-Path $kit "global\commands\audit.md") -Raw) -match 'doc-stats\.ps1" -UpdateStatus') `
      "/audit does not generate the counts before spawning the librarian"
    Assert ((Get-Content (Join-Path $kit "global\agents\librarian-agent.md") -Raw) -match '-UpdateStatus') `
      "librarian-agent still computes its own counts"
  } finally { Remove-Sandbox $sb }
}

Test-Case "dad-guard fails OPEN and cannot loop" {
  # A guard that blocks on its own bugs is worse than the problem. And a Stop hook that blocks its own
  # retry deadlocks the session - the harness sets stop_hook_active on that pass and we must let it go.
  $sb = New-Sandbox
  try {
    $guard = Join-Path $kit "dad-guard.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $sb | Out-Null
    Assert ($LASTEXITCODE -eq 0) "blocked a folder that is not a DAD project"

    New-Item -ItemType Directory -Force "$sb\docs" | Out-Null
    "# Design" | Set-Content "$sb\docs\DESIGN.md" -Encoding UTF8
    "x" | Set-Content "$sb\stray.cs" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $sb | Out-Null
    Assert ($LASTEXITCODE -eq 0) "blocked a DAD project with no git repo"

    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir "$sb\does-not-exist" | Out-Null
    Assert ($LASTEXITCODE -eq 0) "blocked on a nonexistent directory"

    # hook mode, retry pass: must exit 0 no matter what the tree looks like
    $json = '{"stop_hook_active":true,"cwd":"' + $sb.Replace('\','\\') + '"}'
    $json | & powershell -NoProfile -ExecutionPolicy Bypass -File $guard | Out-Null
    Assert ($LASTEXITCODE -eq 0) "the guard blocks its own retry - this would deadlock the session"
  } finally { Remove-Sandbox $sb }
}

Test-Case "/build gates on a LOCKED design and proves the shell first" {
  $b = Get-Content (Join-Path $kit "global\commands\build.md") -Raw
  Assert ($b -match 'DESIGN must be LOCKED') "/build no longer gates on LOCKED"
  Assert ($b -match 'doc-stats\.ps1') "/build does not run a shell preflight"
  # It must not silently degrade to proto - R7 says /build gates on LOCKED.
  Assert ($b -notmatch "``DRAFT``\s*->\s*PROTO mode") "/build still falls through to PROTO mode on a DRAFT design"
  $g = Get-Content (Join-Path $kit "global\agents\grade-agent.md") -Raw
  Assert ($g -match 'SEARCH BUDGET') "grade-agent has no search budget - one invocation burned 1015+ calls"
}

Write-Host "-- scripts --" -ForegroundColor Cyan
$haveGit = [bool](Get-Command git -ErrorAction SilentlyContinue)

Test-Case "new-project with no kind exits 1 (prints usage)" {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "new-project.ps1") | Out-Null
  Assert ($LASTEXITCODE -eq 1) "expected exit 1, got $LASTEXITCODE"
}

Test-Case "scaffold general: docs + wiring + git + hook" {
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "gen"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "new-project.ps1") general $p | Out-Null
    foreach ($f in @("CLAUDE.md", ".mcp.json", "docs\DESIGN.md", "docs\RECIPES.md", "docs\STATUS.md", ".gitignore")) {
      Assert (Test-Path (Join-Path $p $f)) "missing $f"
    }
    Assert (-not (Test-Path (Join-Path $p "docs\TEDD.md"))) "stray TEDD.md"
    Assert ((Get-Content (Join-Path $p "docs\DESIGN.md") -Raw) -match 'Status: DRAFT') "design doc not DRAFT"
    $cm = Get-Content (Join-Path $p "CLAUDE.md") -Raw
    Assert ($cm -notmatch '__DESIGN_DOC__') "token not resolved"
    Assert ($cm -match 'docs/DESIGN.md') "CLAUDE.md missing design-doc path"
    Assert ($cm -match '## Secrets') "CLAUDE.md missing Secrets section"
    $j = Get-Content (Join-Path $p ".mcp.json") -Raw | ConvertFrom-Json
    Assert ($j.mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR -like "*docs") "docs dir not wired"
    Assert ($j.mcpServers.'local-tools'.command -notmatch 'DAD-kit') "exe path not rewritten to this kit"
    $gi = Get-Content (Join-Path $p ".gitignore") -Raw
    Assert ($gi -match '\.env') ".gitignore missing .env"
    if ($haveGit) {
      Assert (Test-Path (Join-Path $p ".git")) "no git repo"
      Assert (Test-Path (Join-Path $p ".git\hooks\pre-commit")) "pre-commit hook not installed"
      Push-Location $p
      $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
      $st = (git status --porcelain | Out-String).Trim(); $log = (git log --oneline | Out-String)
      $ErrorActionPreference = $prev; Pop-Location
      Assert (-not $st) "working tree not clean after scaffold: $st"
      Assert ($log -match 'DAD scaffold') "no initial commit"
    }
  } finally { Remove-Sandbox $sb }
}

Test-Case "scaffold experience: TEDD instead of DESIGN" {
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "exp"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "new-project.ps1") experience $p | Out-Null
    Assert (Test-Path (Join-Path $p "docs\TEDD.md")) "no TEDD.md"
    Assert (-not (Test-Path (Join-Path $p "docs\DESIGN.md"))) "stray DESIGN.md"
    Assert ((Get-Content (Join-Path $p "CLAUDE.md") -Raw) -match 'docs/TEDD.md') "CLAUDE.md not pointing at TEDD"
  } finally { Remove-Sandbox $sb }
}

Test-Case "upgrade-project refreshes kit sections, preserves user sections, idempotent" {
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "old"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    # a deliberately STALE CLAUDE.md: old section wording, user-filled stack, no STATUS/Secrets sections
    @"
# Project: Legacy

## Stack
- Language / runtime: .NET 8 (C# 12)
- Key tools / libraries: System.CommandLine

## Modes (forge / proto / spec)
- old wording that must be replaced

## Design doc
- Design doc: ``docs/DESIGN.md``

## Build / test
- Build: dotnet build
- Test: dotnet test

## Working agreement
- old agreement
"@ | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Set-Content "$p\docs\DESIGN.md" "# Design`n`nStatus: LOCKED" -Encoding UTF8

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "upgrade-project.ps1") $p | Out-Null
    $cm = Get-Content "$p\CLAUDE.md" -Raw
    Assert ($cm -match '\.NET 8 \(C# 12\)') "user Stack was clobbered"
    Assert ($cm -match 'Build: dotnet build') "user Build/test was clobbered"
    Assert ($cm -match 'docs/STATUS.md') "Design docs section not refreshed"
    Assert ($cm -match '## Secrets') "Secrets section not added"
    Assert ($cm -match 'Task tool') "Modes section not refreshed (no Task-tool rule)"
    Assert ($cm -notmatch '__DESIGN_DOC__') "token not resolved"
    Assert ($cm -notmatch 'old wording that must be replaced') "stale Modes body survived"
    foreach ($f in @("docs\STATUS.md", "docs\RECIPES.md")) { Assert (Test-Path (Join-Path $p $f)) "missing $f" }
    $before = $cm
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "upgrade-project.ps1") $p | Out-Null
    Assert ((Get-Content "$p\CLAUDE.md" -Raw) -eq $before) "not idempotent"
  } finally { Remove-Sandbox $sb }
}

Test-Case "close-unit refuses a STORY close when tests run zero tests" {
  # The mediamotor failure: six test projects missing from the .sln, so `dotnet test` exited 0 having run
  # NOTHING while five stories were marked DONE. A green run of 0 tests must never close a story.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    New-Item -ItemType Directory -Force "$p\grades" | Out-Null
    ("# Grade - S1`n`n## Grade history`n| 1 | 2026-07-30 | A | init |`n`n## Assessment`n" + ('detail. ' * 120) + "`n## Suggestions`n1. none") |
      Set-Content "$p\grades\S1_GRADE.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location
    $cu = Join-Path $kit "close-unit.ps1"

    # a test command that succeeds but reports nothing (the silent no-op) -> refuse
    "# Project: t`n`n## Build / test`n- Build: ``echo ok```n- Test:  ``echo Build succeeded``" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id S1 -ProjectDir $p -NoReindex -RequireGrade 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0) "closed a story on a test run with no evidence any test ran"
    Assert (-not (Select-String "$p\docs\STORIES.md" -Pattern 'Status: DONE' -Quiet)) "marked the story DONE anyway"

    # explicit zero -> refuse
    "# Project: t`n`n## Build / test`n- Build: ``echo ok```n- Test:  ``echo Total: 0``" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id S1 -ProjectDir $p -NoReindex -RequireGrade 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0) "closed a story on Total: 0"

    # real test count -> accept
    "# Project: t`n`n## Build / test`n- Build: ``echo ok```n- Test:  ``echo Total: 12``" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id S1 -Title "One" -ProjectDir $p -NoReindex -RequireGrade | Out-Null
    Assert ($LASTEXITCODE -eq 0) "rejected a story whose tests actually ran"
    Assert (Select-String "$p\docs\STORIES.md" -Pattern 'Story S1.*Status: DONE' -Quiet) "did not mark the story DONE"
  } finally { Remove-Sandbox $sb }
}

Test-Case "upgrade-project migrates docs\COMMANDS.md -> RECIPES.md preserving entries" {
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "old"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Project: Legacy`n`n## Stack`n- Language / runtime: .NET`n`n## Build / test`n- Build: dotnet build" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Set-Content "$p\docs\DESIGN.md" "# Design`n`nStatus: LOCKED" -Encoding UTF8
    "# Proven commands - Legacy`n- **Command:** ``dotnet test --filter X``  MY-UNIQUE-ENTRY" |
      Set-Content "$p\docs\COMMANDS.md" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "upgrade-project.ps1") $p 2>&1 | Out-Null
    Assert (Test-Path "$p\docs\RECIPES.md") "RECIPES.md not created"
    Assert (-not (Test-Path "$p\docs\COMMANDS.md")) "old COMMANDS.md left behind"
    Assert ((Get-Content "$p\docs\RECIPES.md" -Raw) -match 'MY-UNIQUE-ENTRY') "migration lost the project's entries"
  } finally { Remove-Sandbox $sb }
}

Test-Case "close-unit -RequireGrade refuses a story with no real grade card" {
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location
    $cu = Join-Path $kit "close-unit.ps1"

    # no card at all -> refuse
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id S1 -ProjectDir $p -NoReindex -SkipVerify -RequireGrade 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0) "closed a story with no grade card"

    # stub card -> still refuse
    New-Item -ItemType Directory -Force "$p\grades" | Out-Null
    "# Grade - S1`nStatus: A" | Set-Content "$p\grades\S1_GRADE.md" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id S1 -ProjectDir $p -NoReindex -SkipVerify -RequireGrade 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0) "accepted a stub grade card"

    # real card -> accept
    ("# Grade - S1`n`n## Grade history`n| 1 | 2026-07-30 | A | initial |`n`n## Assessment`n" + ('detail. ' * 120) + "`n## Suggestions`n1. none") |
      Set-Content "$p\grades\S1_GRADE.md" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id S1 -Title "One" -ProjectDir $p -NoReindex -SkipVerify -RequireGrade | Out-Null
    Assert ($LASTEXITCODE -eq 0) "rejected a real grade card"
    Assert (Select-String "$p\docs\STORIES.md" -Pattern 'Story S1.*Status: DONE' -Quiet) "did not mark the story DONE"
  } finally { Remove-Sandbox $sb }
}

Test-Case "close-unit REFUSES to close a unit whose build fails" {
  # The failure this guards: 5 stories DONE, 6 tasks ticked, 4 checkpoint commits - over a build with 21
  # errors and zero tests ever run. Bookkeeping must never outrun verification.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Task map`n`n## Tasks`n`n### [ ] T1.1 - thing   (Story S1)`n- **Goal:** x" |
      Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    # a CLAUDE.md whose build command fails
    "# Project: t`n`n## Build / test`n- Build: ``exit 1```n- Test:  ``exit 0``" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "close-unit.ps1") `
      -Id T1.1 -Title "thing" -ProjectDir $p -NoReindex 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0) "close-unit closed the unit despite a failing build"
    Assert (-not (Select-String "$p\docs\TASKS.md" -Pattern '^###\s*\[x\]' -Quiet)) "it ticked the task anyway"
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $log = (git log --oneline | Out-String)
    $ErrorActionPreference = $prev; Pop-Location
    Assert ($log -notmatch 'T1\.1') "it committed anyway"

    # and with a passing build it DOES close
    "# Project: t`n`n## Build / test`n- Build: ``exit 0``" | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "close-unit.ps1") `
      -Id T1.1 -Title "thing" -ProjectDir $p -NoReindex | Out-Null
    Assert ($LASTEXITCODE -eq 0) "close-unit failed even with a passing build"
    Assert (Select-String "$p\docs\TASKS.md" -Pattern '^###\s*\[x\]\s*T1\.1' -Quiet) "did not tick after a passing build"
  } finally { Remove-Sandbox $sb }
}

Test-Case "close-unit: tick, roll-up timing, idempotent, commit, loud failure" {
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    @"
# Task map

## Build order
T1.1 -> T1.2 -> T2.1

## Tasks

### [ ] T1.1 - first   (Story S1)
- **Goal:** a
### [ ] T1.2 - second   (Story S1)
- **Goal:** b
### [ ] T2.1 - third   (Story S2)
- **Goal:** c
"@ | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    @"
# Stories

### Story S1: First story   (Epic E1)   <!-- Status: TODO -->
- **Goal:** one

# Story S2 - Second story
- **Goal:** two
"@ | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $cu = Join-Path $kit "close-unit.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "first" -ProjectDir $p -NoReindex | Out-Null
    Assert ($LASTEXITCODE -eq 0) "T1.1 close failed"
    Assert (Select-String "$p\docs\TASKS.md" -Pattern '^###\s*\[x\]\s*T1\.1' -Quiet) "T1.1 not ticked"
    Assert (-not (Select-String "$p\docs\STORIES.md" -Pattern 'Story S1.*Status: DONE' -Quiet)) "S1 rolled up too early"

    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.2 -Title "second" -ProjectDir $p -NoReindex | Out-Null
    Assert (Select-String "$p\docs\STORIES.md" -Pattern 'Story S1.*Status: DONE' -Quiet) "S1 did not roll up when all tasks done"

    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -ProjectDir $p -NoReindex | Out-Null
    Assert ($LASTEXITCODE -eq 0) "re-run not idempotent"

    # heading with no Status comment must get one appended
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T2.1 -Title "third" -ProjectDir $p -NoReindex | Out-Null
    Assert (Select-String "$p\docs\STORIES.md" -Pattern 'Story S2.*Status: DONE' -Quiet) "S2 status not appended"

    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $log = (git log --oneline | Out-String)
    $ErrorActionPreference = $prev; Pop-Location
    foreach ($id in @("T1.1","T1.2","T2.1")) { Assert ($log -match [regex]::Escape($id)) "no commit for $id" }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T9.9 -ProjectDir $p -NoReindex 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0) "bogus id did not fail"
  } finally { Remove-Sandbox $sb }
}

# ---------------------------------------------------------------- server
if (-not $SkipBuild) {
  Write-Host "-- server --" -ForegroundColor Cyan

  Test-Case "local-tools builds (Release)" {
    $out = dotnet build (Join-Path $kit "local-tools\local-tools.csproj") -c Release --nologo -v q 2>&1 | Out-String
    Assert ($out -match "Build succeeded") "build failed: $($out.Trim())"
  }

  Test-Case "MCP server advertises the expected tools" {
    $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
    Assert (Test-Path $exe) "exe not found"
    $expected = @("describe_image","detect_objects","index_datasheets","ingest_url","list_datasheets",
                  "search_datasheets","transcribe_audio","web_search")
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe; $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
      $proc.StandardInput.WriteLine('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}')
      $proc.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"notifications/initialized"}')
      $proc.StandardInput.WriteLine('{"jsonrpc":"2.0","id":2,"method":"tools/list"}')
      $proc.StandardInput.Flush()
      $tools = @()
      $deadline = [DateTime]::Now.AddSeconds(30)
      while ([DateTime]::Now -lt $deadline -and $tools.Count -eq 0) {
        $t = $proc.StandardOutput.ReadLineAsync()
        if (-not $t.Wait(8000)) { break }
        $line = $t.Result; if ($null -eq $line) { break }
        if ($line -match '"id":2') { $tools = @(($line | ConvertFrom-Json).result.tools | ForEach-Object { $_.name }) }
      }
      $diff = Compare-Object ($tools | Sort-Object) $expected
      Assert (-not $diff) "tools mismatch. got: $($tools -join ', ')"
    } finally { try { $proc.Kill() } catch {} }
  }

  Test-Case "CLI --reindex on an empty folder exits 0" {
    $sb = New-Sandbox
    try {
      & (Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe") --reindex $sb | Out-Null
      Assert ($LASTEXITCODE -eq 0) "exit $LASTEXITCODE"
    } finally { Remove-Sandbox $sb }
  }

  Test-Case "this suite's expected tool list matches Tools.cs" {
    # Catches "added a tool but forgot the test" drift in the other direction.
    $declared = ([regex]::Matches((Get-Content (Join-Path $kit "local-tools\Tools.cs") -Raw),
                 'McpServerTool\(Name\s*=\s*"([^"]+)"')).ForEach({ $_.Groups[1].Value }) | Sort-Object
    $expected = @("describe_image","detect_objects","index_datasheets","ingest_url","list_datasheets",
                  "search_datasheets","transcribe_audio","web_search") | Sort-Object
    $diff = Compare-Object $declared $expected
    Assert (-not $diff) "Tools.cs declares: $($declared -join ', ')"
  }

  Test-Case "kit CLAUDE.md points its validation gate at this suite" {
    $claude = Get-Content (Join-Path $kit "CLAUDE.md") -Raw
    Assert ($claude -match 'test-kit\.ps1') "CLAUDE.md's validation gate does not reference test-kit.ps1"
  }
}

# ---------------------------------------------------------------- summary
Write-Host ""
Write-Host "== $script:pass passed, $script:fail failed ==" -ForegroundColor $(if ($script:fail) { "Red" } else { "Green" })
if ($script:fail) {
  Write-Host ""
  foreach ($f in $script:failures) { Write-Host "  - $f" -ForegroundColor Red }
  exit 1
}
exit 0
