# Story S27 - upgrade-project writes the files it refreshes with the project's line endings, not CRLF : report card

**Current grade: A-**  (as of 2026-10-03, iteration 2)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-03        | A-    | initial implementation (T27.1 fde54b1 + T27.2 2bbc8c6)                     |
| 2    | 2026-10-03        | A-    | iter-1 suggestions 1-4 all closed (T27.3 cbc33df, T27.4 e8a1e84, T27.5 5e3b47d, story amended 56be8b7); new gap: the amended Behavior's mixed-ending / no-newline / empty-file rules have no test |

## Assessment (this iteration)
Graded against the AMENDED story (docs/STORIES.md:1101-1155, amended 2026-10-03 in 56be8b7). I re-read every
cite below in the current files.

- Correctness: the code matches the amended Goal and Behavior (docs/STORIES.md:1112-1131) for all four files.
  - The S26 guard at upgrade-project.ps1:33-39 is still the first thing that can stop the run. The helpers
    come after it and before any write, and are unchanged since iteration 1:
    - `Get-ProjectEol` at upgrade-project.ps1:45-71 reads raw text with `ReadAllText`.
    - `ConvertTo-Eol` at upgrade-project.ps1:72-76 normalizes to LF first, then expands, so a rewritten file
      never has mixed endings.
  - Call sites:
    - `.mcp.json`: upgrade-project.ps1:127-128.
    - CLAUDE.md: the ending is detected at upgrade-project.ps1:255, BEFORE the rewrite. The text is joined and
      terminated at upgrade-project.ps1:287 and written at upgrade-project.ps1:288.
    - Stamp: upgrade-project.ps1:290-291.
    - `.gitignore` (T27.4): `$gEol = Get-ProjectEol $gi` at upgrade-project.ps1:150 runs before anything
      writes `$gi`. The fresh file at upgrade-project.ps1:159-160 is joined with LF and passed through
      `ConvertTo-Eol`. The two appends at upgrade-project.ps1:167-168 and upgrade-project.ps1:172-173 use
      `AppendAllText` with UTF-8 no BOM, so the user's existing bytes are never rewritten.
  - Unterminated last line (T27.5): `Get-GitignoreLead` at upgrade-project.ps1:151 returns `$Eol` only when the
    file is non-empty and its last char is not `[char]10`. That is an ordinal compare, not the culture-sensitive
    `EndsWith`. The lead is recomputed right before EACH append (upgrade-project.ps1:167, upgrade-project.ps1:172),
    so the second append never gets a blank line in front of it.
  - Mixed-ending rule (docs/STORIES.md:1123-1125): upgrade-project.ps1:49 returns CRLF on any CRLF. A
    rewritten file goes through `ConvertTo-Eol` and comes out uniform. In `.gitignore` only the appended block
    goes through it, which matches "in `.gitignore` only the appended block is uniform".
  - No-newline rule (docs/STORIES.md:1126-1127): the early return at upgrade-project.ps1:48 fires only when
    the raw text holds a "`n". Otherwise the code falls through to the `.gitattributes` walk at
    upgrade-project.ps1:52-70, which defaults to LF.
  - Nothing else in step 2 changed:
    - the entries and their order (`$secretIgnores` at upgrade-project.ps1:152);
    - both conditions (upgrade-project.ps1:166, upgrade-project.ps1:171);
    - both console lines (upgrade-project.ps1:169, upgrade-project.ps1:174);
    - the `$cur`/`$missing` computation (upgrade-project.ps1:164-165).
