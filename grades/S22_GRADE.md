# Story S22 - doc-stats flags a contract that is REFERENCED but never PINNED (R24) : report card

**Current grade: A-**  (as of 2026-10-01, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-01        | A-    | first card for S22; T22.1 (da3cecf) doc-stats.ps1 check and T22.2 (23e1015) Test-Case READ |

## Assessment (this iteration)
Read (line numbers verified against the files as they are NOW): docs/STORIES.md:904-942 (S22), docs/TASKS.md:2005-2039
(T22.1, T22.2), doc-stats.ps1:111-121 (`$storiesFile`, `$tasksFile`, `$designName`), doc-stats.ps1:220-281 (design
findings block incl. the new check), test-kit.ps1:4204-4270 (the new case), docs/DESIGN.md:545-1468 (Contracts headings
only, via grep). Not run: build/tests, and `git show` (assessor has no shell; commits judged from the files at HEAD).

- Correctness: good. The existing heading regex is hoisted once as `$contractHeadingRx` (doc-stats.ps1:237) and reused by
  both the empty-Contracts check (doc-stats.ps1:239) and the new check (doc-stats.ps1:253) - no second regex (Behavior 1).
  References use `[regex]::Matches` with `\bC[0-9]+[a-z]?(?:-[a-z0-9]+)?\b` (doc-stats.ps1:261), case-sensitive as the
  story requires. Resolution is exact-or-parent via `^C[0-9]+` (doc-stats.ps1:263-264). Sources are design, STORIES,
  TASKS in that order, each skipped if absent, never grades\ (doc-stats.ps1:255-257). First location per file per id via a
  per-file HashSet (doc-stats.ps1:259, 265); ordered dictionary keeps first-seen id order (doc-stats.ps1:254, 266).
  Gate is ONLY the `## Contracts` section, no Status test (doc-stats.ps1:251), so DRAFT and LOCKED both fire. Message text,
  8-entry cap and ` ...` suffix match the story wording (doc-stats.ps1:271-275); it goes into `$f` with the other
  `[design]` findings (Dev notes).
- Acceptance: AC1 test-kit.ps1:4222-4237 (exact string incl. `TASKS.md:5)` - the closing paren proves DESIGN.md:9 is not
  listed; LOCKED re-run at 4231-4233; pinning clears at 4235-4237). AC2 test-kit.ps1:4239-4244 (C4a, C3-b). AC3
  test-kit.ps1:4246-4250 (C2PA, C#, C++, plus lowercase `c9`/`c12` built at runtime - stronger than asked). AC4
  test-kit.ps1:4252-4257 (ids built as `"C" + 7`, so the suite text carries no dangling id). Cap test-kit.ps1:4259-4268
  (count 10, exactly 8 entries, ` ...`). AC5: code-review only - DESIGN pins C1..C5 with `## Contracts` at
  docs/DESIGN.md:545 and `### C5:` at docs/DESIGN.md:1301; a case-sensitive grep of DESIGN/STORIES/TASKS for any id with
  number 0 or >= 6 returned nothing, and every C1-C5 sub-id has a pinned parent, so the kit should be silent. AC6 and the
  T22.2 mutation check (parent rule as no-op -> AC2 fails) are not verifiable without a shell.
- Design: in scope. `-Contract <id>` (doc-stats.ps1:88-108 per T22.1 Refs) and the empty-Contracts finding's behaviour
  are unchanged apart from using the hoisted variable; DESIGN.md was not edited to silence anything.
- Quality: compact, commented with the why (doc-stats.ps1:244-250), PS 5.1-safe (no ternary, explicit generic types).
  Edge gap: the heading regex accepts UPPERCASE suffixes (`[A-Za-z0-9-]*`) but the reference regex only lowercase ones,
  so a heading `### C7-API:` pins `C7-API` while a reference `C7-API` is read as `C7` (\b before `-`) whose parent is not
  pinned -> false WARN. Not hit by the kit today. Gate uses `-match` (case-insensitive) on `## Contracts`, same as the
  pre-existing gate - consistent.
- Hygiene: only doc-stats.ps1 and test-kit.ps1 touched per the tasks; ASCII; the test cleans its sandbox in `finally`
  (test-kit.ps1:4269) and removes TASKS/STORIES between sub-cases via `Set-S22Doc ... $null` (test-kit.ps1:4214).
- Verification mode: no AC touches real machine state (doc-stats only reads docs; fixtures are New-Sandbox %TEMP% dirs).
  AC5 is code-review-only here (grep of the real docs), not a live doc-stats run - T22.2 step 7 asked dev to report the
  live result; that report was not in my inputs.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Align the two id grammars: either let resolution also succeed when a pinned id has the same `^C[0-9]+` parent as
   the reference (doc-stats.ps1:263-264), or restrict the heading regex suffix to the reference grammar. Today
   `### C7-API:` + reference `C7-API` WARNs falsely. Add a Test-Case line for it in test-kit.ps1:4239-4244 (AC2 block).
2. [human] Confirm AC5 live: run `.\doc-stats.ps1 -Findings` on the kit and check no `REFERENCED but never PINNED` line
   appears (my evidence is a grep, see Assessment), and that the T22.2 mutation check was actually performed.
3. [mechanical] None required; optionally note in the comment at doc-stats.ps1:244-250 that fenced code blocks are
   scanned too (a `C<n>` in a code sample counts as a reference).
