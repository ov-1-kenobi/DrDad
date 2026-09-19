# Story S1 - Safe uninstall (uninstall.ps1 + uninstall.cmd) : report card

**Current grade: A-**  (as of 2026-09-19, iteration 1 - backfill grade, story was DONE/closed before grade cards existed)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-19        | A-    | backfill grade of shipped implementation (no card existed) |

## Assessment (this iteration)
- **Correctness:** `D:\projects\DrDad\uninstall.ps1` does everything install.ps1 (`D:\projects\DrDad\install.ps1`)
  now sets up, and the two have visibly co-evolved past S1's original scope: beyond the story's original
  4-item behavior list, uninstall.ps1 also reverses install's later additions - the Stop/PreToolUse hook
  cleanup when no `.bak` exists (`uninstall.ps1:52-75`, mirroring `install.ps1:137-146`), PATH removal
  (`uninstall.ps1:99-107` vs `install.ps1:196-212`), `DAD_HOME` unset (`uninstall.ps1:108-112` vs
  `install.ps1:217-221`), and stripping the `~/.bashrc` DAD-kit block (`uninstall.ps1:113-124` vs
  `install.ps1:227-240`). This is legitimate scope-tracking of a companion script, not creep.
- **Acceptance coverage:**
  - AC1 (remove kit commands/agents by name, restore settings.json from `.bak`): commands loop
    (`uninstall.ps1:31-35`) and agents loop (`uninstall.ps1:37-41`) both `Test-Path`-gate before
    `Remove-Item`, so unrelated files are untouched. `.bak` restore is `uninstall.ps1:44-48`. The command/
    agent NAME LISTS are asserted against the real `global\commands`/`global\agents` directories by
    dedicated tests in `test-kit.ps1:633-649` ("uninstall.ps1 lists every command (and no ghosts)" /
    "...every agent..."), and I independently re-verified: the 17 files in `global\commands\*.md` and 18
    in `global\agents\*.md` match `uninstall.ps1:25-26` exactly. GAP: the "restore from .bak" branch of
    AC1 has no automated test - `test-kit.ps1:1100-1114` only sandboxes the NO-`.bak` path (hook-stripping
    branch); the straightforward `Copy-Item $bak $settings` line is unexercised by the suite.
  - AC2 (`-Full` removes model variants + 3 env vars): `uninstall.ps1:78-94`. Variant names are now read
    from `models.json` (`uninstall.ps1:83-84`) rather than hardcoded, verified live against `ollama list`
    output before removing (`uninstall.ps1:85-87`) - this is MORE robust than the original AC2 text (which
    named 4 fixed variants; `models.json` now declares 6, all correctly covered because the list is
    data-driven). Env var removal at `uninstall.ps1:90-93` matches the 3 names in the story and in
    `install.ps1` (via `ollama-tuning.ps1`, not read here directly). `test-kit.ps1:900-906` asserts
    uninstall.ps1 reads `models.json` for variant names (not hardcoded).
  - AC3 (parses + ASCII): confirmed directly - grepped both `uninstall.ps1` and `uninstall.cmd` for any
    non-ASCII byte (`[^\x00-\x7F]`) and found none. `[CmdletBinding()]` at `uninstall.ps1:13` plus the
    comment at `uninstall.ps1:8-12` show deliberate AST-strictness (mistyped params error instead of
    silently falling through to `$args`), which is a good defensive pattern beyond the letter of AC3.
  - AC4 (never touch kit folder / npm package / VS Code extension): satisfied by omission - no code path
    in uninstall.ps1 calls `Remove-Item` on `$PSScriptRoot`/`$root`, `npm uninstall`, or
    `code --uninstall-extension`; the closing banner explicitly prints the manual-removal notice
    (`uninstall.ps1:127`). This is correct but, unlike AC1/AC2, has no regression test guarding against a
    future edit accidentally deleting the kit folder - it is "safe because nothing does it," not "asserted
    safe."
- **Design adherence:** matches the story's `param([switch]$Full)` shape, plus an added `-ClaudeDir` for
  testability (`uninstall.ps1:14-20`, with a comment explaining why: a prior version of the test pinned an
  implementation detail by grepping for `"Remove('Stop')"`, which broke when the removal logic correctly
  generalized to cover a second hook event). This is a reasonable, documented deviation from the story's
  literal interface, in service of the AC3/testability intent, not scope creep.
- **Quality:** dense but well-commented; every non-obvious choice (why `-ClaudeDir` exists, why the hook
  walk covers every event not just Stop, why `dad-guard\.` uses a trailing dot in the match) has an inline
  rationale comment tied to a real incident. Error handling is defensive (`try/catch` around PATH/env/bashrc
  edits so one failure doesn't abort the rest of the teardown). No dead code observed.
- **Hygiene:** `uninstall.ps1`'s command/agent lists are kept in sync with `global\commands`/`global\agents`
  and enforced by `test-kit.ps1:633-649`, so drift is caught by the gate rather than relying on developer
  discipline (exactly what the story's Dev notes asked for). One documentation gap: the story's Dev notes
  say "Add uninstall.ps1/.cmd to the README files table" - `README.md` at repo root has no such table
  currently (grepped for a files/table listing of scripts and found none), so this specific dev-note item
  looks unaddressed, though it may be moot if the table never existed. `docs/DESIGN.md` mentions
  `uninstall.ps1` twice (lines 284, 293) under R8/R19 but has no dedicated "### Uninstaller" subsection
  mirroring the "### Installer (install.ps1 / install.cmd)" one at `docs/DESIGN.md:364-367`.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Add a sandboxed test-kit.ps1 case that exercises the `.bak`-present branch of AC1: seed
   `settings.json.bak` with distinguishable content, run `uninstall.ps1 -ClaudeDir <fake>`, and assert the
   restored `settings.json` matches the `.bak` byte-for-byte. This is the one AC1 sub-clause the current
   suite (`test-kit.ps1:1100-1114`) does not cover (it only exercises the no-`.bak` hook-strip path).
2. [dev] Consider a light regression test asserting uninstall.ps1 never contains a `Remove-Item` targeting
   `$PSScriptRoot`/`$root` (AC4's "never delete the kit folder" is currently true only by absence of code,
   with no test tripwire if a future edit adds one).
3. [mechanical] Either add a "### Uninstaller (uninstall.ps1 / uninstall.cmd)" subsection to
   `docs/DESIGN.md` mirroring the existing Installer subsection (`docs/DESIGN.md:364-367`), or drop that
   Dev-notes line if the README's files table was already retired - currently the note is silently unmet.
