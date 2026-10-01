# Story S22 - doc-stats flags a contract that is REFERENCED but never PINNED (R24) : report card

**Current grade: A-**  (as of 2026-10-01, iteration 2)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-01        | A-    | first card for S22; T22.1 (da3cecf) doc-stats.ps1 check and T22.2 (23e1015) Test-Case READ |
| 2    | 2026-10-01        | A-    | cites rewritten as full relative paths; doc-stats.ps1 cites after line 250 shifted +1 by hygiene's comment edit; mechanical item applied; AC5 confirmed by a live doc-stats run |

## Assessment (this iteration)
Read (line numbers re-verified against the files as they are NOW): docs/STORIES.md:904-942 (S22), docs/TASKS.md:2005-2039
(T22.1, T22.2), doc-stats.ps1:111-121 (`$storiesFile`, `$tasksFile`, `$designName`), doc-stats.ps1:220-282 (design
findings block incl. the new check), test-kit.ps1:4204-4270 (the new case), docs/DESIGN.md:545-1468 (Contracts headings
only, via grep). Hygiene added a 2-line comment edit at doc-stats.ps1:250-251 (the "Fenced code blocks are NOT skipped"
note), so every doc-stats.ps1 cite after line 250 moved down by 1; all cites below use the current numbers. test-kit.ps1
was not shifted. Not run by me: build/tests, and `git show` (assessor has no shell; commits judged from the files at HEAD).

- Correctness: good. The existing heading regex is hoisted once as `$contractHeadingRx` (doc-stats.ps1:237) and reused by
  both the empty-Contracts check (doc-stats.ps1:239) and the new check (doc-stats.ps1:254) - no second regex (Behavior 1).
  References use `[regex]::Matches` with `\bC[0-9]+[a-z]?(?:-[a-z0-9]+)?\b` (doc-stats.ps1:262), case-sensitive as the
  story requires. Resolution is exact-or-parent via `^C[0-9]+` (doc-stats.ps1:264-265). Sources are design, STORIES,
  TASKS in that order, each skipped if absent, never grades\ (doc-stats.ps1:256-258). First location per file per id via a
  per-file HashSet (doc-stats.ps1:260, 266); an ordered dictionary keeps first-seen id order (doc-stats.ps1:255, 267).
  The gate is ONLY the `## Contracts` section, no Status test (doc-stats.ps1:252), so DRAFT and LOCKED both fire. Message
  text, 8-entry cap and ` ...` suffix match the story wording (doc-stats.ps1:272-276); it goes into `$f` with the other
  `[design]` findings (Dev notes, docs/STORIES.md:940-942).
- Acceptance: AC1 test-kit.ps1:4222-4237 - the exact expected string at test-kit.ps1:4227 ends with the fixture's TASKS
  location followed by a closing paren, which proves the fixture's second DESIGN reference (line 9) is not listed; the
  LOCKED re-run is at test-kit.ps1:4231-4233 and pinning clears it at test-kit.ps1:4235-4237. AC2 test-kit.ps1:4239-4244
  (C4a, C3-b). AC3 test-kit.ps1:4246-4250 (C2PA, C#, C++, plus lowercase `c9`/`c12` built at runtime - stronger than
  asked). AC4 test-kit.ps1:4252-4257 (ids built as `"C" + 7`, so the suite text carries no dangling id). Cap
  test-kit.ps1:4259-4268 (count 10, exactly 8 entries, ` ...`). AC5: CONFIRMED - `dad doc-stats -Findings` on the kit
  printed no "REFERENCED but never PINNED" finding (2026-10-01, reported by the coordinator). That matches my grep:
  docs/DESIGN.md:545 is `## Contracts`, docs/DESIGN.md:1301 pins `### C5:`, and a case-sensitive grep of DESIGN/STORIES/
  TASKS found no id numbered 0 or >= 6; every C1-C5 sub-id has a pinned parent. AC6 and the T22.2 mutation check (parent
  rule as a no-op -> AC2 fails) are not verifiable by me without a shell.
- Design: in scope. `-Contract <id>` (doc-stats.ps1:88-108 per the T22.1 Refs) and the empty-Contracts finding's
  behaviour are unchanged apart from using the hoisted variable; docs/DESIGN.md was not edited to silence anything.
- Quality: compact, commented with the why (doc-stats.ps1:244-251), PS 5.1-safe (no ternary, explicit generic types).
  Edge gap: the heading regex accepts UPPERCASE suffixes (`[A-Za-z0-9-]*`) but the reference regex only lowercase ones,
  so a heading `### C7-API:` pins `C7-API`, while a reference `C7-API` is read as `C7` (\b before `-`), whose parent is not
  pinned -> a false WARN. The kit does not hit this today. The gate uses `-match` (case-insensitive) on `## Contracts`,
  the same as the existing gate - consistent.
- Hygiene: only doc-stats.ps1 and test-kit.ps1 touched per the tasks; ASCII; the test cleans its sandbox in `finally`
  (test-kit.ps1:4269) and removes the TASKS/STORIES fixtures between sub-cases via `Set-S22Doc ... $null`
  (test-kit.ps1:4214).
- Verification mode: no AC touches real machine state (doc-stats only reads docs; fixtures are New-Sandbox %TEMP% dirs).
  AC5 was verified by a live read-only doc-stats run on the kit repo (2026-10-01, per the coordinator), backed by my
  code review and grep.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Make the two id formats agree: either let resolution also succeed when a pinned id has the same `^C[0-9]+`
   parent as the reference (doc-stats.ps1:264-265), or restrict the heading regex suffix to the reference format. Today
   `### C7-API:` plus a reference to `C7-API` WARNs falsely. Add a check for it to the AC2 block (test-kit.ps1:4239-4244).
2. [human] Confirm the T22.2 mutation check (parent rule as a no-op makes the AC2 assert fail) was actually performed;
   AC5 itself is now confirmed by a live run.
3. ~~[mechanical] Note in the comment that fenced code blocks are scanned.~~ APPLIED by hygiene: doc-stats.ps1:250-251.
