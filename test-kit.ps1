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
function New-Sandbox { $p = Join-Path $env:TEMP ("adkit_t_" + [guid]::NewGuid().ToString("N").Substring(0,8)); New-Item -ItemType Directory -Force $p | Out-Null; return $p }
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

Write-Host "== AD-kit test suite ==" -ForegroundColor Cyan

# ---------------------------------------------------------------- static hygiene
Write-Host "-- static --" -ForegroundColor Cyan

Test-Case "all .ps1 parse" {
  foreach ($f in Get-KitFiles @('*.ps1')) {
    $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs) | Out-Null
    Assert ($errs.Count -eq 0) "$($f.Name): $($errs[0].Message)"
  }
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
    $stamp = Join-Path $p ".ad-kit-version"
    Assert (Test-Path $stamp) ".ad-kit-version not written"
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
    Assert ($s -match 'AD-kit') "$rel lost the AD-kit placeholder"
    Assert ($s -notmatch 'claude-local') "$rel has this machine's path baked in"
  }
}

Test-Case "package-kit produces a clean, installable copy" {
  $sb = New-Sandbox
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "package-kit.ps1") -OutDir $sb -Folder | Out-Null
    Assert ($LASTEXITCODE -eq 0) "package-kit exited $LASTEXITCODE"
    $v = (Get-Content (Join-Path $kit "VERSION") -Raw).Trim()
    $out = Join-Path $sb "AD-kit-v$v"
    Assert (Test-Path $out) "package folder not created"
    foreach ($f in @("VERSION","install.cmd","models.json","test-kit.ps1","local-tools\Tools.cs")) {
      Assert (Test-Path (Join-Path $out $f)) "package missing $f"
    }
    foreach ($junk in @("local-tools\bin","local-tools\obj","_tempReference","docs\.index",".git")) {
      Assert (-not (Test-Path (Join-Path $out $junk))) "package should not contain $junk"
    }
    Assert ((Get-Content (Join-Path $out ".mcp.json") -Raw) -match 'AD-kit') "packaged .mcp.json lost the placeholder"
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
                        Where-Object { (Get-Content $_.FullName -Raw) -match 'AD-kit' }).Count -gt 0
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

Test-Case "each command has description frontmatter" {
  foreach ($f in Get-ChildItem (Join-Path $kit "global\commands") -Filter *.md) {
    $head = (Get-Content $f.FullName -TotalCount 5) -join "`n"
    Assert ($head -match '(?m)^description:\s*\S') "$($f.Name): missing 'description:'"
  }
}

# ---------------------------------------------------------------- models manifest
Write-Host "-- models --" -ForegroundColor Cyan
$mfPath = Join-Path $kit "models.json"

Test-Case "models.json is valid and complete" {
  Assert (Test-Path $mfPath) "models.json missing"
  $mf = Get-Content $mfPath -Raw | ConvertFrom-Json
  Assert ($mf.numCtx -ge 32768) "numCtx too small for the agent loop: $($mf.numCtx)"
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

Test-Case "ad-doctor runs and reports (exit code reflects failures only)" {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "ad-doctor.ps1") | Out-Null
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

Test-Case "scan-secrets ignores placeholders and honors AD-ALLOW-SECRET" {
  $sb = New-Sandbox
  try {
    Set-Content "$sb\a.md"   'password: <your-password-here>' -Encoding UTF8
    Set-Content "$sb\b.md"   'api_key = ${MY_API_KEY}' -Encoding UTF8
    Set-Content "$sb\c.yml"  'token: $env:SOME_TOKEN' -Encoding UTF8
    Set-Content "$sb\d.txt"  ("gh" + "p_" + ('b' * 36) + '   # AD-ALLOW-SECRET') -Encoding UTF8
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
    Assert ($j.mcpServers.'local-tools'.command -notmatch 'AD-kit') "exe path not rewritten to this kit"
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
      Assert ($log -match 'AD scaffold') "no initial commit"
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
