# test-kit.ps1 - the kit's own test suite. Runs WITHOUT Ollama, a GPU, or network (after restore), so it
# works in CI. This is the safety net for editing prompt files: it catches the bug classes that actually
# bit us - stale uninstall lists, agents referenced but not installed, commands that forget to name the
# Task tool, non-ASCII creeping in, scaffold/upgrade/close-unit regressions.
#
#   test-kit.ps1              full suite
#   test-kit.ps1 -SkipBuild   skip the dotnet build + MCP tests (fast doc/script-only pass)
#
# Exit code 0 = all passed, 1 = at least one failure.

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
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
    # 'examples' excludes examples\cms3: a dotnet-publish BUILD ARTIFACT from a separate project, containing
    # vendored third-party files (e.g. jquery-validation's own LICENSE.md, real non-ASCII license text) and
    # generated JSON (CMS.deps.json etc.) - not kit-authored text, same reasoning as bin/obj/_tempReference.
    ($parts -notcontains 'bin') -and ($parts -notcontains 'obj') -and ($parts -notcontains '__pycache__') -and
    ($parts -notcontains '_tempReference') -and ($parts -notcontains '.claude') -and ($parts -notcontains '.git') -and
    ($parts -notcontains 'examples')
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

Test-Case "no variable is READ that this file never assigns (the silent-nothing bug)" {
  # THREE bugs of this exact shape shipped in 0.19.0. doc-stats' new security check read $designFile, a
  # name that lives in ratchet.ps1; upgrade-project's read $docs, a name that lives in doc-stats. Neither
  # errored. PowerShell resolves an unknown variable to $null, so `Test-Path $nothing` is false and the
  # whole check quietly passes forever - the worst possible failure for a gate, because it reports success.
  # A gate that cannot fail is indistinguishable from no gate, which is the premise of this entire kit.
  function Get-UnassignedReads([string]$File) {
    $auto = @('_','psitem','args','input','matches','error','host','pwd','home','pid','profile','shellid',
      'psscriptroot','pscommandpath','psboundparameters','psversiontable','psculture','psuiculture',
      'myinvocation','executioncontext','stacktrace','lastexitcode','nestedpromptlevel','outputencoding',
      'foreach','switch','this','true','false','null','iswindows','islinux','ismacos','iscoreclr',
      'erroractionpreference','warningpreference','verbosepreference','debugpreference','confirmpreference',
      'progresspreference','informationpreference','whatifpreference','enabledexperimentalfeatures',
      'psedition','pshome','consolefilename','sender','eventargs','event','eventsubscriber')
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($File, [ref]$tk, [ref]$er)
    if ($er) { return @() }                      # "all .ps1 parse" owns syntax errors, not this test
    # tAssign, not $A: PowerShell variable names are CASE-INSENSITIVE, so a type holder named $V and a
    # loop variable named $v are ONE variable. The first version of this test did exactly that and died
    # with "cannot convert VariableExpressionAst to type System.Type" - the loop had overwritten the type.
    $tAssign  = [System.Management.Automation.Language.AssignmentStatementAst]
    $tParam   = [System.Management.Automation.Language.ParameterAst]
    $tForEach = [System.Management.Automation.Language.ForEachStatementAst]
    $tUnary   = [System.Management.Automation.Language.UnaryExpressionAst]
    $tVar     = [System.Management.Automation.Language.VariableExpressionAst]
    $tCmd     = [System.Management.Automation.Language.CommandAst]
    $tStr     = [System.Management.Automation.Language.StringConstantExpressionAst]
    $assigned = New-Object 'System.Collections.Generic.HashSet[string]'
    $add = { param($n) $assigned.Add($n.Split(':')[-1].ToLower()) | Out-Null }
    foreach ($a in $ast.FindAll({ $args[0] -is $tAssign }, $true)) {
      foreach ($v in $a.Left.FindAll({ $args[0] -is $tVar }, $true)) { & $add $v.VariablePath.UserPath }
    }
    foreach ($p in $ast.FindAll({ $args[0] -is $tParam }, $true)) { & $add $p.Name.VariablePath.UserPath }
    foreach ($e in $ast.FindAll({ $args[0] -is $tForEach }, $true)) { & $add $e.Variable.VariablePath.UserPath }
    # $x++ both reads and writes; if that is the only mention it is a bug on its own terms, not this one
    foreach ($u in $ast.FindAll({ $args[0] -is $tUnary }, $true)) {
      foreach ($v in $u.FindAll({ $args[0] -is $tVar }, $true)) { & $add $v.VariablePath.UserPath }
    }
    foreach ($c in $ast.FindAll({ $args[0] -is $tCmd }, $true)) {
      if ($c.GetCommandName() -in @('New-Variable','Set-Variable','Remove-Variable','Get-Variable')) {
        foreach ($el in $c.CommandElements) { if ($el -is $tStr) { & $add $el.Value } }
      }
    }
    $out = @()
    foreach ($v in $ast.FindAll({ $args[0] -is $tVar }, $true)) {
      if ($v.VariablePath.IsDriveQualified) { continue }        # $env:FOO
      $n = $v.VariablePath.UserPath.Split(':')[-1]
      if ($n.ToLower() -in $auto) { continue }
      if ($assigned.Contains($n.ToLower())) { continue }
      $out += "$([System.IO.Path]::GetFileName($File)):$($v.Extent.StartLineNumber) `$$n"
    }
    return $out
  }

  # SELF-CHECK FIRST. A static analyser that finds nothing on clean code proves nothing about itself, and
  # this suite exists because gates that pass by doing nothing are the recurring failure here.
  $sb = New-Sandbox
  try {
    $probe = Join-Path $sb "probe.ps1"
    @'
param([string]$ProjectDir = ".")
$designName = "DESIGN.md"
$hit = [regex]::Match((Get-Content $designFile -Raw), 'x')
foreach ($x in 1..3) { $x }
$i = 0; $i++
Get-ChildItem $ProjectDir | ForEach-Object { $_.Name }
'@ | Set-Content $probe -Encoding UTF8
    $probeHits = @(Get-UnassignedReads $probe)
    Assert ($probeHits.Count -eq 1) "the analyser is broken: expected exactly 1 hit on the probe, got $($probeHits.Count) ($($probeHits -join '; '))"
    Assert ($probeHits[0] -match '\$designFile') "the analyser missed the real bug shape: $($probeHits -join '; ')"
  } finally { Remove-Sandbox $sb }

  $bad = @()
  foreach ($f in (Get-KitFiles @("*.ps1"))) { $bad += @(Get-UnassignedReads $f.FullName) }
  Assert ($bad.Count -eq 0) "read but never assigned in the same file (silently evaluates to `$null): $($bad -join ', ')"
}

Test-Case "a MISTYPED parameter is an error, not a silent default" {
  # A .ps1 with a plain param() block is not an ADVANCED function, so PowerShell puts unmatched arguments
  # into $args and carries on with the DEFAULTS. `new-project.ps1 -Kind general -Path C:\tmp\x` therefore
  # ignored -Path entirely and scaffolded into the CURRENT directory: CLAUDE.md, .mcp.json, docs\ and a
  # `git init` landed one level above an existing checkout. These scripts are invoked by MODELS, which
  # typo parameter names constantly, and every one of them takes a -ProjectDir that defaults to ".".
  $missing = @()
  foreach ($f in (Get-KitFiles @("*.ps1"))) {
    $t = Get-Content $f.FullName -Raw
    if ($t -notmatch '(?m)^\s*param\s*\(') { continue }
    # [Parameter(...)] on any parameter also makes a script advanced, which is equally sufficient
    if ($t -match '(?m)^\s*\[CmdletBinding' -or $t -match '\[Parameter\(') { continue }
    $missing += $f.Name
  }
  Assert ($missing.Count -eq 0) "these accept a bad parameter silently and run against their defaults: $($missing -join ', ')"

  # And prove it BEHAVES that way, rather than trusting that the attribute is present and effective.
  $np = Join-Path $kit "new-project.ps1"
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $np -Kind general -Path "C:\this-must-not-be-used" 2>&1 | Out-String
  # \s+ not literal spaces: captured native-command output is HARD-WRAPPED at the console width, so any
  # asserted phrase can arrive with a newline inside it. This assertion failed on 'matches\nparameter'.
  Assert ($out -match '(?s)cannot\s+be\s+found\s+that\s+matches\s+parameter\s+name') "a bogus -Path was accepted instead of rejected"
  Assert ($out -notmatch 'Scaffolding') "it started scaffolding despite a parameter it did not understand"
}

Test-Case "scaffold never leaves a repo with NO commits" {
  # git accepts `init` in a folder that contains other repositories, warns about an embedded repo, and
  # then fails the commit - leaving a .git with no HEAD. That is strictly worse than no repo: the ratchet
  # has no baseline, recover-lost has nothing to diff against, and dad-guard sees every file as untracked
  # forever. Observed for real when a scaffold landed one level above an existing checkout.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "outer"; New-Item -ItemType Directory -Force $p | Out-Null
    $inner = Join-Path $p "inner-repo"; New-Item -ItemType Directory -Force $inner | Out-Null
    Push-Location $inner
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    "x" | Set-Content "$inner\f.txt" -Encoding UTF8
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "new-project.ps1") general $p 2>&1 | Out-String
    Assert ($out -match 'git: SKIPPED') "it tried to init a repo around an existing one: $out"
    Assert (-not (Test-Path (Join-Path $p ".git"))) "a .git was left behind wrapping an embedded repository"
    Assert ($out -match 'OWN empty folder|own empty folder') "the message does not say what to do instead"
    # the scaffold itself must still have happened - no git is a degraded mode, not a failure
    Assert (Test-Path (Join-Path $p "CLAUDE.md")) "the scaffold aborted; skipping git should only cost checkpoints"
    Assert (Test-Path (Join-Path $p "docs\DESIGN.md")) "the design doc was not created"
    # and the pre-existing repo must be untouched
    Push-Location $inner; $stillThere = (git rev-parse --verify HEAD 2>$null); Pop-Location
    Assert ([bool]$stillThere) "the embedded repository lost its history"
  } finally { Remove-Sandbox $sb }
}

Test-Case "every kit file the docs tell you to RUN actually exists" {
  # /research's last step said `-File "...\DAD-kit\reindex.ps1" docs`. There is no reindex.ps1 - only
  # reindex.cmd, which takes an absolute path. So the final step of the kit's ONLY online mode failed with
  # "no such file", and the model, having just been told the gate passed, reported the corpus was
  # searchable. Every later offline command then queried an index missing the sources just captured.
  # The existing "every executable a command tells the model to run is permitted" test checks that
  # `powershell` is allow-listed - it never checked that the -File TARGET resolves. This does.
  $missing = @()
  $checked = 0
  $docs = @(Get-KitFiles @("*.md")) + @(Get-ChildItem (Join-Path $kit "global") -Recurse -Filter *.md -File)
  foreach ($f in ($docs | Sort-Object FullName -Unique)) {
    # CHANGELOG is HISTORY: it must be free to name the broken thing it is recording the fix for.
    if ($f.Name -eq "CHANGELOG.md") { continue }
    $text = Get-Content $f.FullName -Raw
    # TASKS.md legitimately NAMES a not-yet-built deliverable, inside an UNCHECKED task's own "Do:" text
    # AND in the Build-order section's prose describing that same task - it is describing what the task
    # will create, not telling the model to run it now (taskmap shards a story's whole task set up front,
    # per R32/S8-S10; the file a task creates does not exist until that task is actually built). Collect
    # every filename named inside an UNCHECKED "### [ ]" task body and treat it as forward-declared
    # ANYWHERE in this one file (Build-order commentary included), so planned-but-not-yet-built work does
    # not trip a check meant to catch STALE prose about files that no longer, or never, existed. A CHECKED
    # "[x]" task's files (and every other doc) are still required to exist, unchanged.
    $pendingNames = $null
    if ($f.Name -eq "TASKS.md") {
      $pendingNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
      foreach ($body in [regex]::Matches($text, '(?ms)^### \[ \].*?(?=^### |\z)')) {
        foreach ($pm in [regex]::Matches($body.Value, '(?i)([A-Za-z0-9_.-]+\.(?:ps1|cmd))')) {
          [void]$pendingNames.Add($pm.Groups[1].Value)
        }
      }
    }
    # any reference to a kit script, however it is written: via the dev-path placeholder, or bare
    foreach ($m in [regex]::Matches($text, '(?i)(?:DAD-kit[\\/])?([A-Za-z0-9_.-]+\.(?:ps1|cmd))')) {
      $name = $m.Groups[1].Value
      # only judge names that LOOK like kit scripts: the kit is flat, so a real one sits at its root
      if ($name -match '(?i)^(setup|build|run|deploy|foo|bar|example|script|my)') { continue }
      $isKitish = ($name -match '(?i)^(dad-|close-|doc-|docs-|api-|new-|upgrade-|use-|sync-|install|uninstall|package-|scan-|test-|reindex|recover-|ratchet|source-|grade-|ollama-|corpus\.|env\.)')
      if (-not $isKitish) { continue }
      if ($pendingNames -and $pendingNames.Contains($name)) { continue }
      $checked++
      if (-not (Test-Path (Join-Path $kit $name))) {
        $line = ($text.Substring(0, $m.Index) -split "`n").Count
        $missing += "$($f.Name):$line -> $name"
      }
    }
  }
  Assert ($checked -gt 20) "this test found only $checked kit-script references - the pattern stopped matching, so it is proving nothing"
  Assert ($missing.Count -eq 0) "the docs tell the model to run files that do not exist: $(($missing | Sort-Object -Unique) -join '; ')"
}

Test-Case "prose never names a model alias or roster count that is not real" {
  # Two drift classes that a reader cannot detect and a model will obey.
  # (1) The planner alias was renamed plan -> oss, and README kept telling you `use-model.cmd plan`, which
  #     simply fails. models.json is the single source of truth for aliases; prose must agree with it.
  # (2) "the 11 commands / 10 agents" survived in README while the kit shipped 15 and 14. A count in prose
  #     is a fact a script can settle, so it must be settled by one.
  $aliases = @((Get-Content (Join-Path $kit "models.json") -Raw | ConvertFrom-Json).models | ForEach-Object { $_.alias })
  Assert ($aliases.Count -ge 4) "could not read the alias list from models.json"
  $badAlias = @()
  foreach ($f in (Get-KitFiles @("*.md"))) {
    if ($f.Name -eq "CHANGELOG.md") { continue }   # history: 'plan' WAS an alias before 0.10.0
    $text = Get-Content $f.FullName -Raw
    foreach ($m in [regex]::Matches($text, '(?i)use-model(?:\.cmd|\.ps1)?\s+([a-z0-9|<> \-]+)')) {
      foreach ($tok in ($m.Groups[1].Value -split '\|')) {
        $tok = $tok.Trim()
        if (-not $tok -or $tok -match '^<' -or $tok -match '\s') { continue }   # <any model>, prose tails
        if ($aliases -notcontains $tok) { $badAlias += "$($f.Name): '$tok'" }
      }
    }
  }
  Assert ($badAlias.Count -eq 0) "prose names model aliases that models.json does not define: $(($badAlias | Sort-Object -Unique) -join '; ')"

  $realCommands = @(Get-ChildItem (Join-Path $kit "global\commands") -Filter *.md -File).Count
  $realAgents   = @(Get-ChildItem (Join-Path $kit "global\agents")   -Filter *.md -File).Count
  $badCount = @()
  foreach ($f in (Get-KitFiles @("*.md"))) {
    if ($f.Name -eq "CHANGELOG.md") { continue }        # history: correct when written, not now
    foreach ($m in [regex]::Matches((Get-Content $f.FullName -Raw), '(?i)\b(\d{1,2})\s+(commands|agents)\b')) {
      $n = [int]$m.Groups[1].Value
      $what = $m.Groups[2].Value.ToLower()
      $expected = if ($what -eq 'commands') { $realCommands } else { $realAgents }
      if ($n -ne $expected) { $badCount += "$($f.Name): says $n $what, ships $expected" }
    }
  }
  Assert ($badCount.Count -eq 0) "roster counts in prose have drifted from what ships: $(($badCount | Sort-Object -Unique) -join '; ')"
}

Test-Case "ONE shell-neutral entry point: dad <subcommand>, from any shell" {
  # The kit is Windows-native but the model is not reliably in any one shell, and every dialect it guesses
  # wrong is a silent failure: `2>nul` under bash writes stderr to a FILE and returns nothing (920-call
  # loop), `&&` is a parser error in PS 5.1, and a POSIX path handed to a Windows script may or may not
  # convert. `dad` is a .cmd, so it behaves identically from Git Bash, cmd and PowerShell, and Git Bash
  # converts POSIX paths on the way in. The model never picks a dialect for a kit operation.
  $dad = Join-Path $kit "dad.cmd"
  Assert (Test-Path $dad) "dad.cmd is missing - the single entry point"

  # It must resolve subcommands, alias the dad- prefix, and pass exit codes through UNCHANGED. Exit codes
  # are the whole contract: /build decides whether a unit closed by reading them.
  & cmd /c "`"$dad`" doc-stats -ProjectDir `"$kit`" >nul 2>&1"
  Assert ($LASTEXITCODE -eq 0) "dad doc-stats failed (exit $LASTEXITCODE)"
  & cmd /c "`"$dad`" doctor >nul 2>&1"
  Assert ($LASTEXITCODE -ne 127) "the dad- prefix alias does not resolve ('dad doctor' -> dad-doctor.cmd)"
  & cmd /c "`"$dad`" no-such-subcommand >nul 2>&1"
  Assert ($LASTEXITCODE -ne 0) "an unknown subcommand exited 0"
  & cmd /c "`"$dad`" >nul 2>&1"
  Assert ($LASTEXITCODE -ne 0) "bare 'dad' exited 0 - usage is not success"
  # a failing subcommand's code must reach the caller, not be swallowed by the dispatcher
  & cmd /c "`"$dad`" doc-stats -ProjectDir `"$kit\_no_such_dir_zz`" >nul 2>&1"
  Assert ($LASTEXITCODE -eq 2) "the subcommand's exit code was not passed through (got $LASTEXITCODE, want 2)"

  # Every subcommand the usage text advertises must actually exist, or the help lies.
  $usage = (& cmd /c "`"$dad`" 2>&1" | Out-String)
  foreach ($m in [regex]::Matches($usage, '(?m)^\s{4,}dad ([a-z][a-z0-9-]+)')) {
    $sub = $m.Groups[1].Value
    $ok = (Test-Path (Join-Path $kit "$sub.cmd")) -or (Test-Path (Join-Path $kit "dad-$sub.cmd"))
    Assert $ok "dad's usage advertises '$sub', which has no wrapper"
  }

  # The allow list needs exactly ONE entry for all of this. Without it every call prompts, and a prompt
  # per call is what makes agents stall and start improvising their own reporting files.
  $allow = @((Get-Content (Join-Path $kit "settings.json") -Raw | ConvertFrom-Json).permissions.allow)
  Assert ($allow -contains "Bash(dad:*)") "settings.json does not permit Bash(dad:*) - every kit call would prompt"

  # And the commands must USE it: no command or agent should still spell out a powershell invocation.
  $longForm = @(Select-String -Path (Join-Path $kit "global\commands\*.md"),(Join-Path $kit "global\agents\*.md") `
                  -Pattern 'powershell\s+-ExecutionPolicy\s+Bypass\s+-File')
  Assert ($longForm.Count -eq 0) "these still tell the model to type a raw powershell invocation: $(($longForm | ForEach-Object { [System.IO.Path]::GetFileName($_.Path) } | Sort-Object -Unique) -join ', ')"
  $usesDad = @(Select-String -Path (Join-Path $kit "global\commands\*.md") -Pattern '(?m)^\s*dad\s+[a-z]')
  Assert ($usesDad.Count -ge 10) "only $($usesDad.Count) commands invoke 'dad' - the migration did not land"
}

Test-Case "the kit reaches EVERY shell: dad shim + DAD_HOME + PATH, install/uninstall symmetric" {
  # cmd/PowerShell find dad.cmd via PATHEXT; bash does NOT append .cmd to a bare name, so `dad doctor` in
  # Git Bash was "command not found" on a real run even with the kit on PATH. The fix is an extensionless
  # `dad` bash shim, a DAD_HOME variable every Windows-launched shell inherits, and the kit on PATH.
  $shim = Join-Path $kit "dad"
  Assert (Test-Path $shim) "the extensionless dad bash shim is missing - Git Bash cannot resolve bare dad"
  $bytes = [System.IO.File]::ReadAllBytes($shim)
  Assert ($bytes -notcontains 13) "the dad shim has CR bytes - a CRLF shebang breaks bash"
  $shimText = [System.Text.Encoding]::ASCII.GetString($bytes)
  Assert ($shimText.StartsWith("#!/usr/bin/env bash")) "the dad shim has no bash shebang"
  Assert ($shimText -match 'powershell -NoProfile -ExecutionPolicy Bypass -File') "the shim does not dispatch .ps1 subcommands"
  Assert ($shimText -match '\$sub\.cmd') "the shim has no .cmd fallback for cmd-only subcommands"

  $inst = Get-Content (Join-Path $kit "install.ps1") -Raw
  Assert ($inst -match 'SetEnvironmentVariable\("DAD_HOME"') "install does not set DAD_HOME"
  Assert ($inst.Contains('# >>> DAD-kit >>>')) "install does not write a managed ~/.bashrc block"
  Assert ($inst.Contains('.ToLower()')) "install does not convert the kit path to bash form for .bashrc"

  $unin = Get-Content (Join-Path $kit "uninstall.ps1") -Raw
  Assert ($unin.Contains('DAD_HOME')) "uninstall does not remove DAD_HOME"
  Assert ($unin.Contains('# >>> DAD-kit >>>')) "uninstall does not strip the ~/.bashrc block"
  Assert ($unin.Contains('USER PATH')) "uninstall does not remove the kit from PATH"

  # IDEMPOTENCY, checked deterministically: the exact strip+append install uses must not stack blocks when
  # run twice. Replicate it on a fixture. (Single-quoted markers so PowerShell does not read >>> as a
  # redirection.)
  $bMark = '# >>> DAD-kit >>>'; $eMark = '# <<< DAD-kit <<<'
  $blk = $bMark + "`n" + 'export DAD_HOME="/d/x"' + "`n" + $eMark + "`n"
  $rx = "(?s)\r?\n?" + [regex]::Escape($bMark) + ".*?" + [regex]::Escape($eMark) + "\r?\n?"
  function Apply($existing) {
    $s = [regex]::Replace($existing, $rx, "`n").TrimEnd("`r","`n")
    if ($s) { return $s + "`n`n" + $blk } else { return $blk }
  }
  $once = Apply 'export FOO=1'
  $twice = Apply $once
  $blockCount = ([regex]::Matches($twice, [regex]::Escape($bMark))).Count
  Assert ($blockCount -eq 1) "re-install stacked a second DAD-kit block in ~/.bashrc (found $blockCount)"
  Assert ($twice.Contains('export FOO=1')) "the .bashrc rewrite dropped the user's own lines"
  $removed = [regex]::Replace($twice, $rx, "`n")
  Assert (-not $removed.Contains('DAD-kit')) "uninstall's strip left the block behind"
  Assert ($removed.Contains('export FOO=1')) "uninstall's strip removed the user's own lines"
}

Test-Case "line endings are consistent per file (LF, CRLF for batch)" {
  # 27 of the kit's text files held BOTH CRLF and LF. Every one was a file edited by writing CRLF strings
  # into an LF file - all inside a single shell, so this was never a shell-mixing problem. What it broke:
  #   - .NET multiline regex anchors `^...$` match before \n and NOT before \r\n, so a pattern that works
  #     on one half of a mixed file silently fails on the other half.
  #   - a literal replace built with "`r`n" matches nothing in an LF region, so the edit no-ops. That is
  #     how the README's H1 got mangled and how 7 of the design doc's 31 requirements got glued onto the
  #     end of previous lines, where the ratchet could not count them.
  # .gitattributes states the rule; this asserts the working tree obeys it.
  $mixed = @(); $wrongEol = @()
  # .claude\ excluded: it is gitignored runtime state (e.g. .dad-ratchet.json), not source - this kit
  # dogfoods itself as a project, so close-unit/ratchet write there against the kit's own repo root.
  # Scanning it made this a "does a runtime artifact happen to be LF" check, not a source-hygiene one.
  $files = Get-ChildItem $kit -Recurse -File -Include *.ps1,*.cmd,*.md,*.json,*.cs |
           Where-Object { $_.FullName -notmatch '\\(_tempReference|bin|obj|\.git|\.claude|node_modules|examples)\\' }
  foreach ($f in $files) {
    $t = [System.IO.File]::ReadAllText($f.FullName)
    $crlf = ([regex]::Matches($t, "`r`n")).Count
    $lf   = ([regex]::Matches($t, "(?<!`r)`n")).Count
    if ($crlf -gt 0 -and $lf -gt 0) { $mixed += "$($f.Name) (crlf=$crlf lf=$lf)"; continue }
    # batch files keep CRLF: cmd.exe has historically misparsed LF-only labels and goto
    if ($f.Extension -in @(".cmd",".bat")) {
      if ($lf -gt 0) { $wrongEol += "$($f.Name) is LF but batch must be CRLF" }
    } elseif ($crlf -gt 0) {
      $wrongEol += "$($f.Name) is CRLF but should be LF"
    }
  }
  Assert ($files.Count -gt 50) "only $($files.Count) files scanned - the filter broke, so this proves nothing"
  Assert ($mixed.Count -eq 0) "files with MIXED line endings (a regex or a replace WILL silently half-fail): $(($mixed | Sort-Object) -join '; ')"
  Assert ($wrongEol.Count -eq 0) "files whose line endings do not match .gitattributes: $(($wrongEol | Sort-Object) -join '; ')"
  Assert (Test-Path (Join-Path $kit ".gitattributes")) "no .gitattributes - nothing normalizes this on commit, so it will drift back"
}

Test-Case "a script given a project dir that does not exist FAILS, loudly" {
  # Found while testing the shells: `doc-stats.cmd -ProjectDir C:\definitely\not\here` printed a
  # Resolve-Path error and exited **0**. A model that mistypes a path therefore gets success plus a stderr
  # blob it may not read, and carries on believing the project has no stories and no tasks. Same
  # silent-nothing shape as every other bug in this kit: the check ran, found nothing, and reported fine.
  $bogus = Join-Path $kit "_no_such_project_dir_xyz"
  foreach ($s in @("doc-stats.ps1","ratchet.ps1","source-stats.ps1")) {
    $p = Join-Path $kit $s
    if (-not (Test-Path $p)) { continue }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $p -ProjectDir $bogus 2>&1 | Out-Null
    Assert ($LASTEXITCODE -ne 0) "$s exited 0 for a project directory that does not exist"
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
  # Windows' app-execution-alias stub (WindowsApps\python.exe, installed by default on Windows 11) makes
  # Get-Command find "a python" even with no real interpreter present - it prints a Store-install prompt
  # and exits nonzero, which then read as "voice.py failed to compile" instead of "no python here".
  python --version *> $null
  if ($LASTEXITCODE -ne 0) { return }   # the Store stub, not a real interpreter - treat as "optional on CI"
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

Test-Case "the signature bank names the .cs file each type lives in, and lookup surfaces it" {
  # Reflection over the DLLs gives signatures but NOT source paths - the exact fact a model kept re-guessing
  # (file name vs class name, editing the wrong file and walking it back). api-surface -AnnotateFiles greps
  # the source and stamps each solution type heading with its .cs file; -Lookup (what close-unit runs on a
  # build error) then hands over the FILE + the signature, so no search is needed.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"
    New-Item -ItemType Directory -Force (Join-Path $p "docs") | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $p "src\Controllers") | Out-Null
    Set-Content (Join-Path $p "src\Controllers\AccountController.cs") -Encoding UTF8 @(
      'namespace X;', 'public class AccountController { public void Login() {} }')
    Set-Content (Join-Path $p "src\Widget.cs") -Encoding UTF8 @(
      'namespace X;', 'public interface IWidget { }')
    # an UNannotated bank, as the C# reflector writes it (backtick-fenced type headings + member lines)
    Set-Content (Join-Path $p "docs\API-SURFACE.md") -Encoding UTF8 @(
      '# API surface', '', '## This solution', '', '### X', '',
      '`class AccountController`', '  - `void Login()`', '',
      '`interface IWidget`')

    $api = Join-Path $kit "api-surface.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $api -AnnotateFiles -ProjectDir $p -Quiet | Out-Null
    $bankFile = Join-Path $p "docs\API-SURFACE.md"
    $bank = Get-Content $bankFile -Raw
    Assert ($bank -match 'class AccountController.*AccountController\.cs') "the class heading was not stamped with its source file"
    Assert ($bank -match 'interface IWidget.*Widget\.cs') "the interface heading was not stamped with its source file"

    # LF, not CRLF: docs\*.md is `* text=auto eol=lf` (.gitattributes). Add-SourceFiles used to hardcode
    # `r`n, silently re-CRLFing API-SURFACE.md on every close-unit-triggered regeneration - the same bug
    # class close-unit.ps1's Save-Text had (commit 9be3aec). Assert on raw bytes, not git's view.
    $rawBank = [System.IO.File]::ReadAllText($bankFile)
    Assert ((([regex]::Matches($rawBank, "`r`n")).Count) -eq 0) "API-SURFACE.md has CRLF line endings after Add-SourceFiles wrote it - regressed"
    Assert ((([regex]::Matches($rawBank, "(?<!`r)`n")).Count) -gt 0) "API-SURFACE.md has no line endings at all after Add-SourceFiles wrote it"

    # -Lookup surfaces the file too (this is what close-unit's Show-Signatures prints on a build error)
    $look = & powershell -NoProfile -ExecutionPolicy Bypass -File $api -Lookup AccountController -ProjectDir $p 2>&1 | Out-String
    Assert ($look -match 'AccountController\.cs') "api-surface -Lookup does not surface the type's source file"

    # idempotent: a second annotate must not append the file twice
    & powershell -NoProfile -ExecutionPolicy Bypass -File $api -AnnotateFiles -ProjectDir $p -Quiet | Out-Null
    $bank2 = Get-Content (Join-Path $p "docs\API-SURFACE.md") -Raw
    Assert ((@([regex]::Matches($bank2, 'AccountController\.cs')).Count) -eq 1) "annotation is not idempotent - the file was stamped twice"
  } finally { Remove-Sandbox $sb }
}

