# Story S28 - DESIGN's Goal, R34, R37(b) and Out of scope reconciled with the cloud-first mission : report card

**Current grade: A-**  (as of 2026-10-09, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-10-09        | A-    | initial grading; docs-only story, closed in commit e86a49d; verified by grep against current docs/DESIGN.md |

## Assessment (this iteration)
- Correctness: every contradiction S28 listed was reworded. Verified by Read/Grep of docs/DESIGN.md:
  line 4 now says "runs on the user's own machine in every mode" (no "Local-only dev CLI");
  `## Goal` (docs/DESIGN.md:9-20) states the loop-engineering mission, "Cloud is the DEFAULT backend (R34)",
  Local as a RESILIENCE mode with its use case, and Hybrid; R34 (docs/DESIGN.md:33-57) orders (a) Cloud,
  (b) Local, (c) Hybrid; R37(b) (docs/DESIGN.md:431-438) retires the "offline thesis" and makes Copilot CLI a pilot;
  R37(e) (docs/DESIGN.md:511) now says "Same pilot posture (R37b)"; C2e (docs/DESIGN.md:784) is retitled around
  keeping Local reachable; `## Out of scope` (docs/DESIGN.md:1660-1662) is reversed and records why.
  R40's "this project's thesis" wording no longer matches any grep (the pattern returned nothing).
- Acceptance coverage:
  - AC1 met: docs/DESIGN.md:14-18.
  - AC2 met: grep for `DEFAULT and the thesis|Offline is the DEFAULT|Offline-first .* is the default` hits only
    docs/DESIGN.md:20, the quoted "used to say" provenance note, which is not a live claim. The literal AC2
    grep therefore still finds a hit (`Offline is the DEFAULT` does not appear, but the `DEFAULT and the thesis`
    string does in the note); the AC as written is slightly too strict for a changelog-style note.
  - AC3 met: docs/DESIGN.md:33-50, with the disconnected-afternoon use case at docs/DESIGN.md:47-50.
  - AC4 met: docs/DESIGN.md:33-34 records the 2026-10-06 decision; contract C6 exists at docs/DESIGN.md:1576
    with Status DECIDED 2026-10-06 (docs/DESIGN.md:1577), resolution order, worked examples and invariants.
  - AC5: not re-run (instructed); recorded as 278 passed / 0 failed at close. Evidence the gate covers the
    contract: test-kit.ps1:1336 ("S29 AC1-AC4: install mode resolution follows C6 ...") and test-kit.ps1:1427
    ("S29 AC1/AC2: a real install.ps1 run in a sandbox profile honors C6 ...").
- Design: matches intent and the human decision. Prose-only change, no code touched. C6 was later IMPLEMENTED by S29;
  docs/DESIGN.md:37-38 and :1577-1581 were updated to say so (commit 7915dbb), consistent with grades/S29_GRADE.md.
- Quality: provenance notes (italic "Reworded 2026-10-06") are helpful but add noise to a LOCKED contract; ASCII
  preserved. Still-stale check: the three "probably fine" lines are mechanics, not thesis framing, and are
  acceptable: docs/DESIGN.md:122 ("everything downstream stays offline"), :136 ("stays OFFLINE and reads the
  corpus"), and :376 ("build offline after", formerly :362). Remaining "Local-only" at docs/DESIGN.md:263 is the
  generic security-review rule, not the mission.
- Hygiene: CHANGELOG 0.58.0/0.58.1 exist per the brief; not independently re-read here.
- Verification mode: no AC touches machine state; all code-review/grep-only on docs/DESIGN.md.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [design] Reword AC2 in docs/STORIES.md (Story S28) so it excludes the quoted provenance note at
   docs/DESIGN.md:20, or drop the quoted old phrase there; as written the literal grep can still hit.
2. [mechanical] Consider a doc-consistency Test-Case in test-kit.ps1 that greps docs/DESIGN.md for live
   "Offline is the DEFAULT" claims (outside quoted notes), since no test names S28 directly (grep for "S28"
   test cases found none; only S29/C6 tests at test-kit.ps1:1336 and :1427 guard the outcome).
3. [human] Decide whether "Reworded 2026-10-06" provenance notes (docs/DESIGN.md:19-20, :1661-1662) stay in
   the locked prose or move to CHANGELOG.md.
