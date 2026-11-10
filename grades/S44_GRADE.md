# Story S44 - Refactor - the working documents stay small, and a source's tier says who set it : report card

**Current grade: B**  (as of 2026-11-10, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-11-10        | B     | initial implementation (commits e4ad399, 79f6f4a), graded by code review only |

## Assessment (this iteration)

How this story was closed: implemented directly from a review's issue list and marked DONE by hand at the
owner's request, NOT through close-unit. There is no close evidence file (`grades/S44_EVIDENCE.md` does not
exist). I did not run and did not see the suite run; the orchestrator reports the last full run on this
branch as 309 passed, 2 failed, with the two fixed and re-checked individually and a final full run still
pending. Nothing below claims the suite is green. Everything here is from reading the files cited.

- Correctness: the three behaviors are implemented and match the story's Goal, with two holes in the lock
  gate (below).
  - Archive: `archive-tasks.ps1:70` only touches a `[x]` task whose `(Story Sx)` is both a target and marked
    DONE (`archive-tasks.ps1:45`); the heading stays and gets a pointer line (`archive-tasks.ps1:87`,
    `archive-tasks.ps1:88`); the body is appended to `docs\archive\TASKS-<story>.md`
    (`archive-tasks.ps1:108`); an already-stubbed task is skipped, which is what makes a second pass move
    nothing (`archive-tasks.ps1:78`); `-DryRun` exits before any write (`archive-tasks.ps1:95`).
  - Story-level close only: `close-unit.ps1:897` requires `-not $closedTask -and $storyClosed` and no
    problems; a failed commit restores or removes the archive file (`close-unit.ps1:1098`) alongside the
    TASKS.md restore (`close-unit.ps1:1093`).
  - Corpus: `local-tools/Rag.cs:369` drops `<root>\archive\` by prefix, so a nested `notes\archive\` stays.
  - Tiers: `source-stats.ps1:141` FAILs a primary/secondary tier with no `human <date>` stamp when the
    header has the column (`source-stats.ps1:71`); `legacy` is collected (`source-stats.ps1:140`) and
    reported as one WARN (`source-stats.ps1:188`); `-LockCheck` is at `source-stats.ps1:196`;
    `source-tier.ps1:87` refuses with exit 3 when input is redirected, before any write
    (`source-tier.ps1:112` is the only write); `upgrade-project.ps1:231` marks set tiers `legacy` and leaves
    unknown rows empty.
  - HOLE 1: `source-stats.ps1:196` builds the block list from `$rows.Keys` only. A citation with NO ledger
    row is a FAIL in the normal run (`source-stats.ps1:120`) but is not in `$bad`, so `-LockCheck` prints
    "OK to lock" and exits 0 (`source-stats.ps1:200`). `global/commands/design.md:136` tells /design to run
    only `-LockCheck` before offering LOCKED, so a design citing a source that does not exist can be offered
    for lock.
  - HOLE 2: a tier value that is not primary/secondary/unknown (for example `primary-ish`) takes the
    WARN-only branch at `source-stats.ps1:135`, never reaches the stamp check at `source-stats.ps1:136`,
    and is not in the lock block list at `source-stats.ps1:196`. An unassessed source passes the lock gate
    by misspelling its tier.
- Acceptance: covered, with gaps noted.
  - AC1: `0.61.0 #11: the story-level close archives the story's task BODIES (headings and every count stay); open stories are untouched; the archive is not indexed`
    at `test-kit.ps1:9907`. It asserts no archive at the roll-up (`test-kit.ps1:9919`), the stub plus commit
    pointer (`test-kit.ps1:9927`), unchanged doc-stats counts (`test-kit.ps1:9935`), the archive in the story
    commit (`test-kit.ps1:9936`), the ratchet (`test-kit.ps1:9939`) and the second pass (`test-kit.ps1:9942`).
    "Verbatim" is asserted by counting a repeated phrase (`test-kit.ps1:9929`), not by comparing the body.
  - AC2: `0.61.0 #11: local-tools does not index docs\archive\ (the live documents are what search returns)`
    at `test-kit.ps1:9956`; nested folder kept (`test-kit.ps1:9967`), archive absent (`test-kit.ps1:9968`).
    Skipped under `-SkipBuild` (`test-kit.ps1:9957`).
  - AC3: `0.61.0 #17: only a human-stamped tier counts; an unstamped tier FAILS source-stats; -LockCheck blocks on cited unknown/unstamped sources; upgrade marks old tiers 'legacy'`
    at `test-kit.ps1:9836`; unstamped FAIL (`test-kit.ps1:9857`), legacy WARN (`test-kit.ps1:9859`), lock
    block (`test-kit.ps1:9865`), no change without a console (`test-kit.ps1:9874`), upgraded ledger passes
    (`test-kit.ps1:9898`). Neither hole above has a case.
  - Behavior with no behavioral test: the stamping writer (`source-tier.ps1:96` to `source-tier.ps1:112`) is
    never executed - `test-kit.ps1:9877` hand-writes the rows "as source-tier writes them" (the story's Dev
    notes say so openly). The two doc-stats findings (`doc-stats.ps1:487`, `doc-stats.ps1:494`) have no case
    I could find (one grep of test-kit.ps1 for their message text returned nothing). The security-agent and
    /design 3b behaviors are prompt text, held only by string matches (`test-kit.ps1:9952`,
    `test-kit.ps1:9953`).
