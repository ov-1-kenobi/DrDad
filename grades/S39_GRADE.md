# Story S39 - Refactor - close-unit is the only writer of close state, and a refusal cannot be walked around : report card

**Current grade: B**  (as of 2026-11-10, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-11-10        | B     | initial implementation (commits 6565b0f, 7eef38b, 12c3180 per the story's Dev notes) |

## Assessment (this iteration)

How this was graded: by reading source and tests only. No test run was observed by this grader. The last
full suite run reported to me (309 passed, 2 failed, the two fixed and re-checked one at a time) predates a
final full run, which is still pending - the suite is NOT confirmed green. The story was implemented from a
review's issue list and marked DONE by hand at the owner's request, not closed through close-unit: there is
no close evidence file (`grades/S39_EVIDENCE.md` does not exist).

- Correctness: the four Behavior lines are implemented as written, with two small defects (suggestions 1, 2).
  - Guard: `dad-status-guard.ps1:41` reads headings only; `dad-status-guard.ps1:84` to
    `dad-status-guard.ps1:88` flag a story that is DONE now and was not DONE in HEAD unless it is the allowed
    one; `dad-status-guard.ps1:54` is the `DAD_ALLOW_STATUS_EDIT=1` override. It is called at the start of
    every close (`close-unit.ps1:421` to `close-unit.ps1:431`, before any tick) and from the pre-commit hook
    (`install-hooks.ps1:109` to `install-hooks.ps1:114`, exit code propagated). close-unit announces its own
    story commit through `DAD_CLOSE_UNIT_STORY`, set and restored around the one git call
    (`close-unit.ps1:1070` to `close-unit.ps1:1073`).
  - Rollback: originals are captured before the tick (`close-unit.ps1:817` to `close-unit.ps1:821`) and put
    back when the commit fails (`close-unit.ps1:1090` to `close-unit.ps1:1105`): TASKS, STORIES, STATUS,
    RECIPES, the evidence file, the archive, then `git reset -q`. That is the full list in the Behavior line.
  - Reason: `close-unit.ps1:795` refuses `-AcceptShrink` when the whitespace-collapsed reason
    (`close-unit.ps1:762`) is under ten characters, logs a block (`close-unit.ps1:802`) and exits before any
    bookkeeping; the reason reaches the gate log through `close-unit.ps1:813` and the commit through the
    trailer at `close-unit.ps1:1039`.
  - Commits: prefix strip at `close-unit.ps1:993` to `close-unit.ps1:996`; the no-duplicate re-run at
    `close-unit.ps1:1046` to `close-unit.ps1:1055`; the empty story commit at `close-unit.ps1:1056` to
    `close-unit.ps1:1065`; the owed-story refusal at `close-unit.ps1:544`; the open-story list is written and
    cleared at `close-unit.ps1:1121` to `close-unit.ps1:1133`.
- Acceptance: each AC has a behavioural test on a real git fixture (not a text match on the script):
  - AC1: `0.60.0 #2: a story marked DONE by hand is refused - by close-unit for another unit, and by the pre-commit hook; the human override works`
    (`test-kit.ps1:8942`) asserts exit 1, no tick, HEAD unchanged, a gate-log line, the hook refusal and the
    override. Covered.
  - AC2: `0.60.0 #2: when the commit does not land, the tick and the DONE stamp are rolled back (nothing is left on disk to bank later)`
    (`test-kit.ps1:8994`) asserts tick, stamp and index. Covered as the AC is worded; the STATUS, RECIPES,
    evidence and archive halves of the Behavior line have no assertion (suggestion 3).
  - AC3: the case at `test-kit.ps1:9047` asserts the bare flag exits 1, nothing ticked, HEAD unchanged,
    baseline still 10 (`test-kit.ps1:9065`), then the trailer and the gate-log line with a reason. Covered.
    `S30 AC6` exists at `test-kit.ps1:3165` (title read, body not read). The ten-character floor itself
    (9 against 10 characters) is not exercised.
  - AC4: cases at `test-kit.ps1:9246` and `test-kit.ps1:9283`. Covered, but the first case promises more than
    it tests (suggestion 2).
- Design: stays inside the files the story names; no new server, no new dependency. The story heading still
  reads "R: pending, see T46.5", so there is no requirement id to trace it to yet. I did not check a pinned
  contract in `docs/DESIGN.md` for this story (none is referenced by it).
- Quality: readable, each gate carries the incident it closes, fails open on its own defects by stated rule
  (`dad-status-guard.ps1:102`), PS 5.1 idioms respected (no here-string `-m`, `$LASTEXITCODE` only).
  Weaknesses: the guard's trust anchors are an environment variable and a local file (suggestions 4, 5).
- Hygiene: `.cmd` wrapper present (`dad-status-guard.cmd:3`); `ratchet.ps1:290` and
  `global/commands/build.md:111` carry the new `-Reason` wording; `global/commands/spec.md:44` carries the
  owed story-level close. NOT verified by me: ASCII-only content of the changed files, and whether the
  install / uninstall inventories list `dad-status-guard` - the suite checks both and I could not run it.
- Verification mode: every AC touches git state and hooks. All four are code-review verified 2026-11-10,
  not live-run by this grader. The tests that hold them run sandboxed (`New-Sandbox` / `New-PfFixture`
  temp projects, e.g. `test-kit.ps1:8944`), so a run does not touch the real repo; whether those cases
  currently pass is unconfirmed until the pending full run.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] `close-unit.ps1:994` - the prefix pattern `\s*[:\-]\s*` accepts a hyphen with no space around it,
   so `-Id S3 -Title "S3-compatible storage"` commits as "S3: compatible storage". Require a colon, or a
   hyphen with whitespace before it, and add the case to the test at `test-kit.ps1:9261`.
2. [dev] `test-kit.ps1:9260` says "lower-case id, dash separator, the prefix twice" but the list on
   `test-kit.ps1:9261` holds one case (no doubled prefix), and the comment at `test-kit.ps1:9267` ("a title
   that merely MENTIONS the id later is left alone") has no assertion under it. Add both cases; the `while`
   loop at `close-unit.ps1:995` is otherwise untested.
3. [dev] Extend the rollback case (`test-kit.ps1:8994`) to a fixture with `docs\STATUS.md` and
   `docs\RECIPES.md` and assert they, the evidence file and the archive are restored
   (`close-unit.ps1:1095` to `close-unit.ps1:1101`). Also confirm in that test that an accepted shrink whose
   commit then fails does not leave the ratchet baseline lowered - I did not read where the baseline is
   written, so this is an open question, not a finding.
4. [dev] `dad-status-guard.ps1:64` honors `DAD_CLOSE_UNIT_STORY` from any caller, and
   `dad-status-guard.ps1:77` allows any STORIES.md path that is new in the commit, so a hand commit passes
   silently by setting that variable or by moving the file (`dad-status-guard.ps1:69` filters to A and M
   only). Unlike `DAD_ALLOW_STATUS_EDIT` neither is named as a decision. At least treat a moved or renamed
   STORIES.md as a comparison against the old path, and add a Test-Case for it.
5. [human] The story's title says a refusal cannot be walked around. Three routes remain by design or by
   omission: `git commit --no-verify`; deleting `.claude\.dad-story-open` (`close-unit.ps1:336`, local
   state, already noted in Dev notes for worktrees); and a hand commit whose subject starts `<story>:`,
   which `Test-UnitCommit` (`close-unit.ps1:352`) accepts as the story commit - the test at
   `test-kit.ps1:9316` relies on that. Decide whether these are acceptable residual risk or follow-up work.
6. [human] S39 is itself DONE by hand with no close evidence file, which is the thing S39 forbids. Decide
   whether to leave it (the `DAD_ALLOW_STATUS_EDIT` path, owner's decision) or re-close it through
   close-unit after the pending full suite run, so the card and history have evidence behind them.
7. [dev] `close-unit.ps1:1048` hard-codes `docs/API-SURFACE.md` while the docs folder is resolved
   at `close-unit.ps1:359`; derive the path from `$docs` so a moved docs folder is still treated as kit
   bookkeeping on a re-run.