Test-Case "api-surface resolves a type deriving from an ASP.NET framework base (ApplicationUser : IdentityUser)" {
  # The measured bug: the reflector resolved types against bin + the .NET runtime but NOT the ASP.NET Core
  # shared framework, so a type whose BASE lives there (ApplicationUser : IdentityUser) could not resolve and
  # was SILENTLY dropped - dev-agent -Lookup'd it, got nothing, and re-invented it. This builds a tiny
  # FrameworkReference lib with such a type and asserts it now appears. Skips (does not fail) when the SDK or
  # the ASP.NET Core shared framework is unavailable.
  $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
  if (-not (Test-Path $exe)) { return }
  if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "app"; New-Item -ItemType Directory -Force $p | Out-Null
    Set-Content (Join-Path $p "app.csproj") -Encoding UTF8 @(
      '<Project Sdk="Microsoft.NET.Sdk">',
      '  <PropertyGroup><TargetFramework>net8.0</TargetFramework><Nullable>enable</Nullable></PropertyGroup>',
      '  <ItemGroup><FrameworkReference Include="Microsoft.AspNetCore.App" /></ItemGroup>',
      '</Project>')
    Set-Content (Join-Path $p "User.cs") -Encoding UTF8 @(
      'using Microsoft.AspNetCore.Identity;',
      'namespace App;',
      'public class ApplicationUser : IdentityUser { public string? FullName { get; set; } }')
    & dotnet build $p -c Release --nologo -v q *> $null
    if ($LASTEXITCODE -ne 0) { return }   # no ASP.NET Core shared framework here -> skip, do not fail
    & $exe --api-surface $p *> $null
    $surfaceFile = Join-Path $p "docs\API-SURFACE.md"
    Assert (Test-Path $surfaceFile) "api-surface wrote no surface for the ASP.NET fixture"
    Assert ((Get-Content $surfaceFile -Raw) -match 'class ApplicationUser') "api-surface dropped ApplicationUser : IdentityUser - the ASP.NET Core shared framework is not in the reflector's resolver paths"
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
    # A stack dir must NOT carry a design-doc template: DESIGN.md/TEDD.md live ONLY in _common, or a copy
    # goes stale. Unity shipped a divergent docs/TEDD.md (old shape: stories inline, no contracts/security)
    # while the scaffold used the _common one - reconciled in 0.31.0 by deleting it and asserting it here.
    foreach ($dd in @("docs\DESIGN.md","docs\TEDD.md")) {
      Assert (-not (Test-Path (Join-Path $p.FullName $dd))) `
        "$($p.Name) ships $dd - the design doc template lives ONLY in _common (a stack copy drifts)"
    }
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
    $out = Join-Path $sb "DrDad-v$v"
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

Test-Case "state-mutating scripts confine real-machine writes behind a param guard" {
  # R35's motivating bug: uninstall.ps1's PATH/DAD_HOME/~/.bashrc cleanup ran UNCONDITIONALLY, so a
  # "sandboxed" test run (uninstall.ps1 -ClaudeDir <sandbox>) silently mutated the REAL machine anyway.
  # This is a static, mechanical gate for that class of bug: find real-machine mutation call SHAPES, then
  # require each one sit inside an `if ($SomeScriptParam) { ... } [else { ... }]` guard - not pinned to
  # today's exact wording or line numbers (that broke last time - R28/R29), so a differently-worded future
  # script still gets caught. Extendable: add more install/uninstall/teardown scripts to the list below.
  $stateMutatingScripts = @("uninstall.ps1")

  $dangerPatterns = @(
    '\[Environment\]::(Set|Remove)EnvironmentVariable\([^)]*,\s*"(User|Machine)"\s*\)',
    '\bollama\s+rm\b',
    'Remove-Item[^\r\n]*\$(?:env:)?(USERPROFILE|HOME)\b',
    '(Set|Remove|New)-ItemProperty\b[^\r\n]*(HKCU:|HKLM:)'
  )

  # A script's own declared parameters are the only things that count as a "guard" - being inside an
  # if-block on ANY condition is not the shape to detect (that would accept any stray if-wrapper).
  function Get-ScriptParamNames([string]$src) {
    $m = [regex]::Match($src, '(?ms)^\s*param\s*\(')
    if (-not $m.Success) { return @() }
    $start = $m.Index + $m.Length - 1
    $depth = 0; $end = -1
    for ($i = $start; $i -lt $src.Length; $i++) {
      if ($src[$i] -eq '(') { $depth++ }
      elseif ($src[$i] -eq ')') { $depth--; if ($depth -eq 0) { $end = $i; break } }
    }
    if ($end -lt 0) { return @() }
    $block = $src.Substring($start, $end - $start)
    return [regex]::Matches($block, '\$(\w+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
  }

  # Character ranges covered by `if ($param) { ... }` and, if present, its immediately-following
  # `else { ... }` - the exact shape uninstall.ps1 uses today (skip message in the if, real mutation in
  # the else), found via brace-depth counting so it is not line-number-fragile.
  function Get-GuardedRegions([string]$src, [string[]]$paramNames) {
    $regions = New-Object System.Collections.Generic.List[object]
    foreach ($pn in $paramNames) {
      foreach ($m in [regex]::Matches($src, "if\s*\(\s*\`$$pn\s*\)\s*\{")) {
        $braceStart = $m.Index + $m.Length - 1
        $depth = 0; $end = -1
        for ($i = $braceStart; $i -lt $src.Length; $i++) {
          if ($src[$i] -eq '{') { $depth++ }
          elseif ($src[$i] -eq '}') { $depth--; if ($depth -eq 0) { $end = $i; break } }
        }
        if ($end -lt 0) { continue }
        $regionEnd = $end
        $rest = $src.Substring($end + 1)
        $elseMatch = [regex]::Match($rest, '^\s*else\s*\{')
        if ($elseMatch.Success) {
          $elseBraceStart = $end + 1 + $elseMatch.Index + $elseMatch.Length - 1
          $depth2 = 0
          for ($j = $elseBraceStart; $j -lt $src.Length; $j++) {
            if ($src[$j] -eq '{') { $depth2++ }
            elseif ($src[$j] -eq '}') { $depth2--; if ($depth2 -eq 0) { $regionEnd = $j; break } }
          }
        }
        $regions.Add([PSCustomObject]@{ Start = $m.Index; End = $regionEnd })
      }
    }
    return $regions
  }

  function Find-UnguardedMutations([string]$src, [string]$label) {
    $regions = Get-GuardedRegions $src (Get-ScriptParamNames $src)
    $unguarded = @()
    foreach ($pat in $dangerPatterns) {
      foreach ($mm in [regex]::Matches($src, $pat)) {
        $idx = $mm.Index
        if (-not ($regions | Where-Object { $idx -ge $_.Start -and $idx -le $_.End })) {
          $unguarded += "$label : '$($mm.Value)' (offset $idx) is not inside an if(<param>){...}[else{...}] guard"
        }
      }
    }
    return $unguarded
  }

  $violations = @()
  foreach ($s in $stateMutatingScripts) {
    $p = Join-Path $kit $s
    Assert (Test-Path $p) "$s not found at kit root"
    $violations += Find-UnguardedMutations (Get-Content $p -Raw) $s
  }
  Assert (-not $violations) ("real-machine mutation not confined behind a param guard:`n" + ($violations -join "`n"))
}

Test-Case "the param-guard detector actually has teeth: an unguarded mutation IS flagged" {
  # The previous Test-Case only proves uninstall.ps1 passes TODAY - a positive result. That alone does not
  # prove the detector would catch a regression: it could pass vacuously (e.g. a typo'd regex that never
  # matches anything). This proves the negative case on a throwaway scratch script - never the real
  # uninstall.ps1 - that reconstructs its real shape (same param name, same danger call) but with the
  # `if ($ClaudeDir) {...} else {...}` guard removed, so the mutation is unconditional. The detector must
  # report at least one violation, or it has no teeth.
  $dangerPatterns = @(
    '\[Environment\]::(Set|Remove)EnvironmentVariable\([^)]*,\s*"(User|Machine)"\s*\)',
    '\bollama\s+rm\b',
    'Remove-Item[^\r\n]*\$(?:env:)?(USERPROFILE|HOME)\b',
    '(Set|Remove|New)-ItemProperty\b[^\r\n]*(HKCU:|HKLM:)'
  )

  function Get-ScriptParamNames([string]$src) {
    $m = [regex]::Match($src, '(?ms)^\s*param\s*\(')
    if (-not $m.Success) { return @() }
    $start = $m.Index + $m.Length - 1
    $depth = 0; $end = -1
    for ($i = $start; $i -lt $src.Length; $i++) {
      if ($src[$i] -eq '(') { $depth++ }
      elseif ($src[$i] -eq ')') { $depth--; if ($depth -eq 0) { $end = $i; break } }
    }
    if ($end -lt 0) { return @() }
    $block = $src.Substring($start, $end - $start)
    return [regex]::Matches($block, '\$(\w+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
  }

  function Get-GuardedRegions([string]$src, [string[]]$paramNames) {
    $regions = New-Object System.Collections.Generic.List[object]
    foreach ($pn in $paramNames) {
      foreach ($m in [regex]::Matches($src, "if\s*\(\s*\`$$pn\s*\)\s*\{")) {
        $braceStart = $m.Index + $m.Length - 1
        $depth = 0; $end = -1
        for ($i = $braceStart; $i -lt $src.Length; $i++) {
          if ($src[$i] -eq '{') { $depth++ }
          elseif ($src[$i] -eq '}') { $depth--; if ($depth -eq 0) { $end = $i; break } }
        }
        if ($end -lt 0) { continue }
        $regionEnd = $end
        $rest = $src.Substring($end + 1)
        $elseMatch = [regex]::Match($rest, '^\s*else\s*\{')
        if ($elseMatch.Success) {
          $elseBraceStart = $end + 1 + $elseMatch.Index + $elseMatch.Length - 1
          $depth2 = 0
          for ($j = $elseBraceStart; $j -lt $src.Length; $j++) {
            if ($src[$j] -eq '{') { $depth2++ }
            elseif ($src[$j] -eq '}') { $depth2--; if ($depth2 -eq 0) { $regionEnd = $j; break } }
          }
        }
        $regions.Add([PSCustomObject]@{ Start = $m.Index; End = $regionEnd })
      }
    }
    return $regions
  }

  function Find-UnguardedMutations([string]$src, [string]$label) {
    $regions = Get-GuardedRegions $src (Get-ScriptParamNames $src)
    $unguarded = @()
    foreach ($pat in $dangerPatterns) {
      foreach ($mm in [regex]::Matches($src, $pat)) {
        $idx = $mm.Index
        if (-not ($regions | Where-Object { $idx -ge $_.Start -and $idx -le $_.End })) {
          $unguarded += "$label : '$($mm.Value)' (offset $idx) is not inside an if(<param>){...}[else{...}] guard"
        }
      }
    }
    return $unguarded
  }

  # Scratch reconstruction of uninstall.ps1's real shape (param name $ClaudeDir, same danger call), but
  # with the if/else guard stripped out - the mutation now runs unconditionally.
  $unguardedScratch = @'
param(
  [string]$ClaudeDir = ""
)
$claude = if ($ClaudeDir) { $ClaudeDir } else { Join-Path $env:USERPROFILE ".claude" }

Write-Host "== Removing cross-shell wiring (PATH, DAD_HOME, ~/.bashrc block) =="
$root = $PSScriptRoot
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath) {
  $kept = ($userPath -split ';' | Where-Object { $_ -and ($_.TrimEnd('\') -ine $root.TrimEnd('\')) })
  $new = ($kept -join ';')
  if ($new -ne $userPath) { [Environment]::SetEnvironmentVariable("Path", $new, "User"); Write-Host "  removed $root from USER PATH" }
}
'@

  $result = Find-UnguardedMutations $unguardedScratch "scratch-unguarded-uninstall.ps1"
  Assert ($result.Count -gt 0) "detector found NO violations in a script whose guard was deliberately removed - it has no teeth"
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
  # MENTIONING an agent is not the same as SPAWNING one: /stories and /taskmap now name scribe-agent and
  # taskmap-agent only to say they must NOT be spawned (R32 - three loops, 920/947/1023 calls, all inside a
  # subagent). Keying on the mention made this test fire on the very fix it should be protecting, so it
  # keys on the spawn instead - and separately insists that a command naming an agent either spawns it
  # properly or forbids it explicitly. Ambiguity is what a weak model resolves by guessing.
  foreach ($f in Get-ChildItem (Join-Path $kit "global\commands") -Filter *.md) {
    $text = Get-Content $f.FullName -Raw
    $spawns  = ($text -match 'subagent_type')
    $forbids = ($text -match '(?i)do\s+NOT\s+spawn')
    if ($spawns) {
      Assert ($text -match 'Task tool') "$($f.Name) spawns an agent but never says 'Task tool'"
    } elseif ($text -match '\b[a-z][a-z0-9-]*-agent\b') {
      Assert $forbids "$($f.Name) names an agent without either spawning it or saying not to - the model will guess"
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

Test-Case "cloud mode: -Cloud drops the Ollama redirect, and use-model resolves an alias to its cloud id" {
  # DrDad's gates are model-agnostic; the ONLY coupling to 'local' is the Ollama base-URL redirect. -Cloud
  # drops it (its ABSENCE is the mode - no marker file), and each alias maps to its models.json 'cloud' id.
  # Same commands, agents, and gates, on Anthropic's frontier models.

  # every alias carries a real claude-* cloud id
  $mf = Get-Content (Join-Path $kit "models.json") -Raw | ConvertFrom-Json
  foreach ($m in $mf.models) {
    Assert ($m.cloud) "alias '$($m.alias)' has no cloud model id in models.json"
    Assert ($m.cloud -match '^claude-') "alias '$($m.alias)' cloud id '$($m.cloud)' is not a claude-* id"
  }
  Assert ("$($mf.cloudSmallFast)" -match '^claude-') "models.json has no cloudSmallFast claude-* id"

  # install.ps1 has the flag and drops the redirect
  $inst = Get-Content (Join-Path $kit "install.ps1") -Raw
  Assert ($inst -match '\[switch\]\$Cloud') "install.ps1 has no -Cloud switch"
  Assert ($inst -match 'ANTHROPIC_BASE_URL' -and $inst -match 'Remove\(') "install.ps1 -Cloud does not drop the Ollama base-URL redirect"
  # use-model + dad-doctor derive the mode from settings, not a marker file
  Assert ((Get-Content (Join-Path $kit "use-model.ps1") -Raw) -match 'ANTHROPIC_BASE_URL' -and (Get-Content (Join-Path $kit "use-model.ps1") -Raw) -match '\.cloud') "use-model.ps1 is not mode-aware"
  Assert ((Get-Content (Join-Path $kit "dad-doctor.ps1") -Raw) -match '\$cloudMode') "dad-doctor.ps1 is not cloud-mode aware"

  # functional: a CLOUD settings.json (no base-URL) -> use-model dev resolves to the cloud id; a LOCAL one -> the tag
  $sb = New-Sandbox
  try {
    $h = Join-Path $sb "home"; New-Item -ItemType Directory -Force "$h\.claude" | Out-Null
    $devCloud = (@($mf.models | Where-Object { $_.alias -eq 'dev' })[0]).cloud
    $devLocal = (@($mf.models | Where-Object { $_.alias -eq 'dev' })[0]).name
    $orig = $env:USERPROFILE
    foreach ($case in @(@{ json = '{ "env": { "ANTHROPIC_MODEL": "seed" } }'; want = $devCloud; label = "cloud" },
                        @{ json = '{ "env": { "ANTHROPIC_BASE_URL": "http://localhost:11434", "ANTHROPIC_MODEL": "seed" } }'; want = $devLocal; label = "local" })) {
      [System.IO.File]::WriteAllText("$h\.claude\settings.json", $case.json, (New-Object System.Text.UTF8Encoding($false)))
      try { $env:USERPROFILE = $h; & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "use-model.ps1") dev | Out-Null }
      finally { $env:USERPROFILE = $orig }
      $got = (Get-Content "$h\.claude\settings.json" -Raw | ConvertFrom-Json).env.ANTHROPIC_MODEL
      Assert ($got -eq $case.want) "use-model dev in $($case.label) mode set '$got', expected '$($case.want)'"
    }
  } finally { Remove-Sandbox $sb }
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
  # RUN the teardown against a sandbox, rather than grepping uninstall.ps1 for "Remove('Stop')". That grep
  # pinned an implementation detail: generalising the removal to cover a second hook event (PreToolUse)
  # broke the test while making the code correct. A hook left behind pointing at a deleted script fires on
  # every turn and fails, so what matters is that EVERY DAD hook is gone - not how.
  $sb2 = New-Sandbox
  try {
    $fake = Join-Path $sb2 ".claude"
    New-Item -ItemType Directory -Force $fake | Out-Null
    Copy-Item (Join-Path $kit "settings.json") (Join-Path $fake "settings.json") -Force
    # -ClaudeDir means SANDBOXED: the cross-shell wiring (real User PATH / DAD_HOME / ~/.bashrc) must be
    # SKIPPED, not just scoped-by-name - it used to run unconditionally regardless of -ClaudeDir, so every
    # run of THIS test mutated whatever real machine executed it (dev box or CI). Snapshot + compare.
    $pathBefore = [Environment]::GetEnvironmentVariable("Path", "User")
    $homeBefore = [Environment]::GetEnvironmentVariable("DAD_HOME", "User")
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "uninstall.ps1") -ClaudeDir $fake 2>&1 | Out-Null
    $after = Get-Content (Join-Path $fake "settings.json") -Raw
    Assert ($after -notmatch 'dad-guard') "uninstall left the Stop hook behind - it would fail on every turn once the folder is gone"
    Assert ($after -notmatch 'dad-loopguard') "uninstall left the PreToolUse hook behind - it would fail on every TOOL CALL"
    Assert (($after | ConvertFrom-Json).env.ANTHROPIC_BASE_URL) "uninstall damaged the rest of settings.json"
    Assert ($pathBefore -eq [Environment]::GetEnvironmentVariable("Path", "User")) "a -ClaudeDir (sandboxed) run mutated the REAL machine's User PATH"
    Assert ($homeBefore -eq [Environment]::GetEnvironmentVariable("DAD_HOME", "User")) "a -ClaudeDir (sandboxed) run mutated the REAL machine's DAD_HOME"
    $u = Get-Content (Join-Path $kit "uninstall.ps1") -Raw
    Assert ($u -match '(?s)if\s*\(\s*\$ClaudeDir\s*\)\s*\{.*?Skipping cross-shell wiring') "uninstall.ps1 does not gate the cross-shell wiring behind -ClaudeDir"
  } finally { Remove-Sandbox $sb2 }
}

Test-Case "copilot-hooks.json is the shape Copilot CLI actually loads" {
  $p = Join-Path $kit "copilot-hooks.json"
  Assert (Test-Path $p) "copilot-hooks.json is missing (install.ps1 -CopilotCli reads it)"
  $bytes = [System.IO.File]::ReadAllBytes($p)
  Assert (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) "copilot-hooks.json has a BOM"
  $j = Get-Content $p -Raw | ConvertFrom-Json
  Assert ($j.version -eq 1) "copilot-hooks.json must declare version 1 or Copilot skips it"
  $evts = @($j.hooks.PSObject.Properties.Name)
  # PascalCase ONLY. Copilot CLI accepts both casings but they are NOT aliases - each dispatches
  # independently, so registering both fires every hook TWICE and corrupts dad-loopguard's repeat
  # count (its whole job is counting identical calls). PascalCase is also the casing that delivers the
  # snake_case payload (tool_name/session_id/tool_input) dad-loopguard already parses.
  foreach ($e in $evts) {
    Assert ($e -cmatch '^[A-Z]') "copilot-hooks.json event '$e' is not PascalCase - camelCase would double-fire alongside it"
  }
  Assert ($evts -contains "Stop") "no Stop hook - the close-out gates would be model-optional under Copilot"
  Assert ($evts -contains "PreToolUse") "no PreToolUse hook - a subagent could repeat one failing command indefinitely"
  # Stop MUST go through the adapter. dad-guard.ps1 wired directly emits the right JSON and is still
  # ignored, because Copilot discards stdout on a nonzero exit - a silent downgrade with no error.
  $stopCmds = @($j.hooks.Stop | ForEach-Object { @($_.bash) + @($_.powershell) }) -join " "
  Assert ($stopCmds -match 'dad-guard-copilot') "Copilot's Stop hook must call dad-guard-copilot.ps1, not dad-guard.ps1 directly"
  $preCmds = @($j.hooks.PreToolUse | ForEach-Object { @($_.bash) + @($_.powershell) }) -join " "
  Assert ($preCmds -match 'dad-loopguard') "Copilot's PreToolUse hook does not call dad-loopguard.ps1"
  # Copilot reads 'bash'/'powershell', not Claude Code's 'command'. A missing key = a silent no-op.
  foreach ($e in $evts) {
    foreach ($h in $j.hooks.$e) {
      Assert ($h.type -eq "command") "copilot-hooks.json $e entry has type '$($h.type)', expected 'command'"
      Assert ($h.bash)       "copilot-hooks.json $e entry has no 'bash' command"
      Assert ($h.powershell) "copilot-hooks.json $e entry has no 'powershell' command"
    }
  }
  # Same placeholder contract as settings.json: install.ps1 rewrites it on the PARSED object.
  $devPath = 'C:\Projects\Claude\MCP\DAD-kit'
  $all = @($evts | ForEach-Object { $j.hooks.$_ } | ForEach-Object { @($_.bash) + @($_.powershell) }) -join " "
  Assert ($all -match [regex]::Escape($devPath)) "copilot-hooks.json does not use the dev-path placeholder"
  $inst = Get-Content (Join-Path $kit "install.ps1") -Raw
  Assert ($inst -match 'copilot-hooks\.json') "install.ps1 never reads copilot-hooks.json"
  Assert ($inst -match '\$h\.bash\s*=\s*\$h\.bash\.Replace') "install.ps1 does not rewrite the Copilot hook's bash command"
  Assert ($inst -match '\$h\.powershell\s*=\s*\$h\.powershell\.Replace') "install.ps1 does not rewrite the Copilot hook's powershell command"
  # USER-level only: Copilot's DOCUMENTED repo-level .github/hooks/ location silently loads nothing on
  # 1.0.89, so following the docs produces a hook that never fires and an installer that says it worked.
  Assert ($inst -match '\.copilot\\hooks') "install.ps1 does not write to the user-level .copilot\hooks dir"
}

Test-Case "dad-guard-copilot converts a BLOCK into Copilot's JSON+exit-0 contract" {
  # Measured on Copilot CLI 1.0.89 (2026-09-29), for its Stop hook:
  #   exit 2 alone                  -> IGNORED, turn ends
  #   {"decision":"block"} + exit 0 -> BLOCKS (retry arrives with stop_hook_active=true)
  #   {"decision":"block"} + exit 2 -> IGNORED (nonzero exit = "hook errored", stdout discarded)
  # dad-guard.ps1's Block() emits JSON *and* exit 2 - the third row - so pointing Copilot at it looks
  # correct and silently does nothing. Run the real adapter over a STUB guard so this asserts the
  # conversion itself, not dad-guard's project-detection.
  $sb = New-Sandbox
  try {
    Copy-Item (Join-Path $kit "dad-guard-copilot.ps1") (Join-Path $sb "dad-guard-copilot.ps1") -Force
    $adapter = Join-Path $sb "dad-guard-copilot.ps1"
    $payload = '{"session_id":"t","cwd":"C:\\x","stop_hook_active":false}'

    # 1) stub BLOCKS in dad-guard.ps1's real shape (JSON on stdout + stderr + exit 2)
    $block = '$null = [Console]::In.ReadToEnd()' + "`r`n" +
             '[Console]::Out.Write(''{"decision":"block","reason":"stub blocked"}'')' + "`r`n" +
             '[Console]::Error.Write("stub blocked")' + "`r`n" + 'exit 2'
    Set-Content (Join-Path $sb "dad-guard.ps1") $block -Encoding ASCII
    $out = $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $adapter 2>$null
    $code = $LASTEXITCODE
    $text = ($out | Out-String).Trim()
    Assert ($code -eq 0) "adapter exited $code on a block; Copilot discards stdout on a nonzero exit, so the block would be IGNORED"
    Assert ($text -match '"decision"\s*:\s*"block"') "adapter did not re-emit a block decision (got: '$text')"
    Assert ($text -match 'stub blocked') "adapter dropped dad-guard's reason text"

    # 2) stub ALLOWS -> adapter must allow silently (no stray JSON that Copilot might read as a block)
    Set-Content (Join-Path $sb "dad-guard.ps1") ('$null = [Console]::In.ReadToEnd()' + "`r`n" + 'exit 0') -Encoding ASCII
    $out2 = $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $adapter 2>$null
    $code2 = $LASTEXITCODE
    Assert ($code2 -eq 0) "adapter exited $code2 on an allow"
    Assert ((($out2 | Out-String).Trim()) -notmatch '"decision"') "adapter emitted a decision on an ALLOW - it would block every stop"

    # 3) stub blocks but prints NO json (stderr only). The verdict must survive, or exit 2's message
    #    would vanish entirely under Copilot.
    Set-Content (Join-Path $sb "dad-guard.ps1") ('$null = [Console]::In.ReadToEnd()' + "`r`n" + '[Console]::Error.Write("no json here")' + "`r`n" + 'exit 2') -Encoding ASCII
    $out3 = $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $adapter 2>$null
    Assert ($LASTEXITCODE -eq 0) "adapter exited nonzero on a json-less block"
    Assert ((($out3 | Out-String).Trim()) -match '"decision"\s*:\s*"block"') "adapter lost a block that produced no JSON"

    # 4) fail OPEN when dad-guard.ps1 is absent, matching dad-guard's own policy
    Remove-Item (Join-Path $sb "dad-guard.ps1") -Force
    $out4 = $payload | & powershell -NoProfile -ExecutionPolicy Bypass -File $adapter 2>$null
    Assert ($LASTEXITCODE -eq 0) "adapter did not fail open when dad-guard.ps1 was missing"
    Assert ((($out4 | Out-String).Trim()) -notmatch '"decision"') "adapter blocked when dad-guard.ps1 was missing - it must fail open"
  } finally { Remove-Sandbox $sb }
}

Test-Case "uninstall removes the Copilot CLI hook file (sandboxed)" {
  # A dad.json left behind fires on every Copilot tool call and every stop, and fails once the kit
  # folder is gone - the same failure the Claude Code hook teardown above exists to prevent.
  $sb = New-Sandbox
  try {
    $fakeHooks = Join-Path $sb "copilot-hooks-dir"
    New-Item -ItemType Directory -Force $fakeHooks | Out-Null
    Copy-Item (Join-Path $kit "copilot-hooks.json") (Join-Path $fakeHooks "dad.json") -Force
    $fakeClaude = Join-Path $sb ".claude"
    New-Item -ItemType Directory -Force $fakeClaude | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "uninstall.ps1") -ClaudeDir $fakeClaude -CopilotDir $fakeHooks 2>&1 | Out-Null
    Assert (-not (Test-Path (Join-Path $fakeHooks "dad.json"))) "uninstall left the Copilot hook file behind - it would fail on every tool call once the folder is gone"
    # A same-named file that is NOT ours must survive.
    Set-Content (Join-Path $fakeHooks "dad.json") '{"version":1,"hooks":{}}' -Encoding ASCII
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "uninstall.ps1") -ClaudeDir $fakeClaude -CopilotDir $fakeHooks 2>&1 | Out-Null
    Assert (Test-Path (Join-Path $fakeHooks "dad.json")) "uninstall deleted a dad.json that contained no DAD guard reference"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the measured Copilot version cannot drift between DESIGN's C2 and install.ps1 (C2f)" {
  # Contract C2f names install.ps1's $CopilotMeasuredVersion the ONE source of truth for the version C2 was
  # measured against, and requires this assertion so the doc and the code cannot disagree silently. That is
  # the contract applying its own rule to itself: every OTHER silent-drift failure here (hook location,
  # event casing, block semantics) is invisible at runtime, and so is this one - a stale number would keep
  # claiming a contract had been verified against a harness nobody ever tested.
  $inst = Get-Content (Join-Path $kit "install.ps1") -Raw
  $m = [regex]::Match($inst, '\$CopilotMeasuredVersion\s*=\s*"([^"]+)"')
  Assert $m.Success "install.ps1 has no `$CopilotMeasuredVersion constant (contract C2f requires one)"
  $constant = $m.Groups[1].Value

  $design = Get-Content (Join-Path $kit "docs\DESIGN.md") -Raw
  $d = [regex]::Match($design, 'MEASURED\s+\d{4}-\d{2}-\d{2}\s+against\s+GitHub\s+Copilot\s+CLI\s+([0-9][0-9.]*)')
  Assert $d.Success "DESIGN.md contract C2 carries no 'MEASURED <date> against GitHub Copilot CLI <version>' stamp"
  $stamped = $d.Groups[1].Value

  Assert ($constant -eq $stamped) "install.ps1 says Copilot $constant but DESIGN.md C2 is stamped $stamped - re-measure C2a-C2e, then update BOTH"

  # dad-doctor must READ the constant, not carry its own copy: two hard-coded numbers is the drift C2f bans.
  $doc = Get-Content (Join-Path $kit "dad-doctor.ps1") -Raw
  Assert ($doc -match 'CopilotMeasuredVersion') "dad-doctor.ps1 does not read install.ps1's `$CopilotMeasuredVersion"
  Assert ($doc -notmatch '"' + [regex]::Escape($constant) + '"') "dad-doctor.ps1 hard-codes the Copilot version instead of reading it from install.ps1"

  # C2f: LOUD at setup, fail-open at runtime. The guards must NOT gain a version self-check.
  foreach ($g in @("dad-guard-copilot.ps1","dad-loopguard.ps1")) {
    $gs = Get-Content (Join-Path $kit $g) -Raw
    Assert ($gs -notmatch '\$CopilotMeasuredVersion') "$g self-checks the harness version at runtime - C2f keeps drift detection at SETUP only, so a guard never blocks on its own uncertainty"
  }
}

Test-Case "C2f's drift check compares versions by EQUALITY, not substring (graded S12 defect)" {
  # Found by grade-agent on S12. Both consumers originally tested the raw `copilot --version` LINE with
  # -match against the measured number. That is silently wrong: "1.0.890" and "11.0.89" both CONTAIN
  # "1.0.89", so an UNMEASURED harness reported "[ok] matches the measured contract" - C2f's only drift
  # mechanism defeating itself, which is precisely the silent-failure class C2 exists to prevent.
  #
  # Prove the defect is REAL first, so this case cannot pass vacuously (e.g. on a typo'd regex): the old
  # comparison must actually mis-match these values, and the new one must not.
  $measured = "1.0.89"
  foreach ($adversarial in @("1.0.890", "11.0.89")) {
    Assert ($adversarial -match [regex]::Escape($measured)) "test is vacuous: '$adversarial' no longer trips the substring form"
    $extracted = [regex]::Match($adversarial, '\d+(\.\d+)+').Value
    Assert ($extracted -ne $measured) "extract-then-compare failed to distinguish '$adversarial' from '$measured'"
  }

  # Now assert neither consumer still carries the substring form, and that both extract + compare.
  foreach ($f in @("install.ps1","dad-doctor.ps1")) {
    $src = Get-Content (Join-Path $kit $f) -Raw
    Assert ($src -notmatch '-notmatch\s+\[regex\]::Escape\(\$(CopilotMeasuredVersion|measured)\)') `
      "$f still substring-tests the Copilot version - '1.0.890' would report as a match on an unmeasured harness"
    Assert ($src -match "\[regex\]::Match\(\`$c\w*,\s*'\\d\+\(\\\.\\d\+\)\+'\)") "$f does not EXTRACT a numeric version before comparing"
    Assert ($src -match '-ne\s+\$(CopilotMeasuredVersion|measured)') "$f does not compare the extracted version for equality"
  }
}

Test-Case "the guard counts WEB source as code (.cshtml, appsettings.json)" {
  # The extension list was C#/Python/JS-shaped and omitted .cshtml, .razor, .html, .css and .json. So for
  # the project types this kit is most likely to be pointed at - an ASP.NET Razor Pages site, or anything
  # ui-agent touches - the actual USER-FACING files were not "code" as far as the guard was concerned. A
  # turn could end with the whole UI uncommitted and unverified and the guard would report a clean tree.
  # Config counts too: an upload size limit or a connection string in appsettings.json decides whether the
  # app works at all.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"
    New-Item -ItemType Directory -Force "$p\Pages" | Out-Null
    New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# t`n`n## Build / test`n- Build: ``exit 0```n- Test:  ``exit 0``" | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    "0.19.4" | Set-Content "$p\.dad-kit-version" -Encoding UTF8
    "# Design`n`nStatus: LOCKED" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $guard = Join-Path $kit "dad-guard.ps1"
    foreach ($f in @("Pages\Upload.cshtml", "appsettings.json", "wwwroot\site.css", "Pages\Index.razor")) {
      $full = Join-Path $p $f
      New-Item -ItemType Directory -Force (Split-Path $full) | Out-Null
      "content" | Set-Content $full -Encoding UTF8
      & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $p 2>&1 | Out-Null
      Assert ($LASTEXITCODE -eq 1) "an uncommitted $f did NOT block - it is user-facing source"
      Remove-Item $full -Force
    }
    # and docs must still NOT trip it: the guard is about code, and blocking doc edits would be constant
    "notes" | Set-Content "$p\docs\NOTES.md" -Encoding UTF8
    '{"x":1}' | Set-Content "$p\docs\data.json" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Check -ProjectDir $p 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 0) "a docs\ change blocked the turn - adding .json must not make the guard fire on documentation"
  } finally { Remove-Sandbox $sb }
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

Test-Case "S1 is a WALKING skeleton, and the kit says so where stories get written" {
  # Measured failure: a project reached 183 passing unit tests across 12 building projects with a
  # TWENTY-LINE host and zero integration tests, having never served a request. Its S1 was "create
  # solution skeleton with warnings as errors" - build configuration. Every later story then added to a
  # pile nobody had assembled. A walking skeleton makes close-unit's test gate mean INTEGRATION from the
  # first close.
  $tpl = Get-Content (Join-Path $kit "templates\_common\docs\STORIES.md") -Raw
  Assert ($tpl -match 'WALKING SKELETON') "the STORIES template does not demand a walking skeleton"
  Assert ($tpl -match 'end to end|END TO END') "it does not say end to end"
  Assert ($tpl -match 'integration test') "it does not require an integration test in S1"
  Assert ($tpl -notmatch '### Story S1: <title>') "S1's placeholder is still a bare title, not an end-to-end slice"
  foreach ($f in @("global\commands\stories.md","global\agents\scribe-agent.md","global\commands\taskmap.md")) {
    Assert ((Get-Content (Join-Path $kit $f) -Raw) -match 'WALKING SKELETON') "$f does not carry the rule"
  }
}

Test-Case "the security review is a gated header, settled before stories" {
  # Auth, input handling and secret management are where a passing test suite tells you least, and
  # retrofitting them after a dozen stories is how the insecure version ships. So it is a header field
  # like Status: - computable, and /build refuses while it is outstanding.
  $tpl = Get-Content (Join-Path $kit "templates\_common\docs\DESIGN.md") -Raw
  Assert ($tpl -match '(?m)^Security review:\s*REQUIRED') "the DESIGN template has no Security review header"
  Assert ($tpl -match 'NOT-REQUIRED') "there is no way to record a deliberate opt-out"
  Assert ($tpl -match '## Security decisions') "there is nowhere for the answers to land"

  # computed: REQUIRED is a finding, DONE and NOT-REQUIRED are not
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    $ds = Join-Path $kit "doc-stats.ps1"
    foreach ($case in @(
      @{ H = "Security review: REQUIRED";                 Expect = $true  },
      @{ H = "Security review: DONE 2026-08-21";           Expect = $false },
      @{ H = "Security review: NOT-REQUIRED (poc, no auth)"; Expect = $false }
    )) {
      "# Design`n`nStatus: LOCKED`n$($case.H)`n" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
      $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String)
      $flagged = ($out -match 'Security review: REQUIRED and not done')
      Assert ($flagged -eq $case.Expect) "'$($case.H)' -> flagged=$flagged, expected $($case.Expect)"
    }
    # an OLD project with no header must WARN, never block
    "# Design`n`nStatus: LOCKED`n" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    $old = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String)
    Assert ($old -match "no 'Security review:' header") "a pre-existing project's missing header was not reported"
    Assert ($LASTEXITCODE -eq 0) "-Findings should never exit non-zero"
  } finally { Remove-Sandbox $sb }

  # the agent, and the two commands that must route to / gate on it
  $a = Get-Content (Join-Path $kit "global\agents\security-agent.md") -Raw
  Assert ($a -match 'web_search' -and $a -match 'ingest_url') "security-agent cannot reach current guidance"
  Assert ($a -match '6 months') "security-agent has no recency requirement - the whole point is checking dates"
  Assert ($a -match 'You do not flip the') "security-agent may set its own DONE header"
  Assert ($a -match 'do not write code|You do not write code') "security-agent is not held to decisions-only"
  $d = Get-Content (Join-Path $kit "global\commands\design.md") -Raw
  Assert ($d -match 'security-agent') "/design never spawns it"
  Assert ($d -match 'StaleDays 180') "/design does not tighten source recency for security"
  $b = Get-Content (Join-Path $kit "global\commands\build.md") -Raw
  Assert ($b -match 'Gate 2b') "/build has no security gate"
  Assert ($b -match 'ABSENT') "/build would block an older project that predates the header"
}

Test-Case "duplicate unit ids are reported (a regenerated file appended, not replaced)" {
  # Real corruption nothing caught: STORIES.md ended up with every story TWICE (28 headings, 14 distinct
  # ids) and TASKS.md carried a stray "RECOVERED" block. The close was clean, so the ratchet baselined the
  # doubled counts as its floor - and the later repair then looked like a regression. An id appearing twice
  # is never right, and it is a grep.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Design`n`nStatus: LOCKED" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    @("# Stories","",
      "### Story S1: One   (Epic E1) <!-- Status: DONE -->","",
      "### Story S2: Two   (Epic E1) <!-- Status: TODO -->","",
      "### Story S1: One   (Epic E1) <!-- Status: DONE -->","") | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    @("# Tasks","","## Tasks","",
      "### [x] T1.1 - a   (Story S1)","- **Goal:** x","",
      "### [ ] T2.1 - b   (Story S2)","- **Goal:** y","",
      "### [x] T1.1 - a   (Story S1)","- **Goal:** x","") | Set-Content "$p\docs\TASKS.md" -Encoding UTF8

    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") `
              -ProjectDir $p -Findings 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 0) "-Findings exited $LASTEXITCODE"
    Assert ($out -match '\[scribe\] DUPLICATE story id S1 - appears 2x') "a duplicated story id was not reported:`n$out"
    Assert ($out -match '\[taskmap\] DUPLICATE task id T1\.1 - appears 2x') "a duplicated task id was not reported:`n$out"
    Assert ($out -match 'lines \d+, \d+') "it did not say WHERE the duplicates are"
    Assert ($out -notmatch 'DUPLICATE story id S2') "a non-duplicated id was flagged"

    # and a clean doc set must produce none of it
    @("# Stories","","### Story S1: One   (Epic E1) <!-- Status: DONE -->","",
      "### Story S2: Two   (Epic E1) <!-- Status: TODO -->","") | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    @("# Tasks","","## Tasks","","### [x] T1.1 - a   (Story S1)","- **Goal:** x","",
      "### [ ] T2.1 - b   (Story S2)","- **Goal:** y","") | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    $clean = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") `
                -ProjectDir $p -Findings 2>&1 | Out-String)
    Assert ($clean -notmatch 'DUPLICATE') "it invented duplicates on a clean doc set:`n$clean"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the corpus has a SHELL door, and it degrades instead of dying" {
  # Nine graded runs called search_datasheets ZERO times while calling shell commands constantly - one run
  # used doc-stats 17 times and Bash 94. Prose preferring an MCP tool has been in three agent files the
  # whole time and never worked once. So the same corpus gets a shell entrance.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Design`n`n### C9: IIIF conformance`n- **Decision:** tile sizes are 512 by default." |
      Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    $df = Join-Path $kit "docs-find.ps1"
    Assert (Test-Path $df) "docs-find.ps1 is missing"
    Assert (Test-Path (Join-Path $kit "docs-find.cmd")) "docs-find has no .cmd wrapper"

    # This box has no Ollama, so semantic search cannot run - the point is that it still ANSWERS.
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $df -ProjectDir $p "tile sizes" 2>&1 | Out-String)
    Assert ($out -match 'tile sizes|512') "it returned nothing when semantic search was unavailable:`n$out"
    Assert ($out -match 'literal scan|semantic search unavailable') "it did not say it had fallen back"

    # a query with no match must say so rather than returning noise
    & powershell -NoProfile -ExecutionPolicy Bypass -File $df -ProjectDir $p "zzzznotpresentzzzz" 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 1) "a no-match query did not exit non-zero"

    # and the agents that need it must point at it
    foreach ($a in @("global\agents\dev-agent.md","global\agents\qa-agent.md","global\commands\build.md")) {
      Assert ((Get-Content (Join-Path $kit $a) -Raw) -match 'docs-find') "$a does not offer the shell door"
    }
  } finally { Remove-Sandbox $sb }
}