- Design: stays inside the story's Data / interfaces list; no pinned contract was identified for this story
  (DESIGN.md does not yet state the 0.61.0 behaviors - that is open task T46.5, so there was no locked text
  to check against). One breadth note: `local-tools/Rag.cs:369` applies to EVERY configured root, not only
  the project's docs folder, so a top-level `archive\` in an extra reference root is silently unindexed too.
- Quality: readable, heavily commented with the WHY, PS 5.1-safe idioms, BOM-less writes
  (`archive-tasks.ps1:99`, `source-tier.ps1:112`), `[CmdletBinding()]` on both new scripts. Defects:
  - `close-unit.ps1:903` discards stderr and never checks the child's exit code; the `catch` at
    `close-unit.ps1:909` only sees parent-side exceptions, so an archive-tasks failure is silent.
  - `archive-tasks.ps1:108` appends the archive BEFORE `archive-tasks.ps1:110` rewrites TASKS.md; a failure
    between the two leaves bodies in both files and the next run appends them a second time.
  - `archive-tasks.ps1:76` ends a body at any line starting with 1-3 `#` and a space, including a `# comment`
    line inside a fenced code block; the rest of that body stays in TASKS.md under the stub (no loss, but
    the task is split and not "verbatim").
  - `source-stats.ps1:228` still says "the design doc cites sources that are not there" when the only FAIL
    is an unstamped tier.
  - `source-tier.ps1:32` hard-codes `docs\SOURCES.md` while `archive-tasks.ps1:35` uses `Resolve-DocsDir`.
  - Not traced: `close-unit.ps1:897` archives before the commit and the undo at `close-unit.ps1:1098` sits
    inside the commit-failed branch only. I did not read every step between them, so I cannot say whether a
    problem raised after the archive but before a commit attempt leaves the archive on disk.
- Hygiene: both `.cmd` wrappers exist and are asserted (`test-kit.ps1:9840`, `test-kit.ps1:9949`); `dad.cmd:69`
  and `dad.cmd:70` list the two commands; the template header has the column
  (`templates/_common/docs/SOURCES.md:30`); research text forbids agents writing the column
  (`global/agents/research-agent.md:40`, `global/commands/research.md:25`). In
  `global/commands/design.md:96` step "3b" sits AFTER step 4 (`global/commands/design.md:94`) and before 4a
  (`global/commands/design.md:103`). The story heading still reads "R: pending, see T46.5".
- Verification mode:
  - AC1: code-review verified 2026-11-10, not live-run by me. The test case is sandboxed (`New-Sandbox`
    fixture and a throwaway git repo, `test-kit.ps1:9909`); I did not see it execute.
  - AC2: code-review verified 2026-11-10, not live-run by me. The case runs the built exe against a sandbox
    docs folder (`test-kit.ps1:9966`); I did not see it execute.
  - AC3: code-review verified 2026-11-10, not live-run by me. Sandboxed ledgers only; the real stamping path
    (a human answering y) is not exercised by anything, by design.
  - No close evidence file exists for this story.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] Close HOLE 1: make `-LockCheck` block when a cited id has no ledger row (`source-stats.ps1:196`
   iterates `$rows.Keys` only), and add an assertion for it to the `0.61.0 #17` case.
2. [dev] Close HOLE 2: treat a tier that is not primary/secondary/unknown as unassessed for the lock gate
   (`source-stats.ps1:135`, `source-stats.ps1:196`), with a Test-Case.
3. [dev] `close-unit.ps1:903`: check `$LASTEXITCODE` from archive-tasks and add a warn on non-zero; and make
   `archive-tasks.ps1:108` / `archive-tasks.ps1:110` safe against a half-done run (write TASKS.md first, or
   skip a body the archive already holds).
4. [dev] Add Test-Cases for the two doc-stats findings (`doc-stats.ps1:487`, `doc-stats.ps1:494`) - the
   story's Behavior says "doc-stats says when it is time" and nothing holds it.
5. [dev] `archive-tasks.ps1:76`: do not end a task body on a `#` line inside a fenced code block.
6. [dev] Make the stamping writer testable without weakening the console check: move
   `source-tier.ps1:96` to `source-tier.ps1:111` into a function a test can call on a ledger string, leaving
   the `IsInputRedirected` refusal as the only entry from the command line.
7. [dev] `source-stats.ps1:228`: word the summary so it is true for an unstamped-tier FAIL.
8. [mechanical] `global/commands/design.md:96`: move step 3b above step 4 so the numbering reads in order.
9. [human] No close evidence and a final full suite run still pending: decide whether S44 stays DONE on
   code review alone, or is re-closed through close-unit once the suite has run clean.
10. [human] `local-tools/Rag.cs:369` skips `archive\` under every root, not only the project docs folder.
    Decide whether that is intended for extra reference roots, and record it (T46.5 is where DESIGN gets
    these behaviors).
11. [human] The tier gate is switched on by the ledger header (`source-stats.ps1:71`) and the stamp is plain
    text anyone can type (`source-tier.ps1:18` says so). Decide whether a ledger without the column should
    at least WARN, so removing the column is not a quiet way out.
