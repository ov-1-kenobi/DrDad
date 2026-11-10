# Story S43 - Refactor - scope and work in progress are bounded by rules the human owns : report card

**Current grade: B**  (as of 2026-11-10, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-11-10        | B     | initial implementation (commits c9ed856, 3cfa8af, b442187), graded by code review only |

## Assessment (this iteration)

How this story was closed: it was implemented directly from a review's issue list and marked DONE by hand
at the owner's request. It was NOT closed through close-unit, so there is no close evidence file
(`grades/S43_EVIDENCE.md` does not exist). I did not see any test run. The orchestrator reports the last
full suite run on this branch as 309 passed, 2 failed, with those two fixed and re-checked individually;
a final full run is still pending, so this card does not claim the suite is green. Everything below is
from reading the source and the test bodies.

- Correctness: the three behaviors are implemented as the story describes them.
  - WIP limit: `close-unit.ps1:470` to `close-unit.ps1:499`. The limit is read from the project's
    CLAUDE.md (`close-unit.ps1:474`); no line leaves `$wipLimit` at -1 and nothing is enforced
    (`close-unit.ps1:477`). "Starts a story" means no task of that story is ticked yet
    (`close-unit.ps1:480`), so a started story continues. The count comes from `doc-stats -Json`
    (`close-unit.ps1:483`), the refusal fires on `-gt` (`close-unit.ps1:485`), lists up to 8 open gates
    (`close-unit.ps1:491`), logs a block (`close-unit.ps1:494`) and exits 1 before anything is ticked.
    The definition of a waiting story is in `doc-stats.ps1:253` to `doc-stats.ps1:262`; the checklist is
    `doc-stats.ps1:957` to `doc-stats.ps1:969`; the `[wip]` finding is `doc-stats.ps1:647`.
  - Serves: `doc-stats.ps1:454` to `doc-stats.ps1:478`. Adoption is a `## Deferred` section or any
    Serves line (`doc-stats.ps1:457`); missing (`doc-stats.ps1:467`), unquoted (`doc-stats.ps1:472`) and
    not-in-Goal (`doc-stats.ps1:474`) are three separate findings; the scaffold placeholder epic is
    skipped (`doc-stats.ps1:463`). The prompt side is `global/commands/design.md:103` (step 4a, with the
    amend-or-defer choice at `global/commands/design.md:107`), and the template carries the line and the
    section (`templates/_common/docs/DESIGN.md:45`, `templates/_common/docs/DESIGN.md:47`).
  - e2e: `close-unit.ps1:506` to `close-unit.ps1:526`. The exempt file existing is the switch
    (`close-unit.ps1:508`), comments are stripped per line (`close-unit.ps1:509`), and a roll-up with no
    tagged task is refused (`close-unit.ps1:513`). `new-project.ps1:109` creates the file empty;
    `upgrade-project.ps1:185` to `upgrade-project.ps1:208` writes it once with DONE and started stories;
    `doc-stats.ps1:633` reports `[taskmap]`; the agent rule is `global/agents/taskmap-agent.md:46`.
- Acceptance: all three ACs have a behavioral test that drives the real scripts in a sandbox.
  - AC1: `0.61.0 #7: over the project's human-gate WIP limit, close-unit will not START a new story; started stories and projects with no limit are untouched`
    at `test-kit.ps1:9598`. It asserts the refusal and that T4.1 is not ticked (`test-kit.ps1:9630`,
    `test-kit.ps1:9632`), a started story still closes (`test-kit.ps1:9634`), raising the limit lifts it
    (`test-kit.ps1:9640`) and removing the line lifts it (`test-kit.ps1:9645`). Covered.
  - AC2: the `0.61.0 #8` case at `test-kit.ps1:9507` asserts old designs stay quiet (`test-kit.ps1:9519`),
    the three findings (`test-kit.ps1:9527` to `test-kit.ps1:9529`), and a fresh scaffold is not flagged
    (`test-kit.ps1:9539`). Covered. The `/design` half is a string match on the prompt
    (`test-kit.ps1:9534`); that is all a suite can do for a prompt file.
  - AC3: the `0.61.0 #9` case at `test-kit.ps1:9543` covers rule off (`test-kit.ps1:9550`), refusal with
    no tick and one log line (`test-kit.ps1:9561` to `test-kit.ps1:9563`), roll-up once tagged
    (`test-kit.ps1:9570`), an exempt story (`test-kit.ps1:9574`), and upgrade exempting S1,S2 but not S3,
    idempotently (`test-kit.ps1:9590`, `test-kit.ps1:9593`). Covered.
  - Gaps, none of which an AC names: (a) the WIP gate fails OPEN - if the doc-stats child fails or its
    output does not parse, `$wip` is null, `$waiting` is empty (`close-unit.ps1:484`) and the close
    proceeds with no message; (b) a title that starts "Human-readable ..." (capital H) counts as a human
    gate through the `\s-\s+Human\b` branch at `doc-stats.ps1:257`, while the test only pins the
    lower-case form (`test-kit.ps1:9608`); (c) the Serves check accepts any 4-character quote
    (`doc-stats.ps1:470`) and matches against the whole Goal section including the template's own HTML
    comment (`templates/_common/docs/DESIGN.md:21`), so a quote of the comment's words would pass;
    (d) with no `## Goal` section `$goalNorm` is empty and an unsupported quote is not flagged
    (`doc-stats.ps1:473`); (e) "exactly ONE" e2e task is enforced as "at least one"
    (`close-unit.ps1:513`, `doc-stats.ps1:639`); (f) the e2e check requires `$myTaskStory`
    (`close-unit.ps1:506`), so it runs on a task close only - I did not verify whether a story-level
    close (`-Id <story>`) of a story whose tasks were ticked outside close-unit can reach DONE without it.
- Design: stays inside the files the story lists; the pieces deliberately not built ("7B+", "9D") are
  disclosed in the Dev notes and parked at T46.13, not silently dropped. All three rules are opt-in for
  existing projects (no limit line, no adoption marker, no exempt file), which matches the stated intent
  that a kit upgrade cannot stop a project by itself (`upgrade-project.ps1:427` only prints a hint).
  No pinned contract from `## Contracts` was identified for this story; the story header still reads
  "R: pending, see T46.5", so traceability to a DESIGN requirement is open.
- Quality: readable and heavily commented with the reason for each gate; refusal messages say what to do
  next. Duplication: the limit regex is written twice (`close-unit.ps1:474`, `doc-stats.ps1:266`) although
  the comment at `close-unit.ps1:469` says doc-stats owns the definition; the human-gate title regex is
  written twice (`doc-stats.ps1:257`, `doc-stats.ps1:960`); the exempt-file parser is written twice
  (`close-unit.ps1:509`, `doc-stats.ps1:635`). Gate section labels in close-unit run 0g, 0f, 0e, 0b
  (`close-unit.ps1:434`, `close-unit.ps1:465`, `close-unit.ps1:500`, `close-unit.ps1:527`), and
  `doc-stats.ps1:970` has `}if ($Json)` joined on one line.
- Hygiene: template, new-project, upgrade-project, build.md (`global/commands/build.md:42`) and the
  taskmap agent are in step with the scripts; `templates/generic/CLAUDE.md:59` carries the default of 3
  and the test pins it (`test-kit.ps1:9647`). ASCII-only and PS 5.1 compatibility were not checked by me
  beyond the lines read (no non-ASCII seen); the suite owns that check.
- Verification mode: no AC here touches machine state outside a project folder. The three test cases
  build their fixtures under `New-Sandbox` temp dirs (`test-kit.ps1:9508`, `test-kit.ps1:9545`,
  `test-kit.ps1:9600`) and remove them in `finally`. AC1, AC2, AC3: code-review verified 2026-11-10, not
  live-run by the grader; no close evidence file; a final full suite run is pending.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Make the WIP gate say so when it cannot count: at `close-unit.ps1:483`, when the limit line exists
   and `$wip` is null, print a warning and write a gate-log line (or refuse) - today a broken doc-stats
   silently disables the rule. Add an assertion to the `0.61.0 #7` case.
2. [dev] Tighten the Serves check in `doc-stats.ps1:470` to `doc-stats.ps1:474`: strip HTML comments from
   the Goal section before matching, require more than one word (4 characters is satisfiable by "tool"),
   and flag an adopted design that has no `## Goal` section instead of skipping the comparison.
3. [dev] Narrow the old-style gate title match at `doc-stats.ps1:257` and `doc-stats.ps1:960` so
   "T5.2 - Human-readable sizes" is not a gate (for example require a space or colon after "Human"), and
   pin it in the fixture at `test-kit.ps1:9608`.
4. [dev] Confirm, and add a test for, the e2e rule on a story-level close: `close-unit.ps1:506` skips the
   check when `$myTaskStory` is not set. If a story can reach DONE that way without a tagged task, check
   there too.
5. [human] This story was marked DONE by hand with no close evidence and none of T43.1 to T43.3 is tagged
   `[e2e]` - it went around the two gates it adds. Decide whether to run it through close-unit after the
   pending full suite run, or record the exception (and whether the kit repo itself opts into
   `grades/e2e-exempt.txt` and a WIP limit).
6. [human] Decide whether "exactly ONE" e2e task should be enforced or reworded to "at least one"
   (`global/agents/taskmap-agent.md:46` versus `close-unit.ps1:513`).
7. [mechanical] Share one definition each for the limit regex, the human-gate title regex and the
   exempt-file parser (see Quality); put `if ($Json)` on its own line at `doc-stats.ps1:970`; put the gate
   section labels in `close-unit.ps1:434` to `close-unit.ps1:527` in order.