Test-Case "docs-find NEVER creates a real directory at an unrewritten .mcp.json placeholder" {
  # R35, found via self-hosting: this KIT's OWN .mcp.json (committed with the unrewritten dev-path
  # placeholder - install.ps1 rewrites it only on a real install, never for the kit's own self-hosted repo)
  # sent docs-find.ps1 chasing LOCALTOOLS_DOCS_DIR to a path that does not exist on this machine. Unlike
  # close-unit.ps1/doc-stats.ps1 (which both guard this with -and (Test-Path $d)), docs-find.ps1 only
  # checked `if ($d)` - truthy, not real - so it set $env:LOCALTOOLS_DOCS_DIR to the bogus path and invoked
  # local-tools.exe, whose Rag.cs unconditionally Directory.CreateDirectory()s the docs dir AND its .index
  # subfolder. That created a real, empty directory tree OUTSIDE any project, on the real machine - which
  # then went on to hijack close-unit's own (correctly guarded) path resolution on a LATER run, because
  # once the bogus path exists, Test-Path stops distinguishing "really configured" from "leaked by a bug".
  if (-not (Test-Path (Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"))) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Design`n`n### C9: marker`n- **Decision:** the real project docs dir was used, per this text." |
      Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    # a bogus LOCALTOOLS_DOCS_DIR, shaped exactly like an unrewritten dev-path placeholder - a path that
    # does NOT exist and must NEVER get created just by being read.
    $bogus = Join-Path $sb "bogus-unrewritten-placeholder\docs"
    Assert (-not (Test-Path $bogus)) "test setup problem: the bogus path already exists"
    @{ mcpServers = @{ 'local-tools' = @{ command = "local-tools.exe"; env = @{ LOCALTOOLS_DOCS_DIR = $bogus } } } } |
      ConvertTo-Json -Depth 10 | Set-Content "$p\.mcp.json" -Encoding UTF8

    $df = Join-Path $kit "docs-find.ps1"
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $df -ProjectDir $p "marker" 2>&1 | Out-String)

    Assert (-not (Test-Path $bogus)) "docs-find created a REAL directory at the unrewritten placeholder path - the exact R35 leak this test guards against:`n$out"
    Assert ($out -match 'marker|C9') "docs-find did not fall back to the PROJECT'S OWN docs dir when the configured LOCALTOOLS_DOCS_DIR did not exist:`n$out"
  } finally { Remove-Sandbox $sb }
}

Test-Case "close-unit RECORDS the commands that worked (RECIPES stops being empty)" {
  # docs\RECIPES.md was designed as a proven-commands log agents append to on success. After nine runs on a
  # real project it held 18 lines - the bare template, zero entries. Meanwhile runs kept emitting broken
  # shell (one used bash syntax with a two-segment-wrong path and lost the turn). So the close-out writes it.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Task map`n`n## Tasks`n`n### [ ] T1.1 - a   (Story S1)`n- **Goal:** x`n`n### [ ] T1.2 - b   (Story S1)`n- **Goal:** y" |
      Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    "# Project: t`n`n## Build / test`n- Build: ``exit 0```n- Test:  ``exit 0``" | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Copy-Item (Join-Path $kit "templates\_common\docs\RECIPES.md") "$p\docs\RECIPES.md"
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $cu = Join-Path $kit "close-unit.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "a" -ProjectDir $p -NoReindex | Out-Null
    Assert ($LASTEXITCODE -eq 0) "the close failed"
    $r = Get-Content "$p\docs\RECIPES.md" -Raw
    Assert ($r -match 'Verified by close-unit') "no verified-commands section was written"
    Assert ($r -match 'exit 0') "the command that actually ran was not recorded"

    # a second close must NOT duplicate the same rows
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.2 -Title "b" -ProjectDir $p -NoReindex | Out-Null
    $r2 = Get-Content "$p\docs\RECIPES.md" -Raw
    Assert ((([regex]::Matches($r2, 'Verified by close-unit')).Count -eq 1)) "the section was written twice"
    Assert ((([regex]::Matches($r2, '\| ``exit 0`` \| build')).Count -le 1)) "the same command was recorded twice"
  } finally { Remove-Sandbox $sb }
}

Test-Case "RECIPES ships pre-loaded with the traps, instead of one delete-me example" {
  # close-unit records the commands THIS project verified, which is worth nothing on day one - and day one
  # is exactly when a model writes `&&` into PowerShell 5.1 and loses the turn. So the template ships the
  # traps that have actually broken a run of this kit. Every one PARSED and then misbehaved, which is why
  # "it ran without a syntax error" is not evidence.
  $r = Get-Content (Join-Path $kit "templates\_common\docs\RECIPES.md") -Raw
  Assert ($r -match '(?m)^## Kit-seeded') "the template has no seeded section - a new project starts with no command cache"
  Assert ($r -match 'do not delete') "the seeded section is not marked as keep-me, so /tidy will treat it as the example entry"
  foreach ($t in @('git commit -F', 'UTF8Encoding\(\$false\)', "The term 'if' is not recognized",
                   '@\(Get-Something', 'Test-Path ""', '&&')) {
    Assert ($r -match $t) "the seeded traps do not cover: $t"
  }
  # Each entry must carry the SAME fields close-unit writes, or the doc is two formats and agents parse neither.
  $seeded = ($r -split '(?m)^## Kit-seeded')[1]
  foreach ($field in @('\*\*Command:\*\*','\*\*Does:\*\*','\*\*When:\*\*','\*\*Gotcha:\*\*','\*\*Verified:\*\*')) {
    Assert ((([regex]::Matches($seeded, $field)).Count -ge 6)) "seeded entries are missing the $field field"
  }
  # A dated 'Verified:' is the whole point - an undated claim is the prose gate this kit exists to replace.
  Assert (-not ($seeded -match 'Verified:\s*<YYYY')) "a seeded entry still has a placeholder date"
}

Test-Case "recover-lost finds what vanished, and knows MOVED from LOST" {
  # The generic shape: a change removed far more than it added, the result still compiles, nothing looks
  # broken. Recovery has to work at the level of NAMED UNITS - a whole-file revert would also discard
  # everything the change ADDED (on the real incident: a test fixture and two correct fixes).
  # And "sensible" means not restoring a unit that merely MOVED - on that same incident 3 of 15 had been
  # relocated to another file, and putting them back would have duplicated them.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\tests" | Out-Null
    $body = (1..6 | ForEach-Object { "    [Fact]`r`n    public void Case$_() { }" }) -join "`r`n"
    "public class T {`r`n$body`r`n    [Fact]`r`n    public void Relocated() { }`r`n}" |
      Set-Content "$p\tests\A.cs" -Encoding UTF8
    "public class Other {`r`n}" | Set-Content "$p\tests\B.cs" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $sha = (git rev-parse HEAD | Out-String).Trim()
    $ErrorActionPreference = $prev; Pop-Location

    # the rewrite: A.cs keeps one old test, GAINS a new one, loses five - and Relocated moves to B.cs
    "public class T {`r`n    [Fact]`r`n    public void Case1() { }`r`n    [Fact]`r`n    public void BrandNew() { }`r`n}" |
      Set-Content "$p\tests\A.cs" -Encoding UTF8
    "public class Other {`r`n    [Fact]`r`n    public void Relocated() { }`r`n}" | Set-Content "$p\tests\B.cs" -Encoding UTF8

    $rl = Join-Path $kit "recover-lost.ps1"
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $rl -ProjectDir $p -Since $sha 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 1) "loss was not detected"
    foreach ($n in @('Case2','Case3','Case4','Case5','Case6')) {
      Assert ($out -match $n) "genuinely lost unit $n was not reported:`n$out"
    }
    Assert ($out -match 'moved elsewhere') "it did not separate moved from lost"
    Assert ($out -match 'Relocated') "the moved unit was not identified"
    # a unit that moved must NOT be listed as GONE - restoring it would duplicate it
    $goneBlock = [regex]::Match($out, '(?s)GONE.*?(moved elsewhere|Report only)').Value
    Assert ($goneBlock -notmatch 'Relocated') "a MOVED unit was listed as gone - a restore would duplicate it"
    Assert ($out -notmatch 'BrandNew') "an ADDED unit was reported as lost"

    # -Restore keeps what arrived and hands back the old content to reconcile
    & powershell -NoProfile -ExecutionPolicy Bypass -File $rl -ProjectDir $p -Since $sha -Restore | Out-Null
    Assert ($LASTEXITCODE -eq 0) "-Restore failed"
    $after = Get-Content "$p\tests\A.cs" -Raw
    Assert ($after -match 'BrandNew') "the restore destroyed what the change ADDED"
    Assert ($after -match 'RECOVERED from') "no recovery marker was written"
    Assert ($after -match 'Case5') "the vanished content was not returned"
    # commented out on purpose - it is a starting point, not a merge
    Assert ($after -match '(?s)/\*.*Case5') "recovered content was pasted live instead of commented for review"

    # nothing to do on a clean tree
    $clean = (& powershell -NoProfile -ExecutionPolicy Bypass -File $rl -ProjectDir $p -Since HEAD 2>&1 | Out-String)
    Assert ($clean -match 'nothing named has vanished' -or $LASTEXITCODE -eq 0) "it invented a loss on a clean comparison"

    # and the three places that must point at it
    Assert ((Get-Content (Join-Path $kit "ratchet.ps1") -Raw) -match 'recover-lost') "ratchet does not point at the recovery tool"
    Assert ((Get-Content (Join-Path $kit "close-unit.ps1") -Raw) -match 'recover-lost') "close-unit does not point at it"
    Assert ((Get-Content (Join-Path $kit "global\commands\build.md") -Raw) -match 'recover-lost') "/build does not route to it"
  } finally { Remove-Sandbox $sb }
}

Test-Case "a shrink comes with a RUNNABLE recovery, not just a complaint" {
  # "Restore it (git has it)" is true and useless - the same unresolvable-advice defect the stop guard
  # shipped with in 0.12.0, repeated. Recovery needs the FILE and the COMMIT, and the count alone has
  # neither. The baseline now records the commit it was taken at, so the restore command can be exact.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\tests" | Out-Null
    $tests = (1..15 | ForEach-Object { "    [Fact]`r`n    public void Case$_() { }" }) -join "`r`n"
    "public class T {`r`n$tests`r`n}" | Set-Content "$p\tests\ApiTests.cs" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $sha = (git rev-parse HEAD | Out-String).Trim()
    $ErrorActionPreference = $prev; Pop-Location

    $r = Join-Path $kit "ratchet.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $r -ProjectDir $p -Update | Out-Null
    $base = Get-Content "$p\.claude\.dad-ratchet.json" -Raw | ConvertFrom-Json
    Assert ($base.commit -eq $sha) "the baseline did not record the commit it was taken at"

    # the runD shape: the file survives and parses, it just has 14 fewer tests
    "public class T {`r`n    [Fact]`r`n    public void OnlyOne() { }`r`n}" | Set-Content "$p\tests\ApiTests.cs" -Encoding UTF8
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $r -ProjectDir $p 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 1) "the shrink was not caught"
    Assert ($out -match 'WHAT WAS REMOVED') "it did not offer a recovery"
    Assert ($out -match 'tests[\\/]ApiTests\.cs') "it did not name the file that lost the tests:`n$out"
    Assert ($out -match '\(15 -> 1 test') "it did not say how many were lost from that file"
    # the command must be runnable as printed: real sha, real path, real redirect
    Assert ($out -match "git show $sha[:]tests[\\/]ApiTests\.cs > ") "no runnable restore command:`n$out"
    Assert ($out -match 'RECONCILE') "it did not warn that the rest of the change may be worth keeping"

    # and running the printed command must actually put the tests back
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $restored = (git show "$sha`:tests/ApiTests.cs" | Out-String)
    $ErrorActionPreference = $prev; Pop-Location
    Assert (@([regex]::Matches($restored, '\[Fact\]')).Count -eq 15) "the recovery command does not return the 15 tests"

    # /build must ROUTE a shrink to recovery, and know it is not the same as a mangled file
    $b = Get-Content (Join-Path $kit "global\commands\build.md") -Raw
    Assert ($b -match 'recovery, not a retry') "/build does not route a shrink to recovery"
    Assert ($b -match 'NOT "mangled"') "/build does not distinguish a shrink from a mangled file"
    Assert (([regex]::Matches($b, 'recovery, not a retry')).Count -eq 1) "the recovery guidance is duplicated in build.md"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the ratchet refuses a SHRINKING verification surface" {
  # The trap every other gate left open: they ask "is X OK now?", which is satisfied by DELETING X.
  # A run rewrote ImageApiControllerTests.cs to add a fixture; 15 of 16 tests did not survive. Every gate
  # went green - build passed, tests RAN (11 > 0), tests PASSED (8), tree clean - because none of them
  # compared against what was there before. Five surfaces were open; all are covered here.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"
    New-Item -ItemType Directory -Force "$p\docs","$p\tests","$p\grades" | Out-Null
    @("# Design","","Status: LOCKED","","- R1: one","- R2: two","","### C9: conformance","- **Decision:** x") |
      Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    @("# Stories","","### Story S1: One <!-- Status: TODO -->","","### Story S2: Two <!-- Status: TODO -->") |
      Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    @("# Tasks","","### [ ] T1.1 - a  (Story S1)","","### [ ] T2.1 - b  (Story S2)") |
      Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    @("# Project: t","","## Build / test","- Build: ``exit 0``","- Test:  ``exit 0``") |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    $tests = (1..15 | ForEach-Object { "    [Fact]`r`n    public void Case$_() { }" }) -join "`r`n"
    "public class T {`r`n$tests`r`n}" | Set-Content "$p\tests\ApiTests.cs" -Encoding UTF8
    ("x" * 900) | Set-Content "$p\grades\S1_GRADE.md" -Encoding UTF8

    $r = Join-Path $kit "ratchet.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $r -ProjectDir $p -Update | Out-Null
    Assert (Test-Path "$p\.claude\.dad-ratchet.json") "no baseline was written"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $r -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 0) "an unchanged project was reported as shrinking"

    # THE runD FAILURE, exactly: rewrite the test file down to one test
    "public class T {`r`n    [Fact]`r`n    public void OnlyOne() { }`r`n}" | Set-Content "$p\tests\ApiTests.cs" -Encoding UTF8
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $r -ProjectDir $p 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 1) "deleting 14 tests was not caught"
    Assert ($out -match 'tests: 15 -> 1') "the drop was not reported with its numbers:`n$out"

    # the other four surfaces
    @("# Design","","Status: LOCKED","","- R1: one") | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8   # C9 + R2 gone
    @("# Stories","","### Story S1: One <!-- Status: TODO -->") | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    @("# Project: t","","## Build / test","- Test:  ``exit 0``") | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    $out2 = (& powershell -NoProfile -ExecutionPolicy Bypass -File $r -ProjectDir $p 2>&1 | Out-String)
    foreach ($k in @('requirements','contracts','stories','hasBuildCommand')) {
      Assert ($out2 -match "$k[: ].*->") "a drop in '$k' was not detected:`n$out2"
    }
    # deleting the Build: line is the nastiest one - it makes close-unit close WITHOUT verification
    Assert ($out2 -match 'hasBuildCommand: 1 -> 0') "losing CLAUDE.md's Build command was not caught"
  } finally { Remove-Sandbox $sb }
}

Test-Case "close-unit REFUSES to close over a shrink, and only ratchets on success" {
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs","$p\tests" | Out-Null
    "# Task map`n`n## Tasks`n`n### [ ] T1.1 - a   (Story S1)`n- **Goal:** x`n`n### [ ] T1.2 - b   (Story S1)`n- **Goal:** y" |
      Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    "# Project: t`n`n## Build / test`n- Build: ``exit 0```n- Test:  ``exit 0``" | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    $tests = (1..10 | ForEach-Object { "    [Fact]`r`n    public void Case$_() { }" }) -join "`r`n"
    "public class T {`r`n$tests`r`n}" | Set-Content "$p\tests\ApiTests.cs" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $cu = Join-Path $kit "close-unit.ps1"
    # first close is clean -> it should RECORD the baseline
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "a" -ProjectDir $p -NoReindex | Out-Null
    Assert ($LASTEXITCODE -eq 0) "the first clean close failed"
    Assert (Test-Path "$p\.claude\.dad-ratchet.json") "a clean close did not record the ratchet baseline"

    # now delete half the tests and try to close the next unit
    "public class T {`r`n    [Fact]`r`n    public void One() { }`r`n}" | Set-Content "$p\tests\ApiTests.cs" -Encoding UTF8
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.2 -Title "b" -ProjectDir $p -NoReindex 2>&1 | Out-String)
    Assert ($LASTEXITCODE -ne 0) "close-unit closed a unit over deleted tests"
    Assert ($out -match 'SHRANK') "it did not say what was wrong:`n$out"
    Assert (-not (Select-String "$p\docs\TASKS.md" -Pattern '^###\s*\[x\]\s*T1\.2' -Quiet)) "it ticked the task anyway"

    # -AcceptShrink is the deliberate override, and it lowers the bar rather than silently passing
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.2 -Title "b" -ProjectDir $p -NoReindex -AcceptShrink | Out-Null
    Assert ($LASTEXITCODE -eq 0) "-AcceptShrink did not allow a deliberate removal"
    $base = Get-Content "$p\.claude\.dad-ratchet.json" -Raw | ConvertFrom-Json
    Assert ($base.tests -eq 1) "the baseline was not lowered to the accepted number ($($base.tests))"
  } finally { Remove-Sandbox $sb }
}

Test-Case "dad-gates-smoke: skeleton reports SKIP honestly, never a fabricated pass (T8.1)" {
  # T8.2/T8.3/T8.4 replaced the stub Test-*Gate functions one at a time with real provocations - this
  # case keeps asserting the report/exit-code contract itself (parse/ASCII/usage/loud-failure), which
  # holds regardless of which gates are real.
  $gs = Join-Path $kit "dad-gates-smoke.ps1"
  Assert (Test-Path $gs) "dad-gates-smoke.ps1 is missing"
  $errs = $null
  [System.Management.Automation.Language.Parser]::ParseFile($gs, [ref]$null, [ref]$errs) | Out-Null
  Assert ($errs.Count -eq 0) "dad-gates-smoke.ps1 does not parse: $($errs[0].Message)"
  $bad = ([System.IO.File]::ReadAllBytes($gs) | Where-Object { $_ -gt 127 }).Count
  Assert ($bad -eq 0) "dad-gates-smoke.ps1 has $bad non-ASCII byte(s)"

  $gsCmd = Join-Path $kit "dad-gates-smoke.cmd"
  Assert (Test-Path $gsCmd) "dad-gates-smoke.cmd is missing"

  $usage = (& cmd /c "`"$(Join-Path $kit 'dad.cmd')`" 2>&1" | Out-String)
  Assert ($usage -match '(?m)^\s{4,}dad gates-smoke\b') "dad.cmd's usage text does not advertise 'gates-smoke'"

  # -ProjectDir must fail loudly on a bad path, same convention as ratchet.ps1/doc-stats.ps1.
  $bogus = Join-Path $kit "_no_such_project_dir_gates_smoke"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $gs -ProjectDir $bogus 2>&1 | Out-Null
  Assert ($LASTEXITCODE -eq 2) "dad-gates-smoke.ps1 did not fail loudly on a missing -ProjectDir (got exit $LASTEXITCODE)"
}

Test-Case "dad-gates-smoke intercepts all three real gates (T8.2/T8.3/T8.4 together)" {
  # S8 AC1-AC5: against the kit's OWN real, unmodified dad-loopguard.ps1/ratchet.ps1/close-unit.ps1/
  # dad-guard.ps1, gates-smoke must report all three gates INTERCEPTED, never SILENT-FAIL or SKIP, and
  # exit 0 - proving the gates actually fire, not merely that the hook files exist.
  $gs = Join-Path $kit "dad-gates-smoke.ps1"
  $sb = New-Sandbox
  try {
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $gs -ProjectDir $sb 2>&1 | Out-String)
    $exit = $LASTEXITCODE
    Assert ($out -match [regex]::Escape("[gates-smoke] loop-guard: INTERCEPTED")) "gate 'loop-guard' was not INTERCEPTED:`n$out"
    Assert ($out -match [regex]::Escape("[gates-smoke] ratchet-close-refusal: INTERCEPTED")) "gate 'ratchet-close-refusal' was not INTERCEPTED:`n$out"
    Assert ($out -match [regex]::Escape("[gates-smoke] dad-guard-stop: INTERCEPTED")) "gate 'dad-guard-stop' was not INTERCEPTED:`n$out"
    Assert ($out -notmatch 'SILENT-FAIL') "a gate was reported as SILENT-FAIL - a real violation got through unnoticed:`n$out"
    Assert ($out -notmatch [regex]::Escape(": SKIP")) "a gate was reported SKIP when all three should have run for real:`n$out"
    Assert ($exit -eq 0) "all three gates intercepted and none is SILENT-FAIL/SKIP, so the run should exit 0:`n$out"
  } finally { Remove-Sandbox $sb }
}

