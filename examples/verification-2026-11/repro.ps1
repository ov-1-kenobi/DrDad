# repro.ps1 - reproductions for the Tier 1 issues. Run once with the OLD kit and once with the NEW kit.
#   repro.ps1 -Kit D:\Tools\DrDad-v0.59.4 -Issue 2 -Root C:\...\drdad-repro\old
#   repro.ps1 -Kit D:\projects\DrDad      -Issue 2 -Root C:\...\drdad-repro\new
param([Parameter(Mandatory)][string]$Kit, [Parameter(Mandatory)][string]$Issue, [Parameter(Mandatory)][string]$Root, [string]$OldKit = "")
$ErrorActionPreference = "Continue"
$env:DAD_HOME = $Kit          # the v2 hook finds the kit through DAD_HOME; point it at the kit under test
New-Item -ItemType Directory -Force $Root | Out-Null

function Say([string]$t) { Write-Host ""; Write-Host ">>> $t" }
function Run([string]$script, [string[]]$a) {
  $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Kit $script) @a 2>&1 | Out-String)
  $code = $LASTEXITCODE
  ($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 14) | ForEach-Object { Write-Host "    $_" }
  Write-Host "    [exit $code]"
  return $code
}
function GitOut([string]$p, [string[]]$a) { $o = (& git -C $p @a 2>&1 | Out-String); return $o.TrimEnd() }

