# Story S40 - Refactor - the dashboard and the scratch folder keep themselves current : report card

**Current grade: B**  (as of 2026-11-10, iteration 1)

## Grade history
| Iter | Date (YYYY-MM-DD) | Grade | Delta (one line: what changed since last) |
|------|-------------------|-------|--------------------------------------------|
| 1    | 2026-11-10        | B     | initial implementation (commits 782acb4, 5e3f0ae, ab4f9c9 per the story's Dev notes) |

## Assessment (this iteration)

How this story was closed: implemented directly from a review's issue list and marked DONE by hand at
the owner's request, NOT through close-unit. There is no close evidence file (`grades/S40_EVIDENCE.md`
does not exist). This grade is code review only: I read the source and the test bodies, I did not run or
see run any build or test. The orchestrator reports the last full suite run on this branch as 309 passed,
2 failed, with those two fixed and re-checked individually and a final full run still pending - so the
suite is NOT confirmed green for this story. The story header also still reads `R: pending, see T46.5`.

- Correctness: the three behaviors are implemented as the story describes, with the caveats below.
  - Snapshot per close: `close-unit.ps1:917` computes `$bookkeepingChanged` from the TASKS/STORIES text
    and `close-unit.ps1:923` calls `doc-stats -UpdateStatus -FromClose` only when it is true, so a re-run
    of a closed unit does not rewrite the file. A failed refresh is a WARN (`close-unit.ps1:925`), and a
    failed commit restores the old STATUS.md (`close-unit.ps1:1095`). The counter lives in
    `doc-stats.ps1:986` to `doc-stats.ps1:989` (keeps the date, adds one; starts at "never" / 1) and is
    reset to today / 0 by a plain `-UpdateStatus` (`doc-stats.ps1:985`). The write is LF, no BOM
    (`doc-stats.ps1:1027`).
  - `[status]` findings: no generated Snapshot while work is done (`doc-stats.ps1:618`), counts that
    differ from the documents (`doc-stats.ps1:623`), narrative 10 or more closes old
    (`doc-stats.ps1:627`). All three named in the Behavior are present.
  - Sweep: `close-unit.ps1:1140` gates on `$storyClosed` with no problems and `close-unit.ps1:1144`
    runs `tidy -Fix -TmpOnly -OlderThanHours 1`. `tidy.ps1:55` to `tidy.ps1:57` select files by
    `LastWriteTime`; `tidy.ps1:53` skips the whole sweep if git tracks anything under `_tmp`.
  - Elevation: `close-unit.ps1:1163` and `dad-doctor.ps1:131` probe `IsInRole(Administrator)`; the result
    is only ever a `$warns.Add` (`close-unit.ps1:1166`) or a `Say "WARN"` (`dad-doctor.ps1:134`); a probe
    that throws is treated as not elevated. Neither path can block.
  - Caveat 1 (wording): "story close" in the code means BOTH a task close that rolls its story up
    (`close-unit.ps1:852` sets `$storyClosed`) and the later story-level close (`close-unit.ps1:858`).
    So the last task of a story does sweep. The test agrees with the code (it sweeps on T1.2), but AC2's
    "a task close does not sweep" is only true of a non-final task.
  - Caveat 2 (wording): "units closed since" counts close-unit runs that changed bookkeeping, not units;
    a task close that also rolls up its story adds 1, not 2.
- Acceptance:
  - AC1 covered by `0.60.0 #4: every close regenerates the STATUS.md Snapshot in its own commit; a re-run does not; doc-stats -Findings flags a stale dashboard`
    at `test-kit.ps1:9077`: counts and NEXT after a close (`test-kit.ps1:9092`), STATUS.md in the HEAD
    commit and tree clean (`test-kit.ps1:9096`), re-run leaves the file byte-identical
    (`test-kit.ps1:9105`), stale counts flagged with both numbers (`test-kit.ps1:9117`), old narrative
    flagged (`test-kit.ps1:9122`). GAP: the "template dashboard on a project with work done" branch
    (`doc-stats.ps1:618`) has no assertion - the test only proves the negative (`test-kit.ps1:9088`),
    and after the first close the Snapshot is always generated. The threshold is exercised at 14 only,
    not at the 9/10 boundary the Behavior names.
  - AC2 covered by `0.60.0 #18: a STORY close sweeps old scratch out of _tmp\ (a task close does not; recent files and git-tracked files stay)`
    at `test-kit.ps1:9367`: non-final task close keeps the files (`test-kit.ps1:9377`), roll-up removes
    old ones and the emptied sub-folder, keeps the recent file and `_tmp` itself (`test-kit.ps1:9380`
    to `test-kit.ps1:9383`), dry run removes nothing (`test-kit.ps1:9396`), tracked file survives
    (`test-kit.ps1:9401`). GAP: the story-level close path (`-Id S1`) is not exercised for the sweep.
  - AC3 covered by `0.60.0 #16 (warning part): close-unit and dad-doctor WARN when the shell is elevated, and stay quiet when it is not`
    at `test-kit.ps1:9405`: exit 0 plus WARN when forced elevated (`test-kit.ps1:9413`,
    `test-kit.ps1:9414`), silence when forced normal (`test-kit.ps1:9420`), dad-doctor both ways
    (`test-kit.ps1:9417`, `test-kit.ps1:9423`). The real `IsInRole` probe is never exercised (both
    branches are forced through `DAD_ASSUME_ELEVATED`), which is reasonable for a suite.
