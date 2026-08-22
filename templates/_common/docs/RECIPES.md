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
