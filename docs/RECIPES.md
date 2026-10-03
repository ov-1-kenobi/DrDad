# Proven recipes - <project>
<!-- Commands that actually WORKED on THIS machine, with enough context to reuse them. Indexed by
     local-tools, so any agent can `search_datasheets` for the correct syntax instead of guessing
     (different models guess shell syntax differently - this is the antidote).
     RULES for agents:
     - CONSULT first: before an unfamiliar shell operation, search this doc for a proven pattern.
     - RECORD on success: append an entry when a NEW command works, or when a command FAILED and you
       found the syntax that works (record the fix, note the trap). Do NOT log routine re-runs of
       commands already listed - update the existing entry instead.
     - Keep entries small and generic (placeholders like <file>); no secrets/tokens ever.
     - Reindex (`index_datasheets`) after adding entries. -->

## Shell: Windows PowerShell 5.1 unless marked otherwise

### Example entry (delete once real ones exist)
- **Command:** `dotnet test <proj> --filter "FullyQualifiedName~<TestClass>" --nologo`
- **Does:** runs a single test class instead of the whole suite.
- **When:** verifying one story's tests quickly.
- **Gotcha:** the filter operator is `~` (contains), not `=`; quote the whole filter in PowerShell.
- **Verified:** <YYYY-MM-DD>, <model>

## Kit-seeded: PowerShell 5.1 traps (verified; do not delete)
<!-- These are NOT examples. Each one is a command that a model wrote, that PARSED, and that then
     failed on a real run of this kit. They ship pre-loaded because every project rediscovers them
     otherwise, and because the failure mode is always the same: PS 5.1 accepts the syntax and
     misbehaves at runtime, so "it ran" is not evidence. Append project-specific entries above. -->

- **Command:** `powershell -NoProfile -Command "Test-Path -LiteralPath 'C:\path'"` to test existence;
  `2>/dev/null` under bash, `2>$null` under PowerShell - **never `2>nul`**
