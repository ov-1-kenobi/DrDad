# Story S6 - Walking-skeleton ratchet - doc-stats [ratchet] finding : report card

**Current grade: A**  (as of 2026-09-22, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-09-22        | A     | initial implementation (T6.1 doc-stats.ps1:663-678, T6.2 test-kit.ps1:3237-3299) |

## Assessment (this iteration)
- **Correctness vs intent:** Matches. `doc-stats.ps1:668-678` adds the `[ratchet]` WARN block in the exact
  generated-finding region cited by C1b (after the `[integrity]` hand-commit block ending at
  `doc-stats.ps1:661`, before `Write-Host "== STATE FACTS...` at `doc-stats.ps1:680`). It computes
  `$ratchetMass = $storyIds.Count + $tasks.Count` (`doc-stats.ps1:670`) and
  `$ratchetDoneRatio = $ratchetDoneMass / $ratchetMass` (`doc-stats.ps1:673`) using ONLY the four counters
  already in scope (`$storyIds` set at `doc-stats.ps1:126`, `$tasks` at `141`, `$tasksDone` at `152`) - no
  new data source, per C1a's brief.
- **Acceptance coverage (traced to DESIGN.md C1a/C1b, not just the story-text summary):**
  - AC1 (fires when mass>=15, doneRatio<15%, matching C1b's message shape): covered by the Opus fixture
    reused for AC1/AC4 in `test-kit.ps1:3270-3278`; message-shape assertions at `:3277-3278` check the
    `walking-skeleton ratchet (R36b/C1)` phrase and `mass >= 15 and the done ratio stays under 15%` text
    verbatim against C1b's pinned wording.
  - AC2 (fresh/small project mass<15 stays silent; C1a's 3/0 stories worked example): `test-kit.ps1:3280-
    3283`, `Set-Fixture 3 0 0 0` then asserts `$o2 -notmatch '\[ratchet\]'`. Matches C1a's table row exactly.
  - AC3 (healthy large project, doneRatio>=15% stays silent; C1a's 50/10 stories + 80/40 tasks worked
    example, mass=130, ratio=38.5%): `test-kit.ps1:3285-3288`, `Set-Fixture 50 10 80 40`, asserts silence.
    Matches the table row exactly.
  - AC4 (Opus regression - 28 stories/0 done + 35 tasks/0 done -> mass=63, doneRatio=0% -> fires with exact
    pinned wording): `test-kit.ps1:3270-3278`. Assertions at `:3274-3275` check the EXACT substituted
    strings `(28 stories + 35 tasks = 63)` and `(0 stories + 0 tasks = 0 done, 0% of mass)`, character-for-
    character matching C1b's own worked-example trace (DESIGN.md:459-464).
  - AC5 (stalled large project - 50/3 stories + 80/5 tasks, doneRatio=6.2%, fires - the case Option A
    would have missed): `test-kit.ps1:3290-3297`, `Set-Fixture 50 3 80 5`, asserts fire plus the exact
    substituted mass/doneRatio strings `(50 stories + 80 tasks = 130)` / `(3 stories + 5 tasks = 8 done,
    6.2% of mass)`. Matches C1a's table row and C1a's own stated purpose for choosing Option B over A.
  - AC6 (full validation gate passes; new Test-Case covers AC1-AC5): the `Test-Case` exists at
    `test-kit.ps1:3237` and structurally exercises all five DESIGN.md C1a table rows via sandboxed fixtures
    (`New-Sandbox`/`Remove-Sandbox`, same pattern as the neighboring `[integrity]`/`grade cards` tests at
    `:3216` and `:3178`). I did NOT execute `test-kit.ps1` myself (no shell tool available to this grading
    pass) so "0 failed" is asserted by code review only, not a live run - see Verification mode below.
- **Design adherence:** Exact match to the PINNED contract, not just the story-text summary. The finding
  message in `doc-stats.ps1:676` is character-for-character identical to C1b's pinned template
  (DESIGN.md:453-458) and its worked Opus trace (DESIGN.md:459-464), including the parenthetical
  "(S1 must close first, per R30)" and the closing "/design or /stories now that the cost is visible"
  clause that a paraphrase would easily have dropped. Threshold constants are named and placed at the top
  of the block (`$ratchetMassFloor = 15`, `$ratchetDoneRatioFloor = 0.15` at `doc-stats.ps1:668-669`),
  matching C1d's explicit convention ("named constants near the top... the same way... `>= 5` uncommitted-
  done threshold at `doc-stats.ps1:595`" - DESIGN.md:527-530). WARN-only, appended to `$f` like every other
  finding, never touching exit code or a gate - C1d's invariant is respected (no new code path near
  `close-unit`/LOCK logic was touched; confirmed by reading the surrounding `[integrity]` block's identical
  `$f.Add(...)` pattern at `doc-stats.ps1:599,659`).
- **Quality:** `$ratchetMass -gt 0` guard at `doc-stats.ps1:671` is a reasonable defensive addition (avoids
  a PowerShell integer divide-by-zero on a fresh project with mass=0) that does not alter the pinned
  behavior, since `mass=0 < 15` would never fire anyway - not a deviation, just a safety net. Comment block
  at `doc-stats.ps1:663-667` cites the exact contract sub-decisions (C1a/C1b/C1d) and source line numbers
  it is implementing, matching the surrounding code's own citation style (e.g. the `[integrity]` block's
  extensive rationale comments at `doc-stats.ps1:605-626`). No non-ASCII characters found anywhere in
  `doc-stats.ps1` (grepped for `[^\x00-\x7F]`, zero matches), satisfying CLAUDE.md's ASCII convention.
- **Hygiene:** Both tasks are ticked `[x]` in `docs/TASKS.md:265` (T6.1) and `docs/TASKS.md:318` (T6.2), and
  the story header at `docs/STORIES.md:220` carries `Status: DONE closed:close-unit`, consistent with
  commits `ac84b69`/`770e902` cited by the orchestrator. One minor pre-existing pattern (NOT introduced by
  this story - S4 and S5's AC lists show the same thing): `docs/STORIES.md:242-256`'s six AC checkboxes for
  S6 are still literally `- [ ]`, unticked, even though the story itself is stamped DONE. This looks like an
  established convention gap in this project's close-unit flow (story-level AC boxes are not auto-ticked on
  close, only the task boxes and the story's own Status marker are) rather than a defect specific to S6 -
  flagged for visibility, not blamed on this unit.

## Verification mode
- No axis of this story touches real machine state (env vars, installed packages, registry, files outside
  the project) - it is a pure text-generation/WARN-message change inside `doc-stats.ps1` plus a sandboxed
  `test-kit.ps1` Test-Case that only ever writes into `New-Sandbox`'s temp directory
  (`test-kit.ps1:3242-3244`, `$sb`/`$p` under the sandbox root, cleaned up via `Remove-Sandbox` in `finally`
  at `:3298`). So the "isolated target" requirement from R35/S4 is satisfied by construction; there is no
  live-vs-sandboxed distinction to record for this unit.
- AC6's "the full validation gate (test-kit.ps1) passes" claim is CODE-REVIEW-ONLY as of this grading pass:
  I read the new `Test-Case` (`test-kit.ps1:3237-3299`) and traced its five fixtures against DESIGN.md
  C1a's worked-example table row by row (see Acceptance coverage above) and the exact pinned message text
  (C1b), but I have no shell/execution tool available in this grading session, so I did not actually run
  `.\test-kit.ps1` and observe `0 failed`. The orchestrator's stated commits (ac84b69, 770e902) imply
  close-unit's own build-verification gate passed at close time, but that is close-unit's claim, not
  something I independently re-ran here.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [human] Confirm (or have qa-agent/hygiene-agent confirm) that `test-kit.ps1` was actually run green after
   T6.2 landed - AC6 is code-review-verified only in this card, not live-executed, since this grading pass
   has no shell access. This is the one gap between "looks correct" and "proven correct."
2. [human] Decide whether story-level AC checkboxes (`docs/STORIES.md`) should be auto-ticked by close-unit
   when a story closes DONE - S4, S5, and now S6 all leave their AC lists as `- [ ]` despite being stamped
   DONE, which makes STORIES.md itself an unreliable acceptance-status source at a glance (a reader has to
   go find the grade card instead). Not a defect introduced by S6, but S6 is the third consecutive story to
   show the same pattern, which is worth a deliberate decision either way (tick them at close, or drop the
   checkbox convention from the story template since it is apparently not load-bearing).
3. [dev] None found - the `[ratchet]` message, thresholds, and Test-Case fixtures are a verbatim match to
   the pinned C1a/C1b contract text; no substantive code fix is warranted from this read.
