# dad-loopguard.ps1 - a Claude Code PreToolUse hook that breaks tight command loops and rejects shell
# redirections that HIDE their own errors.
#
# Why this exists (measured, CMS run, 2026-08-21):
#   A taskmap subagent ran
#       dir "D:\projects\Claude\projects\cms\src" 2>nul
#   NINE HUNDRED AND TWENTY times in a row and the session had to be killed by hand. Two things combined:
#
#   1. `2>nul` is cmd.exe syntax. Under the Bash tool it does not silence anything - it redirects stderr
#      into a FILE named "nul". So the model received: empty stdout, no error text, nothing. It had no way
#      to learn that the path did not exist, so it tried again. And again. (It also littered 28 zero-byte
#      files named `nul` across the project, including inside .git\objects - and `nul` is a reserved
#      device name on Windows, so those are awkward to delete.)
#   2. Nothing in the harness noticed that the same command was failing identically forever.
#
#   The agent's `tools:` frontmatter did NOT include Bash, and it ran Bash anyway - so per-agent tool
#   restriction cannot be relied on as the guard. A hook is enforced by the harness, not by the model.
#
# Contract: PreToolUse hooks receive the tool call as JSON on stdin. Exit 0 = allow. Exit 2 = BLOCK, with
# the reason on stderr for the model to read. Anything else is treated as a non-blocking error, which is
# why every failure path here exits 0: a guard that breaks the session when IT has a bug gets switched off.
#
# Usage:
#   (wired by install.ps1 as a PreToolUse hook)
#   dad-loopguard.ps1 -Check            self-test: prints what it would do for sample commands
#   dad-loopguard.ps1 -Reset            forget the streak state for every session

# CmdletBinding so a MISTYPED parameter is an ERROR. A script with a plain param() block is not an
# ADVANCED function, so PowerShell silently drops unmatched arguments into $args instead of failing:
# `-Path C:\x` on a script whose parameter is -ProjectDir ran against the DEFAULT (the current
# directory). That is how a stray scaffold - CLAUDE.md, .mcp.json, docs\, git init - landed in the
# wrong folder. These scripts are invoked by MODELS, which typo parameter names.
[CmdletBinding()]
param(
  [switch]$Check,
  [switch]$Reset,
  [switch]$Bench,
  [int]$SpiralLimit = 25,   # tests override this; 25 invocations x ~1.7s each is too slow for a suite
  [int]$MaxRepeats = 4          # the Nth CONSECUTIVE identical command is blocked
)

$ErrorActionPreference = "Stop"

$stateDir = Join-Path $env:TEMP "dad-loopguard"

function Normalize([string]$s) {
  if (-not $s) { return "" }
  # collapse whitespace so trivial reformatting is still recognised as the same command
  return ([regex]::Replace($s.Trim(), '\s+', ' '))
}