- **Does:** checks whether a path exists, or discards stderr, without hiding the outcome.
- **When:** any "does this directory/file exist yet" probe.
- **Gotcha:** `2>nul` is cmd.exe syntax. Under the Bash tool it silences NOTHING - it redirects stderr into
  a FILE named `nul`, so you get empty output and no error text and cannot tell "missing" from "empty".
  A real run looped `dir "...\src" 2>nul` **920 times** on this and had to be killed by hand; it also left
  28 zero-byte files named `nul` across the project, including inside `.git\objects\`, and `nul` is a
  reserved device name on Windows so those are awkward to delete. The kit's PreToolUse hook
  (`dad-loopguard`) now blocks this command shape outright.
- **Verified:** 2026-08-22, Opus

- **Command:** delete a stray `nul` with `[System.IO.File]::Delete("\\?\C:\full\path\nul")`
- **Does:** removes a file whose name is a reserved Windows device name.
- **When:** cleaning up after a `2>nul` under bash (see above).
- **Gotcha:** `Remove-Item -LiteralPath "C:\...\nul"` FAILS with *"because it does not exist"* - PowerShell
  resolves `nul` as the NUL DEVICE, not as your file, so it cannot see it at all. `Get-ChildItem -Filter nul`
  still ENUMERATES them fine; it is only the by-path operations that break. The `\\?\` prefix bypasses
  Win32 path parsing and must be given the FULL path (an 8.3 short path like `KOVERM~1` will not resolve).
- **Verified:** 2026-08-22, Opus

- **Command:** `git commit -F <msgfile>` (write the message with `[System.IO.File]::WriteAllText`)
- **Does:** commits with a multi-line message.
- **When:** any commit message longer than one line.
- **Gotcha:** `git commit -m @'...'@` with a here-string MANGLES the message. PS 5.1 re-splits native
  arguments, and a `"X":` inside the text became a path - `fatal: Invalid path 'X:/...'`. There is no
  quoting that reliably fixes it; use a file.
- **Verified:** 2026-08-21, Opus

- **Command:** `[System.IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($false)))`
- **Does:** writes UTF-8 with NO byte-order mark.
- **When:** any `.json`, and any file another tool parses.
- **Gotcha:** `Set-Content -Encoding UTF8` writes a BOM in 5.1, and Node/Claude Code chokes on a BOM in
  `settings.json` / `.mcp.json`. Also: `[System.IO.File]` resolves relative paths against .NET's own
  working directory, which `Set-Location` does NOT change - always pass an absolute path.
- **Verified:** 2026-08-21, Opus

- **Command:** `$n = 16; if ($cond) { $n = 8 }` then use `"...$n..."`
- **Does:** picks a value for use inside a string or a native command line.
- **When:** building a command line from a condition.
- **Gotcha:** `$((if ($cond) { 8 } else { 16 }))` fails with *"The term 'if' is not recognized"* - `if`
  cannot sit in expression position in 5.1. A multi-line `$x = if (...) {}` + newline `elseif` PARSES
  and then fails at runtime, which is worse. Resolve the value on its own line first.
- **Verified:** 2026-08-21, Opus

- **Command:** `$items = @(Get-Something ...)` before touching `.Count`
- **Does:** guarantees an array.
- **When:** any count/emptiness check on a command's output.
- **Gotcha:** a single result unrolls to a scalar, so `.Count` is `$null` and `-gt 0` is false - the
  one-item case silently reports zero. Wrap at the CALL SITE, not inside the function.
- **Verified:** 2026-08-21, Opus

- **Command:** `if ($p -and (Test-Path -LiteralPath $p)) { ... }`
- **Does:** existence check that tolerates an unset path.
- **When:** any path that came from a config value or a regex capture.
- **Gotcha:** `Test-Path ""` THROWS rather than returning false, and `Join-Path` throws on a
  non-existent drive letter. Guard for empty before either.
- **Verified:** 2026-08-21, Opus

- **Command:** match captured output with `-match 'no\s+such\s+file'`, never `-match 'no such file'`
- **Does:** finds a phrase in a command's output reliably.
- **When:** checking whether a build/test/git command reported a particular error.
- **Gotcha:** output captured from a native command is HARD-WRAPPED at the console width, so a phrase you
  are matching can arrive with a newline in the middle of it. A literal-space regex then silently fails
  and you conclude the error was not there. Use `\s+` between words. Same applies to matching phrases in
  hard-wrapped markdown.
- **Verified:** 2026-08-21, Opus

- **Command:** put `[CmdletBinding()]` above `param(...)` in every script
- **Does:** makes a mistyped parameter name a hard error.
- **When:** always, for any script that takes parameters.
- **Gotcha:** a plain `param()` block is not an ADVANCED function, so PowerShell silently drops unmatched
  arguments into `$args` and runs with the DEFAULTS. `script.ps1 -Path C:\x` where the parameter is
  actually `-ProjectDir` ran against `.` - the current directory - and wrote files into the wrong folder.
  It does not warn.
- **Verified:** 2026-08-21, Opus

- **Command:** name a type holder `$tVar`, never `$V`, when a loop in the same scope uses `$v`
- **Does:** keeps two variables actually separate.
- **When:** any script with short variable names, especially AST/reflection code.
- **Gotcha:** PowerShell variable names are CASE-INSENSITIVE - `$V` and `$v` are ONE variable. A type
  stored in `$V` is silently overwritten by `foreach ($v in ...)`, and the failure surfaces far away as
  a bizarre cast error ("cannot convert VariableExpressionAst to type System.Type").
- **Verified:** 2026-08-21, Opus

- **Command:** `<cmd-a>; if ($?) { <cmd-b> }`
- **Does:** runs B only when A succeeded.
- **When:** chaining a build to a test, or a stage to the next.
- **Gotcha:** `&&` and `||` are a PARSER ERROR in 5.1 (they work in PowerShell 7). Models write them
  constantly. `;` alone runs B even when A failed.
- **Verified:** 2026-08-21, Opus
- **Command:** in the shell use `D:/proj/src` or a relative path - never `D:\proj\src`
- **Does:** creates/addresses a path without it collapsing.
- **When:** any mkdir / redirect / path arg from the Bash tool.
- **Gotcha:** bash EATS backslashes, so `mkdir "D:\proj\src"` makes ONE dir literally named `Dprojsrc` in the CWD. A real run left four such junk dirs. Forward slashes or relative paths survive; the Write tool avoids the shell entirely.
- **Verified:** 2026-08-27, Opus

- **Command:** `claude -p "Run the bash command: echo hi" --allowedTools "Bash(echo hi)" --max-turns 3 < /dev/null` from a scratch dir whose `.claude/settings.json` registers a `PreToolUse` hook with `"command": "cat > D:/scratch/payload.txt"`
- **Does:** captures the REAL PreToolUse hook payload (raw stdin) from the installed Claude Code binary.
- **When:** measuring what a hook payload actually carries (R37c: vendor docs are a hypothesis).
- **Gotcha:** hook commands run under a bash-like shell here, so use forward-slash paths (`cmd /c more > D:\x` and backslash PowerShell paths wrote nothing); `< /dev/null` avoids a 3s stdin wait; a failed hook is SILENT - always check the capture file exists. T9.5 measurement (claude 2.1.285, 2026-09-29): payload keys = session_id, transcript_path, cwd, prompt_id, permission_mode, effort, hook_event_name, tool_name, tool_input, tool_use_id - `cwd` IS present (absolute Windows path, backslashes), so T9.2 proceeds. Not measured: `cwd` after an in-session `cd` or when launched from a subdirectory - resolve the project defensively (walk up to `docs`/`grades`), do not assume cwd is the root.
- **Verified:** 2026-09-29, Sonnet 5.5

- **Command:** `powershell -NoProfile -Command '$r = Invoke-RestMethod -Uri http://localhost:11434/api/show -Method Post -Body (@{model="qwen3-14b-cc"} | ConvertTo-Json) -ContentType "application/json" -TimeoutSec 15; $r.parameters; $r.model_info.PSObject.Properties | Where-Object { $_.Name -match "context|architecture" } | ForEach-Object { $_.Name + " = " + $_.Value }'`
- **Does:** reads what the local Ollama reports for a model: `parameters` (holds the configured `num_ctx`) and `model_info` (`general.architecture`, `<arch>.context_length` = the model's own maximum). The served context is the LOWER of `num_ctx` and `<arch>.context_length` (C4a OPEN-4(b), decided 2026-10-03).
- **When:** checking or deriving the context Ollama really serves for a `-cc` model; the `<ctx>` source for the S24 WARN.
- **Gotcha:** `/api/show` replies with a very large JSON (the whole licence text), so parse it - do not dump it. A `python` one-liner failed here (Python is not installed); Invoke-RestMethod parses it natively in 5.1. Read-only: it changes nothing. Needs Ollama up (it returns nothing and times out when it is down).
- **Verified:** 2026-10-03, Sonnet 5.5 (Ollama 0.35.0: qwen3-14b-cc -> `num_ctx 65536`, `qwen3.context_length = 40960`)

## Verified by close-unit
<!-- Appended automatically when a unit closes clean. These ran and worked ON THIS MACHINE. -->
| Command | Does | When | Gotcha | Verified |
|---|---|---|---|---|
| `dotnet build local-tools\local-tools.csproj -c Release` | build this project | from the project root | verified by close-unit on T9.1 | 2026-09-29 |
| `powershell -NoProfile -ExecutionPolicy Bypass -File .\test-kit.ps1` | test this project | from the project root | verified by close-unit on T9.1 | 2026-09-29 |