- Acceptance: AC1-AC6 are all covered by named tests. Three Behavior rules are not (see below).
  - AC1: "S27 AC1: upgrade-project keeps an LF CLAUDE.md LF and still refreshes kit sections"
    (test-kit.ps1:5072-5086). It runs a byte-level `-notcontains 13` check, verifies the old Modes body was
    refreshed, and verifies Stack was preserved.
  - AC2: "S27 AC2: upgrade-project keeps a CRLF CLAUDE.md CRLF throughout" (test-kit.ps1:5088-5100). It uses
    `Test-S27Crlf` at test-kit.ps1:5067-5070, which requires CRLF present and fails on any bare LF.
  - AC3: "S27 AC3: .mcp.json repoint and .dad-kit-version follow the same rule" (test-kit.ps1:5102-5148), with
    sub-cases (a)-(e): LF and CRLF `.mcp.json`; a fresh stamp with no `.gitattributes` comes out LF; a fresh
    stamp under `eol=crlf` comes out CRLF; an existing CRLF stamp is kept CRLF with the current version.
    - The iteration-1 gap is CLOSED. Sub-case (b) at test-kit.ps1:5124-5136 could not tell which rule won.
      The new case "S27 AC3 follow-up: an existing file's line ending beats a conflicting .gitattributes eol"
      (test-kit.ps1:5153-5187) can:
      - (a) An LF `.mcp.json` and an LF CLAUDE.md under `eol=crlf` stay LF (test-kit.ps1:5172-5173). A control
        checks that the FRESH stamp does end CRLF (test-kit.ps1:5175), which proves the attribute file is read.
      - (b) A CRLF CLAUDE.md under `eol=lf` stays CRLF (test-kit.ps1:5183). Its control is a fresh stamp with
        no CR (test-kit.ps1:5185).
    - The stamp and `.gitignore` are not tested against a conflicting attribute. All four writes share
      `Get-ProjectEol`, so this one case covers the rule order for all of them.
  - AC4: the S26 cases are untouched. S26 AC3 is at test-kit.ps1:5047-5058. The T10.5 source-regex pin
    `$noiseIgnores  = @(".claude/")` is still verbatim at upgrade-project.ps1:157.
  - AC5: I did not run the suite (this agent has no shell). The orchestrator reports that close-unit at
    5e3b47d ran the Test command with 262 passed, 0 failed.
  - AC6 has two cases:
    - "S27 follow-up: .gitignore keeps its line ending" (test-kit.ps1:5191-5240):
      - (a) An existing LF file gets no CR. The user's prefix is kept, both appends are present, and the file
        ends in LF.
      - (b) An existing CRLF file passes `Test-S27Crlf`, keeps its prefix, and contains "`r`n.env`r`n" and
        "`r`nbin/`r`n".
      - (c) A fresh file with no `.gitattributes` comes out LF.
      - (d) A fresh file under `eol=crlf` comes out CRLF.
    - "S27 follow-up: an appended .gitignore entry is never glued onto an unterminated last line"
      (test-kit.ps1:5245-5295):
      - Sub-cases: (a) LF unterminated, (b) CRLF unterminated, (c) already terminated.
      - The glue check runs first (test-kit.ps1:5278-5279), so one failure message names both glued
        sub-cases.
      - The no-blank-line asserts (test-kit.ps1:5284, test-kit.ps1:5289, test-kit.ps1:5293) catch a lead that
        is reused for the second append.
      - (c) asserts that no separator was added (test-kit.ps1:5292).
    - Both cases `Skip-Case` when git is absent (test-kit.ps1:5192, test-kit.ps1:5246), so AC6 is proven only
      on a machine that has git.
  - Behavior rules that NO test covers. I read the code for each and it looks correct (see Correctness):
    - (i) A mixed-ending existing file is treated as CRLF (docs/STORIES.md:1123-1125). Searching test-kit.ps1
      for "mixed" finds only the repo-wide line-ending check at test-kit.ps1:525-549, not an upgrade-project
      case.
    - (ii) An existing file with no newline at all follows the fresh-file rule (docs/STORIES.md:1126-1127).
    - (iii) An EMPTY `.gitignore` gets no separator (docs/STORIES.md:1121-1122).
    - Two regressions would pass the whole suite today: changing upgrade-project.ps1:49 to "any bare LF wins",
      or dropping the `Contains("`n")` guard at upgrade-project.ps1:48.
  - Mutation checks for T27.2-T27.5: I could not verify these from the code. They are Do steps in docs/TASKS.md
    T27.3-T27.5, and all five tasks are ticked `[x]`.
