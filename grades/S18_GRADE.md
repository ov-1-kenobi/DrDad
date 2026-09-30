# Story S18 - Verifier claims are computed or cross-checked, not taken on report : report card

**Current grade: B+**  (as of 2026-09-30, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-30        | B+    | first card for S18; close-unit check, build.md text and test bodies READ; suite not run (assessor is read-only) |

## Assessment (this iteration)
Read: docs/STORIES.md:756-786 (S18 block), docs/TASKS.md:1817-1854 (T18.1-T18.3), close-unit.ps1:186-238 and
close-unit.ps1:527-536, global/commands/build.md:150-171, and the test bodies at test-kit.ps1:4968-5058. Not run:
build or suite.

- Correctness: good. Test-GradeCard (close-unit.ps1:201-238) keeps the old size and heading checks, then scans
  every `file:line` (regex at close-unit.ps1:210, range `a-b` uses the larger end at 214). It resolves the path
  relative to the project root, else a UNIQUE same-name file with bin/obj/.git/_tmp/node_modules excluded
  (216-220), and fails on a missing file (220) or a line past EOF (223). If no file:line cited, it falls back to
  `test-kit.ps1:<n>` (228) or a backticked/quoted name of a real Test-Case in test-kit.ps1 (230-232). Nothing
  checkable returns the failure at 236. The gate is binding only with -RequireGrade (close-unit.ps1:533).
- Acceptance: AC1 covered by "close-unit -RequireGrade AC1: a headings-only card with no citation is refused, a
  cited one is accepted" (test-kit.ps1:4968) and "close-unit -RequireGrade AC1: a card citing an existing
  file:line is accepted" (test-kit.ps1:5003). AC2 covered by "close-unit -RequireGrade AC2: a card citing an
  out-of-range line or a missing file is refused" (test-kit.ps1:5025). AC3 covered by "build.md carries the S18
  post-hygiene re-check and neutral grading prompt text" (test-kit.ps1:5053), asserting `doc-stats -Findings`,
  `CONTRADICTED` and `Neutral prompt`; the text is at global/commands/build.md:153-165. AC4: the grandfather
  decision is stated in a comment at close-unit.ps1:197-200 (cards S1-S12 need no backfill); the full-suite
  half was not run by me.
- Design: matches the story Behavior (docs/STORIES.md:765-773). Scope is tight: the check does not judge quality.
  The one undocumented rule (unique same-name fallback) is flagged in docs/TASKS.md:1888 as a [design] note.
- Gaps found:
  (a) build.md:151 says the gate requires `## Assessment` and `## Suggestions`, but Test-GradeCard
  (close-unit.ps1:206) only enforces `## Grade history`. The script is weaker than the prose; a card can pass
  without those two headings.
  (b) The CONTRADICTED re-check (build.md:160-165) is orchestrator prose only. The test at test-kit.ps1:5053 is a
  phrase-presence check, so it proves the text landed, not that a close is blocked. That is inherent to AC3 as
  written, but it is the weakest link in the "computed, not reported" goal.
  (c) No test covers the unique-leaf fallback, the ambiguous-leaf refusal (two same-name files -> "cites missing
  file"), the `a-b` range branch (close-unit.ps1:214), or an old-card non-regression for AC4.
  (d) The file:line regex also matches incidental prose such as a URL or a version-like name-colon-number pair; a card
  mentioning one that does not resolve would be refused. Low risk, but error text does not hint at the cause.
  (e) The first AC1 case notes (test-kit.ps1:4989-4990) that the story is rolled up to DONE before the grade
  gate fires, so a refusal is only the non-zero exit, not an un-DONE file. Pre-existing ordering, but it weakens
  "a card that cites nothing FAILS the gate" to "close exits non-zero after stamping".
- Quality: readable, small, single function, first-failure-only reporting, deterministic. Test sandboxes are
  consistent with neighbouring cases and skip without git.
- Hygiene: build.md is a global command, so the installed copy only updates after the human re-runs install.cmd
  (docs/TASKS.md:151-152 states the executor must not). Not verifiable by me whether that was done.
- Verification mode: no AC touches real machine state; all close-unit cases run in temp sandboxes
  (New-Sandbox). Code-review verified 2026-09-30, suite not live-run by this assessor.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Make Test-GradeCard enforce `## Assessment` and `## Suggestions` too (close-unit.ps1:206), or soften the
   build.md:151 wording. Add a Test-Case for a card missing them.
2. [dev] Add test cases for the ambiguous same-name fallback, a `a-b` range beyond EOF, and one real existing
   card (for AC4 non-regression), next to test-kit.ps1:5025.
3. [dev] Move the grade check ahead of the story roll-up, or make a refusal revert the DONE stamp, so a failed
   -RequireGrade does not leave STORIES.md stamped (close-unit.ps1:527-536 versus the roll-up at 256-274).
4. [human] Decide whether build.md:160-165 CONTRADICTED blocking should stay prose-only, or get a script
   (for example `dad close-unit` running `doc-stats -Findings` itself). Also confirm install.cmd was re-run.
5. [mechanical] Have the failure message at close-unit.ps1:236 name the expected form (full relative path).
