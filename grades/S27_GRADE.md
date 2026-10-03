# Story S27 - upgrade-project writes the files it refreshes with the project's line endings, not CRLF : report card

**Current grade: A-**  (as of 2026-10-03, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-03        | A-    | initial implementation (T27.1 fde54b1 + T27.2 2bbc8c6)                     |

## Assessment (this iteration)
- Correctness: matches Goal/Behavior. Two helpers sit after the S26 guard (upgrade-project.ps1:33-39 is
  still the first thing that can stop the run) and before any write: `Get-ProjectEol` at
  upgrade-project.ps1:45-71 reads raw text with `ReadAllText` (not Get-Content, per Dev notes), returns
  CRLF if the existing file has any CRLF, LF if it has only bare LF, and otherwise (fresh file or no
  newline) walks the project's `.gitattributes` with last-match-wins, defaulting to LF.
  `ConvertTo-Eol` at upgrade-project.ps1:72-76 normalizes to LF first, then expands, so the output never
  has mixed endings. All three writes use them: `.mcp.json` at upgrade-project.ps1:127-128, CLAUDE.md
  (detected at upgrade-project.ps1:249 BEFORE the rewrite, joined/terminated at upgrade-project.ps1:281,
  written at upgrade-project.ps1:282), stamp at upgrade-project.ps1:284-285. The rest of the content
  stays the same: same sections, same JSON, same `$kitVer`, same UTF-8 no-BOM encoding.
- Acceptance:
  - AC1 is covered by "S27 AC1: upgrade-project keeps an LF CLAUDE.md LF and still refreshes kit sections"
    (test-kit.ps1:5072-5086). It runs a byte-level `-notcontains 13` check, verifies the old Modes body
    was refreshed, and verifies Stack was preserved.
  - AC2 is covered by "S27 AC2: upgrade-project keeps a CRLF CLAUDE.md CRLF throughout"
    (test-kit.ps1:5088-5100), which uses `Test-S27Crlf` at test-kit.ps1:5067-5070 (requires CRLF present
    and fails on any bare LF).
  - AC3 is covered by "S27 AC3: .mcp.json repoint and .dad-kit-version follow the same rule"
    (test-kit.ps1:5102-5148), sub-cases (a)-(e): LF and CRLF `.mcp.json`, a fresh stamp with no
    `.gitattributes` comes out LF, a fresh stamp under `eol=crlf` comes out CRLF, and an existing CRLF
    stamp is kept CRLF with the current version. Gap: no case shows that an EXISTING file's ending beats
    a conflicting `.gitattributes`. In (b), at test-kit.ps1:5125-5135, the file and the attribute are both
    CRLF, so the test cannot tell which rule produced the result.
  - AC4: the existing upgrade-project and S26 cases are untouched. The S26 AC3 case at
    test-kit.ps1:5047-5058 is directly above the new block.
  - AC5: I did not run the suite (this agent has no shell). Commit 2bbc8c6 was closed by close-unit,
    which gates on the Test command.
  - I could not verify the T27.2 mutation check (forcing the join back to CRLF should fail AC1) from
    the code.
- STORIES.md AC boxes: NOT ticked. All five S27 boxes at docs/STORIES.md:1123-1130 are still `[ ]`,
  even though the header at docs/STORIES.md:1101 says `Status: DONE closed:close-unit`. S26's boxes at
  docs/STORIES.md:1090-1095 are ticked `[x]`, so S27 is inconsistent with that precedent. I did not
  edit STORIES.md.
- Design: matches docs/TASKS.md T27.1 step by step (helpers, three call sites, header comment at
  upgrade-project.ps1:10). No scope creep: `new-project.ps1`, templates and docs/DESIGN.md were not
  touched. The `.gitattributes` subset (`*`, exact name, `*.<ext>`, `eol=lf|crlf`) is pinned in the
  comment at upgrade-project.ps1:41-44.
- Quality: small and readable, PS 5.1-safe, ASCII. The test fixtures use their own no-BOM writer
  (test-kit.ps1:5064-5066), and none of them pass `$kit` as `-ProjectDir` (`$kit` is only used to locate
  the script, as stated in the comment at test-kit.ps1:5060-5062). One untested edge: a mixed-ending
  existing file is classified as CRLF if it contains ANY CRLF (upgrade-project.ps1:49). The output is
  still uniform, but the rule is not stated in the story.
- Hygiene: no manifest or dependency changes, so nothing to sync. Out of scope but adjacent: the
  `.gitignore` writes still hardcode CRLF. The fresh file is written at upgrade-project.ps1:155-156 and
  the appends use `Add-Content` with "`r`n" at upgrade-project.ps1:163 and upgrade-project.ps1:167.
  docs/TASKS.md T27.1 explicitly excludes them ("NOT the `.gitignore` writes").
- Verification mode: every AC writes project files and runs `git init`/install-hooks, which is machine
  state if pointed at a real project. All three S27 cases run upgrade-project only against `New-Sandbox`
  folders under %TEMP% (test-kit.ps1:5073, test-kit.ps1:5089, test-kit.ps1:5103), so the design is
  live-sandboxed. My own verification is code-review-only because I cannot run the suite. Confirmation
  that it was actually run green rests on close-unit's Test gate for commit 2bbc8c6.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Add a discriminating sub-case to "S27 AC3: .mcp.json repoint and .dad-kit-version follow the
   same rule": an existing LF `.mcp.json` (or stamp) with `.gitattributes` `* text=auto eol=crlf`
   should stay LF. Today's (b) case at test-kit.ps1:5125-5135 gives the same result whether the
   existing-ending rule or the `.gitattributes` rule is used, so a regression that put attributes first
   would pass.
2. [mechanical] Tick S27's AC1-AC5 boxes at docs/STORIES.md:1123-1130 to match the DONE status at
   docs/STORIES.md:1101 and S26's precedent at docs/STORIES.md:1090-1095. Do this only after confirming
   the full `.\test-kit.ps1` prints `0 failed` with the three "S27 AC..." names on PASS lines.
3. [human] The `.gitignore` writes in upgrade-project.ps1 still use CRLF: the fresh file at
   upgrade-project.ps1:155 and the `Add-Content` appends at upgrade-project.ps1:163 and
   upgrade-project.ps1:167. In an `eol=lf` project, an upgrade that adds ignore patterns still adds
   CRLF lines, which means mixed endings in that file. T27.1 excluded this on purpose. Decide whether to
   file it as its own story; the fix would reuse `Get-ProjectEol`/`ConvertTo-Eol`.
4. [human] Mixed-ending existing files resolve to CRLF if any CRLF is present (upgrade-project.ps1:49).
   Confirm "any CRLF wins" is the intended rule (the alternative is majority), and if so, pin it in the
   story text.