- STORIES.md AC boxes: now ticked `[x]` at docs/STORIES.md:1138-1149. That is consistent with
  `Status: DONE closed:close-unit` at docs/STORIES.md:1101 and with S26's precedent at docs/STORIES.md:1088-1095.
  I did not edit STORIES.md.
- Design: matches docs/TASKS.md T27.1-T27.5 step by step.
  - T27.4/T27.5 changed only step 2 (upgrade-project.ps1:145-176). `Get-ProjectEol` and `ConvertTo-Eol` were
    reused unchanged.
  - `Get-GitignoreLead`'s placement and its ordinal last-char compare follow T27.5 Do step 1 to the letter.
  - The story's Data / interfaces (docs/STORIES.md:1132-1135) now names all three helpers and the `.gitignore`
    writes. The iteration-1 mismatch (TASKS excluded `.gitignore`, STORIES never named it) is gone.
  - No scope creep: `new-project.ps1`, templates and docs/DESIGN.md were not touched.
  - Where things are pinned: the `.gitattributes` subset in the comment at upgrade-project.ps1:41-44; the
    `.gitignore` rule comments at upgrade-project.ps1:148-149; the header at upgrade-project.ps1:10.
- Quality: small, readable, PS 5.1-safe, ASCII.
  - Tests use byte-level asserts only and never `Get-Content` for ending checks.
  - Fixtures go through `Write-S27File` (test-kit.ps1:5064-5066), and no case passes `$kit` as `-ProjectDir`,
    as the comment at test-kit.ps1:5060-5062 states.
  - Assert messages name the sub-case and the failure mode, for example ".gitattributes beat the existing
    ending" at test-kit.ps1:5172.
  - Nit: `Get-GitignoreLead` is a single semicolon-chained line at upgrade-project.ps1:151, defined inside the
    git `if` block. The other S27 helpers at upgrade-project.ps1:45-76 are multi-line at the top of the
    script. T27.5 prescribed this location, so it is a style point only.
  - Cost note: the two AC6 cases start 7 upgrade-project processes between them, each with git init, a
    baseline commit and install-hooks. I did not measure the added suite time.
- Hygiene: no manifest or dependency changes, so nothing to sync.
  - Adjacent, and out of scope by the story's own "Not changed: `new-project.ps1`" (docs/STORIES.md:1134-1135):
    new-project.ps1:60 writes the stamp with a hardcoded "`r`n", and new-project.ps1:99 joins the fresh
    `.gitignore` with "`r`n".
  - So a freshly scaffolded project starts CRLF, while upgrade-project's fresh-file default is LF. Upgrades
    keep that CRLF (the existing ending wins), so there is no upgrade diff. But a scaffold into a folder whose
    `.gitattributes` declares `eol=lf` ignores that setting.
- Verification mode: every AC writes project files. AC6's cases also run git init, a baseline commit and
  install-hooks (upgrade-project.ps1:190-223).
  - All six S27 cases run upgrade-project only against `New-Sandbox` folders under %TEMP% (test-kit.ps1:5073,
    test-kit.ps1:5089, test-kit.ps1:5103, test-kit.ps1:5154, test-kit.ps1:5193, test-kit.ps1:5247).
  - The git identity is passed with `-c` (upgrade-project.ps1:210) and `core.autocrlf` is set repo-local
    (upgrade-project.ps1:208), so no global git config is touched.
  - AC1-AC4 and AC6: live-sandboxed by design via `New-Sandbox` (%TEMP%; never the kit repo or D:\Tools). My
    own verification is code-review-only because this agent has no shell. That the cases ran green rests on
    close-unit's Test gate at 5e3b47d.
  - AC5: code-review-only for me. The result (262 passed, 0 failed) is as reported by the orchestrator from
    close-unit.
  - The counts-only summary cannot show whether the two AC6 cases PASSED or SKIPPED. T27.4 and T27.5 both
    require "PASS line (not SKIP)". See suggestion 7.

