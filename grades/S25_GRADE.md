# Story S25 - The Copilot version drift test checks EVERY measured stamp, not just the first : report card

**Current grade: A**  (as of 2026-10-03, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-03        | A     | initial implementation (T25.1 commit 1f88717, T25.2 commit 9162d82) |

## Assessment (this iteration)
- Correctness: `Get-CopilotStampProblems` at test-kit.ps1:1582-1594 uses `[regex]::Matches` (test-kit.ps1:1584) with the
  byte-identical stamp regex, returns one "carries no" problem on zero matches (test-kit.ps1:1585-1587), and per match
  trims a trailing period, computes the line from `$m.Index` by counting "`n" (test-kit.ps1:1589-1590) and emits
  `<Label>:<line> stamped <v> != <constant>` (test-kit.ps1:1591). Exactly the Behavior in docs/STORIES.md:1042-1048.
- Acceptance (code-cited; I did not run the suite - assessor role):
  - AC1: test-kit.ps1:1627-1637 - two 1.0.95 stamps -> 0 problems.
  - AC2: test-kit.ps1:1640-1643 - second stamp at 1.0.89 -> exactly one problem, asserted with `-eq` against
    the problem string for line 6 (stamped 1.0.89 vs constant 1.0.95; first stamp not named). Matches the C5f worked example at docs/DESIGN.md:1481-1484.
  - AC3: test-kit.ps1:1646-1650 - both stamps replaced by prose -> exactly one "carries no" problem; plus
    test-kit.ps1:1653-1654 shows a `against Claude Code` stamp is not counted (the C4a stamp at docs/DESIGN.md:1127).
  - AC4: real-repo case "the measured Copilot version cannot drift between DESIGN's C2 and install.ps1 (C2f)"
    (test-kit.ps1:1596-1622) now calls the function at test-kit.ps1:1608-1610. docs/DESIGN.md holds exactly two Copilot
    stamps, docs/DESIGN.md:683 and docs/DESIGN.md:1311, both 1.0.89 = `$CopilotMeasuredVersion` at install.ps1:32 -> passes by inspection.
  - AC5: full-suite `0 failed` is not independently re-run here; both tasks closed via close-unit (STORIES marker
    `closed:close-unit`, docs/STORIES.md:1035), which refuses a close on a non-zero or zero-test suite run.
  - Fixture case: "S25: the Copilot stamp check covers EVERY MEASURED stamp, not just the first (AC1-AC3)" (test-kit.ps1:1624).
- **AC checkboxes:** docs/STORIES.md:1053-1057 - AC1-AC5 are all still `[ ]` (UNTICKED) even though the story header says
  `Status: DONE closed:close-unit`. T25.1/T25.2 are ticked `[x]` in docs/TASKS.md:2234 and docs/TASKS.md:2250.
- Design: matches C2f/C5f (ONE constant, docs/DESIGN.md:1473-1478). Scope respected: only test-kit.ps1 changed;
  install.ps1, dad-doctor.ps1, docs/DESIGN.md untouched. The read-the-constant block (test-kit.ps1:1603-1606), the
  dad-doctor read-not-copy asserts (test-kit.ps1:1612-1615) and the guards loop (test-kit.ps1:1617-1621) are preserved.
- Quality: small, readable, ASCII, PS 5.1-safe; callers wrap results in `@(...)` so an empty return is a 0-count array;
  failure messages print the actual problem list. One untested branch: the `TrimEnd('.')` path (test-kit.ps1:1589).
- Hygiene: no manifest/dependency impact (test-only change). Verification mode: no AC touches real machine state
  (in-memory fixture strings + a read-only read of docs/DESIGN.md and install.ps1), so no sandbox note is needed.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [human] docs/STORIES.md:1053-1057 - S25's AC1-AC5 checkboxes are unticked while the story is DONE. Decide whether
   close-unit should tick story ACs (it ticks tasks) or the scribe should; same pattern visible in S26 (docs/STORIES.md:1088-1094).
2. [human] docs/DESIGN.md:1470-1472 and docs/DESIGN.md:1477-1478 still state the C2f case checks only the FIRST stamp and that
   the extension is "a follow-up story". Now stale after S25; refresh the C5f Fact text the next time DESIGN is unlocked
   (DESIGN prose cannot be edited while LOCKED).
3. [dev] Add one assertion to the S25 fixture case (test-kit.ps1:1624-1655) for a stamp that ends a sentence, e.g.
   `MEASURED 2026-09-30 against GitHub Copilot CLI 1.0.95.` -> 0 problems, so the `TrimEnd('.')` at test-kit.ps1:1589 is
   proven rather than only read. Low priority: no current DESIGN stamp ends with a period.