Test-Case "dad-gates-smoke reports a genuine per-gate SKIP when one sibling script is missing (S8 grade follow-up)" {
  # The two Test-Cases above only prove the CONTRACT (T8.1 skeleton) and the all-real/all-INTERCEPTED
  # path (T8.2/T8.3/T8.4 together) - neither one forces an INDIVIDUAL gate's own SKIP branch text to
  # actually fire against otherwise-working tooling, only the aggregate all-SKIP->FAIL path is stubbed
  # elsewhere. Copy dad-gates-smoke.ps1 to an isolated directory together with ONLY the two siblings
  # loop-guard/dad-guard-stop need (dad-loopguard.ps1, dad-guard.ps1), deliberately omitting close-
  # unit.ps1/ratchet.ps1 - so ratchet-close-refusal's own "sibling not found" SKIP (dad-gates-smoke.ps1:111)
  # is the ONLY gate that skips, while the other two still run for real and INTERCEPT.
  $sb = New-Sandbox
  $isolated = Join-Path $env:TEMP ("dadkit_gs_iso_" + [guid]::NewGuid().ToString("N").Substring(0,8))
  New-Item -ItemType Directory -Force $isolated | Out-Null
  try {
    Copy-Item (Join-Path $kit "dad-gates-smoke.ps1") $isolated
    Copy-Item (Join-Path $kit "dad-loopguard.ps1") $isolated
    Copy-Item (Join-Path $kit "dad-guard.ps1") $isolated

    $gs = Join-Path $isolated "dad-gates-smoke.ps1"
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $gs -ProjectDir $sb 2>&1 | Out-String)
    $exit = $LASTEXITCODE

    Assert ($out -match [regex]::Escape("[gates-smoke] ratchet-close-refusal: SKIP")) "the per-gate sibling-missing SKIP did not fire for ratchet-close-refusal:`n$out"
    Assert ($out -match 'close-unit\.ps1 / ratchet\.ps1 not found') "the SKIP reason text did not match the sibling-missing message:`n$out"
    Assert ($out -match [regex]::Escape("[gates-smoke] loop-guard: INTERCEPTED")) "loop-guard should still run for real when its own sibling is present:`n$out"
    Assert ($out -match [regex]::Escape("[gates-smoke] dad-guard-stop: INTERCEPTED")) "dad-guard-stop should still run for real when its own sibling is present:`n$out"
    Assert ($out -notmatch 'SILENT-FAIL') "no gate should silently fail in this scenario:`n$out"
    Assert ($exit -eq 0) "one genuine per-gate SKIP alongside two real INTERCEPTED gates is not all-skipped and has zero silent-fails, so it should still exit 0:`n$out"
  } finally {
    Remove-Sandbox $sb
    Remove-Item -LiteralPath $isolated -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Test-Case "grade-trends reads the STATED grade, not a capital letter in prose" {
  # First version scanned for \b[A-F]\b, so "A worked example was missing" scored a D card as an A - and
  # it flipped the reported direction on a real project. A retro built on mis-parsed grades is exactly the
  # confident nonsense this kit exists to prevent, so the parse is pinned.
  $sb = New-Sandbox
  try {
    $g = Join-Path $sb "grades"; New-Item -ItemType Directory -Force $g | Out-Null
    @("# T1 grade","","**Current grade: D** (as of 2026-08-01, iteration 2)","",
      "## Grade history","| Iter | Date | Grade | Delta |","|---|---|---|---|",
      "| 1 | 2026-07-30 | F | initial |","| 2 | 2026-08-01 | D | fixed |","",
      "## Assessment","A worked example was missing. B and C paths untested.",
      ("x" * 900)) | Set-Content "$g\T1_GRADE.md" -Encoding UTF8
    # graded EARLIER but sorts LATER by name - proves ordering is chronological, not alphabetical
    @("# A9 grade","","**Current grade: F** (as of 2026-07-01, iteration 1)","",
      "## Grade history","| Iter | Date | Grade | Delta |","|---|---|---|---|",
      "| 1 | 2026-07-01 | F | initial |","",("x" * 900)) | Set-Content "$g\A9_GRADE.md" -Encoding UTF8

    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "grade-trends.ps1") `
              -ProjectDir $sb 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 0) "grade-trends exited $LASTEXITCODE"
    Assert ($out -match 'T1=D') "it did not read the stated grade (prose 'A worked example' must not win):`n$out"
    Assert ($out -notmatch 'T1=A') "prose letters are still being scored as grades"
    Assert ($out -match 'T1 x2') "it did not count the two grading rounds"
    # chronological: A9 (July 1) must print before T1 (Aug 1) despite sorting later by name
    Assert ($out -match 'A9=F\s+T1=D') "cards are not ordered by when they were graded:`n$out"

    $j = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "grade-trends.ps1") `
            -ProjectDir $sb -Json 2>&1 | Out-String) | ConvertFrom-Json
    Assert ($j.cards -eq 2) "JSON card count wrong"
    Assert (($j.needingRework -join ' ') -match 'T1 x2') "JSON did not report the rework"

    # an empty project must not fail - a retro before any grading is legitimate
    $sb2 = New-Sandbox
    try {
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "grade-trends.ps1") -ProjectDir $sb2 | Out-Null
      Assert ($LASTEXITCODE -eq 0) "it failed a project with no grades folder"
    } finally { Remove-Sandbox $sb2 }

    $r = Get-Content (Join-Path $kit "global\commands\retro.md") -Raw
    Assert ($r -match 'grade-trends\.ps1') "/retro does not run the trend script"
    Assert ($r -match 'WAIT for my approval') "/retro applies changes without approval"
    Assert ($r -match 'more than three changes') "/retro has no cap on proposals"
    Assert ($r -match 'escalate it as a gate|change to the KIT') "/retro never escalates a defect prose cannot fix"
  } finally { Remove-Sandbox $sb }
}

Test-Case "UI work is gated on behaviour and accessibility, not on looks" {
  $u = Get-Content (Join-Path $kit "global\agents\ui-agent.md") -Raw
  Assert ($u -match 'no exit code for taste') "ui-agent does not acknowledge the missing gate"
  Assert ($u -match '(?i)accessibilit') "ui-agent has no accessibility gate"
  Assert ($u -match 'Renders without crashing.*not a test|not a test') "ui-agent accepts render-only tests"
  Assert ($u -match '360px') "ui-agent does not check the narrow viewport"
  Assert ($u -match 'Never claim a visual surface is "done"') "ui-agent may still declare visual work good"
  $b = Get-Content (Join-Path $kit "global\commands\build.md") -Raw
  Assert ($b -match 'ui-agent') "/build never routes a visible unit to ui-agent"
  $p = Get-Content (Join-Path $kit "templates\web\PROFILE.md") -Raw
  Assert ($p -match '## Build / test') "the web profile has no build/test block for close-unit to read"
  Assert ($p -match 'pa11y|axe') "the web profile pins no a11y command"
  Assert ($p -notmatch '(?m)^\s*-\s*(React|Vite)\s+\d+\.') "the web profile pins a version number"
}

Test-Case "brownfield /document describes, and cites, rather than inventing" {
  $d = Get-Content (Join-Path $kit "global\commands\document.md") -Raw
  Assert ($d -match '(?i)(api-surface\.ps1|dad api-surface)') "/document does not use the real API surface"
  Assert ($d -match 'DESCRIBE, never invent') "/document does not forbid invention"
  Assert ($d -match '\(inferred\)') "/document does not mark inference"
  Assert ($d -match 'WORK REMAINING') "/document may write stories for already-done work"
  Assert ($d -match 'Count the tests|count the tests') "/document assumes coverage from a csproj"
  $s = Get-Content (Join-Path $kit "global\agents\survey-agent.md") -Raw
  Assert ($s -match 'ONE AREA PER INVOCATION') "survey-agent may batch the whole solution"
  Assert ($s -match 'cannot determine') "survey-agent has no way to report uncertainty"
  Assert ($s -match 'Never edit anything') "survey-agent is not read-only"
  Assert ($s -match 'cannot LOCATE') "survey-agent may assert absence"
  Assert ($s -notmatch 'tools:.*Write') "survey-agent has write tools - it must be read-only"
}

Test-Case "state findings are GENERATED, not authored by the librarian" {
  # An /audit on a healthy project reported "DESIGN.md Status: LOCKED header missing" (line 5), "S2-S6
  # missing <!-- Status --> markers" (all 14 had them) and "TASKS.md has 0 tasks with [x]" (10 ticked) -
  # immediately after running doc-stats, which had printed the real numbers. Acting on those would have
  # rewritten a correct header and re-ticked ticked tasks. So this whole category is computed now.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs","$p\grades" | Out-Null
    "# Design`n`nStatus: LOCKED`n`n## Contracts`n`n### C1: Thing`n- **Decision:** x" |
      Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    # S1 fully ticked but not DONE; S2 DONE and consistent; S3 marker uses a word that is not in the set
    @("# Stories","",
      "### Story S1: One   (Epic E1) <!-- Status: TODO -->","",
      "### Story S2: Two   (Epic E1) <!-- Status: DONE -->","",
      "### Story S3: Three (Epic E1) <!-- Status: COMPLETE -->","",
      "### Story S4: Four  (Epic E1)","",
      "### Story S5: Five  (Epic E1) <!-- Status: IN-PROGRESS -->","",
      "### Story S6: Six   (Epic E1) <!-- Status: DONE closed:close-unit -->","") | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    @("# Task map","","## Tasks","",
      "### [x] T1.1 - a   (Story S1)","- **Goal:** x","",
      "### [x] T2.1 - b   (Story S2)","- **Goal:** y","",
      "### [ ] T3.1 - c   (Story S3)","- **Goal:** z","") | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    # S2 is DONE and has a real card; T1.1/T2.1 do not
    ("x" * 900 + "`n## Grade history`n| when | grade |`n") | Set-Content "$p\grades\S2_GRADE.md" -Encoding UTF8

    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") `
              -ProjectDir $p -Findings 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 0) "-Findings exited $LASTEXITCODE"

    # the FACTS line must carry the real numbers, so the librarian cannot invent different ones
    Assert ($out -match 'Status LOCKED') "STATE FACTS did not report the real design status"
    Assert ($out -match 'tasks 2/3') "STATE FACTS did not report the real task counts:`n$out"

    # and it must NOT manufacture the findings that run fabricated
    Assert ($out -notmatch 'Status: LOCKED header missing') "it invented a missing Status header"
    Assert ($out -notmatch '0 tasks') "it claimed zero ticked tasks"
    Assert ($out -notmatch 'story S2 has no <!-- Status') "it flagged a story whose marker is present"

    # real problems, found deterministically
    Assert ($out -match 'story S4 has no <!-- Status') "a genuinely unmarked story was missed"
    Assert ($out -match "S3 Status marker is 'COMPLETE'") "a non-vocabulary marker was missed"
    Assert ($out -notmatch "S5 Status marker") "IN-PROGRESS must be accepted as a synonym for DOING, not flagged as bad"
    Assert ($out -notmatch "S6 Status marker") "close-unit's own 'DONE closed:close-unit' stamp (hyphenated) was wrongly flagged as a bad vocabulary marker"
    Assert ($out -match 'story S1 has all 1 task\(s\) \[x\] but is not marked DONE') "a roll-up gap was missed"
    # Grading is per STORY - /build:2 "grade + hygiene per story", /build:98 "grade the completed STORY",
    # DESIGN R18, and close-unit only asking under -RequireGrade on a story close. This assertion used to
    # demand `[grade] T1.1`, i.e. a card per TASK, which locked in a contradiction: on any project with a
    # task map it produced an unresolvable finding for every closed task, and unresolvable findings are how
    # a model learns to skip the list. S2 is DONE and has a real card, so nothing should be demanded here.
    Assert ($out -notmatch '\[grade\] T1\.1') "a closed TASK was reported as missing a grade card"
    Assert ($out -notmatch '\[grade\] T2\.1') "a closed TASK was reported as missing a grade card"
    Assert ($out -notmatch '\[grade\] S2') "it demanded a card that exists"

    # the loop and the agent must both be held to it
    $a = Get-Content (Join-Path $kit "global\commands\audit.md") -Raw
    Assert ($a -match '-Findings') "/audit does not generate the state findings"
    Assert ($a -match 'may not be\s*\r?\n?contradicted|not be contradicted') "/audit does not pass the facts as ground truth"
    Assert ($a -match '-Contract <Cn>') "/audit does not verify a claimed-missing contract"
    $l = Get-Content (Join-Path $kit "global\agents\librarian-agent.md") -Raw
    Assert ($l -match 'STATE FACTS') "librarian is not given ground truth"
    Assert ($l -match 'GENERATED, DO NOT REPORT') "librarian may still author state findings"
    Assert ($l -match 'cannot LOCATE') "librarian may still assert absence"
  } finally { Remove-Sandbox $sb }
}

Test-Case "a claimed-missing contract is settled by grep, not by the model" {
  # A run halted on "the contracts C6 and C7 are not present in DESIGN.md - a critical gap preventing
  # implementation". Both were pinned, at lines 299 and 334, and it had also invented the CONTENTS of C5
  # (quoting an "Azure Storage Adapters" section that existed nowhere in the project). It then did nothing
  # for the rest of the session. Whether a heading exists is a grep; it must never be a judgement call.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    @(
      "# Design", "", "Status: LOCKED", "",
      "## Contracts", "",
      "### C1: Rendition identity", "- **Decision:** x", "",
      "### C6: Materialization policy", "- **Decision:** y", "",
      "### C10-b: Signing", "- **Decision:** z", ""
    ) | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    $ds = Join-Path $kit "doc-stats.ps1"

    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Contract C6 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 0) "a contract that EXISTS was reported missing"
    Assert ($out -match 'C6 EXISTS') "it did not say the contract exists"
    Assert ($out -match 'Materialization policy') "it did not quote the real heading"
    Assert ($out -match 'line 10') "it did not give the line number:`n$out"

    # a genuinely absent one must fail, and list what IS there so the gap is obvious
    $miss = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Contract C7 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 1) "an absent contract did not fail"
    Assert ($miss -match 'C7 is NOT in DESIGN\.md') "it did not name the missing contract"
    Assert ($miss -match 'C1' -and $miss -match 'C6') "it did not list the contracts that DO exist"

    # suffixed ids (C10-b) are real in practice and must resolve
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Contract "C10-b" | Out-Null
    Assert ($LASTEXITCODE -eq 0) "a suffixed contract id (C10-b) did not resolve"

    # and the whole list on demand
    $all = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Contract "*" 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 0) "listing all contracts failed"
    Assert ($all -match '3 contract\(s\)') "wrong contract count:`n$all"

    # the loop has to USE it rather than trust the claim
    $b = Get-Content (Join-Path $kit "global\commands\build.md") -Raw
    Assert ($b -match '-Contract <Cn>') "/build does not verify a needs-contract claim"
    Assert ($b -match 'Exit 0 means the contract EXISTS') "/build does not say what a passing check means"
    $d = Get-Content (Join-Path $kit "global\agents\dev-agent.md") -Raw
    Assert ($d -match 'cannot LOCATE contract') "dev-agent may still assert a contract is absent"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the corpus spans MULTIPLE roots (and does not double-count)" {
  # A research corpus can be large or shared between projects, so LOCALTOOLS_DOCS_DIR takes a ';'-separated
  # list. The first root stays primary - it owns .index\ - and one index covers them all.
  if ($SkipBuild) { return }
  $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
  if (-not (Test-Path $exe)) { return }
  $sb = New-Sandbox
  try {
    $a = Join-Path $sb "projdocs"; $b = Join-Path $sb "shared"
    New-Item -ItemType Directory -Force $a, $b, (Join-Path $a "sources") | Out-Null
    "# design" | Set-Content "$a\DESIGN.md" -Encoding UTF8
    "# captured" | Set-Content "$a\sources\S001-thing.md" -Encoding UTF8
    "# elsewhere" | Set-Content "$b\finding.md" -Encoding UTF8

    $two = (& $exe --corpus "$a;$b" | Out-String)
    Assert ($two -match '2 root\(s\), 3 indexable file\(s\)') "two roots did not yield 3 files:`n$two"
    Assert ($two -match 'S001-thing\.md') "docs\sources\ content was not indexed"
    # tail, not full path: $env:TEMP resolves to an 8.3 short name in some shells and a long one in others
    Assert ($two -match 'projdocs\\\.index\\chunks\.json') "the index did not stay on the PRIMARY root:`n$two"

    # a root nested inside another must not be walked twice
    $nested = (& $exe --corpus "$sb;$a;$b" | Out-String)
    Assert ($nested -match '1 root\(s\), 3 indexable file\(s\)') "nested roots double-counted:`n$nested"

    # a missing root degrades the corpus, it does not break the server
    $missing = (& $exe --corpus "$a;Q:\not\here;$b" | Out-String)
    Assert ($missing -match 'MISSING - skipped') "a missing root was not reported"
    Assert ($missing -match '3 indexable file\(s\)') "a missing root cost us the real files:`n$missing"
  } finally { Remove-Sandbox $sb }
}

Test-Case "publish-run secret-scans, records provenance, commits locally, never pushes" {
  # The proving-ground artifact: a session transcript + a COMPUTED state snapshot copied into a repo's
  # runs/, so "runs as they happen" is a real git trail. The gate that matters: a transcript is exactly
  # where a pasted key ends up, so it is secret-scanned BEFORE anything is copied, and a hit aborts with
  # nothing written. It commits locally but NEVER pushes - publishing to a remote stays the human's call.
  $pr = Join-Path $kit "publish-run.ps1"
  Assert (Test-Path $pr) "publish-run.ps1 is missing"
  Assert (Test-Path (Join-Path $kit "publish-run.cmd")) "publish-run.cmd wrapper is missing"
  $src = Get-Content $pr -Raw
  Assert ($src -notmatch 'git\s+push') "publish-run contains a git push - it must never push"
  Assert ($src -match 'scan-secrets') "publish-run does not secret-scan the transcript"

  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Design`n`nStatus: LOCKED" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    "# Tasks`n`n## Tasks`n`n### [x] T1.1 - a   (Story S1)`n- **Goal:** x" | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    # missing transcript -> usage error
    & powershell -NoProfile -ExecutionPolicy Bypass -File $pr -Transcript (Join-Path $sb "nope.txt") -ProjectDir $p 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 2) "a missing transcript was not rejected"

    # a SECRET in the transcript -> abort, publish NOTHING. Build the key by CONCATENATION so this suite
    # file never itself holds a credential-shaped literal (that would trip the "kit is clean" test - which
    # is exactly what caught the first version of this test).
    $bad = Join-Path $sb "bad.txt"
    $fakeKey = "aws_access_key_id = A" + "KIA" + "IOSFODNN7" + "ABCDEFG"
    "log line`n$fakeKey`nmore" | Set-Content $bad -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $pr -Transcript $bad -ProjectDir $p 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 1) "a transcript with a secret was not blocked"
    Assert (-not (Test-Path (Join-Path $p "runs"))) "a blocked publish still created runs/ - it must write nothing"

    # a non-git runs repo -> refuse (the proof IS the commit)
    $bare = Join-Path $sb "notrepo"; New-Item -ItemType Directory -Force $bare | Out-Null
    $good = Join-Path $sb "good.txt"; "/build`nT1.1 closed, tests green." | Set-Content $good -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $pr -Transcript $good -ProjectDir $p -RunsRepo $bare 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 2) "publishing into a non-git folder was allowed"

    # clean transcript -> publish + local commit
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $pr -Transcript $good -ProjectDir $p -Label s1 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0) "a clean publish failed: $out"
    $runDir = Get-ChildItem (Join-Path $p "runs") -Directory | Select-Object -First 1
    Assert ($null -ne $runDir) "nothing was published"
    Assert (Test-Path (Join-Path $runDir.FullName "transcript.txt")) "the transcript was not copied"
    Assert (Test-Path (Join-Path $runDir.FullName "meta.txt")) "no provenance meta.txt was written"
    $meta = Get-Content (Join-Path $runDir.FullName "meta.txt") -Raw
    Assert ($meta -match 'kit version:') "meta.txt does not record the kit version"
    Assert (Test-Path (Join-Path $p "runs\INDEX.md")) "no runs/INDEX.md index"
    # it committed locally
    Push-Location $p; $log = (git log --oneline | Out-String); Pop-Location
    Assert ($log -match 'run:') "the run was not committed locally"
  } finally { Remove-Sandbox $sb }
}

Test-Case "a visible surface passes through ux-agent -> ui-agent, and close-unit records it (-UxReviewed)" {
  # cms3: ui-agent was routed 0 times in 39 dev spawns, so no design pass ever happened - the routing is
  # prose, and prose routing is what this kit stops trusting. ux-agent is the build-time reviewer (it
  # suggests; ui-agent applies), and the backstop is a commit trailer: close-unit stamps "UX-reviewed:" only
  # when -UxReviewed is passed, and doc-stats flags a project that has visible surfaces but no such commit -
  # the same shape as the "closed:close-unit" story stamp.

  # ux-agent is a REVIEWER, not an editor, and it hands taste to the human
  $ux = Join-Path $kit "global\agents\ux-agent.md"
  Assert (Test-Path $ux) "ux-agent.md is missing"
  $uxText = Get-Content $ux -Raw
  Assert ($uxText -match '(?m)^name:\s*ux-agent\s*$') "ux-agent frontmatter name is not ux-agent"
  $toolsLine = ([regex]::Match($uxText, '(?m)^tools:\s*(.+)$')).Groups[1].Value
  Assert ($toolsLine -notmatch '\bWrite\b' -and $toolsLine -notmatch '\bEdit\b') "ux-agent must not have Write/Edit - it suggests, ui-agent implements"
  Assert ($uxText -match '(?i)aesthetic|no exit code for taste') "ux-agent must hand aesthetic judgement to the human"

  # /build routes the pass and keeps it OUT of the design docs (the code is the record)
  $build = Get-Content (Join-Path $kit "global\commands\build.md") -Raw
  Assert ($build -match '(?i)ux-agent') "/build does not route ux-agent"
  Assert ($build -match '-UxReviewed') "/build does not tell close-unit to record the UX pass"
  Assert ($build -match '(?i)nothing is written into DESIGN') "/build must say the UX pass is NOT baked into the design docs"

  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "web"; New-Item -ItemType Directory -Force "$p\docs","$p\src\Pages" | Out-Null
    "# Design`n`nStatus: LOCKED`n`n## Contracts`n### C1 - pages`nhome + about + contact" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    "# Stories`n`n### Story S1: pages   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    ("# Tasks`n`n## Build order`n`n" +
     "### [ ] T1.1 - home   (Story S1)`n- **Goal:** landing`n`n" +
     "### [ ] T1.2 - about  (Story S1)`n- **Goal:** about`n`n" +
     "### [ ] T1.3 - contact (Story S1)`n- **Goal:** contact") | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "<h1>Home</h1>" | Set-Content "$p\src\Pages\Home.cshtml" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m "scaffold"
    $ErrorActionPreference = $prev; Pop-Location

    # a project WITH a visible surface but NO recorded review -> doc-stats flags [ux]
    $find1 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($find1 -match '\[ux\]') "doc-stats did not flag a visible-surface project with no recorded UX review"

    # close T1.1 WITHOUT -UxReviewed while a .cshtml is staged -> in-loop WARN (still closes)
    "<h1>About</h1>" | Set-Content "$p\src\Pages\About.cshtml" -Encoding UTF8
    $c1 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "close-unit.ps1") -ProjectDir $p -Id T1.1 -Title "home" -NoReindex 2>&1 | Out-String
    Assert ($c1 -match '(?i)visible surface changed') "close-unit did not WARN on a surface change with no UX pass"

    # close T1.2 WITH -UxReviewed -> the commit body carries the trailer, and no WARN
    "<h1>Contact</h1>" | Set-Content "$p\src\Pages\Contact.cshtml" -Encoding UTF8
    $c2 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "close-unit.ps1") -ProjectDir $p -Id T1.2 -Title "about" -UxReviewed -UxNote "nav" -NoReindex 2>&1 | Out-String
    Assert ($c2 -notmatch '(?i)visible surface changed') "close-unit WARNed even though -UxReviewed was passed"
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $bodies = (git log --format=%B | Out-String)
    $ErrorActionPreference = $prev; Pop-Location
    Assert ($bodies -match '(?im)^\s*UX-reviewed:\s*nav') "close-unit -UxReviewed did not stamp 'UX-reviewed:' into the commit body"

    # now that a commit records a review -> doc-stats is quiet on [ux]
    $find2 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($find2 -notmatch '\[ux\]') "doc-stats still flags [ux] after a commit recorded the review"
  } finally { Remove-Sandbox $sb }
}

Test-Case "an experience unit is playtested (playtest-agent -> human), and close-unit records it (-Playtested)" {
  # A game/sim is mostly FEEL, which no test can score. The kit routed feel to the human in prose ("hand me a
  # checklist") and it got skipped. playtest-agent structures the human playtest - it cannot score fun - and
  # close-unit stamps "Playtested:" so an experience cannot claim done with no one having played it. The
  # backstop mirrors -UxReviewed, gated on the design doc being TEDD.md.

  # playtest-agent is a protocol-maker, not an editor, and it hands FEEL to the human
  $pa = Join-Path $kit "global\agents\playtest-agent.md"
  Assert (Test-Path $pa) "playtest-agent.md is missing"
  $paText = Get-Content $pa -Raw
  Assert ($paText -match '(?m)^name:\s*playtest-agent\s*$') "playtest-agent frontmatter name is wrong"
  $ptTools = ([regex]::Match($paText, '(?m)^tools:\s*(.+)$')).Groups[1].Value
  Assert ($ptTools -notmatch '\bWrite\b' -and $ptTools -notmatch '\bEdit\b') "playtest-agent must not have Write/Edit - it structures the test, dev-agent implements"
  Assert ($paText -match '(?i)cannot score fun|no exit code for feel') "playtest-agent must hand the feel/fun verdict to the human"

  # /build routes it for experiences and records via -Playtested
  $build = Get-Content (Join-Path $kit "global\commands\build.md") -Raw
  Assert ($build -match '(?i)playtest-agent') "/build does not route playtest-agent"
  Assert ($build -match '-Playtested') "/build does not tell close-unit to record the playtest"

  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "game"; New-Item -ItemType Directory -Force "$p\docs","$p\src" | Out-Null
    "# TEDD`n`nStatus: LOCKED`nSecurity review: NOT-REQUIRED (local game, no network)`n`n## Experience vision`nfast, punchy arcade feel`n`n## Contracts`n### C1 - score`npoints" | Set-Content "$p\docs\TEDD.md" -Encoding UTF8
    "# Stories`n`n### Story S1: play   <!-- Status: DOING -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    ("# Tasks`n`n## Build order`n`n" +
     "### [ ] T1.1 - player   (Story S1)`n- **Goal:** move`n`n" +
     "### [ ] T1.2 - enemy    (Story S1)`n- **Goal:** chase`n`n" +
     "### [ ] T1.3 - score    (Story S1)`n- **Goal:** points") | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "public class Player {}" | Set-Content "$p\src\Player.cs" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m "scaffold"
    $ErrorActionPreference = $prev; Pop-Location

    # an experience with code but NO recorded playtest -> doc-stats flags [playtest]
    $find1 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($find1 -match '\[playtest\]') "doc-stats did not flag an experience with no recorded playtest"

    # close T1.1 WITHOUT -Playtested while gameplay code is staged -> in-loop WARN (still closes)
    "public class Enemy {}" | Set-Content "$p\src\Enemy.cs" -Encoding UTF8
    $c1 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "close-unit.ps1") -ProjectDir $p -Id T1.1 -Title "player" -NoReindex 2>&1 | Out-String
    Assert ($c1 -match '(?i)experience code changed') "close-unit did not WARN on experience code with no playtest"

    # close T1.2 WITH -Playtested -> the commit body carries the trailer, and no WARN
    "public class Score {}" | Set-Content "$p\src\Score.cs" -Encoding UTF8
    $c2 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "close-unit.ps1") -ProjectDir $p -Id T1.2 -Title "enemy" -Playtested -PlaytestNote "core loop" -NoReindex 2>&1 | Out-String
    Assert ($c2 -notmatch '(?i)experience code changed') "close-unit WARNed even though -Playtested was passed"
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $bodies = (git log --format=%B | Out-String)
    $ErrorActionPreference = $prev; Pop-Location
    Assert ($bodies -match '(?im)^\s*Playtested:\s*core loop') "close-unit -Playtested did not stamp 'Playtested:' into the commit body"

    # now that a commit records a playtest -> doc-stats is quiet on [playtest]
    $find2 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($find2 -notmatch '\[playtest\]') "doc-stats still flags [playtest] after a commit recorded the playtest"
  } finally { Remove-Sandbox $sb }
}

Test-Case "STYLE.md is the visual contract: scaffolded, wired, and doc-stats flags CSS off the palette" {
  # cms3 shipped a UI with no design TARGET - Tailwind named in CLAUDE.md, hand-rolled ad-hoc CSS in the
  # build, a nav linking to nothing. STYLE.md pins the LOOK (palette/type/tone/branding), human-owned;
  # ux-agent reviews against it and doc-stats reads the palette hexes and WARNs when the CSS drifts off them.

  # scaffolded by new-project
  $sbA = New-Sandbox
  try {
    $pj = Join-Path $sbA "np"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "new-project.ps1") general $pj 2>&1 | Out-Null
    Assert (Test-Path (Join-Path $pj "docs\STYLE.md")) "scaffold did not create docs\STYLE.md"
    Assert (Test-Path (Join-Path $pj "docs\UI-TOOLING.md")) "scaffold did not create docs\UI-TOOLING.md"
  } finally { Remove-Sandbox $sbA }

  # wired: /design fills it, taskmap tags [ui] + emits nav + cites it, ux-agent reviews against it
  Assert ((Get-Content (Join-Path $kit "global\commands\design.md") -Raw) -match 'STYLE\.md') "/design does not set up docs/STYLE.md"
  $tm = Get-Content (Join-Path $kit "global\commands\taskmap.md") -Raw
  Assert ($tm -match '\[ui\]' -and $tm -match 'STYLE\.md') "/taskmap does not tag [ui] tasks or cite STYLE.md"
  Assert ($tm -match '(?i)navigation') "/taskmap does not tell it to emit the navigation/shell task"
  $ux = Get-Content (Join-Path $kit "global\agents\ux-agent.md") -Raw
  Assert ($ux -match 'STYLE\.md') "ux-agent does not review against STYLE.md"
  # the offline see->adjust loop: ux-agent reviews the RENDERED screenshot (a picture beats prose), and the
  # STYLE template carries reference images - this is what would have caught cms3's unstyled-render failure.
  Assert ($ux -match '(?i)describe_image' -and $ux -match '(?i)screenshot') "ux-agent does not make the rendered screenshot a first-class review input"
  Assert ((Get-Content (Join-Path $kit "global\commands\build.md") -Raw) -match '(?i)screenshot') "/build [ui] step does not capture a screenshot for the UX review"
  Assert ((Get-Content (Join-Path $kit "templates\_common\docs\STYLE.md") -Raw) -match '(?m)^## Reference') "STYLE.md template has no ## Reference section for reference images"
  $uiDoc = Get-Content (Join-Path $kit "templates\_common\docs\UI-TOOLING.md") -Raw
  Assert ($uiDoc -match 'superdesign' -and $uiDoc -match 'shadcn' -and $uiDoc -match '(?i)installs NONE') "UI-TOOLING.md is missing the verified tools or the 'kit installs none' framing"

  # doc-stats [style]: filled palette + off-palette CSS -> WARN; on-palette -> quiet; unfilled -> quiet
  $sbB = New-Sandbox
  try {
    $p = Join-Path $sbB "web"; New-Item -ItemType Directory -Force "$p\docs","$p\src\css" | Out-Null
    "# Design`n`nStatus: LOCKED`n`n## Contracts`n### C1`nx" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    "# Stories`n`n### Story S1: one   <!-- Status: DOING -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    "# Tasks`n`n## Build order`n`n### [ ] T1.1 - a [ui]   (Story S1)`n- **Goal:** x" | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "# Style`n`n## Palette`n| Token | Hex | Use |`n|---|---|---|`n| bg | #2b2b2b | background |`n| text | #e8e0d0 | text |`n| primary | #7a8450 | actions |" | Set-Content "$p\docs\STYLE.md" -Encoding UTF8

    ".a{color:#ff0000}.b{background:#00ff00}.c{border-color:#0000ff}.d{color:#123456}" | Set-Content "$p\src\css\site.css" -Encoding UTF8
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out -match '\[style\]') "doc-stats did not flag CSS that drifts off the STYLE.md palette"

    ".a{color:#e8e0d0;background:#2b2b2b}.b{color:#7a8450}" | Set-Content "$p\src\css\site.css" -Encoding UTF8
    $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out2 -notmatch '\[style\]') "doc-stats flagged [style] even though the CSS uses only palette colors"

    # the shipped template palette is UNFILLED (<hex> placeholders) - it must NOT produce a false finding
    Copy-Item (Join-Path $kit "templates\_common\docs\STYLE.md") "$p\docs\STYLE.md" -Force
    ".a{color:#ff0000}.b{background:#00ff00}.c{border-color:#0000ff}.d{color:#123456}" | Set-Content "$p\src\css\site.css" -Encoding UTF8
    $out3 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out3 -notmatch '\[style\]') "doc-stats flagged [style] on an UNFILLED palette template"
  } finally { Remove-Sandbox $sbB }
}