# The payload is read with a regex rather than ConvertFrom-Json (see hook mode for why), so JSON escapes
# arrive verbatim and have to be undone here. This is not theoretical: PowerShell's own ConvertTo-Json
# encodes '>' as >, so `2>nul` reaches a naive matcher as `2>nul` and sails straight through.
# Different producers escape differently - Node does not escape '>' - and a guard that only works against
# one encoding is a guard that silently stops working.
function Unescape-Json([string]$s) {
  if (-not $s) { return "" }
  if ($s.IndexOf('\') -lt 0) { return $s }                      # fast path: nothing escaped
  $s = [regex]::Replace($s, '\\u([0-9a-fA-F]{4})', { param($m) [char][Convert]::ToInt32($m.Groups[1].Value, 16) })
  return $s.Replace('\"', '"').Replace('\n', "`n").Replace('\r', "`r").Replace('\t', "`t").Replace('\/', '/').Replace('\\', '\')
}

# Returns $null to allow, or a reason string to block.
function Test-Command([string]$command, [string]$sessionId) {
  $norm = Normalize $command
  if (-not $norm) { return $null }

  # An explicit opt-out, for the rare case where hammering the same command IS the intent (polling).
  if ($norm -match 'dad-allow-repeat') { return $null }

  # --- 1) redirections that hide the error -------------------------------------------------------
  # `2>nul` / `1>nul` / `>nul` are cmd.exe. Under bash they create a FILE called nul and discard nothing;
  # under PowerShell the token is $null, not nul. Either way the model loses the error message - which is
  # the difference between "retry" and "learn". Caught on the FIRST occurrence, not the fourth: the point
  # is to stop an invisible failure from ever being invisible.
  if ($norm -match '(?i)\d?>\s*nul(\s|$|;|&|\|)') {
    return @"
BLOCKED: '2>nul' is cmd.exe syntax and this is not cmd.exe.

Under Bash it does not silence stderr - it redirects it into a FILE named 'nul' (a reserved device name
on Windows), so you get empty output and NO error message, and cannot tell a missing path from an empty
one. A real run of this kit looped the same command 920 times for exactly this reason.

Use instead:
  bash        <cmd> 2>/dev/null
  PowerShell  <cmd> 2>`$null
  existence   powershell -NoProfile -Command "Test-Path -LiteralPath 'C:\path'"   -> True/False

If you were checking whether a path exists, use Test-Path. Do not re-run this command.
"@
  }

  # --- 2) the same command, over and over ---------------------------------------------------------
  # EXEMPT: commands whose result legitimately CHANGES between identical invocations, because the
  # workspace changed underneath them. This hook only sees shell calls, so a build-fix-build-fix cycle
  # looks like four consecutive identical `dotnet build` calls - the Edit calls in between are invisible
  # to it. Measured while benchmarking this very script: it blocked `dotnet build`. For these commands
  # "repeating it gives the same result" is simply FALSE, and a guard that interrupts a compile-error fix
  # loop is a guard someone switches off within the hour.
  #
  # Probes are the opposite: `dir`/`ls`/`cat` on an unchanged tree really do return the same thing every
  # time, and every loop this kit has actually suffered was a probe. So the streak applies to probes and
  # not to work.
  $exempt = @(
    'dotnet','msbuild','npm','pnpm','yarn','node','cargo','go','make','gradle','mvn','python','py',
    'pytest','pip','dvc','docker','git','gh','close-unit','ratchet','recover-lost','test-kit',
    'install','upgrade-project','api-surface','scan-secrets','index_datasheets','reindex'
  )
  $firstWord = ($norm -split '[\s\\/]' | Where-Object { $_ } | Select-Object -First 1)
  if ($firstWord) {
    $bare = [System.IO.Path]::GetFileNameWithoutExtension($firstWord)
    # powershell -File <script>.ps1 -> judge by the SCRIPT, not by "powershell"
    if ($bare -match '(?i)^(powershell|pwsh|cmd)$') {
      $m2 = [regex]::Match($norm, '(?i)-File\s+"?([^"\s]+)"?')
      if ($m2.Success) { $bare = [System.IO.Path]::GetFileNameWithoutExtension($m2.Groups[1].Value) }
    }
    if ($exempt -contains $bare.ToLower()) { return $null }
  }

  # CONSECUTIVE repeats only. Four identical PROBES with nothing at all between them is a loop.
  if (-not $sessionId) { $sessionId = "nosession" }
  $safe = ($sessionId -replace '[^A-Za-z0-9_.-]', '_')
  if ($safe.Length -gt 64) { $safe = $safe.Substring(0, 64) }
  $stateFile = Join-Path $stateDir "$safe.json"

  # FLAT text, not JSON. ConvertFrom-Json alone measured ~500 ms per invocation in PS 5.1 (it loads the
  # serializer), and this runs before EVERY tool call - so the guard would cost more than the loops it
  # prevents. Format: "<streak>|<normalized command>".
  $last = ""; $streak = 0
  if ([System.IO.File]::Exists($stateFile)) {
    try {
      $line = [System.IO.File]::ReadAllText($stateFile)
      $bar = $line.IndexOf('|')
      if ($bar -gt 0) { $streak = [int]$line.Substring(0, $bar); $last = $line.Substring($bar + 1) }
    } catch { $last = ""; $streak = 0 }
  }

  if ($norm -eq $last) { $streak = $streak + 1 } else { $streak = 1 }

  if (-not [System.IO.Directory]::Exists($stateDir)) { [System.IO.Directory]::CreateDirectory($stateDir) | Out-Null }
  [System.IO.File]::WriteAllText($stateFile, "$streak|$norm", (New-Object System.Text.UTF8Encoding($false)))

  if ($streak -ge $MaxRepeats) {
    # Reset so the model gets to try ONE different thing without being blocked again on the next call.
    [System.IO.File]::WriteAllText($stateFile, "0|", (New-Object System.Text.UTF8Encoding($false)))
    $short = if ($norm.Length -gt 160) { $norm.Substring(0, 160) + "..." } else { $norm }
    return @"
BLOCKED: you have now run this SAME command $streak times in a row, with nothing in between:

  $short

Repeating it will produce the same result again. The result you are getting IS the answer - read it as one:

  - empty output is a RESULT (the thing is not there, or the command wrote to stderr you discarded)
  - a path that does not exist will not exist on the next attempt either
  - if you are waiting for something, say so and stop, rather than spinning

Do something DIFFERENT: check the path with `Test-Path`, look at the parent directory, read the file you
are actually after, or report what you found and why it blocks you. If a directory you expected is
missing, that may simply be the truth of this project - say that instead of probing again.
"@
  }

  return $null
}

# READ-ONLY SPIRAL: many looks, nothing written.
#
# The identical-command rule cannot catch this one. A subagent searching with a DIFFERENT query each time
# is making a different call every time, so no streak ever forms - and that is exactly how a scribe
# subagent reached 947 tool calls and produced NO STORIES.md at all. "Lost in search" is the accurate
# description: it kept looking for context instead of writing the thing it was asked for.
#
# So this counts consecutive READ-ONLY calls with no WRITE in between. A write (Edit/Write/NotebookEdit, or
# a shell command, which can have effects) resets it. The threshold is deliberately generous - real work
# reads a lot before writing - but 25 looks with nothing produced is not research, it is a spiral.
$SPIRAL_LIMIT = $SpiralLimit

function Test-Spiral([string]$toolName, [string]$sessionId) {
  if (-not $sessionId) { $sessionId = "nosession" }
  $safe = ($sessionId -replace '[^A-Za-z0-9_.-]', '_')
  if ($safe.Length -gt 64) { $safe = $safe.Substring(0, 64) }
  $stateFile = Join-Path $stateDir "$safe.spiral.json"

  # Anything that changes the world - or a shell command, which might - counts as progress.
  $isWrite = ($toolName -match '(?i)^(Edit|Write|NotebookEdit|MultiEdit)$') -or
             ($toolName -match '(?i)bash|powershell|shell|terminal') -or
             ($toolName -match '(?i)index_datasheets|ingest_url')

  $n = 0
  if ([System.IO.File]::Exists($stateFile)) {
    try { $n = [int][System.IO.File]::ReadAllText($stateFile) } catch { $n = 0 }
  }
  if ($isWrite) { $n = 0 } else { $n = $n + 1 }

  if (-not [System.IO.Directory]::Exists($stateDir)) { [System.IO.Directory]::CreateDirectory($stateDir) | Out-Null }
  $store = if ($n -ge $SPIRAL_LIMIT) { 0 } else { $n }   # reset after blocking, so one nudge is enough
  [System.IO.File]::WriteAllText($stateFile, "$store", (New-Object System.Text.UTF8Encoding($false)))

  if ($n -lt $SPIRAL_LIMIT) { return $null }
  return @"
BLOCKED: $n reads/searches in a row and nothing written.

You are looking for context instead of producing the thing you were asked for. A real run did this 947
times and produced an EMPTY output file before it had to be killed by hand.

What to do NOW, in this order:
  1. If you need the design doc, the stories or the tasks: **Read the file directly.** They are one file
     each, usually 10-20 KB. Searching a corpus for a document you can simply open is pure overhead, and
     if the MCP server is not answering, search returns nothing no matter how you reword the query.
  2. Write what you already have. A partial, correct artifact beats a perfect one you never produced.
  3. If something you genuinely need is absent, SAY SO and stop. "I could not find X, so I did not write
     Y" is a usable result. Another twenty searches is not.

Do not reword the query and try again.
"@
}

# ---- gate log (DESIGN C3, R38(b)) -----------------------------------------------------------------
# Resolve the project the hook payload's cwd belongs to: nearest ancestor holding docs or grades (cwd may
# be a subdirectory), else cwd itself. Returns "" when cwd is empty, and the caller then skips logging.
function Resolve-LogProject([string]$cwd) {
  if (-not $cwd) { return "" }
  $d = $cwd
  for ($i = 0; $i -lt 32 -and $d; $i++) {
    if ([System.IO.Directory]::Exists((Join-Path $d "docs")) -or [System.IO.Directory]::Exists((Join-Path $d "grades"))) { return $d }
    $parent = [System.IO.Path]::GetDirectoryName($d)
    if (-not $parent -or $parent -eq $d) { break }
    $d = $parent
  }
  return $cwd
}

# Fail-open append via dad-gates-log.ps1 (spawns powershell - call ONLY on the first call and on blocks).
function Write-GateLog([string]$cwd, [string]$decision, [string]$tool, [string]$why, [string]$sid) {
  try {
    $pd = Resolve-LogProject $cwd
    if (-not $pd) { return }
    # An EMPTY string argument is dropped by the native call, so -Tool is passed only when non-empty (the helper defaults it to "").
    # Native-call args: collapse whitespace, swap double quotes (they split the argument), cap length (helper truncates to 300 anyway).
    $why = ([regex]::Replace([string]$why, '\s+', ' ')).Replace([string][char]34, "'").Trim()
    if ($why.Length -gt 300) { $why = $why.Substring(0, 300) }
    $la = @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $PSScriptRoot "dad-gates-log.ps1"),"-ProjectDir",$pd,"-Gate","loop-guard","-Decision",$decision,"-Reason",$why,"-Session",$sid)
    if ($tool) { $la += @("-Tool",$tool) }
    & powershell @la 2>$null | Out-Null
  } catch { }
}

# ---------------- self-test ------------------------------------------------------------------------
if ($Reset) {
  if (Test-Path -LiteralPath $stateDir) { Remove-Item -LiteralPath $stateDir -Recurse -Force }
  Write-Host "dad-loopguard: state cleared"
  exit 0
}

if ($Bench) {
  # MEASURE IT ON YOUR OWN MACHINE. This hook runs before EVERY tool call, so its cost is multiplied by
  # every tool call in the run - and the dominant term is not this script, it is how long your machine
  # takes to START a PowerShell process. On the dev box that was ~900 ms (antivirus scanning each launch),
  # making the guard ~2 s per call: about 10 minutes over a 300-call run. On a machine with fast process
  # launch the same guard costs a fraction of that. Do not guess - run this.
  Write-Host "== dad-loopguard overhead on THIS machine ==" -ForegroundColor Cyan
  $self = $PSCommandPath
  # a DIFFERENT payload each time, or the bench trips the repeat guard on its own fourth call
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  for ($i = 0; $i -lt 5; $i++) { & powershell -NoProfile -Command "exit 0" | Out-Null }
  $sw.Stop(); $floor = $sw.ElapsedMilliseconds / 5
  '{"session_id":"bench","tool_name":"Read","tool_input":{"file_path":"warm.md"}}' |
    & powershell -NoProfile -ExecutionPolicy Bypass -File $self 2>$null | Out-Null
  $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
  for ($i = 0; $i -lt 5; $i++) {
    "{`"session_id`":`"bench`",`"tool_name`":`"Read`",`"tool_input`":{`"file_path`":`"f$i.md`"}}" |
      & powershell -NoProfile -ExecutionPolicy Bypass -File $self 2>$null | Out-Null
  }
  $sw2.Stop(); $per = $sw2.ElapsedMilliseconds / 5
  Write-Host ("  bare PowerShell startup : {0} ms  (the floor - nothing can beat this)" -f [math]::Round($floor))
  Write-Host ("  this guard, per call    : {0} ms" -f [math]::Round($per))
  Write-Host ("  cost over 300 tool calls: {0} s" -f [math]::Round($per * 300 / 1000, 1))
  Write-Host ""
  if ($per -gt 700) {
    Write-Host "  That is expensive. To trade some coverage for speed, edit settings.json's PreToolUse" -ForegroundColor Yellow
    Write-Host "  matcher from `"`" (every tool) to a narrower set, e.g.:" -ForegroundColor Yellow
    Write-Host "      `"matcher`": `"Bash|Grep|Glob|Edit|Write|mcp__local-tools__.*`"" -ForegroundColor Cyan
    Write-Host "  That skips Read - the highest-volume tool - while still catching command loops and" -ForegroundColor Yellow
    Write-Host "  search spirals, and still seeing the writes that RESET the spiral counter." -ForegroundColor Yellow
    Write-Host "  Weigh it against what a loop costs: two sessions here were lost to 920 and 947 calls." -ForegroundColor Yellow
  } else {
    Write-Host "  Cheap enough to leave on every tool." -ForegroundColor Green
  }
  exit 0
}

if ($Check) {
  Write-Host "== dad-loopguard self-test ==" -ForegroundColor Cyan
  $sid = "selftest-$PID"
  $cases = @(
    @{ c = 'dir "D:\p\src" 2>nul';        expect = "BLOCK (cmd redirection)" },
    @{ c = 'ls -la src 2>/dev/null';      expect = "allow" },
    @{ c = 'dotnet build';                expect = "allow" }
  )
  foreach ($k in $cases) {
    $r = Test-Command $k.c $sid
    $got = if ($r) { "BLOCK" } else { "allow" }
    Write-Host ("  {0,-34} -> {1,-6} (expected {2})" -f $k.c, $got, $k.expect)
  }
  Write-Host "  -- the same command four times in a row --"
  for ($i = 1; $i -le 4; $i++) {
    $r = Test-Command 'ls -la nowhere' $sid
    Write-Host ("    attempt {0}: {1}" -f $i, $(if ($r) { "BLOCKED" } else { "allowed" }))
  }
  Remove-Item -LiteralPath (Join-Path $stateDir "$($sid -replace '[^A-Za-z0-9_.-]','_').json") -Force -ErrorAction SilentlyContinue
  exit 0
}

# ---------------- hook mode -----------------------------------------------------------------------
# Everything below fails OPEN. A PreToolUse hook sits in front of EVERY tool call; one that errors on its
# own bugs would make the session unusable, and the first thing anyone would do is delete it.
try {
  $raw = [Console]::In.ReadToEnd()
  if (-not $raw) { exit 0 }
  # REGEX, not ConvertFrom-Json. Measured: ConvertFrom-Json costs ~500 ms per invocation in PS 5.1 because
  # it loads the serializer, and this hook runs before EVERY tool call - so the guard would cost far more
  # than the loops it prevents. We need exactly three things out of the payload, and none of them needs a
  # full parse: the tool name, the session id, and enough of tool_input to identify a repeat.
  $toolName = ""
  $m = [regex]::Match($raw, '"tool_name"\s*:\s*"([^"]*)"')
  if ($m.Success) { $toolName = $m.Groups[1].Value }
  $sessionId = ""
  $m = [regex]::Match($raw, '"session_id"\s*:\s*"([^"]*)"')
  if ($m.Success) { $sessionId = $m.Groups[1].Value }
  # cwd: absolute Windows path, JSON-escaped (\\ for \) in the raw payload (measured, T9.5). Gate log only.
  $cwd = ""
  $m = [regex]::Match($raw, '"cwd"\s*:\s*"((?:[^"\\]|\\.)*)"')
  # Single-pass unescape of \\ \" \/ ONLY. Not Unescape-Json: its sequential Replace turns the '\\' + 't' in
  # "...\\t92" into TAB (\t is replaced before \\), yielding an illegal path. Fail-open: a bad cwd just skips.
  if ($m.Success) { $cwd = [regex]::Replace($m.Groups[1].Value, '\\([\\"/])', '$1') }
  # tool_input verbatim - its exact text IS the signature of the call, which is all we need
  $inputSig = ""
  $m = [regex]::Match($raw, '"tool_input"\s*:\s*(\{.*)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if ($m.Success) { $inputSig = $m.Groups[1].Value }
  $cmdMatch = [regex]::Match($inputSig, '"command"\s*:\s*"((?:[^"\\]|\\.)*)"')

  # EVERY tool, not just shell. This guard was matched on Bash alone, and then a scribe subagent made
  # NINE HUNDRED AND FORTY-SEVEN tool calls and had to be killed by hand - not one of them Bash, because
  # scribe-agent's tool list is Read/Grep/Edit/Write plus MCP search. The guard was structurally incapable
  # of seeing a single one. A loop breaker that watches one tool is not a loop breaker.
  if (-not $toolName) { exit 0 }

  # ARMED HEARTBEAT (C3b): the session's first invocation = no per-session state file yet. The spiral file is
  # written on every non-blocked call, so it is the "seen this session" marker; created here so a first call
  # that itself blocks does not re-arm on the next one. No new state file.
  if ($cwd) {
    $safeKey = ($(if ($sessionId) { $sessionId } else { "nosession" }) -replace '[^A-Za-z0-9_.-]', '_')
    if ($safeKey.Length -gt 64) { $safeKey = $safeKey.Substring(0, 64) }
    $marker = Join-Path $stateDir "$safeKey.spiral.json"
    if (-not [System.IO.File]::Exists($marker)) {
      Write-GateLog $cwd "allow" "" "armed" $sessionId
      if (-not [System.IO.Directory]::Exists($stateDir)) { [System.IO.Directory]::CreateDirectory($stateDir) | Out-Null }
      [System.IO.File]::WriteAllText($marker, "0", (New-Object System.Text.UTF8Encoding($false)))
    }
  }

  if ($cmdMatch.Success) {
    # A shell command: the 2>nul check and the work-command exemption both apply.
    $reason = Test-Command (Unescape-Json $cmdMatch.Groups[1].Value) $sessionId
    if ($reason) { if ($cwd) { Write-GateLog $cwd "block" $toolName $reason $sessionId }; [Console]::Error.WriteLine($reason); exit 2 }
  } else {
    # Any other tool: the call's identity is its name plus its input verbatim, so a repeated identical
    # Read / Grep / search_datasheets is caught exactly the way a repeated command is.
    $reason = Test-Command "$toolName $inputSig" $sessionId
    if ($reason) { if ($cwd) { Write-GateLog $cwd "block" $toolName $reason $sessionId }; [Console]::Error.WriteLine($reason); exit 2 }
  }

  # And the spiral check applies to everything: many looks, nothing written.
  $spiral = Test-Spiral $toolName $sessionId
  if ($spiral) { if ($cwd) { Write-GateLog $cwd "block" $toolName $spiral $sessionId }; [Console]::Error.WriteLine($spiral); exit 2 }
  exit 0
} catch {
  exit 0
}