## Suggestions (prioritized; tag each so the team knows who acts)
Numbers 1-4 are kept stable because docs/TASKS.md T27.3 and T27.4 cite "suggestion 1" and "suggestion 3" by
number. Open items, in priority order: 5, 6, 7, 8.

1. [dev] APPLIED (T27.3, cbc33df; verified 2026-10-03). Add a discriminating sub-case where an existing file's
   ending disagrees with `.gitattributes`. Done: "S27 AC3 follow-up: an existing file's line ending beats a
   conflicting .gitattributes eol" (test-kit.ps1:5153-5187) has both directions plus fresh-stamp controls.
2. [mechanical] APPLIED (56be8b7; verified 2026-10-03). Tick S27's AC boxes. Done: AC1-AC6 are `[x]` at
   docs/STORIES.md:1138-1149.
3. [human] APPLIED (decided 2026-10-03 as cleanup tasks T27.4 e8a1e84 and T27.5 5e3b47d; story amended
   56be8b7; verified 2026-10-03). Make the `.gitignore` writes follow the line-ending rule. Done:
   upgrade-project.ps1:150, upgrade-project.ps1:159-160, upgrade-project.ps1:167-168 and
   upgrade-project.ps1:172-173; story Behavior at docs/STORIES.md:1117-1122; AC6 at docs/STORIES.md:1146-1149.
4. [human] APPLIED (decided 2026-10-03, rule kept; verified 2026-10-03). Pin "any CRLF wins" for mixed files.
   Done: stated at docs/STORIES.md:1123-1125, and the code at upgrade-project.ps1:49 is unchanged. It is still
   untested; see 5.
5. [dev] Add one test-kit case, e.g. "S27 follow-up: mixed, no-newline and empty files follow the stated rules",
   to pin the three untested Behavior rules (fixtures under `New-Sandbox` only; `Skip-Case` without git for the
   `.gitignore` parts):
   - (a) A mixed CLAUDE.md (some lines CRLF, some bare LF) -> `Test-S27Crlf` passes after upgrade.
   - (b) A mixed `.gitignore`, e.g. "node_modules/`r`ncustom/`n" -> the original bytes are kept as a prefix,
     and the appended suffix has CRLF and no bare LF. Do not run `Test-S27Crlf` on the whole file: the user's
     bare LF must remain.
   - (c) Under `eol=crlf`, an existing stamp "0.0.0" with no newline -> ends "`r`n". An existing single-line
     `.gitignore` "custom/" -> starts "custom/`r`n.env`r`n".
   - (d) An empty `.gitignore` -> starts with ".env" (no lead).
   - Mutation: making upgrade-project.ps1:49 prefer LF, or removing the `Contains("`n")` guard at
     upgrade-project.ps1:48, must make this case fail. Today both mutations pass the suite.
6. [human] new-project.ps1 still hardcodes CRLF for the stamp (new-project.ps1:60) and the fresh `.gitignore`
   (new-project.ps1:99). upgrade-project's fresh-file default is LF and follows `.gitattributes`. S27 excluded
   new-project on purpose (docs/STORIES.md:1134-1135). Decide whether scaffolding should follow the same rule
   as its own story. The helpers would then need a shared home or a deliberate copy.
7. [human] Confirm that the 5e3b47d close-unit run showed "S27 follow-up: .gitignore keeps its line ending"
   and "S27 follow-up: an appended .gitignore entry is never glued onto an unterminated last line" on PASS
   lines, not SKIP. "262 passed, 0 failed" is counts-only, and both cases `Skip-Case` without git
   (test-kit.ps1:5192, test-kit.ps1:5246). If CI ever lacks git, AC6 silently loses its proof.
8. [mechanical] Optional, no behavior change: reformat `Get-GitignoreLead` at upgrade-project.ps1:151 onto
   several lines in place (same location, same logic, keep the `[char]10` ordinal compare) to match the helper
   style at upgrade-project.ps1:45-76.