Test-Case "the stop guard AUDITS -Ack and escalates on a frozen HEAD; doc-stats consolidates the gap as [integrity]" {
  # The measured ceiling: a run did all work inline, hand-ticked the tasks, -Ack'd dad-guard TWICE, and ended
  # with HEAD never moving - nothing committed. A Stop hook cannot stop a shell command (fail-open is the
  # design), so the override is now AUDITED + ESCALATING, and the hand-tick gap is one loud [integrity]
  # finding (with the frozen HEAD + the -Ack count) instead of 36 [dev] lines that read like a to-do list.
  if (-not $haveGit) { return }
  $guard = Join-Path $kit "dad-guard.ps1"
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs","$p\src" | Out-Null
    "# Design`n`nStatus: LOCKED`n`n## Contracts`n### C1`nx" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    "# Stories`n`n### Story S1: one   <!-- Status: DOING -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    $tl = @("# Tasks","","## Build order","")
    1..6 | ForEach-Object { $tl += "### [x] T1.$_ - task $_   (Story S1)"; $tl += "- **Goal:** x"; $tl += "" }
    $tl | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "class A {}" | Set-Content "$p\src\a.cs" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m "scaffold - no task ids here"
    $ErrorActionPreference = $prev; Pop-Location

    # 6 ticked-but-uncommitted units -> ONE [integrity] line, not 6 [dev] lines
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out -match '\[integrity\]') "doc-stats did not consolidate the hand-tick gap into an [integrity] finding"
    Assert ((@($out -split "`n" | Where-Object { $_ -match '\[dev\]\s*T1\.' })).Count -eq 0) "doc-stats still emitted per-task [dev] spam instead of the [integrity] headline"
    # the STATE FACTS line must QUALIFY the [x] count, not present the fabricated total as a bare fact - a
    # real audit read "tasks 44/44 [x]" as "44 verified" while [integrity] said 32 were hand-ticked lies.
    Assert ($out -match '(?i)\bUNVERIFIED\b') "STATE FACTS did not qualify the hand-ticked task count as UNVERIFIED"
    Assert ($out -notmatch '(?m)tasks 6/6 \[x\] \| next') "STATE FACTS still shows a bare '6/6 [x]' next to 6 uncommitted tasks"

    # -Ack records the override; a repeat ack with HEAD unchanged ESCALATES
    & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Ack -Reason "spike" -ProjectDir $p | Out-Null
    Assert (Test-Path "$p\.claude\.dad-ack-log") "-Ack did not record the override to .claude\.dad-ack-log"
    $ack2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $guard -Ack -ProjectDir $p 2>&1 | Out-String
    Assert ($ack2 -match '(?i)fabrication pattern|ack #2') "a repeat -Ack with a frozen HEAD did not escalate"

    # and [integrity] now surfaces the override count
    $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out2 -match '(?i)overridden \(-Ack\)') "[integrity] did not surface the -Ack override count"
  } finally { Remove-Sandbox $sb }
}

Test-Case "dad watch alarms when the session is BUSY but git HEAD is frozen (the run11 no-progress spiral)" {
  # run9 + run11 each churned ~24h editing constantly with HEAD frozen and 0 commits, until a timeout - and
  # the idle check (keyed on file SILENCE) can never see it. Run the watcher against a repo where the disk
  # stays busy but nothing commits, and assert the NO-PROGRESS alarm fires. Skips without git.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force $p | Out-Null
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    "x" | Set-Content "$p\a.txt"; git add -A; git -c user.name=t -c user.email=t@t commit -q -m init
    $ErrorActionPreference = $prev; Pop-Location

    # tiny no-progress threshold (~1.8s); never idle (IdleMinutes huge); we keep WRITING without committing
    $outFile = Join-Path $sb "watch.out"
    $proc = Start-Process powershell -PassThru -WindowStyle Hidden -RedirectStandardOutput $outFile -ArgumentList @(
      "-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $kit "dad-watch.ps1"),
      "-ProjectDir",$p,"-PollSeconds","1","-IdleMinutes","999","-NoProgressMinutes","0.03","-NoBeep")
    try {
      foreach ($i in 1..12) { Start-Sleep -Milliseconds 600; "tick $i" | Set-Content "$p\a.txt" }
      Start-Sleep -Seconds 1
    } finally {
      try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch { }
      Start-Sleep -Milliseconds 300
    }
    $out = if (Test-Path $outFile) { Get-Content $outFile -Raw } else { "" }
    Assert ($out -match '(?i)NO PROGRESS') "dad watch did not alarm on busy-but-HEAD-frozen (no-progress spiral)"
  } finally { Remove-Sandbox $sb }
}

Test-Case "dad env + dad corpus: create, list, SAFE-archive on remove, restore (knowledge corpora pilot)" {
  # Persistent, cited knowledge banks projects consult instead of re-researching. An environment is an
  # isolated tree; a corpus is a folder + CORPUS.md manifest under it. REMOVE must be SAFE (zip archive, not
  # a hard delete). Point the root at a sandbox so the real user profile is untouched.
  $sb = New-Sandbox
  $prevRoot = $env:DRDAD_ENV_ROOT
  try {
    $env:DRDAD_ENV_ROOT = Join-Path $sb "envs"
    $envPs = Join-Path $kit "env.ps1"; $corpusPs = Join-Path $kit "corpus.ps1"

    & powershell -NoProfile -ExecutionPolicy Bypass -File $envPs new dotnet-web -Quiet | Out-Null
    Assert (Test-Path (Join-Path $env:DRDAD_ENV_ROOT "dotnet-web\corpora")) "dad env new did not create the environment"
    $list = & powershell -NoProfile -ExecutionPolicy Bypass -File $envPs list 2>&1 | Out-String
    Assert ($list -match 'dotnet-web') "dad env list did not show the new environment"

    & powershell -NoProfile -ExecutionPolicy Bypass -File $corpusPs new security -Env dotnet-web -Quiet | Out-Null
    $cdir = Join-Path $env:DRDAD_ENV_ROOT "dotnet-web\corpora\security"
    Assert (Test-Path (Join-Path $cdir "CORPUS.md")) "dad corpus new did not scaffold CORPUS.md"
    Assert (Test-Path (Join-Path $cdir "sources")) "dad corpus new did not create sources\"

    # dad corpus check: a freshly-scaffolded corpus is the TEMPLATE (unfilled) -> [corpus] findings; a filled,
    # sourced, indexed one is clean. This is the honesty gate /corpus validates with before any dialogue.
    $chk = & powershell -NoProfile -ExecutionPolicy Bypass -File $corpusPs check security -Env dotnet-web 2>&1 | Out-String
    Assert ($chk -match '\[corpus\]') "dad corpus check did not flag the unfilled template"
    Assert ($chk -match "(?i)'## Goal' is unfilled") "dad corpus check did not flag the empty Goal"
    $filled = "# Corpus: security`r`n`r`n## Goal`r`nCurrent cited ASP.NET security practice.`r`n`r`n## Scope`r`n- In: web security`r`n- Out: native apps`r`n`r`n## Sources`r`n- https://learn.microsoft.com/aspnet - official docs`r`n`r`n## Build & refresh`r`n- Ingest monthly`r`n"
    [System.IO.File]::WriteAllText((Join-Path $cdir "CORPUS.md"), $filled, (New-Object System.Text.UTF8Encoding($false)))
    New-Item -ItemType Directory -Force (Join-Path $cdir ".index") | Out-Null
    $chk2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $corpusPs check security -Env dotnet-web 2>&1 | Out-String
    Assert ($chk2 -match '(?i)none - the corpus is filled') "dad corpus check flagged a filled, sourced, indexed corpus"

    # dad corpus refresh is a recognized action (reindex verb; the full grab-latest cycle is /corpus refresh).
    # On a missing corpus it reports 'no such corpus', NOT 'unknown action' - proving it is wired (no Ollama).
    $rf = & powershell -NoProfile -ExecutionPolicy Bypass -File $corpusPs refresh nope -Env dotnet-web 2>&1 | Out-String
    Assert ($rf -notmatch '(?i)unknown action') "dad corpus refresh is not a recognized action"

    # dad corpus ingest is a recognized action (corpus-scoped web fetch, the fix for ingest landing in a
    # project). On a missing corpus it says 'no such corpus', NOT 'unknown action' - proving it is wired.
    $ig = & powershell -NoProfile -ExecutionPolicy Bypass -File $corpusPs ingest nope "http://x.invalid/y" -Env dotnet-web 2>&1 | Out-String
    Assert ($ig -notmatch '(?i)unknown action') "dad corpus ingest is not a recognized action"

    # SAFE remove: archives to a dated zip, removes the live folder
    & powershell -NoProfile -ExecutionPolicy Bypass -File $corpusPs remove security -Env dotnet-web -Quiet | Out-Null
    Assert (-not (Test-Path $cdir)) "dad corpus remove did not remove the live folder"
    $zip = @(Get-ChildItem (Join-Path $env:DRDAD_ENV_ROOT "dotnet-web\corpora\_archive") -Filter "security_*.zip" -ErrorAction SilentlyContinue)
    Assert ($zip.Count -eq 1) "dad corpus remove did not archive to a dated zip (found $($zip.Count))"

    # restore brings it back from the zip
    & powershell -NoProfile -ExecutionPolicy Bypass -File $corpusPs restore $zip[0].FullName -Env dotnet-web -Quiet | Out-Null
    Assert (Test-Path (Join-Path $cdir "CORPUS.md")) "dad corpus restore did not bring the corpus back"

    # env remove is also safe-archive
    & powershell -NoProfile -ExecutionPolicy Bypass -File $envPs remove dotnet-web -Quiet | Out-Null
    Assert (-not (Test-Path (Join-Path $env:DRDAD_ENV_ROOT "dotnet-web"))) "dad env remove did not remove the live env"
    Assert (@(Get-ChildItem (Join-Path $env:DRDAD_ENV_ROOT "_archive") -Filter "dotnet-web_*.zip" -ErrorAction SilentlyContinue).Count -eq 1) "dad env remove did not archive the env"
  } finally {
    if ($null -ne $prevRoot) { $env:DRDAD_ENV_ROOT = $prevRoot } else { Remove-Item Env:\DRDAD_ENV_ROOT -ErrorAction SilentlyContinue }
    Remove-Sandbox $sb
  }
}

Test-Case "[domain] flags a pinned-but-unbuilt entity, honors the None escape, and stays silent when built" {
  # The structural gap behind "dev invents its own entity shape per story": the design pins the shared nouns
  # in ## Domain model, but nothing checked them against what got built. This COARSE check (entity-NAME
  # existence vs API-SURFACE) turns a pinned-but-unbuilt entity into an informative WARN that hands over the
  # pinned list to build toward - and stays silent when there is no model or no drift, so it never nags.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    $designWithModel = @(
      '# Design', '', 'Status: LOCKED', '', '## Contracts', '### C1: x', '- **Worked example:** x', '',
      '## Domain model', '### Page', '- **Fields:** Id: int, Slug: string', '### User', '- **Fields:** Id: int', '',
      '## Out of scope')
    Set-Content "$p\docs\DESIGN.md" -Encoding UTF8 $designWithModel
    Set-Content "$p\docs\STORIES.md" -Encoding UTF8 @('# Stories', '', '### Story S1: one   <!-- Status: DOING -->')
    Set-Content "$p\docs\TASKS.md" -Encoding UTF8 @('# Tasks', '', '## Build order', '', '### [ ] T1.1 - x   (Story S1)', '- **Goal:** x')
    # API-SURFACE has Page but NOT User -> User is pinned-but-unbuilt
    Set-Content "$p\docs\API-SURFACE.md" -Encoding UTF8 @('# API surface', '', '## This solution', '', '### App', '', '`class Page`', '  - `int Id`')
    $ds = Join-Path $kit "doc-stats.ps1"

    # 1) drift: User pinned but not built -> [domain] fires, NAMES User, and lists the pinned set as the target
    $flat = ((& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String) -replace '\s+',' ')
    Assert ($flat -match '\[domain\]') "doc-stats did not flag the pinned-but-unbuilt entity"
    Assert ($flat -match 'surface: User') "[domain] did not name the unbuilt entity (User)"
    Assert ($flat -match 'Pinned: Page, User') "[domain] did not list the pinned entities to build toward"

    # 2) 'None (no persisted domain).' suppresses it even though User is still unbuilt (the stateless escape)
    Set-Content "$p\docs\DESIGN.md" -Encoding UTF8 @(
      '# Design', '', 'Status: LOCKED', '', '## Contracts', '### C1: x', '- **Worked example:** x', '',
      '## Domain model', 'None (no persisted domain).', '', '## Out of scope')
    $none = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($none -notmatch '\[domain\]') "[domain] fired on a project that declared None (no persisted domain)"

    # 3) restore the model and build User too -> no drift -> silent (a finding on good input is noise)
    Set-Content "$p\docs\DESIGN.md" -Encoding UTF8 $designWithModel
    Add-Content "$p\docs\API-SURFACE.md" -Encoding UTF8 -Value '`class User`'
    $built = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($built -notmatch '\[domain\]') "[domain] still fired after every pinned entity was built"
  } finally { Remove-Sandbox $sb }
}

Test-Case "[research] flags an opinion-heavy or [research]-tagged task with no pinned Refs, silent when grounded" {
  # run9 measured the cost: a small model spiralled 26h reinventing antiforgery-in-tests that NO task pinned.
  # An opinion-heavy task (oauth/antiforgery/jwt/payments/migrations/identity) - or one tagged [research] -
  # must carry a `Refs:` line pointing at the contract/SOURCE/RECIPE that decides the how. doc-stats WARNs
  # when it does not, names those tasks, and stays silent for a plain task or once Refs is filled.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    Set-Content "$p\docs\DESIGN.md" -Encoding UTF8 @('# Design', '', 'Status: LOCKED', '', '## Contracts', '### C1: x', '- **Worked example:** x')
    Set-Content "$p\docs\STORIES.md" -Encoding UTF8 @('# Stories', '', '### Story S1: one   <!-- Status: DOING -->')
    Set-Content "$p\docs\TASKS.md" -Encoding UTF8 @(
      '# Tasks', '', '## Build order', '', '## Tasks', '',
      '### [ ] T1.1 - Home page list   (Story S1)', '- **Goal:** show pages', '',
      '### [ ] T1.2 - Antiforgery on admin forms   (Story S1)', '- **Goal:** protect POSTs', '',
      '### [ ] T1.3 - OAuth login [research]   (Story S1)', '- **Goal:** external sign-in')
    $ds = Join-Path $kit "doc-stats.ps1"

    # T1.2 (keyword) + T1.3 (tag) ungrounded; T1.1 plain must NOT flag
    $flat = ((& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String) -replace '\s+',' ')
    Assert ($flat -match '\[research\] 2 opinion-heavy') "[research] did not flag exactly the two ungrounded opinion-heavy tasks (T1.1 must be excluded)"
    Assert ($flat -match '\[research\][^\[]*T1\.2') "[research] did not name the antiforgery task (keyword match)"
    Assert ($flat -match '\[research\][^\[]*T1\.3') "[research] did not name the [research]-tagged OAuth task"

    # ground with a Refs line -> silent (a finding on grounded input is noise)
    Set-Content "$p\docs\TASKS.md" -Encoding UTF8 @(
      '# Tasks', '', '## Build order', '', '## Tasks', '',
      '### [ ] T1.2 - Antiforgery on admin forms   (Story S1)', '- **Goal:** protect POSTs', '- **Refs:** C1, R3', '')
    $flat2 = ((& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String) -replace '\s+',' ')
    Assert ($flat2 -notmatch '\[research\]') "[research] still fired after the opinion-heavy task was given a Refs line"
  } finally { Remove-Sandbox $sb }
}

Test-Case "doc-stats flags a default-scaffold entry point (the bare home page cms3 shipped)" {
  # The front door fell through every UI check: the home view was never a [ui] task, so ux-agent never looked,
  # and the nav-links check passed because links existed (just auth-gated). A stock-scaffold home is greppable.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "web"; New-Item -ItemType Directory -Force "$p\docs","$p\src\CMS\Views\Home" | Out-Null
    "# Design`n`nStatus: LOCKED`n`n## Contracts`n### C1`nx" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    "# Stories`n`n### Story S1: one   <!-- Status: DOING -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    "# Tasks`n`n## Build order`n`n### [ ] T1.1 - a   (Story S1)`n- **Goal:** x" | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    ('@{ ViewData["Title"] = "Home Page"; }' + "`n<h1>Welcome</h1>`n<p>Learn about building Web apps with ASP.NET Core.</p>") | Set-Content "$p\src\CMS\Views\Home\Index.cshtml" -Encoding UTF8

    $ds = Join-Path $kit "doc-stats.ps1"
    $flat = ((& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String) -replace '\s+',' ')
    Assert ($flat -match '(?i)\[ui\].*DEFAULT SCAFFOLD') "doc-stats did not flag the default-scaffold entry point"

    # a real home view -> silent
    ('@{ ViewData["Title"] = "Home"; }' + "`n<h1>My CMS</h1>`n<a asp-controller='Pages' asp-action='Index'>Browse pages</a>") | Set-Content "$p\src\CMS\Views\Home\Index.cshtml" -Encoding UTF8
    $flat2 = ((& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String) -replace '\s+',' ')
    Assert ($flat2 -notmatch '(?i)DEFAULT SCAFFOLD') "doc-stats flagged a real home view as scaffold"
  } finally { Remove-Sandbox $sb }
}

Test-Case "only close-unit may close a story: it stamps, a hand-tick is flagged, dad tidy cleans" {
  # Measured, cms3: 5/5 stories marked DONE with 21 tasks still open and 4 commits - the DONE markers were
  # written by hand, not by close-unit. Now close-unit stamps 'closed:close-unit' when it rolls a story up,
  # and doc-stats flags a DONE marker lacking that stamp UNLESS the story also looks genuinely closed (all
  # tasks [x] AND a commit mentions it) - so a legit legacy close stays silent, a fabricated one lights up.
  if (-not $haveGit) { return }

  # close-unit stamps the provenance token
  Assert ((Get-Content (Join-Path $kit "close-unit.ps1") -Raw) -match 'closed:close-unit') "close-unit does not stamp story-close provenance"

  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Design`n`nStatus: LOCKED`nSecurity review: NOT-REQUIRED (test)" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    # S1 hand-ticked DONE, tasks NOT all done, no commit  -> flagged
    # S2 hand-ticked DONE but all tasks [x] and a commit mentions it  -> legit-looking, NOT flagged
    "# Stories`n`n### Story S1: one   <!-- Status: DONE -->`n`n### Story S2: two   <!-- Status: DONE -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    "# Tasks`n`n## Tasks`n`n### [ ] T1.1 - a   (Story S1)`n- **Goal:** x`n`n### [x] T2.1 - b   (Story S2)`n- **Goal:** y" | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m "work on S2 done"
    $ErrorActionPreference = $prev; Pop-Location
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out -match '(?i)story S1 is marked DONE but has NO close-unit stamp') "a hand-ticked, incomplete DONE was not flagged"
    Assert ($out -notmatch '(?i)story S2 is marked DONE') "a story that looks genuinely closed (all tasks [x] + commit) was wrongly flagged"

    # dad tidy: lists junk by default, removes with -Fix, empties _tmp, preserves real files
    New-Item -ItemType Directory -Force "$p\_tmp","$p\src" | Out-Null
    "keep" | Set-Content "$p\src\Program.cs" -Encoding UTF8
    "x" | Set-Content "$p\IMPLEMENTATION_SUMMARY.md" -Encoding UTF8
    "x" | Set-Content "$p\build.binlog" -Encoding UTF8
    "scratch" | Set-Content "$p\_tmp\note.txt" -Encoding UTF8
    $tidy = Join-Path $kit "tidy.ps1"
    Assert (Test-Path $tidy) "tidy.ps1 is missing"
    $list = & powershell -NoProfile -ExecutionPolicy Bypass -File $tidy -ProjectDir $p 2>&1 | Out-String
    Assert ($list -match '(?i)WOULD remove') "tidy did not list junk in the default (no -Fix) mode"
    Assert (Test-Path "$p\IMPLEMENTATION_SUMMARY.md") "tidy removed a file WITHOUT -Fix - default must be safe"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $tidy -ProjectDir $p -Fix 2>&1 | Out-Null
    Assert (-not (Test-Path "$p\IMPLEMENTATION_SUMMARY.md")) "tidy -Fix did not remove the ad-hoc summary"
    Assert (-not (Test-Path "$p\build.binlog")) "tidy -Fix did not remove the binlog"
    Assert (@(Get-ChildItem "$p\_tmp" -Force).Count -eq 0) "tidy -Fix did not empty _tmp/"
    Assert (Test-Path "$p\src\Program.cs") "tidy -Fix removed real source - it must only touch junk"
    Assert (Test-Path "$p\docs\DESIGN.md") "tidy -Fix removed docs"
    # tidy refuses a non-project path (same guard as free-locks)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $tidy -ProjectDir $env:SystemRoot 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 2) "tidy operated on a system path - the guard failed"
  } finally { Remove-Sandbox $sb }

  # scaffold gitignores _tmp/ and *.binlog so scratch and build logs never get committed
  $sb2 = New-Sandbox
  try {
    $pj = Join-Path $sb2 "np"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "new-project.ps1") general $pj 2>&1 | Out-Null
    $gi = Get-Content (Join-Path $pj ".gitignore") -Raw
    Assert ($gi -match '(?m)^_tmp/') "scaffold does not gitignore _tmp/"
    Assert ($gi -match '(?m)^\*\.binlog') "scaffold does not gitignore *.binlog"
  } finally { Remove-Sandbox $sb2 }
}

Test-Case "doc-stats flags a hand-ticked task committed WITHOUT close-unit (doc-only commit, wrong shape)" {
  # A.3: haiku's real repo (ModelTest bake-off) never marked its story DONE (so the story hand-tick check
  # above never fires) and EVERY hand-ticked task WAS mentioned by some commit (so the "no commit mentions
  # it" [integrity] check stays silent too) - it just hand-committed docs\TASKS.md ALONE with messages like
  # "Mark T1.1 complete", a shape close-unit never writes and a file set close-unit never commits standalone.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    $before = "# Task map`n`n## Tasks`n`n### [ ] T1.1 - hand ticked   (Story S1)`n- **Goal:** x`n" +
              "### [ ] T2.1 - real close   (Story S2)`n- **Goal:** y`n### [ ] T2.2 - stays open   (Story S2)`n- **Goal:** z"
    $before | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->`n`n### Story S2: Two   <!-- Status: TODO -->" |
      Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    "# Project: t`n`n## Build / test`n- Build: ``exit 0``" | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base

    # hand-tick T1.1 directly (bypassing close-unit.ps1 entirely) and commit ONLY docs\TASKS.md
    ($before -replace '\[ \] T1\.1', '[x] T1.1') | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    git add docs\TASKS.md
    git -c user.name=t -c user.email=t@t commit -q -m "Mark T1.1 complete"
    $ErrorActionPreference = $prev; Pop-Location

    $ds = Join-Path $kit "doc-stats.ps1"
    $out1 = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out1 -match '(?i)\[integrity\].*DOC-ONLY commit close-unit never made') "the hand-committed, wrong-shape tick was not flagged"
    Assert ($out1 -match 'T1\.1') "the finding did not name T1.1"

    # T2.1 closes for real, through close-unit - same doc-only file set (no code files in this fixture),
    # but the RIGHT message shape ("T2.1: real close") must clear it
    $cu = Join-Path $kit "close-unit.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T2.1 -Title "real close" -ProjectDir $p -NoReindex | Out-Null
    Assert ($LASTEXITCODE -eq 0) "close-unit failed to close T2.1"

    $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out2 -notmatch "T2\.1 \(commit") "a real close-unit commit ('T2.1: real close') was wrongly flagged as hand-ticked"
    Assert ($out2 -match 'T1\.1') "the still-hand-ticked T1.1 finding disappeared after an unrelated close"

    # FALSE POSITIVE #1 (measured on this kit's own history, commits 7c99183/70a383f/d12d844): a
    # scribe-agent/taskmap-agent commit that SHARDS a new task into the backlog is ALSO a doc-only commit
    # naming the id - but it ADDS the task as [ ], it never ticks it, so it must NOT be flagged.
    $withNew = (Get-Content "$p\docs\TASKS.md" -Raw) + "`n### [ ] T3.1 - new work   (Story S3)`n- **Goal:** w"
    $withNew | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git add docs\TASKS.md
    git -c user.name=t -c user.email=t@t commit -q -m "TASKS: shard S3 into T3.1"
    $ErrorActionPreference = $prev; Pop-Location
    $out3 = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out3 -notmatch "T3\.1 \(commit") "a sharding commit that ADDED a task (never ticked it) was wrongly flagged as hand-ticked"

    # FALSE POSITIVE #2 (measured on this kit's own history, commit 9afc835): close-unit's own STORY
    # roll-up commit is shaped around the TASK it closed ("T2.2: ...", never "S2: ..."), so a plain
    # substring/shape check on the STORY id never excludes it - and the diff legitimately shows the
    # story's Status:DONE line changing. Stories have their own dedicated stamp-based detector (the
    # hand-tick check above), so this mechanism must not ALSO fire on the story id here.
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T2.2 -Title "close the story" -ProjectDir $p -NoReindex | Out-Null
    Assert ($LASTEXITCODE -eq 0) "close-unit failed to close T2.2 (the last task of S2)"
    Assert (Select-String "$p\docs\STORIES.md" -Pattern 'Story S2.*Status: DONE closed:close-unit' -Quiet) "S2 did not roll up via close-unit as expected (test setup problem, not the fix)"
    $out4 = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out4 -notmatch "S2 \(commit") "a close-unit story roll-up (commit shaped around the TASK id) was wrongly flagged as a hand-ticked STORY"
  } finally { Remove-Sandbox $sb }
}

Test-Case "doc-stats flags project-root JUNK and a nav-less layout" {
  # Measured, cms3: the root was littered with ELEVEN ad-hoc SUMMARY/COMPLETE/IMPLEMENTATION files (which
  # CLAUDE.md forbids), FOUR path-mangled directories (a Windows path passed to bash, backslashes eaten, so
  # mkdir made one literal dir named DprojectsClaudeprojectscms3srcCMS), a committed .binlog, a duplicate
  # solution file, AND a shared layout that linked to none of the 5 controllers - the app had no nav. All
  # of it was the librarian's remit in PROSE and none of it held, so it is computed now.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "cms"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Design`n`nStatus: LOCKED`nSecurity review: NOT-REQUIRED (test)" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    $ds = Join-Path $kit "doc-stats.ps1"

    # plant each junk class
    "done stuff"           | Set-Content "$p\IMPLEMENTATION_SUMMARY.md" -Encoding UTF8
    "S2 done"              | Set-Content "$p\STORY_S2_COMPLETE.md" -Encoding UTF8
    "x"                    | Set-Content "$p\completed_tasks.txt" -Encoding UTF8
    "binlog"              | Set-Content "$p\msbuild.binlog" -Encoding UTF8
    "sln1" | Set-Content "$p\App.sln" -Encoding UTF8; "sln2" | Set-Content "$p\App.slnx" -Encoding UTF8
    New-Item -ItemType Directory -Force (Join-Path $p "DprojectsClaudeprojectscmssrcApp") | Out-Null   # mangled

    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out -match '(?i)ad-hoc status/summary file') "stray summary files were not flagged"
    Assert ($out -match '(?i)MANGLED path') "the mangled path directory was not flagged"
    Assert ($out -match '(?i)\.binlog') "the committed .binlog was not flagged"
    Assert ($out -match '(?i)2 solution files') "duplicate solution files were not flagged"
    # the user's own run exports must NOT be scolded
    "transcript" | Set-Content "$p\S5run.txt" -Encoding UTF8
    "transcript" | Set-Content "$p\run.txt" -Encoding UTF8
    $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out2 -notmatch 'S5run\.txt|(^|[^a-z])run\.txt') "a user run-export was wrongly flagged as junk"

    # NAVIGABILITY: controllers with a nav-less layout -> WARN; a layout that links them -> silent
    New-Item -ItemType Directory -Force "$p\src\App\Controllers","$p\src\App\Views\Shared" | Out-Null
    "public class HomeController {}"    | Set-Content "$p\src\App\Controllers\HomeController.cs" -Encoding UTF8
    "public class PagesController {}"   | Set-Content "$p\src\App\Controllers\PagesController.cs" -Encoding UTF8
    "public class AccountController {}" | Set-Content "$p\src\App\Controllers\AccountController.cs" -Encoding UTF8
    "<html><body>@RenderBody()</body></html>" | Set-Content "$p\src\App\Views\Shared\_Layout.cshtml" -Encoding UTF8
    $out3 = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out3 -match '(?i)\[ui\].*links to NONE') "a nav-less layout with 3 controllers was not flagged"
    # now give the layout real nav links -> the [ui] finding clears
    '<html><body><nav><a asp-controller="Home" asp-action="Index">Home</a><a asp-controller="Pages">Pages</a><a asp-controller="Account">Login</a></nav>@RenderBody()</body></html>' |
      Set-Content "$p\src\App\Views\Shared\_Layout.cshtml" -Encoding UTF8
    $out4 = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out4 -notmatch '(?i)\[ui\]') "a layout that links every controller still warned - false positive"

    # navigability is a WARN, never a hard FAIL (navigation design varies)
    Assert ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) "navigability must not hard-fail the run"
  } finally { Remove-Sandbox $sb }

  # prevention guidance is present where the junk is created
  $dv = Get-Content (Join-Path $kit "global\agents\dev-agent.md") -Raw
  Assert ($dv -match '(?i)backslash') "dev-agent does not warn against backslash paths under bash"
  Assert ($dv -match '(?i)ad-hoc status|summary') "dev-agent does not warn against ad-hoc summary files"
}

Test-Case "data-stats gates DATASET integrity, and the corpus indexes data files" {
  # /research captures SOURCES (documents with provenance). A research SITE also needs DATA - the rows it
  # charts - and nothing here knew what a dataset was. A column can vanish, a unit can change from kg to
  # lb, a scrape can return 3 rows instead of 300, and the code still compiles, the tests still pass, and
  # every gate stays green. A chart drawn from that is confidently wrong, which is worse than one that is
  # obviously broken. Same declare-then-verify shape as SOURCES.md/source-stats.
  $ds = Join-Path $kit "data-stats.ps1"
  Assert (Test-Path $ds) "data-stats.ps1 is missing"
  Assert (Test-Path (Join-Path $kit "data-stats.cmd")) "data-stats.cmd wrapper is missing"
  Assert (Test-Path (Join-Path $kit "templates\_common\docs\DATASETS.md")) "the DATASETS.md template is missing"

  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"
    New-Item -ItemType Directory -Force "$p\docs","$p\data" | Out-Null
    @'
# Datasets

## D001: harvest-log
- **File:** `data/harvest-log.csv`
- **Key:** date+bed
- **Min rows:** 3
- **Columns:**
  | column | type | required | range |
  |---|---|---|---|
  | date | date | yes | 2020-01-01..2035-12-31 |
  | bed | text | yes | |
  | kg | number | yes | 0..500 |
  | method | text | no | broadfork;no-dig;mulch |
'@ | Set-Content "$p\docs\DATASETS.md" -Encoding UTF8

    # every defect class at once
    @'
date,bed,kg,method,notes
2026-06-01,B1,12.4,no-dig,ok
2026-06-08,B2,,mulch,
2026-06-15,B1,880,no-dig,
2026-06-22,B3,4.2,hugelkultur,
2026-06-01,B1,12.4,no-dig,dupe
'@ | Set-Content "$p\data\harvest-log.csv" -Encoding UTF8
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 1) "a dataset full of defects exited $LASTEXITCODE - it must FAIL"
    Assert ($out -match "(?i)required but empty")        "an empty required value was not caught"
    Assert ($out -match "(?i)880 outside")               "an out-of-range value was not caught"
    Assert ($out -match "(?i)hugelkultur.*not one of")   "a value outside the allowed SET was not caught - note the set separator is ';' because '|' would end the markdown table cell"
    Assert ($out -match "(?i)duplicate key")             "a duplicate key row was not caught"
    Assert ($out -match "(?i)WARN.*notes")               "an undeclared column was not reported as drift"

    # a CLEAN dataset must be silent and exit 0 - a gate that fires on good data gets switched off
    @'
date,bed,kg,method
2026-06-01,B1,12.4,no-dig
2026-06-08,B2,7.5,mulch
2026-06-15,B3,4.2,broadfork
'@ | Set-Content "$p\data\harvest-log.csv" -Encoding UTF8
    $ok = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0) "a clean dataset failed: $ok"
    Assert ($ok -notmatch 'FAIL') "a clean dataset produced a FAIL"

    # a missing file, and a short load - the silent killers
    Remove-Item "$p\data\harvest-log.csv" -Force
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 1) "a MISSING declared file did not fail"
    "date,bed,kg,method`n2026-06-01,B1,1,no-dig" | Set-Content "$p\data\harvest-log.csv" -Encoding UTF8
    $short = & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p 2>&1 | Out-String
    Assert ($short -match '(?i)declared minimum') "1 row against a declared minimum of 3 was accepted - a partial load looks exactly like this"

    # no ledger at all = not a data project, stay silent
    Remove-Item "$p\docs\DATASETS.md" -Force
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 0) "a project with no DATASETS.md was failed - it simply declares no data"
  } finally { Remove-Sandbox $sb }

  # the corpus must actually INDEX data files, or the model cannot answer "what columns does this have?"
  $rag = Get-Content (Join-Path $kit "local-tools\Rag.cs") -Raw
  Assert ($rag -match '"\.csv"') "the corpus does not index .csv - a dataset would be invisible to search"
  Assert ($rag -match '"\.json"') "the corpus does not index .json"
  # the header must be repeated per chunk, or chunk 7 is a wall of anonymous numbers
  Assert ($rag -match '(?s)ext == "\.csv".{0,1200}header') "CSV chunks do not carry the header - rows without column names are unsearchable"

  # and it must be honest about what it does NOT do
  $src = Get-Content $ds -Raw
  Assert ($src -match '(?i)not.{0,20}TRUE|traceability, not truth|SHAPE, NOT TRUTH') "data-stats does not state that it checks shape, not truth"
}

