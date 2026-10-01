# Story S21 - A skipped test-kit case must be COUNTED as skipped, never as a pass (R24) : report card

**Current grade: A-**  (as of 2026-10-01, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-01        | A-    | first card for S21; T21.1 (c21eb35), T21.2 (11f210d), T21.3 (6c9f5eb) read at HEAD |

## Assessment (this iteration)
Read: docs/STORIES.md:872-902 (S21), docs/TASKS.md:1956-2003 (T21.1-T21.3), test-kit.ps1:1-60 (header, counters,
Test-Case, Assert, Skip-Case), every Skip-Case call site (test-kit.ps1:670, 2086, 2152, 2831-2833, 2864-2866, 4505-4507,
6013), the S21 cases test-kit.ps1:5048-5181, the summary test-kit.ps1:7225-7231, close-unit.ps1:185-197 (Get-TestCount),
grades/gates-log.jsonl:72-98. Not run: build or tests, and no `git show` (assessor has no shell; commits judged from HEAD).

- Correctness: good. ONE helper, reason required: `Skip-Case` (test-kit.ps1:56-60) throws an ordinary failure on a
  blank reason (test-kit.ps1:57), a FAIL for `-NeedsBuild` on a full run (test-kit.ps1:58), else the `__DAD_SKIP__:`
  sentinel. Test-Case's catch (test-kit.ps1:38-47) sorts the sentinel into `$script:skip` and prints
  `SKIP  <name> - <reason>` without touching pass/fail/failures; the PASS path is unchanged (test-kit.ps1:35-37).
  Summary is `== N passed, M failed, K skipped ==` (test-kit.ps1:7227); a skip never colours or fails the run. Header
  comment added (test-kit.ps1:9-10). Matches T21.1 step by step.
- Acceptance:
  - AC1 (SKIP lines + nonzero count under -SkipBuild): mechanism proven by "S21 AC1/AC3: Skip-Case counts SKIP not
    PASS; -NeedsBuild on a FULL run FAILS; a blank reason FAILS" (test-kit.ps1:5048-5087), which extracts the REAL
    three functions via AST (test-kit.ps1:5052-5054) into a child probe and asserts SKIP/FAIL/PASS lines and counts
    `1 2 1` (full) / `1 1 2` (-SkipBuild). The three `$SkipBuild` guards are converted (test-kit.ps1:2831, 2864,
    4505). The real-suite -SkipBuild skip count is run-only, not asserted by any case - not verified by me.
  - AC2 (`0 skipped` on a full healthy run) and AC6 (`0 failed`): run-only; I cannot verify. Indirect evidence:
    grades/gates-log.jsonl:98 records a clean T21.3 close, and the close-unit.ps1:187-188 comment cites a green
    243-test run.
  - AC3: probe-build FAILs on a full run (test-kit.ps1:5065, 5074, 5078). Simulated via a direct
    `Skip-Case -NeedsBuild` call rather than a real absent exe path - acceptable, the condition is the helper's.
  - AC4: "S21 AC4: no $SkipBuild / missing-exe early return is left in test-kit.ps1" (test-kit.ps1:5089-5100). My own
    grep for `\breturn\s*\}` confirms no remaining line mixes it with `$SkipBuild` / `Test-Path $exe` / `local-tools.exe`.
  - AC5: "S21 AC5: close-unit reads the passed count..." (test-kit.ps1:5102-5132) proves 0 passed + 3 skipped refuses
    and 12 passed closes. Better than asked: the real story close was refused twice by a DECOY (this suite's own case
    name containing "0 passed refuses", grades/gates-log.jsonl:87 and grades/gates-log.jsonl:89); T21.3 fixed
    Get-TestCount to take the LAST match (close-unit.ps1:186-194) and pinned it with a decoy fixture case
    (test-kit.ps1:5134-5164) plus a unit case (test-kit.ps1:5166-5181). Touching close-unit.ps1 was allowed by T21.3
    "only if case 3 fails" - it effectively did.
- Design: scope respected. T21.2's exact list is converted with the exact reason strings (docs/TASKS.md:1982-1984);
  the S19 case's own fake `SKIP (exe not built)` print is gone (test-kit.ps1:2152). Out-of-scope guards left as
  instructed (docs/TASKS.md:1985). No contract touched.
- Quality: clean, commented (test-kit.ps1:53-55 documents the call-before-own-try/catch rule). Two weak spots: (a) the
  AC4 lint is single-line only - a multi-line `if ($SkipBuild) {` / `return` / `}` would slip past
  test-kit.ps1:5092-5097; (b) nothing stops a future case from calling Skip-Case inside its own `try { } catch { }`,
  where the sentinel is swallowed and the case PASSes - exactly the bug S21 closes.
- Hygiene: ASCII, PS 5.1 idioms, sandboxes removed in `finally` (test-kit.ps1:5086, 5131, 5163). No manifest/dep change.
  The R24 gap remains outside S21: ~35 `if (-not $haveGit) { return }` guards (e.g. test-kit.ps1:225, 5011) plus
  python/dotnet/ollama/harness guards (test-kit.ps1:583, 588, 671, 685, 1239, 1617) still count as PASS when they run
  nothing - deferred by docs/TASKS.md:2205.
- Verification mode: no AC touches real machine state. The probe and close-unit fixtures run in New-Sandbox %TEMP%
  dirs (live-sandboxed by design). My verification is code-review-only (no shell).

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Follow-up story (R24): convert the remaining optional-tool early returns (`$haveGit` guards e.g.
   test-kit.ps1:225; python test-kit.ps1:583/588; dotnet/ASP.NET test-kit.ps1:671/685; ollama test-kit.ps1:1239;
   harness test-kit.ps1:1617) to `Skip-Case "<reason>"`. On a box without git, ~35 cases still read as PASS having
   asserted nothing. docs/TASKS.md:2205 already names this follow-up.
2. [dev] Harden the S21 AC4 lint (test-kit.ps1:5089-5100): (a) also catch the multi-line form (a `return` alone on a
   line within a few lines after a `$SkipBuild`/exe test); (b) add an AST check that no `Skip-Case` call sits inside
   a `TryStatementAst` that has a catch clause in a Test-Case body, since a body-level catch swallows the sentinel and
   the case PASSes.
3. [human] docs/STORIES.md:872 already reads `Status: DONE closed:close-unit`, but grades/gates-log.jsonl has no
   `clean close: S21` entry - only two refusals (grades/gates-log.jsonl:87, 89) before the T21.3 fix, and this is
   the first S21 grade card. Confirm the story close (with -RequireGrade and the full suite) really ran after T21.3,
   or re-run it now that this card exists. Also note: last-match in Get-TestCount (close-unit.ps1:192-193) means a
   multi-project `dotnet test` now reports the LAST project's `Total tests` rather than the first. Neither sums, and
   the zero-check still works. Decide whether that matters for downstream projects.