- Design: touches only the files in the story's Data / interfaces line plus the `_tmp/` sentence in
  `templates/generic/CLAUDE.md:100` (named by T40.2). `templates/_common/docs/STATUS.md:6` documents the
  generated Snapshot. No pinned contract is involved; no scope creep seen.
- Quality: readable, each block carries a comment saying why it exists, and every new step is non-fatal
  by construction (try/catch into `$warns`). Weak points: (a) age is judged by `LastWriteTime` alone
  (`tidy.ps1:57`), and `Copy-Item` preserves that timestamp, so a backup copied into `_tmp` minutes ago
  from an old file looks old and is swept; (b) one tracked file under `_tmp` (a `.gitkeep` is enough)
  disables the sweep for good (`tidy.ps1:53`), and close-unit says nothing because it only adds a note
  when `removed` is above zero (`close-unit.ps1:1146`) - the accumulation the story exists to stop comes
  back silently; (c) the elevation warning is added at `close-unit.ps1:1165`, near the end of the
  script, and the file has 18 `exit` statements - I did not read each one, but any refusal that exits
  before that line prints no elevation warning, and a refused close is where "tools that refuse
  elevation fail in ways that look like code bugs" matters most; (d) the Snapshot regex at
  `doc-stats.ps1:614` matches the first `Stories: n/m Tasks: n/m` anywhere in the file, not only inside
  `## Snapshot`; (e) the elevation probe is the same five lines in two scripts (`close-unit.ps1:1159`,
  `dad-doctor.ps1:127`); (f) `doc-stats.ps1:970` has `}if ($Json)` on one line.
- Hygiene: no non-ASCII bytes found in `close-unit.ps1`, `doc-stats.ps1`, `tidy.ps1`, `dad-doctor.ps1`
  (searched). The new `tidy` switches are in its header usage (`tidy.ps1:13`) and the new `doc-stats`
  switch in its header (`doc-stats.ps1:8`). One Test-Case per fixed issue, per CLAUDE.md. No C# was
  changed by this story as far as the task Touches lists say; I did not read `local-tools`.
- Verification mode:
  - AC1: code-review only by me. The test runs in a `New-Sandbox` fixture project, so a live run touches
    no real project; I did not see it run.
  - AC2: code-review only by me. It deletes files, but only under the sandbox fixture's `_tmp`;
    `tidy.ps1:35` to `tidy.ps1:38` also refuse a path that does not look like a project. Not seen run.
  - AC3: code-review only by me. Elevation is simulated with `DAD_ASSUME_ELEVATED` and restored in a
    `finally` (`test-kit.ps1:9424`); no real elevation is needed or changed. Not seen run.

## Suggestions (prioritized; tag each so the team knows who acts)
1. [dev] `tidy.ps1:57`: judge age by the later of `CreationTime` and `LastWriteTime`, so a file copied
   into `_tmp` recently (Copy-Item keeps the source's write time) is not swept from under a working
   agent. Add an assertion to the `0.60.0 #18` case with a freshly copied old file.
2. [dev] `tidy.ps1:53` / `close-unit.ps1:1146`: skip only the tracked files (compare against the full
   `git ls-files -- _tmp` list) instead of abandoning the sweep, or at least have close-unit WARN when
   the sweep was skipped because `_tmp` is tracked. Today one `.gitkeep` turns the feature off silently.
3. [dev] `test-kit.ps1:9077`: add the missing positive case for `doc-stats.ps1:618` (template STATUS.md,
   tasks ticked by hand or with `-NoCommit`-style setup, expect `[status] ... no generated Snapshot`),
   and a 9-versus-10 boundary check for `doc-stats.ps1:627`.
4. [dev] `close-unit.ps1:1159`: compute the elevation flag early and print the warning on refusal paths
   too (first confirm which of the early exits bypass line 1165 - I did not trace them all).
5. [dev] `doc-stats.ps1:614`: anchor the count match to the `## Snapshot` block so prose elsewhere in
   STATUS.md cannot satisfy or trip the staleness check.
6. [mechanical] `doc-stats.ps1:970`: put `if ($Json)` on its own line after the closing brace.
7. [mechanical] `docs/STORIES.md` S40 AC2 and the first Behavior bullet: say "a task close that does not
   finish its story does not sweep" and "closes since" rather than "units closed since", to match
   `close-unit.ps1:852` and `doc-stats.ps1:989`. (Wording only; scribe owns the file.)
8. [human] This story was marked DONE by hand with no close evidence file and with the final full suite
   run still pending. Decide whether to run it through `close-unit -Id S40 -RequireGrade` once the suite
   is green, or to accept the hand close as recorded; the `R: pending, see T46.5` marker is also yours.