Test-Case "source-stats gates citation integrity" {
  # Research has no compiler. It DOES have something checkable: whether the design doc's claims trace to
  # sources that exist and were actually assessed. Verifies traceability, not truth.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs\sources" | Out-Null
    $script = Join-Path $kit "source-stats.ps1"

    # a project with no ledger is not a research project - must pass, not nag
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 0) "it failed a project that has no SOURCES.md"

    $ledger = "# Sources`n`n| id | tier | fetched | title | url |`n|---|---|---|---|---|`n"
    # S001: real, tiered, cited.  S002: in the ledger but its file is MISSING.
    ($ledger + "| S001 | primary | 2026-08-01 | A standard | https://example.invalid/a |`n" +
               "| S002 | primary | 2026-08-01 | Lost one | https://example.invalid/b |`n") |
      Set-Content "$p\docs\SOURCES.md" -Encoding UTF8
    "captured" | Set-Content "$p\docs\sources\S001-a-standard.md" -Encoding UTF8
    # cites S001 (fine) and S003 (nothing behind it)
    "# Design`n`nStatus: DRAFT`n`nThe thing is 14% [S001] and also [S003]." | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8

    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script -ProjectDir $p 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 1) "it passed a doc citing a source that does not exist"
    Assert ($out -match '\[S003\].*NO row') "an unbacked citation was not reported:`n$out"
    Assert ($out -match 'S002 is in the ledger but') "a ledger row with no file was not reported:`n$out"

    # fix both -> passes
    "captured" | Set-Content "$p\docs\sources\S002-lost-one.md" -Encoding UTF8
    "# Design`n`nStatus: DRAFT`n`nThe thing is 14% [S001]. Also [S002]." | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File $script -ProjectDir $p | Out-Null
    Assert ($LASTEXITCODE -eq 0) "it still failed after both problems were fixed"

    # untiered sources are a WARN, never a silent pass - the human has to assess them
    ($ledger + "| S001 | unknown | 2026-08-01 | A standard | https://example.invalid/a |`n") |
      Set-Content "$p\docs\SOURCES.md" -Encoding UTF8
    "# Design`n`nStatus: DRAFT`n`n14% [S001]." | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    $out2 = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script -ProjectDir $p 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 0) "an untiered source should warn, not fail"
    Assert ($out2 -match 'no tier yet') "an untiered source was not flagged:`n$out2"
    # and a hoarded source (captured, never cited) gets reported
    "captured" | Set-Content "$p\docs\sources\S009-never-used.md" -Encoding UTF8
    $out3 = (& powershell -NoProfile -ExecutionPolicy Bypass -File $script -ProjectDir $p 2>&1 | Out-String)
    Assert ($out3 -match 'S009.*no ledger row') "an unrecorded source file was not reported:`n$out3"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the security gate cannot DEADLOCK when the MCP server is down" {
  # The gate as shipped in 0.19.0 had one exit: run /design, which spawns security-agent. But every tool
  # security-agent has is an MCP tool, and `search_datasheets` was called ZERO times across nine graded
  # runs - decent evidence the server is not always connected. Unconnected server -> the agent cannot
  # work -> the header stays REQUIRED -> Gate 2b STOPs /build. The project is wedged by missing plumbing,
  # and the gate's own advice is to run the thing that does not work. Fail-closed on infrastructure is how
  # a gate gets deleted, so there must always be a HUMAN route out, and it must be stated at the stop.
  $build  = Get-Content (Join-Path $kit "global\commands\build.md") -Raw
  $design = Get-Content (Join-Path $kit "global\commands\design.md") -Raw
  $agent  = Get-Content (Join-Path $kit "global\agents\security-agent.md") -Raw

  $gate = [regex]::Match($build, '(?s)Gate 2b.*?(?=\*\*Gate 3)').Value
  Assert ($gate.Length -gt 200) "Gate 2b is missing from build.md"
  Assert ($gate -match 'NOT-REQUIRED') "the STOP does not name the route that does not depend on the MCP server"
  Assert ($gate -match '/mcp|dad-doctor') "the STOP does not say how to find out the server is the problem"
  Assert ($gate -match 'may not|do not|not take') "nothing stops the model taking the human's escape hatch itself"

  # /design must not quietly leave REQUIRED standing when the agent came back empty - that is the wedge.
  Assert ($design -match '(?is)could\s+not\s+search|not\s+connected|unconnected') "/design has no branch for the agent being unable to search"
  Assert ($design -match '(?s)security-agent.*?(?:from memory|not relay|Do not relay)') "/design does not refuse a security review produced from memory"

  # And the agent itself must say so rather than improvising, because a plausible undated review is worse
  # than none: /design pins it, and everything downstream treats it as decided.
  # \s+ not a literal space: these files are hard-wrapped at ~100 chars, so any asserted phrase can land
  # with a newline in the middle of it. This assertion failed exactly that way on "from\nmemory".
  Assert ($agent -match '(?is)could\s+not\s+search') "security-agent has no defined behaviour when its tools do not answer"
  Assert ($agent -match '(?is)from\s+memory') "security-agent is not forbidden from answering from memory - the exact thing it exists to replace"
}

Test-Case "the loop guard breaks a repeated command, and rejects 2>nul outright" {
  # Measured, CMS run: a taskmap subagent ran `dir "D:\...\cms\src" 2>nul` NINE HUNDRED AND TWENTY times
  # in a row and the session had to be killed by hand. Two causes, both fixed here.
  #   1. `2>nul` is cmd.exe. Under Bash it writes stderr to a FILE named `nul`, so the model got empty
  #      output and NO error - nothing to learn from, so it retried forever. (Reproduced: exit 2, no
  #      stdout, a 'nul' file created.) It also left 28 such files, including in .git\objects.
  #   2. Nothing noticed the repetition. The agent's `tools:` frontmatter did NOT include Bash and it ran
  #      Bash anyway, so per-agent tool restriction cannot be the guard. A HOOK is enforced by the harness.
  $lg = Join-Path $kit "dad-loopguard.ps1"
  Assert (Test-Path $lg) "dad-loopguard.ps1 is missing"

  function Invoke-Guard($cmd, $session) {
    $j = @{ session_id = $session; tool_name = "Bash"; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
    $out = ($j | & powershell -NoProfile -ExecutionPolicy Bypass -File $lg 2>&1 | Out-String)
    return @{ Code = $LASTEXITCODE; Text = $out }
  }
  $sid = "testkit-$PID-$(Get-Random)"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null

  # the exact command from the incident: blocked on the FIRST call, not the fourth
  $r = Invoke-Guard 'dir "D:\projects\Claude\projects\cms\src" 2>nul' $sid
  Assert ($r.Code -eq 2) "2>nul was allowed (exit $($r.Code)) - the invisible-failure shape must be refused"
  Assert ($r.Text -match '(?is)2>/dev/null|Test-Path') "the block does not say what to use instead"

  # legitimate commands are untouched, however often they repeat NON-consecutively
  foreach ($ok in @('ls -la src 2>/dev/null', 'dotnet build', 'git status --porcelain')) {
    $r2 = Invoke-Guard $ok $sid
    Assert ($r2.Code -eq 0) "'$ok' was blocked (exit $($r2.Code)) - false positives make a guard get deleted"
  }

  # WORK COMMANDS ARE EXEMPT, even back to back. This hook only sees SHELL calls, so a build-fix-build-fix
  # cycle reaches it as four consecutive identical `dotnet build` calls - the Edit calls in between are
  # invisible to it. Found by benchmarking the guard: it blocked `dotnet build`. For a build, a test, or
  # anything else whose result changes when the workspace changes, "you will get the same result" is FALSE,
  # and a guard that interrupts a compile-error fix loop is one somebody switches off within the hour.
  foreach ($work in @('dotnet build', 'dotnet test --nologo', 'npm run build', 'git status --porcelain',
                      'powershell -File "C:\k\close-unit.ps1" -Id T1.1')) {
    for ($i = 1; $i -le 6; $i++) {
      $a = Invoke-Guard $work $sid
      Assert ($a.Code -eq 0) "'$work' was BLOCKED on consecutive call $i - work commands must never be throttled"
    }
  }
  # Probes are the opposite: on an unchanged tree they really do return the same thing, and every loop this
  # kit has actually suffered was a probe.
  foreach ($probe in @('cat docs/DESIGN.md', 'find . -name Foo.cs')) {
    $hit = $false
    for ($i = 1; $i -le 5; $i++) { if ((Invoke-Guard $probe $sid).Code -eq 2) { $hit = $true; break } }
    Assert $hit "repeating the probe '$probe' was never blocked"
  }

  # but four IDENTICAL calls back to back, with nothing between, is a loop
  $blocked = $false
  for ($i = 1; $i -le 4; $i++) {
    $r3 = Invoke-Guard 'ls -la nowhere-at-all' $sid
    if ($r3.Code -eq 2) { $blocked = $true; Assert ($i -ge 3) "blocked too early (attempt $i) - a couple of retries is normal"; break }
  }
  Assert $blocked "four consecutive identical commands were never blocked - this is the 920-call loop"

  # and it must FAIL OPEN: garbage in, allow. A PreToolUse hook sits in front of EVERY tool call, so one
  # that errors on its own bugs makes the session unusable and gets switched off within the hour.
  foreach ($junk in @('', 'not json at all', '{"tool_name":"Bash"}', '{"tool_input":{}}')) {
    $out = ($junk | & powershell -NoProfile -ExecutionPolicy Bypass -File $lg 2>&1 | Out-String)
    Assert ($LASTEXITCODE -eq 0) "malformed hook input returned $LASTEXITCODE - the guard must fail OPEN"
  }
  # A non-shell tool is now very much its business - see "the loop guard sees EVERY tool". What must NOT
  # happen is a FIRST-time call being blocked: only a repeat or a spiral blocks.
  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null
  $j2 = '{"session_id":"firsttime","tool_name":"Read","tool_input":{"file_path":"once.md"}}'
  $j2 | & powershell -NoProfile -ExecutionPolicy Bypass -File $lg 2>&1 | Out-Null
  Assert ($LASTEXITCODE -eq 0) "a first-time non-shell tool call was blocked"

  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null
}

Test-Case "the loop guard sees EVERY tool, and catches a search spiral" {
  # Measured, CMS2 run: a scribe subagent made NINE HUNDRED AND FORTY-SEVEN tool calls and produced NO
  # STORIES.md at all, then had to be killed by hand. The guard could not see one of them: it was matched
  # on "Bash", and scribe-agent's tool list is Read/Grep/Edit/Write plus MCP search - no Bash anywhere.
  # A loop breaker that watches one tool is not a loop breaker.
  #
  # And the identical-call rule alone would still have missed it: an agent searching with a DIFFERENT
  # query each time never forms a streak. That is what "lost in search" means, so there is a second rule -
  # many reads, nothing written.
  $lg = Join-Path $kit "dad-loopguard.ps1"
  $s = Get-Content (Join-Path $kit "settings.json") -Raw | ConvertFrom-Json
  $matchers = @($s.hooks.PreToolUse | ForEach-Object { $_.matcher })
  Assert ($matchers -contains "") "the PreToolUse matcher is narrowed to specific tools - a non-Bash subagent loop is invisible again"

  # -SpiralLimit 5 keeps this test to a handful of invocations. The hook costs ~1.7 s per call on a machine
  # with slow process launch, so a 25-deep test would add a minute to the suite for no extra coverage.
  function Fire($tool, $inp, $sess) {
    (@{ session_id = $sess; tool_name = $tool; tool_input = $inp } | ConvertTo-Json -Compress) |
      & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -SpiralLimit 5 2>$null | Out-Null
    return $LASTEXITCODE
  }
  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null

  # a NON-shell tool repeated identically is now caught
  $hit = 0
  for ($i = 1; $i -le 6; $i++) { if ((Fire "Read" @{ file_path = "same.md" } "t1") -eq 2) { $hit = $i; break } }
  Assert ($hit -eq 4) "an identical non-shell tool call was not blocked on the 4th (got $hit)"

  # a VARYING search spiral with nothing written is caught by the second rule
  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null
  $hit2 = 0
  for ($i = 1; $i -le 7; $i++) {
    if ((Fire "mcp__local-tools__search_datasheets" @{ query = "reworded query $i" } "t2") -eq 2) { $hit2 = $i; break }
  }
  Assert ($hit2 -eq 5) "differently-worded searches with nothing written were not blocked at the limit (got $hit2)"

  # but a WRITE resets it: real work reads a lot before it writes, and a guard that punishes that gets removed
  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null
  $falsePositive = $false
  for ($round = 1; $round -le 3; $round++) {
    for ($i = 1; $i -le 4; $i++) { if ((Fire "Read" @{ file_path = "r$round-$i.md" } "t3") -eq 2) { $falsePositive = $true } }
    Fire "Write" @{ file_path = "STORIES.md"; content = "a story" } "t3" | Out-Null
  }
  Assert (-not $falsePositive) "reads with a write before the limit was blocked - legitimate work must not trip this"

  # JSON escaping must not defeat the 2>nul check. PowerShell's ConvertTo-Json encodes '>' as \u003e while
  # Node emits it literally; a guard that only handles one encoding silently stops working.
  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null
  Assert ((Fire "Bash" @{ command = 'dir "D:\p\src" 2>nul' } "t4") -eq 2) "2>nul escaped as \u003e was not caught"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null
  '{"session_id":"t5","tool_name":"Bash","tool_input":{"command":"dir \"D:\\p\" 2>nul"}}' |
    & powershell -NoProfile -ExecutionPolicy Bypass -File $lg 2>$null | Out-Null
  Assert ($LASTEXITCODE -eq 2) "2>nul in literal (Node-style) JSON was not caught"

  # -Bench must exist: this hook's cost is multiplied by every tool call, and it is dominated by how fast
  # the MACHINE starts a process - so the number cannot be assumed, it has to be measured where it runs.
  $bench = (& powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Bench 2>&1 | Out-String)
  Assert ($bench -match '(?i)per\s+call') "-Bench does not report per-call overhead"
  Assert ($bench -match '(?i)300\s+tool\s+calls') "-Bench does not translate the cost into a whole run"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $lg -Reset | Out-Null
}

Test-Case "iterative work is ONE AGENT PER UNIT, verified between, retry-limited" {
  # Three consecutive runs died inside a subagent and nowhere else: taskmap-agent 920 identical
  # `dir ... 2>nul` calls; scribe-agent 947 calls with STORIES.md never written; scribe-agent 1023 identical
  # `Search **/STORIES.md` calls. Eleven graded runs in the main loop: zero loops.
  #
  # The 1023-call run SETTLED the question two releases had left open: the PreToolUse hook does not fire for
  # a subagent's tool calls. It was the ideal case - identical, consecutive, non-shell, matcher set to every
  # tool - and not one call was blocked. The tools: frontmatter does not restrain it either; it looped on
  # Glob, which scribe-agent does not list. So a subagent is a region where NO gate applies, and the two
  # commands that ITERATE over many items must not run there.
  # NOT "never delegate" - that was an overcorrection from three failures without looking at the successes.
  # Bounded spawns finish in single digits (S1.2-S1.5 -> 5 calls, S2.1-S2.8 -> 9). What fails is ONE agent
  # asked to manage the WHOLE job. So: one agent per unit, control back between them, and a retry limit so
  # the ORCHESTRATOR cannot become the same loop one level up.
  foreach ($c in @("stories","taskmap")) {
    $t = Get-Content (Join-Path $kit "global\commands\$c.md") -Raw
    Assert ($t -match '(?is)ONE\s+AGENT\s+PER\s+(UNIT|STORY|EPIC)') "/$c does not state the one-agent-per-unit rule"
    Assert ($t -match '(?is)exactly\s+one\s+(epic|story)') "/$c does not scope each spawn to a single unit"
    Assert ($t -match '(?is)RETRY\s+LIMIT') "/$c has no retry limit - an orchestrator that re-spawns forever is the same loop"
    Assert ($t -match '1023') "/$c does not carry the measurement, so a later editor will widen the scope again"
    Assert ($t -match 'doc-stats -Findings') "/$c does not verify between units"
    Assert ($t -match '(?i)(DIRECTLY with Read|Read.{0,40}(design doc|STORIES\.md).{0,40}direct)') "/$c does not say to read the doc directly"
    Assert ($t -match 'dad watch') "/$c does not point at the watchdog - detection is the only remaining control"
    # the evidence table is what stops a later editor 'simplifying' this back to one big spawn
    Assert ($t -match '(?s)\|\s*5\s*\*{0,2}\s*-?\s*fine|5\*{0,2} - fine') "/$c does not show that SMALL spawns succeed - without it the rule reads as anti-agent"
  }
  # The one-shot delegations have never looped and stay. If this list ever empties, the kit has lost its
  # subagents entirely - which is NOT the finding; the finding is about iteration.
  $oneShot = 0
  foreach ($c in @("design","document","audit","grade","research")) {
    $p = Join-Path $kit "global\commands\$c.md"
    if ((Test-Path $p) -and ((Get-Content $p -Raw) -match 'subagent_type')) { $oneShot++ }
  }
  Assert ($oneShot -ge 4) "the one-shot agent delegations disappeared - only ITERATIVE generation was supposed to move"
  # R32 must record why, or the next maintainer re-delegates it
  $design = Get-Content (Join-Path $kit "docs\DESIGN.md") -Raw
  Assert ($design -match '(?s)R32.*?UNOBSERVABLE') "R32 does not record the subagent finding"
  Assert ($design -match '(?s)R32.*?1023') "R32 does not carry the measurement"
}

Test-Case "the watchdog makes a spiral loud in minutes, and never writes to the project" {
  # Nothing can interrupt a spiralling subagent: hooks do not fire there, the tools list does not restrain
  # it, and while a Task runs the orchestrator is SUSPENDED so it cannot poll or cut the call short. Two
  # runs therefore burned HOURS before a human noticed. Prevention is unavailable; detection is not. A
  # spiral writes NOTHING, so silence on disk is the signal.
  $w = Join-Path $kit "dad-watch.ps1"
  Assert (Test-Path $w) "dad-watch.ps1 is missing"
  Assert (Test-Path (Join-Path $kit "dad-watch.cmd")) "dad-watch.cmd wrapper is missing"
  $src = Get-Content $w -Raw
  # It must never write into what it watches - a watcher that changes the thing it watches is useless,
  # and would also reset its own idle timer forever.
  Assert ($src -notmatch 'WriteAllText|Set-Content|New-Item|Out-File|Add-Content') "dad-watch WRITES - it would reset its own idle timer and never alarm"
  # a bad path must fail loudly, like every other script
  & powershell -NoProfile -ExecutionPolicy Bypass -File $w -ProjectDir (Join-Path $kit "_no_such_dir_zz") 2>&1 | Out-Null
  Assert ($LASTEXITCODE -ne 0) "dad-watch accepted a project dir that does not exist"

  # END TO END: it must report progress, then alarm on silence. Run it against a sandbox with a tiny
  # idle window so the test takes seconds rather than minutes.
  $sb = New-Sandbox
  try {
    $proj = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$proj\docs" | Out-Null
    "# D" | Set-Content "$proj\docs\DESIGN.md" -Encoding UTF8
    $job = Start-Job -ScriptBlock { param($ps1, $dir)
      & powershell -NoProfile -ExecutionPolicy Bypass -File $ps1 -ProjectDir $dir -IdleMinutes 0.2 -PollSeconds 2 -NoBeep
    } -ArgumentList $w, $proj
    try {
      Start-Sleep -Seconds 5
      "s" | Set-Content "$proj\docs\STORIES.md" -Encoding UTF8      # progress
      Start-Sleep -Seconds 22                                        # then silence
      $out = (Receive-Job $job) -join "`n"
    } finally { Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue }
    Assert ($out -match 'wrote docs\\STORIES\.md') "the watchdog did not notice a write - it would alarm during healthy work"
    Assert ($out -match '(?i)QUIET') "the watchdog never alarmed on silence - that is its whole job"
    Assert ($out -match '(?i)doc-stats') "the alarm does not tell the human what to run next"
    # after the first full alarm, repeats must be COMPACT dotted ticks, not the whole banner again -
    # a warning that re-bangs in full every poll buries the log (the reason for this change)
    Assert ($out -match '(?im)^\s*\.\s*\[\d\d:\d\d:\d\d\]\s*still quiet') "repeats are not compact ticks - the banner is re-printing in full"
    $fullAlarms = ([regex]::Matches($out, 'GO LOOK')).Count
    Assert ($fullAlarms -le 2) "the full alarm printed $fullAlarms times in a short window - it should fire once, then tick"
  } finally { Remove-Sandbox $sb }
}

Test-Case "corpus-consuming agents are told to READ the doc, not search for it" {
  # Seven agents have MCP search as their ONLY corpus door and no shell, so when local-tools is not
  # answering they have no second door - and rewording the query cannot help. One of them burned 947 calls
  # and produced an empty file. The design doc is ONE file of 10-20 KB and every one of these agents has
  # Read: searching a corpus for a document you can simply open is pure overhead even when it works.
  foreach ($a in @("scribe-agent","taskmap-agent","architect-agent","requirements-agent","grade-agent")) {
    $t = Get-Content (Join-Path $kit "global\agents\$a.md") -Raw
    Assert ($t -match '(?is)Read\s+the\s+document;\s+do\s+not\s+search\s+for\s+it') "$a is not told to read the doc directly"
    Assert ($t -match '(?is)give\s+up\s+after') "$a has no bound on failed searches - rewording forever is the failure mode"
    Assert ($t -match '947') "$a does not carry the measurement, so a later editor will soften the rule"
  }
  # and none of them should be told a shell path for an MCP tool - one run invented docs/search_datasheets.ps1
  foreach ($f in (Get-ChildItem (Join-Path $kit "global\agents") -Filter *.md)) {
    $t = Get-Content $f.FullName -Raw
    Assert ($t -notmatch 'search_datasheets\.ps1') "$($f.Name) names a search_datasheets script, which does not exist"
  }
}

Test-Case "an UNREADABLE task ledger is an error, not a count of zero" {
  # Measured, same CMS run: a 41 KB TASKS.md whose blocks were headed `### S1.1: Dashboard Overview` with
  # anonymous `- [ ]` bullets, and whose Build order sequenced 19 `T` ids defined NOWHERE in the file.
  # doc-stats printed "tasks 0/0" - a NUMBER - so it read as "no tasks yet" rather than "I cannot parse
  # your ledger". close-unit could tick nothing; /build could select no unit. A day of planning, unusable.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Design`n`nStatus: LOCKED`nSecurity review: NOT-REQUIRED (test)" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    # the real shape that produced 0/0
    $body = "# Tasks`r`n`r`n## Build order (dependency-sorted)`r`nT1.1 -> T1.2 -> T2.1`r`n`r`n## E1: Admin`r`n"
    foreach ($n in 1..40) {
      $body += "### S1.$n`: Story-numbered heading, no checkbox and no T id`r`n- [ ] do a thing in ``src/A$n.cs```r`n- [ ] do another thing`r`n`r`n"
    }
    Set-Content "$p\docs\TASKS.md" $body -Encoding UTF8
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out -match '(?is)NOT\s+ONE\s+task\s+id\s+is\s+parseable') "a 40-block TASKS.md that parses to zero was reported as a plain count"
    Assert ($out -match '(?is)###\s*\[\s*\]\s*T') "the finding does not state the heading shape that would work"
    Assert ($out -match '(?is)Build\s+order\s+sequences\s+3\s+id') "dangling Build-order ids went unreported: /build walks that list"

    # A CORRECT ledger must stay silent - a finding that fires on good input is noise, and noise gets ignored.
    $good = "# Tasks`r`n`r`n## Build order`r`nT1.1 -> T1.2`r`n`r`n## Tasks`r`n`r`n### [ ] T1.1 - first   (Story S1.1)`r`n- **Goal:** x`r`n`r`n### [x] T1.2 - second   (Story S1.1)`r`n- **Goal:** y`r`n"
    Set-Content "$p\docs\TASKS.md" $good -Encoding UTF8
    $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out2 -notmatch '(?is)NOT\s+ONE\s+task\s+id') "a well-formed ledger was flagged as unparseable"
    Assert ($out2 -notmatch '(?is)DEFINED\s+NOWHERE') "ids that ARE defined were reported as dangling"

    # A TRUNCATED task map: stories that were never planned at all. This is how the CMS run lost 13
    # stories - the agent hung partway through E4, the totals still looked plausible, and nothing said
    # that E4 and E5 had never been mapped. /build would simply never reach that work.
    $st = "# Stories`r`n`r`n### Story S1.1: mapped   <!-- Status: TODO -->`r`n`r`n### Story S4.1: never mapped   <!-- Status: TODO -->`r`n`r`n### Story S4.2: also never mapped   <!-- Status: TODO -->`r`n"
    Set-Content "$p\docs\STORIES.md" $st -Encoding UTF8
    Set-Content "$p\docs\TASKS.md" $good -Encoding UTF8      # only S1.1 has tasks
    $out4 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out4 -match '(?is)2\s+of\s+3\s+stories\s+have\s+NO\s+tasks') "stories with no tasks went unreported - a truncated taskmap looks complete"
    Assert ($out4 -match 'S4\.1') "the finding does not name which stories were skipped"

    # And a freshly scaffolded template (small, legitimately empty) must not be flagged either.
    Copy-Item (Join-Path $kit "templates\_common\docs\STORIES.md") "$p\docs\STORIES.md" -Force
    Remove-Item "$p\docs\TASKS.md" -Force
    $out3 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out3 -notmatch '(?is)NOT\s+ONE\s+story\s+id') "the shipped template was flagged - a new project would start with a false alarm"
  } finally { Remove-Sandbox $sb }
}

Test-Case "a one-word edit cannot satisfy the LOCK or the SECURITY gate" {
  # Both gates cost the model exactly one word to pass, and both then report green forever.
  #   LOCKED: /build Gate 2 reads only the WORD "LOCKED". A design locked with an EMPTY '## Contracts'
  #     section is the same unfinished state the gate exists to refuse - /design step 5 never landed - and
  #     every dev-agent downstream improvises the semantics that were supposed to be pinned.
  #   Security review: NOT-REQUIRED is the escape from a gate that STOPS the build. Written without a
  #     reason it is indistinguishable from an omission. DONE is likewise one word, and what makes it TRUE
  #     is security-agent having written CITED decisions into the doc.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    $ds = Join-Path $kit "doc-stats.ps1"
    function Set-Design($header, $extra) {
      $body = "# Design`r`n`r`nStatus: LOCKED`r`n$header`r`n`r`n## Requirements`r`n- R1: a`r`n`r`n## Contracts`r`n$extra`r`n"
      Set-Content "$p\docs\DESIGN.md" $body -Encoding UTF8
    }
    function Findings() { return (& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String) }

    # LOCKED + empty Contracts section -> flagged
    Set-Design "Security review: NOT-REQUIRED (local-only tool, no auth)" "<!-- nothing pinned yet -->"
    $o = Findings
    Assert ($o -match "(?is)LOCKED and its '## Contracts' section is EMPTY") "a design locked with nothing pinned was accepted"
    # ...and a real contract silences it
    Set-Design "Security review: NOT-REQUIRED (local-only tool, no auth)" "### C1: File naming`r`n- **Decision:** slug"
    $o2 = Findings
    Assert ($o2 -notmatch "(?is)Contracts' section is EMPTY") "a pinned contract did not clear the finding"

    # NOT-REQUIRED with no reason -> flagged; with a reason -> silent (already asserted above)
    Set-Design "Security review: NOT-REQUIRED" "### C1: x`r`n- **Decision:** y"
    Assert ((Findings) -match '(?is)NOT-REQUIRED with no stated reason') "NOT-REQUIRED with no reason was accepted - that is the gate waved through"
    Set-Design "Security review: NOT-REQUIRED ()" "### C1: x`r`n- **Decision:** y"
    Assert ((Findings) -match '(?is)NOT-REQUIRED with no stated reason') "an EMPTY parenthetical counted as a reason"

    # DONE with no decisions section -> flagged
    Set-Design "Security review: DONE 2026-08-22" "### C1: x`r`n- **Decision:** y"
    Assert ((Findings) -match '(?is)no .## Security decisions. section') "DONE was accepted with nothing recorded"
    # DONE with an UNCITED decisions section -> flagged
    $body = "# Design`r`n`r`nStatus: LOCKED`r`nSecurity review: DONE 2026-08-22`r`n`r`n## Contracts`r`n### C1: x`r`n- **Decision:** y`r`n`r`n## Security decisions`r`n- Use the framework's built-in auth.`r`n"
    Set-Content "$p\docs\DESIGN.md" $body -Encoding UTF8
    Assert ((Findings) -match '(?is)cites no sources') "DONE was accepted over decisions that cite nothing"
    # DONE with a cited decision -> silent
    $body2 = $body.Replace("- Use the framework's built-in auth.", "- Use the framework's built-in auth. [S007]")
    Set-Content "$p\docs\DESIGN.md" $body2 -Encoding UTF8
    $o3 = Findings
    Assert ($o3 -notmatch '(?is)cites no sources') "a properly cited decision was still flagged"
    Assert ($o3 -notmatch '(?is)Security review') "a correctly completed review produced noise"
  } finally { Remove-Sandbox $sb }
}

Test-Case "doc-stats flags a NOT-REQUIRED security waiver contradicted by the design's own auth content" {
  # A.4: the existence check above (previous Test-Case) only asks "is there a parenthetical >=4 chars" -
  # it never asks whether the reason is CREDIBLE. A real run waived the review as
  # "NOT-REQUIRED (small personal project...)" on an app that demonstrably shipped bcrypt + JWT auth
  # (ModelTest bake-off, haiku/docs/DESIGN.md:9) - this doc's own rule keeps auth-handling projects REQUIRED,
  # and the gate stayed silent because the reason merely EXISTED. Grep for the auth-shaped keywords instead.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    $ds = Join-Path $kit "doc-stats.ps1"
    function Set-SecurityDesign($extraDesign, $storiesContent) {
      $body = "# Design`r`n`r`nStatus: LOCKED`r`nSecurity review: NOT-REQUIRED (small personal project, low risk)`r`n`r`n" +
              "## Requirements`r`n- R1: a`r`n`r`n## Contracts`r`n### C1: x`r`n- **Decision:** y`r`n$extraDesign`r`n"
      Set-Content "$p\docs\DESIGN.md" $body -Encoding UTF8
      if ($storiesContent) { Set-Content "$p\docs\STORIES.md" $storiesContent -Encoding UTF8 }
      elseif (Test-Path "$p\docs\STORIES.md") { Remove-Item "$p\docs\STORIES.md" }
    }
    function Findings() { return (& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String) }

    # a NOT-REQUIRED waiver with a plausible reason, but the design itself pins a JWT login requirement
    Set-SecurityDesign "`r`n## Requirements`r`n- R2: users log in with a password and get a JWT token" $null
    Assert ((Findings) -match '(?is)NOT-REQUIRED, but .*(mentions|DESIGN).*auth') "an auth-shaped design contradicting its own NOT-REQUIRED waiver was not flagged"

    # the same waiver on a genuinely auth-free project (a CLI tool) must stay silent - no false positive
    Set-SecurityDesign "" $null
    $o = Findings
    Assert ($o -notmatch '(?is)NOT-REQUIRED, but') "an auth-free project was flagged for a waiver it is entitled to"

    # the keyword can also live in STORIES.md, not just DESIGN.md
    Set-SecurityDesign "" "# Stories`r`n`r`n### Story S1: sign in   <!-- Status: TODO -->`r`n- **Goal:** add a login form"
    Assert ((Findings) -match '(?is)NOT-REQUIRED, but') "an auth-shaped STORY was not enough to flag the waiver"
  } finally { Remove-Sandbox $sb }
}

