# Story S42 - Refactor - grades rest on facts the grader cannot fake, and repeated suggestions force a retro : report card

**Current grade: B**  (as of 2026-11-10, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-11-10        | B     | initial implementation (T42.1 + T42.2, commits dabcd2e and 004828c per the story's Dev notes) |

## Assessment (this iteration)
What was read: `close-unit.ps1:203-322`, `close-unit.ps1:434-464`, `close-unit.ps1:866-890`, all of
`grade-trends.ps1` (241 lines), `test-kit.ps1:9650-9795`, and the matching lines of the three prompt
files. Story text: `docs/STORIES.md:1451`. Tasks: `docs/TASKS.md:3421` and `docs/TASKS.md:3428`.

- Close evidence: no close evidence file (the S42 evidence file under grades\ does not exist). The story
  was implemented directly from a review's issue list and marked DONE by hand at the owner's request, NOT
  closed through close-unit. So there is no Evidence line to quote and no cap to obey. I have no shell and
  did not see tests run. The orchestrator reports the last full run before the write-up as 309 passed,
  2 failed, the two fixed and re-checked individually, a final full run still pending - the suite is NOT
  confirmed green, and this grade does not assume it is.
- Correctness: matches the Goal and both Behavior bullets.
  - Evidence file: `Write-StoryEvidence` at `close-unit.ps1:276` collects the story id plus its task ids
    (`close-unit.ps1:280`), counts test-failure and build-failure blocks from the gate log
    (`close-unit.ps1:293-294`), counts open doc-stats findings naming the story (`close-unit.ps1:305`),
    sets the cap to B or none (`close-unit.ps1:308`) and writes one line (`close-unit.ps1:309`). It is
    called only when the story flips to DONE (`close-unit.ps1:868-875`).
  - Quote + cap: `Test-GradeCard` compares whitespace-normalised text (`close-unit.ps1:254-256`) and
    rejects a grade ranked above the cap (`close-unit.ps1:258-264`). A story with no evidence file skips
    the block (`close-unit.ps1:251`), which is the "older kit judged as before" clause.
  - Recurrence: suggestions are read from the `## Suggestions` section only (`grade-trends.ps1:153`),
    keyed by tag + theme (`grade-trends.ps1:162`), three cards needed (`grade-trends.ps1:169`).
    `retroDue` needs a recurrence AND a baseline AND five closes (`grade-trends.ps1:172`). close-unit
    refuses before anything is ticked (`close-unit.ps1:452-459`) or warns (`close-unit.ps1:461`,
    `close-unit.ps1:878-879`). `-RecordRetro` appends the log line (`grade-trends.ps1:52-56`).
- Acceptance: both ACs are implemented and each clause has an assertion (read, not run).
  - AC1: `0.61.0 #5: a roll-up writes machine-made close evidence; the grade card must quote it and may not exceed its cap`
    at `test-kit.ps1:9650`. Counts pinned at `test-kit.ps1:9673` (3 ran, 2 test blocks, cap B); file in
    the roll-up commit `test-kit.ps1:9674`; missing line rejected `test-kit.ps1:9679`; above cap rejected
    `test-kit.ps1:9683`; at cap accepted `test-kit.ps1:9687`; clean story has no cap `test-kit.ps1:9697`;
    older-kit story untouched `test-kit.ps1:9718-9719`.
  - AC2: `0.61.0 #6: suggestions recurring on 3+ cards are listed at every roll-up, and hold the story close once 5 stories closed without a retro; no recurrence = no gate`
    at `test-kit.ps1:9725`. Two cards do not recur `test-kit.ps1:9753`; three do `test-kit.ps1:9759`;
    sixth roll-up held and nothing ticked `test-kit.ps1:9767-9769`; retro releases it
    `test-kit.ps1:9771-9774`; six closes with no recurrence never held `test-kit.ps1:9789-9792`.
  - Gaps in the tests, not in the ACs as written: the findings-driven cap is never isolated
    (`test-kit.ps1:9673` accepts any findings count, the cap there comes from the two test blocks); no
    case for an evidence file whose Evidence line is missing, or a card whose grade line cannot be parsed.
- Design: no scope creep; the five files in Data / interfaces are the five that changed. Prompt side is
  present: `global/agents/grade-agent.md:40`, `global/commands/build.md:163`, `global/commands/retro.md:62`.
  The weak point against the Goal ("facts the grader cannot fake") is that several paths FAIL OPEN:
  - `close-unit.ps1:253`: an evidence file with no `Evidence (close-unit` line passes with no check at
    all, so emptying the file removes both the quote rule and the cap.
  - `close-unit.ps1:261-262`: if the card has no parsable `Current grade:` line the cap check is skipped.
    `grade-trends.ps1:97-100` falls back to the history table for the same card; close-unit does not, so
    a card graded A only in its history row gets past a cap of B.
  - `close-unit.ps1:298-307`: a doc-stats run that fails or prints nothing is swallowed by an empty catch
    and reported as the fact "open findings: 0", which can turn a cap of B into none.
  - `close-unit.ps1:450`: if grade-trends fails or prints non-JSON, the retro gate is silently off.
  - `close-unit.ps1:441` and `close-unit.ps1:871`: `-SkipVerify` skips the retro gate, and a story rolled
    up with it gets "tests NOT verified" yet cap none (`close-unit.ps1:308` caps only on blocks/findings).
  - Path without a task map (`close-unit.ps1:857`): the story flips in the same run that checks the card,
    so `evidenceFresh` (`close-unit.ps1:874`) exempts it. I did not read `Set-StoryDone`, so this is
    inferred from the two call sites, not confirmed.
- Design, recurrence: the themes at `grade-trends.ps1:123-134` are broad (`\btest(s|ing)?\b`, `comment`,
  `document`), and recurrence is counted over every card ever written, with nothing marking a suggestion
  as dealt with (`grade-trends.ps1:150-169`; the message at `grade-trends.ps1:225` says "still not done"
  but nothing checks that). On a project with a dozen cards "[dev] tests / coverage" will recur almost by
  construction, so "refused only when something recurs" tends toward "a retro every five stories", and it
  re-fires after every retro for the same three old cards. The Dev notes call the rule "deliberately
  crude"; the test at `test-kit.ps1:9774` confirms the warning is meant to persist after a retro.
- Quality: readable, heavily commented with the reason for each rule, PowerShell 5.1 idioms, BOM-less
  UTF-8 writes (`close-unit.ps1:320`, `grade-trends.ps1:49`). Small things: the grade rank table is
  written twice (`close-unit.ps1:260`, `grade-trends.ps1:174`); the grade regex differs between the two
  scripts (`grade-trends.ps1:90` ends in `\b`, `close-unit.ps1:261` does not); each card is read from
  disk three times (`grade-trends.ps1:84`, `grade-trends.ps1:138`, `grade-trends.ps1:151`); the usage
  header at `grade-trends.ps1:3-4` omits `-RecordRetro`, `-Note` and `-EnsureBaseline`; the default text
  at `close-unit.ps1:870` ("no Test command in CLAUDE.md") is also what is written when a Test command
  exists but its count is null (`close-unit.ps1:872`) - reachability not confirmed, the test-run block
  was not read.
- Hygiene: one Test-Case per issue, as CLAUDE.md asks. Every line read was ASCII. No manifest or
  dependency change is involved. `Get-DoneStoryCount` (`grade-trends.ps1:40`) counts every heading
  marked DONE, including stories marked by hand, as this one was.
- Verification mode: both ACs act on project files only, and their tests run in throwaway sandboxes
  (`test-kit.ps1:9652`, `test-kit.ps1:9727`).
  - AC1: Code-review verified 2026-11-10, not live-run - the grader has no shell and there is no close
    evidence file for this story.
  - AC2: Code-review verified 2026-11-10, not live-run - same reason.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Make the evidence check fail closed: when the evidence file exists but has no Evidence line
   (`close-unit.ps1:253`), or the card has no parsable current grade (`close-unit.ps1:262`), return a
   problem instead of passing; add an assertion for each to the `0.61.0 #5` case.
2. [dev] Do not report an unknown as a fact: when the doc-stats call at `close-unit.ps1:299` fails or
   returns nothing, write "open findings: unknown" and cap at B, and add a fixture where a finding alone
   (no test block) produces the cap, which `test-kit.ps1:9673` does not isolate.
3. [human] Decide whether recurrence should count only cards dated after the last recorded retro, and
   whether the themes at `grade-trends.ps1:123-134` are too broad to gate on. As built, a broad theme
   keeps the gate firing every five stories whatever the retro decided.
4. [human] Decide whether a roll-up made with `-SkipVerify` should carry a cap (today "tests NOT
   verified" gives cap none, `close-unit.ps1:871`), and whether S42 itself, marked DONE by hand with no
   close evidence file and no confirmed green full run, is acceptable as closed.
5. [dev] Confirm the path with no task map (`close-unit.ps1:857` with `close-unit.ps1:874`): if the
   story flips and is checked in one run, the quote and cap rules never apply to it.
6. [dev] Warn, rather than stay silent, when the grade-trends call at `close-unit.ps1:450` yields no JSON.
7. [mechanical] Add `-RecordRetro`, `-Note` and `-EnsureBaseline` to the usage header at
   `grade-trends.ps1:3-4`; give `close-unit.ps1:261` the same trailing `\b` as `grade-trends.ps1:90`.