# A scaffolded project with two stories of two tasks each, a fake build and a fake test command.
# The test command fails while a file named fail.flag exists; the fast test fails while scan.flag exists.
function New-Proj([string]$name, [switch]$FastTest) {
  $p = Join-Path $Root $name
  if (Test-Path $p) { Get-ChildItem $p -Recurse -Force -File | ForEach-Object { $_.Attributes = 'Normal' }; Remove-Item $p -Recurse -Force }
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Kit "new-project.ps1") general $p | Out-Null
  New-Item -ItemType Directory -Force "$p\tests","$p\tools" | Out-Null
  "@echo off`r`necho Total: 3`r`nif exist fail.flag exit /b 1`r`nexit /b 0" | Set-Content "$p\tools\fake-test.cmd" -Encoding ASCII
  "@echo off`r`necho Total: 1`r`nif exist scan.flag exit /b 1`r`nexit /b 0" | Set-Content "$p\tools\fake-scan.cmd" -Encoding ASCII
  $cm = [System.IO.File]::ReadAllText("$p\CLAUDE.md")
  $cm = [regex]::Replace($cm, '(?m)^- Build:.*$', '- Build: `exit 0`')
  $cm = [regex]::Replace($cm, '(?m)^- Test:.*$', '- Test:  `tools\fake-test.cmd`')
  if ($FastTest) {
    if ($cm -match '(?m)^- Fast test:.*$') { $cm = [regex]::Replace($cm, '(?m)^- Fast test:.*$', '- Fast test: `tools\fake-scan.cmd`') }
    else { $cm = [regex]::Replace($cm, '(?m)^(- Test:.*)$', "`$1`n- Fast test: ``tools\fake-scan.cmd``") }
  }
  [System.IO.File]::WriteAllText("$p\CLAUDE.md", $cm, (New-Object System.Text.UTF8Encoding($false)))
  $t = @("# Task map","","## Tasks","")
  foreach ($s in 1..2) { foreach ($n in 1..2) { $t += @("### [ ] T$s.$n - unit $s.$n   (Story S$s)","- **Goal:** x","") } }
  [System.IO.File]::WriteAllText("$p\docs\TASKS.md", (($t -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
  $st = "# Stories`n`n### Story S1: One   <!-- Status: TODO -->`n- x`n`n### Story S2: Two   <!-- Status: TODO -->`n- y`n"
  [System.IO.File]::WriteAllText("$p\docs\STORIES.md", $st, (New-Object System.Text.UTF8Encoding($false)))
  $tests = (1..10 | ForEach-Object { "    [Fact]`r`n    public void Case$_() { }" }) -join "`r`n"
  "public class T {`r`n$tests`r`n}" | Set-Content "$p\tests\ApiTests.cs" -Encoding UTF8
  & git -C $p add -A 2>&1 | Out-Null
  & git -C $p -c user.name=human -c user.email=h@h commit -q -m "docs: stories, tasks, build commands" 2>&1 | Out-Null
  return $p
}
function Close([string]$p, [string[]]$a) { return (Run "close-unit.ps1" (@("-ProjectDir", $p, "-NoReindex") + $a)) }

switch ($Issue) {
  "1" {
    $p = New-Proj "i1"
    Say ".mcp.json written by new-project"
    $j = Get-Content "$p\.mcp.json" -Raw | ConvertFrom-Json
    Write-Host "    command             = $($j.mcpServers.'local-tools'.command)"
    Write-Host "    LOCALTOOLS_DOCS_DIR = $($j.mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR)"
    Say "pre-commit hook lines that locate the kit"
    Get-Content "$p\.git\hooks\pre-commit" | Where-Object { $_ -match 'scan-secrets|DAD_HOME|kit=' } | ForEach-Object { Write-Host "    $_" }
    Say "does a commit still go through the hook?"
    "note" | Set-Content "$p\docs\note.md"
    & git -C $p add -A 2>&1 | Out-Null
    $o = (& git -C $p -c user.name=human -c user.email=h@h commit -m "docs: note" 2>&1 | Out-String)
    Write-Host "    commit exit $LASTEXITCODE; HEAD: $(GitOut $p @('log','--oneline','-1'))"
    Say "do the kit scripts still find the docs folder? (doc-stats)"
    [void](Run "doc-stats.ps1" @("-ProjectDir", $p))
  }
  "1u" {
    # upgrade path: a project scaffolded by the OLD kit, upgraded by the kit under test
    $old = "D:\Tools\DrDad-v0.59.4"
    $p = Join-Path $Root "i1u"
    if (Test-Path $p) { Get-ChildItem $p -Recurse -Force -File | ForEach-Object { $_.Attributes = 'Normal' }; Remove-Item $p -Recurse -Force }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $old "new-project.ps1") general $p | Out-Null
    Say "before upgrade (scaffolded by 0.59.4)"
    $j = Get-Content "$p\.mcp.json" -Raw | ConvertFrom-Json
    Write-Host "    command             = $($j.mcpServers.'local-tools'.command)"
    Write-Host "    LOCALTOOLS_DOCS_DIR = $($j.mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR)"
    Get-Content "$p\.git\hooks\pre-commit" | Where-Object { $_ -match 'scan-secrets' } | ForEach-Object { Write-Host "    hook: $_" }
    Say "upgrade-project with the kit under test"
    [void](Run "upgrade-project.ps1" @($p))
    Say "after upgrade"
    $j = Get-Content "$p\.mcp.json" -Raw | ConvertFrom-Json
    Write-Host "    command             = $($j.mcpServers.'local-tools'.command)"
    Write-Host "    LOCALTOOLS_DOCS_DIR = $($j.mcpServers.'local-tools'.env.LOCALTOOLS_DOCS_DIR)"
    Get-Content "$p\.git\hooks\pre-commit" | Where-Object { $_ -match 'scan-secrets|DAD_HOME|kit=' } | ForEach-Object { Write-Host "    hook: $_" }
    Write-Host "    .dad-kit-version    = $((Get-Content "$p\.dad-kit-version" -Raw).Trim())"
    Write-Host "    gate log present    = $(Test-Path "$p\grades\gates-log.jsonl")"
  }
  "2" {
    $p = New-Proj "i2"
    Say "close T1.1 (fine)"; [void](Close $p @("-Id","T1.1","-Title","unit 1.1"))
    Say "the suite now fails; close T1.2, the LAST task of S1 (a story close)"
    "x" | Set-Content "$p\fail.flag"
    [void](Close $p @("-Id","T1.2","-Title","unit 1.2"))
    Write-Host "    STORIES S1 line: $((Select-String "$p\docs\STORIES.md" -Pattern 'Story S1').Line)"
    Say "an agent hand-edits S1 to DONE (forging the stamp) and ticks T1.2 by hand"
    $s = [System.IO.File]::ReadAllText("$p\docs\STORIES.md").Replace("### Story S1: One   <!-- Status: TODO -->", "### Story S1: One   <!-- Status: DONE closed:close-unit -->")
    [System.IO.File]::WriteAllText("$p\docs\STORIES.md", $s, (New-Object System.Text.UTF8Encoding($false)))
    Say "(a) it runs close-unit for T2.1, a task of ANOTHER story (no story tests run for it)"
    $c = Close $p @("-Id","T2.1","-Title","unit 2.1")
    Write-Host "    HEAD: $(GitOut $p @('log','--oneline','-1'))"
    Write-Host "    is 'S1 DONE' in HEAD? $([bool]((GitOut $p @('show','HEAD:docs/STORIES.md')) -match 'Story S1.*Status: DONE'))"
    Say "(b) or it commits by hand: git commit -am 'T1.2: unit 1.2; S1 DONE'"
    $o = (& git -C $p -c user.name=agent -c user.email=a@a commit -a -m "T1.2: unit 1.2; S1 DONE" 2>&1 | Out-String)
    ($o -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 6) | ForEach-Object { Write-Host "    $_" }
    Write-Host "    [git commit exit $LASTEXITCODE]"
    Write-Host "    is 'S1 DONE' in HEAD? $([bool]((GitOut $p @('show','HEAD:docs/STORIES.md')) -match 'Story S1.*Status: DONE'))"
  }
  "2c" {
    # the S55 sequence from GDN: the close passes, the COMMIT fails, the DONE stamp stays on disk
    $p = New-Proj "i2c"
    [void](Close $p @("-Id","T1.1","-Title","unit 1.1"))
    Say "replace the pre-commit hook with one that always fails, then close T1.2 (last task of S1)"
    [System.IO.File]::WriteAllText("$p\.git\hooks\pre-commit", "#!/bin/sh`necho hook says no`nexit 1`n")
    [void](Close $p @("-Id","T1.2","-Title","unit 1.2"))
    Write-Host "    on disk, STORIES S1 line: $((Select-String "$p\docs\STORIES.md" -Pattern 'Story S1').Line)"
    Write-Host "    on disk, TASKS T1.2 line: $((Select-String "$p\docs\TASKS.md" -Pattern 'T1\.2').Line)"
    Write-Host "    HEAD: $(GitOut $p @('log','--oneline','-1'))"
  }
  "3" {
    $p = New-Proj "i3"
    Say "close T1.1 (records the ratchet baseline: 10 tests)"; [void](Close $p @("-Id","T1.1","-Title","unit 1.1"))
    Say "delete 6 of the 10 tests, then close T2.1"
    $four = (1..4 | ForEach-Object { "    [Fact]`r`n    public void Case$_() { }" }) -join "`r`n"
    "public class T {`r`n$four`r`n}" | Set-Content "$p\tests\ApiTests.cs" -Encoding UTF8
    [void](Close $p @("-Id","T2.1","-Title","unit 2.1"))
    Say "re-run with -AcceptShrink and NO reason (what GDN's log shows, 10 seconds after each block)"
    [void](Close $p @("-Id","T2.1","-Title","unit 2.1","-AcceptShrink"))
    Write-Host "    T2.1 line: $((Select-String "$p\docs\TASKS.md" -Pattern 'T2\.1').Line)"
    Say "re-run with -AcceptShrink -Reason"
    [void](Close $p @("-Id","T2.1","-Title","unit 2.1","-AcceptShrink","-Reason","Kristen approved 2026-11-09: cases 5-10 duplicated the contract test"))
    Write-Host "    T2.1 line: $((Select-String "$p\docs\TASKS.md" -Pattern 'T2\.1').Line)"
    Say "last 3 gate-log lines"
    Get-Content "$p\grades\gates-log.jsonl" | Select-Object -Last 3 | ForEach-Object { Write-Host "    $_" }
    Say "last commit body"
    (GitOut $p @('log','-1','--format=%B')) -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { Write-Host "    $_" }
  }
  "4" {
    $p = New-Proj "i4"
    Say "close T1.1 and T2.1"
    [void](Close $p @("-Id","T1.1","-Title","unit 1.1")); [void](Close $p @("-Id","T2.1","-Title","unit 2.1"))
    Say "docs\STATUS.md Snapshot section afterwards (real state: 2/4 tasks done)"
    $lines = Get-Content "$p\docs\STATUS.md"; $on = $false
    foreach ($l in $lines) { if ($l -match '^## Snapshot') { $on = $true } elseif ($l -match '^## ') { $on = $false }; if ($on) { Write-Host "    $l" } }
    Write-Host "    STATUS.md in the last commit? $([bool]((GitOut $p @('show','--stat','--format=','HEAD')) -match 'STATUS.md'))"
    Say "doc-stats -Findings: does it notice a stale dashboard? (hand-set the snapshot back to 0/4)"
    $s = [System.IO.File]::ReadAllText("$p\docs\STATUS.md") -replace 'Tasks: \d+/\d+', 'Tasks: 0/4'
    [System.IO.File]::WriteAllText("$p\docs\STATUS.md", $s, (New-Object System.Text.UTF8Encoding($false)))
    $o = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Kit "doc-stats.ps1") -ProjectDir $p -Findings 2>&1 | Out-String)
    $hit = @($o -split "`r?`n" | Where-Object { $_ -match '(?i)\[status\]|STATUS\.md' })
    if ($hit.Count) { $hit | ForEach-Object { Write-Host "    $_" } } else { Write-Host "    (no finding mentions STATUS.md)" }
  }
  "10" {
    $p = New-Proj "i10"
    Say "add a real .NET solution: src\App (library) and tests\App.IntegrationTests (test project)"
    New-Item -ItemType Directory -Force "$p\src\App","$p\tests\App.IntegrationTests" | Out-Null
    $lib = '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework><RollForward>LatestMajor</RollForward></PropertyGroup></Project>'
    $tst = '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework><RollForward>LatestMajor</RollForward><IsTestProject>true</IsTestProject></PropertyGroup><ItemGroup><ProjectReference Include="..\..\src\App\App.csproj" /></ItemGroup></Project>'
    $lib | Set-Content "$p\src\App\App.csproj" -Encoding UTF8
    "namespace App; public class Greeter { public string Hello(string name) => name; }" | Set-Content "$p\src\App\Greeter.cs" -Encoding UTF8
    $tst | Set-Content "$p\tests\App.IntegrationTests\App.IntegrationTests.csproj" -Encoding UTF8
    "namespace App.IntegrationTests; public class GreeterTestHelper { public void Check_hello() { } }" | Set-Content "$p\tests\App.IntegrationTests\GreeterTestHelper.cs" -Encoding UTF8
    Remove-Item "$p\tests\ApiTests.cs"
    $cm = [System.IO.File]::ReadAllText("$p\CLAUDE.md")
    $cm = [regex]::Replace($cm, '(?m)^- Build:.*$', '- Build: `dotnet build tests\App.IntegrationTests\App.IntegrationTests.csproj -nologo -v q`')
    [System.IO.File]::WriteAllText("$p\CLAUDE.md", $cm, (New-Object System.Text.UTF8Encoding($false)))
    & git -C $p add -A 2>&1 | Out-Null; & git -C $p -c user.name=human -c user.email=h@h commit -q -m "add solution" 2>&1 | Out-Null
    Say "close T1.1 (the build runs, the API surface is regenerated)"
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Kit "close-unit.ps1") -ProjectDir $p -Id T1.1 -Title "unit 1.1" 2>&1 | Out-String)
    ($out -split "`r?`n" | Where-Object { $_ -match 'API surface|close-unit (OK|INCOMPLETE)|FAIL' }) | ForEach-Object { Write-Host "    $_" }
    foreach ($f in @("docs\API-SURFACE.md", ".claude\API-SURFACE.md")) {
      $full = Join-Path $p $f
      if (Test-Path $full) {
        Write-Host "    $f exists; mentions GreeterTestHelper (test assembly)? $([bool](Select-String $full -Pattern 'GreeterTestHelper' -Quiet)); mentions Greeter? $([bool](Select-String $full -Pattern 'class Greeter\b' -Quiet))"
      } else { Write-Host "    $f does not exist" }
    }
    Write-Host "    files in the T1.1 commit: $(((GitOut $p @('show','--stat','--format=','HEAD')) -split "`n" | ForEach-Object { ($_ -split '\|')[0].Trim() } | Where-Object { $_ -and $_ -notmatch 'changed' }) -join ', ')"
    Write-Host "    tracked by git: $((GitOut $p @('ls-files')) -split "`n" | Where-Object { $_ -match 'API-SURFACE' })"
    Say "lookup still works"
    [void](Run "api-surface.ps1" @("-ProjectDir", $p, "-Lookup", "Greeter"))
  }
  "12" {
    $p = New-Proj "i12" -FastTest
    Say "CLAUDE.md has a 'Fast test:' line (the source-scan subset). It currently FAILS (scan.flag)."
    Write-Host "    $((Select-String "$p\CLAUDE.md" -Pattern '^- Fast test').Line)"
    "x" | Set-Content "$p\scan.flag"
    Say "close T1.1 - an ordinary task close, not a story close"
    [void](Close $p @("-Id","T1.1","-Title","unit 1.1"))
    Write-Host "    T1.1 line: $((Select-String "$p\docs\TASKS.md" -Pattern 'T1\.1').Line)"
    Say "fix the scan failure and close again"
    Remove-Item "$p\scan.flag"
    [void](Close $p @("-Id","T1.1","-Title","unit 1.1"))
    Write-Host "    T1.1 line: $((Select-String "$p\docs\TASKS.md" -Pattern 'T1\.1').Line)"
  }
  "14" {
    $p = New-Proj "i14"
    Say "(i) the title already starts with the id, as agents often pass it"
    [void](Close $p @("-Id","T1.1","-Title","T1.1: unit 1.1"))
    Write-Host "    subject: $(GitOut $p @('log','-1','--format=%s'))"
    Say "(ii) the same close is run a second time"
    $before = (GitOut $p @('rev-list','--count','HEAD'))
    [void](Close $p @("-Id","T1.1","-Title","T1.1: unit 1.1"))
    $after = (GitOut $p @('rev-list','--count','HEAD'))
    Write-Host "    commits before: $before, after: $after"
    Write-Host "    last two subjects: $((GitOut $p @('log','-2','--format=%s')) -replace "`n", ' | ')"
    Say "(iii) close T1.2: story S1 rolls up to DONE. Then go straight on to T2.1 with no story-level close of S1"
    [void](Close $p @("-Id","T1.2","-Title","unit 1.2"))
    [void](Close $p @("-Id","T2.1","-Title","unit 2.1"))
    Write-Host "    T2.1 line: $((Select-String "$p\docs\TASKS.md" -Pattern 'T2\.1').Line)"
    Say "do the story-level close of S1, then T2.1 again"
    [void](Close $p @("-Id","S1","-Title","S1 polish"))
    Write-Host "    commits whose subject starts with 'S1:': $(@((GitOut $p @('log','--format=%s')) -split "`n" | Where-Object { $_ -match '^S1:' }).Count)"
    [void](Close $p @("-Id","T2.1","-Title","unit 2.1"))
    Write-Host "    T2.1 line: $((Select-String "$p\docs\TASKS.md" -Pattern 'T2\.1').Line)"
  }
  "15" {
    $p = New-Proj "i15"
    Say "right after scaffold: is there a gate log, and is it in the initial commit?"
    Write-Host "    grades\gates-log.jsonl exists: $(Test-Path "$p\grades\gates-log.jsonl")"
    Write-Host "    tracked in the scaffold commit: $([bool]((GitOut $p @('show','--stat','--format=',(GitOut $p @('rev-list','--max-parents=0','HEAD')))) -match 'gates-log'))"
    if (Test-Path "$p\grades\gates-log.jsonl") { Get-Content "$p\grades\gates-log.jsonl" | Select-Object -First 2 | ForEach-Object { Write-Host "    $_" } }
  }
  "16" {
    $p = New-Proj "i16"
    $adm = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Say "this shell is elevated: $adm. Close T1.1 and look for a warning."
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Kit "close-unit.ps1") -ProjectDir $p -NoReindex -Id T1.1 -Title "unit 1.1" 2>&1 | Out-String)
    $hit = @($out -split "`r?`n" | Where-Object { $_ -match '(?i)elevat|administrator' })
    if ($hit.Count) { $hit | ForEach-Object { Write-Host "    $_" } } else { Write-Host "    (close-unit printed nothing about elevation)" }
    Write-Host "    close-unit exit: $LASTEXITCODE"
    Say "dad doctor"
    Push-Location $p
    $d = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Kit "dad-doctor.ps1") 2>&1 | Out-String)
    Pop-Location
    $hit = @($d -split "`r?`n" | Where-Object { $_ -match '(?i)elevat' })
    if ($hit.Count) { $hit | ForEach-Object { Write-Host "    $_" } } else { Write-Host "    (dad doctor printed nothing about elevation)" }
  }
  "18" {
    $p = New-Proj "i18"
    New-Item -ItemType Directory -Force "$p\_tmp\bak" | Out-Null
    "old" | Set-Content "$p\_tmp\old-log.txt"; "old" | Set-Content "$p\_tmp\bak\old.orig"; "new" | Set-Content "$p\_tmp\in-flight.txt"
    $then = (Get-Date).AddHours(-5)
    (Get-Item "$p\_tmp\old-log.txt").LastWriteTime = $then; (Get-Item "$p\_tmp\bak\old.orig").LastWriteTime = $then; (Get-Item "$p\_tmp\bak").LastWriteTime = $then
    Say "_tmp holds two 5-hour-old scratch files and one written just now. Close T1.1 (task), then T1.2 (closes story S1)."
    [void](Close $p @("-Id","T1.1","-Title","unit 1.1"))
    Write-Host "    after the TASK close, _tmp: $((Get-ChildItem "$p\_tmp" -Recurse -File | ForEach-Object { $_.Name }) -join ', ')"
    [void](Close $p @("-Id","T1.2","-Title","unit 1.2"))
    Write-Host "    after the STORY close, _tmp: $((Get-ChildItem "$p\_tmp" -Recurse -File | ForEach-Object { $_.Name }) -join ', ')"
  }
}