Test-Case "grade cards are demanded for STORIES only, not for every task" {
  # doc-stats demanded a card for every done TASK as well as every done story, contradicting /build:2
  # ("grade + hygiene per story"), /build:98, DESIGN R18 and close-unit (which only asks under
  # -RequireGrade, on a story close). On any project with a task map that meant a permanent [grade]
  # finding for every closed task - findings that can never be resolved, which is exactly how a model
  # learns that the findings list is noise and stops reading it.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Design`r`n`r`nStatus: LOCKED`r`nSecurity review: NOT-REQUIRED (test fixture)" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    "# Stories`r`n`r`n### Story S1: one   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    "# Tasks`r`n`r`n## Tasks`r`n`r`n### [x] T1.1 - done task   (Story S1)`r`n- **Goal:** x`r`n" | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out -notmatch '\[grade\] T1\.1') "a closed TASK was reported as missing a grade card - grading is per STORY"
    # a DONE story with no card SHOULD still be reported
    "# Stories`r`n`r`n### Story S1: one   <!-- Status: DONE -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String
    Assert ($out2 -match '\[grade\] S1') "a DONE story with no grade card went unreported - that check must stay"
  } finally { Remove-Sandbox $sb }
}

Test-Case "doc-stats fires [ratchet] per C1a's worked mass/doneRatio table, silent below the floor or above the ratio" {
  # T6.1 added a WARN-only [ratchet] finding: mass = storiesTotal + tasksTotal, doneRatio = doneMass/mass,
  # fires when mass >= 15 AND doneRatio < 0.15 (C1a). This mechanically drives doc-stats.ps1 -Findings
  # through DESIGN.md C1a's four worked-example rows (docs/TASKS.md T6.2) - the exact regression fixture
  # for the real Opus/ModelTest incident (28 stories/0 done, 35 tasks/0 done, mass 63) that motivated R36b.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    $ds = Join-Path $kit "doc-stats.ps1"
    "# Design`r`n`r`nStatus: LOCKED`r`nSecurity review: NOT-REQUIRED (test fixture)" | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8

    # Builds a STORIES.md/TASKS.md pair with exactly $storiesTotal story headings ($storiesDone of them
    # carrying '<!-- Status: DONE -->' ON THE HEADING LINE - doc-stats.ps1:132 only counts DONE when the
    # marker is on the same line as the heading) and $tasksTotal '### [ ]'/'### [x]' task blocks.
    function Set-Fixture([int]$storiesTotal, [int]$storiesDone, [int]$tasksTotal, [int]$tasksDone) {
      $storyLines = @("# Stories", "")
      for ($i = 1; $i -le $storiesTotal; $i++) {
        $marker = if ($i -le $storiesDone) { "<!-- Status: DONE -->" } else { "<!-- Status: TODO -->" }
        $storyLines += "### Story S${i}: story $i   $marker"
      }
      Set-Content "$p\docs\STORIES.md" ($storyLines -join "`r`n") -Encoding UTF8

      $taskLines = @("# Tasks", "", "## Tasks", "")
      for ($i = 1; $i -le $tasksTotal; $i++) {
        $box = if ($i -le $tasksDone) { "x" } else { " " }
        $taskLines += "### [$box] T1.$i - task $i   (Story S1)"
        $taskLines += "- **Goal:** x"
        $taskLines += ""
      }
      Set-Content "$p\docs\TASKS.md" ($taskLines -join "`r`n") -Encoding UTF8
    }
    function Findings() { return (& powershell -NoProfile -ExecutionPolicy Bypass -File $ds -ProjectDir $p -Findings 2>&1 | Out-String) }

    # AC1/AC4: the Opus-incident regression numbers - 28/0 stories, 35/0 tasks -> mass=63, doneRatio=0%
    Set-Fixture 28 0 35 0
    $o1 = Findings
    Assert ($o1 -match '\[ratchet\]') "the Opus-incident numbers (28 stories/0 done, 35 tasks/0 done, mass 63) did not fire [ratchet]"
    Assert ($o1 -match [regex]::Escape('(28 stories + 35 tasks = 63)')) "mass was not substituted as '(28 stories + 35 tasks = 63)'"
    Assert ($o1 -match [regex]::Escape('(0 stories + 0 tasks = 0 done, 0% of mass)')) "doneRatio was not substituted as '0 stories + 0 tasks = 0 done, 0% of mass'"
    # C1b's pinned message shape: names the mechanism and states the two pinned floors
    Assert ($o1 -match '(?i)walking-skeleton ratchet \(R36b/C1\)') "message does not name the walking-skeleton ratchet per C1b"
    Assert ($o1 -match 'mass >= 15 and the done ratio stays under 15%') "message does not state the pinned mass/doneRatio floors"

    # AC2: early small project - 3/0 stories, 0/0 tasks -> mass=3 < 15 -> SILENT, no false positive
    Set-Fixture 3 0 0 0
    $o2 = Findings
    Assert ($o2 -notmatch '\[ratchet\]') "an early 3-story/0-task project (mass 3 < 15) falsely fired [ratchet]"

    # AC3: healthy large project - 50/10 stories, 80/40 tasks -> mass=130, doneRatio=38.5% >= 15% -> SILENT
    Set-Fixture 50 10 80 40
    $o3 = Findings
    Assert ($o3 -notmatch '\[ratchet\]') "a healthy large project (mass 130, 38.5% done) falsely fired [ratchet]"

    # AC5: stalled large project - 50/3 stories, 80/5 tasks -> mass=130, doneRatio=6.2% < 15% -> FIRES
    # (the case a story-only ratio would have missed, since it is a large mostly-scoped project that just
    # stalled, not an early one)
    Set-Fixture 50 3 80 5
    $o4 = Findings
    Assert ($o4 -match '\[ratchet\]') "a stalled large project (mass 130, 6.2% done) did not fire [ratchet]"
    Assert ($o4 -match [regex]::Escape('(50 stories + 80 tasks = 130)')) "mass was not substituted as '(50 stories + 80 tasks = 130)' for the stalled-project case"
    Assert ($o4 -match [regex]::Escape('(3 stories + 5 tasks = 8 done, 6.2% of mass)')) "doneRatio was not substituted as '3 stories + 5 tasks = 8 done, 6.2% of mass' for the stalled-project case"
  } finally { Remove-Sandbox $sb }
}

Test-Case "a corpus that nothing cites is ONE finding, said loudly" {
  # Measured on the CMS run: 11 source files, a 17-contract design doc, and `cited in docs: 0`. The whole
  # research phase produced files and changed nothing downstream. Two failures at once: the count printed
  # as a bare number (reads like "not citing YET"), and the per-source "hoarded" warning fired ELEVEN
  # times, burying the three real FAILs underneath it.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs\sources" | Out-Null
    $rows = "# Sources`r`n`r`n| id | tier | fetched | title | url | published |`r`n|--|--|--|--|--|--|`r`n"
    foreach ($n in 1..5) {
      $id = "S00$n"
      $rows += "| $id | primary | 2026-08-22 | doc $n | https://e$n.example | 2026-08-01 |`r`n"
      "x" | Set-Content "$p\docs\sources\$id-x.md" -Encoding UTF8
    }
    Set-Content "$p\docs\SOURCES.md" $rows -Encoding UTF8
    "# D`r`n`r`nStatus: DRAFT`r`n`r`nA design that cites nothing it gathered." | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8

    $ss = Join-Path $kit "source-stats.ps1"
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ss -ProjectDir $p 2>&1 | Out-String
    Assert ($out -match '(?is)NOT\s+ONE\s+is\s+cited') "a corpus with zero citations was reported only as the number 0"
    Assert ($LASTEXITCODE -eq 0) "zero citations must WARN, not FAIL - sources may legitimately be cited later"
    $hoarded = ([regex]::Matches($out, 'hoarded')).Count
    Assert ($hoarded -eq 0) "the per-source 'hoarded' warning fired $hoarded times on top of the aggregate - that noise buried the real FAILs"

    # But once SOME are cited, an uncited one is genuinely worth naming individually again.
    "# D`r`n`r`nStatus: DRAFT`r`n`r`nCites [S001] only." | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8
    $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $ss -ProjectDir $p 2>&1 | Out-String
    Assert ($out2 -notmatch '(?is)NOT\s+ONE\s+is\s+cited') "the aggregate fired even though a source WAS cited"
    Assert ($out2 -match 'hoarded') "an individually uncited source stopped being reported"
  } finally { Remove-Sandbox $sb }
}

Test-Case "recency is checked on PUBLICATION date, and old ledgers still parse" {
  # 0.19.0 claimed security guidance was held to "under ~6 months old" and gated it with -StaleDays 180.
  # But StaleDays measured the FETCHED date, and in a fresh run everything was fetched today - so the flag
  # could not catch anything on the first pass, which is the only pass that matters. A 2019 article pulled
  # this morning looked current. The claim was enforced by prose. So the ledger gained a 'published' column.
  # It is the LAST column deliberately: parsing is positional, and inserting it beside 'fetched' would make
  # every pre-existing ledger read its TITLE as a date. That regression is the second half of this test.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs\sources" | Out-Null
    @'
# Sources

| id | tier | fetched | title | url | published |
|--|--|--|--|--|--|
| S001 | primary | 2026-08-21 | Old five-column row | https://a.example |
| S002 | primary | 2026-08-21 | Fetched today, written years ago | https://b.example | 2019-03-04 |
| S003 | primary | 2026-08-21 | Honestly undated page | https://c.example | undated |
'@ | Set-Content "$p\docs\SOURCES.md" -Encoding UTF8
    foreach ($id in @("S001","S002","S003")) { "x" | Set-Content "$p\docs\sources\$id-x.md" -Encoding UTF8 }
    "# D`n`nStatus: DRAFT`n`nCites [S001] [S002] [S003]." | Set-Content "$p\docs\DESIGN.md" -Encoding UTF8

    $ss = Join-Path $kit "source-stats.ps1"
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ss -ProjectDir $p -StaleDays 180 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0) "an old publication date must WARN, never FAIL - a blocking recency gate gets switched off"
    Assert ($out -match 'S002 was PUBLISHED') "a source published years before it was fetched went unnoticed - the whole point of the column"
    Assert ($out -notmatch 'S003 (was PUBLISHED|has an unparsable)') "'undated' is an honest answer and must not be nagged about"
    # BACKWARD COMPATIBILITY: the five-column row must still parse its own tier, or appending the column
    # silently corrupted every ledger in existence.
    Assert ($out -notmatch 'S001 has no tier') "a pre-0.19.1 five-column row lost its tier - the columns shifted"
    Assert ($out -match 'no published date in the ledger') "the missing-date report did not mention the old row"
    Assert ($out -notmatch 'S001.*S002.*S003') "missing dates must be reported ONCE in aggregate, not per source"

    # And the agents that WRITE rows must agree with the reader on the column order, or the gate polices a
    # format nothing produces.
    foreach ($a in @("research-agent.md","security-agent.md")) {
      $t = Get-Content (Join-Path $kit "global\agents\$a") -Raw
      Assert ($t -match 'published') "$a never mentions the published column it is supposed to fill"
      Assert ($t -match '(?i)undated') "$a is not told what to write when a page has no date, so it will guess one"
    }
  } finally { Remove-Sandbox $sb }
}

Test-Case "/research is wired, online, and owns only the corpus" {
  $r = Get-Content (Join-Path $kit "global\commands\research.md") -Raw
  Assert ($r -match 'research-agent') "/research does not spawn its agent"
  Assert ($r -match 'Task tool') "/research does not name the Task tool"
  Assert ($r -match '(?i)(source-stats\.ps1|dad source-stats)') "/research has no gate"
  Assert ($r -match 'ONLINE') "/research does not flag that it is the online mode"
  $a = Get-Content (Join-Path $kit "global\agents\research-agent.md") -Raw
  Assert ($a -match 'web_search' -and $a -match 'ingest_url') "research-agent lacks the web tools"
  # the human tiers sources - that judgement is the one thing no model should make here
  Assert ($a -match 'unknown.*Always|Always.*unknown') "research-agent is not forced to leave tier unknown"
  Assert ($a -match 'Never write to the design doc') "research-agent is not held to one-writer-per-doc"
  Assert ($a -match 'credentials or personal data') "research-agent has no rule about capturing secrets/PII"
  # doc-researcher must stay OFFLINE - two agents, two jobs
  $d = Get-Content (Join-Path $kit "global\agents\doc-researcher.md") -Raw
  Assert ($d -notmatch 'web_search') "doc-researcher gained web access - it is the offline corpus reader"
  # scaffold lays the corpus down so /research has somewhere to write
  Assert ((Get-Content (Join-Path $kit "new-project.ps1") -Raw) -match 'SOURCES\.md') "scaffold does not create SOURCES.md"
  Assert ((Get-Content (Join-Path $kit "new-project.ps1") -Raw) -match 'docs\\sources') "scaffold does not create docs\sources\"
  # and /design points back at it rather than inventing evidence
  Assert ((Get-Content (Join-Path $kit "global\commands\design.md") -Raw) -match '/research') "/design never mentions /research"
}

Test-Case "close-unit REFUSES to bank new work under an already-closed id" {
  # A real run produced a commit titled "T8.1: Implement ObjectStore" whose diff was VariantProcessor.cs
  # (T7.1's work), because close-unit does `git add -A` and banks whatever is dirty under whatever id it
  # is given. Then `t8.1` matched the already-ticked `T8.1`, took the idempotent path, and committed
  # T8.2's MetadataStore under a no-op close - leaving T8.2 open with its code already in history.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    New-Item -ItemType Directory -Force "$p\src" | Out-Null
    "# Task map`n`n## Tasks`n`n### [x] T8.1 - done thing   (Story S8)`n- **Goal:** x`n`n### [ ] T8.2 - other thing   (Story S8)`n- **Goal:** y" |
      Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "# Stories`n`n### Story S8: Eight   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    "# Project: t`n`n## Build / test`n- Build: ``exit 0```n- Test:  ``exit 0``" | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    # T8.2's work, offered up under the closed id T8.1
    "public class Other { }" | Set-Content "$p\src\Other.cs" -Encoding UTF8
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "close-unit.ps1") `
      -Id T8.1 -Title "wrong unit" -ProjectDir $p -NoReindex 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0) "it banked new code under an already-closed id"
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $log = (git log --oneline | Out-String)
    $ErrorActionPreference = $prev; Pop-Location
    Assert ($log -notmatch 'wrong unit') "it committed anyway"

    # lower-case id must not sneak past either - matching is case-insensitive
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "close-unit.ps1") `
      -Id t8.1 -Title "wrong unit lower" -ProjectDir $p -NoReindex 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0) "a lower-cased id got past the already-closed check"

    # closing it under the id that OWNS the work must still work
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "close-unit.ps1") `
      -Id T8.2 -Title "other thing" -ProjectDir $p -NoReindex | Out-Null
    Assert ($LASTEXITCODE -eq 0) "the correct id was refused too"
    Assert (Select-String "$p\docs\TASKS.md" -Pattern '^###\s*\[x\]\s*T8\.2' -Quiet) "T8.2 was not ticked"
  } finally { Remove-Sandbox $sb }
}

Test-Case "the stack is decided EARLY, and the record says so" {
  # Reversed 2026-08-13: 'late architecture' only deferred the blockers - no Build command means /build
  # Gate 1 refuses, close-unit verifies nothing, and library docs cannot be ingested before the libraries
  # are known (which is how 16 guessed Magick.NET calls shipped).
  $d = Get-Content (Join-Path $kit "global\commands\design.md") -Raw
  $steps = [regex]::Matches($d, '(?m)^(\d+)\. \*\*([^*]+)\*\*')
  Assert ($steps.Count -ge 5) "design.md no longer has numbered steps"
  $archStep = ($steps | Where-Object { $_.Groups[2].Value -match 'architecture' } | Select-Object -First 1)
  $reqStep  = ($steps | Where-Object { $_.Groups[2].Value -match 'requirements' } | Select-Object -First 1)
  Assert ($archStep -and $reqStep) "could not find the architecture and requirements steps"
  Assert ([int]$archStep.Groups[1].Value -lt [int]$reqStep.Groups[1].Value) `
    "architecture is step $($archStep.Groups[1].Value) but requirements is $($reqStep.Groups[1].Value) - stack must come FIRST"
  Assert ($d -notmatch '(?i)decided?\s+LATE') "design.md still says the stack is decided late"
  # Every surface, not just design.md. The reversal in 0.13.0 left the claim standing in FIVE other places
  # - new-project's closing advice, the README's mode table, /scaffold, /design's own frontmatter
  # description, and the heading of the very section the model fills in ("decide LATE - once requirements
  # are stable"). A rule reversed in one file and restated in six is not reversed.
  # EVERY markdown and script in the kit, not a hand-picked list. The previous version of this test named
  # six surfaces - and the reversed rule was then found in THREE MORE places it did not look
  # (templates/README.md twice, and the kit's own LOCKED docs/DESIGN.md). A regression test with a
  # hardcoded list of places to check is a test that only ever catches the bug you already found.
  $stale = @()
  $sweep = @(Get-KitFiles @("*.md","*.ps1")) + @(Get-ChildItem (Join-Path $kit "global") -Recurse -Filter *.md -File) +
           @(Get-ChildItem (Join-Path $kit "templates") -Recurse -Filter *.md -File)
  foreach ($p in ($sweep | Sort-Object FullName -Unique)) {
    if ($p.Name -eq "CHANGELOG.md") { continue }   # history: "decided late" WAS true before 0.13.0
    if ($p.Name -eq "test-kit.ps1") { continue }   # this test's own pattern strings
    foreach ($m in [regex]::Matches((Get-Content $p.FullName -Raw),
        '(?i)(decided?|choose|chosen|chooses|pick|picked|emerges?)\s+(the\s+)?(stack\s+|platform\s+|architecture\s+)?(LATE|later)\b')) {
      $stale += "$($p.Name) -> '$($m.Value)'"
    }
  }
  Assert ($stale.Count -eq 0) "the stack is decided FIRST, but these still say otherwise: $($stale -join '; ')"
  $des = Get-Content (Join-Path $kit "docs\DESIGN.md") -Raw
  Assert ($des -match 'EARLY architecture') "R7 still records late architecture"
  Assert ($des -notmatch 'late architecture') "R7 still contains the old 'late architecture' wording"
}

Test-Case "the API surface generator produces real signatures" {
  # The registry is only worth having if it carries EXACT signatures including generics - that is the whole
  # difference between it and grepping source. Generate it for the kit's OWN server and check the shape.
  if ($SkipBuild) { return }
  $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
  if (-not (Test-Path $exe)) { return }
  $sb = New-Sandbox
  try {
    $out = Join-Path $sb "API-SURFACE.md"
    & $exe --api-surface $kit $out | Out-Null
    Assert ($LASTEXITCODE -eq 0) "--api-surface exited $LASTEXITCODE"
    Assert (Test-Path $out) "no file written"
    $s = Get-Content $out -Raw
    Assert ($s -match '# API surface \(generated') "missing the generated header"
    Assert ($s -match '(?m)^### local-tools') "the kit's own assembly is missing"
    # its own public API must be there, with a real signature
    Assert ($s -match 'ApiSurface') "the ApiSurface type is missing from its own surface"
    Assert ($s -match 'Generate\(string projectDir') "signatures carry no parameter types"
    # generics must survive - the thing that cost 4h25m was generic type parameters
    Assert ($s -match '<') "no generic signatures at all - suspicious"
    Assert ($s -notmatch '(?m)^### System\.') "framework assemblies leaked in (index would be swamped)"
    # lookup mode must find a member and name its owner
    $hit = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "api-surface.ps1") `
             -ProjectDir $sb -Lookup "Generate" 2>&1 | Out-String
    # -ProjectDir $sb has no docs\ - point it at the file we just made instead
    New-Item -ItemType Directory -Force (Join-Path $sb "docs") | Out-Null
    Copy-Item $out (Join-Path $sb "docs\API-SURFACE.md") -Force
    $hit = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "api-surface.ps1") `
             -ProjectDir $sb -Lookup "Generate" 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0) "lookup found nothing for a member that exists"
    Assert ($hit -match 'Generate') "lookup output does not contain the member"
  } finally { Remove-Sandbox $sb }
}

Test-Case "a build failure hands over the real signatures" {
  # runA made ZERO search_datasheets calls, so a registry the model must REMEMBER to consult is worth
  # nothing. The compiler already names what it could not resolve; close-unit looks those up and prints
  # them in the failure, so the answer arrives without anyone choosing to ask for it.
  $cu = Get-Content (Join-Path $kit "close-unit.ps1") -Raw
  Assert ($cu -match 'function Show-Signatures') "close-unit has no signature lookup"
  Assert ($cu -match 'Show-Signatures \$r\.Output') "Show-Signatures is never called on a build failure"
  Assert ($cu -match 'CS\(\?:1501') "it does not key off the compiler's unresolved-symbol errors"
  Assert ($cu -match 'api-surface\.ps1') "close-unit does not regenerate the surface after a good build"
  # and the agent that writes the code has to be told it exists
  $dev = Get-Content (Join-Path $kit "global\agents\dev-agent.md") -Raw
  Assert ($dev -match 'API-SURFACE\.md') "dev-agent is not told about the API surface"
  Assert ($dev -match '(?i)(api-surface\.ps1|dad api-surface)') "dev-agent has no command to look a signature up"
}

Test-Case "scaffold and upgrade ignore .claude/ (agent worktrees are not source)" {
  # One project showed 313 changed paths, 247 of them agent worktrees under .claude/.
  foreach ($f in @("new-project.ps1","upgrade-project.ps1")) {
    $s = Get-Content (Join-Path $kit $f) -Raw
    Assert ($s -match '\.claude/') "$f does not add .claude/ to .gitignore"
  }
}

Test-Case "a stale pre-commit hook is REPAIRED, not reported healthy" {
  # The worst failure yet, because it fails CLOSED: a hook naming a scanner in a moved/renamed kit
  # aborts every commit in the project. install-hooks saw the string "scan-secrets.ps1" and returned
  # "already installed" without checking the path resolved - so upgrade-project never fixed it, and
  # dad-doctor reported [OK]. Three things agreed the project was fine while no commit could be made.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force $p | Out-Null
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q
    $ErrorActionPreference = $prev; Pop-Location

    # a hook from a kit that no longer lives there
    $hookPath = Join-Path $p ".git\hooks\pre-commit"
    New-Item -ItemType Directory -Force (Split-Path $hookPath) | Out-Null
    $stale = "#!/bin/sh`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"D:\gone\OLD-kit\scan-secrets.ps1`" -Staged -Quiet`n"
    [System.IO.File]::WriteAllText($hookPath, $stale, (New-Object System.Text.UTF8Encoding($false)))

    # NO -Force: repair must happen on the ordinary path, because that is what upgrade-project calls
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "install-hooks.ps1") -ProjectDir $p | Out-Null
    $now = Get-Content $hookPath -Raw
    Assert ($now -notmatch 'OLD-kit') "the stale hook was left pointing at a missing scanner"
    Assert ($now -match [regex]::Escape((Join-Path $kit "scan-secrets.ps1"))) "the hook was not repointed at this kit"

    # a HEALTHY hook must be left alone (no needless rewrites)
    $before = Get-Content $hookPath -Raw
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "install-hooks.ps1") -ProjectDir $p | Out-Null
    Assert ((Get-Content $hookPath -Raw) -eq $before) "a healthy hook was rewritten"

    # and a FOREIGN hook is still never hijacked
    [System.IO.File]::WriteAllText($hookPath, "#!/bin/sh`necho mine`n", (New-Object System.Text.UTF8Encoding($false)))
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "install-hooks.ps1") -ProjectDir $p | Out-Null
    Assert ((Get-Content $hookPath -Raw) -match 'echo mine') "a foreign pre-commit hook was overwritten"

    # dad-doctor must call a broken hook a FAILURE, not an OK
    $doc = Get-Content (Join-Path $kit "dad-doctor.ps1") -Raw
    Assert ($doc -match 'points at a MISSING scanner') "dad-doctor still reports any pre-commit file as healthy"
  } finally { Remove-Sandbox $sb }
}

Test-Case "upgrade-project repoints a project's .mcp.json at THIS kit" {
  # Nothing used to do this. install.ps1 rewrites only the .mcp.json files inside the KIT folder, so
  # moving or renaming the kit left every existing project launching local-tools.exe from a path that
  # might not exist - silently, because a dead MCP server just looks like "no search_datasheets".
  # Observed for real: a project still pointed at the pre-rename kit folder. DAD-RENAME-OK
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Project: t`n`n## Stack`n- x" | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    $stale = 'D:\somewhere\OLD-kit\local-tools\bin\Release\net8.0\local-tools.exe'
    $mcp = @{ mcpServers = @{ 'local-tools' = @{
      command = $stale; args = @(); env = @{ LOCALTOOLS_DOCS_DIR = "$p\docs" } } } } | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText("$p\.mcp.json", $mcp, (New-Object System.Text.UTF8Encoding($false)))

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "upgrade-project.ps1") $p 2>$null | Out-Null
    $j = Get-Content "$p\.mcp.json" -Raw | ConvertFrom-Json
    Assert ($j.mcpServers.'local-tools'.command -ne $stale) ".mcp.json still points at the old kit"
    Assert ($j.mcpServers.'local-tools'.command -like "$kit*") "exe path was not repointed at this kit: $($j.mcpServers.'local-tools'.command)"
    # the corpus is the PROJECT's - only the binary moves
    Assert ($j.mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR -like "$p*") "the project's docs dir was clobbered"
    # no BOM: Node reads this file
    $bytes = [System.IO.File]::ReadAllBytes("$p\.mcp.json")
    Assert (-not ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB)) ".mcp.json was written with a BOM"
  } finally { Remove-Sandbox $sb }
}

Test-Case "dad-doctor's fix hints name commands that actually fix the thing" {
  $doc = Get-Content (Join-Path $kit "dad-doctor.ps1") -Raw
  # install.cmd does NOT touch a project's .mcp.json - suggesting it sent you in a circle.
  Assert ($doc -notmatch '\.mcp\.json.*re-run install\.cmd') "the .mcp.json hint still points at install.cmd, which cannot fix it"
  Assert ($doc -match 'upgrade-project\.cmd.*\.mcp\.json|\.mcp\.json.*upgrade-project\.cmd') "the .mcp.json hint does not name upgrade-project"
  # and the same bare-command defect the guard had must not live on here
  Assert ($doc -notmatch 'close-unit\.cmd -Id <id>') "dad-doctor still hands out bare close-unit.cmd (not on PATH)"
}

Test-Case "dad-doctor flags a stale kit path and checks the current project by default" {
  # After a machine move, a project's .mcp.json + git hook still name the OLD kit location: the MCP server
  # silently never starts and every commit aborts (cms3 hit both). The doctor's project checks catch this -
  # but they only ran with -ProjectDir, and the .mcp.json message did not distinguish a MISSING path from a
  # different kit. Now it names the missing path and routes to upgrade-project, and it checks the project
  # you are STANDING in when no -ProjectDir is passed.
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Project: t`n`n## Stack`n- x" | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    $stale = 'D:\gone\OLD-kit\local-tools\bin\Release\net8.0\local-tools.exe'
    $mcp = @{ mcpServers = @{ 'local-tools' = @{
      command = $stale; args = @(); env = @{ LOCALTOOLS_DOCS_DIR = "$p\docs" } } } } | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText("$p\.mcp.json", $mcp, (New-Object System.Text.UTF8Encoding($false)))

    # explicit -ProjectDir: the stale exe path is named as missing, and the fix is upgrade-project
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "dad-doctor.ps1") -ProjectDir $p 2>&1 | Out-String
    Assert ($out -match '(?i)does NOT exist|stale after a move') "doctor did not flag the stale .mcp.json kit path as missing"
    Assert ($out -match 'upgrade-project') "doctor did not name upgrade-project as the fix for the stale path"

    # no -ProjectDir, run from INSIDE the project: it auto-detects and still flags the break
    Push-Location $p
    $auto = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "dad-doctor.ps1") 2>&1 | Out-String
    Pop-Location
    Assert ($auto -match '(?i)auto-detected the current directory') "doctor did not auto-detect the project it was standing in"
    Assert ($auto -match '(?i)does NOT exist|stale after a move') "the auto-detected run did not flag the stale .mcp.json"

    # but the doctor must NOT treat the KIT's own folder as a project to onboard (it self-hosts a .mcp.json)
    Push-Location $kit
    $kitRun = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "dad-doctor.ps1") 2>&1 | Out-String
    Pop-Location
    Assert ($kitRun -notmatch '(?i)auto-detected the current directory') "doctor wrongly auto-detected the kit folder as a project"
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
    Assert ((Get-Content (Join-Path $kit "global\commands\audit.md") -Raw) -match '(?i)(doc-stats\.ps1" -UpdateStatus|dad doc-stats -UpdateStatus)') `
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
    Assert ($cm -match '## Hybrid') "Hybrid section not added to a project that never had it"
    Assert ($cm -match 'local_generate') "Hybrid section does not mention local_generate"
    Assert ($cm -match '(?i)\[LOCAL DRAFT') "Hybrid section drops the honesty-fence wording (the draft label)"
    Assert ($cm -notmatch '__DESIGN_DOC__') "token not resolved"
    Assert ($cm -notmatch 'old wording that must be replaced') "stale Modes body survived"
    foreach ($f in @("docs\STATUS.md", "docs\RECIPES.md")) { Assert (Test-Path (Join-Path $p $f)) "missing $f" }
    $before = $cm
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kit "upgrade-project.ps1") $p | Out-Null
    Assert ((Get-Content "$p\CLAUDE.md" -Raw) -eq $before) "not idempotent"
  } finally { Remove-Sandbox $sb }
}

Test-Case "dev-agent and qa-agent are ACTUALLY wired for hybrid, not just told about it in CLAUDE.md" {
  # A subagent is restricted to only the tools in its OWN frontmatter (R32 in DESIGN.md - "a subagent is an
  # unguarded, unobservable region"). CLAUDE.md telling every session local_generate exists is not enough for
  # a SUBAGENT to actually call it - the grant has to be on the agent file itself, the same lesson that made
  # corpus-agent need an explicit ingest_url/web_search grant, not just prose. Check both halves: the tool
  # grant (frontmatter) and an explicit instruction (subagents do not discover capabilities from ambient
  # context - search_datasheets was called ZERO times across nine graded runs until agents were told to use it).
  foreach ($name in @("dev-agent", "qa-agent")) {
    $path = Join-Path $kit "global\agents\$name.md"
    Assert (Test-Path $path) "$name.md is missing"
    $txt = Get-Content $path -Raw
    $toolsLine = ([regex]::Match($txt, '(?m)^tools:\s*(.*)$')).Groups[1].Value
    Assert ($toolsLine -match 'mcp__local-tools__local_generate') "$name.md's tools: frontmatter does not grant local_generate - it cannot call the tool even if it knows about it"
    Assert ($txt -match '(?i)HYBRID') "$name.md has no explicit HYBRID-mode instruction - a subagent will not discover local_generate on its own"
    Assert ($txt -match '(?i)\[LOCAL DRAFT') "$name.md does not carry the honesty-fence wording (draft label) - risks banking unverified local output"
  }
  # And the two agents this session deliberately did NOT wire (their job is judgment/citation, not drudge
  # generation) should stay that way - delegating grading/analysis to a weak local model is the opposite of
  # this kit's thesis. A future accidental wildcard grant would silently violate that; catch it here.
  foreach ($name in @("grade-agent", "security-agent", "architect-agent")) {
    $txt = Get-Content (Join-Path $kit "global\agents\$name.md") -Raw
    $toolsLine = ([regex]::Match($txt, '(?m)^tools:\s*(.*)$')).Groups[1].Value
    Assert ($toolsLine -notmatch 'local_generate') "$name.md was granted local_generate - this agent's job is judgment/citation, not drudge-work; delegating it to a local model is out of scope"
  }
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

Test-Case "a build FILE-LOCK is cleared (project-scoped) and the build retried" {
  # Measured: a left-over apphost (a `dotnet run` nobody stopped) held bin\app.exe, so `dotnet build` failed
  # with MSB3026 / "being used by another process" seven times and the model could not clear it. free-locks
  # kills only processes running from THIS project's folder - safe on any machine - and close-unit clears
  # the lock and retries the build once before declaring failure.
  $fl = Join-Path $kit "free-locks.ps1"
  Assert (Test-Path $fl) "free-locks.ps1 is missing"
  Assert (Test-Path (Join-Path $kit "free-locks.cmd")) "free-locks.cmd wrapper is missing"

  # SAFETY is structural: it must scope by PROJECT PATH, never kill by image name alone (that could hit
  # Ollama, Claude Code, or the user's other work). Assert the scoping is in the source and no blanket kill.
  $src = Get-Content $fl -Raw
  Assert ($src -match 'StartsWith\(\$projPrefix') "free-locks does not scope kills to the project path"
  Assert ($src -notmatch 'Stop-Process\s+-Name') "free-locks kills by image NAME - that could hit unrelated processes"
  Assert ($src -match '(?i)REFUS') "free-locks has no guard against a too-broad project path"

  # refuses a shallow / non-project path
  & powershell -NoProfile -ExecutionPolicy Bypass -File $fl -ProjectDir $env:SystemRoot 2>&1 | Out-Null
  Assert ($LASTEXITCODE -eq 2) "free-locks operated on a system path - the guard failed"

  # clean project, nothing running -> nothing to free, exit 0
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Project: t" | Set-Content "$p\CLAUDE.md" -Encoding UTF8
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $fl -ProjectDir $p 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0) "free-locks failed on a clean project"
    Assert ($out -match '(?i)nothing to free') "free-locks did not report a clean project cleanly"

    # close-unit: a build that reports MSB3026 must trigger the clear-and-retry path, and (still failing)
    # report the lock specifically rather than the generic 'fix the build'.
    if ($haveGit) {
      "# Project: t`n`n## Build / test`n- Build: ``cmd /c ""echo error MSB3026: could not copy app.exe - being used by another process & exit 1""```n- Test:  ``exit 0``" |
        Set-Content "$p\CLAUDE.md" -Encoding UTF8
      "# Tasks`n`n## Tasks`n`n### [ ] T1.1 - a   (Story S1)`n- **Goal:** x" | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
      "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
      Push-Location $p
      $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
      git init -q; git config core.autocrlf false
      git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
      $ErrorActionPreference = $prev; Pop-Location
      $cu = Join-Path $kit "close-unit.ps1"
      $co = & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "a" -ProjectDir $p -NoReindex 2>&1 | Out-String
      Assert ($LASTEXITCODE -ne 0) "close-unit closed a unit whose build stayed locked"
      Assert ($co -match '(?i)FILE LOCK') "close-unit did not recognise the lock signature"
      Assert ($co -match '(?i)retrying the build') "close-unit did not retry the build after clearing"
      Assert ($co -match '(?i)free-locks|Still locked') "close-unit did not point at the lock remedy"
    }
  } finally { Remove-Sandbox $sb }

  # the agents that run builds must carry the prevention rule (test in-process; do not leave the app up)
  foreach ($f in @("global\agents\qa-agent.md","global\agents\dev-agent.md")) {
    $t = Get-Content (Join-Path $kit $f) -Raw
    Assert ($t -match '(?i)free-locks') "$f does not mention free-locks"
    Assert ($t -match '(?i)in-process|WebApplicationFactory|leave.{0,20}running|dotnet run') "$f does not warn against leaving the app running"
  }
}

Test-Case "an environment block is named as such, and security-tampering is forbidden" {
  # Measured, CMS run: Windows App Control refused to run the built test DLL. qa-agent, with no instruction
  # for this case, spent the session trying to STOP the Application Identity service, add Defender
  # exclusions, and disable AppLocker/WDAC. A build/test failure carrying that signature is ENVIRONMENTAL,
  # not a code failure, and the response must be STOP-and-report, never lower the machine's security.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    # a build command that PRINTS the App Control signature and fails, so close-unit's build path sees it
    "# Project: t`n`n## Build / test`n- Build: ``cmd /c ""echo This program is blocked by Windows App Control policy & exit 1""```n- Test:  ``exit 0``" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    "# Tasks`n`n## Tasks`n`n### [ ] T1.1 - a   (Story S1)`n- **Goal:** x" | Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $cu = Join-Path $kit "close-unit.ps1"
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "a" -ProjectDir $p -NoReindex 2>&1 | Out-String
    Assert ($LASTEXITCODE -ne 0) "close-unit closed a unit whose build was blocked"
    Assert ($out -match '(?i)ENVIRONMENT BLOCK') "a policy block was reported as an ordinary build failure"
    Assert ($out -match '(?is)(disable|stop).{0,80}service') "the block notice does not forbid stopping a service"
    Assert ($out -match '(?i)Defender') "the block notice does not forbid Defender exclusions"
    Assert ($out -match '(?i)human') "the block notice does not say it is the human's decision"
    # and it must NOT offer the ordinary 'fix the build' advice, which sends the model back to churn on code
    Assert ($out -notmatch '(?i)Fix the build, then re-run') "it told the model to fix code for an environment block"

    # a NORMAL build failure must still get the ordinary path, not be mislabelled as environmental
    "# Project: t`n`n## Build / test`n- Build: ``cmd /c ""echo error CS1002 syntax & exit 1""```n- Test:  ``exit 0``" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Push-Location $p; git add -A; git -c user.name=t -c user.email=t@t commit -q -m b2; Pop-Location
    $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "a" -ProjectDir $p -NoReindex 2>&1 | Out-String
    Assert ($out2 -notmatch '(?i)ENVIRONMENT BLOCK') "an ordinary compile error was mislabelled as an environment block"
    Assert ($out2 -match '(?i)Fix the build') "an ordinary build failure lost its normal guidance"
  } finally { Remove-Sandbox $sb }

  # the prose surfaces must carry the rule too - close-unit is the gate, but the agents act before it runs
  foreach ($f in @("global\agents\qa-agent.md","global\agents\dev-agent.md","global\commands\build.md")) {
    $t = Get-Content (Join-Path $kit $f) -Raw
    Assert ($t -match '(?i)App Control|AppLocker|WDAC') "$f does not mention the security-block signature"
    Assert ($t -match '(?i)(never|do not|not).{0,60}(disable|stop|exclusion|admin|policy)') "$f does not forbid the security-tampering workaround"
  }
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

Test-Case "close-unit REFUSES to close when no Build command resolves (no -SkipVerify)" {
  # A.2: a missing/unparseable Build: line used to print a yellow WARNING and then close ANYWAY - no
  # -SkipVerify required. That is how haiku's close-out (ModelTest bake-off) proceeded unverified: CLAUDE.md
  # had no root package.json to build, Get-ClaudeCommand resolved to "", and close-unit ticked + committed
  # regardless. -SkipVerify must be the ONLY way past verification.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Task map`n`n## Tasks`n`n### [ ] T1.1 - thing   (Story S1)`n- **Goal:** x" |
      Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    # the unfilled placeholder the template ships - Get-ClaudeCommand rejects it and returns ""
    "# Project: t`n`n## Build / test`n- Build: ``<set in /design's architecture step>```n- Test:  ``<set in /design's architecture step>``" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $cu = Join-Path $kit "close-unit.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "thing" -ProjectDir $p -NoReindex 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0) "close-unit closed with no Build command resolved and no -SkipVerify"
    Assert (-not (Select-String "$p\docs\TASKS.md" -Pattern '^###\s*\[x\]' -Quiet)) "it ticked the task anyway"
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    $log = (git log --oneline | Out-String)
    $ErrorActionPreference = $prev; Pop-Location
    Assert ($log -notmatch 'T1\.1') "it committed anyway"

    # -SkipVerify remains the deliberate, explicit escape hatch and still works
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "thing" -ProjectDir $p -NoReindex -SkipVerify | Out-Null
    Assert ($LASTEXITCODE -eq 0) "-SkipVerify did not close the unit"
    Assert (Select-String "$p\docs\TASKS.md" -Pattern '^###\s*\[x\]\s*T1\.1' -Quiet) "-SkipVerify did not tick the task"
  } finally { Remove-Sandbox $sb }
}

Test-Case "Get-ClaudeCommand extracts a backtick-quoted Build command even with trailing prose" {
  # A.1: the old regex required ONLY whitespace after the closing backtick, so a realistic line like
  # "- Build: `npm run build` (root workspace)" failed to match AT ALL and returned "" - verified against
  # both bake-off projects (haiku/CLAUDE.md, opus/CLAUDE.md), which both pin commands shaped exactly like
  # this. Prove the REAL close-unit.ps1 now extracts the bare command and ignores the trailing parenthetical.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    "# Task map`n`n## Tasks`n`n### [ ] T1.1 - thing   (Story S1)`n- **Goal:** x" |
      Set-Content "$p\docs\TASKS.md" -Encoding UTF8
    "# Stories`n`n### Story S1: One   <!-- Status: TODO -->" | Set-Content "$p\docs\STORIES.md" -Encoding UTF8
    # benign commands (exit 0 / a fake test count) so build+test trivially pass - only the PARSING is under
    # test. This is the LAST task of its only story, so the close also verifies tests - Test: needs a
    # parseable count, not just an exit code.
    "# Project: t`n`n## Build / test`n- Build: ``exit 0`` (root workspace)`n- Test:  ``cmd /c echo Total: 1`` (root workspace)" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $cu = Join-Path $kit "close-unit.ps1"
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "thing" -ProjectDir $p -NoReindex 2>&1 | Out-String
    Assert ($out -notmatch '(?i)no build command found') "trailing prose after the backtick still defeats extraction"
    Assert ($out -match '(?im)^\[close-unit\] build: exit 0\s*$') "extracted command is not the bare 'exit 0' (trailing parenthetical leaked into it)"
    Assert ($LASTEXITCODE -eq 0) "close-unit did not close even though the extracted build command passes"
    Assert (Select-String "$p\docs\TASKS.md" -Pattern '^###\s*\[x\]\s*T1\.1' -Quiet) "did not tick after a passing build extracted from a trailing-prose line"
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
    # Build/Test must resolve here: A.2 made an unresolved Build: line FATAL, and two of these closes
    # (T1.2 -> S1 roll-up, T2.1 -> S2 roll-up) are story closes, which also demand a parseable test count.
    "# Project: t`n`n## Build / test`n- Build: ``exit 0```n- Test:  ``cmd /c echo Total: 1``" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
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

Test-Case "the KIT's OWN CLAUDE.md satisfies close-unit's Get-ClaudeCommand 'Build' parser" {
  # All other close-unit fixtures use a synthetic CLAUDE.md shaped exactly right - none ever checked the
  # KIT's own root CLAUDE.md, which is why its "- C# server: ..." bullet (not "- Build:") went undetected:
  # every unit closed against this repo (T4.1-T5.1, S4, S5) silently skipped build verification. Copy the
  # REAL file into a sandbox and assert Get-ClaudeCommand actually finds it - not a re-implementation of
  # the regex, the real close-unit.ps1 run against the kit's real CLAUDE.md text.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    Copy-Item (Join-Path $kit "CLAUDE.md") (Join-Path $p "CLAUDE.md")
    @"
# Task map

## Build order
T1.1

## Tasks

### [ ] T1.1 - first   (Story S1)
- **Goal:** a
"@ | Set-Content "$p\docs\TASKS.md" -Encoding UTF8 -NoNewline
    @"
# Stories

### Story S1: First story   (Epic E1)   <!-- Status: TODO -->
- **Goal:** one
"@ | Set-Content "$p\docs\STORIES.md" -Encoding UTF8 -NoNewline
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $cu = Join-Path $kit "close-unit.ps1"
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "first" -ProjectDir $p -NoReindex 2>&1 | Out-String
    Assert ($out -notmatch 'no build command found') "close-unit still cannot find a Build command in the kit's own real CLAUDE.md"
    Assert ($out -match '(?i)build:\s*dotnet build') "close-unit did not extract the real 'dotnet build ...' command from the kit's own CLAUDE.md"
  } finally { Remove-Sandbox $sb }
}

Test-Case "close-unit writes TASKS.md/STORIES.md back as LF, never CRLF" {
  # Save-Text used to hardcode `r`n regardless of the target file's .gitattributes convention (both
  # TASKS.md and STORIES.md are `* text=auto eol=lf`). git's own status/diff never caught it - the
  # eol=lf clean filter normalizes CRLF away when computing the staged/committed blob, so the commit
  # looked fine while the WORKING TREE copy was silently re-CRLF'd on every tick. Found via self-hosting
  # (dogfooding /build against this kit's own docs/TASKS.md). Assert on raw bytes, not git's view.
  if (-not $haveGit) { return }
  $sb = New-Sandbox
  try {
    $p = Join-Path $sb "proj"; New-Item -ItemType Directory -Force "$p\docs" | Out-Null
    @"
# Task map

## Build order
T1.1

## Tasks

### [ ] T1.1 - first   (Story S1)
- **Goal:** a
"@ | Set-Content "$p\docs\TASKS.md" -Encoding UTF8 -NoNewline
    @"
# Stories

### Story S1: First story   (Epic E1)   <!-- Status: TODO -->
- **Goal:** one
"@ | Set-Content "$p\docs\STORIES.md" -Encoding UTF8 -NoNewline
    # T1.1 is the last task of the only story, so this close also verifies tests (needs a parseable count).
    "# Project: t`n`n## Build / test`n- Build: ``exit 0```n- Test:  ``cmd /c echo Total: 1``" |
      Set-Content "$p\CLAUDE.md" -Encoding UTF8
    Push-Location $p
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    git init -q; git config core.autocrlf false
    git add -A; git -c user.name=t -c user.email=t@t commit -q -m base
    $ErrorActionPreference = $prev; Pop-Location

    $cu = Join-Path $kit "close-unit.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cu -Id T1.1 -Title "first" -ProjectDir $p -NoReindex | Out-Null
    Assert ($LASTEXITCODE -eq 0) "T1.1 close failed"

    foreach ($f in @("$p\docs\TASKS.md", "$p\docs\STORIES.md")) {
      $t = [System.IO.File]::ReadAllText($f)
      $crlf = ([regex]::Matches($t, "`r`n")).Count
      $lf = ([regex]::Matches($t, "(?<!`r)`n")).Count
      Assert ($crlf -eq 0) "$(Split-Path $f -Leaf) has $crlf CRLF line ending(s) after close-unit wrote it - Save-Text regressed"
      Assert ($lf -gt 0) "$(Split-Path $f -Leaf) has no line endings at all after close-unit wrote it - something else broke"
    }
  } finally { Remove-Sandbox $sb }
}

Test-Case "the hybrid local_generate tool is GATED on LOCALTOOLS_HYBRID (Program.cs), and labels its output a draft" {
  # The whole point of hybrid: the local drudge tool exists ONLY when the flag is on. If Program.cs ever went
  # back to assembly scanning, HybridTools would be exposed unconditionally - handing the weak local model a job
  # that local/cloud mode deliberately keeps on the cloud brain. Guard that statically (no build needed).
  $prog = Get-Content (Join-Path $kit "local-tools\Program.cs") -Raw
  Assert ($prog -match 'Rag\.HybridEnabled') "Program.cs does not gate registration on Rag.HybridEnabled"
  Assert ($prog -match 'WithTools<HybridTools>') "Program.cs does not conditionally register HybridTools"
  Assert ($prog -notmatch 'WithToolsFromAssembly') "Program.cs uses assembly scanning - that would expose HybridTools UNconditionally"
  $hy = Get-Content (Join-Path $kit "local-tools\HybridTools.cs") -Raw
  Assert ($hy -match '(?i)DRAFT') "HybridTools.cs does not label local_generate output a DRAFT (the honesty fence)"
  $rag = Get-Content (Join-Path $kit "local-tools\Rag.cs") -Raw
  Assert ($rag -match 'LOCALTOOLS_HYBRID') "Rag.cs does not read LOCALTOOLS_HYBRID for HybridEnabled"
}

Test-Case "install + doctor wire three modes (local / cloud / hybrid) and toggle LOCALTOOLS_HYBRID cleanly" {
  # local = Ollama redirect; cloud = Anthropic loop, GPU still runs RAG (support models VERIFIED); hybrid = cloud
  # loop PLUS LOCALTOOLS_HYBRID=1 (local_generate). The flag must be SET for hybrid and CLEARED otherwise, so
  # re-installing as cloud/local turns the local tool off instead of leaving a stale marker.
  $inst = Get-Content (Join-Path $kit "install.ps1") -Raw
  Assert ($inst -match '\[switch\]\$Hybrid') "install.ps1 has no -Hybrid switch"
  Assert ($inst -match '\$cloudLoop\s*=\s*\$Cloud\s*-or\s*\$Hybrid') "install.ps1 does not run the cloud agent loop for -Hybrid"
  Assert ($inst -match 'Add-Member\s+-NotePropertyName\s+"LOCALTOOLS_HYBRID"\s+-NotePropertyValue\s+"1"') "install.ps1 -Hybrid does not SET LOCALTOOLS_HYBRID=1 via Add-Member"
  Assert ($inst -notmatch '\$s\.env\.LOCALTOOLS_HYBRID\s*=\s*"1"') "install.ps1 uses plain dot-assignment to CREATE LOCALTOOLS_HYBRID - throws on a fresh settings.json (0.48.0's actual shipped bug); use Add-Member -Force"
  Assert ($inst -match 'Remove\("LOCALTOOLS_HYBRID"\)') "install.ps1 does not CLEAR a stale LOCALTOOLS_HYBRID for cloud/local"
  Assert ($inst -match 'Ensure-OllamaModel') "install.ps1 cloud/hybrid does not verify the Ollama support models are pulled"
  $doc = Get-Content (Join-Path $kit "dad-doctor.ps1") -Raw
  Assert ($doc -match '\$hybridMode') "dad-doctor does not detect hybrid mode"
  Assert ($doc -match 'local_generate') "dad-doctor does not report / verify the local_generate co-processor"
  Assert ($doc -match '\$env:LOCALTOOLS_HYBRID\s*=\s*"1"') "dad-doctor does not set the flag to VERIFY the tool is exposed (not just that the marker is set)"
}

Test-Case "settings.json env can gain LOCALTOOLS_HYBRID (a NEW key) without throwing - 0.48.0's real install bug" {
  # 0.48.0 shipped `$s.env.LOCALTOOLS_HYBRID = "1"`. Plain dot-assignment on a ConvertFrom-Json PSCustomObject
  # can only OVERWRITE an EXISTING property - it cannot CREATE one, and throws "The property 'X' cannot be
  # found on this object. Verify that the property exists and can be set." settings.json's env block has no
  # LOCALTOOLS_HYBRID key by default (by design - -Hybrid is what adds it), so every real -Hybrid install hit
  # this. A text-match test ('LOCALTOOLS_HYBRID\s*=\s*"1"') PASSED anyway, because the broken line matched its
  # own regex - a grep cannot catch a runtime exception. This test actually RUNS the mutation, against the
  # REAL settings.json (not a hand-built fixture, which could accidentally include the key and hide the bug).
  $settingsPath = Join-Path $kit "settings.json"
  Assert (Test-Path $settingsPath) "settings.json is missing"
  $s = Get-Content $settingsPath -Raw | ConvertFrom-Json
  Assert (-not ($s.env.PSObject.Properties.Name -contains "LOCALTOOLS_HYBRID")) `
    "settings.json already has a LOCALTOOLS_HYBRID key - this test needs a key that does NOT exist yet to prove the fix path"

  $threw = $false; $errMsg = ""
  try { $s.env | Add-Member -NotePropertyName "LOCALTOOLS_HYBRID" -NotePropertyValue "1" -Force -ErrorAction Stop }
  catch { $threw = $true; $errMsg = $_.Exception.Message }
  Assert (-not $threw) "Add-Member threw creating a new property on the real settings.json env object: $errMsg"
  Assert ($s.env.LOCALTOOLS_HYBRID -eq "1") "the property was added but is not readable back as '1'"

  # Round-trip through JSON too - Add-Member's NoteProperty must actually serialize (it does; ConvertTo-Json
  # walks NoteProperties same as any other), so a future refactor that swaps in a non-serializing trick is caught.
  $rt = ($s | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
  Assert ($rt.env.LOCALTOOLS_HYBRID -eq "1") "LOCALTOOLS_HYBRID did not survive a ConvertTo-Json/ConvertFrom-Json round-trip"
}

Test-Case "S7's pricing-sentence language landed in both stories.md and design.md" {
  # T7.1/T7.2 added a pricing ask to /stories (per-epic expand loop) and /design (new requirement/epic with
  # no stories yet), mirroring the existing 4b pricing sentence shape. Presence/shape check on prose content
  # only - not a behavioral test - same pattern as the other prompt-content Test-Cases in this file.
  $stories = Get-Content (Join-Path $kit "global\commands\stories.md") -Raw
  Assert ($stories -match "keep scoping the next") "stories.md is missing the T7.1 pricing sentence's 'keep scoping the next' phrasing"
  Assert ($stories -match "Build what's already\s+scoped") "stories.md is missing the T7.1 pricing sentence's 'Build what's already scoped' phrasing"

  $design = Get-Content (Join-Path $kit "global\commands\design.md") -Raw
  Assert ($design -match "aren't\s+priced yet") "design.md is missing the T7.2 pricing sentence's 'aren't priced yet' phrasing"
}

# ---------------------------------------------------------------- server
if (-not $SkipBuild) {
  Write-Host "-- server --" -ForegroundColor Cyan

  Test-Case "local-tools builds (Release)" {
    $out = dotnet build (Join-Path $kit "local-tools\local-tools.csproj") -c Release --nologo -v q 2>&1 | Out-String
    Assert ($out -match "Build succeeded") "build failed: $($out.Trim())"
  }

  # Launch the MCP server, ask tools/list, return the tool-name array. `$childEnv` overrides go to the CHILD
  # only (via ProcessStartInfo), and LOCALTOOLS_HYBRID is cleared unless the caller sets it - so the base tool
  # list is deterministic even when the suite runs in a hybrid shell.
  function Get-McpToolList([string]$exe, [hashtable]$childEnv = @{}) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe; $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.EnvironmentVariables.Remove("LOCALTOOLS_HYBRID") | Out-Null
    foreach ($k in $childEnv.Keys) { $psi.EnvironmentVariables[$k] = [string]$childEnv[$k] }
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
      return ,$tools
    } finally { try { $proc.Kill() } catch {} }
  }

  Test-Case "MCP server advertises the expected tools" {
    $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
    Assert (Test-Path $exe) "exe not found"
    $expected = @("describe_image","detect_objects","index_datasheets","ingest_url","list_datasheets",
                  "search_datasheets","transcribe_audio","web_search")
    $tools = Get-McpToolList $exe                    # hybrid OFF (helper clears LOCALTOOLS_HYBRID)
    $diff = Compare-Object ($tools | Sort-Object) $expected
    Assert (-not $diff) "tools mismatch. got: $($tools -join ', ')"
  }

  Test-Case "HYBRID mode exposes local_generate; it is ABSENT in local/cloud" {
    # The 5080-as-a-drudge-tool for the cloud model. It must appear ONLY when LOCALTOOLS_HYBRID is set (which
    # install.ps1 -Hybrid does), and must NOT leak into the default tool set - so a local/cloud install cannot
    # accidentally hand the weak local model a job the mode exists to keep on the cloud brain.
    $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
    Assert (Test-Path $exe) "exe not found"
    $off = Get-McpToolList $exe
    Assert ($off -notcontains 'local_generate') "local_generate leaked into the default (non-hybrid) tool set: $($off -join ', ')"
    Assert ($off.Count -eq 8) "expected 8 base tools without hybrid, got $($off.Count)"
    $on = Get-McpToolList $exe @{ LOCALTOOLS_HYBRID = "1" }
    Assert ($on -contains 'local_generate') "LOCALTOOLS_HYBRID=1 did not expose local_generate. got: $($on -join ', ')"
    Assert ($on.Count -eq 9) "expected 9 tools with hybrid on, got $($on.Count)"
  }

  Test-Case "CLI --reindex on an empty folder exits 0" {
    $sb = New-Sandbox
    try {
      & (Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe") --reindex $sb | Out-Null
      Assert ($LASTEXITCODE -eq 0) "exit $LASTEXITCODE"
    } finally { Remove-Sandbox $sb }
  }

  Test-Case "CLI --ingest targets the GIVEN root, not the open project (corpus scope)" {
    # The bug: the ingest_url MCP tool writes to whatever root the server STARTED in (a project's docs\web\),
    # because WebDir is fixed from LOCALTOOLS_DOCS_DIR at startup and a per-call env change cannot move it - so
    # a /corpus refresh landed its fetches in whatever project was open, not the corpus. --ingest <url> <root>
    # is the shell door 'dad corpus ingest' uses to route the fetch (and reindex) to the CHOSEN root. Proof
    # without a network: IngestUrlAsync creates <root>\web BEFORE fetching, so an offline .invalid URL shows
    # web\ appearing under the corpus even while LOCALTOOLS_DOCS_DIR points at a 'project'.
    $exe = Join-Path $kit "local-tools\bin\Release\net8.0\local-tools.exe"
    if (-not (Test-Path $exe)) { return }
    & $exe --ingest 2>&1 | Out-Null
    Assert ($LASTEXITCODE -ne 0) "--ingest with no url should print usage and exit non-zero"
    $sb = New-Sandbox
    $prev = $env:LOCALTOOLS_DOCS_DIR
    try {
      $project = Join-Path $sb "project-docs"; $corpus = Join-Path $sb "corpus"
      New-Item -ItemType Directory -Force $project, $corpus | Out-Null
      $env:LOCALTOOLS_DOCS_DIR = $project           # stand in for the project the MCP server started in
      & $exe --ingest "http://drdad-nonexistent.invalid/page" $corpus | Out-Null
      Assert (Test-Path (Join-Path $corpus "web")) "--ingest did not route the fetch into the GIVEN corpus root"
      Assert (-not (Test-Path (Join-Path $project "web"))) "--ingest wrote into the open PROJECT, not the corpus (the bug)"
    } finally {
      if ($null -ne $prev) { $env:LOCALTOOLS_DOCS_DIR = $prev } else { Remove-Item Env:\LOCALTOOLS_DOCS_DIR -ErrorAction SilentlyContinue }
      Remove-Sandbox $sb
    }
  }

  Test-Case "this suite's expected tool list matches Tools.cs" {
    # Catches "added a tool but forgot the test" drift in the other direction.
    $declared = ([regex]::Matches((Get-Content (Join-Path $kit "local-tools\Tools.cs") -Raw),
                 'McpServerTool\(Name\s*=\s*"([^"]+)"')).ForEach({ $_.Groups[1].Value }) | Sort-Object
    $expected = @("describe_image","detect_objects","index_datasheets","ingest_url","list_datasheets",
                  "search_datasheets","transcribe_audio","web_search") | Sort-Object
    $diff = Compare-Object $declared $expected
    Assert (-not $diff) "Tools.cs declares: $($declared -join ', ')"
    # The hybrid drudge tool lives in its OWN file (HybridTools.cs), so the base list above stays clean and the
    # gated tool cannot silently join it. That file must declare exactly local_generate.
    $hy = ([regex]::Matches((Get-Content (Join-Path $kit "local-tools\HybridTools.cs") -Raw),
                 'McpServerTool\(Name\s*=\s*"([^"]+)"')).ForEach({ $_.Groups[1].Value }) | Sort-Object
    Assert (-not (Compare-Object $hy @("local_generate"))) "HybridTools.cs declares: $($hy -join ', ')"
  }

  Test-Case "kit CLAUDE.md points its validation gate at this suite" {
    $claude = Get-Content (Join-Path $kit "CLAUDE.md") -Raw
    Assert ($claude -match 'test-kit\.ps1') "CLAUDE.md's validation gate does not reference test-kit.ps1"
  }

  Test-Case "docs\ holds no stray HTML - it is markdown, and local-tools indexes it PLAINTEXT" {
    # 0.48.2 accidentally shipped docs/index.html and docs/series.html (36KB + 23KB) - standalone exports
    # of the Field Manual / Video Series artifacts, written there by a working-directory mixup during an
    # unrelated task, then swept into the commit by `git add -A` without being scrutinized. Two real costs:
    # they would have bloated/polluted the kit's OWN RAG corpus (search_datasheets chunks docs/ as plain
    # text - a 36KB marketing page is pure noise there), and they shipped inside the distributable package
    # kit source (docs\ is never excluded by package-kit.ps1). The kit's docs are markdown by design; an
    # .html file under docs\ is always a foreign artifact that does not belong in version control here.
    $strayHtml = @(Get-ChildItem (Join-Path $kit "docs") -Recurse -Filter "*.html" -ErrorAction SilentlyContinue)
    Assert ($strayHtml.Count -eq 0) "stray .html file(s) under docs\: $($strayHtml.FullName -join ', ') - these do not belong in the kit's own docs (markdown only); move them out and re-commit"
  }

  Test-Case "examples\cms3 ships a README but NOT the compiled binaries into git history" {
    # examples/cms3 is a dotnet-publish BUILD ARTIFACT from a separate, private project (cms3) - copied onto
    # this machine, never authored here. Committing ~57MB of DLLs would bloat git history permanently and
    # every republish would duplicate another full copy - staying gitignored is trivially reversible the
    # other way, committing it is not. package-kit.ps1 still ships it correctly (it copies the live
    # filesystem, not git), so distribution does not depend on git tracking it at all.
    $gi = Get-Content (Join-Path $kit ".gitignore") -Raw
    Assert ($gi -match '(?m)^examples/cms3/\*\s*$') ".gitignore does not blanket-ignore examples/cms3/* - a future publish could accidentally commit binaries"
    Assert ($gi -match '(?m)^!examples/cms3/README\.md\s*$') ".gitignore does not carve out an exception for examples/cms3/README.md - the one file that SHOULD be tracked"
    $readme = Join-Path $kit "examples\cms3\README.md"
    if (Test-Path $readme) {
      $ignored = $true
      try { & git -C $kit check-ignore -q "examples/cms3/README.md" 2>$null; $ignored = ($LASTEXITCODE -eq 0) } catch { }
      Assert (-not $ignored) "examples/cms3/README.md IS matched by gitignore - the exception rule is not working"
    }
    # If a build artifact happens to be present on THIS machine (it will not be on a fresh clone or CI -
    # that is the whole point), sanity-check its shape rather than requiring it.
    $dll = Join-Path $kit "examples\cms3\CMS.dll"
    if (Test-Path $dll) {
      Assert (-not (Test-Path (Join-Path $kit "examples\cms3\cms.db"))) "a runtime cms.db is sitting in examples\cms3 - clean up before shipping (it would be gitignored anyway, but package-kit.ps1 would still stage it into the distributable zip)"
      $roslyn = @(Get-ChildItem (Join-Path $kit "examples\cms3") -Filter "Microsoft.CodeAnalysis*.dll" -ErrorAction SilentlyContinue)
      Assert ($roslyn.Count -eq 0) "examples\cms3 contains Roslyn DLLs - the RuntimeCompilation bloat fix (S21) regressed, or this was republished from an unfixed cms3"
    }
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
